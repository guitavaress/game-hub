extends SceneTree
## Teste do arranjo das janelas nos monitores (Fase 14.29): DeskLayout puro, sem compositor.

var failures := 0
const AREA := Rect2i(0, 0, 1920, 1080)


func _initialize() -> void:
	var layout := DeskLayout.new()
	var areas: Array[Rect2i] = [AREA, Rect2i(0, 26, 1920, 1054), AREA]
	layout.set_areas(areas)

	print("== Abrir 1, 2 e 3 janelas ==")
	_check("uma janela ocupa a área útil (sem a barra)", layout.add(1, 1) == 1 and layout.rects(1)[1] == Rect2i(0, 26, 1920, 1054))
	layout.add(2, 1)
	_check("duas ficam lado a lado", layout.rects(1)[1] == Rect2i(0, 26, 960, 1054) and layout.rects(1)[2] == Rect2i(960, 26, 960, 1054))
	layout.add(3, 1)
	_check("a terceira divide a metade da direita, em cima e embaixo",
			layout.rects(1)[1] == Rect2i(0, 26, 960, 1054) and layout.rects(1)[2] == Rect2i(960, 26, 960, 527)
			and layout.rects(1)[3] == Rect2i(960, 553, 960, 527))
	_check("a quarta vai para o monitor vizinho mais perto (o da esquerda)", layout.add(4, 1) == 0 and layout.windows_on(0) == [4])
	_check("tudo certo na contagem", layout.window_count() == 4 and layout.free_slots() == 5)

	print("== Fechar arruma de novo ==")
	_check("fechar a do meio faz a de baixo subir", layout.remove(2) == 1 and layout.rects(1)[3] == Rect2i(960, 26, 960, 1054))
	_check("fechar uma que não existe devolve -1", layout.remove(99) == -1)

	print("== Foco por direção ==")
	layout.add(2, 1)  # de volta: ordem 1, 3, 2
	_check("da esquerda da saída 1 para a direita: a de cima", layout.neighbor(1, Vector2i.RIGHT) == 3)
	_check("da de cima para baixo: a de baixo", layout.neighbor(3, Vector2i.DOWN) == 2)
	_check("da de baixo para a esquerda: a grande", layout.neighbor(2, Vector2i.LEFT) == 1)
	_check("da grande para a esquerda: passa de monitor", layout.neighbor(1, Vector2i.LEFT) == 4)
	_check("do monitor 0 para a direita volta à da esquerda do 1", layout.neighbor(4, Vector2i.RIGHT) == 1)
	_check("sem vizinho, 0", layout.neighbor(4, Vector2i.LEFT) == 0 and layout.neighbor(3, Vector2i.UP) == 0)
	layout.add(5, 2)
	_check("da de cima da direita, para a direita: passa para o monitor 2", layout.neighbor(3, Vector2i.RIGHT) == 5)

	print("== Tela cheia ==")
	_check("liga", layout.toggle_fullscreen(3) and layout.rects(1)[3] == Rect2i(0, 26, 1920, 1054))
	_check("as outras não são alvo do foco, escondidas", layout.neighbor(4, Vector2i.RIGHT) == 3 and layout.neighbor(5, Vector2i.LEFT) == 3)
	_check("desliga", not layout.toggle_fullscreen(3) and layout.rects(1)[3] == Rect2i(960, 26, 960, 527))
	layout.toggle_fullscreen(3)
	layout.remove(3)
	_check("fechar a janela em tela cheia solta a tela cheia", layout.fullscreen_of(1) == 0)

	print("== Mover para outro monitor ==")
	_check("a 2 vai para o monitor 3 (saída 2)", layout.move_to(2, 2) and layout.output_of(2) == 2 and layout.windows_on(1) == [1])
	_check("mover para onde já está é recusado", not layout.move_to(2, 2))
	layout.add(6, 2)
	_check("o monitor cheio recusa (3 por monitor)", layout.windows_on(2).size() == 3 and not layout.move_to(1, 2))
	_check("saída que não existe é recusada", not layout.move_to(1, 7))

	print("== Tudo cheio ==")
	var full := DeskLayout.new()
	full.set_areas(areas)
	for id in 9:
		full.add(id + 1, 1)
	_check("9 janelas cabem, a 10ª não", full.free_slots() == 0 and full.add(10, 1) == -1)

	print("== Monitores que somem ==")
	var fewer: Array[Rect2i] = [AREA, AREA]
	var homeless := full.set_areas(fewer)
	_check("as da saída que sumiu não couberam (as outras duas estão cheias): todas sem lugar", homeless.size() == 3 and full.window_count() == 6)
	var smaller := DeskLayout.new()
	smaller.set_areas(areas)
	smaller.add(1, 2)
	_check("com vaga, a janela da saída que sumiu vai para a última", smaller.set_areas(fewer).is_empty() and smaller.output_of(1) == 1)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
