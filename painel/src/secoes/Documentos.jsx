// Todos os documentos do cofre, com filtro por pasta e por texto.

import { useMemo, useState } from 'react';
import { AnimatePresence, LayoutGroup, motion } from 'motion/react';
import Icone from '../pecas/Icone.jsx';
import { NOMES_PASTAS, tempoRelativo } from '../util.js';

const semAcento = (s) =>
  s
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();

export default function Documentos({ docs, abrir, mudou }) {
  const [pasta, setPasta] = useState('tudo');
  const [termo, setTermo] = useState('');
  const [todos, setTodos] = useState(false);
  const LIMITE = 12;
  const pastas = useMemo(() => ['tudo', ...new Set(docs.map((d) => d.pasta.split('/')[0]))], [docs]);

  const lista = useMemo(() => {
    const t = semAcento(termo.trim());
    return docs
      .filter((d) => pasta === 'tudo' || d.pasta.split('/')[0] === pasta)
      .filter((d) => !t || semAcento(d.titulo + ' ' + d.arquivo).includes(t))
      .sort((a, b) => (b.modificado || '').localeCompare(a.modificado || ''));
  }, [docs, pasta, termo]);

  return (
    <section id="docs" className="secao" aria-labelledby="titulo-docs">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-docs">Documentos</h2>
          <p>
            Os {docs.length} arquivos do cofre, do mais recente ao mais antigo. Para buscar dentro do texto, use <kbd>Ctrl</kbd> <kbd>K</kbd>.
          </p>
        </div>
      </div>

      <div className="docs-barra">
        <label className="campo">
          <Icone nome="busca" />
          <input value={termo} onChange={(e) => setTermo(e.target.value)} placeholder="Filtrar pelo nome…" aria-label="Filtrar documentos pelo nome" />
        </label>
        <LayoutGroup id="filtro-docs">
          <div className="abas" role="group" aria-label="Filtrar por pasta">
            {pastas.map((p) => (
              <button key={p} aria-pressed={pasta === p} onClick={() => setPasta(p)}>
                {pasta === p && <motion.i className="fundo-aba" layoutId="aba-docs" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
                <span>{p === 'tudo' ? 'Tudo' : NOMES_PASTAS[p] || p}</span>
              </button>
            ))}
          </div>
        </LayoutGroup>
      </div>

      <div className="tabela-docs superficie">
        <AnimatePresence initial={false} mode="popLayout">
          {lista.length === 0 && (
            <motion.p key="vazio" className="vazio" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              Nenhum documento com “{termo}”.
            </motion.p>
          )}
          {(todos || termo ? lista : lista.slice(0, LIMITE)).map((d) => (
            <motion.button
              key={d.arquivo}
              layout="position"
              className={`doc-linha ${mudou(d.arquivo) ? 'mudou' : ''}`}
              onClick={() => abrir(d.arquivo)}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, transition: { duration: 0.12 } }}
              transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            >
              <span className="t">
                <b>{d.titulo}</b>
                <span>{d.arquivo}</span>
              </span>
              <span className="pasta">{NOMES_PASTAS[d.pasta.split('/')[0]] || d.pasta}</span>
              <span className="quando">{tempoRelativo(d.modificado)}</span>
            </motion.button>
          ))}
        </AnimatePresence>
        {!termo && lista.length > LIMITE && (
          <div className="mais-docs">
            <button className="botao" onClick={() => setTodos((t) => !t)} aria-expanded={todos}>
              {todos ? 'Mostrar só os recentes' : `Mostrar todos os ${lista.length}`}
            </button>
          </div>
        )}
      </div>
    </section>
  );
}
