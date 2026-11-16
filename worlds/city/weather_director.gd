class_name WeatherDirector
extends Node
## O TEMPO da cidade (Fase 19.6): um só para o mundo todo. Ele decide se está
## limpo, nublado, com chuva fraca ou com chuva forte, quanto dura cada um e
## como passa de um para o outro (devagar, sem pulo). Ele não desenha nada:
##   - o céu fecha pelo DayNight (set_weather_overlay: menos sol, mais névoa);
##   - o chão da cidade molha e seca aos poucos (CityDecor.set_ground_wetness);
##   - cada lugar com clima (grupo GROUP, ex.: o DistrictWeather de cada
##     bairro) recebe set_weather(estado, força) e mostra do jeito dele: chuva
##     na cidade, neve e nevasca na montanha, poeira no deserto.
## Quando uma passagem termina, ele avisa weather_changed (a cidade repassa à
## janela da casa, que refaz o retrato com o tempo novo).
##
## A FORÇA vai de 0 a 1: 0 = nada cai, 0,5 = chuva fraca, 1 = chuva forte. No
## meio de uma passagem ela fica entre os dois tempos.
##
## O sorteio é determinístico: a semente sai da data e da hora da cidade quando
## ela abre (seed_for), então a mesma hora do mesmo dia dá o mesmo tempo (os
## testes e as capturas repetem). Depois, o tempo anda pelo relógio de verdade
## (e não pelo da cidade: com "Hora: dia" fixa, o tempo ainda muda).
##
## A opção "Clima" do menu (AppConfig.get_weather) escolhe: "dinamico" (padrão,
## o sorteio) ou um tempo fixo ("limpo" é o "sempre limpo"). Para testar:
##   --clima-rapido      o tempo anda 10 vezes mais rápido (cada tempo dura
##                       um ou dois minutos, a passagem uns 6 s);
##   --clima=<modo>      fixa o modo só nesta vez (ex.: --clima=chuva_forte),
##                       sem gravar no config.cfg.
## Rodando um script de teste ou ferramenta (-s), o padrão é "limpo": a
## bateria não pode depender do dia em que roda. As ferramentas fixam o tempo
## com force.

## Uma passagem terminou: o tempo agora é este (um dos STATES).
signal weather_changed(state: String)

## Quem mostra o tempo (set_weather(estado: String, força: float)).
const GROUP: StringName = &"city_weather"
## Quem só precisa de dois números, e não do tempo inteiro: quanto o céu fechou
## (set_weather_cover(0 a 1); a casa, para o sol que entra pela janela
## enfraquecer junto, revisão da 19.6) e quanto chove (set_weather_rain(a
## força, 0 a 1); a casa, para a chuva no vidro da janela, Fase 19.6.1).
const COVER_GROUP: StringName = &"weather_cover"
## Os tempos. cover: quanto o céu fecha (0 a 1); strength: a força da chuva;
## minutes: quanto dura (mínimo, máximo); next: a chance de cada tempo seguinte
## (sempre um vizinho: do limpo não se vai direto à chuva forte).
const STATES: Dictionary = {
	"limpo": {"cover": 0.0, "strength": 0.0, "minutes": Vector2(10.0, 20.0),
			"next": {"nublado": 1.0}},
	"nublado": {"cover": 0.45, "strength": 0.0, "minutes": Vector2(4.0, 8.0),
			"next": {"limpo": 0.5, "chuva_fraca": 0.5}},
	"chuva_fraca": {"cover": 0.55, "strength": 0.5, "minutes": Vector2(3.0, 6.0),
			"next": {"nublado": 0.6, "chuva_forte": 0.4}},
	"chuva_forte": {"cover": 0.9, "strength": 1.0, "minutes": Vector2(2.0, 4.0),
			"next": {"chuva_fraca": 1.0}},
}
## A chance do tempo com que a cidade abre.
const START_CHANCES: Dictionary = {"limpo": 0.55, "nublado": 0.25, "chuva_fraca": 0.15, "chuva_forte": 0.05}
## Quanto dura a passagem de um tempo para o outro (s). Trocar no menu é mais
## rápido.
const PASSAGE_SECONDS: float = 60.0
const MENU_PASSAGE_SECONDS: float = 4.0
## O chão: quanto chega a molhar em cada força (chuva fraca 0,6, forte 1) e
## quantos segundos leva para molhar por inteiro, e para secar.
const WET_AT_LIGHT: float = 0.6
const WET_SECONDS: float = 20.0
const DRY_SECONDS: float = 60.0
## Os argumentos de teste (veja o começo do arquivo).
const FAST_ARG: String = "--clima-rapido"
const FAST_FACTOR: float = 10.0
const MODE_ARG: String = "--clima="
## Menor mudança que vale reenviar ao céu e ao chão (cada envio refaz a luz).
const PUBLISH_STEP: float = 0.01

