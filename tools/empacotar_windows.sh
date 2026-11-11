#!/bin/bash
# Monta o pacote do Windows do Game Hub (Fase 18): o zip que vai para os amigos.
#
# Uso, da raiz do projeto (no Windows, pelo Git Bash):
#   bash tools/empacotar_windows.sh
#       exporta, monta GameHub-<versão>-windows/ (exe, pck, LEIA-ME.txt e
#       licencas/), confere e gera o zip. Termina com "pacote conferido".
#   bash tools/empacotar_windows.sh --conferir <pasta>
#       só confere uma pasta já montada (sem exportar e sem zip). Serve para
#       provar que a trava funciona numa cópia com um arquivo plantado.
#
# O que sai (fora do repositório; mude com PACOTES=/outra/pasta):
#   C:\Projetos\game-hub-builds\GameHub-<versão>-windows\
#   C:\Projetos\game-hub-builds\GameHub-<versão>-windows.zip
#
# A trava: o zip NÃO é gerado se o pacote tiver qualquer coisa fora da lista
# (exe, pck, LEIA-ME.txt e as licenças de tools/pacote/licencas.txt), se faltar
# ou estiver diferente uma licença, ou se achar um config.cfg, uma imagem de
# capa, as pastas tests, tools, docs, painel ou native (também dentro do pck),
# ou algo com cara da chave da Steam (32 letras hexadecimais) ou de um SteamID.
# Dentro do pck, os scripts são descompactados para a busca (listar_pck.gd).
# A trava nunca imprime o que achou: só o arquivo e o motivo.
#
# A Godot padrão é a de C:\Godot; para usar outra: GODOT=/caminho bash tools/...
# Feche o GameHub.exe antes: com ele aberto, o Windows não deixa sobrescrever.

cd "$(dirname "$0")/.." || exit 1
RAIZ=$(pwd)

GODOT="${GODOT:-/c/Godot/Godot_v4.7.2-stable_win64_console.exe}"
PACOTES="${PACOTES:-/c/Projetos/game-hub-builds}"
VERSAO=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NOME="GameHub-$VERSAO-windows"

# A chave da Steam Web API tem 32 letras hexadecimais. O padrão pega o nome do
# campo e o valor logo depois (com aspas, igual ou espaço no meio).
PADRAO_CHAVE='web_api_key[^0-9A-Fa-f]{0,12}[0-9A-Fa-f]{32}'
# O SteamID64 de uma pessoa (17 dígitos, começa com 7656119) ao lado do campo.
PADRAO_ID='steam_?id[^0-9]{0,12}7656119[0-9]{10}'
# Nomes de capa: os do nosso cache (<appid>.jpg, <appid>_hd.jpg) e os da Steam
# (library_600x900.jpg, header.jpg, logo.png...). No pck a imagem vira
# "<nome>.jpg.import" e ".godot/imported/<nome>.jpg-<hash>.ctex".
PADRAO_CAPA='^([0-9]+([_.-].*)?|(library|header|logo|hero|capsule)[a-z0-9_]*)\.(jpg|jpeg|png|webp)$'
# Pastas que nunca vão para os amigos (em qualquer nível, no pck ou fora).
PASTAS_PROIBIDAS='^(tests|tools|docs|painel|native|build|game-hub-brand-kit|\.git|\.github|\.claude|\.codex|\.agents|\.vscode)$'

if [ ! -x "$GODOT" ]; then
	echo "Godot não encontrada em $GODOT (use a variável GODOT)."
	exit 1
fi

# Caminho do Windows (C:\...) para a Godot e o PowerShell.
caminho_win() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

# Texto para o Bloco de Notas: UTF-8 com BOM e fim de linha do Windows, com a
# versão no lugar de {VERSAO}. Tem que ser o último sed: o sed do Git Bash tira
# o "\r" de tudo o que lê de um pipe.
texto_windows() { printf '\xEF\xBB\xBF'; sed "s/\r\$//; s/{VERSAO}/$VERSAO/g; s/\$/\r/" "$1"; }

# As licenças da lista, "origem destino" por linha (sem comentários).
licencas_da_lista() { tr -d '\r' < "$RAIZ/tools/pacote/licencas.txt" | grep -vE '^[[:space:]]*(#|$)'; }

