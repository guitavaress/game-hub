"""Testes dos rótulos do gabarito de capturas (C.2). Sem Godot."""
import os
import sys
import tempfile
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
    """C.2.1 e C.2.2: só uma pasta nova, e o gabarito só sai com todas as rodadas boas."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.pasta = self._tmp.name

    def png(self, nome):
        with open(os.path.join(self.pasta, nome), "wb") as f:
            f.write(b"x")

    def test_saida_relativa_vira_absoluta(self):
        nova = os.path.join(self.pasta, "nova")
        self.assertEqual(g.preparar_saida(os.path.relpath(nova)), os.path.abspath(nova))

    def test_saida_dentro_do_repositorio_e_recusada(self):
        with self.assertRaises(ValueError):
            g.preparar_saida(os.path.join(g.comum.PROJETO, "capturas"))

    def test_pasta_com_qualquer_coisa_e_recusada(self):
        # O gerador nunca mexe num gabarito que já existe: nem o manifesto, nem os PNG.
        self.assertEqual(g.preparar_saida(self.pasta), os.path.abspath(self.pasta))  # vazia: ok
        self.png("praca_13h_normal.png")
        with self.assertRaises(ValueError):
            g.preparar_saida(self.pasta)

    def test_rodada_que_falhou_impede_publicar(self):
        self.png("a.png")
        casos = [{"id": "a", "arquivo": "a.png"}]
        self.assertEqual(g.problemas_para_publicar([], casos, self.pasta), [])
        self.assertTrue(g.problemas_para_publicar(["portao/normal: x"], casos, self.pasta))

    def test_nenhuma_captura_ou_png_faltando_impede_publicar(self):
        self.assertTrue(g.problemas_para_publicar([], [], self.pasta))
        problemas = g.problemas_para_publicar([], [{"id": "falta", "arquivo": "falta.png"}], self.pasta)
        self.assertIn("falta", problemas[0])

    def test_manifesto_gravado_inteiro(self):
        g.gravar_manifesto(self.pasta, [{"id": "a"}, {"id": "b"}])
        with open(os.path.join(self.pasta, "capturas.jsonl"), encoding="utf-8") as f:
            self.assertEqual(len(f.readlines()), 2)
        self.assertFalse(os.path.exists(os.path.join(self.pasta, "capturas.jsonl.tmp")))


GEO = {"variante_aplicada": True, "pontos": {"praca": {}, "cima": {}}}
TODAS = ["rpg_praca_13h.png", "rpg_praca_22h.png", "rpg_cima_13h.png", "rpg_cima_22h.png"]


class TesteRodada(unittest.TestCase):
    """C.2.2: a saída da Godot não basta; a rodada precisa da variante e de todas as capturas."""

    def test_rodada_completa_vale(self):
        self.assertEqual(g.checar_rodada(0, GEO, TODAS, "13,22"), "")
        self.assertEqual(g.checar_rodada(3221225477, GEO, TODAS, "13,22"), "")

    def test_queda_no_meio_com_captura_faltando(self):
        # Caiu com 0xC0000005 depois de salvar só parte: a saída é "aceita", mas falta captura.
        self.assertIn("faltando", g.checar_rodada(3221225477, GEO, TODAS[:3], "13,22"))

    def test_variante_nao_aplicada_e_recusada(self):
        geo = dict(GEO, variante_aplicada=False)
        self.assertIn("variante", g.checar_rodada(0, geo, TODAS, "13,22"))
        self.assertIn("variante", g.checar_rodada(0, {"pontos": GEO["pontos"]}, TODAS, "13,22"))

    def test_saida_ruim_e_sem_geometria(self):
        self.assertIn("saiu", g.checar_rodada(1, GEO, TODAS, "13,22"))
        self.assertIn("geometria", g.checar_rodada(0, None, TODAS, "13,22"))
        self.assertIn("ponto", g.checar_rodada(0, {"variante_aplicada": True, "pontos": {}}, [], "13"))


if __name__ == "__main__":
    unittest.main()
