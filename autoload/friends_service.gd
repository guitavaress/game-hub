extends Node
## FriendsService: descobre quais amigos da Steam estão online e o que jogam (autoload).
##
## Usa a Steam Web API com a chave do usuário (menu Esc › Amigos, que grava no
## config.cfg, seção [steam]):
##   - ISteamUser/GetFriendList: quem são os amigos (a cada 10 minutos);
##   - ISteamUser/GetPlayerSummaries: nome, status, jogo atual e avatar de cada
##     um (a cada 60 segundos, até 100 amigos por pedido).
##
## Enquanto um jogo roda, o hub está pausado e este serviço também: não gastamos
## consultas à toa. Quando o hub acorda, atualizamos na hora.
##
## Não conhece a cidade: só avisa (friends_changed) e responde perguntas.
## A CHAVE É SEGREDO: nunca aparece em mensagens nem em logs.

## A lista de amigos (ou o status de algum deles) mudou.
signal friends_changed
## Algo deu errado (ou falta configurar), com uma mensagem para o HUD
## (1ª linha = título do aviso, o resto = o que fazer).
signal problem(message: String)
## O avatar de um amigo terminou de baixar.
signal avatar_ready(steam_id: String, texture: Texture2D)

const API_URL: String = "https://api.steampowered.com/ISteamUser/"
const SUMMARY_INTERVAL: float = 60.0
const FRIEND_LIST_MAX_AGE: float = 600.0
const MAX_IDS_PER_REQUEST: int = 100
const REQUEST_TIMEOUT: float = 15.0
## Ao acordar, só atualiza se a última consulta tiver mais que isso (segundos).
const MIN_SECONDS_BETWEEN_REFRESHES: float = 20.0

const AVATAR_DIR: String = "user://cache/avatars"
const AVATAR_MAX_AGE_DAYS: int = 7
const MAX_AVATAR_DOWNLOADS: int = 3
const SECONDS_PER_DAY: int = 24 * 60 * 60

var _enabled: bool = false
var _api_key: String = ""
var _steam_id: String = ""
var _problem: String = ""

var _friend_ids: PackedStringArray = []
var _friend_list_ms: int = -1          # quando a lista foi buscada (-1 = nunca)
var _last_refresh_ms: int = -1
var _friends: Array[SteamFriend] = []

var _http: HTTPRequest
var _timer: Timer
var _pending_kind: String = ""         # "friends" ou "summaries"
var _summary_batches: Array[PackedStringArray] = []
var _collected: Array[SteamFriend] = []

var _avatars: Dictionary[String, Texture2D] = {}
var _avatar_queue: Array[SteamFriend] = []
var _avatar_downloads: Dictionary[String, HTTPRequest] = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(AVATAR_DIR)

	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	# O Timer é "pausável": com o hub dormindo (jogo aberto), ele para sozinho.
	_timer = Timer.new()
	_timer.wait_time = SUMMARY_INTERVAL
	_timer.timeout.connect(refresh)
	add_child(_timer)

	HubWindow.woke_up.connect(_on_hub_woke_up)
	_start()


## Lê a configuração e começa a consultar (se estiver tudo certo).
func _start() -> void:
	if not AppConfig.are_friends_enabled():
		return
	_api_key = AppConfig.get_web_api_key()
	if _api_key.is_empty():
		_report("Amigos desligados\nColoque a chave da Steam Web API em Esc › Amigos.")
		return

	_steam_id = AppConfig.get_steam_id_override()
	if _steam_id.is_empty():
		_steam_id = SteamLibrary.get_current_steam_id()
	if not (_steam_id.length() == 17 and _steam_id.is_valid_int()):
		_report("Amigos: não descobri seu ID Steam\nAbra a Steam, ou escreva o ID em Esc › Amigos.")
		return

	_enabled = true
	_timer.start()
	refresh()


## Recomeça do zero com as opções atuais (o menu de pausa chama depois de
## salvar uma chave nova).
func restart() -> void:
	if not _pending_kind.is_empty():
		_http.cancel_request()
		_pending_kind = ""
	_enabled = false
	_timer.stop()
	_problem = ""
	_friend_ids = PackedStringArray()
	_friend_list_ms = -1
	_last_refresh_ms = -1
	_summary_batches.clear()
	_collected.clear()
	var had_friends := not _friends.is_empty()
	_friends.clear()
	if had_friends:
		friends_changed.emit()
	_start()


