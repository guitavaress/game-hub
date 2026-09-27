class_name Vdf
extends RefCounted
## Leitor de arquivos VDF/ACF da Steam (o formato "KeyValues" da Valve).
##
## NÃO é um autoload: use  var dados := Vdf.parse(texto)
##
## O formato é assim:
##
##   "AppState"
##   {
##       "appid"     "2379780"
##       "name"      "Balatro"
##       "InstalledDepots"
##       {
##           ...
##       }
##   }
##
## Vira um Dictionary: {"AppState": {"appid": "2379780", "name": "Balatro", ...}}
## Todos os valores chegam como TEXTO (String); converta com int() quando precisar.
##
## Também entende:  \" e \\ dentro de aspas, comentários "//" e condições
## entre colchetes como [$WIN32] (que são ignoradas).
##
## Para ser rápido em arquivos grandes (o localconfig.vdf tem ~300 KB), o leitor
## compara CÓDIGOS das letras (unicode_at) e pula direto até a aspa de
## fechamento com find(), em vez de olhar letra por letra.

enum Token { END, TEXT, OPEN, CLOSE }

# Códigos das letras que importam.
const CHAR_TAB: int = 9
const CHAR_NEWLINE: int = 10
const CHAR_RETURN: int = 13
const CHAR_SPACE: int = 32
const CHAR_QUOTE: int = 34      # "
const CHAR_SLASH: int = 47      # /
const CHAR_BRACKET: int = 91    # [
const CHAR_BACKSLASH: int = 92  # \
const CHAR_OPEN: int = 123      # {
const CHAR_CLOSE: int = 125     # }

var _text: String = ""
var _length: int = 0
var _pos: int = 0
var _token: Token = Token.END
var _token_text: String = ""


## Transforma o texto de um arquivo VDF/ACF em Dictionary.
static func parse(text: String) -> Dictionary:
	var parser := Vdf.new()
	parser._text = text
	parser._length = text.length()
	return parser._parse_block()


## Procura uma chave ignorando maiúsculas/minúsculas (a Steam escreve "Valve"
## num arquivo e "valve" em outro). Devolve null se não achar.
static func get_ignoring_case(data: Dictionary, key: String) -> Variant:
	if data.has(key):
		return data[key]
	var lower_key := key.to_lower()
	for existing: String in data:
		if existing.to_lower() == lower_key:
			return data[existing]
	return null


## Segue um caminho de chaves (ignorando maiúsculas/minúsculas).
## Ex.: get_nested(dados, ["UserLocalConfigStore", "Software", "Valve", "Steam", "apps"])
## Devolve {} se alguma parte do caminho não existir.
static func get_nested(data: Dictionary, keys: Array[String]) -> Dictionary:
	var current: Variant = data
	for key in keys:
		if not current is Dictionary:
			return {}
		current = get_ignoring_case(current, key)
	return current if current is Dictionary else {}


## Lê pares "chave valor" (ou "chave { ... }") até achar "}" ou o fim do texto.
func _parse_block() -> Dictionary:
	var result := {}
	while true:
		_next_token()
		if _token != Token.TEXT:
			return result  # END ou CLOSE: acabou este bloco

		var key := _token_text
		_next_token()
		match _token:
			Token.TEXT:
				result[key] = _token_text
			Token.OPEN:
				result[key] = _parse_block()
			_:
				return result  # arquivo quebrado: devolve o que deu para ler
	return result


## Avança para o próximo "pedaço" do texto: um texto, "{" ou "}".
func _next_token() -> void:
	_skip_spaces_and_comments()
	if _pos >= _length:
		_token = Token.END
		return

	var character := _text.unicode_at(_pos)
	if character == CHAR_OPEN:
		_token = Token.OPEN
		_pos += 1
	elif character == CHAR_CLOSE:
		_token = Token.CLOSE
		_pos += 1
	elif character == CHAR_QUOTE:
		_token = Token.TEXT
		_token_text = _read_quoted()
	else:
		_token = Token.TEXT
		_token_text = _read_unquoted()


func _skip_spaces_and_comments() -> void:
	while _pos < _length:
		var character := _text.unicode_at(_pos)
		if character == CHAR_SPACE or character == CHAR_TAB \
				or character == CHAR_NEWLINE or character == CHAR_RETURN:
			_pos += 1
		elif character == CHAR_SLASH and _pos + 1 < _length and _text.unicode_at(_pos + 1) == CHAR_SLASH:
			# Comentário: pula até o fim da linha.
			var line_end := _text.find("\n", _pos)
			_pos = _length if line_end == -1 else line_end
		elif character == CHAR_BRACKET:
			# Condição tipo [$WIN32]: ignorada.
			var bracket_end := _text.find("]", _pos)
			_pos = _length if bracket_end == -1 else bracket_end + 1
		else:
			return


## Lê um texto entre aspas. Caminho rápido: pula direto até a próxima aspa.
## Só se houver "\" no meio (raro) é que lemos letra por letra.
func _read_quoted() -> String:
	_pos += 1  # pula a aspa de abertura
	var closing := _text.find("\"", _pos)
	if closing == -1:
		closing = _length
	var content := _text.substr(_pos, closing - _pos)
	if not content.contains("\\"):
		_pos = closing + 1
		return content
	return _read_quoted_with_escapes()


## Caminho lento: trata \" \\ \n e \t.
func _read_quoted_with_escapes() -> String:
	var result := ""
	while _pos < _length:
		var character := _text.unicode_at(_pos)
		if character == CHAR_QUOTE:
			_pos += 1  # pula a aspa de fechamento
			return result
		if character == CHAR_BACKSLASH and _pos + 1 < _length:
			_pos += 1
			match _text[_pos]:
				"n":
					result += "\n"
				"t":
					result += "\t"
				_:
					result += _text[_pos]  # \\ vira \ e \" vira "
		else:
			result += _text[_pos]
		_pos += 1
	return result


## Lê um texto sem aspas (raro), até um espaço, aspas ou chave.
func _read_unquoted() -> String:
	var start := _pos
	while _pos < _length:
		var character := _text.unicode_at(_pos)
		if character == CHAR_SPACE or character == CHAR_TAB or character == CHAR_NEWLINE \
				or character == CHAR_RETURN or character == CHAR_QUOTE \
				or character == CHAR_OPEN or character == CHAR_CLOSE:
			break
		_pos += 1
	return _text.substr(start, _pos - start)