# Gera a licença da Godot (pelo próprio motor) no arquivo dado, já no formato do pacote.
gerar_licenca_godot() {
	local cru="$1.cru"
	timeout 120 "$GODOT" --headless --path "$(caminho_win "$RAIZ")" -s res://tools/pacote/licenca_godot.gd \
		-- "$(caminho_win "$cru")" >/dev/null 2>&1 || { rm -f "$cru"; return 1; }
	[ -s "$cru" ] || { rm -f "$cru"; return 1; }
	texto_windows "$cru" > "$1" || { rm -f "$cru"; return 1; }
	rm -f "$cru"
}


# --- A trava ------------------------------------------------------------------
# recusar_do_pck <motivo>: cada linha que chega é um arquivo do pck recusado.
# Soma em "problemas" (a variável de quem chamou, a conferir_pacote).
recusar_do_pck() {
	local rel
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		# Sem motivo, a própria linha já diz (o listar_pck.gd põe entre parênteses).
		if [ -n "$1" ]; then echo "  RECUSADO: pck: res://$rel ($1)"; else echo "  RECUSADO: pck: res://$rel"; fi
		problemas=$((problemas + 1))
	done
}

# conferir_pacote <pasta>: imprime "RECUSADO: ..." para cada problema e devolve
# 1 se houver algum. Nunca imprime o conteúdo achado (pode ser a chave).
conferir_pacote() {
	local pasta="$1" problemas=0 rel nome
	if [ ! -d "$pasta" ]; then
		echo "  RECUSADO: a pasta $pasta não existe"
		return 1
	fi

	# 1. Só o que está na lista pode estar na pasta.
	local permitidos=" GameHub.exe GameHub.pck LEIA-ME.txt licencas licencas/godot.txt "
	local origem destino
	while read -r origem destino; do
		permitidos+="licencas/$destino "
	done < <(licencas_da_lista)
	for nome in GameHub.exe GameHub.pck LEIA-ME.txt licencas; do
		[ -e "$pasta/$nome" ] || { echo "  RECUSADO: falta $nome"; problemas=$((problemas + 1)); }
	done
	while IFS= read -r rel; do
		rel="${rel#./}"
		nome="${rel##*/}"
		[[ "$permitidos" == *" $rel "* ]] && [ ! -L "$pasta/$rel" ] && continue
		if [ "$nome" = "config.cfg" ]; then
			echo "  RECUSADO: $rel (um config.cfg: pode ter a chave da Steam)"
		elif echo "$nome" | grep -qiE '\.(jpg|jpeg|png|webp|bmp|gif)$'; then
			echo "  RECUSADO: $rel (uma imagem: pode ser capa de jogo)"
		elif [ -d "$pasta/$rel" ] && echo "$nome" | grep -qE "$PASTAS_PROIBIDAS"; then
			echo "  RECUSADO: $rel/ (pasta do repositório)"
		else
			echo "  RECUSADO: $rel (não está na lista do pacote)"
		fi
		problemas=$((problemas + 1))
	done < <(cd "$pasta" && find . -mindepth 1 | sort)

	# 2. As licenças: todas as da lista, iguais ao original, e a da Godot igual à
	# que o motor gera agora. Faltando ou diferente, recusa. O LEIA-ME também.
	while read -r origem destino; do
		if [ ! -f "$pasta/licencas/$destino" ]; then
			echo "  RECUSADO: falta licencas/$destino ($origem)"
			problemas=$((problemas + 1))
		elif ! cmp -s <(texto_windows "$RAIZ/$origem") "$pasta/licencas/$destino"; then
			echo "  RECUSADO: licencas/$destino está diferente de $origem"
			problemas=$((problemas + 1))
		fi
	done < <(licencas_da_lista)
	local godot_agora
	godot_agora=$(mktemp)
	if [ ! -f "$pasta/licencas/godot.txt" ]; then
		echo "  RECUSADO: falta licencas/godot.txt"
		problemas=$((problemas + 1))
	elif ! gerar_licenca_godot "$godot_agora" || ! cmp -s "$godot_agora" "$pasta/licencas/godot.txt"; then
		echo "  RECUSADO: licencas/godot.txt está diferente da licença da Godot"
		problemas=$((problemas + 1))
	fi
	rm -f "$godot_agora"
	if [ -f "$pasta/LEIA-ME.txt" ] && ! cmp -s <(texto_windows "$RAIZ/tools/pacote/LEIA-ME.txt") "$pasta/LEIA-ME.txt"; then
		echo "  RECUSADO: LEIA-ME.txt está diferente do modelo (tools/pacote/LEIA-ME.txt)"
		problemas=$((problemas + 1))
	fi

	# 3. Nenhum arquivo (nem o exe e o pck, lidos como bytes) tem a chave ou o ID.
	# O grep devolve 0 (achou), 1 (não achou) ou 2 (não conseguiu ler): o 2 também recusa.
	local achados codigo
	achados=$(LC_ALL=C grep -rlaE "$PADRAO_CHAVE" "$pasta" 2>/dev/null); codigo=$?
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		echo "  RECUSADO: ${rel#"$pasta"/} tem um texto de 32 hex ao lado de web_api_key (parece a chave)"
		problemas=$((problemas + 1))
	done <<< "$achados"
	[ "$codigo" -le 1 ] || { echo "  RECUSADO: não consegui ler todos os arquivos para procurar a chave"; problemas=$((problemas + 1)); }
	achados=$(LC_ALL=C grep -rlaiE "$PADRAO_ID" "$pasta" 2>/dev/null); codigo=$?
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		echo "  RECUSADO: ${rel#"$pasta"/} tem um SteamID64 ao lado de steam_id"
		problemas=$((problemas + 1))
	done <<< "$achados"
	[ "$codigo" -le 1 ] || { echo "  RECUSADO: não consegui ler todos os arquivos para procurar o SteamID"; problemas=$((problemas + 1)); }

	# 4. Dentro do pck: a lista e a busca nos scripts vêm da própria Godot
	# (tools/pacote/listar_pck.gd).
	if [ -f "$pasta/GameHub.pck" ]; then
		local lista
		lista=$(timeout 240 "$GODOT" --headless --main-pack "$(caminho_win "$pasta/GameHub.pck")" \
			-s "$(caminho_win "$RAIZ/tools/pacote/listar_pck.gd")" 2>&1 | tr -d '\r')
		if ! echo "$lista" | grep -q '^TOTAL='; then
			echo "  RECUSADO: não consegui listar o GameHub.pck"
			problemas=$((problemas + 1))
		else
			# Um filtro só para a lista inteira (um processo por arquivo do pck
			# levaria minutos no Windows). Caminhos sem o "res://".
			local caminhos pastas
			caminhos=$(echo "$lista" | sed -n 's/^\(ARQ\|DIR\)=res:\/\///p')
			pastas=$(echo "$PASTAS_PROIBIDAS" | sed 's/^\^//; s/\$$//')
			recusar_do_pck "" < <(echo "$lista" | sed -n 's/^SEGREDO=res:\/\///p')
			recusar_do_pck "script que não deu para abrir e conferir" < <(echo "$lista" | sed -n 's/^GDC_FALHA=res:\/\///p')
			if echo "$caminhos" | grep -qx 'autoload/app_config.gdc' && ! echo "$lista" | grep -qx 'CONTROLE=sim'; then
				echo "  RECUSADO: pck: a busca nos scripts não funcionou (o controle no AppConfig falhou)"
				problemas=$((problemas + 1))
			fi
			recusar_do_pck "um config.cfg" < <(echo "$caminhos" | grep -E '(^|/)config\.cfg$')
			recusar_do_pck "pasta do repositório" < <(echo "$caminhos" | grep -E "(^|/)$pastas(/|$)")
			recusar_do_pck "cache de capas" < <(echo "$caminhos" | grep -E '(^|/)cache/art(/|$)')
			# Tira o ".import"/".remap" e o "-<hash>.ctex" do nome importado e
			# compara o resto com os nomes de capa.
			recusar_do_pck "parece capa de jogo" < <(echo "$caminhos" | PADRAO="$PADRAO_CAPA" awk -F/ '{ padrao = ENVIRON["PADRAO"]
				n = tolower($NF); sub(/\.(import|remap)$/, "", n); sub(/-[0-9a-f]{32}\.[a-z0-9]+$/, "", n)
				if (n ~ padrao) print $0 }')
		fi
	fi

	if [ "$problemas" -gt 0 ]; then
		echo "  $problemas problema(s): o zip NÃO foi gerado."
		return 1
	fi
	return 0
}

