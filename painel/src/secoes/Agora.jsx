// A abertura: a cidade do projeto, a fase atual, a próxima subetapa e os números.

import { useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion, useInView } from 'motion/react';
import Cidade from '../fundo/Cidade.jsx';
import Contador from '../pecas/Contador.jsx';
import Md from '../pecas/Md.jsx';
import Icone from '../pecas/Icone.jsx';

const sobe = (atraso) => ({
  initial: { opacity: 0, y: 16, filter: 'blur(6px)' },
  animate: { opacity: 1, y: 0, filter: 'blur(0px)' },
  transition: { duration: 0.7, delay: atraso, ease: [0.16, 1, 0.3, 1] },
});

function descrever(p) {
  if (!p) return null;
  if (p.estado === 'futura') return { nome: p.nome, detalhe: 'próxima fase, ainda sem plano' };
  const s = `${p.feitas} de ${p.total} ${p.plano ? 'subetapas' : 'partes'}`;
  return { nome: p.nome, detalhe: p.estado === 'andamento' ? `${s} · em andamento` : `${s} · feita` };
}

export default function Agora({ dados, atual, abrir }) {
  const [foco, setFoco] = useState(null);
  // fora da tela, as luzes que piscam param (economiza e não distrai)
  const cena = useRef(null);
  const cenaVisivel = useInView(cena);
  const proxima = atual?.subetapas.find((s) => !s.feita && !s.riscada);

  const numeros = useMemo(() => {
    const hoje = Date.now();
    const commits30 = Object.entries(dados.git?.porDia || {}).reduce(
      (s, [dia, n]) => (hoje - new Date(dia + 'T12:00:00').getTime() <= 30 * 864e5 ? s + n : s),
      0,
    );
    return [
      { v: dados.fases.filter((f) => f.situacao === 'feita' || f.situacao === 'reaberta').length, t: 'fases com plano concluídas' },
      { v: dados.fases.reduce((s, f) => s + f.feitas, 0), t: 'subetapas feitas, todas as fases' },
      { v: dados.tarefas.length, t: 'tarefas abertas nos planos' },
      { v: dados.ideias.length, t: 'ideias na caixa de entrada' },
      { v: commits30, t: 'commits nos últimos 30 dias' },
    ];
  }, [dados]);

  const legenda = descrever(foco);

  return (
    <section id="agora" className="agora" aria-labelledby="titulo-agora">
      <div className="cena" ref={cena} data-pausada={!cenaVisivel}>
        <div className="cena-texto">
          <div>
            <motion.h1 id="titulo-agora" {...sobe(0.15)}>
              {atual ? (
                <>
                  <span className="fase-num">Fase {atual.numero}</span> · {atual.nome}
                </>
              ) : (
                'Nenhuma fase em andamento'
              )}
            </motion.h1>
            {atual && (
              <motion.div className="cena-meta" {...sobe(0.3)}>
                <span>
                  <b className="num">{atual.feitas}</b> de <b className="num">{atual.total}</b> subetapas feitas
                </span>
                {dados.git?.branch && (
                  <span>
                    branch <code>{dados.git.branch}</code>
                  </span>
                )}
              </motion.div>
            )}
          </div>
          {proxima && (
            <motion.button className="proxima" onClick={() => abrir(atual.arquivo, `${proxima.id} ${proxima.nome}`)} {...sobe(0.45)}>
              <small>Próxima subetapa</small>
              <strong>
                {proxima.id} · {proxima.nome}
              </strong>
              <small>
                {proxima.tamanho || 'sem tamanho'} · abrir no plano <Icone nome="seta" tamanho={12} style={{ verticalAlign: '-1px' }} />
              </small>
            </motion.button>
          )}
        </div>

        <Cidade gantt={dados.inicio.gantt} fases={dados.fases} abrir={abrir} aoFocar={setFoco} />

        <div className="cena-legenda">
          <AnimatePresence mode="wait" initial={false}>
            <motion.span
              key={legenda ? legenda.nome : 'padrao'}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.18 }}
            >
              {legenda ? (
                <>
                  <b>{legenda.nome}</b> · {legenda.detalhe}
                </>
              ) : (
                <>Cada prédio é uma fase e cada janela acesa, uma subetapa feita. Passe o mouse (ou toque) para ver; clique para abrir o plano.</>
              )}
            </motion.span>
          </AnimatePresence>
          <span className="chaves" aria-hidden="true">
            <span className="chave">
              <i className="amostra" style={{ background: '#67e8f9' }} /> feita
            </span>
            <span className="chave">
              <i className="amostra" style={{ background: '#67e8f9', animation: 'piscar 1.4s infinite' }} /> próxima
            </span>
            <span className="chave">
              <i className="amostra" style={{ outline: '1px dashed #3a5a7b' }} /> fase futura
            </span>
          </span>
        </div>
      </div>

      <div className="regua" aria-label="Números do projeto">
        {numeros.map((n) => (
          <div key={n.t}>
            <strong>
              <Contador valor={n.v} />
            </strong>
            <span>{n.t}</span>
          </div>
        ))}
      </div>

      {dados.inicio.agora.length > 0 && (
        <ul className="agora-lista superficie" aria-label="Agora, do Início">
          {dados.inicio.agora.map((item, i) => (
            <motion.li
              key={i}
              className="agora-item"
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-40px' }}
              transition={{ duration: 0.5, delay: i * 0.06, ease: [0.16, 1, 0.3, 1] }}
            >
              <Md texto={item} origem="Início.md" abrir={abrir} inline />
            </motion.li>
          ))}
        </ul>
      )}
    </section>
  );
}
