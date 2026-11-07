// O rumo: as próximas fases como uma linha de metrô (a estação acesa é a de agora),
// a visão V1–V6, o que está parado e o horizonte.

import { motion } from 'motion/react';
import Md from '../pecas/Md.jsx';
import Icone from '../pecas/Icone.jsx';
import { seguirMouse } from '../util.js';

const facil = [0.16, 1, 0.3, 1];

const maiuscula = (t) => t.charAt(0).toUpperCase() + t.slice(1);

const SITUACAO = {
  feita: { texto: 'feita', icone: 'ok' },
  parcial: { texto: 'em parte', icone: 'meia' },
  proxima: { texto: 'a seguir', icone: 'proxima' },
  parada: { texto: 'parada', icone: 'pausa' },
  horizonte: { texto: 'horizonte', icone: 'horizonte' },
};

export default function Rumo({ roadmap, atual, abrir }) {
  const { proximas, versoes, parados, horizonte } = roadmap;
  // A primeira das próximas é a de agora quando o nome bate com a fase em andamento.
  const agoraIdx = proximas.findIndex((p) => atual && p.titulo.toLowerCase().includes(atual.nome.toLowerCase().slice(0, 10)));

  return (
    <section id="rumo" className="secao" aria-labelledby="titulo-rumo">
      <div className="secao-cabeca">
        <div>
          <h2 id="titulo-rumo">O rumo</h2>
          <p>As próximas fases na ordem do ROADMAP. Nenhuma anda sem virar plano antes.</p>
        </div>
        <button className="botao" onClick={() => abrir('ROADMAP.md')}>
          <Icone nome="docs" /> Abrir o ROADMAP
        </button>
      </div>

      <div className="metro" style={{ '--n': proximas.length }}>
        <div className="metro-trilho" aria-hidden="true">
          <motion.i
            initial={{ scaleX: 0, scaleY: 0 }}
            whileInView={{ scaleX: 1, scaleY: 1 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 1.2, ease: facil }}
            style={{ '--frac': agoraIdx >= 0 ? agoraIdx / Math.max(1, proximas.length - 1) : 0 }}
          />
        </div>
        {proximas.map((p, i) => (
          <motion.div
            key={p.titulo}
            className="estacao"
            data-agora={i === agoraIdx}
            initial={{ opacity: 0, y: 18 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.55, delay: 0.15 + i * 0.12, ease: facil }}
          >
            <span className="estacao-ponto num" aria-hidden="true">
              {p.n}
            </span>
            <button className="estacao-cartao luz" onClick={() => abrir('ROADMAP.md', p.cabecalho)} onPointerMove={seguirMouse}>
              {i === agoraIdx && <span className="chip forte" style={{ justifySelf: 'start' }}>agora</span>}
              <h3>{p.titulo}</h3>
              <p>
                <Md texto={maiuscula(p.objetivo.replace(/:$/, '.'))} origem="ROADMAP.md" abrir={abrir} inline />
              </p>
              {p.prontoQuando && (
                <div className="pronto">
                  <b>Pronto quando:</b> <Md texto={p.prontoQuando} origem="ROADMAP.md" abrir={abrir} inline />
                </div>
              )}
            </button>
          </motion.div>
        ))}
      </div>

      <div className="visao" aria-label="As versões da visão">
        {versoes.map((v, i) => {
          const s = SITUACAO[v.situacao] || SITUACAO.horizonte;
          return (
            <motion.div
              key={v.id}
              className="versao"
              data-s={v.situacao}
              initial={{ opacity: 0, scale: 0.96 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true, margin: '-40px' }}
              transition={{ duration: 0.45, delay: i * 0.06, ease: facil }}
            >
              <div className="versao-topo">
                <span className="versao-id">{v.id}</span>
                <span className="selo" data-s={v.situacao}>
                  <Icone nome={s.icone} tamanho={12} /> {s.texto}
                </span>
              </div>
              <h3>{v.nome}</h3>
              <p>{v.oQue}</p>
              {v.texto && (
                <span className="situacao">
                  <Md texto={v.texto} origem="ROADMAP.md" abrir={abrir} inline />
                </span>
              )}
            </motion.div>
          );
        })}
      </div>

      <div className="duas">
        <div className="superficie">
          <h3 className="bloco-titulo">
            Parados
            <small>Nada aqui anda sem uma decisão nova sua.</small>
          </h3>
          <ul className="lista-simples">
            {parados.map((p) => (
              <li key={p.oQue}>
                <b>
                  <Md texto={p.oQue} origem="ROADMAP.md" abrir={abrir} inline />
                </b>
                <span>
                  <Md texto={p.porQue} origem="ROADMAP.md" abrir={abrir} inline />
                </span>
              </li>
            ))}
          </ul>
        </div>
        <div className="superficie">
          <h3 className="bloco-titulo">
            Horizonte
            <small>Ideias guardadas, sem compromisso.</small>
          </h3>
          <div style={{ paddingBottom: 8 }}>
            {horizonte.map((h, i) => (
              <details key={i} className="horizonte">
                <summary>
                  {h.titulo || 'Ideia'}
                  <Icone nome="seta" tamanho={16} />
                </summary>
                <div className="texto">
                  <Md texto={h.texto} origem="ROADMAP.md" abrir={abrir} inline />
                </div>
              </details>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