if [ "$1" = "--conferir" ]; then
	[ -n "$2" ] || { echo "Uso: bash tools/empacotar_windows.sh --conferir <pasta>"; exit 1; }
	echo "== conferindo $2 =="
	if conferir_pacote "$2"; then
		echo "pasta conferida: nada que não possa ir"
		exit 0
	fi
	exit 1
fi


# --- 1. Exportar ---------------------------------------------------------------
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

# --- 2. Montar a pasta -------------------------------------------------------------
PASTA="$PACOTES/$NOME"
ZIP="$PACOTES/$NOME.zip"
echo "== montando $PASTA =="
mkdir -p "$PACOTES" || exit 1
# Só apaga a pasta e o zip com o nome do pacote, dentro de PACOTES.
case "$NOME" in GameHub-*-windows) ;; *) echo "Nome de pacote estranho: $NOME"; exit 1 ;; esac
rm -rf "${PASTA:?}" "${ZIP:?}"
mkdir -p "$PASTA/licencas" || exit 1
cp build/windows/GameHub.exe build/windows/GameHub.pck "$PASTA/" || exit 1

faltou=0
texto_windows tools/pacote/LEIA-ME.txt > "$PASTA/LEIA-ME.txt" || faltou=1
while read -r origem destino; do
	if [ ! -f "$origem" ] || [ -z "$destino" ]; then
		echo "  falta a licença $origem (tools/pacote/licencas.txt)"
		faltou=1
	elif ! texto_windows "$origem" > "$PASTA/licencas/$destino"; then
		echo "  não consegui copiar a licença $origem"
		faltou=1
	fi
