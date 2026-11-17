#!/bin/bash
# Bateria de testes automáticos do Game Hub (roda sem abrir janela).
#
# Uso, a partir de qualquer pasta (no Windows, pelo Git Bash):
#   bash tests/run_tests.sh              # todos os testes
#   bash tests/run_tests.sh check_gates  # só os testes com esses nomes
#
# A Godot padrão é a de C:\Godot; para usar outra:
#   GODOT=/caminho/da/godot bash tests/run_tests.sh
#
# Nenhum teste abre jogo de verdade (a Steam é "falsa" nos testes do launcher).
# Os que mexem no user://config.cfg ou no cache guardam uma cópia e devolvem no fim.

#   No Linux, procura "godot" no PATH e depois em ~/.local/bin/godot.
if [ -z "$GODOT" ]; then
	if [ -x "/c/Godot/Godot_v4.7.2-stable_win64_console.exe" ]; then
		GODOT="/c/Godot/Godot_v4.7.2-stable_win64_console.exe"
	elif command -v godot >/dev/null 2>&1; then
		GODOT="$(command -v godot)"
	else
		GODOT="$HOME/.local/bin/godot"
	fi
fi
cd "$(dirname "$0")/.." || exit 1

if [ ! -x "$GODOT" ]; then
	echo "Godot não encontrada em $GODOT (use a variável GODOT)."
	exit 1
fi

# Trava: o user:// (config.cfg, chave, cache) é um só para todos os worktrees.
# Se outra Godot de teste ou captura estiver rodando, esta espera sozinha.
# A trava é a mesma das capturas (tools/com_trava.sh), funciona no Git Bash do
# Windows e no Linux, e se solta no fim, em erro e em Ctrl+C. Se já vier de um
# com_trava.sh (GODOT_HUB_TRAVA), não trava de novo.
if [ -z "$GODOT_HUB_TRAVA" ]; then
	exec bash tools/com_trava.sh bash "tests/$(basename "$0")" "$@"
fi

if [ $# -gt 0 ]; then
	TESTS="$*"
else
	TESTS=$(ls tests/check_*.gd | xargs -n1 basename | sed 's/\.gd$//')
fi

# 1. Importa o projeto e procura erros de script.
echo "== importando o projeto =="
errors=$(timeout 300 "$GODOT" --headless --path . --import 2>&1 | grep -iE "script error|parse error" | head -5)
if [ -n "$errors" ]; then
	echo "$errors"
	echo "RESULTADO GERAL: erro de script ao importar"
	exit 1
fi

# 2. A visão do jogador (Fase 20.5): os testes rodam sempre a partir da
#    primeira pessoa, seja qual for a do usuário no config.cfg. Ela é guardada
#    aqui e devolvida no fim, também em erro e em Ctrl+C (tests/visao_da_bateria.gd).
devolver_visao() {
	timeout 60 "$GODOT" --headless --path . -s res://tests/visao_da_bateria.gd -- devolver >/dev/null 2>&1
}
trap devolver_visao EXIT
trap 'exit 130' INT TERM
timeout 60 "$GODOT" --headless --path . -s res://tests/visao_da_bateria.gd -- guardar >/dev/null 2>&1

# 3. Roda cada teste. Cada um imprime "RESULTADO: TUDO OK" (ou as falhas).
failed=0
for t in $TESTS; do
	args=()
	[ "$t" = "check_phase3_cache" ] && args=(-- --mode=cached)
	out=$(timeout 240 "$GODOT" --headless --path . -s "res://tests/$t.gd" "${args[@]}" 2>&1)
	if echo "$out" | grep -q "SCRIPT ERROR"; then
		status="ERRO DE SCRIPT"
	elif echo "$out" | grep -q "RESULTADO: TUDO OK"; then
		status="ok"
	elif [ "$t" = "check_phase3_cache" ] && echo "$out" | grep -q "pronta"; then
		status="ok"
	elif [ "$t" = "check_portal_regression" ] && echo "$out" | grep -q "ok:" && ! echo "$out" | grep -q "FALHOU"; then
		status="ok"
	else
		status="FALHOU"
	fi
	if [ "$status" != "ok" ]; then
		failed=$((failed + 1))
		echo "$t: $status"
		echo "$out" | grep -E "FALHOU|SCRIPT ERROR|RESULTADO" | head -8 | sed 's/^/    /'
	else
		echo "$t: ok"
	fi
done

# 4. O compositor nativo (Fase 14, parte 2): os testes do Rust e as licenças
#    dos crates. Só na bateria inteira, no Linux, com o Rust instalado e depois
#    de compilar uma vez (o --offline garante que a bateria nunca baixa nada).
if [ $# -eq 0 ]; then
	if [ "$(uname -s)" != "Linux" ] || ! command -v cargo >/dev/null 2>&1; then
		echo "cargo test: pulado (sem Rust ou fora do Linux)"
	elif [ ! -d native/compositor/target ]; then
		echo "cargo test: pulado (rode antes bash tools/linux/compilar_compositor.sh)"
	else
		if out=$(cargo test --offline --locked --manifest-path native/compositor/Cargo.toml 2>&1); then
			echo "cargo test: ok ($(echo "$out" | grep -oE '[0-9]+ passed' | head -1))"
		else
			failed=$((failed + 1))
			echo "cargo test: FALHOU"
			echo "$out" | grep -E "FAILED|panicked|^error" | head -8 | sed 's/^/    /'
		fi
		if out=$(bash tools/linux/checar_licencas.sh 2>&1); then
			echo "$out" | tail -1
		else
			failed=$((failed + 1))
			echo "$out" | tail -9 | sed 's/^/    /'
		fi
	fi
fi

echo
if [ $failed -eq 0 ]; then
	echo "RESULTADO GERAL: TUDO OK"
else
	echo "RESULTADO GERAL: $failed teste(s) com problema"
	exit 1
fi
