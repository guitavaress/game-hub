"""Testes da régua de pixels (regua_pixels.py).

Os PNG são gerados aqui mesmo, com um gravador próprio que aplica cada filtro de
verdade (0 a 4), e ficam numa pasta temporária; nada sobra no repositório.
"""

import binascii
import os
import random
import struct
import sys
import tempfile
import time
import unittest
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import regua_pixels  # noqa: E402


# ---------------------------------------------------------------------------
# Gravador de PNG para os testes (independente do leitor)
# ---------------------------------------------------------------------------

def _chunk(tipo: bytes, dados: bytes) -> bytes:
    crc = binascii.crc32(tipo + dados) & 0xFFFFFFFF
    return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", crc)


def _filtrar_linha(filtro: int, cru: bytes, anterior: bytes, bpp: int) -> bytes:
    """Aplica o filtro PNG a uma linha (o inverso do que o leitor faz)."""
    saida = bytearray(len(cru))
    for i in range(len(cru)):
        a = cru[i - bpp] if i >= bpp else 0
        b = anterior[i]
        c = anterior[i - bpp] if i >= bpp else 0
        if filtro == 0:
            previsao = 0
        elif filtro == 1:
            previsao = a
        elif filtro == 2:
            previsao = b
        elif filtro == 3:
            previsao = (a + b) // 2
        else:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            if pa <= pb and pa <= pc:
                previsao = a
            elif pb <= pc:
                previsao = b
            else:
                previsao = c
        saida[i] = (cru[i] - previsao) & 255
    return bytes(saida)


def gravar_bruto(caminho, largura, altura, tipo_cor, profundidade, bruto, entrelacado=0):
    """Grava um PNG com os dados já filtrados (inclui o byte de filtro de cada linha)."""
    ihdr = struct.pack(">IIBBBBB", largura, altura, profundidade, tipo_cor, 0, 0, entrelacado)
    with open(caminho, "wb") as f:
        f.write(regua_pixels.ASSINATURA_PNG)
        f.write(_chunk(b"IHDR", ihdr))
        f.write(_chunk(b"IDAT", zlib.compress(bruto)))
        f.write(_chunk(b"IEND", b""))


def gravar_png(caminho, largura, altura, canais, linhas, filtro=0):
    """Grava RGB (canais=3) ou RGBA (canais=4). `filtro` é um número (0 a 4)
    ou uma lista de filtros que se repete de linha em linha."""
    filtros = [filtro] if isinstance(filtro, int) else list(filtro)
    anterior = bytes(largura * canais)
    partes = []
    for y, linha in enumerate(linhas):
        f = filtros[y % len(filtros)]
        partes.append(bytes([f]) + _filtrar_linha(f, linha, anterior, canais))
        anterior = linha
    gravar_bruto(caminho, largura, altura, 6 if canais == 4 else 2, 8, b"".join(partes))


def imagem_gradiente(largura, altura, canais):
    return [
        bytes((x * 7 + y * 13 + c * 50) % 256 for x in range(largura) for c in range(canais))
        for y in range(altura)
    ]


def imagem_ruido(largura, altura, canais, semente=1234):
    rng = random.Random(semente)
    return [bytes(rng.randrange(256) for _ in range(largura * canais)) for _ in range(altura)]


def imagem_por_linha(largura, altura, canais, cor_da_linha):
    """Imagem em que cada linha y tem a cor (r, g, b) devolvida por cor_da_linha(y)."""
    linhas = []
    for y in range(altura):
        r, g, b = cor_da_linha(y)
        pixel = bytes([r, g, b, 255][:canais])
        linhas.append(pixel * largura)
    return linhas


def luma(r, g, b):
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


# ---------------------------------------------------------------------------
# Testes
# ---------------------------------------------------------------------------

