"""Testes da triagem (J.3): a tabela de decisão, a base e o portão. Sem Godot e sem rede."""
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(__file__))
import avaliar  # noqa: E402
import comum  # noqa: E402
import jev  # noqa: E402
import perguntas  # noqa: E402
import triar_falhas as tf  # noqa: E402


def caso(teste="check_gates", saida=1, status="FALHOU", passou=False, diff=()):
    return {"teste": teste, "resumo_bateria": [], "diff": list(diff),
            "rodada2": {"saida": saida, "status": status, "passou": passou,
                        "tempo_esgotado": saida == comum.SAIDA_TEMPO_ESGOTADO}}


NADA = {"jogo_faltando": 0.0}
FALTA = {"jogo_faltando": 1.0}


PREDIO = "\n".join(['ERROR: Node not found: "Building_2379780/GamePortal"',
                    "SCRIPT ERROR: Attempt to call function 'x' in base 'null instance'"])


TODOS = set(comum.JOGOS_EXIGIDOS)            # a biblioteca com os 4 jogos exigidos
SEM_BALATRO = TODOS - {2379780}


class TesteRegras(unittest.TestCase):
    """A tabela que a ferramenta usa (só código)."""

    def test_cada_linha_da_tabela(self):
        r = tf.categoria_regras
        self.assertEqual(r(caso(comum.FALHA_SEM_GODOT, None, "sem godot"), "", TODOS)[0], "ambiente")
        self.assertEqual(r(caso(saida=0, status="ok", passou=True), "", TODOS)[0], "instavel")
        self.assertEqual(r(caso(), 'SCRIPT ERROR: Parse Error: Function "_cehck()" not found', TODOS)[0],
                         "erro_de_script")
        self.assertEqual(r(caso(saida=124, status="ERRO DE SCRIPT"), PREDIO, SEM_BALATRO)[0], "ambiente")
        self.assertEqual(r(caso(), "SCRIPT ERROR: Invalid call. Nonexistent function 'x'", TODOS)[0],
                         "erro_de_script")
        self.assertEqual(r(caso(saida=124), "", TODOS)[0], "tempo_esgotado")
        self.assertEqual(r(caso(), "  [FALHOU] um pórtico por bairro", TODOS)[0], "regressao")

    def test_predio_sem_portal_com_jogo_instalado_e_do_codigo(self):
        # Achado da revisão do Codex (J.3.1): uma mudança que tira o GamePortal do prédio dá a
        # mesma mensagem "Node not found". Com o jogo instalado, a culpa é do código.
        r = tf.categoria_regras
        self.assertEqual(r(caso(status="ERRO DE SCRIPT"), PREDIO, TODOS)[0], "erro_de_script")
        sem_script = 'ERROR: Node not found: "Building_2379780/GamePortal"\n  [FALHOU] jogador na porta'
        self.assertEqual(r(caso(), sem_script, TODOS)[0], "regressao")

    def test_sem_saber_a_biblioteca_nao_culpa_o_ambiente(self):
        self.assertEqual(tf.categoria_regras(caso(status="ERRO DE SCRIPT"), PREDIO, None)[0], "erro_de_script")

    def test_compilacao_vence_o_predio(self):
        # Um erro de compilação derruba a cidade e também some prédio: a causa é o código.
        log = PREDIO + '\nSCRIPT ERROR: Parse Error: Cannot find member "connectx"'
        self.assertEqual(tf.categoria_regras(caso(), log, SEM_BALATRO)[0], "erro_de_script")

    def test_frase_de_ambiente_mostra_o_jogo_e_o_predio(self):
        frase = tf.categoria_regras(caso(), PREDIO, SEM_BALATRO)[1]
        self.assertIn("Balatro (2379780)", frase)
        self.assertIn("Building_2379780", frase)

    def test_base_do_plano_erra_o_predio(self):
        self.assertEqual(tf.categoria_base(caso(status="ERRO DE SCRIPT"), PREDIO)[0], "erro_de_script")
        self.assertEqual(tf.categoria_base(caso(), "ERROR: Failed loading resource: res://a.png")[0], "ambiente")

    def test_ligacao(self):
        c = caso(diff=["tests/check_gates.gd", "worlds/city/gate_builder.gd", "ui/hud.gd"])
        self.assertEqual(tf.ligados_ao_diff(c, "erro em gate_builder"),
                         ["tests/check_gates.gd", "worlds/city/gate_builder.gd"])


