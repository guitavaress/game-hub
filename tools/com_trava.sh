#!/bin/bash
# Roda um comando dentro da "fila da Godot" (Windows/Git Bash e Linux).
#
# Uso:
#   bash tools/com_trava.sh <comando...>
#   bash tools/com_trava.sh "$GODOT" --path . -s tools/capturar_pontos.gd -- ...
#
# Por quê: o user:// (config.cfg, cache) é um só para todos os worktrees, então
# só uma Godot de teste/captura roda por vez. Quem chega com a vez ocupada avisa
# uma vez e espera sozinho. O tests/run_tests.sh usa esta mesma trava.
#
# Como funciona (sem flock, que não existe no Git Bash):
#   - a trava é uma PASTA (mkdir é atômico: só um processo consegue criá-la),
#     em ${XDG_RUNTIME_DIR:-/tmp}/game-hub-godot.lock, fora do repositório e
#     comum a todos os worktrees;
#   - dentro dela fica o arquivo "pid" com o PID de quem travou. No Git Bash esse
#     PID é o do MSYS (o do próprio bash, $$), e "kill -0" entende esse número
#     em qualquer outro bash do Git Bash. (O PID do Windows seria outro número;
#     por isso não se mistura os dois.) Se o processo não existe mais, a trava é
#     velha e é tomada. A tomada é um "mv" (atômico), para dois esperando ao
#     mesmo tempo não tomarem a mesma trava;
#   - a variável GODOT_HUB_TRAVA marca "já estou com a trava", para o
#     com_trava.sh chamando o run_tests.sh (que também pede a trava) não travar
#     em si mesmo;
#   - a trava se solta no fim normal, em erro, em Ctrl+C e em kill (trap).

if [ $# -eq 0 ]; then
	echo "Uso: bash tools/com_trava.sh <comando...>"
	exit 2
fi

# Já tenho a trava (veio de um com_trava.sh/run_tests.sh de cima): só roda.
if [ -n "$GODOT_HUB_TRAVA" ]; then
	exec "$@"
fi

TRAVA="${GODOT_HUB_TRAVA_DIR:-${XDG_RUNTIME_DIR:-/tmp}/game-hub-godot.lock}"
AVISOU=0
SEM_PID=0

while ! mkdir "$TRAVA" 2>/dev/null; do
	dono=$(cat "$TRAVA/pid" 2>/dev/null)
	velha=0
	if [ -n "$dono" ]; then
		SEM_PID=0
		kill -0 "$dono" 2>/dev/null || velha=1
	elif [ ! -d "$TRAVA" ]; then
		continue # soltou agora mesmo: tenta de novo
	else
		# Pasta criada, mas o pid ainda não foi escrito (instante). Se passar
		# de uns 10 s, quem criou morreu no meio: trava velha.
		SEM_PID=$((SEM_PID + 1))
		[ $SEM_PID -gt 20 ] && velha=1
	fi
	if [ $velha -eq 1 ]; then
		# Toma a trava velha: só um ganha o mv; o resto volta a tentar.
		if mv "$TRAVA" "$TRAVA.velha.$$" 2>/dev/null; then
			rm -rf "$TRAVA.velha.$$"
			echo "== trava velha (processo $dono não existe mais); tomando =="
		fi
		continue
	fi
	if [ $AVISOU -eq 0 ]; then
		echo "== outra Godot de teste está rodando; esperando =="
		AVISOU=1
	fi
	sleep 0.5
done
echo $$ >"$TRAVA/pid"

filho=""
soltar() {
	# Só solta se a trava ainda é minha.
	if [ "$(cat "$TRAVA/pid" 2>/dev/null)" = "$$" ]; then
		rm -rf "$TRAVA"
	fi
}
parar() {
	# Ctrl+C ou kill: derruba o comando e sai com o código de sinal.
	if [ -n "$filho" ]; then
		kill "$filho" 2>/dev/null
		sleep 0.3
		kill -9 "$filho" 2>/dev/null
	fi
	exit "$1"
}
trap soltar EXIT
trap 'parar 130' INT
trap 'parar 143' TERM

export GODOT_HUB_TRAVA=1
# Em segundo plano + wait: assim o bash atende o sinal na hora (em primeiro
# plano, ele só atenderia depois que o comando terminasse).
"$@" &
filho=$!
wait "$filho"
codigo=$?
filho=""
exit $codigo
