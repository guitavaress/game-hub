extends Node
## AppConfig: lê as preferências do usuário em user://config.cfg (autoload).
##
## Onde fica o arquivo: %APPDATA%\Godot\app_userdata\Game Hub\config.cfg
## (no editor: menu Projeto > Abrir Pasta de Dados do Usuário).
##
## Na primeira vez, o arquivo é criado com comentários explicando cada opção.
## Depois disso o hub só LÊ o arquivo, para nunca apagar o que você escreveu.

const CONFIG_PATH: String = "user://config.cfg"

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
"""

var _config := ConfigFile.new()


func _ready() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_write_default_file()
	var error := _config.load(CONFIG_PATH)
	if error != OK:
		push_warning("Não consegui ler %s (erro %d). Usando valores padrão." % [CONFIG_PATH, error])
		_config.parse(DEFAULT_CONFIG_TEXT)


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
