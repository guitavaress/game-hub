// A linha do tempo do Início.md (o gantt), desenhada aqui: as barras crescem
// ao entrar na tela, a fase em andamento tem uma luz correndo, e "hoje" é uma linha.

import { useEffect, useMemo, useRef } from 'react';
import { motion } from 'motion/react';
import { dataCurta } from '../util.js';

const DIA = 864e5;
const ms = (d) => new Date(d + 'T00:00:00Z').getTime();

export default function LinhaDoTempo({ gantt, fases, abrir }) {
  const { ini, fim, marcas, linhas } = useMemo(() => {
    const ini = Math.min(...gantt.map((g) => ms(g.inicio)));
    const fim = Math.max(...gantt.map((g) => ms(g.fim)), Date.now() + 3 * DIA);
    const marcas = [];
    const passo = 7 * DIA;
    for (let t = ini; t <= fim; t += passo) marcas.push(t);
    const linhas = [];
    let secao = null;
    for (const g of gantt) {
      if (g.secao !== secao) {
        secao = g.secao;
        linhas.push({ tipo: 'secao', nome: secao });
      }
      linhas.push({ tipo: 'barra', g });
    }
    return { ini, fim, marcas, linhas };
  }, [gantt]);

  // Quando não cabe (celular), começa mostrando o fim: perto de hoje.
  const caixa = useRef(null);
  useEffect(() => {
    const el = caixa.current;
    if (el && el.scrollWidth > el.clientWidth) el.scrollLeft = el.scrollWidth;
  }, []);

  if (!gantt.length) return null;
  const pct = (t) => `${((t - ini) / (fim - ini)) * 100}%`;
  const hoje = Date.now();
  const porNumero = new Map(fases.map((f) => [f.numero, f]));
  let ordem = 0;

  return (
    <section id="tempo" className="secao" aria-labelledby="titulo-tempo">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-tempo">Linha do tempo</h2>
          <p>As datas vêm dos commits. As próximas fases ainda não têm data: ali a barra só mostra a ordem.</p>
        </div>
        <button className="botao" onClick={() => abrir('Início.md', 'Linha do tempo')}>
          Editar no Início
        </button>
      </div>

      <div className="tempo superficie" ref={caixa}>
        <div className="tempo-grade">
          <div className="tempo-eixo" aria-hidden="true">
            {marcas.map((t) => (
              <span key={t} style={{ left: pct(t) }}>
                {dataCurta(new Date(t).toISOString().slice(0, 10))}
              </span>
            ))}
          </div>
          {linhas.map((l, i) => {
            if (l.tipo === 'secao')
              return (
                <div key={'s' + i} className="tempo-secao">
                  {l.nome}
                </div>
              );
            const { g } = l;
            const plano = g.fase ? porNumero.get(g.fase) : null;
            const n = ordem++;
            const esq = (ms(g.inicio) - ini) / (fim - ini);
            const larg = Math.max((ms(g.fim) - ms(g.inicio)) / (fim - ini), 0.006);
            const titulo = `${g.nome}: ${dataCurta(g.inicio)} a ${dataCurta(g.fim)}${g.semData ? ' (sem data, só a ordem)' : ''}`;
            return (
              <div key={g.chave || g.nome} style={{ display: 'contents' }}>
                <div className="tempo-nome" title={g.nome}>
                  {plano ? <button onClick={() => abrir(plano.arquivo)}>{g.nome}</button> : g.nome}
                </div>
                <div className="tempo-faixa">
                  <motion.div
                    className="barra"
                    data-e={g.estado}
                    title={titulo}
                    style={{ left: `${esq * 100}%`, width: `${larg * 100}%` }}
                    initial={{ scaleX: 0, opacity: 0 }}
                    whileInView={{ scaleX: 1, opacity: 1 }}
                    viewport={{ once: true, margin: '-30px' }}
                    transition={{ duration: 0.7, delay: Math.min(n * 0.045, 0.8), ease: [0.16, 1, 0.3, 1] }}
                  />
                </div>
              </div>
            );
          })}
          <div className="hoje" style={{ left: `calc(var(--nome) + (100% - var(--nome)) * ${(hoje - ini) / (fim - ini)})` }} aria-hidden="true">
            <span>hoje</span>
          </div>
        </div>
      </div>
    </section>
  );
}