class TesteJogosExigidos(unittest.TestCase):
    def test_sem_steam_nao_da_para_saber(self):
        with mock.patch.object(comum, "_pastas_da_steam", return_value=[]):
            self.assertIsNone(comum.apps_instalados())

    def test_state_flags_como_o_hub(self):
        # J.3.2 (revisão do Codex): manifesto sem o bit 4 do StateFlags = baixando; o hub não
        # cria o prédio, então a triagem também não pode contar o jogo como instalado.
        with tempfile.TemporaryDirectory() as tmp:
            def manifesto(app_id, flags):
                arq = os.path.join(tmp, "appmanifest_%d.acf" % app_id)
                with open(arq, "w", encoding="utf-8") as f:
                    f.write('"AppState"\n{\n\t"appid"\t\t"%d"\n\t"name"\t\t"Jogo %d"\n'
                            '\t"StateFlags"\t\t"%d"\n}\n' % (app_id, app_id, flags))
                return arq
            arqs = [manifesto(2379780, 4), manifesto(489830, 1026), manifesto(892970, 6),
                    manifesto(413150, 1028)]
            with mock.patch.object(comum, "_pastas_da_steam", return_value=[tmp]):
                with mock.patch.object(comum, "_manifestos", return_value=arqs):
                    self.assertEqual(comum.apps_instalados(), {2379780, 892970, 413150})
                    self.assertEqual(comum.exigidos_faltando(), {489830: "Skyrim"})
                    # Para esconder dos logs, entram todos, até o que está baixando.
                    self.assertIn("Jogo 489830", comum.jogos_instalados())

    def test_caminhos_linux_como_o_hub(self):
        # J.3.2: ~/.steam/root e a Steam em Flatpak, como o SteamClientLinux.
        with tempfile.TemporaryDirectory() as casa:
            flatpak = os.path.join(casa, ".var", "app", "com.valvesoftware.Steam", ".local", "share", "Steam")
            root = os.path.join(casa, ".steam", "root")
            candidatas = comum.candidatas_linux(casa)
            self.assertIn(os.path.realpath(root), candidatas)
            self.assertIn(flatpak, candidatas)
            os.makedirs(os.path.join(flatpak, "steamapps"))
            with mock.patch.object(comum.os, "name", "posix"), \
                    mock.patch.object(comum.os.path, "expanduser", return_value=casa):
                self.assertEqual(comum._pastas_da_steam(), [flatpak])


class TesteAvaliarBiblioteca(unittest.TestCase):
    def test_biblioteca_do_caso(self):
        log = 'ERROR: Node not found: "Building_892970/GamePortal"'
        antigo = {"provocacao": "ambiente_sem_jogo", "log_texto": log}
        novo = {"provocacao": "ambiente_sem_jogo", "log_texto": "", "jogo_escondido": 413150}
        outro = {"provocacao": "regressao_teste", "log_texto": log}
        self.assertEqual(avaliar.instalados_do_caso(antigo), TODOS - {892970})
        self.assertEqual(avaliar.instalados_do_caso(novo), TODOS - {413150})
        self.assertEqual(avaliar.instalados_do_caso(outro), TODOS)


