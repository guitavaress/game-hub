extends Node
## AppConfig: lê as preferências do usuário em user://config.cfg (autoload).
##
## Onde fica o arquivo: %APPDATA%\Godot\app_userdata\Game Hub\config.cfg
## (no editor: menu Projeto > Abrir Pasta de Dados do Usuário).
##
## Na primeira vez, o arquivo é criado com comentários explicando cada opção.
## Depois disso o hub mexe no arquivo só de dois jeitos, sem nunca apagar o que
## você escreveu:
##   - seções novas (de fases novas do projeto) são ACRESCENTADAS no fim;
##   - o menu de pausa troca SÓ a linha da opção mudada (os comentários ficam).
##
## Quando uma opção muda pelo menu, o sinal settings_changed avisa quem liga
## para ela (a cidade troca a qualidade, o relógio troca a hora...).

## Uma opção mudou (seção e nome, como no arquivo).
signal settings_changed(section: String, key: String)

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

## Seção de áudio (fase 6), acrescentada do mesmo jeito.
const AUDIO_SECTION_TEXT: String = """
[audio]

; Volumes de 0.0 (mudo) a 1.0 (máximo).
master_volume=0.8
; Passos, portal, avisos.
effects_volume=1.0
; Sons dos bairros (motor, cartas, vento...).
ambience_volume=0.8
"""

## Seção de vídeo (P2: menu de pausa), acrescentada do mesmo jeito.
const VIDEO_SECTION_TEXT: String = """
[video]

; Qualidade do 3D: "alta" (tudo ligado), "media" (sem reflexos na tela) ou
; "leve" (sem reflexos nem sombreamento extra e 3D em 50%: para PCs fracos).
quality="alta"
; Hora da cidade: "relogio" (segue o relógio do PC), "dia" ou "noite".
time_of_day="relogio"
"""

## Seções novas e o texto de cada uma: se o arquivo não tiver alguma, ela é
## acrescentada no fim.
const ADDED_SECTIONS: Dictionary[String, String] = {
	"steam": STEAM_SECTION_TEXT,
	"audio": AUDIO_SECTION_TEXT,
	"video": VIDEO_SECTION_TEXT,
}

## Valores aceitos para as opções de vídeo.
const QUALITY_LEVELS: Array[String] = ["leve", "media", "alta"]
const TIME_OF_DAY_MODES: Array[String] = ["relogio", "dia", "noite"]

