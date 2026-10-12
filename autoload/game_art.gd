extends Node
## GameArt: arranja a imagem de capa de cada jogo (autoload).
##
## Ordem de busca:
##   1. Nosso cache:          user://cache/art/<appid>_hd.jpg (600x900) ou <appid>.jpg
##   2. Cache local da Steam: <Steam>/appcache/librarycache/<appid>/...
##      (capa "em pé", normalmente 300x450; se não houver, a capa "deitada")
##   3. Download da loja, nesta ordem:
##        a) endereço exato vindo do StoreInfo (funciona para jogos recentes)
##        b) endereço "simples" do CDN (funciona para jogos mais antigos)
##   4. Se nada der certo: quem pediu mostra uma placa (placeholder).
##      Anotamos a falha e só tentamos baixar de novo depois de 7 dias.
##
## Capas em HD: se a capa encontrada for pequena (menos de 600 px de largura),
## devolvemos ela na hora e baixamos a versão 600x900 em segundo plano. Quando
## ela chega, o sinal art_ready avisa de novo, com a imagem melhor.
##
## Também arranja o HERO (banner largo 1920x620, sem logo, feito pela Steam para
## ficar ATRÁS do logo) e o LOGO (PNG transparente) de cada jogo.
##
## Memória (Fase 8.8): na cidade, o hero e o logo aparecem numa fachada, então
## get_hero e get_logo devolvem uma versão COMPRIMIDA para a placa de vídeo
## (S3TC, ~6 vezes menos memória; só diminuem se passarem de
## WORLD_MAX_WIDTH, como alguns logos de 4700 px). Com 200 jogos, a memória de
## textura cai de ~1,9 GB para ~0,3 GB. A tela "Abrindo X…" é a tela inteira:
## ela pede o original sem compressão com get_hero_full e get_logo_full
## (carregado na hora, um de cada vez).
##
## Em segundo plano (Fase 9.3): carregar um hero ou um logo do disco leva de
## 10 a 160 ms (um PNG de 4700 px é o pior). Para a cidade montar sem travar
## a casa, preload_world_art(app_ids) carrega em threads (WorkerThreadPool) e
## is_world_art_ready(app_id) diz quando acabou. A COMPRESSÃO (~6 ms) fica na
## thread principal: o compressor S3TC da Godot às vezes trava quando roda
## numa thread (medido na 9.3: 1 vez a cada 3 rodadas com 200 jogos).
## get_hero/get_logo continuam valendo a qualquer hora: se o carregamento
## daquele jogo ainda estiver em andamento, esperam por ele.
##
## Uso:
##   var textura := GameArt.get_art(app_id)   # null = ainda não temos
##   GameArt.art_ready.connect(...)           # chegou uma capa (nova ou melhor)
##   var hero := GameArt.get_hero(app_id)     # null = ainda não temos (hero_ready avisa)
##   var logo := GameArt.get_logo(app_id)     # null = o jogo não tem logo

## Uma capa acabou de chegar (a primeira, ou uma versão melhor).
signal art_ready(app_id: int, texture: Texture2D)
## Um hero acabou de chegar (download).
signal hero_ready(app_id: int, texture: Texture2D)

const CACHE_DIR: String = "user://cache/art"
const CDN_URL: String = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%d/%s"
const MAX_DOWNLOADS: int = 4
const DOWNLOAD_TIMEOUT: float = 15.0
const RETRY_AFTER_DAYS: int = 7
const SECONDS_PER_DAY: int = 24 * 60 * 60
## Capas com menos que isso de largura ganham uma versão HD baixada.
const HD_MIN_WIDTH: int = 600
## Largura máxima do hero e do logo usados no mundo (fachadas). Diminuir custa
## tempo na abertura, então só as imagens enormes passam por isso.
const WORLD_MAX_WIDTH: int = 2048
## Quantos carregamentos em segundo plano rodam ao mesmo tempo (o resto das
## threads fica livre para a Godot).
const MAX_PARALLEL_LOADS: int = 3

## Nomes de arquivo no cache local da Steam, em ordem de preferência.
## (O nome muda conforme o jogo e a versão da Steam, e às vezes o arquivo fica
## dentro de uma subpasta com nome de "hash".)
const STEAM_CACHE_FILES: Array[String] = [
	"library_600x900.jpg",  # capa em pé
	"library_capsule.jpg",  # capa em pé (nome novo)
	"header.jpg",           # capa deitada
	"library_header.jpg",   # capa deitada (nome novo)
]

