class_name DeskLayout
extends RefCounted
## O ARRANJO DAS JANELAS nos monitores da mesa (Fase 14.29). GDScript puro, sem
## nós nem compositor: o AppSessions passa as áreas úteis e as janelas, e
## pergunta onde cada uma fica. É o "dwindle" do Hyprland, simplificado:
##   - 1 janela ocupa a área útil inteira;
##   - 2 ficam lado a lado;
##   - 3: a primeira à esquerda, e as outras duas empilhadas à direita;
##   - no máximo MAX_PER_OUTPUT por monitor;
##   - fechar arruma de novo (as que sobram mantêm a ordem);
##   - tela cheia: uma janela por monitor ocupa a área útil toda por cima das outras;
##   - foco por direção, inclusive de um monitor para o outro (os monitores
##     ficam lado a lado, na ordem das saídas).

const MAX_PER_OUTPUT := 3

## Quantas janelas cabem em cada monitor, no total.
var _areas: Array[Rect2i] = []
## Os ids das janelas de cada saída, na ordem em que entraram.
var _windows: Array = []
## A janela em tela cheia de cada saída (0 = nenhuma).
var _fullscreen: Array[int] = []


## Define as áreas úteis (uma por saída). Janelas de saídas que sumiram vão
## para a última que sobrou (ou ficam sem lugar, se couber menos). Devolve os
## ids das janelas que não couberam em lugar nenhum.
func set_areas(areas: Array[Rect2i]) -> Array[int]:
	var homeless: Array[int] = []
	while _windows.size() > areas.size():
		var orphans: Array = _windows.pop_back()
		_fullscreen.pop_back()
		for id: int in orphans:
			if areas.is_empty() or _count(areas.size() - 1) >= MAX_PER_OUTPUT:
				homeless.append(id)
			else:
				_windows[areas.size() - 1].append(id)
	while _windows.size() < areas.size():
		_windows.append([])
		_fullscreen.append(0)
	_areas = areas.duplicate()
	return homeless


func output_count() -> int:
	return _areas.size()


func set_area(output: int, area: Rect2i) -> void:
	if output >= 0 and output < _areas.size():
		_areas[output] = area


func windows_on(output: int) -> Array[int]:
	var list: Array[int] = []
	if output >= 0 and output < _windows.size():
		list.assign(_windows[output])
	return list


## Quantas janelas ainda cabem, somando os monitores.
func free_slots() -> int:
	return _areas.size() * MAX_PER_OUTPUT - window_count()


func window_count() -> int:
	var total := 0
	for list: Array in _windows:
		total += list.size()
	return total


## A saída da janela (-1 se não existe).
func output_of(id: int) -> int:
	for o in _windows.size():
		if id in _windows[o]:
			return o
	return -1


## Põe a janela na saída `preferred`; se estiver cheia, na mais perto que tiver
## vaga. Devolve a saída usada, ou -1 se todas estão cheias.
func add(id: int, preferred: int) -> int:
	if _areas.is_empty() or output_of(id) >= 0:
		return output_of(id)
	preferred = clampi(preferred, 0, _areas.size() - 1)
	for distance in _areas.size():
		for candidate in [preferred - distance, preferred + distance]:
			if candidate >= 0 and candidate < _areas.size() and _count(candidate) < MAX_PER_OUTPUT:
				_windows[candidate].append(id)
				return candidate
	return -1


## Tira a janela e devolve a saída onde ela estava (-1 se não existia).
func remove(id: int) -> int:
	var o := output_of(id)
	if o < 0:
		return -1
	_windows[o].erase(id)
	if _fullscreen[o] == id:
		_fullscreen[o] = 0
	return o


## Manda a janela para outro monitor. false se não existe, já está lá ou está cheio.
func move_to(id: int, output: int) -> bool:
	var from := output_of(id)
	if from < 0 or output < 0 or output >= _areas.size() or output == from or _count(output) >= MAX_PER_OUTPUT:
		return false
	remove(id)
	_windows[output].append(id)
	return true


## Liga ou desliga a tela cheia da janela. Devolve se ficou em tela cheia.
func toggle_fullscreen(id: int) -> bool:
	var o := output_of(id)
	if o < 0:
		return false
	_fullscreen[o] = 0 if _fullscreen[o] == id else id
	return _fullscreen[o] == id


func fullscreen_of(output: int) -> int:
	return _fullscreen[output] if output >= 0 and output < _fullscreen.size() else 0


## Onde cada janela da saída fica (id -> Rect2i, em pixels da saída). Em tela
## cheia, a janela ocupa a área útil toda e as outras ficam onde estavam
## (escondidas embaixo dela).
@warning_ignore("integer_division")
func rects(output: int) -> Dictionary:
	var result := {}
	if output < 0 or output >= _areas.size():
		return result
	var area := _areas[output]
	var ids: Array = _windows[output]
	match ids.size():
		0:
			pass
		1:
			result[ids[0]] = area
		2:
			var half := area.size.x / 2
			result[ids[0]] = Rect2i(area.position, Vector2i(half, area.size.y))
			result[ids[1]] = Rect2i(area.position + Vector2i(half, 0), Vector2i(area.size.x - half, area.size.y))
		_:
			var half := area.size.x / 2
			var top := area.size.y / 2
			result[ids[0]] = Rect2i(area.position, Vector2i(half, area.size.y))
			var right_x := area.position.x + half
			result[ids[1]] = Rect2i(Vector2i(right_x, area.position.y), Vector2i(area.size.x - half, top))
			result[ids[2]] = Rect2i(Vector2i(right_x, area.position.y + top), Vector2i(area.size.x - half, area.size.y - top))
	var full := _fullscreen[output]
	if full != 0 and result.has(full):
		result[full] = area
	return result


## A janela vizinha de `id` na direção `direction` (Vector2i.LEFT, RIGHT, UP,
## DOWN), inclusive em outro monitor. 0 se não há. Janelas escondidas por uma
## tela cheia não contam.
func neighbor(id: int, direction: Vector2i) -> int:
	var from := _global_rect(id)
	if from.size == Vector2i.ZERO:
		return 0
	var center := Vector2(from.position) + Vector2(from.size) / 2.0
	var best := 0
	var best_score := INF
	for o in _windows.size():
		for other: int in _windows[o]:
			if other == id or _hidden(other):
				continue
			var rect := _global_rect(other)
			var delta := Vector2(rect.position) + Vector2(rect.size) / 2.0 - center
			var along := delta.x * direction.x + delta.y * direction.y
			if along <= 0.0:
				continue
			var across := absf(delta.x * direction.y) + absf(delta.y * direction.x)
			var score := along + across * 2.0
			if score < best_score:
				best_score = score
				best = other
	return best


func _count(output: int) -> int:
	return _windows[output].size()


## A janela está escondida embaixo de uma tela cheia da mesma saída?
func _hidden(id: int) -> bool:
	var o := output_of(id)
	return o >= 0 and _fullscreen[o] != 0 and _fullscreen[o] != id


## O retângulo da janela no "mundo dos monitores": as saídas lado a lado, na ordem.
func _global_rect(id: int) -> Rect2i:
	var o := output_of(id)
	if o < 0:
		return Rect2i()
	var rect: Rect2i = rects(o).get(id, Rect2i())
	var x := 0
	for i in o:
		x += _areas[i].position.x + _areas[i].size.x
	rect.position.x += x
	return rect
