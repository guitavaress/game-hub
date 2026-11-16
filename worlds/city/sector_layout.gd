class_name SectorLayout
extends RefCounted
## Planta da cidade em SETORES (Fase 15.3): cada bairro ganha uma fatia que vai
## da praça até a borda. Só contas, nenhum nó. A mesma lista dá sempre a
## mesma planta (empates se decidem por x e depois por z).
##
## Como funciona, em poucas palavras:
##   1. o tamanho: R é o menor anel em que cabem todos os quarteirões;
##   2. a borda (as 8R células do anel R) é repartida primeiro, em trechos
##      contíguos e proporcionais: assim todo bairro tem um pedaço da borda;
##   3. a cunha de cada bairro são as células cujo centro cai entre os limites
##      do seu trecho (vistos da praça);
##   4. o território nasce no trecho de borda e cresce por vizinhança, dando
##      preferência à própria cunha: assim é sempre uma área contínua;
##   5. os quarteirões crescem de dentro para fora a partir da célula do
##      território mais perto da praça; o resto vira vaga, perto da borda;
##   6. se um bairro ficar cercado sem lugar, R cresce e a conta recomeça.
##
## O bairro cresce com as horas (Fase 19.9): cada bairro pode ter um NÍVEL (0 a
## 3, do LibraryStats.district_levels). O nível não dá prédio: dá TERRITÓRIO.
## O bairro passa a "pedir" mais células do que tem quarteirões (a demanda).
## A demanda entra só no passo 4, DEPOIS que todo bairro já tem o lugar dos
## seus quarteirões: o território a mais sai das células que iam virar vagas
## (a folga do anel), e quem fica sem célula livre por perto para de crescer.
## Assim, com ou sem horas (revisão de risco da 19.9):
##   - o anel R é o mesmo (a mureta e o metrô não mudam);
##   - a partilha da borda e as cunhas são as mesmas (a montanha e o mirante,
##     que seguem a cunha e a borda do bairro, ficam iguais);
##   - nenhum bairro perde o lugar dos quarteirões.
## Os quarteirões continuam seguindo os jogos; o que sobra vira vaga. Sem
## nível (ou tudo 0), a conta é a de antes.

## Folga para comparar ângulos (uma célula exatamente em cima do limite).
const ANGLE_EPSILON: float = 1e-6
## Quantos anéis a mais a conta tenta antes de desistir (o teste exige até 2).
const MAX_EXTRA_RINGS: int = 8
## Quanto território a mais cada nível de horas pede (19.9), em quartos dos
## quarteirões do bairro: nível 1 = +25%, 2 = +50%, 3 = +75%, e no mínimo uma
## vaga por nível (um bairro de 1 quarteirão no nível 3 ganha 3 vagas).
const LEVEL_GROWTH_QUARTERS: int = 1
## O maior nível que a conta aceita.
const MAX_LEVEL: int = 3
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CORNERS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## A planta: um setor por entrada de "counts" (quarteirões por bairro), na
## mesma ordem. Contagem 0 mantém o lugar, com um setor vazio. "focus" é o
## índice do bairro cuja fatia deve ficar centrada no norte (-1 = nenhum).
## "levels" (19.9) é o nível de horas de cada bairro, na mesma ordem (vazio ou
## faltando = 0): mais nível, mais território (veja demands).
static func plan(counts: Array[int], focus: int = -1, levels: Array[int] = []) -> Array[DistrictSector]:
	var wanted: Array[int] = demands(counts, levels)
	# O anel sai dos quarteirões, e não da demanda: as horas não aumentam a cidade.
	var base: int = base_ring(counts)
	if base == 0:
		return _empty_plan(counts.size())
	for ring: int in range(base, base + MAX_EXTRA_RINGS + 1):
		var result: Array[DistrictSector] = _plan_with_ring(counts, wanted, focus, ring)
		if not result.is_empty():
			if ring > base + 2:
				push_warning("SectorLayout: a planta precisou crescer %d anéis" % (ring - base))
			return result
	# Não deve acontecer; se acontecer, a cidade ainda monta (em anéis).
	push_error("SectorLayout: nenhuma planta coube; usando os anéis")
	return CityLayout.ring_plan(counts)