## Canais de áudio (default_bus_layout.tres) e a opção de volume de cada um.
const VOLUME_KEYS: Dictionary[String, String] = {
	"Master": "master_volume",
	"Efeitos": "effects_volume",
	"Ambiente": "ambience_volume",
}

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
""" + STEAM_SECTION_TEXT + AUDIO_SECTION_TEXT + VIDEO_SECTION_TEXT

## Problema ao ler o arquivo, para o HUD avisar ("" = tudo certo).
var load_problem: String = ""

var _config := ConfigFile.new()


func _ready() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_write_default_file()
	else:
		var current_text := FileAccess.get_file_as_string(CONFIG_PATH)
		for section in ADDED_SECTIONS:
			if not current_text.contains("[%s]" % section):
				_append_to_file(ADDED_SECTIONS[section])

	var error := _config.load(CONFIG_PATH)
	if error != OK:
		push_warning("Não consegui ler %s (erro %d). Usando valores padrão." % [CONFIG_PATH, error])
		# Primeira linha = título do aviso; o resto = o que fazer.
		load_problem = "O config.cfg tem um erro de digitação\n" \
				+ "Confira aspas e colchetes. Por enquanto, uso as opções padrão."
		_config.parse(DEFAULT_CONFIG_TEXT)
	_apply_volumes()
	GraphicsQuality.apply_to_viewport(get_tree().root, get_quality())


## Aplica os volumes do config.cfg nos canais de áudio.
func _apply_volumes() -> void:
	for bus_name in VOLUME_KEYS:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus == -1:
			continue
		var volume := get_volume(bus_name)
		AudioServer.set_bus_mute(bus, volume <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))


# --- Som e vídeo -------------------------------------------------------------

## Volume de um canal ("Master", "Efeitos" ou "Ambiente"), de 0.0 a 1.0.
func get_volume(bus_name: String) -> float:
	return clampf(float(_config.get_value("audio", VOLUME_KEYS.get(bus_name, ""), 1.0)), 0.0, 1.0)


## Muda o volume na hora. save = false só aplica (enquanto o controle está
## sendo arrastado); save = true também grava no config.cfg.
func set_volume(bus_name: String, volume: float, save: bool = true) -> void:
	if not VOLUME_KEYS.has(bus_name):
		return
	var value := snappedf(clampf(volume, 0.0, 1.0), 0.01)
	if save:
		_set_option("audio", VOLUME_KEYS[bus_name], value)
	else:
		_config.set_value("audio", VOLUME_KEYS[bus_name], value)
	_apply_volumes()


## Qualidade do 3D: "leve", "media" ou "alta".
func get_quality() -> String:
	var level := str(_config.get_value("video", "quality", "alta")).strip_edges().to_lower()
	return level if level in QUALITY_LEVELS else "alta"


func set_quality(level: String) -> void:
	if not level in QUALITY_LEVELS:
		return
	_set_option("video", "quality", level)
	GraphicsQuality.apply_to_viewport(get_tree().root, level)


## Hora da cidade: "relogio" (relógio do PC), "dia" ou "noite".
func get_time_of_day() -> String:
	var mode := str(_config.get_value("video", "time_of_day", "relogio")).strip_edges().to_lower()
	return mode if mode in TIME_OF_DAY_MODES else "relogio"


func set_time_of_day(mode: String) -> void:
	if mode in TIME_OF_DAY_MODES:
		_set_option("video", "time_of_day", mode)


## Chave da Steam Web API ("" = não configurada). É SEGREDO: nunca imprima.
func get_web_api_key() -> String:
	return str(_config.get_value("steam", "web_api_key", "")).strip_edges()


## SteamID64 escrito pelo usuário ("" = descobrir sozinho).
func get_steam_id_override() -> String:
	return str(_config.get_value("steam", "steam_id", "")).strip_edges()


func are_friends_enabled() -> bool:
	return bool(_config.get_value("steam", "friends_enabled", true))


## Grava as opções de amigos (pelo menu de pausa). A chave é SEGREDO: vai só
## para o config.cfg deste PC, nunca para a tela nem para o log.
func set_friends_settings(api_key: String, steam_id: String, enabled: bool) -> void:
	_set_option("steam", "web_api_key", api_key.strip_edges(), false)
	_set_option("steam", "steam_id", steam_id.strip_edges(), false)
	_set_option("steam", "friends_enabled", enabled)


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


## Muda uma opção: na memória, no arquivo (só a linha dela) e avisa.
func _set_option(section: String, key: String, value: Variant, notify: bool = true) -> void:
	_config.set_value(section, key, value)
	_write_option_to_file(section, key, value)
	if notify:
		settings_changed.emit(section, key)


## Troca no arquivo SÓ a linha "chave=valor" da opção, dentro da seção certa.
## Se a opção não existir, ela entra logo abaixo do nome da seção; se a seção
## não existir, ela entra no fim. Os comentários ficam como estão.
func _write_option_to_file(section: String, key: String, value: Variant) -> void:
	var line_text := "%s=%s" % [key, var_to_str(value)]
	var lines := FileAccess.get_file_as_string(CONFIG_PATH).split("\n")
	var section_line := -1
	var current := ""
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			if current == section:
				section_line = i
		elif current == section and (line.begins_with(key + "=") or line.begins_with(key + " =")):
			lines[i] = line_text
			_save_lines(lines)
			return
	if section_line == -1:
		lines.append_array(["", "[%s]" % section, "", line_text])
	else:
		lines.insert(section_line + 1, line_text)
	_save_lines(lines)


func _save_lines(lines: PackedStringArray) -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não consegui gravar %s." % CONFIG_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()


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
