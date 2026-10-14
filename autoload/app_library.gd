extends Node
## AppLibrary: a lista dos programas instalados (autoload), a "estante de apps".
##
## Igual ao SteamLibrary, mas para apps comuns (navegador, terminal...). Quem
## sabe ler o sistema é o DesktopApps (em autoload/platform/); aqui ficam a
## ordem, as categorias e os apps que o usuário escondeu no config.cfg.
##
## Ordem: os abertos pelo hub mais recentemente primeiro, depois por nome.

## Categorias da estante: id → nome na tela. "diversos" é a que sobra.
const CATEGORIES: Dictionary[String, String] = {
	"internet": "Internet",
	"escritorio": "Escritório",
	"midia": "Mídia",
	"graficos": "Gráficos",
	"programacao": "Programação",
	"sistema": "Sistema",
	"jogos": "Jogos",
	"diversos": "Outros",
}

## Categoria do XDG → id daqui. A ordem importa: a primeira que casar vale
## (um editor com "Utility;Development" é de Programação, não de Outros).
const XDG_TO_CATEGORY: Array[Array] = [
	["Game", "jogos"],
	["Development", "programacao"],
	["Graphics", "graficos"],
	["Office", "escritorio"],
	["AudioVideo", "midia"], ["Audio", "midia"], ["Video", "midia"],
	["Network", "internet"], ["WebBrowser", "internet"],
	["System", "sistema"], ["Settings", "sistema"], ["TerminalEmulator", "sistema"],
]

## Quantos "abertos recentemente" guardamos.
const MAX_RECENT: int = 30

## A lista mudou (carregou de novo).
signal apps_changed

## Os apps visíveis, já na ordem da estante.
var apps: Array[DesktopApp] = []

var _recent: Array[String] = []


func _ready() -> void:
	reload()


## Lê o sistema de novo e refaz a lista.
func reload() -> void:
	set_apps(DesktopApps.list_apps())


## Define a lista (a leitura do sistema, ou uma de teste): tira os ocultos do
## config.cfg e ordena.
func set_apps(all_apps: Array[DesktopApp]) -> void:
	_recent = AppConfig.get_recent_apps()
	apps = sorted_apps(all_apps, AppConfig.get_hidden_apps(), _recent)
	apps_changed.emit()


func get_app(id: String) -> DesktopApp:
	for app in apps:
		if app.id == id:
			return app
	return null


## Os apps de uma categoria ("" = todos), na ordem da estante.
func apps_in(category: String = "") -> Array[DesktopApp]:
	if category == "":
		return apps.duplicate()
	var result: Array[DesktopApp] = []
	for app in apps:
		if category_of(app) == category:
			result.append(app)
	return result


## Os ids das categorias que têm pelo menos um app, na ordem de CATEGORIES.
func used_categories() -> Array[String]:
	var result: Array[String] = []
	for id in CATEGORIES:
		if not apps_in(id).is_empty():
			result.append(id)
	return result


## Marca o app como aberto agora: ele sobe para o começo da estante e fica gravado.
func mark_opened(id: String) -> void:
	_recent.erase(id)
	_recent.push_front(id)
	if _recent.size() > MAX_RECENT:
		_recent.resize(MAX_RECENT)
	AppConfig.set_recent_apps(_recent)
	set_apps(apps)


## O id da categoria da estante (de CATEGORIES) para um app.
static func category_of(app: DesktopApp) -> String:
	for pair in XDG_TO_CATEGORY:
		if pair[0] in app.categories:
			return pair[1]
	return "diversos"


## Tira os ocultos e ordena: os de "recent" primeiro (na ordem dela), depois
## os outros por nome. Não muda a lista de entrada.
static func sorted_apps(all_apps: Array[DesktopApp], hidden: Array[String], recent: Array[String]) -> Array[DesktopApp]:
	var result: Array[DesktopApp] = []
	for app in all_apps:
		if not app.id in hidden:
			result.append(app)
	result.sort_custom(func(a: DesktopApp, b: DesktopApp) -> bool:
		var ra := recent.find(a.id)
		var rb := recent.find(b.id)
		if ra != rb:
			if ra == -1 or rb == -1:
				return rb == -1
			return ra < rb
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return result
