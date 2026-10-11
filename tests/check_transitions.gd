extends SceneTree
## Teste das curvas nas transições (Fase 11.1): nada de tween linear na UI.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fade = root.get_node("ScreenFade")

	print("\n== cortina: fade_out começa devagar (EASE_IN) ==")
	fade.set_amount(0.0)
	fade.fade_out(0.4)
	await create_timer(0.2).timeout
	var meio: float = fade.get_amount()
	print("   no meio do fade_out: %.2f" % meio)
	_check("fade_out no meio está abaixo de 0,5", meio < 0.5)
	await create_timer(0.4).timeout
	_check("fade_out termina em 1", is_equal_approx(fade.get_amount(), 1.0))

	print("\n== cortina: fade_in começa rápido (EASE_OUT) ==")
	fade.fade_in(0.4)
	await create_timer(0.2).timeout
	meio = fade.get_amount()
	print("   no meio do fade_in: %.2f" % meio)
	_check("fade_in no meio está abaixo de 0,5 (já clareou mais da metade)", meio < 0.5)
	await create_timer(0.4).timeout
	_check("fade_in termina em 0", is_equal_approx(fade.get_amount(), 0.0))

	print("\n== vinheta da porta ==")
	_check("progresso 0,5 fecha menos que 0,5", fade.door_charge.vignette_amount(0.5) < 0.5)
	_check("extremos ficam como estão", is_equal_approx(fade.door_charge.vignette_amount(0.0), 0.0)
		and is_equal_approx(fade.door_charge.vignette_amount(1.0), 1.0))
	fade.set_door_charge(0.5, "Teste", Color.WHITE)
	var amount: float = fade.door_charge._vignette_material.get_shader_parameter("amount")
	_check("a vinheta recebe a curva, o anel o progresso", amount < 0.5 and is_equal_approx(fade.door_charge.get_progress(), 0.5))
	fade.set_door_charge(0.0)

	print("\n== cartão do que se olha ==")
	var hud: Node = load("res://ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_look_info({"title": "Alvo"})
	_check("começa transparente", hud._look_card.visible and hud._look_card.modulate.a < 0.2)
	await create_timer(0.3).timeout
	_check("chega a 1", is_equal_approx(hud._look_card.modulate.a, 1.0))
	var bottom: float = hud._look_card.offset_bottom
	hud.set_look_info({"title": "Outro alvo"})
	_check("trocar de alvo não repete a animação", is_equal_approx(hud._look_card.modulate.a, 1.0)
		and is_equal_approx(hud._look_card.offset_bottom, bottom))
	hud.set_look_info({})
	_check("ao sumir, o cartão já conta como escondido", not hud.is_look_card_shown())
	await create_timer(0.25).timeout
	_check("e depois fica invisível", not hud._look_card.visible)

	print("\n== aviso: sai subindo ==")
	var toast: Node = load("res://ui/toast.gd").create("Teste", "", 0, 5.0)
	root.add_child(toast)
	await process_frame
	toast.close()
	await create_timer(0.1).timeout
	_check("no meio da saída o painel já subiu", toast._panel.position.y < 0.0)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
