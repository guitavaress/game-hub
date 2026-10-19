class_name SystemSettingsView
extends VBoxContainer
## A aba "SISTEMA" do menu de pausa (Fase 14.10; veio do computador na 14.25), só onde dá (no Linux):
##   - o interruptor "Abrir o hub ao entrar no Omarchy" (liga e apaga o
##     autostart, via Autostart);
##   - o botão "Copiar a linha do atalho", para colar no bindings.lua. O hub nunca
##     escreve na config do Hyprland: o atalho é do usuário;
##   - o botão "Copiar a linha da tecla de emergência" (Fase 14.30): sentado à
##     mesa, o Hyprland fica num submap; esta tecla volta tudo ao normal.
## É uma página do SettingsView (add_page). O teclado e o controle andam pelos
## botões como no resto do SettingsView.

const SHORTCUT_HELP: String = "Para chamar o hub com %s, cole a linha abaixo no fim de ~/.config/hypr/bindings.lua e recarregue o Hyprland."
const COPIED_TEXT: String = "Linha copiada. Cole em ~/.config/hypr/bindings.lua."
const EMERGENCY_HELP: String = "Sentado à mesa, o hub fica com os atalhos do Omarchy. Cole a linha abaixo em ~/.config/hypr/bindings.lua: SUPER + SHIFT + ESC devolve os atalhos ao Hyprland mesmo se o hub travar."
const EMERGENCY_COPIED_TEXT: String = "Linha copiada. Cole em ~/.config/hypr/bindings.lua e recarregue o Hyprland."
const FAILED_TEXT: String = "Não consegui mexer no arquivo de autostart."

## Quem liga e desliga o autostart. Os testes trocam por um de pasta de exemplo.
var autostart: Autostart = Autostart.new()

var _check: CheckButton
var _copy_button: Button
var _emergency_button: Button
var _status: Label
## true enquanto o interruptor está sendo marcado (não é o usuário mexendo).
var _refreshing: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(HubTheme.label("AO ENTRAR", &"HubSection"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(HubTheme.label("Abrir o hub ao entrar no Omarchy"))
	row.add_child(HubTheme.expander())
	_check = CheckButton.new()
	_check.name = "AutostartCheck"
	_check.toggled.connect(_on_toggled)
	row.add_child(_check)
	add_child(row)

	add_child(HubTheme.label("ATALHO", &"HubSection"))
	var help := HubTheme.label(SHORTCUT_HELP % Autostart.SHORTCUT_KEY, &"HubBodyLight")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var line := HubTheme.label(autostart.shortcut_line(), &"HubBodyLight")
	line.name = "ShortcutLine"
	line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	add_child(line)
	var button_row := HBoxContainer.new()
	_copy_button = HubTheme.button("Copiar a linha do atalho")
	_copy_button.name = "CopyButton"
	_copy_button.pressed.connect(_on_copy)
	button_row.add_child(_copy_button)
	add_child(button_row)

	add_child(HubTheme.label("TECLA DE EMERGÊNCIA", &"HubSection"))
	var emergency_help := HubTheme.label(EMERGENCY_HELP, &"HubBodyLight")
	emergency_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(emergency_help)
	var emergency_line := HubTheme.label(Autostart.emergency_line(), &"HubBodyLight")
	emergency_line.name = "EmergencyLine"
	emergency_line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	add_child(emergency_line)
	var emergency_row := HBoxContainer.new()
	_emergency_button = HubTheme.button("Copiar a linha da tecla de emergência")
	_emergency_button.name = "EmergencyButton"
	_emergency_button.pressed.connect(_on_copy_emergency)
	emergency_row.add_child(_emergency_button)
	add_child(emergency_row)

	_status = HubTheme.label("", &"HubBodyLight")
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	refresh()


## Marca o interruptor como está o arquivo agora (o SettingsView chama ao mostrar a tela).
func refresh() -> void:
	_refreshing = true
	_check.set_pressed_no_signal(autostart.is_enabled())
	_refreshing = false


func _on_toggled(on: bool) -> void:
	if _refreshing:
		return
	if autostart.set_enabled(on):
		_status.text = ""
	else:
		_status.text = FAILED_TEXT
	refresh()  # mostra o que de fato ficou valendo


func _on_copy_emergency() -> void:
	DisplayServer.clipboard_set(Autostart.emergency_line())
	_status.text = EMERGENCY_COPIED_TEXT


func _on_copy() -> void:
	DisplayServer.clipboard_set(autostart.shortcut_line())
	_status.text = COPIED_TEXT
