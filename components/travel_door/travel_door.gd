class_name TravelDoor
extends Node3D
## PORTA DE VIAGEM (Fase 9): olhar para ela e apertar E leva o jogador a outro
## lugar, com a tela escurecendo (player.travel_to). É a lógica da porta da
## casa, sem a aparência: quem usa desenha a moldura em volta (a casa desenha
## a porta do loft; a cidade, a porta "Casa" da praça), como no PortalShell.
##
## Convenção (igual à do GamePortal): a origem fica no CHÃO, no meio da
## porta, e a FRENTE (+Z) aponta para o lado de onde o jogador vem.
##
## Quem cria preenche door_name e, quando souber, destination. Enquanto
## locked_reason tiver texto, a porta fica trancada e o cartão mostra o motivo.

## Nome no cartão ("Casa", "Rua").
var door_name: String = ""
## Linha de baixo do cartão quando a porta está aberta ("Ir para a praça").
var detail: String = ""
## Dica do E no cartão.
var action_text: String = "E para entrar"
## Mensagem na tela escura durante a viagem.
var travel_message: String = ""
## Para onde a porta leva. O jogador fica virado para o -Z deste transform
## (como no player.teleport_to).
var destination: Transform3D = Transform3D.IDENTITY
## Texto = trancada (ex.: "Montando a cidade… 40%"); vazio = aberta.
var locked_reason: String = ""
## Tamanho da área olhável (largura, altura, profundidade).
var look_size: Vector3 = Vector3(1.6, 2.6, 0.6)

var _has_destination: bool = false


func _ready() -> void:
	add_to_group("travel_door")
	# Alvo "olhável" (camada 3): o raio da câmera acha a porta por aqui.
	var look := Area3D.new()
	look.name = "LookArea"
	look.collision_layer = 4
	look.collision_mask = 0
	look.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = look_size
	shape.shape = box
	shape.position = Vector3(0.0, look_size.y / 2.0, 0.0)
	look.add_child(shape)
	add_child(look)


## Define para onde a porta leva (veja destination).
func set_destination(target: Transform3D) -> void:
	destination = target
	_has_destination = true


func is_open() -> bool:
	return _has_destination and locked_reason.is_empty()


func get_look_info() -> Dictionary:
	if not locked_reason.is_empty():
		return {"title": door_name, "detail": locked_reason}
	return {"title": door_name, "detail": detail, "action": action_text if _has_destination else ""}


## E apertado olhando para a porta (o jogador já confere se pode interagir:
## sem painel aberto, sem viagem, sem jogo abrindo ou rodando).
func interact(player: Node) -> void:
	if not is_open() or not player.has_method("travel_to"):
		return
	player.travel_to(destination, travel_message)
