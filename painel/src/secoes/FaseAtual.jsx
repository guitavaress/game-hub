// A fase atual: as subetapas como uma trilha que acende até onde você chegou,
// e o bloco "Para o dono" do plano.

import { useState } from 'react';
import { motion } from 'motion/react';
import Md from '../pecas/Md.jsx';
import Icone from '../pecas/Icone.jsx';
import { seguirMouse } from '../util.js';

const facil = [0.16, 1, 0.3, 1];

export default function FaseAtual({ atual, abrir, mudou }) {
  const [aberto, setAberto] = useState(false);
  if (!atual) return null;
  const validas = atual.subetapas.filter((s) => !s.riscada);
  const idxProxima = validas.findIndex((s) => !s.feita);
  const fracao = validas.length ? (idxProxima < 0 ? 1 : idxProxima / Math.max(1, validas.length - 1)) : 0;

  return (
    <section id="fase" className="secao" aria-labelledby="titulo-fase">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-fase">A fase atual, passo a passo</h2>
          <p>
            As subetapas da Fase {atual.numero} na ordem do plano. A linha acende até a próxima em aberto.
          </p>
        </div>
        <button className="botao" onClick={() => abrir(atual.arquivo)}>
          <Icone nome="docs" /> Abrir o plano
        </button>
      </div>

      <div className="fase-grade">
        <ol className={`trilha superficie ${mudou(atual.arquivo) ? 'mudou' : ''}`} aria-label={`Subetapas da Fase ${atual.numero}`}>
          <span className="trilha-linha" aria-hidden="true" />
          <motion.span
            className="trilha-feita"
            aria-hidden="true"
            initial={{ scaleY: 0 }}
            whileInView={{ scaleY: fracao }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 1.6, ease: facil }}
          />
          {validas.map((s, i) => {
            const estado = s.feita ? 'feita' : i === idxProxima ? 'proxima' : 'futura';
            return (
              <motion.li
                key={s.id + s.nome}
                className="passo"
                data-estado={estado}
                initial={{ opacity: 0, x: -10 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, margin: '-40px' }}
                transition={{ duration: 0.45, delay: Math.min(i * 0.05, 0.6), ease: facil }}
              >
                <span className="no" aria-hidden="true" />
                <button onClick={() => abrir(atual.arquivo, `${s.id} ${s.nome}`)} aria-label={`${s.id} ${s.nome}, ${estado === 'feita' ? 'feita' : estado === 'proxima' ? 'próxima' : 'em aberto'}`}>
                  <div className="passo-topo">
                    <span className="passo-id">{s.id}</span>
                    <span className="passo-nome">{s.nome}</span>
                  </div>
                  {(s.tamanho || s.hashes.length > 0 || estado === 'proxima') && (
                    <div className="passo-meta">
                      {estado === 'proxima' && <span className="chip forte">próxima</span>}
                      {s.tamanho && <span className="chip">{s.tamanho}</span>}
                      {s.hashes.slice(0, 3).map((h) => (
                        <span key={h} className="chip">
                          <code>{h}</code>
                        </span>
                      ))}
                    </div>
                  )}
                </button>
              </motion.li>
            );
          })}
        </ol>

        <aside className="dono superficie luz" onPointerMove={seguirMouse}>
          <h3>Para o dono</h3>
          <div className="progresso">
            <div className="progresso-barra" aria-hidden="true">
              {validas.map((s, i) => (
                <motion.i
                  key={s.id + i}
                  data-feita={s.feita}
                  data-proxima={i === idxProxima}
                  initial={{ scaleX: 0 }}
                  whileInView={{ scaleX: 1 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.4, delay: i * 0.04, ease: facil }}
                />
              ))}
            </div>
            <small className="num">
              {atual.feitas} de {atual.total} subetapas · {atual.status}
            </small>
          </div>
          <motion.div
            className="recorte"
            data-aberto={aberto}
            initial={false}
            animate={{ height: aberto ? 'auto' : 280 }}
            transition={{ duration: 0.45, ease: facil }}
          >
            <ul>
              {atual.paraODono.map((item, i) => (
                <li key={i}>
                  <Md texto={item} origem={atual.arquivo} abrir={abrir} inline />
                </li>
              ))}
            </ul>
          </motion.div>
          <button className="botao" onClick={() => setAberto((a) => !a)} aria-expanded={aberto}>
            {aberto ? 'Mostrar menos' : 'Ler tudo'}
          </button>
        </aside>
      </div>
    </section>
  );
}
