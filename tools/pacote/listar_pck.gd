extends SceneTree
## Lista tudo o que está dentro de um pck (Fase 18.6), uma linha por arquivo:
##   ARQ=res://caminho/do/arquivo
##
## O tools/empacotar_windows.sh usa a lista para recusar um pacote com
## config.cfg, capas de jogo ou pastas do repositório (tests, tools, docs...).
##
## Uso: godot --headless --main-pack <GameHub.pck> -s <caminho absoluto deste script>
## Com --main-pack, o res:// é o pck. O DirAccess só vê o que está no pck (o
## FileAccess cairia no disco), por isso a lista sai dele.


func _initialize() -> void:
	var count := _walk("res://")
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
		print("ARQ=%s" % path.path_join(file))
		count += 1
	for sub in dir.get_directories():
		print("DIR=%s" % path.path_join(sub))
		count += _walk(path.path_join(sub))
	return count
