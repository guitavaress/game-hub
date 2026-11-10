class_name FeedbackReport
extends RefCounted
## Resumo local: só lê os campos permitidos; nunca envia nem grava dados.


static func build(respostas: Dictionary) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var config: Node = tree.root.get_node("AppConfig")
	var library: Node = tree.root.get_node("SteamLibrary")
	var categories: Node = tree.root.get_node("GameCategories")
	var games: Array = library.get_installed_games()
	var districts: Dictionary = {}
	for game: SteamGame in games:
		districts[categories.get_category_id(game.app_id)] = true
	# A tela guarda esta amostra ao abrir; horas com o hub minimizado não
	# entram numa média acumulada nem alteram o texto já mostrado.
	var fps := "indisponível"
	if DisplayServer.get_name() != "headless" and Engine.get_frames_drawn() > 0:
		fps = "%d" % Engine.get_frames_per_second()
	# O resumo técnico só usa estes campos permitidos, nunca a ficha dos jogos.
	var lines: PackedStringArray = [
		"Game Hub — Contar o que achei",
		"Versão: %s" % ProjectSettings.get_setting("application/config/version", "indisponível"),
		"Sistema: %s" % OS.get_name(),
		"Placa de vídeo: %s" % RenderingServer.get_video_adapter_name(),
		"Qualidade: %s" % config.get_quality(),
		"FPS agora: %s" % fps,
		"Jogos: %d" % games.size(),
		"Bairros: %d" % districts.size(),
		"Chave configurada: %s" % ("sim" if not config.get_web_api_key().is_empty() else "não"),
	]
	var answers: PackedStringArray = [
		"O que você achou?\n%s" % str(respostas.get("impressao", "")).strip_edges(),
		"O que travou ou confundiu?\n%s" % str(respostas.get("dificuldades", "")).strip_edges(),
		"Voltaria a abrir? %s" % str(respostas.get("voltaria", "Talvez")),
	]
	var answer_text := "\n".join(answers)
	# Remove identificadores e caminhos colados nas respostas, preservando
	# palavras comuns que também sejam títulos de jogos, como Portal e Inside.
	for secret: String in [config.get_web_api_key(), config.get_steam_id_override()]:
		if not secret.is_empty():
			answer_text = answer_text.replace(secret, "[removido]")
	var private_text := RegEx.new()
	private_text.compile("(?i)(?:[a-z]:[\\\\/]|/home/|/Users/|user://|res://)[^\\r\\n]*|\\b[0-9]{17}\\b|\\b[0-9a-f]{32}\\b")
	return "\n".join(lines) + "\n\n" + private_text.sub(answer_text, "[removido]", true)
