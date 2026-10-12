extends Node
## QUAL APARELHO ESTÁ EM USO (Fase 12.7): teclado e mouse, ou controle (Xbox).
## Autoload. Guarda o último aparelho usado e avisa quando muda
## (device_changed). As dicas desenhadas na tela ("Esc", "E", "Tab", "Segure E
## para jogar") perguntam aqui o que escrever: "E" no teclado, "X" no controle.
##
## Quem usa:
##   - KeyHint (ui/key_hint.gd): teclas desenhadas que trocam sozinhas;
##   - fill("Segure {interact} para jogar"): texto corrido; o HUD preenche o
##     cartão do que se olha com isto.
##
## Só conta como "usar o controle" um botão apertado ou um analógico além de
## STICK_THRESHOLD (um analógico com folga manda eventos pequenos o tempo todo
## e faria as dicas piscarem). Mexer o mouse ou apertar uma tecla volta para o
## teclado.
##
## O mouse some enquanto o controle está em uso (com um menu aberto, o cursor
## ficaria parado em cima de um botão) e volta com o teclado ou o mouse.

signal device_changed(gamepad: bool)

## Inclinação (0 a 1) a partir da qual um analógico conta como "uso".
const STICK_THRESHOLD: float = 0.5

## As dicas: nome → [o que se escreve no teclado, o que se escreve no controle].
## Cada lado é uma lista de teclas desenhadas.
const HINTS: Dictionary[String, Array] = {
	"move": [["W", "A", "S", "D"], ["LS"]],
	"look": [["Mouse"], ["RS"]],
	"sprint": [["Shift"], ["L3"]],
	"jump": [["Espaço"], ["A"]],
	"interact": [["E"], ["X"]],
	"search": [["Tab"], ["Y"]],
	"map": [["M"], ["View"]],
	"menu": [["Esc"], ["Menu"]],
	"back": [["Esc"], ["B"]],
	"confirm": [["Enter"], ["A"]],
	"travel": [["Shift+Enter"], ["X"]],
	"nav": [["↑↓"], ["↑↓"]],
	"tabs": [["←→"], ["LB", "RB"]],
}

## A cor de cada botão do controle Xbox (as outras teclas não têm cor).
const PAD_COLORS: Dictionary[String, Color] = {
	"A": Color("6BD968"),
	"B": Color("E5534B"),
	"X": Color("4C8DFF"),
	"Y": Color("F2C14E"),
}

var _gamepad: bool = false


func _ready() -> void:
	# O hub inteiro pausa (menu, busca, jogo aberto): este nó continua ouvindo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# O sinal da janela vê o evento ANTES de qualquer painel (que pode "engolir"
	# o botão, como o B que fecha um menu).
	get_tree().root.window_input.connect(_on_window_input)


func _process(_delta: float) -> void:
	# Com o controle, o cursor do mouse fica escondido (fora de um jogo aberto
	# por fora, quando o hub dorme e o mouse é do jogo).
	if _gamepad and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not HubWindow.is_sleeping:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func is_gamepad() -> bool:
	return _gamepad


## Troca o aparelho "à mão" (os testes usam; o jogo troca sozinho pelos eventos).
func set_gamepad(on: bool) -> void:
	if on == _gamepad:
		return
	_gamepad = on
	if not on and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	device_changed.emit(on)


## As teclas desenhadas de uma dica, no aparelho de agora ("interact" → ["E"]).
func labels(hint: String) -> PackedStringArray:
	if not HINTS.has(hint):
		push_warning("Dica de tecla desconhecida: %s" % hint)
		return PackedStringArray([hint])
	return PackedStringArray(HINTS[hint][1 if _gamepad else 0])


## A cor de uma tecla do controle (transparente = sem cor, ou no teclado).
func pad_color(label: String) -> Color:
	if _gamepad and PAD_COLORS.has(label):
		return PAD_COLORS[label]
	return Color(0, 0, 0, 0)


## Troca os marcadores "{interact}" de um texto pelas teclas de agora:
## "Segure {interact} para jogar" → "Segure E para jogar" (ou "Segure X ...").
func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	for hint in HINTS:
		text = text.replace("{%s}" % hint, "".join(labels(hint)))
	return text


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		set_gamepad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_THRESHOLD:
		set_gamepad(true)
	elif event is InputEventKey and event.pressed:
		set_gamepad(false)
	elif event is InputEventMouseButton and event.pressed:
		set_gamepad(false)
	elif event is InputEventMouseMotion and event.relative.length() > 0.0:
		set_gamepad(false)