func is_enabled() -> bool:
	return _enabled


## Último problema avisado ("" = nenhum). O HUD lê isto ao aparecer.
func get_problem() -> String:
	return _problem


## Amigos online (incluindo ausentes), em ordem alfabética.
func get_online_friends() -> Array[SteamFriend]:
	var result: Array[SteamFriend] = []
	for friend in _friends:
		if friend.is_online():
			result.append(friend)
	return result


## Amigos online jogando esse jogo agora.
func get_friends_playing(app_id: int) -> Array[SteamFriend]:
	var result: Array[SteamFriend] = []
	for friend in _friends:
		if friend.is_online() and friend.game_id == app_id and app_id > 0:
			result.append(friend)
	return result


## Pede à Steam o status atualizado dos amigos.
func refresh() -> void:
	if not _enabled or not _pending_kind.is_empty():
		return  # desligado, ou já tem um pedido em andamento
	_last_refresh_ms = Time.get_ticks_msec()
	var list_age := (Time.get_ticks_msec() - _friend_list_ms) / 1000.0
	if _friend_list_ms == -1 or list_age > FRIEND_LIST_MAX_AGE:
		_request("friends", "GetFriendList/v1/?key=%s&steamid=%s&relationship=friend" % [_api_key.uri_encode(), _steam_id])
	else:
		_request_summaries()


func _on_hub_woke_up() -> void:
	if _last_refresh_ms == -1 or (Time.get_ticks_msec() - _last_refresh_ms) / 1000.0 > MIN_SECONDS_BETWEEN_REFRESHES:
		refresh()


# --- Pedidos à Web API -------------------------------------------------------

func _request(kind: String, path: String) -> void:
	_pending_kind = kind
	var error := _http.request(API_URL + path)
	if error != OK:
		_pending_kind = ""
		# Sem o endereço na mensagem: ele tem a chave!
		_report("Amigos: não consegui falar com a Steam (erro %d)\nTento de novo em 1 minuto." % error)


func _request_summaries() -> void:
	if _friend_ids.is_empty():
		_set_friends([])
		return
	_summary_batches.clear()
	_collected.clear()
	for first in range(0, _friend_ids.size(), MAX_IDS_PER_REQUEST):
		_summary_batches.append(_friend_ids.slice(first, first + MAX_IDS_PER_REQUEST))
	_request_next_summary_batch()


func _request_next_summary_batch() -> void:
	var ids: PackedStringArray = _summary_batches.pop_front()
	_request("summaries", "GetPlayerSummaries/v2/?key=%s&steamids=%s" % [_api_key.uri_encode(), ",".join(ids)])


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _pending_kind
	_pending_kind = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_report("Amigos: sem conexão com a Steam\nTento de novo em 1 minuto.")
		return
	match code:
		200:
			pass
		401:
			_report("Amigos: sua lista de amigos é privada\nNa Steam: Perfil › Editar perfil › "
					+ "Configurações de privacidade, deixe \"Lista de amigos\" como Pública.")
			return
		403:
			# "Retrying will not help": a chave está errada. Paramos até o hub reabrir.
			_enabled = false
			_timer.stop()
			_report("Amigos: a chave da Steam Web API é inválida\nConfira e salve de novo em Esc › Amigos.")
			return
		429:
			_report("Amigos: a Steam pediu para esperar um pouco\nMuitas consultas; tento de novo em 1 minuto.")
			return
		_:
			_report("Amigos: a Steam respondeu com erro %d\nTento de novo em 1 minuto." % code)
			return

	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	match kind:
		"friends":
			_friend_ids = parse_friend_ids(json)
			_friend_list_ms = Time.get_ticks_msec()
			_request_summaries()
		"summaries":
			_collected.append_array(parse_players(json))
			if not _summary_batches.is_empty():
				_request_next_summary_batch()
			else:
				_set_friends(_collected.duplicate())