class TesteTabelaComJev(unittest.TestCase):
    """A tabela medida no portão (avaliar.py), com o Jev no lugar da regra do prédio."""

    def test_regras_vem_antes_do_jev(self):
        t = tf.categoria_com_jev
        self.assertEqual(t(caso(comum.FALHA_SEM_GODOT, None, "sem godot"), "", FALTA)[0], "ambiente")
        self.assertEqual(t(caso(saida=0, status="ok", passou=True), "", FALTA)[0], "instavel")
        self.assertEqual(t(caso(), 'SCRIPT ERROR: Parse Error: x', FALTA)[0], "erro_de_script")
        self.assertEqual(t(caso(saida=124), "", NADA)[0], "tempo_esgotado")

    def test_faixa_do_meio_e_indefinido(self):
        t = tf.categoria_com_jev
        c = caso(status="ERRO DE SCRIPT")
        self.assertEqual(t(c, PREDIO, {"jogo_faltando": 0.9})[0], "ambiente")
        self.assertEqual(t(c, PREDIO, NADA)[0], "erro_de_script")
        self.assertEqual(t(c, PREDIO, {"jogo_faltando": 0.5})[0], "indefinido")
        log = "  [FALHOU] prédio do <jogo> existe"
        self.assertEqual(t(caso(), log, {"jogo_faltando": 0.1})[0], "regressao")
        self.assertEqual(t(caso(), log, {"jogo_faltando": 0.5})[0], "indefinido")

    def test_ligacao_com_jev(self):
        c = caso(diff=["tests/check_gates.gd", "worlds/city/gate_builder.gd", "ui/hud.gd"])
        outros = perguntas.arquivos_para_o_jev(c)
        self.assertEqual(outros, ["worlds/city/gate_builder.gd", "ui/hud.gd"])
        p = {"ligado_0": 0.9, "ligado_1": 0.1}
        self.assertEqual(tf.ligados_com_jev(c, p, outros),
                         ["tests/check_gates.gd", "worlds/city/gate_builder.gd"])
        self.assertIn("ligado_1", perguntas.perguntas_do_caso(c))
        self.assertNotIn("ligado_2", perguntas.perguntas_do_caso(c))


class TesteEstado(unittest.TestCase):
    def test_trecho_pega_erros_e_o_fim(self):
        log = "\n".join(["linha %d" % i for i in range(200)])
        log = log.replace("linha 10\n", "ERROR: Can't load x\n   at: a.gd\n")
        t = perguntas.trecho_do_log(log)
        self.assertIn("ERROR: Can't load x", t)
        self.assertIn("at: a.gd", t)
        self.assertIn("linha 199", t)
        self.assertNotIn("linha 100\n", t)
        self.assertLessEqual(len(perguntas.trecho_do_log("x" * 50000)), perguntas.MAX_CARACTERES + 30)

    def test_trecho_junta_repetidas_e_guarda_a_causa(self):
        causa = ['SCRIPT ERROR: Parse Error: Cannot find member "connectx"', "   at: a.gd:3"]
        efeito = ["SCRIPT ERROR: Invalid assignment on a base object of type 'Nil'.",
                  "   at: portal_shell.gd:63"]
        meio = ["linha %d" % i for i in range(3000)]
        log = "\n".join(causa + efeito * 40 + meio + ["ERROR: outro %d" % i for i in range(400)])
        t = perguntas.trecho_do_log(log)
        self.assertIn("connectx", t)                       # a causa, do começo, ficou
        self.assertIn("(repetida 40 vezes)", t)            # o efeito virou uma linha só
        self.assertEqual(t.count("type 'Nil'"), 1)
        self.assertIn("meio cortado", t)
        self.assertIn("ERROR: outro 399", t)               # o fim também ficou


class TestePortao(unittest.TestCase):
    def test_acerto_balanceado(self):
        pares = [("a", "a")] * 9 + [("a", "b")] + [("b", "a")]
        nota, por = avaliar.acerto_balanceado(pares, ["a", "b"])
        self.assertAlmostEqual(por["a"], 0.9)
        self.assertEqual(por["b"], 0.0)
        self.assertAlmostEqual(nota, 0.45)


class TesteSemChave(unittest.TestCase):
    def test_sem_chave_e_erro(self):
        with mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "", "TYPESAFE_API_KEY_FILE": "",
                                          "USERPROFILE": "/nao/existe", "HOME": "/nao/existe"}):
            with mock.patch("os.path.expanduser", return_value="/nao/existe"):
                with self.assertRaises(jev.ErroJev):
                    jev.Cliente()


if __name__ == "__main__":
    unittest.main()
