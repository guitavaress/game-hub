# PC limpo (Fase 18.3): testa o hub como se fosse a primeira vez neste PC,
# sem perder os seus dados.
#
# O hub (no editor e no .exe) guarda tudo na mesma pasta:
#   %APPDATA%\Godot\app_userdata\Game Hub   (config.cfg, cache das capas, logs)
# Este script NUNCA apaga nada: ele so troca o nome das pastas.
#
# Uso (no PowerShell, da raiz do projeto):
#   powershell -ExecutionPolicy Bypass -File tools\pc_limpo.ps1 guardar
#       "Game Hub" vira "Game Hub.guardado". O proximo hub que abrir ve um PC limpo.
#   powershell -ExecutionPolicy Bypass -File tools\pc_limpo.ps1 devolver
#       a pasta do teste vira "Game Hub.teste-<data>" (apague quando quiser)
#       e "Game Hub.guardado" volta a ser "Game Hub".
#   powershell -ExecutionPolicy Bypass -File tools\pc_limpo.ps1 estado
#       mostra o que existe agora.
# -Raiz <pasta> troca a pasta de cima (os testes usam uma pasta falsa).
#
# Recusa rodar com o hub aberto (o GameHub.exe, a Godot de teste ou o F5 do
# editor): os arquivos estariam em uso. As mensagens ficam sem acento de
# proposito: o PowerShell 5.1 le o script como ANSI e trocaria as letras.

param(
	[Parameter(Position = 0)]
	[ValidateSet('guardar', 'devolver', 'estado')]
	[string]$Acao = 'estado',
	[string]$Raiz = (Join-Path $env:APPDATA 'Godot\app_userdata')
)

$ErrorActionPreference = 'Stop'
$pasta = Join-Path $Raiz 'Game Hub'
$guardada = Join-Path $Raiz 'Game Hub.guardado'

function Mostrar-Estado {
	Write-Output ("  Game Hub           : " + $(if (Test-Path -LiteralPath $pasta) { 'existe' } else { 'nao existe' }))
	Write-Output ("  Game Hub.guardado  : " + $(if (Test-Path -LiteralPath $guardada) { 'existe (os seus dados)' } else { 'nao existe' }))
	$testes = @(Get-ChildItem -LiteralPath $Raiz -Directory -Filter 'Game Hub.teste-*' -ErrorAction SilentlyContinue)
	foreach ($t in $testes) {
		Write-Output ("  " + $t.Name + " : sobra de um teste (pode apagar)")
	}
}

# Hub ou Godot de teste aberto? O hub rodado pelo editor (F5) tambem conta: ele
# abre outra Godot com --remote-debug. (O editor em si nao usa a pasta.)
function Conferir-Processos {
	$abertos = @(Get-CimInstance Win32_Process | Where-Object {
		$_.Name -like 'GameHub*' -or
		($_.Name -like 'Godot*' -and $_.CommandLine -match '(\s-s\s|--headless|--main-pack|--remote-debug)')
	})
	if ($abertos.Count -gt 0) {
		Write-Output 'Feche antes o hub (ou a Godot de teste) que esta aberto:'
		foreach ($p in $abertos) { Write-Output ("  " + $p.ProcessId + "  " + $p.Name) }
		exit 1
	}
}

Write-Output ("Pasta: " + $Raiz)
if (-not (Test-Path -LiteralPath $Raiz)) {
	Write-Output 'A pasta de cima nao existe. Confira o -Raiz.'
	exit 1
}

switch ($Acao) {
	'estado' {
		Mostrar-Estado
	}
	'guardar' {
		if (Test-Path -LiteralPath $guardada) {
			Write-Output 'Ja existe uma "Game Hub.guardado". Rode "devolver" antes (nada foi mexido).'
			exit 1
		}
		if (-not (Test-Path -LiteralPath $pasta)) {
			Write-Output 'Nao ha "Game Hub" para guardar: o hub ja vai abrir como num PC limpo.'
			exit 0
		}
		Conferir-Processos
		Rename-Item -LiteralPath $pasta -NewName 'Game Hub.guardado'
		Write-Output 'Guardado: "Game Hub" agora e "Game Hub.guardado".'
		Write-Output 'Abra o hub para testar. Depois rode "devolver".'
		Mostrar-Estado
	}
	'devolver' {
		if (-not (Test-Path -LiteralPath $guardada)) {
			Write-Output 'Nao ha "Game Hub.guardado" para devolver (nada foi mexido).'
			exit 1
		}
		Conferir-Processos
		if (Test-Path -LiteralPath $pasta) {
			$nome = 'Game Hub.teste-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
			Rename-Item -LiteralPath $pasta -NewName $nome
			Write-Output ('A pasta do teste virou "' + $nome + '" (apague quando quiser).')
		}
		Rename-Item -LiteralPath $guardada -NewName 'Game Hub'
		Write-Output 'Devolvido: os seus dados voltaram para "Game Hub".'
		if (-not (Test-Path -LiteralPath (Join-Path $pasta 'config.cfg'))) {
			Write-Output 'Aviso: a pasta devolvida nao tem config.cfg (confira).'
		}
		Mostrar-Estado
	}
}
