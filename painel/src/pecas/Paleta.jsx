// Busca rápida (Ctrl+K ou /): procura no título, nos subtítulos e no texto de todos os documentos.

import { useEffect, useMemo, useRef, useState } from 'react';
import { motion } from 'motion/react';
import Icone from './Icone.jsx';
import { slug } from '../util.js';
import useDialogo from './useDialogo.js';

const semAcento = (s) =>
  s
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();

function destacar(texto, termo) {
  if (!termo) return texto;
  const i = semAcento(texto).indexOf(semAcento(termo));
  if (i < 0) return texto;
  return (
    <>
      {texto.slice(0, i)}
      <mark>{texto.slice(i, i + termo.length)}</mark>
      {texto.slice(i + termo.length)}
    </>
  );
}

export default function Paleta({ docs, abrir, fechar }) {
  const [termo, setTermo] = useState('');
  const [sel, setSel] = useState(0);
  const campo = useRef(null);
  const lista = useRef(null);
  const dialogo = useRef(null);

  useDialogo(dialogo, campo, fechar);

  const resultados = useMemo(() => {
    const t = semAcento(termo.trim());
    if (!t) return docs.slice(0, 8).map((d) => ({ doc: d, onde: d.resumo, ancora: '' }));
    const achados = [];
    for (const d of docs) {
      let pontos = 0;
      let onde = '';
      let ancora = '';
      if (semAcento(d.titulo).includes(t)) pontos += 10;
      const sub = d.titulos.find((h) => semAcento(h.texto).includes(t));
      if (sub) {
        pontos += 5;
        onde = sub.texto;
        ancora = slug(sub.texto);
      }
      const corpo = semAcento(d.texto);
      const i = corpo.indexOf(t);
      if (i >= 0) {
        pontos += 1;
        if (!onde) {
          const ini = Math.max(0, i - 40);
          onde = (ini ? '…' : '') + d.texto.slice(ini, i + t.length + 70).replace(/[#*`|>\n]+/g, ' ');
        }
      }
      if (pontos) achados.push({ doc: d, onde, ancora, pontos });
    }
    return achados.sort((a, b) => b.pontos - a.pontos).slice(0, 30);
  }, [termo, docs]);

  useEffect(() => setSel(0), [termo]);
  useEffect(() => {
    lista.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [sel]);

  const tecla = (e) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSel((s) => Math.min(s + 1, resultados.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSel((s) => Math.max(s - 1, 0));
    } else if (e.key === 'Enter' && resultados[sel]) {
      e.preventDefault();
      const r = resultados[sel];
      abrir(r.doc.arquivo, r.ancora);
    }
  };

  return (
    <>
      <motion.div className="paleta-veu" onClick={fechar} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} />
      <motion.div
        ref={dialogo}
        className="paleta"
        role="dialog"
        aria-modal="true"
        aria-label="Buscar nos documentos"
        initial={{ opacity: 0, y: -14, scale: 0.97, filter: 'blur(4px)' }}
        animate={{ opacity: 1, y: 0, scale: 1, filter: 'blur(0px)' }}
        exit={{ opacity: 0, y: -8, scale: 0.98, transition: { duration: 0.14 } }}
        transition={{ type: 'spring', stiffness: 420, damping: 32 }}
      >
        <label className="campo">
          <Icone nome="busca" />
          <input
            ref={campo}
            value={termo}
            onChange={(e) => setTermo(e.target.value)}
            onKeyDown={tecla}
            placeholder="Buscar em todos os documentos…"
            aria-label="Buscar"
            role="combobox"
            aria-expanded="true"
            aria-controls="paleta-lista"
          />
          <kbd>Esc</kbd>
        </label>
        <ul id="paleta-lista" role="listbox" ref={lista}>
          {resultados.length === 0 && <li className="vazio">Nada com “{termo}”. Tente outra palavra.</li>}
          {resultados.map((r, i) => (
            <li key={r.doc.arquivo + r.ancora}>
              <button role="option" aria-selected={i === sel} onMouseMove={() => setSel(i)} onClick={() => abrir(r.doc.arquivo, r.ancora)}>
                <b>{destacar(r.doc.titulo, termo.trim())}</b>
                <span>{r.doc.arquivo}</span>
                {r.onde && <em>{destacar(r.onde, termo.trim())}</em>}
              </button>
            </li>
          ))}
        </ul>
        <div className="paleta-pe">
          <span>
            <kbd>↑</kbd> <kbd>↓</kbd> escolher
          </span>
          <span>
            <kbd>Enter</kbd> abrir
          </span>
        </div>
      </motion.div>
    </>
  );
}
