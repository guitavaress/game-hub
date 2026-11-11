extends SceneTree
## Lista tudo o que está dentro de um pck e procura segredos nele (Fase 18.6).
##
## Saída, uma linha por coisa:
##   ARQ=res://caminho/do/arquivo       DIR=res://pasta
##   SEGREDO=res://arquivo (motivo)     algo com cara de chave ou de SteamID
##   GDC_FALHA=res://arquivo            um script ou recurso que não deu para abrir
##   SCRIPTS=<quantos>  CONTROLE=<sim|nao>  TOTAL=<quantos arquivos>
##
## O tools/empacotar_windows.sh usa a lista para recusar um pacote com
## config.cfg, capas de jogo, pastas do repositório ou segredos.
##
## Por que abrir os arquivos: no pck, os scripts vão como "tokens" compactados
## (.gdc) e as cenas dos modelos 3D vão compactadas (RSCC). Uma busca de texto no
## pck não enxerga o que está dentro deles. Aqui cada um é descompactado antes.
## O que se procura, em qualquer lugar e em quantas linhas for:
##   - 32 ou mais letras hexadecimais seguidas (a chave da Steam tem 32);
##   - um SteamID64 escrito (7656119 + 10 dígitos);
##   - um SteamID64 guardado como número inteiro (8 bytes). Nos tokens e nos
##     recursos, os números não viram texto. Esta busca fica de fora só nas
##     malhas dos modelos 3D, onde números ao acaso dariam alarme falso.
## O CONTROLE confere que a leitura funciona: o texto "web_api_key" do AppConfig
## tem que aparecer descompactado; se o formato mudar numa Godot nova, ele vira
## "nao" e o pacote é recusado. Um RSCC que não descompacta inteiro (cada bloco
## e o tamanho total batendo) também é recusado.
##
## Uso: godot --headless --main-pack <GameHub.pck> -s <caminho absoluto deste script>
## Com --main-pack, o res:// é o pck. O DirAccess só vê o que está no pck (o
## FileAccess cairia no disco), por isso a lista sai dele.

## Textos públicos que podem aparecer (não são segredo de ninguém).
const ALLOWED: Array[String] = [
	"fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb",  # SteamFriend.DEFAULT_AVATAR_HASH, o avatar padrão da Steam
]
const CONTROL_SCRIPT := "res://autoload/app_config.gdc"
## Arquivos que podem guardar texto ou números do projeto: cenas e recursos,
## configurações e shaders. Fora ficam as imagens, sons e fontes importadas, e os
## .import/.remap (que têm o hash de 32 hex do nome importado). Os .gd/.tres/.tscn
## em texto só aparecem se o export mudar para não compactar; entram por garantia.
const SCANNED: Array[String] = ["res", "scn", "cfg", "json", "gdshader", "gdshaderinc", "binary",
	"svg", "gd", "tres", "tscn", "txt"]
## As malhas importadas dos modelos 3D (.glb/.gltf): sem a busca de inteiros.
const MODEL_DIR := "res://.godot/imported/"

# A busca é feita sobre os bytes escritos em hexadecimal (hex_encode), que é
# rápido e não perde nenhum byte. Cada byte vira 2 letras; por isso cada achado
# precisa começar numa posição par.
## Um caractere hexadecimal (0-9, A-F, a-f), 32 ou mais vezes.
var _hex_run := RegEx.create_from_string("(?:3[0-9]|4[1-6]|6[1-6]){32,}")
## "7656119" e mais 10 dígitos.
var _steam_text := RegEx.create_from_string("37363536313139(?:3[0-9]){10}")
## Um inteiro de 8 bytes (little-endian) entre os SteamID64 de pessoas: os 4
## bytes de cima são 0x01100001 e os de baixo (o número da conta) não são zero.
var _steam_int := RegEx.create_from_string("([0-9a-f]{8})01001001")
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
		elif file.get_extension() in SCANNED:
			_scan_resource(full)
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
	var hex := tokens.hex_encode()
	if path == CONTROL_SCRIPT and hex.contains("web_api_key".to_ascii_buffer().hex_encode()):
		_control = true
	_scan_hex(path, hex, true)


## Um recurso: se vier compactado (RSCC), descompacta antes.
func _scan_resource(path: String) -> void:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() >= 4 and raw.slice(0, 4).get_string_from_ascii() == "RSCC":
		raw = _unpack_rscc(raw)
		if raw.is_empty():
			print("GDC_FALHA=%s" % path)
			return
	_scan_hex(path, raw.hex_encode(), not path.begins_with(MODEL_DIR))


## O formato compactado de recurso da Godot: "RSCC", o modo (4 bytes), o tamanho
## do bloco (4), o tamanho total (4), o tamanho compactado de cada bloco (4 cada)
## e os blocos. Devolve vazio se algo não bater (e quem chamou recusa).
static func _unpack_rscc(raw: PackedByteArray) -> PackedByteArray:
	if raw.size() < 16:
		return PackedByteArray()
	var mode := raw.decode_u32(4)
	var block_size := raw.decode_u32(8)
	var total := raw.decode_u32(12)
	if block_size == 0 or mode > FileAccess.COMPRESSION_BROTLI:
		return PackedByteArray()
	var blocks := total / block_size + 1
	var offset := 16 + 4 * blocks
	var out := PackedByteArray()
	for i in blocks:
		if 16 + 4 * i + 4 > raw.size():
			return PackedByteArray()
		var packed := raw.decode_u32(16 + 4 * i)
		var expected := block_size if i < blocks - 1 else total - block_size * (blocks - 1)
		if expected > 0:
			if offset + packed > raw.size():
				return PackedByteArray()
			var block := raw.slice(offset, offset + packed).decompress(expected, mode)
			if block.size() != expected:
				return PackedByteArray()
			out.append_array(block)
		offset += packed
	return out if out.size() == total else PackedByteArray()


## Procura a chave e o SteamID nos bytes (já em hexadecimal). Imprime só o caminho.
func _scan_hex(path: String, hex: String, with_integers: bool) -> void:
	for found in _matches_at_even(_hex_run, hex):
		if not found.hex_decode().get_string_from_ascii() in ALLOWED:
			print("SEGREDO=%s (texto de 32 ou mais hex, como a chave)" % path)
			break
	if not _matches_at_even(_steam_text, hex).is_empty():
		print("SEGREDO=%s (parece um SteamID64 escrito)" % path)
	if with_integers:
		for found in _matches_at_even(_steam_int, hex):
			if found.left(8) != "00000000":
				print("SEGREDO=%s (parece um SteamID64 guardado como número)" % path)
				break


## Os achados que começam num byte inteiro (posição par no texto hexadecimal).
static func _matches_at_even(regex: RegEx, hex: String) -> Array[String]:
	var result: Array[String] = []
	var from := 0
	while true:
		var found := regex.search(hex, from)
		if found == null:
			break
		if found.get_start() % 2 == 0:
			result.append(found.get_string())
			from = found.get_end()
		else:
			from = found.get_start() + 1
	return result