## Quantas células cada bairro pede (19.9): os quarteirões, mais o território
## do nível de horas (LEVEL_GROWTH_QUARTERS). Bairro sem quarteirão pede 0
## (mesmo com nível); sem nível, a demanda é a própria contagem.
@warning_ignore("integer_division")
static func demands(counts: Array[int], levels: Array[int] = []) -> Array[int]:
	var result: Array[int] = []
	for i: int in counts.size():
		var count: int = maxi(counts[i], 0)
		var level: int = clampi(levels[i], 0, MAX_LEVEL) if i < levels.size() else 0
		var extra: int = 0
		if count > 0 and level > 0:
			# Arredonda para cima: (count * level * quartos) / 4.
			extra = maxi(level, (count * level * LEVEL_GROWTH_QUARTERS + 3) / 4)
		result.append(count + extra)
	return result


## O anel da borda antes de qualquer crescimento: o menor R em que cabem todos
## os quarteirões (4R² + 4R células) e em que cada bairro tem 1 célula de borda.
static func base_ring(counts: Array[int]) -> int:
	var total: int = 0
	var districts: int = 0
	for count: int in counts:
		if count > 0:
			total += count
			districts += 1
	if total == 0:
		return 0
	var ring: int = 1
	while 4 * ring * ring + 4 * ring < total or 8 * ring < districts:
		ring += 1
	return ring


static func _empty_plan(size: int) -> Array[DistrictSector]:
	var result: Array[DistrictSector] = []
	for i: int in size:
		result.append(DistrictSector.new())
	return result


## Uma tentativa com a borda no anel "ring". Devolve vazio se faltar lugar.
## "counts" (os quarteirões) repartem a borda, dão as cunhas e o lugar garantido;
## "wanted" (demands) é até onde cada bairro cresce depois, se houver lugar.
@warning_ignore("integer_division")
static func _plan_with_ring(counts: Array[int], wanted: Array[int], focus: int, ring: int) -> Array[DistrictSector]:
	# Só os bairros com quarteirões entram na conta; "active" guarda o índice original.
	var active: Array[int] = []
	var sizes: Array[int] = []
	var claims: Array[int] = []
	for i: int in counts.size():
		if counts[i] > 0:
			active.append(i)
			sizes.append(counts[i])
			claims.append(wanted[i])
	var border: Array[Vector2i] = CityLayout.ring_cells(ring)
	var slots: int = border.size()
	var quotas: Array[int] = _border_quotas(sizes, slots)

	# Onde começa o trecho de cada bairro na borda (índice em "border").
	var starts: Array[int] = []
	var next_start: int = 0
	for quota: int in quotas:
		starts.append(next_start)
		next_start += quota
	var focus_k: int = active.find(focus)
	if focus_k >= 0:
		# Gira o anel: o meio do trecho do foco cai na célula norte (índice 0).
		var shift: int = -(quotas[focus_k] / 2) - starts[focus_k]
		for k: int in starts.size():
			starts[k] = posmod(starts[k] + shift, slots)

	# Limites da cunha: o ponto entre a última célula de um trecho e a primeira do próximo.
	var wedges: Array[Vector2] = []
	for k: int in active.size():
		var start_angle: float = _boundary_angle(border, starts[k])
		var width: float = TAU
		if active.size() > 1:
			var end_angle: float = _boundary_angle(border, starts[k] + quotas[k])
			width = fposmod(end_angle - start_angle, TAU)
		wedges.append(Vector2(start_angle, start_angle + width))

	# Todas as células dos anéis 1..R, de dentro para fora e em ordem horária.
	var cells: Array[Vector2i] = []
	for r: int in range(1, ring + 1):
		cells.append_array(CityLayout.ring_cells(r))
	# A cunha "prefere" as células cujo centro cai entre os seus limites.
	var preferred: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		preferred[cell] = _wedge_of(cell, wedges)
	var bisectors: Array[float] = []
	for wedge: Vector2 in wedges:
		bisectors.append((wedge.x + wedge.y) / 2.0)
	var owner: Dictionary[Vector2i, int] = _claim_territories(cells, border, preferred, sizes, claims, bisectors)
	if owner.is_empty():
		return []

	var territories: Array = []
	for k: int in active.size():
		territories.append([] as Array[Vector2i])
	for cell: Vector2i in cells:
		territories[owner[cell]].append(cell)

	var result: Array[DistrictSector] = _empty_plan(counts.size())
	for k: int in active.size():
		var territory: Array[Vector2i] = territories[k]
		var bisector: float = bisectors[k]
		var sector: DistrictSector = result[active[k]]
		sector.wedge = wedges[k]
		sector.blocks = _grow(territory, sizes[k], bisector)
		# Território: os quarteirões e depois as vagas (por anel, depois por ângulo).
		sector.territory = sector.blocks.duplicate()
		for cell: Vector2i in territory:
			if not sector.blocks.has(cell):
				sector.territory.append(cell)
	return result