## false = nunca baixa nada (os testes de escala, com jogos inventados, ligam isto).
var allow_downloads: bool = true
var _textures: Dictionary[int, Texture2D] = {}
var _heroes: Dictionary[int, Texture2D] = {}
## Logos já procurados (app_id -> textura, ou null se o jogo não tem logo).
var _logos: Dictionary = {}
## Downloads esperando a vez. Cada um: {"app_id", "stem", "urls", "kind"}.
## "kind" é "cover" (capa) ou "hero".
## "stem" é o nome do arquivo sem extensão: "2379780" ou "2379780_hd".
var _queue: Array[Dictionary] = []
## Downloads em andamento, pelo "stem".
var _active: Dictionary[String, Dictionary] = {}
## Carregamentos em segundo plano: "hero:<app_id>" ou "logo:<app_id>" -> tarefa
## do WorkerThreadPool. As imagens prontas ficam em _loaded_images até a
## thread principal transformá-las em textura (protegidas pelo _loaded_lock).
var _pending: Dictionary[String, int] = {}
## Carregamentos esperando a vez (no máximo MAX_PARALLEL_LOADS rodam juntos).
## Cada um: [key, caminho do arquivo].
var _load_queue: Array[Array] = []
var _loaded_images: Dictionary[String, Image] = {}
var _loaded_lock := Mutex.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	set_process(false)  # só trabalha com carregamentos na fila


## Com carregamentos na fila: começa os próximos quando há vaga.
func _process(_delta: float) -> void:
	_start_queued()
	if _load_queue.is_empty():
		set_process(false)


## Fechando o hub: esvazia a fila e espera as threads terminarem.
func _exit_tree() -> void:
	_load_queue.clear()
	for task in _pending.values():
		WorkerThreadPool.wait_for_task_completion(task)
	_pending.clear()


# --- Em segundo plano -----------------------------------------------------------

## Começa a carregar (em threads) o hero e o logo destes jogos, na ordem da
## lista. Quem ainda não tem arquivo no disco fica de fora (get_hero baixa).
func preload_world_art(app_ids: Array[int]) -> void:
	for app_id in app_ids:
		if not _heroes.has(app_id) and not _is_loading("hero:%d" % app_id):
			var hero_path := _hero_path(app_id)
			if not hero_path.is_empty():
				_load_queue.append(["hero:%d" % app_id, hero_path])
		if not _logos.has(app_id) and not _is_loading("logo:%d" % app_id):
			var logo_path := _logo_path(app_id)
			if logo_path.is_empty():
				_logos[app_id] = null  # o jogo não tem logo
			else:
				_load_queue.append(["logo:%d" % app_id, logo_path])
	_start_queued()
	set_process(not _load_queue.is_empty())


## O hero e o logo deste jogo já estão prontos (ou nem existem no disco)?
## Não espera nada: quem quer esperar pergunta de novo no próximo quadro.
## Termina (comprime) no máximo UMA imagem por chamada: comprimir custa uns
## 10 ms, e as duas juntas pesariam num quadro só.
func is_world_art_ready(app_id: int) -> bool:
	for key in ["hero:%d" % app_id, "logo:%d" % app_id]:
		if _queue_index(key) >= 0:
			return false  # ainda esperando a vez
		if _pending.has(key):
			if WorkerThreadPool.is_task_completed(_pending[key]):
				_finish_loading(key)
			return false  # a outra (se houver) fica para a próxima chamada
	return true


## Começa os carregamentos da fila enquanto houver vaga.
func _start_queued() -> void:
	var running := 0
	for task in _pending.values():
		if not WorkerThreadPool.is_task_completed(task):
			running += 1
	while running < MAX_PARALLEL_LOADS and not _load_queue.is_empty():
		var next: Array = _load_queue.pop_front()
		_pending[next[0]] = WorkerThreadPool.add_task(_load_in_thread.bind(next[0], next[1]), false, "GameArt " + next[0])
		running += 1


func _is_loading(key: String) -> bool:
	return _pending.has(key) or _queue_index(key) >= 0


func _queue_index(key: String) -> int:
	for i in _load_queue.size():
		if _load_queue[i][0] == key:
			return i
	return -1


