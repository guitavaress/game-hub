extends Node
## StoreInfo: busca na loja da Steam as TAGS e os endereços das CAPAS dos jogos (autoload).
##
## Usa uma API pública da loja (IStoreBrowseService/GetItems): não precisa de
## chave nem de login. Um único pedido traz até 50 jogos de uma vez.
##
## O resultado fica guardado em user://cache/store_info.json por 30 dias, então
## a internet só é usada na primeira vez (e quando o cache vence).
##
## Uso:
##   StoreInfo.fetch(lista_de_app_ids)   # pede o que estiver faltando
##   StoreInfo.is_fetching()             # ainda buscando?
##   StoreInfo.get_tags(app_id)          # tags, da mais votada para a menos votada
##   StoreInfo.get_capsule_url(app_id)   # endereço da capa "em pé" (600x900)

## Terminou de buscar tudo o que foi pedido (success = false se algo falhou).
signal fetch_finished(success: bool)

const API_URL: String = "https://api.steampowered.com/IStoreBrowseService/GetItems/v1/?input_json="
const ASSET_BASE_URL: String = "https://shared.akamai.steamstatic.com/store_item_assets/"
const CACHE_PATH: String = "user://cache/store_info.json"
const MAX_AGE_DAYS: int = 30
const BATCH_SIZE: int = 50
const REQUEST_TIMEOUT: float = 10.0
const SECONDS_PER_DAY: int = 24 * 60 * 60

## Informações por jogo. A chave é o app_id em texto (o JSON só aceita texto
## como chave). Cada valor: {"fetched": data, "tags": [ids], "capsule": url, "header": url}
var _cache: Dictionary = {}
var _queue: Array[int] = []
var _current_batch: Array[int] = []
var _fetching: bool = false
var _had_error: bool = false
var _http: HTTPRequest


func _ready() -> void:
	_load_cache()
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


## Pede à loja as informações que faltam (ou estão velhas) desses jogos.
## Se não faltar nada, não faz nada (e is_fetching() continua false).
func fetch(app_ids: Array[int]) -> void:
	for app_id in app_ids:
		if needs_update(app_id) and not app_id in _queue and not app_id in _current_batch:
			_queue.append(app_id)
	if not _fetching and not _queue.is_empty():
		_had_error = false
		_send_next_batch()


func is_fetching() -> bool:
	return _fetching


## true se já temos informação desse jogo (mesmo que velha).
func has_info(app_id: int) -> bool:
	return _cache.has(str(app_id))


## true se não temos informação, ou se ela tem mais de MAX_AGE_DAYS dias.
func needs_update(app_id: int) -> bool:
	if not has_info(app_id):
		return true
	var age := int(Time.get_unix_time_from_system()) - int(_cache[str(app_id)].get("fetched", 0))
	return age > MAX_AGE_DAYS * SECONDS_PER_DAY


## IDs das tags do jogo, da mais votada para a menos votada ([] se não souber).
func get_tags(app_id: int) -> Array[int]:
	var result: Array[int] = []
	if has_info(app_id):
		for tag: Variant in _cache[str(app_id)].get("tags", []):
			result.append(int(tag))
	return result


## Endereço da capa "em pé" (600x900) na loja, ou "" se não souber.
func get_capsule_url(app_id: int) -> String:
	return _cache.get(str(app_id), {}).get("capsule", "")


## Endereço da capa "deitada" (460x215) na loja, ou "" se não souber.
func get_header_url(app_id: int) -> String:
	return _cache.get(str(app_id), {}).get("header", "")


func _send_next_batch() -> void:
	if _queue.is_empty():
		_fetching = false
		_current_batch = []
		_save_cache()
		fetch_finished.emit(not _had_error)
		return

	_fetching = true
	_current_batch = _queue.slice(0, BATCH_SIZE)
	_queue = _queue.slice(BATCH_SIZE)

	var ids: Array = []
	for app_id in _current_batch:
		ids.append({"appid": app_id})
	var input := {
		"ids": ids,
		"context": {"language": "brazilian", "country_code": "BR"},
		"data_request": {"include_tag_count": 20, "include_assets": true},
	}
	var error := _http.request(API_URL + JSON.stringify(input).uri_encode())
	if error != OK:
		push_warning("StoreInfo: não consegui fazer o pedido (erro %d)." % error)
		_had_error = true
		_send_next_batch.call_deferred()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("StoreInfo: a loja não respondeu (resultado %d, HTTP %d)." % [result, code])
		_had_error = true
	else:
		_read_response(body)
	_send_next_batch()


func _read_response(body: PackedByteArray) -> void:
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary:
		_had_error = true
		return
	var items: Array = json.get("response", {}).get("store_items", [])
	var now := int(Time.get_unix_time_from_system())
	var answered: Array[int] = []

	for item: Dictionary in items:
		var app_id := int(item.get("appid", item.get("id", 0)))
		if app_id <= 0:
			continue
		answered.append(app_id)
		_cache[str(app_id)] = {
			"fetched": now,
			"tags": _read_tags(item),
			"capsule": _asset_url(item, "library_capsule"),
			"header": _asset_url(item, "header"),
		}

	# Jogos que a loja não conhece (removidos da loja, por exemplo): guardamos
	# "sem informação" para não perguntar de novo toda vez.
	for app_id in _current_batch:
		if not app_id in answered:
			_cache[str(app_id)] = {"fetched": now, "tags": [], "capsule": "", "header": ""}


## Lista de IDs de tags, ordenada pelo número de votos (maior primeiro).
func _read_tags(item: Dictionary) -> Array:
	var tags: Array = item.get("tags", [])
	tags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("weight", 0)) > int(b.get("weight", 0)))
	var ids: Array = []
	for tag: Dictionary in tags:
		ids.append(int(tag.get("tagid", 0)))
	return ids


## Monta o endereço completo de uma imagem. A loja manda um "molde" assim:
##   asset_url_format = "steam/apps/3527290/${FILENAME}?t=123"
##   library_capsule  = "480bd8.../library_600x900.jpg"
func _asset_url(item: Dictionary, asset_name: String) -> String:
	var assets: Dictionary = item.get("assets", {})
	var url_format: String = assets.get("asset_url_format", "")
	var file_name: String = assets.get(asset_name, "")
	if url_format.is_empty() or file_name.is_empty():
		return ""
	return ASSET_BASE_URL + url_format.replace("${FILENAME}", file_name)


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if json is Dictionary:
		_cache = json


func _save_cache() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_PATH.get_base_dir())
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("StoreInfo: não consegui salvar %s." % CACHE_PATH)
		return
	file.store_string(JSON.stringify(_cache, "\t"))
	file.close()
