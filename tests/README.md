# Testes automáticos

Cada `check_<nome>.gd` é um script que a Godot roda **sem janela** (`--headless -s`). Ele monta a cidade de verdade, confere uma lista de coisas e imprime o resultado. Nenhum teste abre jogo de verdade.

## Rodar

```bash
bash tests/run_tests.sh                          # todos (alguns minutos)
bash tests/run_tests.sh check_gates check_trees  # só estes
```

Primeiro o script importa o projeto (erro de script para tudo). Depois roda cada teste e termina com `RESULTADO GERAL: TUDO OK` ou com a lista do que falhou. O script acha a Godot em `C:\Godot` (Windows) ou no `PATH`/`~/.local/bin/godot` (Linux); para outra, rode `GODOT=/caminho/godot bash tests/run_tests.sh`.

**Quando rodar:** antes de cada commit. Durante uma subetapa, rode só os testes ligados a ela e deixe a bateria inteira para o fim.

## Escrever um teste novo

Um teste por recurso: `tests/check_<recurso>.gd`, que o `run_tests.sh` encontra sozinho.

```gdscript
extends SceneTree
## Teste de <recurso> (Fase N.x).

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var city: Node = load("res://worlds/city/city.tscn").instantiate()
	city.play_intro = false  # pula a descida pelo céu
	root.add_child(city)
	while not city.is_city_ready():
		await process_frame
	await process_frame

	var launcher := root.get_node("GameLauncher")  # autoloads: sempre assim
	_check("descrição do que deve ser verdade", 1 + 1 == 2)

	print("\nRESULTADO: %s" % ("TUDO OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FALHOU", label])
	if not ok:
		failures += 1
```

**O contrato com o `run_tests.sh`:** cada conferência imprime `[ok]` ou `[FALHOU]`, e a última linha é `RESULTADO: TUDO OK` (ou `N FALHA(S)`). Sem essa linha, o teste conta como falha.

## Armadilhas conhecidas
- **Autoloads** se acessam com `root.get_node("Nome")`. Escrever `GameLauncher.algo` direto num script `-s` não compila.
- **Classes que usam autoloads** (ex.: `CityBuilding`) não podem aparecer como tipo no teste. Use `Node` ou acesse pelos métodos do objeto.
- **Espere a cidade:** use `while not city.is_city_ready()`. Um número fixo de frames dá resultado diferente em cada máquina.
- **Nada de Steam ou internet de verdade no que importa.** O launcher aceita uma Steam falsa (`state_reader` e `url_opener`). Se algo do mundo real puder estar em andamento (ex.: a consulta de amigos com a chave do usuário), espere terminar antes de testar.
- **Arquivos do usuário:** se o teste mexe em `user://config.cfg` ou no cache, guarde uma cópia no começo e devolva no fim (veja `check_pause_menu.gd`).
- **Nunca** use uma chave ou um ID real. Use valores falsos, como `76561190000000001`.
- **Capturas de tela** precisam de janela (sem `--headless`). Elas ficam fora deste diretório e fora do repositório, porque mostram capas de jogos.
- **A biblioteca de verdade importa.** Vários testes montam a cidade com os jogos instalados e procuram prédios específicos. Precisam estar instalados: **Balatro (2379780), Skyrim (489830), Valheim (892970) e Stardew Valley (413150)**; o Valheim também dá o bairro Terror. Num PC sem esses jogos, esses testes falham por falta do jogo, e não por erro no hub. O motor do bairro de esportes (`check_phase6_audio`) não exige jogo de esporte: sem ele, o teste confere o som pela tabela do bairro e avisa na saída. **Teste novo:** prefira achar o prédio pela categoria (`GameCategories.get_category_id`) a fixar um app id.
- **Depois de um `SCRIPT ERROR`**, o teste não chega ao `quit()` e fica parado até o `timeout` (240 s). Uma bateria com muitas falhas demora.
- **Testes de plataforma** (`check_platform`, `check_steam_linux`, `check_window_host`) usam pastas e comandos falsos em `tests/fixtures/` (com `.gdignore`, para a Godot não importar nada dali), então rodam igual no Windows e no Linux.
- **`check_steam_windows`** só roda no Windows (nos outros sistemas, "pulado"): usa o `reg.exe` e o `tasklist` de verdade, mas numa chave de mentira (`HKCU\Software\GameHubTest`) que ele cria e apaga. Não toca na chave real da Steam.
- **`check_profiles`** (Fase 7) compara os perfis e o `GameCategories` com o retrato do comportamento de antes (`tests/fixtures/profiles_atuais.json`). O JSON devolve números como decimais: compare tags e ids convertendo para `int`.
- **GitHub Actions** (`.github/workflows/testes.yml`): a cada push em `fase-*` e em cada Pull Request, roda os quatro testes de plataforma num Windows e num Linux do GitHub. A bateria completa **não** roda lá (precisa dos jogos instalados).
