// As ideias por estágio (crua → madura → virou-fase → descartada), com filtro por versão.
// Ideia não é tarefa: só vira trabalho quando entra no ROADMAP como fase.

import { useMemo, useState } from 'react';
import { AnimatePresence, LayoutGroup, motion } from 'motion/react';
import Md from '../pecas/Md.jsx';
import { dataCurta, seguirMouse } from '../util.js';

const COLUNAS = [
  { id: 'crua', nome: 'Crua' },
  { id: 'madura', nome: 'Madura' },
  { id: 'virou-fase', nome: 'Virou fase' },
  { id: 'descartada', nome: 'Descartada' },
];
const CUSTO = { P: 'custo pequeno', M: 'custo médio', G: 'custo grande' };

export default function Ideias({ ideias, abrir, mudou }) {
  const [versao, setVersao] = useState('todas');
  const versoes = useMemo(() => ['todas', ...[...new Set(ideias.map((i) => i.versao).filter(Boolean))].sort()], [ideias]);
  const visiveis = ideias.filter((i) => versao === 'todas' || i.versao === versao);

  return (
    <section id="ideias" className="secao" aria-labelledby="titulo-ideias">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-ideias">Ideias</h2>
          <p>A caixa de entrada. Nova ideia vai para a pasta ideias/, com o modelo "ideia" do Obsidian.</p>
        </div>
        {versoes.length > 2 && (
          <LayoutGroup id="filtro-ideias">
            <div className="abas" role="group" aria-label="Filtrar por versão">
              {versoes.map((v) => (
                <button key={v} aria-pressed={versao === v} onClick={() => setVersao(v)}>
                  {versao === v && <motion.i className="fundo-aba" layoutId="aba-ideias" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
                  <span>{v === 'todas' ? 'Todas' : v}</span>
                </button>
              ))}
            </div>
          </LayoutGroup>
        )}
      </div>

      <LayoutGroup id="quadro-ideias">
        <div className="quadro">
          {COLUNAS.map((c) => {
            const daColuna = visiveis.filter((i) => i.status === c.id);
            return (
              <motion.div key={c.id} className="coluna" layout>
                <div className="coluna-cabeca">
                  <span>{c.nome}</span>
                  <span className="conta num">{daColuna.length}</span>
                </div>
                <AnimatePresence mode="popLayout">
                  {daColuna.length === 0 && (
                    <motion.div key="vazia" className="coluna-vazia" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                      Nenhuma ideia aqui
                    </motion.div>
                  )}
                  {daColuna.map((i) => (
                    <motion.button
                      key={i.arquivo}
                      layout
                      layoutId={`ideia-${i.arquivo}`}
                      className={`ideia luz ${mudou(i.arquivo) ? 'mudou' : ''}`}
                      onPointerMove={seguirMouse}
                      onClick={() => abrir(i.arquivo)}
                      initial={{ opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.15 } }}
                      whileHover={{ y: -3 }}
                      transition={{ type: 'spring', stiffness: 380, damping: 32 }}
                    >
                      <h3>{i.titulo}</h3>
                      {i.resumo && (
                        <p>
                          <Md texto={i.resumo} origem={i.arquivo} abrir={abrir} inline />
                        </p>
                      )}
                      <span className="chips">
                        {i.versao && <span className="chip forte">{i.versao}</span>}
                        {i.custo && <span className="chip">{CUSTO[i.custo] || i.custo}</span>}
                        {i.data && <span className="chip">{dataCurta(i.data)}</span>}
                      </span>
                    </motion.button>
                  ))}
                </AnimatePresence>
              </motion.div>
            );
          })}
        </div>
      </LayoutGroup>
    </section>
  );
}
