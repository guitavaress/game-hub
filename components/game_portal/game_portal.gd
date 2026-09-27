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

@onready var _entry_area: Area3D = $EntryArea
@onready var _entry_shape: CollisionShape3D = $EntryArea/CollisionShape3D
@onready var _look_shape: CollisionShape3D = $LookArea/CollisionShape3D
@onready var _return_point: Marker3D = $ReturnPoint
## Público: o sistema de amigos (fase 5) vai usar.
@onready var friend_spot: Marker3D = $FriendSpot

## Quem está parado na porta agora (null = ninguém).
var _player: Player = null
## Há quantos segundos o jogador está na porta.
var _charge: float = 0.0
## true entre chamar GameLauncher.launch() e receber session_ended.
var _waiting_for_game: bool = false


func _ready() -> void:
	_apply_sizes()
	_entry_area.body_entered.connect(_on_entry_body_entered)
	_entry_area.body_exited.connect(_on_entry_body_exited)
	GameLauncher.session_ended.connect(_on_session_ended)


func _process(delta: float) -> void:
	if _waiting_for_game:
		return

	if _player != null and app_id > 0:
		_charge += delta                         # na porta: escurece
	elif _charge > 0.0:
		_charge = maxf(0.0, _charge - delta * CANCEL_SPEED)  # saiu: clareia
	else:
		return  # ninguém aqui e nada acontecendo: não mexe na tela

	ScreenFade.set_amount(_charge / enter_time)
	if _charge >= enter_time:
		_start_game()


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
func get_look_label() -> String:
	if app_id <= 0:
		return "Portal sem jogo configurado"
	return get_game_name()


## Posição e direção onde o jogador reaparece ao voltar do jogo.
func get_return_transform() -> Transform3D:
	return _return_point.global_transform


func _start_game() -> void:
	_waiting_for_game = true
	ScreenFade.set_amount(1.0)
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
