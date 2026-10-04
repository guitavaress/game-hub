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

# 2. Roda cada teste. Cada um imprime "RESULTADO: TUDO OK" (ou as falhas).
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

echo
if [ $failed -eq 0 ]; then
	echo "RESULTADO GERAL: TUDO OK"
else
	echo "RESULTADO GERAL: $failed teste(s) com problema"
	exit 1
fi
