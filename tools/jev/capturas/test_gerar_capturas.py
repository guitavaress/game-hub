"""Testes dos rótulos do gabarito de capturas (C.2). Sem Godot."""
import os
import sys
import tempfile
import time
import unittest

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gerar_capturas as g  # noqa: E402

CLARA = {"torre_na_tela": True, "torre_altura_px": 45.0, "torre_desobstruida": True}
PEQUENA = {"torre_na_tela": True, "torre_altura_px": 8.0, "torre_desobstruida": True}
FORA = {"torre_na_tela": False, "torre_altura_px": 0.0, "torre_desobstruida": False}


class TesteRotulos(unittest.TestCase):
    def test_normal_de_dia(self):
        r = g.rotulos("normal", 0.0, CLARA)
        self.assertEqual(r, {"tela_preta": False, "dia": True, "neve_estourada": False,
                             "sem_pinheiros": False, "torre_visivel": True})

    def test_noite_nao_julga_pinheiro_nem_neve_estourada(self):
        r = g.rotulos("sem_pinheiros", 1.0, CLARA)
        self.assertEqual((r["dia"], r["sem_pinheiros"]), (False, None))
        self.assertIsNone(g.rotulos("neve_estourada", 1.0, CLARA)["neve_estourada"])
        self.assertIsNone(g.rotulos("normal", 1.0, CLARA)["sem_pinheiros"])

    def test_tela_preta_fica_fora(self):
        # A variante não ficou preta de verdade: nenhuma conferência dela entra na conta.
        r = g.rotulos("tela_preta", 0.0, CLARA)
        self.assertTrue(all(v is None for v in r.values()))

    def test_defeitos_de_dia(self):
        self.assertTrue(g.rotulos("sem_pinheiros", 0.0, CLARA)["sem_pinheiros"])
        self.assertTrue(g.rotulos("neve_estourada", 0.0, CLARA)["neve_estourada"])
        # Com a exposição alta os pinheiros continuam lá: não "sumiram".
        self.assertFalse(g.rotulos("neve_estourada", 0.0, CLARA)["sem_pinheiros"])

    def test_torre(self):
        self.assertFalse(g.rotulos("torre_escondida", 0.0, CLARA)["torre_visivel"])
        self.assertFalse(g.rotulos("normal", 0.0, FORA)["torre_visivel"])
        self.assertIsNone(g.rotulos("normal", 0.0, PEQUENA)["torre_visivel"])

    def test_hora_do_meio_e_ambigua(self):
        self.assertIsNone(g.rotulos("normal", 0.5, CLARA)["dia"])

    def test_parte(self):
        self.assertEqual(g.parte_de("ajuste", "praca"), "ajuste")
        self.assertEqual(g.parte_de("ajuste", "mirante"), "portao")
        self.assertEqual(g.parte_de("portao", "praca"), "portao")


class TestePublicar(unittest.TestCase):
    """C.2.1: o gabarito só é gravado com todas as rodadas boas, na pasta certa."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.pasta = self._tmp.name

    def png(self, nome, idade=0.0):
        caminho = os.path.join(self.pasta, nome)
        with open(caminho, "wb") as f:
            f.write(b"x")
        if idade:
            os.utime(caminho, (time.time() - idade, time.time() - idade))

    def test_saida_relativa_vira_absoluta(self):
        rel = os.path.relpath(self.pasta)
        self.assertEqual(g.preparar_saida(rel, False), os.path.abspath(self.pasta))

    def test_saida_dentro_do_repositorio_e_recusada(self):
        with self.assertRaises(ValueError):
            g.preparar_saida(os.path.join(g.comum.PROJETO, "capturas"), False)

    def test_pasta_com_gabarito_pede_substituir(self):
        with open(os.path.join(self.pasta, "capturas.jsonl"), "w") as f:
            f.write("{}\n")
        with self.assertRaises(ValueError):
            g.preparar_saida(self.pasta, False)
        self.assertEqual(g.preparar_saida(self.pasta, True), os.path.abspath(self.pasta))

    def test_rodada_que_falhou_impede_publicar(self):
        t0 = time.time() - 1
        self.png("a.png")
        casos = [{"id": "a", "arquivo": "a.png"}]
        self.assertEqual(g.problemas_para_publicar([], casos, self.pasta, t0), [])
        self.assertTrue(g.problemas_para_publicar(["portao/normal (saída 1)"], casos, self.pasta, t0))

    def test_nenhuma_captura_impede_publicar(self):
        self.assertTrue(g.problemas_para_publicar([], [], self.pasta, time.time()))

    def test_png_de_rodada_anterior_nao_conta(self):
        self.png("velho.png", idade=3600)
        casos = [{"id": "velho", "arquivo": "velho.png"}, {"id": "falta", "arquivo": "falta.png"}]
        problemas = g.problemas_para_publicar([], casos, self.pasta, time.time() - 60)
        self.assertEqual(len(problemas), 1)
        self.assertIn("velho", problemas[0])
        self.assertIn("falta", problemas[0])

    def test_manifesto_gravado_inteiro(self):
        g.gravar_manifesto(self.pasta, [{"id": "a"}, {"id": "b"}])
        with open(os.path.join(self.pasta, "capturas.jsonl"), encoding="utf-8") as f:
            self.assertEqual(len(f.readlines()), 2)
        self.assertFalse(os.path.exists(os.path.join(self.pasta, "capturas.jsonl.tmp")))


if __name__ == "__main__":
    unittest.main()
