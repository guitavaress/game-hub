"""Régua de pixels: mede uma captura de tela PNG só com código.

Por que existe: o spike "Jev nas capturas" (docs/plans/ferramenta-jev-capturas.md)
compara o Jev com uma régua de código. Esta régua lê o PNG pronto (1280x720, salvo
pela Godot 4.7 com filtros adaptativos do libpng) e calcula brilho, quantidade de
branco e de preto e o brilho do céu. Assim ela não disputa a Godot com o gerador de
capturas e vale para qualquer pasta de capturas, inclusive as antigas.

Só usa a biblioteca padrão do Python (sem Pillow e sem numpy).

Uso na linha de comando:
    python tools/jev/capturas/regua_pixels.py <png> [<png>...]
Imprime um JSON por arquivo.
"""

import json
import struct
import sys
import zlib
from itertools import accumulate

ASSINATURA_PNG = b"\x89PNG\r\n\x1a\n"

# Tipos de cor aceitos: 2 = RGB (3 canais) e 6 = RGBA (4 canais).
CANAIS_POR_TIPO = {2: 3, 6: 4}

# Cache das máscaras usadas para somar duas linhas byte a byte (filtro Up).
_MASCARAS: dict[int, tuple[int, int]] = {}


def _somar_linhas(a: bytes, b: bytes) -> bytes:
    """Soma duas linhas byte a byte (módulo 256), de uma vez só.

    Truque: tratamos a linha inteira como um número grande. Somamos os 7 bits
    de baixo de cada byte e depois acertamos o bit de cima com um XOR, assim o
    "vai um" de um byte nunca invade o byte vizinho.
    """
    n = len(a)
    if n not in _MASCARAS:
        _MASCARAS[n] = (int.from_bytes(b"\x7f" * n, "big"), int.from_bytes(b"\x80" * n, "big"))
    baixo, alto = _MASCARAS[n]
    ia = int.from_bytes(a, "big")
    ib = int.from_bytes(b, "big")
    soma = ((ia & baixo) + (ib & baixo)) ^ ((ia ^ ib) & alto)
    return soma.to_bytes(n, "big")


def _ler_cabecalho(corpo: bytes) -> tuple[int, int, int]:
    """Confere o chunk IHDR e devolve (largura, altura, canais)."""
    if len(corpo) != 13:
        raise ValueError("PNG inválido: o cabeçalho (IHDR) tem tamanho errado.")
    largura, altura, profundidade, tipo_cor, compressao, filtro, entrelacado = struct.unpack(
        ">IIBBBBB", corpo
    )
    if tipo_cor == 3:
        raise ValueError("PNG com paleta (tipo de cor 3) não é suportado; só RGB e RGBA.")
    if tipo_cor not in CANAIS_POR_TIPO:
        raise ValueError(f"Tipo de cor {tipo_cor} não é suportado; só RGB (2) e RGBA (6).")
    if profundidade != 8:
        raise ValueError(f"PNG de {profundidade} bits não é suportado; só 8 bits por canal.")
    if entrelacado != 0:
        raise ValueError("PNG entrelaçado (Adam7) não é suportado.")
    if compressao != 0 or filtro != 0:
        raise ValueError("PNG com método de compressão ou de filtro desconhecido.")
    if largura == 0 or altura == 0:
        raise ValueError("PNG inválido: largura ou altura zero.")
    return largura, altura, CANAIS_POR_TIPO[tipo_cor]


