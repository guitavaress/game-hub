extends SceneTree
## Lista tudo o que está dentro de um pck e procura segredos nos scripts (Fase 18.6).
##
## Saída, uma linha por coisa:
##   ARQ=res://caminho/do/arquivo       DIR=res://pasta
##   SEGREDO=res://script.gdc (motivo)  um script com cara de chave ou SteamID
##   GDC_FALHA=res://script.gdc         um script que não deu para abrir
##   SCRIPTS=<quantos>  CONTROLE=<sim|nao>  TOTAL=<quantos arquivos>
##
## O tools/empacotar_windows.sh usa a lista para recusar um pacote com
## config.cfg, capas de jogo, pastas do repositório ou segredos.
##
## Por que abrir os scripts: no pck eles vão como "tokens" compactados (.gdc), e
## uma busca de texto no pck não enxerga o que está escrito neles. Aqui cada .gdc
## é descompactado (e os recursos com texto, como .res e .scn, são lidos). Nos
## tokens, os textos entre aspas aparecem em claro (os nomes de variáveis e os
## números, não). Por isso a busca é por qualquer
## sequência de 32 ou mais letras hexadecimais (a chave da Steam tem 32), em
## qualquer lugar e em quantas linhas for, e por SteamID64 (7656119 + 10 dígitos).
## O CONTROLE confere que a leitura funciona: o texto "web_api_key" do AppConfig
## tem que aparecer descompactado; se o formato mudar numa Godot nova, ele vira
## "nao" e o pacote é recusado.
##
## Uso: godot --headless --main-pack <GameHub.pck> -s <caminho absoluto deste script>
## Com --main-pack, o res:// é o pck. O DirAccess só vê o que está no pck (o
## FileAccess cairia no disco), por isso a lista sai dele.

## Textos públicos que podem aparecer (não são segredo de ninguém).
const ALLOWED: Array[String] = [
	"fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb",  # SteamFriend.DEFAULT_AVATAR_HASH, o avatar padrão da Steam
]
const CONTROL_SCRIPT := "res://autoload/app_config.gdc"
## Recursos que guardam texto em claro (cenas e recursos binários, configurações,
## shaders). Fora ficam as imagens, sons e malhas importadas, e os .import/.remap
## (que têm o hash de 32 hex do nome importado). Os .gd/.tres/.tscn em texto só
## aparecem se o export mudar para não compactar; entram por garantia.
const TEXT_BEARING: Array[String] = ["res", "scn", "cfg", "json", "gdshader", "gdshaderinc", "binary",
	"svg", "gd", "tres", "tscn", "txt"]

var _hex_run := RegEx.create_from_string("[0-9A-Fa-f]{32,}")
var _steam_id := RegEx.create_from_string("7656119[0-9]{10}")
var _scripts := 0
var _control := false


func _initialize() -> void:
	var count := _walk("res://")
	print("SCRIPTS=%d" % _scripts)
	print("CONTROLE=%s" % ("sim" if _control else "nao"))
	print("TOTAL=%d" % count)
	quit(0)


func _walk(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	dir.include_hidden = true
	dir.include_navigational = false
	var count := 0
	for file in dir.get_files():
		var full := path.path_join(file)
		print("ARQ=%s" % full)
		if file.ends_with(".gdc"):
			_scan_script(full)
		elif file.get_extension() in TEXT_BEARING:
			_scan_bytes(full, FileAccess.get_file_as_bytes(full))
		count += 1
	for sub in dir.get_directories():
		print("DIR=%s" % path.path_join(sub))
		count += _walk(path.path_join(sub))
	return count


## Abre um .gdc: "GDSC", versão (4 bytes), tamanho descompactado (4 bytes) e os
## tokens (compactados com zstd quando o tamanho não é zero).
func _scan_script(path: String) -> void:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() < 12 or raw.slice(0, 4).get_string_from_ascii() != "GDSC":
		print("GDC_FALHA=%s" % path)
		return
	var size := raw.decode_u32(8)
	var tokens := raw.slice(12) if size == 0 else raw.slice(12).decompress(size, FileAccess.COMPRESSION_ZSTD)
	if tokens.is_empty() or (size != 0 and tokens.size() != size):
		print("GDC_FALHA=%s" % path)
		return
	_scripts += 1
	if path == CONTROL_SCRIPT and _printable(tokens).contains("web_api_key"):
		_control = true
	_scan_bytes(path, tokens)


## Procura a chave e o SteamID nos bytes de um arquivo. Imprime só o caminho.
func _scan_bytes(path: String, bytes: PackedByteArray) -> void:
	var text := _printable(bytes)
	for found in _hex_run.search_all(text):
		if not found.get_string() in ALLOWED:
			print("SEGREDO=%s (texto de 32 ou mais hex, como a chave)" % path)
			break
	if _steam_id.search(text) != null:
		print("SEGREDO=%s (parece um SteamID64)" % path)


## Os bytes como texto: o que não é letra visível vira ".". Nunca é impresso.
static func _printable(bytes: PackedByteArray) -> String:
	var clean := bytes.duplicate()
	for i in clean.size():
		var b := clean[i]
		if b < 32 or b > 126:
			clean[i] = 46
	return clean.get_string_from_ascii()
