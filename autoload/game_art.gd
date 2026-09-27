extends Node
## GameArt: arranja a imagem de capa de cada jogo (autoload).
##
## Ordem de busca:
##   1. Nosso cache:          user://cache/art/<appid>.jpg (ou .png)
##   2. Cache local da Steam: <Steam>/appcache/librarycache/<appid>/...
##      (capa "em pé" 600x900; se não houver, a capa "deitada" 460x215)
##   3. Download da loja, nesta ordem:
##        a) endereço exato vindo do StoreInfo (funciona para jogos recentes)
##        b) endereço "simples" do CDN (funciona para jogos mais antigos)
##      A imagem baixada é salva no nosso cache.
##   4. Se nada der certo: quem pediu mostra uma placa (placeholder).
##      Anotamos a falha e só tentamos baixar de novo depois de 7 dias.
##
## Uso:
##   var textura := GameArt.get_art(app_id)   # null = ainda não temos
##   GameArt.art_ready.connect(...)           # avisa quando um download termina

## Uma imagem que não estava disponível acabou de chegar.
signal art_ready(app_id: int, texture: Texture2D)

const CACHE_DIR: String = "user://cache/art"
const CDN_URL: String = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%d/%s"
const MAX_DOWNLOADS: int = 4
const DOWNLOAD_TIMEOUT: float = 15.0
const RETRY_AFTER_DAYS: int = 7
const SECONDS_PER_DAY: int = 24 * 60 * 60

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
var _queue: Array[int] = []
## Downloads em andamento: app_id -> endereços que ainda faltam tentar.
var _pending_urls: Dictionary[int, Array] = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


## Devolve a capa do jogo, ou null se ainda não tivermos (aí começa o download
## e o sinal art_ready avisa quando chegar).
func get_art(app_id: int) -> Texture2D:
	if _textures.has(app_id):
		return _textures[app_id]

	var path := _find_on_disk(app_id)
	if not path.is_empty():
		var texture := _load_texture(path)
		if texture != null:
			_textures[app_id] = texture
			return texture

	_queue_download(app_id)
	return null


## Procura a imagem no nosso cache e depois no cache da Steam. "" = não achou.
func _find_on_disk(app_id: int) -> String:
	for extension in ["jpg", "png"]:
		var cached := "%s/%d.%s" % [CACHE_DIR, app_id, extension]
		if FileAccess.file_exists(cached):
			return cached

	var steam := SteamLibrary.get_steam_path()
	if steam.is_empty():
		return ""
	var files := _list_files("%s/appcache/librarycache/%d" % [steam, app_id], 2)
	for wanted in STEAM_CACHE_FILES:
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


# --- Downloads ---------------------------------------------------------------

func _queue_download(app_id: int) -> void:
	if app_id in _queue or _pending_urls.has(app_id) or _failed_recently(app_id):
		return
	_queue.append(app_id)
	_start_downloads()


func _start_downloads() -> void:
	while _pending_urls.size() < MAX_DOWNLOADS and not _queue.is_empty():
		var app_id: int = _queue.pop_front()
		var urls := _candidate_urls(app_id)
		_pending_urls[app_id] = urls

		var http := HTTPRequest.new()
		http.timeout = DOWNLOAD_TIMEOUT
		http.request_completed.connect(_on_download_completed.bind(http, app_id))
		add_child(http)
		_request_next_url(http, app_id)


func _candidate_urls(app_id: int) -> Array:
	var urls: Array = []
	for url in [
		StoreInfo.get_capsule_url(app_id),
		StoreInfo.get_header_url(app_id),
		CDN_URL % [app_id, "library_600x900.jpg"],
		CDN_URL % [app_id, "header.jpg"],
	]:
		if not url.is_empty() and not url in urls:
			urls.append(url)
	return urls


func _request_next_url(http: HTTPRequest, app_id: int) -> void:
	var urls: Array = _pending_urls[app_id]
	while not urls.is_empty():
		if http.request(urls[0]) == OK:
			return
		urls.pop_front()  # não deu nem para pedir: tenta o próximo
	_finish_download(http, app_id, null)


func _on_download_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest, app_id: int) -> void:
	var extension := _image_extension(body)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not extension.is_empty():
		var path := "%s/%d.%s" % [CACHE_DIR, app_id, extension]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			var texture := _load_texture(path)
			if texture != null:
				_finish_download(http, app_id, texture)
				return

	# Este endereço não serviu: tenta o próximo.
	_pending_urls[app_id].pop_front()
	_request_next_url(http, app_id)


func _finish_download(http: HTTPRequest, app_id: int, texture: Texture2D) -> void:
	_pending_urls.erase(app_id)
	http.queue_free()
	if texture != null:
		_textures[app_id] = texture
		art_ready.emit(app_id, texture)
	else:
		_mark_failed(app_id)
	_start_downloads()


## Descobre o tipo da imagem pelos primeiros bytes ("" = não é imagem).
func _image_extension(bytes: PackedByteArray) -> String:
	if bytes.size() > 4 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		return "jpg"
	if bytes.size() > 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	return ""


# --- Falhas ------------------------------------------------------------------
# Guardamos um arquivo <appid>.none com a data da falha, para não ficar
# tentando baixar toda vez que o hub abre.

func _mark_failed(app_id: int) -> void:
	var file := FileAccess.open("%s/%d.none" % [CACHE_DIR, app_id], FileAccess.WRITE)
	if file != null:
		file.store_string(str(int(Time.get_unix_time_from_system())))
		file.close()


func _failed_recently(app_id: int) -> bool:
	var path := "%s/%d.none" % [CACHE_DIR, app_id]
	if not FileAccess.file_exists(path):
		return false
	var failed_at := FileAccess.get_file_as_string(path).to_int()
	var age := int(Time.get_unix_time_from_system()) - failed_at
	return age < RETRY_AFTER_DAYS * SECONDS_PER_DAY
