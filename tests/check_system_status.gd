extends SceneTree
## Teste do estado do sistema (Fase 14.8): SystemInfoLinux e SystemStatus.
##
## Usa uma pasta /sys de exemplo (tests/fixtures/power_supply) e respostas
## falsas do nmcli e do wpctl, então roda igual no Linux e no Windows.

const FIXTURES: String = "res://tests/fixtures/power_supply"

var failures := 0
var _answers: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var base := ProjectSettings.globalize_path(FIXTURES)
	var fake := func(program: String, _args: Array) -> String: return _answers.get(program, "")

	print("== bateria ==")
	var on_battery := SystemInfoLinux.new(base, fake).read_battery()
	_check("com bateria: 67%%, descarregando", on_battery == {"present": true, "percent": 67, "charging": false})
	var full := SystemInfoLinux.new(base + "/carregando", fake).read_battery()
	_check("BAT1 cheia na tomada conta como carregando", full == {"present": true, "percent": 100, "charging": true})
	var desktop := SystemInfoLinux.new(base + "/desktop", fake).read_battery()
	_check("sem bateria (só AC): present = false", desktop["present"] == false)
	var missing := SystemInfoLinux.new(base + "/nao-existe", fake).read_battery()
	_check("pasta inexistente: present = false", missing["present"] == false)

	print("== rede (nmcli) ==")
	var wifi := SystemInfoLinux.parse_network("ethernet:unavailable:\nwifi:connected:Casa\\:5G\nloopback:connected (externally):lo\n")
	_check("wifi conectado, com o nome (\\: vira :)", wifi == {"known": true, "type": "wifi", "connected": true, "name": "Casa:5G"})
	var cable := SystemInfoLinux.parse_network("wifi:disconnected:\nethernet:connected:Cabo 1\n")
	_check("cabo conectado", cable["type"] == "ethernet" and cable["connected"] and cable["name"] == "Cabo 1")
	var offline := SystemInfoLinux.parse_network("wifi:disconnected:\nethernet:unavailable:\nloopback:connected (externally):lo\n")
	_check("sem rede: conhecido, mas desconectado", offline == {"known": true, "type": "none", "connected": false, "name": ""})
	_check("nmcli sem resposta: não sei", SystemInfoLinux.parse_network("")["known"] == false)

	print("== volume (wpctl) ==")
	_check("Volume: 0.45 → 45%", SystemInfoLinux.parse_volume("Volume: 0.45\n") == {"known": true, "percent": 45, "muted": false})
	_check("[MUTED] → mudo", SystemInfoLinux.parse_volume("Volume: 0.30 [MUTED]\n") == {"known": true, "percent": 30, "muted": true})
	_check("acima de 100% não é cortado", SystemInfoLinux.parse_volume("Volume: 1.20\n")["percent"] == 120)
	_check("wpctl sem resposta: não sei", SystemInfoLinux.parse_volume("")["known"] == false)
	_check("lixo: não sei", SystemInfoLinux.parse_volume("Volume: abc")["known"] == false)

	print("== read() completo ==")
	_answers = {"nmcli": "wifi:connected:Casa\n", "wpctl": "Volume: 0.50\n"}
	var all := SystemInfoLinux.new(base, fake).read()
	_check("junta bateria, rede e volume",
			all["battery"]["percent"] == 67 and all["network"]["name"] == "Casa" and all["volume"]["percent"] == 50)
	_answers = {}
	var blind := SystemInfoLinux.new(base + "/desktop", fake).read()
	_check("sem nenhum programa: tudo 'não sei', sem erro",
			blind["battery"]["present"] == false and blind["network"]["known"] == false and blind["volume"]["known"] == false)
	_check("a base responde 'não sei'", SystemInfoBackend.new().read() == SystemInfoBackend.unknown())
	_check("SystemInfo devolve as 3 partes", SystemInfo.read().has_all(["battery", "network", "volume"]))

	print("== SystemStatus ==")
	var status: Node = root.get_node("SystemStatus")
	var count := [0]
	status.changed.connect(func() -> void: count[0] += 1)
	status.apply(all)
	_check("apply guarda o estado e avisa", count[0] == 1 and status.battery()["percent"] == 67 and status.volume()["percent"] == 50)
	status.apply(all)
	_check("o mesmo estado não avisa de novo", count[0] == 1)
	var changed := all.duplicate(true)
	changed["volume"]["percent"] = 10
	status.apply(changed)
	_check("estado diferente avisa", count[0] == 2 and status.volume()["percent"] == 10)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
