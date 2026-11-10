// Mostra markdown do cofre. Os links para outros .md abrem dentro do painel;
// links externos abrem numa aba nova.

import { useMemo } from 'react';
import { Marked } from 'marked';
import { resolverLink, slug } from '../util.js';

const marked = new Marked({ gfm: true, breaks: false });
marked.use({
  renderer: {
    // Títulos com id (o slug), para os links #ancora funcionarem.
    heading({ tokens, depth, text }) {
      const html = this.parser.parseInline(tokens);
      return `<h${depth} id="${slug(text)}">${html}</h${depth}>\n`;
    },
    link({ href, title, tokens }) {
      const texto = this.parser.parseInline(tokens);
      const externo = /^[a-z]+:/i.test(href || '');
      const t = title ? ` title="${title}"` : '';
      return externo
        ? `<a href="${href}"${t} target="_blank" rel="noreferrer noopener">${texto}</a>`
        : `<a href="${href}"${t} data-interno="1">${texto}</a>`;
    },
  },
});

export function mdParaHtml(texto, inline = false) {
  const limpo = (texto || '').replace(/<!--[\s\S]*?-->/g, '');
  return inline ? marked.parseInline(limpo) : marked.parse(limpo.replace(/^---\n[\s\S]*?\n---\n/, ''));
}

// Intercepta os cliques nos links internos e manda abrir no leitor.
export function aoClicarLink(e, origem, abrir) {
  const a = e.target.closest('a[data-interno]');
  if (!a) return;
  const destino = resolverLink(a.getAttribute('href'), origem);
  e.preventDefault();
  e.stopPropagation();
  if (destino) abrir(destino.arquivo, destino.ancora);
}

export default function Md({ texto, origem, abrir, inline = false, className = '' }) {
  const html = useMemo(() => mdParaHtml(texto, inline), [texto, inline]);
  const Tag = inline ? 'span' : 'div';
  return (
    <Tag
      className={`${inline ? 'md-inline' : 'md'} ${className}`}
      onClick={(e) => aoClicarLink(e, origem, abrir)}
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
