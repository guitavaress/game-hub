// O servidor do painel: entrega o site já compilado (dist/), os dados do cofre
// em /api/painel e um canal "ao vivo" em /api/eventos (Server-Sent Events).
// Sem Express: só o node:http.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync, statSync } from 'node:fs';
import { join, resolve, extname, dirname, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { lerCofre } from './ler-cofre.js';
import { lerGit } from './git.js';
import { vigiar } from './vigia.js';

const aqui = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(process.env.REPO || join(aqui, '..', '..'));
const DOCS = resolve(process.env.DOCS || join(REPO, 'docs'));
const SITE = resolve(process.env.SITE || join(aqui, '..', 'dist'));
const PORTA = Number(process.env.PORT || 4170);

const TIPOS = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.json': 'application/json; charset=utf-8',
  '.woff2': 'font/woff2',
  '.ico': 'image/x-icon',
};

let dados = null;
let versao = 0;
const ouvintes = new Set();

async function montar(mudou = []) {
  const inicio = Date.now();
  const cofre = lerCofre(DOCS);
  const git = await lerGit(REPO);
  versao += 1;
  dados = { versao, geradoEm: new Date().toISOString(), mudou, ...cofre, git };
  console.log(`[painel] cofre lido em ${Date.now() - inicio} ms (${cofre.docs.length} documentos)`);
}

function avisar(evento) {
  const msg = `event: mudou\ndata: ${JSON.stringify(evento)}\n\n`;
  for (const res of ouvintes) res.write(msg);
}

async function servirArquivo(res, caminho) {
  const corpo = await readFile(caminho);
  const ext = extname(caminho);
  res.writeHead(200, {
    'Content-Type': TIPOS[ext] || 'application/octet-stream',
    // Os arquivos de /assets têm o hash no nome: podem ficar em cache.
    'Cache-Control': caminho.includes(`${join(SITE, 'assets')}`) ? 'public, max-age=31536000, immutable' : 'no-cache',
  });
  res.end(corpo);
}

const servidor = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');

    if (url.pathname === '/api/painel') {
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(dados));
      return;
    }

    if (url.pathname === '/api/eventos') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-store',
        Connection: 'keep-alive',
      });
      res.write(`event: ola\ndata: ${JSON.stringify({ versao })}\n\n`);
      ouvintes.add(res);
      req.on('close', () => ouvintes.delete(res));
      return;
    }

    // Arquivos do site. normalize + o teste de prefixo impedem sair da pasta (../).
    const pedido = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, '');
    const caminho = resolve(SITE, pedido);
    if (caminho.startsWith(SITE) && existsSync(caminho) && statSync(caminho).isFile()) {
      await servirArquivo(res, caminho);
      return;
    }
    // Qualquer outro endereço abre o painel (o React cuida do resto).
    const indice = join(SITE, 'index.html');
    if (existsSync(indice)) {
      await servirArquivo(res, indice);
      return;
    }
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('O site ainda não foi compilado (npm run build).');
  } catch (erro) {
    console.error('[painel] erro:', erro);
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Erro no painel.');
  }
});

await montar();

vigiar(DOCS, REPO, async (mudou) => {
  await montar(mudou);
  console.log('[painel] mudou:', mudou.join(', '));
  avisar({ versao, mudou });
});

// Mantém a conexão viva (alguns navegadores fecham conexões paradas).
setInterval(() => {
  for (const res of ouvintes) res.write(': pulso\n\n');
}, 25_000);

servidor.listen(PORTA, '0.0.0.0', () => {
  console.log(`[painel] no ar em http://localhost:${PORTA} (cofre: ${DOCS})`);
});