done < <(licencas_da_lista)
if ! gerar_licenca_godot "$PASTA/licencas/godot.txt"; then
	echo "  não consegui gerar a licença da Godot"
	faltou=1
fi
[ "$faltou" -eq 0 ] || { echo "Faltou licença: o zip NÃO foi gerado."; exit 1; }
echo "  $(ls "$PASTA/licencas" | wc -l) licenças em licencas/"

# --- 3. Conferir e zipar -------------------------------------------------------------
echo "== conferindo o pacote =="
if ! conferir_pacote "$PASTA"; then
	exit 1
fi
echo "  nada que não possa ir"

echo "== gerando o zip =="
# Cada arquivo entra com o caminho escrito com "/". No PowerShell 5, tanto o
# Compress-Archive quanto o ZipFile.CreateFromDirectory gravam com "\", e alguns
# programas de descompactar se perdem (ou criam arquivos com "\" no nome).
powershell.exe -NoProfile -NonInteractive -Command "
	\$ErrorActionPreference = 'Stop'
	Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
	\$pasta = '$(caminho_win "$PASTA")'
	\$acima = Split-Path -Parent \$pasta
	\$zip = [IO.Compression.ZipFile]::Open('$(caminho_win "$ZIP")', 'Create')
	try {
		Get-ChildItem -LiteralPath \$pasta -Recurse -File | Sort-Object FullName | ForEach-Object {
			\$nome = \$_.FullName.Substring(\$acima.Length + 1).Replace('\\', '/')
			[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(\$zip, \$_.FullName, \$nome, 'Optimal')
		}
	} finally { \$zip.Dispose() }
" || { echo "O zip falhou."; rm -f "$ZIP"; exit 1; }

# O zip tem exatamente o que a pasta conferida tem (nem mais, nem menos).
no_zip=$(powershell.exe -NoProfile -NonInteractive -Command "
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	\$z = [IO.Compression.ZipFile]::OpenRead('$(caminho_win "$ZIP")')
	\$z.Entries | ForEach-Object { \$_.FullName }
	\$z.Dispose()
" | tr -d '\r' | sort)
na_pasta=$(cd "$PACOTES" && find "$NOME" -type f | sort)
if [ "$no_zip" != "$na_pasta" ]; then
	echo "O zip não bate com a pasta conferida:"
	diff <(echo "$na_pasta") <(echo "$no_zip") | sed 's/^/  /'
	rm -f "$ZIP"
	exit 1
fi
tamanho=$(ls -l "$ZIP" | awk '{printf "%.0f MB", $5/1048576}')
echo "  $(echo "$no_zip" | wc -l) arquivos, $tamanho"
echo "pacote conferido: $(caminho_win "$ZIP")"
