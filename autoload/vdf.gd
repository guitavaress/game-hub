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

enum Token { END, TEXT, OPEN, CLOSE }

var _text: String = ""
var _pos: int = 0
var _token: Token = Token.END
var _token_text: String = ""


## Transforma o texto de um arquivo VDF/ACF em Dictionary.
static func parse(text: String) -> Dictionary:
	var parser := Vdf.new()
	parser._text = text
	return parser._parse_block()


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
	if _pos >= _text.length():
		_token = Token.END
		return

	var character := _text[_pos]
	if character == "{":
		_token = Token.OPEN
		_pos += 1
	elif character == "}":
		_token = Token.CLOSE
		_pos += 1
	elif character == "\"":
		_token = Token.TEXT
		_token_text = _read_quoted()
	else:
		_token = Token.TEXT
		_token_text = _read_unquoted()


func _skip_spaces_and_comments() -> void:
	while _pos < _text.length():
		var character := _text[_pos]
		if character == " " or character == "\t" or character == "\n" or character == "\r":
			_pos += 1
		elif character == "/" and _text.substr(_pos, 2) == "//":
			# Comentário: pula até o fim da linha.
			while _pos < _text.length() and _text[_pos] != "\n":
				_pos += 1
		elif character == "[":
			# Condição tipo [$WIN32]: ignorada.
			while _pos < _text.length() and _text[_pos] != "]":
				_pos += 1
			_pos += 1
		else:
			return


## Lê um texto entre aspas, tratando \" \\ \n e \t.
func _read_quoted() -> String:
	_pos += 1  # pula a aspa de abertura
	var result := ""
	while _pos < _text.length():
		var character := _text[_pos]
		if character == "\"":
			_pos += 1  # pula a aspa de fechamento
			return result
		if character == "\\" and _pos + 1 < _text.length():
			_pos += 1
			match _text[_pos]:
				"n":
					result += "\n"
				"t":
					result += "\t"
				_:
					result += _text[_pos]  # \\ vira \ e \" vira "
		else:
			result += character
		_pos += 1
	return result


## Lê um texto sem aspas (raro), até um espaço, aspas ou chave.
func _read_unquoted() -> String:
	var start := _pos
	while _pos < _text.length():
		var character := _text[_pos]
		if character in [" ", "\t", "\n", "\r", "\"", "{", "}"]:
			break
		_pos += 1
	return _text.substr(start, _pos - start)