class TestLerPng(unittest.TestCase):
    def setUp(self):
        self._pasta = tempfile.TemporaryDirectory()
        self.addCleanup(self._pasta.cleanup)
        self.pasta = self._pasta.name

    def caminho(self, nome="t.png"):
        return os.path.join(self.pasta, nome)

    def test_cada_filtro_e_cada_tipo_de_cor(self):
        tamanhos = [(7, 5), (13, 9), (1, 4), (16, 3)]  # inclui larguras ímpares
        for canais in (3, 4):
            for filtro in range(5):
                for largura, altura in tamanhos:
                    for nome, fabrica in (("gradiente", imagem_gradiente), ("ruido", imagem_ruido)):
                        with self.subTest(canais=canais, filtro=filtro, tam=(largura, altura), img=nome):
                            linhas = fabrica(largura, altura, canais)
                            gravar_png(self.caminho(), largura, altura, canais, linhas, filtro)
                            l, a, c, lidas = regua_pixels.ler_png(self.caminho())
                            self.assertEqual((l, a, c), (largura, altura, canais))
                            self.assertEqual([bytes(x) for x in lidas], linhas)

    def test_filtros_misturados_na_mesma_imagem(self):
        for canais in (3, 4):
            with self.subTest(canais=canais):
                linhas = imagem_ruido(11, 15, canais, semente=7)
                gravar_png(self.caminho(), 11, 15, canais, linhas, [4, 1, 3, 0, 2, 4, 4])
                _, _, _, lidas = regua_pixels.ler_png(self.caminho())
                self.assertEqual([bytes(x) for x in lidas], linhas)

    def test_varios_chunks_idat(self):
        # Os dados de imagem podem vir partidos em vários IDAT.
        linhas = imagem_ruido(9, 6, 3, semente=99)
        filtrado = b"".join(b"\x00" + linha for linha in linhas)
        comprimido = zlib.compress(filtrado)
        meio = len(comprimido) // 2
        ihdr = struct.pack(">IIBBBBB", 9, 6, 8, 2, 0, 0, 0)
        with open(self.caminho(), "wb") as f:
            f.write(regua_pixels.ASSINATURA_PNG)
            f.write(_chunk(b"IHDR", ihdr))
            f.write(_chunk(b"IDAT", comprimido[:meio]))
            f.write(_chunk(b"IDAT", comprimido[meio:]))
            f.write(_chunk(b"IEND", b""))
        _, _, _, lidas = regua_pixels.ler_png(self.caminho())
        self.assertEqual([bytes(x) for x in lidas], linhas)

    def test_paleta_levanta_erro(self):
        gravar_bruto(self.caminho(), 2, 2, 3, 8, b"\x00\x00\x00" * 2)
        with self.assertRaises(ValueError):
            regua_pixels.ler_png(self.caminho())

    def test_16_bits_levanta_erro(self):
        gravar_bruto(self.caminho(), 2, 2, 2, 16, (b"\x00" + bytes(12)) * 2)
        with self.assertRaises(ValueError):
            regua_pixels.ler_png(self.caminho())

    def test_entrelacado_levanta_erro(self):
        gravar_bruto(self.caminho(), 2, 2, 2, 8, (b"\x00" + bytes(6)) * 2, entrelacado=1)
        with self.assertRaises(ValueError):
            regua_pixels.ler_png(self.caminho())

    def test_assinatura_errada_levanta_erro(self):
        with open(self.caminho(), "wb") as f:
            f.write(b"isto nao e um png de jeito nenhum")
        with self.assertRaises(ValueError):
            regua_pixels.ler_png(self.caminho())

    def test_dados_cortados_levantam_erro(self):
        # Diz que tem 4 linhas, mas só entrega 1.
        gravar_bruto(self.caminho(), 2, 4, 2, 8, b"\x00" + bytes(6))
        with self.assertRaises(ValueError):
            regua_pixels.ler_png(self.caminho())


