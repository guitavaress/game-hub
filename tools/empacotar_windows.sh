#!/bin/bash
# Gera o build do Windows (Fase 18): build/windows/GameHub.exe + GameHub.pck.
#
# Uso, da raiz do projeto (no Windows, pelo Git Bash):
#   bash tools/empacotar_windows.sh
#
# Nesta versão (18.2) ele só EXPORTA e confere o pck com o
# tests/check_exported_build.gd. O LEIA-ME, as licenças e o zip entram na 18.6.
# A Godot padrão é a de C:\Godot; para usar outra: GODOT=/caminho bash tools/...
#
# A pasta build/ não vai para o git (.gitignore). Feche o GameHub.exe antes:
# com ele aberto, o Windows não deixa sobrescrever o arquivo.

cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-/c/Godot/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -x "$GODOT" ]; then
	echo "Godot não encontrada em $GODOT (use a variável GODOT)."
	exit 1
fi

VERSAO=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
echo "== exportando o Game Hub $VERSAO para o Windows =="
mkdir -p build/windows
rm -f build/windows/GameHub.exe build/windows/GameHub.pck
# O "import" antes garante que os recursos novos (ex.: um ícone) já foram importados.
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1
if ! timeout 600 "$GODOT" --headless --path . --export-release "Windows" build/windows/GameHub.exe >/dev/null 2>&1 \
		|| [ ! -f build/windows/GameHub.exe ] || [ ! -f build/windows/GameHub.pck ]; then
	echo "O export falhou. Rode à mão para ver a mensagem:"
	echo "  \"$GODOT\" --headless --path . --export-release Windows build/windows/GameHub.exe"
	exit 1
fi
ls -l build/windows/GameHub.exe build/windows/GameHub.pck | awk '{printf "  %s  %.0f MB\n", $NF, $5/1048576}'

echo "== conferindo o pck (tests/check_exported_build.gd) =="
saida=$(timeout 240 "$GODOT" --headless --path . -s res://tests/check_exported_build.gd 2>&1)
echo "$saida" | grep -E "FALHOU|RESULTADO" | sed 's/^/  /'
if ! echo "$saida" | grep -q "RESULTADO: TUDO OK"; then
	echo "O pck tem problema (veja as linhas FALHOU acima)."
	exit 1
fi
echo "build conferido: build/windows/GameHub.exe"
