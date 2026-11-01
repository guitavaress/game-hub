"""O cliente do Jev (TypeSafe), num lugar só.

- Versão fixa (jev-1.14.0), para o resultado ser repetível.
- A chave vem de TYPESAFE_API_KEY ou do arquivo em TYPESAFE_API_KEY_FILE (ou
  ~/.typesafe/api_key). Ela nunca é impressa nem gravada.
- Um erro HTTP ou de rede é ERRO, nunca uma resposta (a skill TypeSafe pede isso).
- Cada envio soma os tokens de entrada; a saída do Jev é grátis.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.request

URL = "https://api.typesafe.ai/v1/systemone"
MODELO = "jev-1.14.0"
PRECO_POR_TOKEN = 0.042 / 1_000_000  # US$ por token de entrada


class ErroJev(Exception):
    """O Jev não respondeu (sem chave, sem rede, HTTP ≠ 200). Nunca vira resposta."""


def chave() -> str:
    valor = os.environ.get("TYPESAFE_API_KEY", "").strip()
    arquivos = [os.environ.get("TYPESAFE_API_KEY_FILE", ""),
                os.path.join(os.path.expanduser("~"), ".typesafe", "api_key")]
    for arquivo in arquivos:
        if not valor and arquivo and os.path.isfile(arquivo):
            # utf-8-sig tira o BOM que o Bloco de Notas às vezes põe no começo.
            with open(arquivo, encoding="utf-8-sig") as f:
                valor = f.read().strip()
    return valor


def pedido(estado: dict, perguntas: dict, assets: dict = None) -> dict:
    """O corpo do pedido. `assets` ({chave: imagem_png(...)}) só quando há imagem: a chave
    aparece como texto no estado ou na pergunta, e a API troca pela imagem."""
    corpo = {"model": MODELO, "state": estado, "questions": perguntas}
    if assets:
        corpo["assets"] = assets
    return corpo


# Limites de imagem da API (docs.typesafe.ai/go/images): cada lado entre 280 e 1568 px.
LADO_MIN, LADO_MAX = 280, 1568


def tamanho_png(dados: bytes) -> tuple:
    """(largura, altura) lidas do cabeçalho do PNG, sem abrir a imagem."""
    if dados[:8] != b"\x89PNG\r\n\x1a\n" or dados[12:16] != b"IHDR":
        raise ErroJev("o arquivo não é um PNG")
    return int.from_bytes(dados[16:20], "big"), int.from_bytes(dados[20:24], "big")


def imagem_png(caminho: str) -> dict:
    """Um asset de imagem PNG. Recusa antes de enviar o que a API recusaria (tamanho)."""
    with open(caminho, "rb") as f:
        dados = f.read()
    largura, altura = tamanho_png(dados)
    if not (LADO_MIN <= largura <= LADO_MAX and LADO_MIN <= altura <= LADO_MAX):
        raise ErroJev("imagem %dx%d fora do limite da API (%d a %d px por lado)"
                      % (largura, altura, LADO_MIN, LADO_MAX))
    return {"type": "image", "format": "png", "data_base64": base64.b64encode(dados).decode("ascii")}


class Cliente:
    """Manda os pedidos e conta o gasto. `contas` vai para o relatório de custo."""

    def __init__(self):
        self._chave = chave()
        if not self._chave:
            raise ErroJev("sem chave do Jev: defina TYPESAFE_API_KEY_FILE (o arquivo da chave, fora do repositório)")
        self.chamadas = 0
        self.tokens = 0

    def enviar(self, corpo: dict) -> dict:
        dados = json.dumps(corpo).encode("utf-8")
        cabecalhos = {"Authorization": "Bearer " + self._chave, "Content-Type": "application/json"}
        if corpo.get("assets"):
            # Imagem ainda é "protótipo" na TypeSafe: a API exige este aviso explícito.
            cabecalhos["TypeSafe-Danger-Zone-Images"] = "true"
        req = urllib.request.Request(URL, data=dados, method="POST", headers=cabecalhos)
        for tentativa in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    resposta = json.load(resp)
                break
            except urllib.error.HTTPError as e:
                if e.code in (429, 529) and tentativa < 4:
                    time.sleep(2 ** tentativa)
                    continue
                raise ErroJev("o Jev respondeu HTTP %d: %s" % (e.code, e.read()[:300])) from None
            except (urllib.error.URLError, TimeoutError) as e:
                raise ErroJev("sem conexão com o Jev: %s" % e) from None
        self.chamadas += 1
        self.tokens += resposta.get("usage", {}).get("input_tokens", 0)
        if "answers" not in resposta:
            raise ErroJev("resposta do Jev sem 'answers'")
        return resposta

    def custo(self) -> float:
        return self.tokens * PRECO_POR_TOKEN

    def relatorio(self) -> str:
        return "Jev: %d chamadas, %d tokens de entrada, US$ %.4f" % (self.chamadas, self.tokens, self.custo())


def noul(resposta: dict, qid: str) -> float:
    """A probabilidade de "sim" de uma pergunta noul."""
    valor = resposta["answers"][qid]["noul"]
    if isinstance(valor, dict):  # por garantia, se a API mandar {"true": p, ...}
        valor = valor.get("true", valor.get("probability"))
    return float(valor)
