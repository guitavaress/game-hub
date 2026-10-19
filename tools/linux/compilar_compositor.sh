#!/bin/bash
# Compila o compositor do hub (Fase 14, parte 2) e põe o .so onde a Godot procura.
#
# Uso, da raiz do projeto (só no Linux):
#   bash tools/linux/compilar_compositor.sh
#
# Precisa do Rust (instalado uma vez com: mise use -g rust@stable).
# A primeira vez demora uns minutos e o Cargo baixa os crates fixados no
# Cargo.lock (todos já aprovados; a lista de licenças é conferida no fim).
# Depois, o hub abre os apps dentro dos telões. Sem compilar, o hub segue
# funcionando e abre os apps fora, como na parte 1 da Fase 14.

cd "$(dirname "$0")/../.." || exit 1

if [ "$(uname -s)" != "Linux" ]; then
	echo "O compositor é só para Linux. No Windows, o hub abre os apps fora."
	exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
	echo "Não achei o Rust (cargo). Instale com: mise use -g rust@stable"
	exit 1
fi

echo "== compilando (versão otimizada) =="
cargo build --release --locked --manifest-path native/compositor/Cargo.toml || {
	echo "A compilação falhou (veja a mensagem acima)."
	exit 1
}

mkdir -p native/bin
cp native/compositor/target/release/libhub_compositor.so native/bin/
echo "== pronto: native/bin/libhub_compositor.so ($(du -h native/bin/libhub_compositor.so | cut -f1)) =="

bash tools/linux/checar_licencas.sh
