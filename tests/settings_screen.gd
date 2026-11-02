extends RefCounted
## Uma tela 3D de teste com o SettingsView dentro (e a aba Casa), no lugar onde
## estava o monitor do computador antes da 14.25. As configurações agora moram
## no menu de pausa; vários testes ainda precisam de uma Screen3D de verdade com
## uma interface clicável, então montam esta.

var screen: Screen3D
var settings: SettingsView
var home_view: HomeSettingsView


## Cria a tela na casa, na posição do monitor do meio da mesa.
static func install(home: Node3D, with_home_tab: bool = true) -> RefCounted:
	var fixture = load("res://tests/settings_screen.gd").new()
	var middle: Screen3D = home.get_node("ComputerDesk").get_screen()
	var spot := middle.global_transform
	fixture.settings = SettingsView.new()
	fixture.settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if with_home_tab:
		fixture.home_view = HomeSettingsView.new()
		fixture.settings.add_page("Casa", fixture.home_view)
	var quit := HubTheme.button("Sair do hub")  # o rodapé do foco, como no monitor antigo
	quit.name = "QuitButton"
	fixture.settings.set_footer_controls([quit] as Array[Control])
	var background := PanelContainer.new()
	background.theme = HubTheme.get_theme()
	background.theme_type_variation = &"HubScreen"
	var column := VBoxContainer.new()
	column.add_child(fixture.settings)
	column.add_child(quit)
	background.add_child(column)
	fixture.screen = Screen3D.new()
	fixture.screen.name = "TestScreen"
	fixture.screen.screen_name = "Computador"
	fixture.screen.detail = "Configurações"
	fixture.screen.screen_size = ComputerDesk.SCREEN_SIZE
	fixture.screen.resolution = ComputerDesk.SCREEN_RESOLUTION
	fixture.screen.set_content(background)
	fixture.screen.focus_changed.connect(func(focused: bool) -> void:
		if focused:
			fixture.settings.refresh()
			fixture.settings.grab_tab_focus()
		else:
			fixture.settings.save_pending()
			fixture.settings.drop_focus())
	home.add_child(fixture.screen)
	home._put_on_interior_layer(fixture.screen)
	fixture.screen.global_transform = spot
	middle.get_parent().remove_child(middle)  # o monitor sem sinal sai, para não atrapalhar o olhar
	middle.free()
	return fixture
