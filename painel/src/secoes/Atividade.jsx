// Atividade: os commits por dia (as últimas 17 semanas) e os últimos commits.

import { useMemo } from 'react';
import { motion } from 'motion/react';
import Icone from '../pecas/Icone.jsx';
import { tempoRelativo } from '../util.js';

const SEMANAS = 17;
const nivel = (n) => (n === 0 ? 0 : n <= 2 ? 1 : n <= 5 ? 2 : n <= 9 ? 3 : 4);
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

export default function Atividade({ git, novos }) {
  const { semanas, total, dias, melhor, sequencia } = useMemo(() => {
    const porDia = git?.porDia || {};
    const hoje = new Date();
    hoje.setHours(12, 0, 0, 0);
    // começa num domingo, SEMANAS atrás
    const inicio = new Date(hoje);
    inicio.setDate(inicio.getDate() - inicio.getDay() - (SEMANAS - 1) * 7);
    const semanas = [];
    let total = 0;
    let dias = 0;
    for (let s = 0; s < SEMANAS; s++) {
      const semana = [];
      for (let d = 0; d < 7; d++) {
        const dia = new Date(inicio);
        dia.setDate(inicio.getDate() + s * 7 + d);
        const chave = iso(dia);
        const n = porDia[chave] || 0;
        const futuro = dia > hoje;
        if (!futuro) {
          total += n;
          if (n) dias += 1;
        }
        semana.push({ chave, n, futuro, hoje: chave === iso(hoje) });
      }
      semanas.push(semana);
    }
    // o dia com mais commits e quantos dias seguidos, até hoje, tiveram commit
    let melhor = { chave: '', n: 0 };
    for (const [chave, n] of Object.entries(porDia)) if (n > melhor.n) melhor = { chave, n };
    let sequencia = 0;
    const d = new Date(hoje);
    if (!porDia[iso(d)]) d.setDate(d.getDate() - 1); // hoje ainda sem commit não quebra a sequência
    while (porDia[iso(d)]) {
      sequencia += 1;
      d.setDate(d.getDate() - 1);
    }
    return { semanas, total, dias, melhor, sequencia };
  }, [git]);

  if (!git) return null;

  return (
    <section id="atividade" className="secao" aria-labelledby="titulo-atividade">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-atividade">Atividade</h2>
          <p>
            Na branch <code>{git.branch || '—'}</code>: <b className="num">{total}</b> commits em <b className="num">{dias}</b> dias nas últimas {SEMANAS} semanas
            {git.total ? (
              <>
                , <span className="num">{git.total}</span> no total
              </>
            ) : null}
            .
          </p>
        </div>
      </div>

      <div className="atividade">
        <div className="calor superficie">
          <div className="calor-grade" role="img" aria-label={`Mapa de commits por dia: ${total} commits nas últimas ${SEMANAS} semanas`}>
            {semanas.map((semana, s) =>
              semana.map((d, i) =>
                d.futuro ? (
                  <i key={d.chave} style={{ visibility: 'hidden' }} />
                ) : (
                  <motion.i
                    key={d.chave}
                    data-n={nivel(d.n)}
                    data-hoje={d.hoje}
                    title={`${new Date(d.chave + 'T12:00:00').toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' })}: ${d.n} commit${d.n === 1 ? '' : 's'}`}
                    initial={{ opacity: 0, scale: 0.4 }}
                    whileInView={{ opacity: 1, scale: 1 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.35, delay: s * 0.035 + i * 0.012, ease: [0.16, 1, 0.3, 1] }}
                  />
                ),
              ),
            )}
          </div>
          <div className="calor-legenda">
            <span>17 semanas, uma coluna por semana</span>
            <span className="escala" aria-hidden="true">
              menos
              {[0, 1, 2, 3, 4].map((n) => (
                <i key={n} className="calor-grade-i" data-n={n} style={{ display: 'inline-block' }} />
              ))}
              mais
            </span>
          </div>
        </div>

        <div className="resumo-commits superficie">
          <div>
            <strong className="num">{total}</strong>
            <span>commits em {SEMANAS} semanas</span>
          </div>
          <div>
            <strong className="num">{dias ? (total / dias).toFixed(1).replace('.', ',') : '0'}</strong>
            <span>commits por dia de trabalho</span>
          </div>
          <div>
            <strong className="num">{melhor.n}</strong>
            <span>no dia mais cheio{melhor.chave ? `, ${new Date(melhor.chave + 'T12:00:00').toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' })}` : ''}</span>
          </div>
          <div>
            <strong className="num">
              {sequencia} {sequencia === 1 ? 'dia' : 'dias'}
            </strong>
            <span>seguidos com commit, até hoje</span>
          </div>
        </div>

        <div className="superficie commits-caixa">
          <ul className="commits">
            {git.commits.map((c, i) => (
              <motion.li
                key={c.hash}
                className={novos.has(c.hash) ? 'mudou' : ''}
                initial={{ opacity: 0, x: 12 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: Math.min(i * 0.035, 0.5), ease: [0.16, 1, 0.3, 1] }}
              >
                <code>
                  <Icone nome="commit" tamanho={13} style={{ verticalAlign: '-2px', marginRight: 4 }} />
                  {c.hash}
                </code>
                <span>{c.assunto}</span>
                <span className="quando">{tempoRelativo(c.data)}</span>
              </motion.li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
