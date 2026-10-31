"""Testes dos rótulos do gabarito de capturas (C.2). Sem Godot."""
import os
import sys
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


if __name__ == "__main__":
    unittest.main()
