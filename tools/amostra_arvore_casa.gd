extends "res://tools/capturar_casa.gd"
## A amostra do pinheiro do Blender PELA JANELA DA CASA (Fase 19.2). A janela é
## um retrato do mundo (WindowView): com os pinheiros do bairro trocados (só na
## memória) pelo TreeModel, o retrato mostra os novos. Rode COM JANELA:
##
##   godot --path . -s tools/amostra_arvore_casa.gd -- <pasta> [jogos] [horas] [qualidade] [tema] [vista] [modo]
##
## Os seis primeiros são os do capturar_casa.gd; "modo": hoje (padrão) | novo.
## Os arquivos levam o modo (cabana-novo_janela_13h.png).

const SAMPLE: GDScript = preload("res://tools/amostra_arvore.gd")


func _prepare(city: Node, home: Node3D) -> void:
	var args := OS.get_cmdline_user_args()
	var mode := String(args[6]) if args.size() > 6 else "hoje"
	if mode == "novo":
		for district: String in ["rpg"]:
			var trees: TreeModel = SAMPLE.swap_pines(city, district)
			print("Modo novo: pinheiros do bairro %s trocados: %s" % [district, trees != null])
	_mode_label = mode
	# O retrato da janela é refeito com as árvores novas.
	var view: Node = home.call("get_window_view") if home.has_method("get_window_view") else null
	if view != null:
		view.call("on_point_changed")
