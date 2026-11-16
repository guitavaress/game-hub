class_name DayCycleSpec
extends Resource
## O DIA como uma lista de momentos (Fase 19.4): madrugada, nascer do sol,
## manhã, meio-dia, tarde, pôr do sol, anoitecer e noite. Cada momento tem a
## hora e os valores do céu (veja DayMoment). O DayNight pergunta sample(hora)
## e recebe a mistura do momento de antes com o de depois.
##
## O arquivo (profiles/day_cycle.tres) é gerado por tools/gerar_ciclo_do_dia.gd.
## Quem acende à noite (postes, janelas...) NÃO olha esta lista: segue o
## DayNight.night_amount(hora), que não mudou.

## Os momentos, em ordem de hora (de 0 a 24). Depois do último vem o primeiro
## do dia seguinte.
@export var moments: Array[DayMoment] = []


## Como a cidade fica nesta hora (0 a 24; passa de 24 dá a volta). Dentro da
## parada de um momento, devolve o próprio momento (não altere); entre dois,
## um momento novo, misturado em linha reta.
func sample(hour: float) -> DayMoment:
	if moments.is_empty():
		return DayMoment.new()
	var index: int = _index_at(hour)
	var current: DayMoment = moments[index]
	if moments.size() == 1:
		return current
	var next: DayMoment = moments[(index + 1) % moments.size()]
	var since: float = fposmod(hour - current.hour, 24.0)
	if since <= current.hold_hours:
		return current
	var span: float = fposmod(next.hour - current.hour, 24.0)
	var moving: float = span - current.hold_hours
	if moving <= 0.0:
		return next
	return DayMoment.mix(current, next, clampf((since - current.hold_hours) / moving, 0.0, 1.0))


## O momento em que se está ou o último que passou (ex.: 10h é "manha").
func moment_at(hour: float) -> DayMoment:
	if moments.is_empty():
		return DayMoment.new()
	return moments[_index_at(hour)]


## O que está errado na lista (vazio = tudo certo): momento vazio, fora de
## ordem, id repetido, ou uma parada que passa do momento seguinte.
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if moments.is_empty():
		found.append("a lista está vazia")
		return found
	var ids: Array[String] = []
	for i: int in moments.size():
		var moment: DayMoment = moments[i]
		if moment == null:
			found.append("o momento %d está vazio" % i)
			continue
		if moment.id.is_empty() or ids.has(moment.id):
			found.append("o momento %d está sem id ou com id repetido" % i)
		ids.append(moment.id)
		if moment.hour < 0.0 or moment.hour >= 24.0:
			found.append("%s: a hora fica fora de 0 a 24" % moment.id)
		if i > 0 and moments[i - 1] != null and moment.hour <= moments[i - 1].hour:
			found.append("%s: fora de ordem" % moment.id)
		if moments.size() > 1 and moments[(i + 1) % moments.size()] != null:
			var span: float = fposmod(moments[(i + 1) % moments.size()].hour - moment.hour, 24.0)
			if moment.hold_hours >= span:
				found.append("%s: a parada passa do momento seguinte" % moment.id)
	return found


## O último momento cuja hora já chegou (antes do primeiro, o último da lista,
## que é o da véspera).
func _index_at(hour: float) -> int:
	var h: float = fposmod(hour, 24.0)
	var index: int = moments.size() - 1
	for i: int in moments.size():
		if moments[i].hour <= h:
			index = i
	return index
