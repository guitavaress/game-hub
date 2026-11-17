class_name CameraBlock
extends RefCounted
## VOLUME SÓ DA CÂMERA (Fase 20.5). Há enfeites que o jogador atravessa (ou nem
## alcança), mas que a câmera da terceira pessoa não pode atravessar: a copa
## das árvores e as luminárias penduradas da casa. Sem isto, o braço da câmera
## parava dentro dos galhos, que tapavam a tela.
##
## Esses enfeites ganham um volume simples na camada de física LAYER (a 4,
## "so_camera" no project.godot). Quem bate nela é SÓ o braço da câmera do
## jogador (Player soma CameraBlock.mask() à máscara do braço). O jogador
## (máscara 1), o raio do olhar (1 e 3), os portais e o resto não a enxergam.
##
## É o mundo que põe o volume (regra 2: mundos posicionam e decoram): a árvore
## (TreeModel) e o enfeite da casa (HomeDecor) chamam make_body/add_cylinder.
##
## Camadas de física do projeto: 1 mundo, 2 jogador, 3 alvo do olhar, 4 esta.

## A camada (1 a 32). O ÚNICO lugar com este número.
const LAYER: int = 4


## A máscara (bits) da camada.
static func mask() -> int:
	return 1 << (LAYER - 1)


## Um corpo parado nesta camada, sem máscara (não procura nada; só é achado).
static func make_body(body_name: String = "CameraBlock") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = mask()
	body.collision_mask = 0
	return body


## Um cilindro em pé nesta camada, com o meio em "center" (no espaço de
## "parent"). Para as luminárias penduradas.
static func add_cylinder(parent: Node3D, body_name: String, radius: float, height: float,
		center: Vector3) -> StaticBody3D:
	var body := make_body(body_name)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	body.position = center
	parent.add_child(body)
	return body
