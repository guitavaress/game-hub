extends Node
## AppConfig: lê as preferências do usuário em user://config.cfg (autoload).
##
## Onde fica o arquivo: %APPDATA%\Godot\app_userdata\Game Hub\config.cfg
## (no editor: menu Projeto > Abrir Pasta de Dados do Usuário).
##
## Na primeira vez, o arquivo é criado com comentários explicando cada opção.
## Depois disso o hub só LÊ o arquivo, para nunca apagar o que você escreveu.
## A única exceção: seções novas (de fases novas do projeto) são ACRESCENTADAS
## no fim do arquivo, sem mexer no resto.

const CONFIG_PATH: String = "user://config.cfg"

## Seção dos amigos (fase 5). Fica separada para poder ser acrescentada em
## arquivos criados antes dela existir.
const STEAM_SECTION_TEXT: String = """
[steam]

; Chave da Steam Web API, para ver seus amigos na cidade.
; Pegue em https://steamcommunity.com/dev/apikey (em "domínio", escreva localhost)
; e cole entre as aspas. Ex.: web_api_key="0123ABCD..."
; SEGREDO: não mostre para ninguém. Se vazar, apague a chave na mesma página.
web_api_key=""

; Seu SteamID64 (17 dígitos). Vazio = descobrir sozinho pela Steam.
steam_id=""

; false = não mostrar amigos (e não avisar sobre a chave).
friends_enabled=true
"""

## Conteúdo inicial do arquivo (linhas com ";" são comentários).
const DEFAULT_CONFIG_TEXT: String = """; Configuração do Game Hub.
; Edite com o Bloco de Notas, salve e abra o hub de novo.
; Linhas que começam com ";" são comentários.

[library]

; Apps que NÃO devem virar prédio (App IDs separados por vírgula).
; 431960 = Wallpaper Engine, 993090 = Lossless Scaling
excluded_app_ids=[431960, 993090]

[categories]

; Forçar o bairro de um jogo:  App ID: "bairro"
; Bairros: esportes, rpg, sobrevivencia, simulacao, estrategia,
;          acao, cartas, aventura, casual, outros
; Exemplo (Stardew Valley no bairro de RPG):  overrides={ 413150: "rpg" }
overrides={}
""" + STEAM_SECTION_TEXT

## Problema ao ler o arquivo, para o HUD avisar ("" = tudo certo).
var load_problem: String = ""

var _config := ConfigFile.new()


func _ready() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_write_default_file()
	elif not FileAccess.get_file_as_string(CONFIG_PATH).contains("[steam]"):
		_append_to_file(STEAM_SECTION_TEXT)

	var error := _config.load(CONFIG_PATH)
	if error != OK:
		push_warning("Não consegui ler %s (erro %d). Usando valores padrão." % [CONFIG_PATH, error])
		load_problem = "O config.cfg tem um erro de digitação (confira aspas e colchetes). " \
				+ "Por enquanto, estou usando as opções padrão."
		_config.parse(DEFAULT_CONFIG_TEXT)


## Chave da Steam Web API ("" = não configurada). É SEGREDO: nunca imprima.
func get_web_api_key() -> String:
	return str(_config.get_value("steam", "web_api_key", "")).strip_edges()


## SteamID64 escrito pelo usuário ("" = descobrir sozinho).
func get_steam_id_override() -> String:
	return str(_config.get_value("steam", "steam_id", "")).strip_edges()


func are_friends_enabled() -> bool:
	return bool(_config.get_value("steam", "friends_enabled", true))


## App IDs que o usuário escondeu da cidade.
func get_excluded_app_ids() -> Array[int]:
	var result: Array[int] = []
	var value: Variant = _config.get_value("library", "excluded_app_ids", [])
	if value is Array:
		for item: Variant in value:
			result.append(int(item))
	return result


## Bairro forçado pelo usuário para esse jogo ("" = nenhum).
func get_category_override(app_id: int) -> String:
	var overrides: Variant = _config.get_value("categories", "overrides", {})
	if not overrides is Dictionary:
		return ""
	# Aceita tanto  413150: "rpg"  quanto  "413150": "rpg".
	for key: Variant in overrides:
		if int(key) == app_id:
			return String(overrides[key]).strip_edges().to_lower()
	return ""


func _write_default_file() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não consegui criar %s." % CONFIG_PATH)
		return
	file.store_string(DEFAULT_CONFIG_TEXT)
	file.close()


## Acrescenta texto no FIM do arquivo, sem mexer no que já está lá.
func _append_to_file(text: String) -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ_WRITE)
	if file == null:
		push_warning("Não consegui atualizar %s." % CONFIG_PATH)
		return
	file.seek_end()
	file.store_string(text)
	file.close()