class TestMedir(unittest.TestCase):
    def setUp(self):
        self._pasta = tempfile.TemporaryDirectory()
        self.addCleanup(self._pasta.cleanup)
        self.arquivo = os.path.join(self._pasta.name, "t.png")

    def medir_linhas(self, largura, altura, canais, linhas, filtro=4, **kw):
        gravar_png(self.arquivo, largura, altura, canais, linhas, filtro)
        return regua_pixels.medir(self.arquivo, **kw)

    def test_toda_branca(self):
        for canais in (3, 4):
            with self.subTest(canais=canais):
                m = self.medir_linhas(64, 40, canais, imagem_por_linha(64, 40, canais, lambda y: (255, 255, 255)))
                self.assertEqual(m["brilho_medio"], 1.0)
                self.assertEqual(m["fracao_quase_branco"], 1.0)
                self.assertEqual(m["fracao_quase_preto"], 0.0)
                self.assertEqual(m["brilho_ceu"], 1.0)
                self.assertEqual(m["fracao_estourado_baixo"], 1.0)
                self.assertEqual((m["largura"], m["altura"]), (64, 40))

    def test_toda_preta(self):
        m = self.medir_linhas(64, 40, 3, imagem_por_linha(64, 40, 3, lambda y: (0, 0, 0)))
        self.assertEqual(m["brilho_medio"], 0.0)
        self.assertEqual(m["fracao_quase_branco"], 0.0)
        self.assertEqual(m["fracao_quase_preto"], 1.0)
        self.assertEqual(m["brilho_ceu"], 0.0)
        self.assertEqual(m["fracao_estourado_baixo"], 0.0)

    def test_cima_clara_e_baixo_escuro(self):
        # 40 linhas; amostradas a cada 4: metade de cima (5 linhas) clara, metade de baixo escura.
        clara, escura = 200, 20
        m = self.medir_linhas(
            64, 40, 3,
            imagem_por_linha(64, 40, 3, lambda y: (clara,) * 3 if y < 20 else (escura,) * 3),
        )
        self.assertAlmostEqual(m["brilho_ceu"], clara / 255, places=4)
        self.assertAlmostEqual(m["brilho_medio"], (clara + escura) / 2 / 255, places=4)
        self.assertEqual(m["fracao_estourado_baixo"], 0.0)
        self.assertEqual(m["fracao_quase_branco"], 0.0)
        self.assertEqual(m["fracao_quase_preto"], 0.0)

    def test_chao_branco_estourado(self):
        # Céu azul nas 16 linhas de cima (40%); chão branco nos 60% de baixo.
        ceu = (100, 150, 255)
        m = self.medir_linhas(
            64, 40, 3,
            imagem_por_linha(64, 40, 3, lambda y: ceu if y < 16 else (255, 255, 255)),
        )
        self.assertEqual(m["fracao_estourado_baixo"], 1.0)
        self.assertAlmostEqual(m["brilho_ceu"], luma(*ceu), places=4)
        # Das 10 linhas amostradas, 4 são céu (não estourado) e 6 são chão branco.
        self.assertAlmostEqual(m["fracao_quase_branco"], 0.6, places=4)

    def test_alfa_e_ignorado(self):
        opaca = imagem_por_linha(32, 20, 4, lambda y: (255, 255, 255))
        transparente = [bytes([255, 255, 255, 0]) * 32 for _ in range(20)]
        a = self.medir_linhas(32, 20, 4, opaca)
        b = self.medir_linhas(32, 20, 4, transparente)
        self.assertEqual(a, b)

    def test_passo_1_e_o_padrao_dao_o_mesmo_numa_imagem_uniforme(self):
        linhas = imagem_por_linha(32, 20, 3, lambda y: (60, 120, 180))
        gravar_png(self.arquivo, 32, 20, 3, linhas, 2)
        self.assertEqual(regua_pixels.medir(self.arquivo, passo=1), regua_pixels.medir(self.arquivo))

    def test_valores_arredondados_a_4_casas(self):
        linhas = imagem_por_linha(32, 20, 3, lambda y: (1, 2, 3))
        m = self.medir_linhas(32, 20, 3, linhas)
        for chave in ("brilho_medio", "fracao_quase_branco", "fracao_quase_preto", "brilho_ceu", "fracao_estourado_baixo"):
            self.assertEqual(m[chave], round(m[chave], 4))
        self.assertIsInstance(m["largura"], int)
        self.assertIsInstance(m["altura"], int)


class TestDesempenho(unittest.TestCase):
    def test_1280x720_com_paeth(self):
        largura, altura = 1280, 720
        rng = random.Random(42)
        passo_linha = largura * 3
        # Dados "filtrados" aleatórios, todos marcados como Paeth: o leitor faz o mesmo
        # trabalho de uma captura de verdade (a imagem resultante não importa aqui).
        bruto = b"".join(b"\x04" + rng.randbytes(passo_linha) for _ in range(altura))
        with tempfile.TemporaryDirectory() as pasta:
            arquivo = os.path.join(pasta, "grande.png")
            gravar_bruto(arquivo, largura, altura, 2, 8, bruto)
            inicio = time.perf_counter()
            m = regua_pixels.medir(arquivo)
            duracao = time.perf_counter() - inicio
        print(f"\n[desempenho] medir 1280x720 Paeth: {duracao:.2f} s")
        self.assertEqual((m["largura"], m["altura"]), (largura, altura))
        self.assertLess(duracao, 6.0)


if __name__ == "__main__":
    unittest.main()
