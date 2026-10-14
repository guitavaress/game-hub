class_name SystemInfoLinux
extends SystemInfoBackend
## O estado do computador no Linux (Omarchy):
##   - bateria: arquivos de /sys/class/power_supply/BAT* (capacity e status);
##   - rede: `nmcli -t -f TYPE,STATE,CONNECTION dev` (NetworkManager);
##   - volume: `wpctl get-volume @DEFAULT_AUDIO_SINK@` (PipeWire).
## Se um programa não existe ou falha, aquela parte responde "não sei".

## Pasta das fontes de energia. Os testes trocam por uma pasta de exemplo.
var power_dir: String
## Quem roda um comando: Callable(programa: String, argumentos: Array) -> String
## (a saída, ou "" se falhou). Os testes trocam por respostas falsas.
var runner: Callable


func _init(power: String = "/sys/class/power_supply", command_runner: Callable = Callable()) -> void:
	power_dir = power.trim_suffix("/")
	runner = command_runner if command_runner.is_valid() else _run_command


func platform_name() -> String:
	return "linux"


func read() -> Dictionary:
	var result := SystemInfoBackend.unknown()
	result["battery"] = read_battery()
	result["network"] = parse_network(str(runner.call("nmcli", ["-t", "-f", "TYPE,STATE,CONNECTION", "dev"])))
	result["volume"] = parse_volume(str(runner.call("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"])))
	return result


## A primeira bateria (BAT0, BAT1...). Sem bateria (desktop): present = false.
func read_battery() -> Dictionary:
	var names := Array(DirAccess.get_directories_at(power_dir))
	names = names.filter(func(n: String) -> bool: return n.begins_with("BAT"))
	names.sort()
	for dir_name: String in names:
		var base := power_dir.path_join(dir_name)
		var capacity := FileAccess.get_file_as_string(base.path_join("capacity")).strip_edges()
		if not capacity.is_valid_int():
			continue
		var status := FileAccess.get_file_as_string(base.path_join("status")).strip_edges()
		return {
			"present": true,
			"percent": clampi(capacity.to_int(), 0, 100),
			# "Full" = cheia e na tomada: para o painel é o mesmo que carregando.
			"charging": status == "Charging" or status == "Full",
		}
	return {"present": false, "percent": 0, "charging": false}


## Lê a saída do nmcli. Cada linha é TIPO:ESTADO:NOME (":" dentro do nome vem
## como "\:"). Vale a primeira conexão ativa (wifi/ethernet antes de outras).
static func parse_network(text: String) -> Dictionary:
	var none := {"known": false, "type": "none", "connected": false, "name": ""}
	var lines := text.strip_edges().split("\n", false)
	if lines.is_empty():
		return none
	none["known"] = true
	var best: Dictionary = {}
	for line in lines:
		var fields := _split_unescaped(line)
		if fields.size() < 2:
			continue
		var kind := fields[0]
		if kind == "loopback" or not fields[1].begins_with("connected"):
			continue
		var type := "wifi" if kind == "wifi" else ("ethernet" if kind == "ethernet" else "other")
		var found := {"known": true, "type": type, "connected": true,
				"name": fields[2] if fields.size() > 2 else ""}
		if best.is_empty() or (best["type"] == "other" and type != "other"):
			best = found
	return best if not best.is_empty() else none


## Lê a saída do wpctl: "Volume: 0.45" ou "Volume: 0.45 [MUTED]".
static func parse_volume(text: String) -> Dictionary:
	var unknown_volume := {"known": false, "percent": 0, "muted": false}
	var line := text.strip_edges()
	if not line.begins_with("Volume:"):
		return unknown_volume
	var parts := line.trim_prefix("Volume:").strip_edges().split(" ", false)
	if parts.is_empty() or not parts[0].is_valid_float():
		return unknown_volume
	return {"known": true, "percent": roundi(parts[0].to_float() * 100.0), "muted": line.contains("[MUTED]")}


## Separa por ":" ignorando os "\:" (que viram ":" no texto).
static func _split_unescaped(line: String) -> PackedStringArray:
	var fields := PackedStringArray()
	var current := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and i + 1 < line.length():
			current += line[i + 1]
			i += 2
			continue
		if c == ":":
			fields.append(current)
			current = ""
		else:
			current += c
		i += 1
	fields.append(current)
	return fields


func _run_command(program: String, args: Array) -> String:
	var output: Array = []
	var string_args := PackedStringArray()
	for a in args:
		string_args.append(str(a))
	if OS.execute(program, string_args, output) != 0 or output.is_empty():
		return ""
	return str(output[0])
