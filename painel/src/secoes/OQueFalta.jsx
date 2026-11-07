// O que falta: os "- [ ]" abertos dos planos (o que o plugin Tasks fazia), por arquivo.

import { useMemo, useState } from 'react';
import { AnimatePresence, LayoutGroup, motion } from 'motion/react';
import Md from '../pecas/Md.jsx';

const FILTROS = [
  { id: 'tudo', nome: 'Tudo' },
  { id: 'fases', nome: 'Nas fases' },
  { id: 'conferencia', nome: 'No dia de conferência' },
];

export default function OQueFalta({ tarefas, docs, abrir, mudou }) {
  const [filtro, setFiltro] = useState('tudo');
  const titulos = useMemo(() => new Map(docs.map((d) => [d.arquivo, d.titulo])), [docs]);

  const grupos = useMemo(() => {
    const lista = tarefas.filter((t) =>
      filtro === 'tudo' ? true : filtro === 'fases' ? t.arquivo.startsWith('plans/fase-') : t.arquivo.includes('conferencia'),
    );
    const mapa = new Map();
    for (const t of lista) {
      if (!mapa.has(t.arquivo)) mapa.set(t.arquivo, []);
      mapa.get(t.arquivo).push(t);
    }
    return [...mapa.entries()];
  }, [tarefas, filtro]);

  return (
    <section id="falta" className="secao" aria-labelledby="titulo-falta">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-falta">O que falta</h2>
          <p>Os itens em aberto dos planos. Clique num item para abrir o plano naquele ponto.</p>
        </div>
        <LayoutGroup id="filtro-falta">
          <div className="abas" role="group" aria-label="Filtrar tarefas">
            {FILTROS.map((f) => (
              <button key={f.id} aria-pressed={filtro === f.id} onClick={() => setFiltro(f.id)}>
                {filtro === f.id && <motion.i className="fundo-aba" layoutId="aba-falta" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
                <span>{f.nome}</span>
              </button>
            ))}
          </div>
        </LayoutGroup>
      </div>

      <motion.div className="grupos" layout>
        <AnimatePresence mode="popLayout">
          {grupos.length === 0 && (
            <motion.p key="vazio" className="vazio superficie" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              Nada em aberto aqui.
            </motion.p>
          )}
          {grupos.map(([arquivo, itens]) => (
            <motion.div
              key={arquivo}
              layout
              className={`grupo superficie ${mudou(arquivo) ? 'mudou' : ''}`}
              initial={{ opacity: 0, scale: 0.97, y: 10 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.97, transition: { duration: 0.15 } }}
              transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
            >
              <div className="grupo-cabeca">
                <button onClick={() => abrir(arquivo)}>{titulos.get(arquivo) || arquivo}</button>
                <span className="chip num">{itens.length}</span>
              </div>
              {itens.map((t) => (
                <button key={t.linha} className="tarefa" onClick={() => abrir(arquivo, textoInicial(t.texto))}>
                  <span className="caixa" aria-hidden="true" />
                  <span>
                    {t.secao && <small>{t.secao}</small>}
                    <Md texto={t.texto} origem={arquivo} abrir={abrir} inline />
                  </span>
                </button>
              ))}
            </motion.div>
          ))}
        </AnimatePresence>
      </motion.div>
    </section>
  );
}

// O começo do texto da tarefa, sem marcação, para achar o ponto no documento.
function textoInicial(md) {
  return md
    .replace(/\*\*|`|~~/g, '')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .slice(0, 40)
    .trim();
}