## O relógio da cidade (o céu fecha por ele). Pode faltar (testes).
var day_night: DayNight
## Quantas vezes mais rápido o tempo anda (1 = normal; --clima-rapido = 10).
var time_scale: float = 1.0

var _rng := RandomNumberGenerator.new()
var _started: bool = false
## O modo de agora ("dinamico" ou um tempo fixo) e o forçado pelas
## ferramentas ("" = nenhum; ganha do modo).
var _mode: String = "dinamico"
var _forced: String = ""
## O modo do argumento --clima= ("" = o do menu).
var _arg_mode: String = ""
## A passagem: o céu e a força de onde ela sai, o tempo para onde vai, quanto
## já andou (0 a 1; 1 = o tempo assentou) e quanto ela dura.
var _from_cover: float = 0.0
var _from_strength: float = 0.0
var _state: String = "limpo"
var _passage: float = 1.0
var _passage_seconds: float = PASSAGE_SECONDS
## Segundos até o próximo sorteio (só no dinâmico, com o tempo assentado).
var _remaining: float = 0.0
## Os valores de agora e os últimos enviados.
var _cover: float = 0.0
var _strength: float = 0.0
var _wet: float = 0.0
var _sent_cover: float = -1.0
var _sent_strength: float = -1.0
var _sent_state: String = ""
var _sent_wet: float = -1.0
## Se este tempo já mexeu no chão (para devolver seco ao sair).
var _touched_ground: bool = false


## A semente do sorteio para a data e a hora da cidade dadas: a mesma hora do
## mesmo dia dá o mesmo tempo.
static func seed_for(date: Dictionary, hour: float) -> int:
	return hash("%04d-%02d-%02d %02d" % [int(date.get("year", 0)), int(date.get("month", 0)),
			int(date.get("day", 0)), floori(hour)])


## Os modos da opção "Clima" (o primeiro é o padrão).
static func modes() -> Array[String]:
	var list: Array[String] = ["dinamico"]
	for state: String in STATES:
		list.append(state)
	return list


func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in args:
		if arg == FAST_ARG:
			time_scale = FAST_FACTOR
		elif arg.begins_with(MODE_ARG) and arg.trim_prefix(MODE_ARG) in modes():
			_arg_mode = arg.trim_prefix(MODE_ARG)
	if not _started:
		var hour := day_night.current_hour() if day_night != null else 12.0
		start(seed_for(Time.get_date_dict_from_system(), hour))
	AppConfig.settings_changed.connect(_on_settings_changed)
	var mode := _current_mode()
	# Rodando um teste ou uma ferramenta (-s), abre limpo (salvo o argumento);
	# o menu ainda pode mudar depois.
	if _arg_mode.is_empty() and Engine.get_main_loop().get_script() != null:
		mode = "limpo"
	_set_mode(mode, true)


func _exit_tree() -> void:
	# O chão é da cidade toda (um material só): volta seco.
	if _touched_ground:
		CityDecor.set_ground_wetness(0.0)
		_touched_ground = false
	if is_instance_valid(day_night):
		day_night.set_weather_overlay(0.0)


func _process(delta: float) -> void:
	step(delta * time_scale)


