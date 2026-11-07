// Pequenas funções usadas em várias partes do painel.

// O "slug" de um título, como o GitHub e o Obsidian fazem nos links (#2-mostrar-para-amigos).
export function slug(texto) {
  return String(texto)
    .trim()
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s/g, '-');
}

// Resolve um link relativo ("../ROADMAP.md#x") a partir do arquivo onde ele está.
// Devolve { arquivo, ancora } dentro do cofre, ou null se o link for para fora.
export function resolverLink(href, origem) {
  if (!href || /^[a-z]+:/i.test(href)) return null;
  const [caminho, ancora = ''] = href.split('#');
  if (!caminho) return { arquivo: origem, ancora: decodeURIComponent(ancora) };
  if (!/\.md$/i.test(caminho)) return null;
  const partes = origem.split('/').slice(0, -1);
  for (const p of decodeURIComponent(caminho).split('/')) {
    if (p === '..') {
      if (!partes.length) return null; // sai do cofre (ex.: ../AGENTS.md)
      partes.pop();
    } else if (p && p !== '.') partes.push(p);
  }
  return { arquivo: partes.join('/'), ancora: decodeURIComponent(ancora) };
}

// O endereço que abre a nota no Obsidian (o cofre se chama "docs").
export function linkObsidian(arquivo) {
  return `obsidian://open?vault=docs&file=${encodeURIComponent(arquivo.replace(/\.md$/i, ''))}`;
}

const rtf = new Intl.RelativeTimeFormat('pt-BR', { numeric: 'auto' });
export function tempoRelativo(data, agora = Date.now()) {
  if (!data) return '';
  const s = Math.round((new Date(data).getTime() - agora) / 1000);
  const a = Math.abs(s);
  if (a < 45) return 'agora';
  if (a < 3600) return rtf.format(Math.round(s / 60), 'minute');
  if (a < 86400) return rtf.format(Math.round(s / 3600), 'hour');
  if (a < 86400 * 30) return rtf.format(Math.round(s / 86400), 'day');
  return new Date(data).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short', year: 'numeric' });
}

export function dataCurta(iso) {
  return new Date(iso + (iso.length === 10 ? 'T12:00:00' : '')).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' });
}

export function lerPreferencia(chave, padrao) {
  try {
    return localStorage.getItem(chave) ?? padrao;
  } catch {
    return padrao;
  }
}

export function salvarPreferencia(chave, valor) {
  try {
    localStorage.setItem(chave, valor);
  } catch {
    /* sem armazenamento (janela anônima): segue sem lembrar */
  }
}

// Brilho que segue o mouse: guarda a posição em --mx/--my no elemento.
export function seguirMouse(e) {
  const r = e.currentTarget.getBoundingClientRect();
  e.currentTarget.style.setProperty('--mx', `${e.clientX - r.left}px`);
  e.currentTarget.style.setProperty('--my', `${e.clientY - r.top}px`);
}

// Os nomes das pastas do cofre, para as pessoas.
export const NOMES_PASTAS = {
  '': 'Raiz',
  plans: 'Planos',
  design: 'Design',
  ideias: 'Ideias',
};
