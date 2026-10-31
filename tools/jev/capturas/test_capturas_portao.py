"""Testes do portão do Jev nas capturas (C.3). Sem rede, sem Godot e sem a régua de pixels:
o gabarito é sintético (arquivos temporários), as medidas são injetadas e o Jev é um mock.

Rodar (na raiz do projeto):  python -m unittest discover tools/jev
"""
import base64
import contextlib
import io
import json
import os
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import avaliar_capturas as ac  # noqa: E402
import jev  # noqa: E402
import perguntas_capturas as pc  # noqa: E402

TODAS_NULAS = {c: None for c in pc.CONFERENCIAS}


def png_falso(id_: str) -> bytes:
    """Um PNG "de mentira": só a assinatura e o IHDR de 1280x720 (o que o jev.imagem_png lê).
    O id vai no fim, para o Jev falso saber de qual captura é o pedido."""
    return (b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1280, 720)
            + b"\x08\x02\x00\x00\x00" + b"\0\0\0\0" + id_.encode())


def medidas_base(**mudancas) -> dict:
    m = {"brilho_medio": 0.5, "fracao_quase_branco": 0.0, "fracao_quase_preto": 0.0,
         "brilho_ceu": 0.5, "fracao_estourado_baixo": 0.0, "fracao_escura_baixo": 0.1,
         "largura": 1280, "altura": 720}
    m.update(mudancas)
    return m


class ClienteFalso:
    """Um Jev de mentira: responde pelo id escondido na imagem e conta chamadas e tokens."""

    def __init__(self, respostas: dict, tokens_por_chamada: int = 3000, tokens_iniciais: int = 0,
                 falhar_na_chamada=None):
        self.respostas = respostas          # {id: {conferencia: p}}
        self.tokens_por_chamada = tokens_por_chamada
        self.tokens = tokens_iniciais
        self.chamadas = 0
        self.falhar_na_chamada = falhar_na_chamada
        self.vistos = []

    def enviar(self, corpo: dict) -> dict:
        if self.falhar_na_chamada is not None and self.chamadas == self.falhar_na_chamada:
            raise jev.ErroJev("o Jev respondeu HTTP 500 (simulado)")
        dados = base64.b64decode(corpo["assets"][pc.CHAVE_IMAGEM]["data_base64"])
        id_ = dados[33:].decode()
        self.vistos.append(id_)
        self.chamadas += 1
        self.tokens += self.tokens_por_chamada
        return {"answers": {q: {"noul": self.respostas[id_].get(q, 0.5)} for q in corpo["questions"]},
                "usage": {"input_tokens": self.tokens_por_chamada}}

    def custo(self) -> float:
        return self.tokens * jev.PRECO_POR_TOKEN

    def relatorio(self) -> str:
        return "Jev: %d chamadas, %d tokens de entrada, US$ %.4f" % (self.chamadas, self.tokens, self.custo())


