#!/bin/bash
# Confere a licença de todos os crates que o compositor usa (Fase 14.15).
#
# Regra do projeto (CLAUDE.md, seção Addons): só licenças permissivas, nenhum
# crate GPL. A exceção é o godot-rust (MPL-2.0), aprovada pelo dono.
# Quando um crate oferece escolha ("MIT OR Apache-2.0"), basta uma das
# opções ser permitida.
#
# Uso, da raiz do projeto: bash tools/linux/checar_licencas.sh
# Não baixa nada: usa só o que o Cargo já tem (--offline).

cd "$(dirname "$0")/../.." || exit 1
if ! command -v cargo >/dev/null 2>&1; then
	echo "licenças: pulado (sem cargo)"
	exit 0
fi

meta=$(cargo metadata --manifest-path native/compositor/Cargo.toml --format-version 1 \
	--offline --locked --filter-platform x86_64-unknown-linux-gnu 2>&1) || {
	echo "$meta" | tail -3
	echo "licenças: FALHOU (o cargo metadata não rodou)"
	exit 1
}

# A conta é em Python (vem com o Linux), lendo a lista que o Cargo deu.
script=$(cat <<'PY'
import json, re, sys

# Licenças permitidas para qualquer crate.
PERMITIDAS = {
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "Zlib", "0BSD",
    "Unlicense", "CC0-1.0", "BSL-1.0", "Unicode-3.0", "Unicode-DFS-2016",
}
# A exceção do dono (2026-10-14): o godot-rust, MPL-2.0.
EXCECAO_MPL = re.compile(r"^(godot|godot-.*|gdextension-api)$")


def aceita(expr, permitidas):
    """A expressão SPDX (ex.: "(MIT OR Apache-2.0) AND Unicode-3.0") é aceita?
    OR: basta um lado. AND: os dois lados. "A WITH exceção" vale como A."""
    tokens = re.findall(r"\(|\)|[^\s()]+", expr.replace("/", " OR "))
    pos = 0

    def ou():
        nonlocal pos
        ok = e()
        while pos < len(tokens) and tokens[pos] == "OR":
            pos += 1
            ok = e() or ok
        return ok

    def e():
        nonlocal pos
        ok = termo()
        while pos < len(tokens) and tokens[pos] == "AND":
            pos += 1
            ok = termo() and ok
        return ok

    def termo():
        nonlocal pos
        if tokens[pos] == "(":
            pos += 1
            ok = ou()
            pos += 1  # o ")"
            return ok
        nome = tokens[pos]
        pos += 1
        if pos < len(tokens) and tokens[pos] == "WITH":
            pos += 2  # "WITH LLVM-exception": a exceção só dá mais liberdade
        return nome in permitidas

    try:
        return ou() and pos == len(tokens)
    except IndexError:
        return False


meta = json.load(sys.stdin)
usados = {n["id"] for n in meta["resolve"]["nodes"]}
problemas = []
total = 0
for pkg in meta["packages"]:
    if pkg["id"] not in usados:
        continue
    total += 1
    nome, licenca = pkg["name"], pkg.get("license") or ""
    permitidas = PERMITIDAS | ({"MPL-2.0"} if EXCECAO_MPL.match(nome) else set())
    if not licenca or not aceita(licenca, permitidas):
        problemas.append("    %s %s: %s" % (nome, pkg["version"], licenca or "sem licença declarada"))
if problemas:
    print("\n".join(problemas))
    print("licenças: FALHOU (%d de %d crates fora da regra)" % (len(problemas), total))
    sys.exit(1)
print("licenças: ok (%d crates, nenhum GPL)" % total)
PY
)
echo "$meta" | python3 -I -c "$script"
