class_name WindowViewPoint
extends Marker3D
## O PONTO DE VISTA que um mundo oferece às janelas (Fase 17.3).
##
## O mundo (a cidade, por exemplo) põe um destes onde a vista é bonita, virado
## para onde se olha (o -Z do nó, como uma câmera), e só quando já está pronto
## para ser visto: o ponto existir quer dizer "pode tirar o retrato". Quem tira
## o retrato é o WindowView, que não conhece nenhum mundo: ele só procura um
## nó no grupo WindowView.POINT_GROUP.
##
## Ao entrar e ao sair da cena, o ponto avisa as janelas (grupo WindowView.GROUP)
## no fim do quadro, para elas tirarem o retrato ou voltarem à vista de reserva.

## Aproximação da vista (1 = como a olho nu; 1,2 = tudo 20% maior na janela,
## como uma lente mais fechada). Quem escolhe o enquadramento é o mundo.
@export_range(1.0, 3.0) var zoom: float = 1.0
## Camadas de render que o MUNDO não quer no retrato (máscara de bits). Serve
## para o que só faz sentido para quem anda na rua, como letreiros flutuantes
## que, vistos de longe pela janela, parecem etiquetas de mapa. Na rua, nada muda.
@export_flags_3d_render var hidden_layers: int = 0


func _enter_tree() -> void:
	add_to_group(WindowView.POINT_GROUP)
	_tell_windows()


func _exit_tree() -> void:
	remove_from_group(WindowView.POINT_GROUP)
	_tell_windows()


func _tell_windows() -> void:
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, WindowView.GROUP, &"on_point_changed")