class BaseComGabarito(unittest.TestCase):
    """Cria uma pasta de gabarito temporária e escreve capturas.jsonl + PNG falsos."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.pasta = self._tmp.name
        self.medidas = {}      # {nome do arquivo: medidas}
        self.respostas = {}    # {id: {conferencia: p}} do Jev falso
        self.linhas = []
        self.addCleanup(self._tmp.cleanup)

    def adicionar(self, id_, parte, dia, ceu, p_dia, sem_capas=True, rotulos=None, geometria=None,
                  **extra_medidas):
        rot = dict(TODAS_NULAS)
        rot["dia"] = dia
        rot.update(rotulos or {})
        arquivo = id_ + ".png"
        with open(os.path.join(self.pasta, arquivo), "wb") as f:
            f.write(png_falso(id_))
        linha = {"id": id_, "arquivo": arquivo, "ponto": "praca", "hora": 13, "variante": "normal",
                 "parte": parte, "rotulos": rot,
                 "geometria": geometria or {"torre_na_tela": False, "torre_altura_px": 0.0,
                                            "torre_desobstruida": False}}
        if sem_capas is not None:
            linha["sem_capas"] = sem_capas
        self.linhas.append(linha)
        self.medidas[arquivo] = medidas_base(brilho_ceu=ceu, **extra_medidas)
        self.respostas[id_] = {"dia": p_dia}

    def gravar(self):
        with open(os.path.join(self.pasta, "capturas.jsonl"), "w", encoding="utf-8") as f:
            for l in self.linhas:
                f.write(json.dumps(l) + "\n")

    def medir(self, caminho):
        self.medir_chamadas = getattr(self, "medir_chamadas", 0) + 1
        return self.medidas[os.path.basename(caminho)]

    def gabarito_bom(self):
        """Um gabarito onde o Jev vence a régua na conferência "dia" (o portão da régua erra 2 de 4)."""
        self.adicionar("a1", "ajuste", True, 0.8, 0.9)
        self.adicionar("a2", "ajuste", True, 0.9, 0.95)
        self.adicionar("a3", "ajuste", False, 0.1, 0.05)
        self.adicionar("a4", "ajuste", False, 0.2, 0.10)
        self.adicionar("p1", "portao", True, 0.9, 0.9)
        self.adicionar("p2", "portao", True, 0.3, 0.9)   # a régua erra (céu "escuro" de dia)
        self.adicionar("p3", "portao", False, 0.1, 0.1)
        self.adicionar("p4", "portao", False, 0.1, 0.1)
        self.gravar()

    def rodar(self, *args, cliente=None):
        """Roda a linha de comando; devolve (código, saída, o cliente falso)."""
        cliente = cliente or ClienteFalso(self.respostas)
        saida = io.StringIO()
        with contextlib.redirect_stdout(saida):
            codigo = ac.main(["--gabarito", self.pasta, *args], criar_cliente=lambda: cliente,
                             medir=self.medir)
        return codigo, saida.getvalue(), cliente


# ------------------------------------------------------------------ a régua

class TestChaveDaImagem(unittest.TestCase):
    def test_chave_nao_aparece_no_texto(self):
        # A API troca TODA ocorrência da chave pela imagem: com "screenshot" ela entrava no
        # meio das perguntas ("in this screenshot") e o pedido gastava 4,5x tokens.
        from perguntas_capturas import CHAVE_IMAGEM, CONTEXTO, perguntas_do_pedido, exigir_chave_unica
        texto = json.dumps({"context": CONTEXTO, "q": perguntas_do_pedido("a tall stone tower")})
        self.assertNotIn(CHAVE_IMAGEM, texto)
        exigir_chave_unica(perguntas_do_pedido("a tall stone tower"))  # não levanta
        with self.assertRaises(ValueError):
            exigir_chave_unica({"x": {"instructions": "look at %s" % CHAVE_IMAGEM}})


class TestRegua(unittest.TestCase):
    def test_cada_conferencia(self):
        m = medidas_base(brilho_ceu=0.8, brilho_medio=0.02, fracao_estourado_baixo=0.6, fracao_escura_baixo=0.3)
        self.assertTrue(ac.decide_regua("dia", m, {}, 0.7))
        self.assertFalse(ac.decide_regua("dia", m, {}, 0.9))
        self.assertTrue(ac.decide_regua("tela_preta", m, {}, 0.05))    # <=
        self.assertFalse(ac.decide_regua("tela_preta", m, {}, 0.01))
        # Neve estourada: o brilho médio (0,02 aqui), e não a fração >= 0,98.
        self.assertTrue(ac.decide_regua("neve_estourada", m, {}, 0.01))
        self.assertFalse(ac.decide_regua("neve_estourada", m, {}, 0.05))
        # Pinheiros sumidos: poucas manchas escuras no chão (<=, como a tela preta).
        self.assertTrue(ac.decide_regua("sem_pinheiros", m, {}, 0.3))
        self.assertFalse(ac.decide_regua("sem_pinheiros", m, {}, 0.2))

    def test_torre_pede_as_tres_condicoes(self):
        g = {"torre_na_tela": True, "torre_desobstruida": True, "torre_altura_px": 40.0}
        self.assertTrue(ac.decide_regua("torre_visivel", {}, g, 30))
        self.assertFalse(ac.decide_regua("torre_visivel", {}, g, 50))                         # pequena demais
        self.assertFalse(ac.decide_regua("torre_visivel", {}, dict(g, torre_na_tela=False), 0))
        self.assertFalse(ac.decide_regua("torre_visivel", {}, dict(g, torre_desobstruida=False), 0))

    def test_conferencia_desconhecida_e_erro(self):
        with self.assertRaises(ValueError):
            ac.decide_regua("outra", medidas_base(), {}, 0.5)


# ------------------------------------------------------------------ limiares no ajuste

def _caso(id_, certo, ceu, p=None, conf="dia", geometria=None):
    """Para rodar_avaliacao direto, sem arquivos."""
    c = {"id": id_, "rotulos": dict(TODAS_NULAS, **{conf: certo}), "geometria": geometria or {}}
    return c, medidas_base(brilho_ceu=ceu), p


def _montar(lista, conf="dia"):
    casos = [c for c, _, _ in lista]
    medidas = {c["id"]: m for c, m, _ in lista}
    respostas = {c["id"]: {conf: p} for c, _, p in lista if p is not None}
    return casos, medidas, respostas


class TestLimiarSoNoAjuste(unittest.TestCase):
    AJUSTE = [_caso("a1", True, 0.8, 0.9), _caso("a2", True, 0.9, 0.95),
              _caso("a3", False, 0.1, 0.05), _caso("a4", False, 0.2, 0.10)]

    def avaliar_com_portao(self, portao_lista):
        casos_a, med_a, resp_a = _montar(self.AJUSTE)
        casos_p, med_p, resp_p = _montar(portao_lista)
        medidas = {**med_a, **med_p}
        respostas = {**resp_a, **resp_p}
        return ac.rodar_avaliacao(casos_a, casos_p, medidas, respostas, ["dia"])["dia"]

    def test_limiar_da_regua_vem_do_ajuste(self):
        # Perfeitos no ajuste: 0.5 e 0.8 (empate). O do meio da lista é o menor dos dois.
        r = self.avaliar_com_portao([_caso("p1", True, 0.9, 0.9), _caso("p2", False, 0.1, 0.1)])
        self.assertAlmostEqual(r["lim_regua"], 0.5)

    def test_um_portao_diferente_nao_muda_os_limiares(self):
        r1 = self.avaliar_com_portao([_caso("p1", True, 0.9, 0.9), _caso("p2", False, 0.1, 0.1)])
        # Um portão "enganador": se o limiar fosse medido nele, mudaria.
        r2 = self.avaliar_com_portao([_caso("q1", True, 0.3, 0.35), _caso("q2", True, 0.35, 0.4),
                                      _caso("q3", False, 0.45, 0.6), _caso("q4", False, 0.4, 0.55)])
        self.assertEqual(r1["lim_regua"], r2["lim_regua"])
        self.assertEqual(r1["lim_jev"], r2["lim_jev"])
        self.assertEqual(r1["n_ajuste"], r2["n_ajuste"])

    def test_limiar_do_jev_empata_perto_de_0_7(self):
        # No ajuste todos os limiares candidatos acertam tudo: fica o 0.7.
        r = self.avaliar_com_portao([_caso("p1", True, 0.9, 0.9), _caso("p2", False, 0.1, 0.1)])
        self.assertAlmostEqual(r["lim_jev"], 0.7)

    def test_limiar_do_jev_acompanha_o_ajuste(self):
        ajuste = [_caso("a1", True, 0.8, 0.45), _caso("a2", True, 0.9, 0.5),
                  _caso("a3", False, 0.1, 0.1), _caso("a4", False, 0.2, 0.2)]
        casos, medidas, respostas = _montar(ajuste)
        r = ac.rodar_avaliacao(casos, casos, medidas, respostas, ["dia"])["dia"]
        self.assertAlmostEqual(r["lim_jev"], 0.4)   # o único que separa 0.45 de 0.2

    def test_candidatos_da_regua_incluem_valores_pontos_medios_e_pontas(self):
        amostras = [{"medidas": medidas_base(brilho_ceu=v), "geometria": {}} for v in (0.2, 0.6)]
        c = ac.candidatos_regua("dia", amostras)
        self.assertIn(0.2, c)
        self.assertIn(0.6, c)
        self.assertTrue(any(abs(x - 0.4) < 1e-9 for x in c))
        self.assertTrue(min(c) < 0.2 and max(c) > 0.6)


class TestRotuloNulo(unittest.TestCase):
    def test_null_deixa_a_captura_fora(self):
        lista = [_caso("a1", True, 0.8, 0.9), _caso("a2", False, 0.1, 0.1),
                 _caso("a3", None, 0.0, 0.9),            # rótulo null: não conta
                 _caso("p1", True, 0.9, 0.9), _caso("p2", None, 0.0, 0.9)]
        casos, medidas, respostas = _montar(lista)
        ajuste, portao = casos[:3], casos[3:]
        r = ac.rodar_avaliacao(ajuste, portao, medidas, respostas, ["dia"])["dia"]
        self.assertEqual(r["n_ajuste"], 2)
        self.assertEqual(r["n_portao"], 1)

    def test_conferencia_sem_nenhum_rotulo_no_ajuste(self):
        lista = [_caso("a1", True, 0.8, 0.9), _caso("p1", True, 0.9, 0.9)]
        casos, medidas, respostas = _montar(lista)
        r = ac.rodar_avaliacao(casos[:1], casos[1:], medidas, respostas, ["neve_estourada"])["neve_estourada"]
        self.assertIsNone(r["nota"])
        self.assertIn("ajuste", r["motivo"])


# ------------------------------------------------------------------ nota e veredito

def _nota(regua, jev_, classes_jev=None):
    return {"n": 10, "regua": {"acerto": regua, "por_classe": {True: regua, False: regua}},
            "jev": {"acerto": jev_, "por_classe": classes_jev or {True: jev_, False: jev_}},
            "concordancia": None}


class TestVeredito(unittest.TestCase):
    def test_jev_passa_com_as_tres_condicoes(self):
        v, motivo = ac.decidir_veredito(_nota(0.75, 0.95))
        self.assertEqual(v, "JEV")
        self.assertIn("95%", motivo)

    def test_no_limite_exato_ainda_passa(self):
        # 0.90 - 0.80 dá 0.0999999... em decimais: a tolerância evita o falso "não passou".
        self.assertEqual(ac.decidir_veredito(_nota(0.80, 0.90))[0], "JEV")

    def test_regua_quando_o_jev_acerta_pouco(self):
        v, motivo = ac.decidir_veredito(_nota(0.5, 0.85))
        self.assertEqual(v, "RÉGUA")
        self.assertIn("abaixo de 90%", motivo)

    def test_regua_quando_a_vantagem_e_pequena(self):
        v, motivo = ac.decidir_veredito(_nota(0.85, 0.92))
        self.assertEqual(v, "RÉGUA")
        self.assertIn("só 7 pontos", motivo)

    def test_regua_quando_ela_ja_passa_de_90(self):
        v, motivo = ac.decidir_veredito(_nota(0.95, 0.95))
        self.assertEqual(v, "RÉGUA")
        self.assertIn("já acerta 95%", motivo)

    def test_classe_colapsada_derruba_o_jev(self):
        v, motivo = ac.decidir_veredito(_nota(0.5, 0.95, {True: 0.0, False: 1.0}))
        self.assertEqual(v, "RÉGUA")
        self.assertIn("colapsada", motivo)
        self.assertIn("sim", motivo)

    def test_portao_sem_uma_das_classes_nao_prova_nada(self):
        v, motivo = ac.decidir_veredito(_nota(0.5, 0.95, {True: 0.95}))
        self.assertEqual(v, "RÉGUA")
        self.assertIn("exemplos de sim e de não", motivo)

    def test_sem_jev_nao_ha_veredito(self):
        self.assertIsNone(ac.decidir_veredito({"jev": None, "regua": {}})[0])

    def test_de_ponta_a_ponta_jev_vence(self):
        # Ajuste e portão do TestLimiar: a régua acerta metade dos "sim" do portão.
        ajuste = [_caso("a1", True, 0.8, 0.9), _caso("a2", True, 0.9, 0.95),
                  _caso("a3", False, 0.1, 0.05), _caso("a4", False, 0.2, 0.10)]
        portao = [_caso("p1", True, 0.9, 0.9), _caso("p2", True, 0.3, 0.9),
                  _caso("p3", False, 0.1, 0.1), _caso("p4", False, 0.1, 0.1)]
        ca, ma, ra = _montar(ajuste)
        cp, mp, rp = _montar(portao)
        r = ac.rodar_avaliacao(ca, cp, {**ma, **mp}, {**ra, **rp}, ["dia"])["dia"]
        self.assertAlmostEqual(r["nota"]["regua"]["acerto"], 0.75)
        self.assertAlmostEqual(r["nota"]["jev"]["acerto"], 1.0)
        self.assertEqual(r["veredito"], "JEV")
        self.assertEqual(r["nota"]["jev"]["por_classe"], {True: 1.0, False: 1.0})

    def test_concordancia(self):
        ajuste = [_caso("a1", True, 0.8, 0.9), _caso("a2", False, 0.1, 0.1)]
        portao = [_caso("p1", True, 0.9, 0.9),     # régua sim, Jev sim, certo
                  _caso("p2", True, 0.3, 0.9),     # régua não, Jev sim: discordam
                  _caso("p3", False, 0.9, 0.1),    # régua sim, Jev não: discordam
                  _caso("p4", False, 0.1, 0.1)]    # régua não, Jev não, certo
        ca, ma, ra = _montar(ajuste)
        cp, mp, rp = _montar(portao)
        r = ac.rodar_avaliacao(ca, cp, {**ma, **mp}, {**ra, **rp}, ["dia"])["dia"]
        c = r["nota"]["concordancia"]
        self.assertEqual(c["n"], 2)
        self.assertAlmostEqual(c["fracao"], 0.5)
        self.assertAlmostEqual(c["acerto"], 1.0)


# ------------------------------------------------------------------ o pedido e as proteções

class TestPedido(BaseComGabarito):
    def test_recusa_sem_capas(self):
        for valor in (None, False, "true", 1):
            self.adicionar("x", "ajuste", True, 0.8, 0.9, sem_capas=valor)
            caso = self.linhas[-1]
            if valor is None:
                caso.pop("sem_capas", None)
            with self.assertRaises(ValueError, msg="sem_capas=%r" % (valor,)):
                pc.pedido_da_captura(caso, self.pasta, "")
            self.linhas.clear()

    def test_aceita_com_sem_capas_true(self):
        self.adicionar("x", "ajuste", True, 0.8, 0.9)
        corpo = pc.pedido_da_captura(self.linhas[0], self.pasta, "")
        self.assertEqual(corpo["model"], jev.MODELO)
        self.assertEqual(corpo["assets"][pc.CHAVE_IMAGEM]["type"], "image")

    def test_main_recusa_antes_de_enviar_qualquer_coisa(self):
        self.adicionar("a1", "ajuste", True, 0.8, 0.9)
        self.adicionar("a2", "ajuste", False, 0.1, 0.1, sem_capas=None)  # sem a declaração
        self.gravar()
        codigo, saida, cliente = self.rodar()
        self.assertEqual(codigo, 2)
        self.assertEqual(cliente.chamadas, 0)
        self.assertIn("sem_capas", saida)
        self.assertIn("0 chamadas", saida)

    def test_estado_nao_entrega_a_resposta(self):
        self.adicionar("praca_17h_normal", "portao", True, 0.8, 0.9)
        caso = self.linhas[0]
        corpo = pc.pedido_da_captura(caso, self.pasta, "uma torre alta e azul")
        texto = json.dumps(corpo["state"]).lower()
        for proibido in ("hora", "hour", "variante", "variant", "ponto", "praca", "17", "13",
                         caso["id"], caso["arquivo"], "normal", "portao", "ajuste"):
            self.assertNotIn(proibido, texto, proibido)
        self.assertEqual(set(corpo["state"]), {"context", "screenshot"})
        # E o resto do texto (perguntas) também não cita o caso.
        texto_total = pc.texto_do_pedido(corpo).lower()
        for proibido in (caso["id"], caso["arquivo"], "variante"):
            self.assertNotIn(proibido, texto_total)

    def test_torre_so_com_descricao(self):
        self.adicionar("x", "ajuste", True, 0.8, 0.9)
        sem = pc.pedido_da_captura(self.linhas[0], self.pasta, "")
        self.assertNotIn("torre_visivel", sem["questions"])
        pendente = pc.pedido_da_captura(self.linhas[0], self.pasta, pc.TORRE_PENDENTE)
        self.assertNotIn("torre_visivel", pendente["questions"])
        self.assertNotIn(pc.TORRE_PENDENTE, json.dumps(pendente["questions"]))
        com = pc.pedido_da_captura(self.linhas[0], self.pasta, "a tall white tower")
        self.assertIn("a tall white tower", com["questions"]["torre_visivel"]["instructions"])

    def test_uma_pergunta_noul_por_conferencia(self):
        com = pc.perguntas_do_pedido("a tall white tower")
        self.assertEqual(list(com), pc.CONFERENCIAS)
        for q in com.values():
            self.assertEqual(q["type"], "noul")
            self.assertEqual(set(q["criteria"]), {"true", "false"})


# ------------------------------------------------------------------ cache, teto e erros do Jev

class TestJevMockado(BaseComGabarito):
    def test_gabarito_bom_de_ponta_a_ponta(self):
        self.gabarito_bom()
        codigo, saida, cliente = self.rodar()
        self.assertEqual(codigo, 0, saida)
        self.assertEqual(cliente.chamadas, 8)
        self.assertIn("VEREDITO: JEV", saida)
        self.assertIn("Jev: 8 chamadas", saida)
        # A torre fica de fora do pedido sem --descricao-torre.
        self.assertIn("sem --descricao-torre", saida)

    def test_segunda_rodada_nao_paga_de_novo(self):
        self.gabarito_bom()
        _, _, c1 = self.rodar()
        self.assertEqual(c1.chamadas, 8)
        codigo, saida, c2 = self.rodar()
        self.assertEqual(codigo, 0)
        self.assertEqual(c2.chamadas, 0)
        self.assertIn("0 chamadas", saida)
        self.assertIn("VEREDITO: JEV", saida)   # mesmo resultado, vindo do cache

    def test_pedido_diferente_paga_de_novo(self):
        self.gabarito_bom()
        self.rodar()
        # Agora com a pergunta da torre: o pedido muda, a assinatura muda.
        codigo, _, c2 = self.rodar("--descricao-torre", "a tall white tower")
        self.assertEqual(codigo, 0)
        self.assertEqual(c2.chamadas, 8)

    def test_medidas_ficam_em_cache(self):
        self.gabarito_bom()
        self.rodar()
        primeira = self.medir_chamadas
        self.assertEqual(primeira, 8)
        self.rodar()
        self.assertEqual(self.medir_chamadas, primeira)   # nada medido de novo
        self.assertTrue(os.path.isfile(os.path.join(self.pasta, "medidas.jsonl")))

    def test_formato_do_cache_de_respostas(self):
        self.gabarito_bom()
        self.rodar()
        with open(os.path.join(self.pasta, "respostas_jev.jsonl"), encoding="utf-8") as f:
            linhas = [json.loads(l) for l in f]
        self.assertEqual(len(linhas), 8)
        self.assertEqual(set(linhas[0]), {"id", "assinatura", "p"})
        self.assertIn("dia", linhas[0]["p"])
        self.assertNotIn("torre_visivel", linhas[0]["p"])

    def test_teto_antes_do_primeiro_envio(self):
        self.gabarito_bom()
        cliente = ClienteFalso(self.respostas, tokens_iniciais=20_000_000)   # ~US$ 0,84
        codigo, saida, _ = self.rodar(cliente=cliente)
        self.assertEqual(codigo, 2)
        self.assertEqual(cliente.chamadas, 0)
        self.assertIn("teto de custo", saida)
        self.assertIn("Jev: 0 chamadas", saida)

    def test_teto_no_meio_da_rodada(self):
        self.gabarito_bom()
        # Cada chamada custa ~US$ 0,21: depois da 3ª já passou de US$ 0,50.
        cliente = ClienteFalso(self.respostas, tokens_por_chamada=5_000_000)
        codigo, saida, _ = self.rodar(cliente=cliente)
        self.assertEqual(codigo, 2)
        self.assertEqual(cliente.chamadas, 3)
        self.assertIn("teto de custo", saida)
        self.assertNotIn("VEREDITO", saida)

    def test_erro_do_jev_para_tudo_e_nao_vira_resposta(self):
        self.gabarito_bom()
        cliente = ClienteFalso(self.respostas, falhar_na_chamada=2)
        codigo, saida, _ = self.rodar(cliente=cliente)
        self.assertEqual(codigo, 2)
        self.assertEqual(cliente.chamadas, 2)
        self.assertIn("HTTP 500", saida)
        self.assertIn("Jev: 2 chamadas", saida)       # o relatório de custo aparece
        self.assertNotIn("VEREDITO", saida)
        with open(os.path.join(self.pasta, "respostas_jev.jsonl"), encoding="utf-8") as f:
            self.assertEqual(len(f.readlines()), 2)   # só as 2 que deram certo
        # Rodando de novo, só as 6 que faltam são perguntadas.
        codigo, _, c2 = self.rodar()
        self.assertEqual(codigo, 0)
        self.assertEqual(c2.chamadas, 6)

    def test_sem_chave_para_tudo(self):
        self.gabarito_bom()

        def sem_chave():
            raise jev.ErroJev("sem chave do Jev")
        saida = io.StringIO()
        with contextlib.redirect_stdout(saida):
            codigo = ac.main(["--gabarito", self.pasta], criar_cliente=sem_chave, medir=self.medir)
        self.assertEqual(codigo, 2)
        self.assertIn("sem chave", saida.getvalue())
        self.assertIn("0 chamadas", saida.getvalue())

    def test_resposta_fora_do_formato_para_tudo(self):
        self.gabarito_bom()

        class Quebrado(ClienteFalso):
            def enviar(self, corpo):
                return {"answers": {}, "usage": {}}   # sem a pergunta "dia"
        codigo, saida, cliente = self.rodar(cliente=Quebrado(self.respostas))
        self.assertEqual(codigo, 2)
        self.assertIn("fora do formato", saida)

    def test_sem_enviar_so_calcula_a_regua(self):
        self.gabarito_bom()
        codigo, saida, cliente = self.rodar("--sem-enviar")
        self.assertEqual(codigo, 0, saida)
        self.assertEqual(cliente.chamadas, 0)
        self.assertIn("faltam 8 pedidos", saida)
        self.assertIn("régua:", saida)
        self.assertNotIn("Jev:   ", saida)
        self.assertNotIn("VEREDITO", saida)
        self.assertIn("0 chamadas", saida)

    def test_so_ajuste_nunca_le_o_portao(self):
        self.gabarito_bom()
        # Se o modo tocasse no portão, estas capturas quebrariam o teste.
        for p in ("p1", "p2", "p3", "p4"):
            os.remove(os.path.join(self.pasta, p + ".png"))
        codigo, saida, cliente = self.rodar("--so-ajuste")
        self.assertEqual(codigo, 0, saida)
        self.assertEqual(cliente.chamadas, 4)
        self.assertNotIn("p1", cliente.vistos)
        self.assertIn("o portão não foi lido", saida)
        self.assertNotIn("VEREDITO", saida)
        with open(os.path.join(self.pasta, "medidas.jsonl"), encoding="utf-8") as f:
            ids = {json.loads(l)["id"] for l in f}
        self.assertEqual(ids, {"a1", "a2", "a3", "a4"})

    def test_so_ajuste_mostra_cada_erro_com_as_probabilidades(self):
        self.adicionar("a1", "ajuste", True, 0.9, 0.9)
        self.adicionar("a2", "ajuste", True, 0.8, 0.4)    # nenhum limiar separa 0.40 (sim) de 0.50 (não)
        self.adicionar("a3", "ajuste", False, 0.1, 0.5)
        self.adicionar("a4", "ajuste", False, 0.2, 0.1)
        self.gravar()
        codigo, saida, _ = self.rodar("--so-ajuste")
        self.assertEqual(codigo, 0, saida)
        self.assertIn("errou: a2", saida)
        self.assertIn("p = 0.40", saida)


class TestGabarito(BaseComGabarito):
    def test_ler_gabarito_filtra_as_partes(self):
        self.gabarito_bom()
        self.assertEqual(len(ac.ler_gabarito(self.pasta)), 8)
        so = ac.ler_gabarito(self.pasta, ("ajuste",))
        self.assertEqual({c["parte"] for c in so}, {"ajuste"})


if __name__ == "__main__":
    unittest.main()