## Troca a lista de amigos e avisa quem estiver ouvindo.
func _set_friends(friends: Array[SteamFriend]) -> void:
	friends.sort_custom(func(a: SteamFriend, b: SteamFriend) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	_friends = friends
	_clear_problem()
	friends_changed.emit()


## Da resposta do GetFriendList, pega os SteamIDs dos amigos.
static func parse_friend_ids(json: Variant) -> PackedStringArray:
	var ids := PackedStringArray()
	if json is Dictionary:
		for entry: Variant in json.get("friendslist", {}).get("friends", []):
			if entry is Dictionary and entry.has("steamid"):
				ids.append(str(entry["steamid"]))
	return ids


## Da resposta do GetPlayerSummaries, monta uma ficha (SteamFriend) por amigo.
static func parse_players(json: Variant) -> Array[SteamFriend]:
	var friends: Array[SteamFriend] = []
	if not json is Dictionary:
		return friends
	for player: Variant in json.get("response", {}).get("players", []):
		if not player is Dictionary:
			continue
		var friend := SteamFriend.new()
		friend.steam_id = str(player.get("steamid", ""))
		friend.name = str(player.get("personaname", "?"))
		friend.status = int(player.get("personastate", 0))
		friend.game_name = str(player.get("gameextrainfo", ""))
		friend.avatar_url = str(player.get("avatarmedium", ""))
		# Jogos fora da Steam têm um "gameid" gigante: esses não são app IDs.
		var game_id := str(player.get("gameid", ""))
		if game_id.is_valid_int() and game_id.length() <= 10:
			friend.game_id = game_id.to_int()
		friends.append(friend)
	return friends


func _report(message: String) -> void:
	if message == _problem:
		return  # não repete o mesmo aviso a cada minuto
	_problem = message
	push_warning(message)
	problem.emit(message)


func _clear_problem() -> void:
	_problem = ""


# --- Avatares ----------------------------------------------------------------

## Avatar do amigo, ou null se ainda não tivermos (aí baixa, e o sinal
## avatar_ready avisa quando chegar).
func get_avatar(friend: SteamFriend) -> Texture2D:
	if _avatars.has(friend.steam_id):
		return _avatars[friend.steam_id]

	var path := _avatar_path(friend.steam_id)
	var texture: Texture2D = null
	if FileAccess.file_exists(path):
		texture = _load_texture(path)
		if texture != null:
			_avatars[friend.steam_id] = texture
		var age := int(Time.get_unix_time_from_system()) - FileAccess.get_modified_time(path)
		if texture != null and age < AVATAR_MAX_AGE_DAYS * SECONDS_PER_DAY:
			return texture

	# Não temos, ou está velho: baixa (e enquanto isso usa o velho, se houver).
	_queue_avatar(friend)
	return texture


func _queue_avatar(friend: SteamFriend) -> void:
	if friend.avatar_url.is_empty() or _avatar_downloads.has(friend.steam_id):
		return
	for queued in _avatar_queue:
		if queued.steam_id == friend.steam_id:
			return
	_avatar_queue.append(friend)
	_start_avatar_downloads()


func _start_avatar_downloads() -> void:
	while _avatar_downloads.size() < MAX_AVATAR_DOWNLOADS and not _avatar_queue.is_empty():
		var friend: SteamFriend = _avatar_queue.pop_front()
		var http := HTTPRequest.new()
		http.timeout = REQUEST_TIMEOUT
		http.request_completed.connect(_on_avatar_downloaded.bind(http, friend.steam_id))
		add_child(http)
		_avatar_downloads[friend.steam_id] = http
		if http.request(friend.avatar_url) != OK:
			_finish_avatar(http, friend.steam_id)


func _on_avatar_downloaded(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest, steam_id: String) -> void:
	# Só aceita JPG (é o formato dos avatares da Steam).
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 2 \
			and body[0] == 0xFF and body[1] == 0xD8:
		var path := _avatar_path(steam_id)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			var texture := _load_texture(path)
			if texture != null:
				_avatars[steam_id] = texture
				avatar_ready.emit(steam_id, texture)
	_finish_avatar(http, steam_id)


func _finish_avatar(http: HTTPRequest, steam_id: String) -> void:
	_avatar_downloads.erase(steam_id)
	http.queue_free()
	_start_avatar_downloads()


func _avatar_path(steam_id: String) -> String:
	return "%s/%s.jpg" % [AVATAR_DIR, steam_id]


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