## Se "key" está na fila ou carregando: na fila, sai dela (quem pediu carrega
## na hora); carregando, espera terminar e guarda a textura.
func _settle(key: String) -> void:
	var index := _queue_index(key)
	if index >= 0:
		_load_queue.remove_at(index)
	elif _pending.has(key):
		_finish_loading(key)


## Roda numa thread: carrega, diminui se precisar e gera os mipmaps. A
## compressão e a textura ficam para a thread principal (_finish_loading).
func _load_in_thread(key: String, path: String) -> void:
	var image := _decode_image(path, WORLD_MAX_WIDTH, false)
	_loaded_lock.lock()
	_loaded_images[key] = image
	_loaded_lock.unlock()


## Espera (se ainda não acabou) o carregamento "key" e guarda a textura.
func _finish_loading(key: String) -> void:
	WorkerThreadPool.wait_for_task_completion(_pending[key])
	_pending.erase(key)
	_loaded_lock.lock()
	var image: Image = _loaded_images.get(key)
	_loaded_images.erase(key)
	_loaded_lock.unlock()
	if image != null:
		image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
	var texture := _to_texture(image, true)
	var app_id := int(key.get_slice(":", 1))
	if key.begins_with("hero:"):
		if texture != null:
			_heroes[app_id] = texture
	else:
		_logos[app_id] = texture


## Devolve a capa do jogo, ou null se ainda não tivermos (aí começa o download
## e o sinal art_ready avisa quando chegar).
func get_art(app_id: int) -> Texture2D:
	if _textures.has(app_id):
		return _textures[app_id]

	# 1) versão HD que já baixamos antes
	var hd_path := _cached_file("%d_hd" % app_id)
	if not hd_path.is_empty():
		var hd_texture := _load_texture(hd_path)
		if hd_texture != null and hd_texture.get_width() >= HD_MIN_WIDTH:
			_textures[app_id] = hd_texture
			return hd_texture
		# "HD" que não é HD (versões antigas do hub salvavam assim): apaga.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hd_path))

	# 2) nosso cache normal, ou o cache da Steam
	var path := _cached_file(str(app_id))
	if path.is_empty():
		path = _find_in_steam_cache(app_id)
	if not path.is_empty():
		var texture := _load_texture(path)
		if texture != null:
			_textures[app_id] = texture
			if texture.get_width() < HD_MIN_WIDTH:
				_queue_download(app_id, "%d_hd" % app_id, _hd_urls(app_id))
			return texture

	# 3) não temos nada: baixa (a normal; se vier pequena, depois vem a HD)
	_queue_download(app_id, str(app_id), _normal_urls(app_id))
	return null


## Hero do jogo (banner 1920x620), ou null se ainda não tivermos (aí começa o
## download e o sinal hero_ready avisa quando chegar).
func get_hero(app_id: int) -> Texture2D:
	_settle("hero:%d" % app_id)  # estava na fila ou carregando em segundo plano
	if _heroes.has(app_id):
		return _heroes[app_id]
	var path := _hero_path(app_id)
	if not path.is_empty():
		var texture := _load_texture(path, WORLD_MAX_WIDTH, true)
		if texture != null:
			_heroes[app_id] = texture
			return texture
	_queue_download(app_id, "%d_hero" % app_id, _hero_urls(app_id), "hero")
	return null


## Logo do jogo (PNG com fundo transparente, do cache local da Steam), ou null
## se não houver. Serve para letreiros: fica mais bonito que o nome em texto.
func get_logo(app_id: int) -> Texture2D:
	_settle("logo:%d" % app_id)  # estava na fila ou carregando em segundo plano
	if _logos.has(app_id):
		return _logos[app_id]
	var path := _logo_path(app_id)
	var logo: Texture2D = null if path.is_empty() else _load_texture(path, WORLD_MAX_WIDTH, true)
	_logos[app_id] = logo
	return logo


## Hero no tamanho original, para a tela inteira ("Abrindo X…"). Carrega na
## hora e guarda só o último (null = ainda não temos: use get_hero, que baixa).
func get_hero_full(app_id: int) -> Texture2D:
	return _full("hero", app_id, _hero_path(app_id))


## Logo no tamanho original, para a tela inteira (null = o jogo não tem logo).
func get_logo_full(app_id: int) -> Texture2D:
	return _full("logo", app_id, _logo_path(app_id))


## Uma imagem original guardada por tipo ("hero", "logo"): a tela só mostra
## um jogo por vez, então não vale guardar mais.
var _full_cache: Dictionary[String, Array] = {}

