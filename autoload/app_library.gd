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
## O ícone de um app acabou de ficar pronto (pedido com request_icon).
signal icon_ready(app_id: String)

## Lado do ícone na memória: PNGs maiores encolhem; SVG é desenhado neste tamanho.
const ICON_SIZE: int = 256

## Os apps visíveis, já na ordem da estante.
var apps: Array[DesktopApp] = []

var _recent: Array[String] = []
## Ícones já carregados (id do app → textura, ou null se não achou imagem).
var _icons: Dictionary[String, Texture2D] = {}
## Ids com carregamento em andamento.
var _loading: Dictionary[String, bool] = {}


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


## O ícone do app, ou null se ainda não carregou (ou se ele não tem imagem).
## Na primeira chamada começa a carregar numa thread; o icon_ready avisa.
func get_icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	request_icon(id)
	return null


## Já tentamos carregar esse ícone (mesmo que não tenha achado imagem)?
func has_icon_result(id: String) -> bool:
	return _icons.has(id)


## Começa a carregar o ícone numa thread (se ainda não foi nem está sendo).
func request_icon(id: String) -> void:
	if _icons.has(id) or _loading.has(id):
		return
	var app := get_app(id)
	if app == null:
		return
	_loading[id] = true
	# Método com bind, e não função anônima: uma lambda que usa o "self" e roda
	# em thread corrompe a memória ao fechar a Godot (visto na 14.3).
	WorkerThreadPool.add_task(_load_icon_task.bind(id, app.icon_name))


## Roda numa thread: acha o arquivo, lê a imagem e entrega para a thread principal.
func _load_icon_task(id: String, icon_name: String) -> void:
	var image := load_icon_image(DesktopApps.find_icon(icon_name))
	_icon_loaded.call_deferred(id, image)


func _icon_loaded(id: String, image: Image) -> void:
	_loading.erase(id)
	_icons[id] = ImageTexture.create_from_image(image) if image != null else null
	icon_ready.emit(id)


## Lê um PNG ou SVG e devolve uma imagem de no máximo ICON_SIZE de lado
## (null se o arquivo não abre). Roda bem numa thread.
static func load_icon_image(path: String) -> Image:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if path.get_extension().to_lower() == "svg":
		var svg := FileAccess.get_file_as_string(path)
		if image.load_svg_from_string(svg, 1.0) != OK:
			return null
		var side := maxi(image.get_width(), image.get_height())
		if side > 0 and side != ICON_SIZE:
			image = Image.new()
			if image.load_svg_from_string(svg, float(ICON_SIZE) / side) != OK:
				return null
	elif image.load(path) != OK:
		return null
	if image.is_empty():
		return null
	var big := maxi(image.get_width(), image.get_height())
	if big > ICON_SIZE:
		var factor := float(ICON_SIZE) / big
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	return image


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