## Quantas células de borda cada bairro recebe: proporcional aos quarteirões,
## pelo maior resto; quem ficaria sem nenhuma recebe 1 de quem tem mais.
@warning_ignore("integer_division")
static func _border_quotas(sizes: Array[int], slots: int) -> Array[int]:
	var total: int = 0
	for size: int in sizes:
		total += size
	var quotas: Array[int] = []
	var remainders: Array[int] = []
	var used: int = 0
	for size: int in sizes:
		# Conta inteira, para não depender de arredondamento: cota = size * slots / total.
		quotas.append(size * slots / total)
		remainders.append(size * slots % total)
		used += quotas[-1]
	var order: Array = range(sizes.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return remainders[a] > remainders[b] or (remainders[a] == remainders[b] and a < b))
	for i: int in slots - used:
		quotas[order[i]] += 1
	for k: int in quotas.size():
		if quotas[k] > 0:
			continue
		var donor: int = 0
		for j: int in quotas.size():
			if quotas[j] >= quotas[donor]:
				donor = j  # empate: o de índice maior cede
		quotas[donor] -= 1
		quotas[k] = 1
	return quotas


## Ângulo do ponto entre a célula "index - 1" e a célula "index" da borda.
static func _boundary_angle(border: Array[Vector2i], index: int) -> float:
	var before: Vector2i = border[posmod(index - 1, border.size())]
	var after: Vector2i = border[posmod(index, border.size())]
	return CityLayout.clockwise_angle((Vector2(before) + Vector2(after)) / 2.0)


## A cunha que contém o centro da célula: a de início mais próximo antes dele,
## no sentido horário. Em cima de um limite, fica com a cunha que começa ali.
static func _wedge_of(cell: Vector2i, wedges: Array[Vector2]) -> int:
	var angle: float = CityLayout.clockwise_angle(Vector2(cell))
	var best: int = 0
	var best_distance: float = INF
	for k: int in wedges.size():
		var distance: float = fposmod(angle - wedges[k].x, TAU)
		if distance > TAU - ANGLE_EPSILON:
			distance = 0.0
		if distance < best_distance:
			best_distance = distance
			best = k
	return best


## Reparte as células entre os bairros sem deixar pedaço solto: cada território
## nasce no seu trecho de borda e só cresce por vizinhança (lado ou canto).
##   1. quem ainda não tem lugar para todos os quarteirões cresce primeiro (o mais
##      apertado na frente), preferindo células da própria cunha, depois as mais
##      perto da praça e da bissetriz;
##   2. (19.9) com horas, quem tem nível cresce do mesmo jeito até a demanda
##      ("claims"), só em células ainda livres; quem não acha célula livre
##      encostada para de crescer (o lugar dos quarteirões já está garantido);
##   3. o que sobra vai, em ondas da borda para a praça, para o dono da cunha
##      (ou, se ele não encostar na célula, para o vizinho com mais contatos).
## Uma cunha fina demais não perde o bairro: ele vira uma mancha encostada na
## borda. Devolve vazio se algum bairro ficar cercado sem lugar no passo 1.
static func _claim_territories(cells: Array[Vector2i], border: Array[Vector2i],
		preferred: Dictionary[Vector2i, int], sizes: Array[int], claims: Array[int],
		bisectors: Array[float]) -> Dictionary[Vector2i, int]:
	var owner: Dictionary[Vector2i, int] = {}
	var claimed: Array[int] = []
	claimed.resize(sizes.size())
	for cell: Vector2i in border:
		owner[cell] = preferred[cell]
		claimed[preferred[cell]] += 1

	# 1. Primeiro, lugar para todos os quarteirões (igual com ou sem horas).
	if not _claim_up_to(cells, owner, claimed, preferred, sizes, bisectors, true):
		return {}  # cercado pelos vizinhos
	# 2. Depois, o território a mais das horas, só no que ainda está livre.
	if claims != sizes:
		_claim_up_to(cells, owner, claimed, preferred, claims, bisectors, false)

	# 3. Por fim, as sobras (vagas), uma onda por vez.
	while owner.size() < cells.size():
		var wave: Dictionary[Vector2i, int] = {}
		for cell: Vector2i in cells:
			if owner.has(cell):
				continue
			var contacts: Dictionary[int, int] = _contacts(cell, owner)
			if contacts.is_empty():
				continue
			var chosen: int = preferred[cell]
			if not contacts.has(chosen):
				chosen = -1
				for j: int in contacts:
					if chosen < 0 or contacts[j] > contacts[chosen] or (contacts[j] == contacts[chosen] and j < chosen):
						chosen = j
			wave[cell] = chosen
		if wave.is_empty():
			push_error("SectorLayout: células sem vizinho")
			return {}
		owner.merge(wave)
	return owner


