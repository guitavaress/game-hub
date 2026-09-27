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

## Nomes de arquivo no cache local da Steam, em ordem de preferência.
## (O nome muda conforme o jogo e a versão da Steam, e às vezes o arquivo fica
## dentro de uma subpasta com nome de "hash".)
const STEAM_CACHE_FILES: Array[String] = [
	"library_600x900.jpg",  # capa em pé
	"library_capsule.jpg",  # capa em pé (nome novo)
	"header.jpg",           # capa deitada
	"library_header.jpg",   # capa deitada (nome novo)
]

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


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


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
	if _heroes.has(app_id):
		return _heroes[app_id]
	var path := _cached_file("%d_hero" % app_id)
	if path.is_empty():
		path = _find_in_steam_cache(app_id, ["library_hero.jpg"])
	if not path.is_empty():
		var texture := _load_texture(path)
		if texture != null:
			_heroes[app_id] = texture
			return texture
	_queue_download(app_id, "%d_hero" % app_id, _hero_urls(app_id), "hero")
	return null


## Logo do jogo (PNG com fundo transparente, do cache local da Steam), ou null
## se não houver. Serve para letreiros: fica mais bonito que o nome em texto.
func get_logo(app_id: int) -> Texture2D:
	if _logos.has(app_id):
		return _logos[app_id]
	var logo: Texture2D = null
	var steam := SteamLibrary.get_steam_path()
	if not steam.is_empty():
		for file in _list_files("%s/appcache/librarycache/%d" % [steam, app_id], 2):
			if file.get_file() == "logo.png":
				logo = _load_texture(file)
				break
	_logos[app_id] = logo
	return logo


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


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("GameArt: imagem inválida em %s" % path)
		return null
	image.generate_mipmaps()  # deixa a imagem bonita vista de longe
	return ImageTexture.create_from_image(image)


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
	if urls.is_empty() or _active.has(stem) or _failed_recently(stem):
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
			var texture := _load_texture(path)
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
