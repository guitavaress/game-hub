// Vigia o cofre: a cada 2 s confere a data e o tamanho de cada .md e do git.
// É por "polling" (conferir de tempo em tempo) porque, no Docker do Windows,
// o aviso de "arquivo mudou" do sistema não atravessa para dentro do contêiner.

import { statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { listarMarkdown } from './ler-cofre.js';

function assinatura(caminho) {
  try {
    const st = statSync(caminho);
    return `${st.mtimeMs}:${st.size}`;
  } catch {
    return 'sumiu';
  }
}

// Fotografa o estado atual: { 'plans/fase-17.md': '1730...:2048', ... }
function fotografar(docs, repo) {
  const foto = new Map();
  for (const p of listarMarkdown(docs)) foto.set(relative(docs, p).split(sep).join('/'), assinatura(p));
  // logs/HEAD muda a cada commit, checkout e merge.
  foto.set('(git)', assinatura(join(repo, '.git', 'logs', 'HEAD')) + assinatura(join(repo, '.git', 'HEAD')));
  return foto;
}

// Chama aoMudar(listaDeArquivos) quando algo muda. Devolve uma função para parar.
export function vigiar(docs, repo, aoMudar, intervalo = 2000) {
  let antes = fotografar(docs, repo);
  const timer = setInterval(() => {
    const agora = fotografar(docs, repo);
    const mudou = [];
    for (const [arq, sig] of agora) if (antes.get(arq) !== sig) mudou.push(arq);
    for (const arq of antes.keys()) if (!agora.has(arq)) mudou.push(arq);
    antes = agora;
    if (mudou.length) aoMudar(mudou);
  }, intervalo);
  return () => clearInterval(timer);
}
