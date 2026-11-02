"""Testes do conferir_capturas.py (C.4). Sem rede, sem Godot: medidas injetadas e Jev falso.

Rodar (na raiz do projeto):  python -m unittest discover tools/jev
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import conferir_capturas as cc  # noqa: E402
from test_capturas_portao import ClienteFalso, medidas_base, png_falso  # noqa: E402

DIA = medidas_base(fracao_quase_preto=0.0, brilho_medio=0.5)
NOITE = medidas_base(fracao_quase_preto=0.01, brilho_medio=0.1)
ESTOURADA = medidas_base(fracao_quase_preto=0.0, brilho_medio=0.8)
NORMAL_DE_DIA = {"dia": True, "tela_preta": False, "neve_estourada": False, "sem_pinheiros": False,
                 "torre_visivel": None}


class TestConferir(unittest.TestCase):
    def test_sem_esperado_avisa_so_defeito(self):
        self.assertEqual(cc.conferir({"id": "a"}, DIA, None)["avisos"], [])
        self.assertEqual(cc.conferir({"id": "a"}, ESTOURADA, None)["avisos"], ["neve estourada"])

    def test_noite_nao_julga_neve_nem_pinheiros(self):
        r = cc.conferir({"id": "a"}, medidas_base(fracao_quase_preto=0.01, brilho_medio=0.9),
                        {"sem_pinheiros": 0.99, "dia": 0.1})["respostas"]
        self.assertEqual((r["dia"], r["neve_estourada"], r["sem_pinheiros"]), (False, None, None))

    def test_com_esperado_avisa_a_diferenca(self):
        caso = {"id": "a", "rotulos": dict(NORMAL_DE_DIA, dia=False)}
        self.assertEqual(cc.conferir(caso, DIA, None)["avisos"], ["parece dia (esperado: parece noite)"])

    def test_erro_da_regua_do_dia_nao_esconde_os_pinheiros(self):
        # De dia de verdade, mas um pixel quase preto: a régua diz noite. Os pinheiros
        # continuam conferidos, porque o esperado diz que é dia.
        caso = {"id": "a", "rotulos": NORMAL_DE_DIA}
        l = cc.conferir(caso, NOITE, {"sem_pinheiros": 0.9, "dia": 0.95})
        self.assertTrue(l["respostas"]["sem_pinheiros"])
        self.assertIn("sem pinheiros (esperado: com pinheiros)", l["avisos"])
        self.assertIn("parece noite (esperado: parece dia)", l["avisos"])
        self.assertIn("o Jev acha que é dia", l["avisos"])

    def test_limiar_do_jev(self):
        caso = {"id": "a"}
        self.assertFalse(cc.conferir(caso, DIA, {"sem_pinheiros": 0.69})["respostas"]["sem_pinheiros"])
        self.assertTrue(cc.conferir(caso, DIA, {"sem_pinheiros": 0.70})["respostas"]["sem_pinheiros"])

    def test_torre_pela_geometria(self):
        self.assertIsNone(cc.torre_visivel({}))
        self.assertTrue(cc.torre_visivel({"torre_na_tela": True, "torre_desobstruida": True,
                                          "torre_altura_px": 25.0}))
        self.assertFalse(cc.torre_visivel({"torre_na_tela": True, "torre_desobstruida": True,
                                           "torre_altura_px": 8.0}))
        self.assertFalse(cc.torre_visivel({"torre_na_tela": True, "torre_desobstruida": False,
                                           "torre_altura_px": 80.0}))


class TestLinhaDeComando(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.pasta = self._tmp.name
        self.medidas = {}

    def png(self, id_, medidas):
        with open(os.path.join(self.pasta, id_ + ".png"), "wb") as f:
            f.write(png_falso(id_))
        self.medidas[id_ + ".png"] = medidas

    def manifesto(self, linhas):
        with open(os.path.join(self.pasta, "capturas.jsonl"), "w", encoding="utf-8") as f:
            for l in linhas:
                f.write(json.dumps(l) + "\n")

    def rodar(self, *args, cliente=None):
        saida = io.StringIO()
        with contextlib.redirect_stdout(saida):
            codigo = cc.main([self.pasta, *args], criar_cliente=lambda: cliente,
                             medir=lambda c: self.medidas[os.path.basename(c)])
        return codigo, saida.getvalue()

    def test_pasta_sem_manifesto_so_a_regua(self):
        self.png("praca", DIA)
        codigo, saida = self.rodar()
        self.assertEqual(codigo, 0)
        self.assertIn("sem capturas.jsonl", saida)
        self.assertIn("0 chamadas", saida)

    def test_sem_manifesto_o_jev_e_recusado(self):
        self.png("praca", DIA)
        cliente = ClienteFalso({"praca": {"sem_pinheiros": 0.9}})
        codigo, saida = self.rodar("--jev", cliente=cliente)
        self.assertEqual(codigo, 2)
        self.assertEqual(cliente.chamadas, 0)
        self.assertIn("capas", saida)

    def test_captura_sem_sem_capas_e_recusada_antes_de_enviar(self):
        self.png("a", DIA)
        self.png("b", DIA)
        self.manifesto([{"id": "a", "arquivo": "a.png", "sem_capas": True, "rotulos": NORMAL_DE_DIA},
                        {"id": "b", "arquivo": "b.png", "rotulos": NORMAL_DE_DIA}])
        cliente = ClienteFalso({"a": {}, "b": {}})
        codigo, _ = self.rodar("--jev", cliente=cliente)
        self.assertEqual((codigo, cliente.chamadas), (2, 0))

    def test_com_jev_aponta_os_pinheiros_sumidos(self):
        self.png("a", DIA)
        self.png("b", DIA)
        self.manifesto([{"id": i, "arquivo": i + ".png", "sem_capas": True, "rotulos": NORMAL_DE_DIA}
                        for i in ("a", "b")])
        cliente = ClienteFalso({"a": {"sem_pinheiros": 0.1, "dia": 0.9},
                                "b": {"sem_pinheiros": 0.95, "dia": 0.9}})
        codigo, saida = self.rodar("--jev", cliente=cliente)
        self.assertEqual((codigo, cliente.chamadas), (1, 2))
        self.assertIn("1 de 2 capturas", saida)
        self.assertIn("SUMIRAM", saida)
        # Rodar de novo usa as respostas guardadas: nenhuma chamada nova.
        cliente2 = ClienteFalso({})
        self.rodar("--jev", cliente=cliente2)
        self.assertEqual(cliente2.chamadas, 0)


if __name__ == "__main__":
    unittest.main()
