class_name TransitStop
extends Node3D
## PARADA de transporte (Fase 8): a lógica de uma estação de metrô, sem a
## aparência. Na cidade, a MetroEntrance monta a boca da estação em volta
## dela; num bioma futuro, a mesma parada pode ser um teleférico.
##
## Convenção (igual à do PortalShell): a FRENTE é a face +Z. Na frente fica a
## ENTRADA (EntryArea): pisar nela abre o painel de linhas (quem está no grupo
## "transit_panel"). O painel só abre de novo depois que o jogador sai da
## entrada (senão, fechar com Esc reabriria na hora).
##
## Quem chega por outra parada aparece no ponto de saída (get_exit_transform),
## um pouco à frente da entrada e virado para fora.
##
## Quem cria preenche stop_name, color, order e detail ANTES de adicionar à cena.

## Tamanho da entrada (largura, altura, profundidade) e a distância dela até a parada.
const ENTRY_SIZE: Vector3 = Vector3(1.6, 2.4, 1.4)
const ENTRY_OFFSET: float = 1.0
## O ponto de chegada fica fora da entrada, a esta distância da parada.
const EXIT_DISTANCE: float = 3.2

## Nome da estação ("RPG e Fantasia", "Central"...).
var stop_name: String = ""
## Cor da linha (o néon do bairro).
var color: Color = Color.WHITE
## Ordem na lista de linhas (menor primeiro).
var order: int = 0
## Linha de baixo no painel ("57 jogos").
var detail: String = ""

var _entry: Area3D
## true = pisar na entrada abre o painel; false = espera o jogador sair.
var _armed: bool = true


func _ready() -> void:
	add_to_group("transit_stop")
	_entry = Area3D.new()
	_entry.name = "EntryArea"
	_entry.collision_layer = 0
	_entry.collision_mask = 2  # o jogador
	_entry.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ENTRY_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, ENTRY_SIZE.y / 2.0, ENTRY_OFFSET)
	_entry.add_child(shape)
	add_child(_entry)
	_entry.body_entered.connect(_on_body_entered)
	_entry.body_exited.connect(_on_body_exited)

	# Alvo "olhável": olhar para a parada mostra o nome dela no HUD.
	var look := Area3D.new()
	look.name = "LookArea"
	look.collision_layer = 4
	look.collision_mask = 0
	look.monitoring = false
	var look_shape := CollisionShape3D.new()
	var look_box := BoxShape3D.new()
	look_box.size = Vector3(1.4, 3.0, 1.0)
	look_shape.shape = look_box
	look_shape.position = Vector3(0.0, 1.5, 0.0)
	look.add_child(look_shape)
	add_child(look)


## Onde chega quem vem de outra parada: à frente da entrada, virado para fora.
func get_exit_transform() -> Transform3D:
	var front := global_basis.z
	front.y = 0.0
	front = front.normalized()
	var spot := global_position + front * EXIT_DISTANCE
	# teleport_to vira o jogador para -Z do alvo: -Z = para fora da parada.
	return Transform3D(Basis.looking_at(front), spot)


## O ponto do meio da entrada (para os testes "pisarem" nela).
func get_entry_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.1, ENTRY_OFFSET)


func is_armed() -> bool:
	return _armed


func get_look_info() -> Dictionary:
	return {"label": "METRÔ", "label_color": color, "title": "Estação " + stop_name,
			"detail": "entre para escolher a linha", "accent": color}


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not _armed:
		return
	for panel in get_tree().get_nodes_in_group("transit_panel"):
		if panel.has_method("open_for") and panel.open_for(self):
			_armed = false  # só reabre depois de sair da entrada
			return


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_armed = true