## Começa o sorteio com a semente dada: o primeiro tempo (pela START_CHANCES),
## já no meio dele, com o céu e o chão como se estivesse assim havia tempo.
func start(seed_value: int) -> void:
	_started = true
	_rng.seed = seed_value
	var first := _pick(START_CHANCES)
	_remaining = _duration(first) * _rng.randf_range(0.2, 1.0)
	_settle(first)
	_wet = wet_for(_strength)


## Anda o tempo em "seconds" segundos (o _process chama a cada quadro; um
## teste pode chamar direto, com passos grandes).
func step(seconds: float) -> void:
	if _passage < 1.0:
		_passage = minf(_passage + seconds / _passage_seconds, 1.0)
		if _passage >= 1.0:
			weather_changed.emit(_state)
	elif _effective_mode() == "dinamico":
		_remaining -= seconds
		if _remaining <= 0.0:
			var next := _pick(STATES[_state]["next"])
			_remaining = _duration(next)
			_begin(next, PASSAGE_SECONDS)
	_update_values()
	var wet_target := wet_for(_strength)
	_wet = move_toward(_wet, wet_target, seconds / (WET_SECONDS if _wet < wet_target else DRY_SECONDS))
	publish()


## Força um tempo na hora, com o céu e o chão já no ponto (capturas e medida).
## "" volta ao modo de antes (devagar).
func force(state: String) -> void:
	if state != "" and not STATES.has(state):
		return
	_forced = state
	if state != "":
		_settle(state)
		_wet = wet_for(_strength)
		publish()
	else:
		_remaining = 0.0  # o dinâmico sorteia de novo quanto dura o tempo de agora
		_set_mode(_mode, false)


func forced_state() -> String:
	return _forced


## O tempo de agora (o de destino, no meio de uma passagem).
func current_state() -> String:
	return _state


## A força de agora (0 a 1; veja o começo do arquivo).
func current_strength() -> float:
	return _strength


## Quanto o céu está fechado agora (0 a 1).
func current_cover() -> float:
	return _cover


func current_wetness() -> float:
	return _wet


## true no meio de uma passagem.
func is_passing() -> bool:
	return _passage < 1.0


## O modo que vale agora ("dinamico" ou um tempo).
func current_mode() -> String:
	return _effective_mode()


## Quanto o chão molha com a força dada (0 a 1).
static func wet_for(strength: float) -> float:
	return mix(strength, WET_AT_LIGHT, 1.0)


## Um valor que vale "light" na chuva fraca (força 0,5) e "heavy" na forte
## (força 1): abaixo da fraca, desce em linha reta até 0; entre as duas, passa
## em linha reta. Quem mostra o tempo usa a mesma conta (quantidade, volume).
static func mix(strength: float, light: float, heavy: float) -> float:
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.5:
		return light * strength / 0.5
	return lerpf(light, heavy, (strength - 0.5) / 0.5)


## Manda o tempo de agora ao céu, ao chão e a quem mostra o tempo. Só reenvia
## o que mudou o bastante (PUBLISH_STEP: cada envio refaz a luz ou o chão); o
## valor final de uma passagem sempre vai. Um lugar novo pede tudo de novo com
## publish(true). Fora da cena não manda nada (um teste pode simular solto).
func publish(everything: bool = false) -> void:
	if not is_inside_tree():
		return
	var settled := not is_passing()
	var layers := GraphicsQuality.rain_layers(AppConfig.get_quality())
	var cover := _cover if bool(layers.get("ceu", true)) else 0.0
	if everything or _changed(cover, _sent_cover, settled):
		_sent_cover = cover
		if is_instance_valid(day_night):
			day_night.set_weather_overlay(cover)
		get_tree().call_group(COVER_GROUP, &"set_weather_cover", cover)
	var wet := _wet if bool(layers.get("chao", true)) else 0.0
	var wet_done := _wet == wet_for(_strength)
	if (everything or _changed(wet, _sent_wet, wet_done)) and (wet > 0.0 or _touched_ground):
		_sent_wet = wet
		CityDecor.set_ground_wetness(wet)
		_touched_ground = true
	if everything or _state != _sent_state or _changed(_strength, _sent_strength, settled):
		_sent_state = _state
		_sent_strength = _strength
		get_tree().call_group(GROUP, &"set_weather", _state, _strength)
		get_tree().call_group(COVER_GROUP, &"set_weather_rain", _strength)


