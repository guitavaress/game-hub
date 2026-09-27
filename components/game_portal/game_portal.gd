class_name GamePortal
extends Node3D
## GamePortal: qualquer lugar do mundo que "é" um jogo.
##
## Hoje fica na porta de um prédio; no futuro pode ficar numa caverna, num portão
## ou no boxe de uma pista. Por isso ele NÃO sabe nada sobre prédios.
##
## Convenção de posição (vale para qualquer mundo):
##   - a origem do portal fica no CHÃO, no meio da passagem;
##   - o eixo +Z local aponta para FORA (de onde o jogador vem);
##   - a área de entrada fica logo atrás da origem (lado -Z, "dentro").
##
## Nós filhos (veja game_portal.tscn):
##   EntryArea   : a "porta". Ficar dentro dela por enter_time segundos abre o jogo.
##   LookArea    : alvo do raio da câmera; olhar para ela mostra o nome no HUD.
##   FriendSpot  : onde NPCs de amigos vão aparecer (fase 5).
##   ReturnPoint : onde o jogador reaparece quando o jogo fecha.

## App ID da Steam do jogo deste portal (0 = nenhum).
@export var app_id: int = 0
## Nome para mostrar. Se ficar vazio, usamos o nome que a Steam conhece.
@export var display_name: String = ""
## Segundos parado na porta até o jogo abrir (a tela escurece nesse tempo).
@export var enter_time: float = 1.5
## Tamanho da área de entrada (largura, altura, profundidade), em metros.
@export var entry_size: Vector3 = Vector3(2.0, 2.6, 1.2)
## Tamanho da área "olhável" (largura, altura, profundidade), em metros.
@export var look_size: Vector3 = Vector3(3.0, 3.5, 1.0)

## Ao sair da porta antes da hora, a tela clareia X vezes mais rápido do que escureceu.
const CANCEL_SPEED: float = 3.0
## Segundos para a tela clarear quando o jogador volta do jogo.
const RETURN_FADE_TIME: float = 1.0
## Distância entre amigos lado a lado, e quantos cabem por fileira.
const FRIEND_SPACING: float = 1.5
const FRIENDS_PER_ROW: int = 6

## Sons (Kenney, CC0): zumbido enquanto a tela escurece e "whoosh" ao entrar.
const CHARGE_SOUND: AudioStream = preload("res://assets/kenney/sci-fi-sounds/forceField_000.ogg")
const ENTER_SOUND: AudioStream = preload("res://assets/kenney/sci-fi-sounds/doorOpen_000.ogg")
## Tom e volume do zumbido: do começo ao fim da espera na porta.
const CHARGE_PITCH: Vector2 = Vector2(0.7, 1.7)
const CHARGE_VOLUME_DB: Vector2 = Vector2(-20.0, -6.0)

@onready var _entry_area: Area3D = $EntryArea
@onready var _entry_shape: CollisionShape3D = $EntryArea/CollisionShape3D
@onready var _look_shape: CollisionShape3D = $LookArea/CollisionShape3D
@onready var _return_point: Marker3D = $ReturnPoint
## Onde o primeiro amigo que joga este jogo aparece (os outros se espalham).
@onready var friend_spot: Marker3D = $FriendSpot

## Bonequinhos dos amigos jogando este jogo agora.
var _friend_npcs: Array[FriendNpc] = []

## Quem está parado na porta agora (null = ninguém).
var _player: Player = null
## Há quantos segundos o jogador está na porta.
var _charge: float = 0.0
## true entre chamar GameLauncher.launch() e receber session_ended.
var _waiting_for_game: bool = false

var _charge_sound: AudioStreamPlayer3D
var _enter_sound: AudioStreamPlayer


func _ready() -> void:
	_apply_sizes()
	_build_sounds()
	_entry_area.body_entered.connect(_on_entry_body_entered)
	_entry_area.body_exited.connect(_on_entry_body_exited)
	GameLauncher.session_ended.connect(_on_session_ended)
	FriendsService.friends_changed.connect(_update_friends)
	_update_friends()


func _process(delta: float) -> void:
	if _waiting_for_game:
		return

	if _player != null and app_id > 0:
		_charge += delta                         # na porta: escurece
	elif _charge > 0.0:
		_charge = maxf(0.0, _charge - delta * CANCEL_SPEED)  # saiu: clareia
	else:
		return  # ninguém aqui e nada acontecendo: não mexe na tela

	var ratio := _charge / enter_time
	ScreenFade.set_amount(ratio)
	_update_charge_sound(ratio)
	if _charge >= enter_time:
		_start_game()


## O zumbido sobe de tom e de volume enquanto a tela escurece.
func _update_charge_sound(ratio: float) -> void:
	if ratio <= 0.0:
		_charge_sound.stop()
		return
	if not _charge_sound.playing:
		_charge_sound.play()
	_charge_sound.pitch_scale = lerpf(CHARGE_PITCH.x, CHARGE_PITCH.y, ratio)
	_charge_sound.volume_db = lerpf(CHARGE_VOLUME_DB.x, CHARGE_VOLUME_DB.y, ratio)


func _build_sounds() -> void:
	_charge_sound = AudioStreamPlayer3D.new()
	_charge_sound.stream = AmbientEmitter.looping(CHARGE_SOUND)
	_charge_sound.bus = &"Efeitos"
	_charge_sound.position = Vector3(0.0, 1.5, -0.6)  # dentro do vão da porta
	add_child(_charge_sound)

	_enter_sound = AudioStreamPlayer.new()
	_enter_sound.stream = ENTER_SOUND
	_enter_sound.bus = &"Efeitos"
	_enter_sound.volume_db = -4.0
	# ALWAYS: o hub pausa logo depois de entrar, mas o "whoosh" termina de tocar.
	_enter_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_enter_sound)