func _full(kind: String, app_id: int, path: String) -> Texture2D:
	var cached: Array = _full_cache.get(kind, [])
	if not cached.is_empty() and cached[0] == app_id:
		return cached[1]
	var texture: Texture2D = null if path.is_empty() else _load_texture(path)
	_full_cache[kind] = [app_id, texture]
	return texture


## Onde está o hero no disco ("" = não temos).
func _hero_path(app_id: int) -> String:
	var path := _cached_file("%d_hero" % app_id)
	if path.is_empty():
		path = _find_in_steam_cache(app_id, ["library_hero.jpg"])
	return path


## Onde está o logo no disco, no cache da Steam ("" = não há).
func _logo_path(app_id: int) -> String:
	var steam := SteamLibrary.get_steam_path()
	if steam.is_empty():
		return ""
	for file in _list_files("%s/appcache/librarycache/%d" % [steam, app_id], 2):
		if file.get_file() == "logo.png":
			return file
	return ""


## Arquivo "<stem>.jpg" ou "<stem>.png" no nosso cache ("" = não existe).
func _cached_file(stem: String) -> String:
	for extension in ["jpg", "png"]:
		var path := "%s/%s.%s" % [CACHE_DIR, stem, extension]
		if FileAccess.file_exists(path):
			return path
	return ""


## Procura, no cache local da Steam, o primeiro destes nomes de arquivo.
func _find_in_steam_cache(app_id: int, names: Array[String] = STEAM_CACHE_FILES) -> String:
	var steam := SteamLibrary.get_steam_path()
	if steam.is_empty():
		return ""
	var files := _list_files("%s/appcache/librarycache/%d" % [steam, app_id], 2)
	for wanted in names:
		for file in files:
			if file.get_file() == wanted:
				return file
	return ""


## Lista arquivos de uma pasta e das subpastas (até "depth" níveis).
func _list_files(folder: String, depth: int) -> PackedStringArray:
	var result := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return result
	for file_name in DirAccess.get_files_at(folder):
		result.append(folder + "/" + file_name)
	if depth > 1:
		for sub_folder in DirAccess.get_directories_at(folder):
			result.append_array(_list_files(folder + "/" + sub_folder, depth - 1))
	return result


## Carrega uma imagem do disco. "max_width" > 0 diminui (mantendo a proporção)
## se for mais larga; "compress" comprime para a placa de vídeo (S3TC: ~4 a 8
## vezes menos memória). Se a compressão não existir nesta versão da Godot, a
## imagem fica sem comprimir (funciona igual, só gasta mais).
func _load_texture(path: String, max_width: int = 0, compress: bool = false) -> Texture2D:
	return _to_texture(_decode_image(path, max_width, compress), compress)


## A parte pesada do _load_texture (pode rodar numa thread: não cria textura
## nem mexe em nada do GameArt). Devolve null se a imagem for inválida.
static func _decode_image(path: String, max_width: int, compress: bool) -> Image:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	if max_width > 0 and image.get_width() > max_width:
		var height := maxi(1, roundi(image.get_height() * float(max_width) / image.get_width()))
		image.resize(max_width, height, Image.INTERPOLATE_BILINEAR)  # rápido; a imagem continua grande
	image.generate_mipmaps()  # deixa a imagem bonita vista de longe
	if compress:
		image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
	return image


## Textura a partir da imagem já carregada (na thread principal).
func _to_texture(image: Image, wanted_compressed: bool) -> Texture2D:
	if image == null:
		push_warning("GameArt: imagem inválida")
		return null
	if wanted_compressed and not image.is_compressed() and not _warned_compress:
		_warned_compress = true
		push_warning("GameArt: sem compressão de textura nesta versão; as capas gastam mais memória.")
	return ImageTexture.create_from_image(image)


var _warned_compress: bool = false


# --- Endereços ---------------------------------------------------------------

func _normal_urls(app_id: int) -> Array[String]:
	return _without_empty([
		StoreInfo.get_capsule_url(app_id),
		StoreInfo.get_header_url(app_id),
		CDN_URL % [app_id, "library_600x900.jpg"],
		CDN_URL % [app_id, "header.jpg"],
	])


## A versão HD (600x900) da capa em pé: o endereço exato vem do StoreInfo.
func _hd_urls(app_id: int) -> Array[String]:
	return _without_empty([
		StoreInfo.get_capsule_hd_url(app_id),
		CDN_URL % [app_id, "library_600x900_2x.jpg"],
	])