## Faz cada território crescer, uma célula por vez, até "targets" células: o
## mais apertado (a maior fração que falta) cresce primeiro, preferindo
## células da própria cunha, depois as mais perto da praça e da bissetriz.
## "strict": quem fica cercado faz a conta falhar (devolve falso); sem ele,
## quem fica cercado só para de crescer.
static func _claim_up_to(cells: Array[Vector2i], owner: Dictionary[Vector2i, int], claimed: Array[int],
		preferred: Dictionary[Vector2i, int], targets: Array[int], bisectors: Array[float], strict: bool) -> bool:
	var stuck: Dictionary[int, bool] = {}
	while true:
		var k: int = -1
		var tightest: float = 0.0
		for j: int in targets.size():
			if stuck.has(j):
				continue
			var missing: float = float(targets[j] - claimed[j]) / targets[j]
			if missing > tightest:  # empate: o de índice menor
				tightest = missing
				k = j
		if k < 0:
			return true
		var best: Vector2i
		var best_key: Array = []
		for cell: Vector2i in cells:
			if owner.has(cell) or _contacts(cell, owner).get(k, 0) == 0:
				continue
			var key: Array = [0 if preferred[cell] == k else 1] + _seed_key(cell, bisectors[k])
			if best_key.is_empty() or _is_before(key, best_key):
				best = cell
				best_key = key
		if best_key.is_empty():
			if strict:
				return false
			stuck[k] = true
			continue
		owner[best] = k
		claimed[k] += 1
	return true


## Quantos vizinhos (lado ou canto) a célula tem em cada território.
static func _contacts(cell: Vector2i, owner: Dictionary[Vector2i, int]) -> Dictionary[int, int]:
	var contacts: Dictionary[int, int] = {}
	for step: Vector2i in NEIGHBORS:
		var other: Vector2i = cell + step
		if owner.has(other):
			contacts[owner[other]] = contacts.get(owner[other], 0) + 1
	return contacts


## Os "count" quarteirões do bairro, crescendo dentro do território. O primeiro
## (o pórtico) é a célula mais perto da praça; os seguintes, sempre vizinhos de
## um já escolhido, preferem o anel menor (de dentro para fora), depois encostar
## de lado (e não só pelo canto), depois a bissetriz.
static func _grow(territory: Array[Vector2i], count: int, bisector: float) -> Array[Vector2i]:
	var gate: Vector2i = territory[0]
	for cell: Vector2i in territory:
		if _is_before(_seed_key(cell, bisector), _seed_key(gate, bisector)):
			gate = cell
	var blocks: Array[Vector2i] = [gate]
	var taken: Dictionary[Vector2i, bool] = {gate: true}
	while blocks.size() < count:
		var best: Vector2i
		var best_key: Array = []
		for cell: Vector2i in territory:
			if taken.has(cell):
				continue
			var touches_side: bool = false
			var touches_corner: bool = false
			for step: Vector2i in SIDES:
				touches_side = touches_side or taken.has(cell + step)
			for step: Vector2i in CORNERS:
				touches_corner = touches_corner or taken.has(cell + step)
			if not touches_side and not touches_corner:
				continue
			var key: Array = _seed_key(cell, bisector)
			key.insert(1, 0 if touches_side else 1)
			if best_key.is_empty() or _is_before(key, best_key):
				best = cell
				best_key = key
		if best_key.is_empty():
			break  # o território é contínuo, então isto não deve acontecer
		blocks.append(best)
		taken[best] = true
	return blocks


## Ordem de preferência: anel menor, mais perto da bissetriz, x, z.
static func _seed_key(cell: Vector2i, bisector: float) -> Array:
	var off_axis: float = absf(wrapf(CityLayout.clockwise_angle(Vector2(cell)) - bisector, -PI, PI))
	return [CityLayout.ring_of(cell), off_axis, cell.x, cell.y]


## Compara duas chaves campo a campo (a primeira diferença decide).
static func _is_before(a: Array, b: Array) -> bool:
	for i: int in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