## Nome do jogo deste portal ("" se não houver jogo).
func get_game_name() -> String:
	if not display_name.is_empty():
		return display_name
	if app_id <= 0:
		return ""
	var steam_name := SteamLibrary.get_game_name(app_id)
	if steam_name.is_empty():
		return "Jogo %d (não encontrado na Steam)" % app_id
	return steam_name


## "Contrato" com o jogador: o texto que aparece no HUD ao olhar para cá.
## Ex.: "Balatro — 24 h jogadas · jogado ontem"
func get_look_label() -> String:
	if app_id <= 0:
		return "Portal sem jogo configurado"
	var info := _play_info()
	return get_game_name() if info.is_empty() else "%s — %s" % [get_game_name(), info]


## "24 h jogadas · jogado ontem" (ou "" se a Steam não souber).
func _play_info() -> String:
	var minutes := SteamLibrary.get_playtime_minutes(app_id)
	var last_played := SteamLibrary.get_last_played(app_id)
	if minutes <= 0 and last_played <= 0:
		return "nunca jogado" if minutes == 0 else ""
	var parts := PackedStringArray()
	if minutes > 0:
		parts.append(_format_playtime(minutes))
	if last_played > 0:
		parts.append(_format_last_played(last_played))
	return " · ".join(parts)


static func _format_playtime(minutes: int) -> String:
	if minutes < 60:
		return "%d min jogados" % minutes
	var hours := minutes / 60.0
	if hours < 10.0:
		# Uma casa decimal, com vírgula: "2,5 h" (e "2 h" em vez de "2,0 h").
		return "%s h jogadas" % ("%.1f" % hours).replace(".", ",").trim_suffix(",0")
	return "%d h jogadas" % floori(hours)


static func _format_last_played(unix_time: int) -> String:
	# Compara DIAS do calendário no fuso do PC (ontem às 23h = "ontem").
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var today := floori((Time.get_unix_time_from_system() + bias_seconds) / 86400.0)
	var day := floori((unix_time + bias_seconds) / 86400.0)
	var days := maxi(today - day, 0)
	if days == 0:
		return "jogado hoje"
	if days == 1:
		return "jogado ontem"
	if days < 30:
		return "jogado há %d dias" % days
	if days < 365:
		var months := floori(days / 30.0)
		return "jogado há 1 mês" if months == 1 else "jogado há %d meses" % months
	var years := floori(days / 365.0)
	return "jogado há 1 ano" if years == 1 else "jogado há %d anos" % years


## Posição e direção onde o jogador reaparece ao voltar do jogo.
func get_return_transform() -> Transform3D:
	return _return_point.global_transform


func _start_game() -> void:
	_waiting_for_game = true
	ScreenFade.set_amount(1.0)
	_charge_sound.stop()
	_enter_sound.play()
	GameLauncher.launch(app_id, self)


func _on_session_ended(ended_app_id: int, source: Node, _success: bool, _message: String) -> void:
	if source == self:
		# A sessão que ESTE portal pediu acabou.
		_waiting_for_game = false
		_charge = 0.0
		# Coloca o jogador na frente da porta (fora da área, para não reabrir o jogo).
		_teleport_player_to_door(_player)
		# Se o hub nem chegou a dormir (ex.: o jogo não está mais instalado),
		# quem escureceu a tela foi este portal, então ele mesmo clareia.
		if not HubWindow.is_sleeping:
			ScreenFade.fade_in(RETURN_FADE_TIME)
	elif source == null and ended_app_id == app_id and app_id > 0:
		# Este jogo foi aberto POR FORA do hub e fechou: o jogador volta na
		# porta deste portal, como se tivesse entrado por aqui.
		_teleport_player_to_door(null)


## Leva o jogador para o ReturnPoint. Se não soubermos quem é (null), procuramos
## pelo grupo "player".
func _teleport_player_to_door(player: Player) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.teleport_to(get_return_transform())


func _on_entry_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body as Player


func _on_entry_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


## Mostra, ao lado da porta, os amigos que estão jogando este jogo agora.
func _update_friends() -> void:
	for npc in _friend_npcs:
		npc.queue_free()
	_friend_npcs.clear()
	if app_id <= 0:
		return

	var friends := FriendsService.get_friends_playing(app_id)
	for i in friends.size():
		var npc := FriendNpc.new()
		npc.friend = friends[i]
		npc.show_game_name = false  # a placa do prédio já diz qual é o jogo
		npc.position = _friend_slot(i)
		add_child(npc)
		_friend_npcs.append(npc)


## Posição do amigo número "index": o primeiro no FriendSpot, os outros se
## alternando dos dois lados da porta (sem bloquear a entrada), em fileiras.
func _friend_slot(index: int) -> Vector3:
	var row := floori(index / float(FRIENDS_PER_ROW))
	var in_row := index % FRIENDS_PER_ROW
	var side := 1.0 if in_row % 2 == 0 else -1.0
	var step := floori(in_row / 2.0)
	var base := friend_spot.position
	return Vector3(side * (absf(base.x) + step * FRIEND_SPACING), base.y, base.z + row * FRIEND_SPACING)


## Cada portal ganha formas de colisão próprias com os tamanhos exportados.
## (Criamos novas para não compartilhar a mesma forma entre portais diferentes.)
func _apply_sizes() -> void:
	var entry_box := BoxShape3D.new()
	entry_box.size = entry_size
	_entry_shape.shape = entry_box
	_entry_shape.position = Vector3(0.0, entry_size.y / 2.0, -entry_size.z / 2.0)

	var look_box := BoxShape3D.new()
	look_box.size = look_size
	_look_shape.shape = look_box
	_look_shape.position = Vector3(0.0, look_size.y / 2.0, 0.0)
