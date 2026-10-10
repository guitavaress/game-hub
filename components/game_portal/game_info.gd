class_name GameInfo
extends RefCounted
## O CARTÃO de um jogo (Fase 9.4): nome, bairro, horas, última vez e amigos.
## Só funções estáticas. O GamePortal (porta do prédio) e a estante da casa
## usam o mesmo código, então o cartão é igual nos dois lugares.


## Nome do jogo ("Jogo N (não encontrado na Steam)" se a Steam não o conhece).
static func game_name(app_id: int) -> String:
	if app_id <= 0:
		return ""
	var steam_name := SteamLibrary.get_game_name(app_id)
	if steam_name.is_empty():
		return "Jogo %d (não encontrado na Steam)" % app_id
	return steam_name


## O cartão do HUD (contrato get_look_info):
##   label/label_color: a categoria do jogo ("CARTAS E TABULEIRO", na cor néon);
##   title/detail: o nome e "24 h jogadas · jogado ontem";
##   friends: "Ana e Bruno jogando agora" ("" = ninguém);
##   accent: cor da mira enquanto olha para o jogo.
## "title" opcional: quem tem um nome próprio (display_name do portal) passa aqui.
static func look_info(app_id: int, title: String = "") -> Dictionary:
	var category := GameCategories.get_category_id(app_id)
	var neon := GameCategories.get_neon_color(category)
	var friends := FriendsService.get_friends_playing(app_id)
	var friends_text := ""
	if not friends.is_empty():
		friends_text = SteamFriend.join_names(friends) + " jogando agora"
	return {
		"label": GameCategories.get_category_name(category).to_upper(),
		"label_color": neon,
		"title": title if not title.is_empty() else game_name(app_id),
		"detail": play_info(app_id),
		"friends": friends_text,
		"accent": neon,
	}


## "24 h jogadas · jogado ontem" (ou "" se a Steam não souber).
static func play_info(app_id: int) -> String:
	var minutes := SteamLibrary.get_playtime_minutes(app_id)
	var last_played := SteamLibrary.get_last_played(app_id)
	if minutes <= 0 and last_played <= 0:
		return "nunca jogado" if minutes == 0 else ""
	var parts := PackedStringArray()
	if minutes > 0:
		parts.append(format_playtime(minutes))
	if last_played > 0:
		parts.append(format_last_played(last_played))
	return " · ".join(parts)


static func format_playtime(minutes: int) -> String:
	if minutes < 60:
		return "%d min jogados" % minutes
	var hours := minutes / 60.0
	if hours < 10.0:
		# Uma casa decimal, com vírgula: "2,5 h" (e "2 h" em vez de "2,0 h").
		return "%s h jogadas" % ("%.1f" % hours).replace(".", ",").trim_suffix(",0")
	return "%d h jogadas" % floori(hours)


static func format_last_played(unix_time: int) -> String:
	# Compara DIAS do calendário no fuso do PC (ontem às 23h = "ontem").
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var today := floori((Time.get_unix_time_from_system() + bias_seconds) / 86400.0)
	var day := floori((unix_time + bias_seconds) / 86400.0)
	var days := maxi(today - day, 0)
	if days == 0:
		return "jogado hoje"
	if days == 1:
		return "jogado ontem"
	if days < 30:
		return "jogado há %d dias" % days
	if days < 365:
		var months := floori(days / 30.0)
		return "jogado há 1 mês" if months == 1 else "jogado há %d meses" % months
	var years := floori(days / 365.0)
	return "jogado há 1 ano" if years == 1 else "jogado há %d anos" % years
