"""Testes das peças do gabarito (J.2) e da limpeza dos logs. Sem Godot e sem rede."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import comum  # noqa: E402
import provocar_falhas as pf  # noqa: E402

TESTE = """extends SceneTree

func _run() -> void:
\tawait process_frame
\t_check("um pórtico por bairro", gates.size() == districts.size())
\t_check("letreiro (%.1f m)" % tallest, above)
\tprint("fim")
"""

CODIGO = """const ALTURA := 12.5  # metros
var ligado := true

func subir(x: int) -> int:
\tif x > 3:
\t\treturn atualizar_altura(x)
\treturn 0
"""


class TesteMutacoes(unittest.TestCase):
    def test_inverter_check(self):
        linhas = pf.linhas_de_check(TESTE)
        self.assertEqual(linhas, [4, 5])
        novo = pf.inverter_check(TESTE, 4)
        self.assertIn('_check("um pórtico por bairro", not (gates.size() == districts.size()))', novo)
        novo = pf.inverter_check(TESTE, 5)
        self.assertIn('_check("letreiro (%.1f m)" % tallest, not (above))', novo)

    def test_mutacao_muda_codigo_e_nao_comentario(self):
        muts = pf.mutacoes_possiveis(CODIGO)
        self.assertTrue(muts)
        # "func subir" não é mexida; o 3 do "x > 3" e o "true" são.
        self.assertNotIn(3, [m[0] for m in muts])
        mudados = {pf.aplicar_mutacao(CODIGO, *m) for m in muts}
        self.assertIn(CODIGO.replace("var ligado := true", "var ligado := false"), mudados)
        self.assertIn(CODIGO.replace("x > 3", "x <= 3"), mudados)
        self.assertIn(CODIGO.replace("12.5", "25.500"), mudados)
        self.assertTrue(all("# metros" in m for m in mudados))

    def test_errar_nome(self):
        chamadas = pf.chamadas_possiveis(CODIGO)
        nomes = [c[2] for c in chamadas]
        self.assertIn("atualizar_altura", nomes)
        self.assertNotIn("subir", nomes)  # a declaração não é chamada
        i = nomes.index("atualizar_altura")
        novo = pf.errar_nome(CODIGO, *chamadas[i])
        self.assertNotIn("atualizar_altura(", novo)
        self.assertEqual(len(novo), len(CODIGO))

    def test_inserir_laco(self):
        novo = pf.inserir_laco(TESTE)
        self.assertIn("\tawait process_frame\n\twhile true:", novo)
        self.assertEqual(pf.inserir_laco("func x():\n\tpass\n"), "")

    def test_resumo_igual_ao_da_bateria(self):
        log = "\n".join(["  [ok] a"] + ["  [FALHOU] b%d" % i for i in range(10)] + ["RESULTADO: 10 FALHA(S)"])
        resumo = pf.resumo_da_bateria(log)
        self.assertEqual(len(resumo), 8)
        self.assertEqual(resumo[0], "  [FALHOU] b0")

    def test_separar_portao_por_categoria(self):
        casos = [{"categoria": "a"} for _ in range(9)] + [{"categoria": "b"} for _ in range(3)]
        pf.separar_portao(casos)
        portao_a = sum(1 for c in casos if c["categoria"] == "a" and c["parte"] == "portao")
        portao_b = sum(1 for c in casos if c["categoria"] == "b" and c["parte"] == "portao")
        self.assertEqual((portao_a, portao_b), (3, 1))
        outra = [{"categoria": "a"} for _ in range(9)]
        pf.separar_portao(outra)
        self.assertEqual([c["parte"] for c in casos[:9]], [c["parte"] for c in outra])  # semente fixa


class TesteLimpeza(unittest.TestCase):
    def test_limpar_log(self):
        casa = os.path.expanduser("~")
        usuario = os.path.basename(casa)
        copia = os.path.join(casa, "AppData", "Local", "Temp", "provocar-1")
        log = ("ERROR: res://x.gd em %s\\tests\\a.gd\n" % copia
               + "abrindo %s/Documents\n" % casa.replace("\\", "/")
               + "git bash: /c/%s\n" % casa[3:].replace("\\", "/")
               + "olá %s, jogando Hollow Knight\n" % usuario)
        privados = [casa, usuario, "Hollow Knight"]
        limpo = comum.limpar_log(log, [copia], privados)
        self.assertIn("<projeto>", limpo)
        self.assertIn("<casa>", limpo)
        self.assertIn("<usuario>", limpo)
        self.assertIn("<jogo>", limpo)
        self.assertFalse(comum.tem_dado_privado(limpo, privados))
        self.assertTrue(comum.tem_dado_privado(log, privados))


if __name__ == "__main__":
    unittest.main()
