"""Testes da coleta (J.1). Rodar: python -m unittest discover tools/jev

Nenhum teste abre a Godot: a segunda rodada é simulada.
"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import coletar_falhas  # noqa: E402
import comum  # noqa: E402

SAIDA_COM_2_FALHAS = """== importando o projeto ==
check_avatar: ok
check_gates: FALHOU
    FALHOU: a porta 3 devia abrir
    RESULTADO: 1 falha(s)
check_home: ok
check_terrain: ERRO DE SCRIPT
    SCRIPT ERROR: Parse Error: Identifier "altura_maxima" not declared
check_zones: ok
cargo test: pulado (sem Rust ou fora do Linux)

RESULTADO GERAL: 2 teste(s) com problema
"""

SAIDA_OK = """== importando o projeto ==
check_avatar: ok
check_gates: ok

RESULTADO GERAL: TUDO OK
"""

SAIDA_IMPORTACAO = """== importando o projeto ==
SCRIPT ERROR: Parse Error: Unexpected "}" in res://worlds/city/city.gd
RESULTADO GERAL: erro de script ao importar
"""


def rodada_falsa(falha, godot):
    """Simula a segunda rodada: o check_gates passa (instável), o outro falha igual."""
    if falha["teste"] == "check_gates":
        return {"saida": 0, "status": "ok", "log": "RESULTADO: TUDO OK\n"}
    return {"saida": 1, "status": "ERRO DE SCRIPT", "log": "SCRIPT ERROR: ...\n"}


class TesteColeta(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.pasta = os.path.join(self.tmp.name, "coleta")

    def tearDown(self):
        self.tmp.cleanup()

    def test_duas_falhas_viram_dois_logs(self):
        entradas = coletar_falhas.coletar(SAIDA_COM_2_FALHAS, self.pasta, "godot",
                                          ["tests/check_gates.gd"], rodar=rodada_falsa)
        self.assertEqual([e["teste"] for e in entradas], ["check_gates", "check_terrain"])
        self.assertEqual(entradas[0]["resumo_bateria"],
                         ["FALHOU: a porta 3 devia abrir", "RESULTADO: 1 falha(s)"])
        self.assertTrue(entradas[0]["rodada2"]["passou"])
        self.assertFalse(entradas[1]["rodada2"]["passou"])
        logs = sorted(f for f in os.listdir(self.pasta) if f.endswith(".log"))
        self.assertEqual(logs, ["check_gates.log", "check_terrain.log"])
        with open(os.path.join(self.pasta, "coleta.json"), encoding="utf-8") as f:
            coleta = json.load(f)
        self.assertEqual(coleta["diff"], ["tests/check_gates.gd"])
        self.assertEqual(len(coleta["falhas"]), 2)

    def test_tudo_ok_nao_grava_nada(self):
        entradas = coletar_falhas.coletar(SAIDA_OK, self.pasta, "godot", [], rodar=rodada_falsa)
        self.assertEqual(entradas, [])
        self.assertFalse(os.path.exists(self.pasta))

    def test_importacao_quebrada_vira_uma_falha(self):
        falhas = coletar_falhas.ler_falhas(SAIDA_IMPORTACAO)
        self.assertEqual(len(falhas), 1)
        self.assertEqual(falhas[0]["teste"], comum.FALHA_IMPORTACAO)
        self.assertIn("city.gd", falhas[0]["resumo_bateria"][0])

    def test_godot_ausente_nao_roda_de_novo(self):
        texto = "Godot não encontrada em /x/godot (use a variável GODOT).\n"
        falhas = coletar_falhas.ler_falhas(texto)
        self.assertEqual(falhas[0]["teste"], comum.FALHA_SEM_GODOT)
        r = coletar_falhas.rodar_de_novo(falhas[0], "/x/godot")
        self.assertEqual(r["status"], "sem godot")

    def test_tempo_esgotado_vira_124(self):
        r = comum.rodar([sys.executable, "-c", "import time; time.sleep(5)"], tempo=1)
        self.assertEqual(r["saida"], comum.SAIDA_TEMPO_ESGOTADO)

    def test_veredito_igual_ao_da_bateria(self):
        self.assertEqual(comum.veredito("check_x", "RESULTADO: TUDO OK"), "ok")
        self.assertEqual(comum.veredito("check_x", "SCRIPT ERROR\nRESULTADO: TUDO OK"),
                         "ERRO DE SCRIPT")
        self.assertEqual(comum.veredito("check_phase3_cache", "cache pronta"), "ok")
        self.assertEqual(comum.veredito("check_portal_regression", "ok: a\nFALHOU: b"), "FALHOU")
        self.assertEqual(comum.veredito("check_x", ""), "FALHOU")


if __name__ == "__main__":
    unittest.main()