# --- Por dentro -------------------------------------------------------------------

## Mudou o bastante para reenviar? Parado (o valor chegou), qualquer mudança
## vale; andando, só um passo de PUBLISH_STEP.
static func _changed(value: float, sent: float, arrived: bool) -> bool:
	if value == sent:
		return false
	return arrived or sent < 0.0 or absf(value - sent) >= PUBLISH_STEP


func _current_mode() -> String:
	if not _arg_mode.is_empty():
		return _arg_mode
	return AppConfig.get_weather()


func _effective_mode() -> String:
	return _forced if not _forced.is_empty() else _mode


## Põe o modo: um tempo fixo passa a ele (devagar, a não ser na abertura); o
## dinâmico continua de onde está.
func _set_mode(mode: String, instant: bool) -> void:
	# Voltando ao dinâmico vindo de um tempo fixo, a duração é sorteada de novo
	# (revisão da 19.6: sobrava a da abertura, e a chuva forte durava 20 min).
	if mode == "dinamico" and _mode != "dinamico":
		_remaining = 0.0
	_mode = mode
	if _forced != "":
		return
	if mode != "dinamico" and (mode != _state or (instant and is_passing())):
		if instant:
			_settle(mode)
			_wet = wet_for(_strength)
			# Sem passagem não há o aviso do fim dela: avisa aqui (a janela da
			# casa refaz o retrato por ele).
			weather_changed.emit(_state)
		else:
			_begin(mode, MENU_PASSAGE_SECONDS)
	elif mode == "dinamico" and _remaining <= 0.0:
		_remaining = _duration(_state)
	_update_values()
	publish(true)


func _on_settings_changed(section: String, key: String) -> void:
	if section == "video" and key == "weather" and _arg_mode.is_empty():
		# Com o jogo pausado (o menu Esc aberto), o tempo não anda: a troca vale
		# na hora, para o céu e o chão já mudarem atrás do menu (como a "Hora").
		_set_mode(AppConfig.get_weather(), get_tree().paused)
	elif section == "video" and key == "quality":
		publish(true)


## Começa uma passagem para o tempo dado. Ela sai do céu e da força de agora:
## uma passagem no meio de outra continua dali, sem pulo.
func _begin(next: String, seconds: float) -> void:
	_from_cover = _cover
	_from_strength = _strength
	_state = next
	_passage = 0.0
	_passage_seconds = seconds


## Assenta no tempo dado, sem passagem.
func _settle(state: String) -> void:
	_state = state
	_passage = 1.0
	_from_cover = float(STATES[state]["cover"])
	_from_strength = float(STATES[state]["strength"])
	_update_values()


## O céu e a força na altura da passagem (uma curva suave entre os dois tempos).
func _update_values() -> void:
	var t := smoothstep(0.0, 1.0, _passage)
	var target: Dictionary = STATES[_state]
	_cover = lerpf(_from_cover, float(target["cover"]), t)
	_strength = lerpf(_from_strength, float(target["strength"]), t)


func _duration(state: String) -> float:
	var minutes: Vector2 = STATES[state]["minutes"]
	return _rng.randf_range(minutes.x, minutes.y) * 60.0


## Sorteia uma chave pelas chances (os valores somam 1, ou perto disso).
func _pick(chances: Dictionary) -> String:
	var roll := _rng.randf() * _total(chances)
	var last := ""
	for key: String in chances:
		last = key
		roll -= float(chances[key])
		if roll <= 0.0:
			return key
	return last


static func _total(chances: Dictionary) -> float:
	var total := 0.0
	for key: String in chances:
		total += float(chances[key])
	return total
