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

# Trava: o user:// (config.cfg, chave, cache) é um só para todos os worktrees
# do claude-squad. Se outra bateria estiver rodando, esta espera ela acabar.
# A trava se solta sozinha quando o script termina. Sem flock (Git Bash no
# Windows), segue sem trava.
if command -v flock >/dev/null 2>&1; then
	TRAVA="${XDG_RUNTIME_DIR:-/tmp}/game-hub-testes.lock"
	exec 9>"$TRAVA"
	if ! flock -n 9; then
		echo "== outra bateria está rodando; esperando ela terminar =="
		flock 9
	fi
fi

# Cada execução guarda a saída completa fora do repositório.
LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/game-hub-tests.XXXXXX") || exit 1
export GAME_HUB_TEST_LOG_DIR="$LOG_DIR"
echo "Logs: $LOG_DIR"
if [ $# -gt 0 ]; then
    TESTS=("$@")
else
    TESTS=()
    for path in tests/check_*.gd; do
        TESTS+=("$(basename "$path" .gd)")
    done
fi
for t in "${TESTS[@]}"; do
    if [[ ! "$t" =~ ^check_[a-z0-9_]+$ ]] || [ ! -f "tests/$t.gd" ]; then
        echo "Teste inválido: $t"
        exit 1
    fi
done

# XDG (Linux) e APPDATA (Windows/Git Bash) são vistos somente pelos filhos.
# Cada teste ganha uma pasta nova; uma falha/timeout não deixa preferências
# para o próximo teste. Não copiamos nem lemos config.cfg pessoal.
isolate_data() {
    local data="$LOG_DIR/$1-data"
    mkdir -p "$data"
    if command -v cygpath >/dev/null 2>&1; then
        data=$(cygpath -m "$data")
    fi
    export XDG_DATA_HOME="$data" XDG_CONFIG_HOME="$data/config" XDG_CACHE_HOME="$data/cache"
    export APPDATA="$data" LOCALAPPDATA="$data/cache" GAME_HUB_TEST_DATA="$data"
}
isolate_data import

# Não usar pipeline: precisamos do código do processo, inclusive timeout (124).
echo "== importando o projeto =="
timeout --kill-after=5 "${IMPORT_TIMEOUT:-300}" "$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1
code=$?
if [ "$code" -ne 0 ] || grep -qiE 'SCRIPT ERROR|Parse Error|^ERROR:' "$LOG_DIR/import.log"; then
    echo "RESULTADO GERAL: erro ao importar (saída $code); veja $LOG_DIR/import.log"
    exit 1
fi

failed=0
passed=0
skipped=0
for t in "${TESTS[@]}"; do
    args=()
    [ "$t" = "check_phase3_cache" ] && args=(-- --mode=cached)
    isolate_data "$t"
    log="$LOG_DIR/$t.log"
    # Herança mantém o script e suas verificações; só prepara os serviços.
    wrapper="$LOG_DIR/$t.gd"
    cat >"$wrapper" <<EOF
extends "res://tests/$t.gd"

func _initialize() -> void:
    load("res://tests/test_environment.gd").install(root)
    super._initialize()
EOF
    timeout --kill-after=5 "${TEST_TIMEOUT:-240}" "$GODOT" --headless --path . -s "$wrapper" "${args[@]}" >"$log" 2>&1
    code=$?
    # Normaliza CRLF do console no Windows antes de conferir o contrato.
    tr -d '\r' <"$log" >"$log.normalized"
    result=$(grep '^RESULTADO:' "$log.normalized" | tail -1)
    status="FALHOU"
    if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
        status="TIMEOUT"
    elif [ "$code" -ne 0 ]; then
        status="SAÍDA $code"
    elif grep -qiE 'SCRIPT ERROR|Parse Error|\[FALHOU\]|^RESULTADO:.*FALHA' "$log.normalized"; then
        status="FALHOU"
    elif [ "$(grep -c '^RESULTADO:' "$log.normalized")" -eq 1 ]; then
        if [ "$result" = 'RESULTADO: TUDO OK' ]; then
            status="ok"
        elif [[ "$result" == 'RESULTADO: PULADO: '* ]]; then
            status="pulado"
        fi
    fi
    case "$status" in
        ok) passed=$((passed + 1));;
        pulado) skipped=$((skipped + 1));;
        *) failed=$((failed + 1));;
    esac
    echo "$t: $status (saída $code)" | tee -a "$LOG_DIR/resumo.log"
    if [ "$status" != ok ]; then
        grep -E 'FALHOU|SCRIPT ERROR|RESULTADO:' "$log.normalized" | head -8
        echo "    log: $log"
    fi
done

echo "Aprovados: $passed; pulados: $skipped; falhas: $failed" | tee -a "$LOG_DIR/resumo.log"
if [ "$failed" -eq 0 ]; then
    echo "RESULTADO GERAL: TUDO OK"
else
    echo "RESULTADO GERAL: $failed teste(s) com problema"
    exit 1
fi
