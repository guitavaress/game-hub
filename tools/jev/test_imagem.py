"""Testes do envio de imagem ao Jev (spike das capturas, C.1). Sem rede."""
import io
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(__file__))
import jev  # noqa: E402


def png_falso(largura: int, altura: int) -> bytes:
    """Só a assinatura e o cabeçalho IHDR: basta para ler o tamanho."""
    ihdr = largura.to_bytes(4, "big") + altura.to_bytes(4, "big") + b"\x08\x02\x00\x00\x00"
    return b"\x89PNG\r\n\x1a\n" + (13).to_bytes(4, "big") + b"IHDR" + ihdr + b"\x00" * 4


class TesteImagem(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def arquivo(self, largura, altura):
        caminho = os.path.join(self.tmp.name, "c_%dx%d.png" % (largura, altura))
        with open(caminho, "wb") as f:
            f.write(png_falso(largura, altura))
        return caminho

    def test_tamanho_do_png(self):
        self.assertEqual(jev.tamanho_png(png_falso(1280, 720)), (1280, 720))
        with self.assertRaises(jev.ErroJev):
            jev.tamanho_png(b"GIF89a" + b"\x00" * 30)

    def test_limite_da_api(self):
        asset = jev.imagem_png(self.arquivo(1280, 720))
        self.assertEqual((asset["type"], asset["format"]), ("image", "png"))
        with self.assertRaises(jev.ErroJev):
            jev.imagem_png(self.arquivo(1600, 900))   # a captura do hub vem com 1600 px
        with self.assertRaises(jev.ErroJev):
            jev.imagem_png(self.arquivo(200, 720))

    def test_pedido_com_e_sem_imagem(self):
        self.assertNotIn("assets", jev.pedido({"a": 1}, {}))
        corpo = jev.pedido({"captura": "img1"}, {}, {"img1": jev.imagem_png(self.arquivo(1280, 720))})
        self.assertIn("img1", corpo["assets"])

    def test_cabecalho_de_imagem_so_com_imagem(self):
        enviados = []

        def urlopen_falso(req, timeout):
            enviados.append({k.lower(): v for k, v in req.header_items()})
            return io.BytesIO(json.dumps({"answers": {}, "usage": {"input_tokens": 10}}).encode())

        with mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "chave-de-teste"}), \
                mock.patch("urllib.request.urlopen", urlopen_falso):
            cliente = jev.Cliente()
            cliente.enviar(jev.pedido({}, {}))
            cliente.enviar(jev.pedido({"c": "img1"}, {}, {"img1": jev.imagem_png(self.arquivo(1280, 720))}))
        self.assertNotIn("typesafe-danger-zone-images", enviados[0])
        self.assertEqual(enviados[1].get("typesafe-danger-zone-images"), "true")
        self.assertEqual(cliente.tokens, 20)


if __name__ == "__main__":
    unittest.main()
