extends SceneTree
## Teste das texturas nítidas (Fase 10.1; o bioma montanha entrou na 15.0).
##
## As texturas da ambientCG, o atlas das árvores e os céus HDRI são importados
## com compressão de placa (VRAM) e, menos os céus, com mipmaps: assim o
## asfalto ao longe não "granula" nem cintila. Os mapas de relevo (NormalGL)
## usam a compressão própria de relevo. Este teste lê cada .import e confere
## isso, para ninguém voltar o import sem querer (no editor, a aba Importar
## grava direto nesses arquivos).

var failures := 0

## Formatos de imagem comprimidos para a placa de vídeo (desktop).
const COMPRESSED_FORMATS: Array[int] = [
	Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5,
	Image.FORMAT_RGTC_R, Image.FORMAT_RGTC_RG,
	Image.FORMAT_BPTC_RGBA, Image.FORMAT_BPTC_RGBF, Image.FORMAT_BPTC_RGBFU,
	Image.FORMAT_DXT5_RA_AS_RG,
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("== ambientCG e árvores: VRAM + mipmaps ==")
	var imports: Array[String] = []
	for folder in DirAccess.get_directories_at("res://assets/ambientcg"):
		for file in DirAccess.get_files_at("res://assets/ambientcg/" + folder):
			if file.ends_with(".import"):
				imports.append("res://assets/ambientcg/%s/%s" % [folder, file])
	imports.append("res://assets/generated/tree_impostor.png.import")
	# Fase 15.0 (bioma montanha): o atlas do pinheiro e as texturas da rocha 3D.
	imports.append("res://assets/generated/pine_impostor.png.import")
	for folder in DirAccess.get_directories_at("res://assets/polyhaven/models"):
		var textures := "res://assets/polyhaven/models/%s/textures" % folder
		for file in DirAccess.get_files_at(textures):
			if file.ends_with(".import"):
				imports.append("%s/%s" % [textures, file])
	_check("achou as 27 texturas da ambientCG, os 2 atlas e as 3 da rocha (%d)" % imports.size(), imports.size() == 32)
	var bad: Array[String] = []
	var bad_normals: Array[String] = []
	for path in imports:
		var config := ConfigFile.new()
		if config.load(path) != OK:
			bad.append(path.get_file())
			continue
		if int(config.get_value("params", "compress/mode", 0)) != 2 \
				or not bool(config.get_value("params", "mipmaps/generate", false)):
			bad.append(path.get_file())
		var is_normal := path.contains("_NormalGL") or path.contains("_nor_gl")
		if is_normal and int(config.get_value("params", "compress/normal_map", 0)) != 1:
			bad_normals.append(path.get_file())
	_check("todas com compress/mode=2 e mipmaps (erradas: %s)" % str(bad), bad.is_empty())
	_check("relevo com compress/normal_map=1 (erradas: %s)" % str(bad_normals), bad_normals.is_empty())

	print("== céus HDRI: VRAM (sem mipmaps) ==")
	var bad_sky: Array[String] = []
	for file in DirAccess.get_files_at("res://assets/polyhaven/hdri"):
		if not file.ends_with(".import"):
			continue
		var config := ConfigFile.new()
		config.load("res://assets/polyhaven/hdri/" + file)
		if int(config.get_value("params", "compress/mode", 0)) != 2:
			bad_sky.append(file)
	_check("os 3 céus com compress/mode=2 (errados: %s)" % str(bad_sky), bad_sky.is_empty())

	print("== a textura carregada é comprimida e tem mipmaps ==")
	var samples: Array[String] = [
		"res://assets/ambientcg/Road012A/Road012A_1K-JPG_Color.jpg",
		"res://assets/ambientcg/Bricks097/Bricks097_1K-JPG_NormalGL.jpg",
		"res://assets/ambientcg/Concrete034/Concrete034_1K-JPG_Roughness.jpg",
		"res://assets/generated/tree_impostor.png",
		"res://assets/ambientcg/Snow010A/Snow010A_1K-JPG_Color.jpg",
		"res://assets/generated/pine_impostor.png",
	]
	for path in samples:
		var texture := load(path) as CompressedTexture2D
		var mipmaps := _imported_mipmaps(path)
		var ok := texture != null and texture.get_format() in COMPRESSED_FORMATS and mipmaps > 0
		_check("%s: formato %d comprimido, %d mipmaps" % [path.get_file(), texture.get_format() if texture != null else -1, mipmaps], ok)
	var sky := load("res://assets/polyhaven/hdri/rogland_clear_night_2k.hdr") as CompressedTexture2D
	_check("céu da noite comprimido (BC6H)", sky != null and sky.get_format() in COMPRESSED_FORMATS)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


## Quantos mipmaps o arquivo importado (.ctex) tem. Sem janela, a Godot usa
## um renderizador "falso" e has_mipmaps() responde sempre false; por isso o
## número vem do cabeçalho do arquivo: "GST2", versão, largura, altura, flags,
## limite e 3 reservados (4 bytes cada), o formato dos dados (4), largura e
## altura (2 + 2) e, no byte 44, o número de mipmaps.
func _imported_mipmaps(source: String) -> int:
	var config := ConfigFile.new()
	if config.load(source + ".import") != OK:
		return -1
	var imported := ""
	for key in config.get_section_keys("remap"):
		if key.begins_with("path"):
			imported = str(config.get_value("remap", key))
	var file := FileAccess.open(imported, FileAccess.READ)
	if file == null or file.get_buffer(4).get_string_from_ascii() != "GST2":
		return -1
	file.seek(44)
	return int(file.get_32())


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
