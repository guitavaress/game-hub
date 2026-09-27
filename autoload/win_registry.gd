class_name WinRegistry
extends RefCounted
## Ajudante para ler valores do Registro do Windows.
##
## NÃO é um autoload: as funções são "static", então dá para chamar
## WinRegistry.read_string(...) de qualquer script, sem instanciar nada.
##
## Por baixo, roda o comando do Windows:  reg query <chave> /v <valor>
## e lê o texto que ele imprime, que tem este formato:
##
##   HKEY_CURRENT_USER\Software\Valve\Steam
##       SteamPath    REG_SZ    c:/program files (x86)/steam


## Lê um valor de texto (REG_SZ). Devolve "" se não existir.
static func read_string(key: String, value_name: String) -> String:
	var result := _query(key, value_name)
	return result.get("data", "")


## Lê um número (REG_DWORD). Devolve "fallback" se não existir.
## Ex.: RunningAppID aparece como "0x0" ou "0x248a44"; aqui vira 0 ou 2394692.
static func read_dword(key: String, value_name: String, fallback: int = -1) -> int:
	var result := _query(key, value_name)
	if result.get("type", "") != "REG_DWORD":
		return fallback
	return String(result["data"]).hex_to_int()


## Roda o "reg query" e devolve {"type": "REG_SZ", "data": "..."} ou {} se falhar.
static func _query(key: String, value_name: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute("reg", ["query", key, "/v", value_name], output)
	if exit_code != 0 or output.is_empty():
		return {}

	# Procura a linha:  <espaços> NomeDoValor <espaços> REG_TIPO <espaços> dado
	var regex := RegEx.create_from_string(
			"^\\s*" + _escape_regex(value_name) + "\\s+(REG_[A-Z_]+)\\s+(.*?)\\s*$")
	for line: String in String(output[0]).split("\n"):
		var found := regex.search(line.strip_edges(false, true))
		if found:
			return {"type": found.get_string(1), "data": found.get_string(2)}
	return {}


static func _escape_regex(text: String) -> String:
	var escaped := ""
	for character in text:
		if "\\^$.|?*+()[]{}".contains(character):
			escaped += "\\"
		escaped += character
	return escaped