func _hero_urls(app_id: int) -> Array[String]:
	return _without_empty([
		StoreInfo.get_hero_url(app_id),
		CDN_URL % [app_id, "library_hero.jpg"],
	])


func _without_empty(urls: Array) -> Array[String]:
	var result: Array[String] = []
	for url: String in urls:
		if not url.is_empty() and not url in result:
			result.append(url)
	return result


# --- Downloads ---------------------------------------------------------------

func _queue_download(app_id: int, stem: String, urls: Array[String], kind: String = "cover") -> void:
	if not allow_downloads or urls.is_empty() or _active.has(stem) or _failed_recently(stem):
		return
	for job in _queue:
		if job["stem"] == stem:
			return
	_queue.append({"app_id": app_id, "stem": stem, "urls": urls, "kind": kind})
	_start_downloads()


func _start_downloads() -> void:
	while _active.size() < MAX_DOWNLOADS and not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var http := HTTPRequest.new()
		http.timeout = DOWNLOAD_TIMEOUT
		http.request_completed.connect(_on_download_completed.bind(http, job))
		add_child(http)
		_active[job["stem"]] = job
		_request_next_url(http, job)


func _request_next_url(http: HTTPRequest, job: Dictionary) -> void:
	var urls: Array[String] = job["urls"]
	while not urls.is_empty():
		if http.request(urls[0]) == OK:
			return
		urls.pop_front()  # não deu nem para pedir: tenta o próximo
	_finish_download(http, job, null)


func _on_download_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest, job: Dictionary) -> void:
	var extension := _image_extension(body)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not extension.is_empty():
		var path := "%s/%s.%s" % [CACHE_DIR, job["stem"], extension]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			var is_hero: bool = job["kind"] == "hero"
			var texture := _load_texture(path, WORLD_MAX_WIDTH if is_hero else 0, is_hero)
			var is_hd_job := String(job["stem"]).ends_with("_hd")
			if texture != null and (not is_hd_job or texture.get_width() >= HD_MIN_WIDTH):
				_finish_download(http, job, texture)
				return
			# Pedimos HD e veio pequena (ou a imagem é inválida): não serve.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Este endereço não serviu: tenta o próximo.
	var urls: Array[String] = job["urls"]
	urls.pop_front()
	_request_next_url(http, job)


func _finish_download(http: HTTPRequest, job: Dictionary, texture: Texture2D) -> void:
	var app_id: int = job["app_id"]
	_active.erase(job["stem"])
	http.queue_free()
	if texture != null and job["kind"] == "hero":
		_heroes[app_id] = texture
		hero_ready.emit(app_id, texture)
	elif texture != null:
		# Só troca se for melhor (ou se ainda não tínhamos nada).
		var current: Texture2D = _textures.get(app_id)
		if current == null or texture.get_width() > current.get_width():
			_textures[app_id] = texture
			art_ready.emit(app_id, texture)
		# Baixou a normal e ela veio pequena? Então busca a HD também.
		if texture.get_width() < HD_MIN_WIDTH and not String(job["stem"]).ends_with("_hd"):
			_queue_download(app_id, "%d_hd" % app_id, _hd_urls(app_id))
	else:
		_mark_failed(job["stem"])
	_start_downloads()


## Descobre o tipo da imagem pelos primeiros bytes ("" = não é imagem).
func _image_extension(bytes: PackedByteArray) -> String:
	if bytes.size() > 4 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		return "jpg"
	if bytes.size() > 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	return ""


# --- Falhas ------------------------------------------------------------------
# Guardamos um arquivo <stem>.none com a data da falha, para não ficar
# tentando baixar toda vez que o hub abre.

func _mark_failed(stem: String) -> void:
	var file := FileAccess.open("%s/%s.none" % [CACHE_DIR, stem], FileAccess.WRITE)
	if file != null:
		file.store_string(str(int(Time.get_unix_time_from_system())))
		file.close()


func _failed_recently(stem: String) -> bool:
	var path := "%s/%s.none" % [CACHE_DIR, stem]
	if not FileAccess.file_exists(path):
		return false
	var failed_at := FileAccess.get_file_as_string(path).to_int()
	var age := int(Time.get_unix_time_from_system()) - failed_at
	return age < RETRY_AFTER_DAYS * SECONDS_PER_DAY

