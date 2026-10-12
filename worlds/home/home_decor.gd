class_name HomeDecor
extends RefCounted
## O ENFEITE de um tema da casa (Fase 13): os móveis de enfeite e as luminárias
## que mudam de um tema para outro (no loft: tapete, sofá, mesinha, abajur e os
## pendentes). Cada tema tem o seu script, que estende este e preenche build().
## O perfil do tema diz qual script usar (HomeProfile.decor_script), como o
## enfeite dos bairros (DistrictProfile.props_script).
##
## O enfeite não é um nó: as peças entram direto na casa ("target"), para a
## casa poder refazer tudo ao trocar de tema.
##
## Convenção: as mesmas da casa (origem no chão, no meio da sala; o norte, -Z,
## é a parede da janela).

## Onde as peças entram (a casa).
var target: Node3D
## O perfil do tema (cores das lâmpadas, marca de passos...).
var profile: HomeProfile


## Monta o enfeite. Cada tema escreve o seu.
func build() -> void:
	pass


## Caixa com material e, se "solid", colisão, já dentro da casa.
func add_box(box_name: String, box_size: Vector3, center: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	return make_box(target, box_name, box_size, center, material, solid, profile.footstep)


## Põe um nó qualquer (luz, malha) dentro da casa.
func add_node(node: Node3D) -> Node3D:
	target.add_child(node)
	return node


## Caixa com material e, se "solid", colisão (camada 1, como o chão e as
## paredes). "footstep" é a marca que o jogador lê para o som dos passos
## ("" = nenhuma). Usada pela casa, pelos enfeites e pelos móveis.
static func make_box(parent: Node3D, box_name: String, box_size: Vector3, center: Vector3, material: Material,
		solid: bool = true, footstep: String = "") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box_size
		shape.shape = box_shape
		body.add_child(shape)
		if not footstep.is_empty():
			body.set_meta("footstep", footstep)
		mesh.add_child(body)
	return mesh