def ler_png(caminho):
    """Decodifica um PNG de 8 bits, RGB ou RGBA, sem entrelaçamento.

    Devolve (largura, altura, canais, linhas). `linhas` é uma lista de `bytes`
    (uma por linha, sem o byte de filtro), com os canais intercalados (RGBRGB...).
    Qualquer outro formato levanta ValueError com uma mensagem em português.
    """
    with open(caminho, "rb") as arquivo:
        dados = arquivo.read()
    if dados[:8] != ASSINATURA_PNG:
        raise ValueError("Não é um PNG: a assinatura do arquivo está errada.")

    # 1) Percorre os chunks: guarda o cabeçalho e junta todos os IDAT.
    pos = 8
    cabecalho = None
    pedacos = []
    while pos + 8 <= len(dados):
        tamanho, tipo = struct.unpack(">I4s", dados[pos : pos + 8])
        corpo = dados[pos + 8 : pos + 8 + tamanho]
        if len(corpo) < tamanho:
            raise ValueError("PNG cortado: um chunk está incompleto.")
        pos += 12 + tamanho  # 4 de tamanho + 4 de tipo + corpo + 4 de CRC
        if tipo == b"IHDR":
            cabecalho = _ler_cabecalho(corpo)
        elif tipo == b"IDAT":
            pedacos.append(corpo)
        elif tipo == b"IEND":
            break
    if cabecalho is None:
        raise ValueError("PNG inválido: falta o cabeçalho (IHDR).")
    if not pedacos:
        raise ValueError("PNG inválido: não há dados de imagem (IDAT).")
    largura, altura, canais = cabecalho

    # 2) Descomprime e confere o tamanho.
    try:
        bruto = zlib.decompress(b"".join(pedacos))
    except zlib.error as erro:
        raise ValueError(f"PNG com dados de imagem corrompidos: {erro}") from erro
    passo_linha = largura * canais
    if len(bruto) < altura * (passo_linha + 1):
        raise ValueError("PNG cortado: faltam dados de imagem.")

    # 3) Desfaz o filtro de cada linha, como na especificação PNG.
    #    Para Sub, Average e Paeth cada canal (R, G, B, A) depende só dele mesmo,
    #    então tratamos um canal por vez; isso deixa o laço de Python bem mais leve.
    linhas = []
    anterior = bytes(passo_linha)
    for y in range(altura):
        inicio = y * (passo_linha + 1)
        filtro = bruto[inicio]
        cru = bruto[inicio + 1 : inicio + 1 + passo_linha]

        if filtro == 0:  # None
            atual = cru
        elif filtro == 1:  # Sub: soma o pixel da esquerda (soma acumulada por canal)
            atual = bytearray(passo_linha)
            for c in range(canais):
                atual[c::canais] = bytes(v & 255 for v in accumulate(cru[c::canais]))
        elif filtro == 2:  # Up: soma o pixel de cima
            atual = _somar_linhas(cru, anterior)
        elif filtro == 3:  # Average: soma a média de esquerda e cima
            atual = bytearray(passo_linha)
            for c in range(canais):
                saida = bytearray()
                juntar = saida.append
                a = 0
                for x, b in zip(cru[c::canais], anterior[c::canais]):
                    a = (x + ((a + b) >> 1)) & 255
                    juntar(a)
                atual[c::canais] = saida
        elif filtro == 4:  # Paeth: escolhe o vizinho mais próximo de a + b - c
            atual = bytearray(passo_linha)
            for c0 in range(canais):
                saida = bytearray()
                juntar = saida.append
                a = 0  # esquerda
                c = 0  # esquerda-acima
                for x, b in zip(cru[c0::canais], anterior[c0::canais]):  # b = acima
                    pa = b - c
                    if pa < 0:
                        pa = -pa
                    pb = a - c
                    if pb < 0:
                        pb = -pb
                    pc = a + b - c - c
                    if pc < 0:
                        pc = -pc
                    if pa <= pb and pa <= pc:
                        a = (x + a) & 255
                    elif pb <= pc:
                        a = (x + b) & 255
                    else:
                        a = (x + c) & 255
                    juntar(a)
                    c = b
                atual[c0::canais] = saida
        else:
            raise ValueError(f"PNG com filtro desconhecido ({filtro}) na linha {y}.")

        atual = bytes(atual)
        linhas.append(atual)
        anterior = atual
    return largura, altura, canais, linhas


def medir(caminho, passo=4):
    """Mede a captura, amostrando um pixel a cada `passo` em x e em y.

    Tudo é float entre 0 e 1 (4 casas), menos `largura` e `altura` (int):
      brilho_medio            média da luma de todos os pixels amostrados
      fracao_quase_branco     fração com luma >= 0.96
      fracao_quase_preto      fração com luma <= 0.04
      brilho_ceu              luma média dos 20% de cima da imagem
      fracao_estourado_baixo  fração com luma >= 0.98 nos 60% de baixo (o chão)
      fracao_escura_baixo     fração com luma <= 0.25 nos 60% de baixo (manchas escuras no
                              chão de neve: pinheiros, rochas, sombras)
    """
    passo = max(1, int(passo))
    largura, altura, canais, linhas = ler_png(caminho)

    # Limites na escala 0..255 (evita dividir cada pixel por 255).
    lim_branco = 0.96 * 255
    lim_preto = 0.04 * 255
    lim_estourado = 0.98 * 255
    lim_escuro = 0.25 * 255

    topo_fim = max(1, round(altura * 0.2))  # linhas y < topo_fim são o céu
    baixo_ini = altura - max(1, round(altura * 0.6))  # linhas y >= baixo_ini são o chão

    total = 0.0
    n = 0
    brancos = 0
    pretos = 0
    soma_ceu = 0.0
    n_ceu = 0
    estourados = 0
    escuros_baixo = 0
    n_baixo = 0

    salto = passo * canais
    for y in range(0, altura, passo):
        linha = linhas[y]
        lumas = [
            0.2126 * r + 0.7152 * g + 0.0722 * b
            for r, g, b in zip(linha[0::salto], linha[1::salto], linha[2::salto])
        ]
        total += sum(lumas)
        n += len(lumas)
        brancos += sum(1 for v in lumas if v >= lim_branco)
        pretos += sum(1 for v in lumas if v <= lim_preto)
        if y < topo_fim:
            soma_ceu += sum(lumas)
            n_ceu += len(lumas)
        if y >= baixo_ini:
            estourados += sum(1 for v in lumas if v >= lim_estourado)
            escuros_baixo += sum(1 for v in lumas if v <= lim_escuro)
            n_baixo += len(lumas)

    def norm(valor: float, divisor: int) -> float:
        return round(valor / divisor, 4) if divisor else 0.0

    return {
        "brilho_medio": norm(total / 255, n),
        "fracao_quase_branco": norm(brancos, n),
        "fracao_quase_preto": norm(pretos, n),
        "brilho_ceu": norm(soma_ceu / 255, n_ceu),
        "fracao_estourado_baixo": norm(estourados, n_baixo),
        "fracao_escura_baixo": norm(escuros_baixo, n_baixo),
        "largura": largura,
        "altura": altura,
    }


def main(argv) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if not argv:
        print("Uso: python tools/jev/capturas/regua_pixels.py <png> [<png>...]")
        return 2
    codigo = 0
    for caminho in argv:
        try:
            saida = {"arquivo": caminho, **medir(caminho)}
        except (ValueError, OSError) as erro:
            saida = {"arquivo": caminho, "erro": str(erro)}
            codigo = 1
        print(json.dumps(saida, ensure_ascii=False))
    return codigo


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
