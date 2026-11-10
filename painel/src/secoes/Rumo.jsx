// O rumo: as próximas fases na ordem do ROADMAP (a de agora marcada), os pilares e o
// fluxo da visão (Steam → … → Game Hub), o que está parado e o horizonte.

import { Fragment } from 'react';
import Md from '../pecas/Md.jsx';
import Icone from '../pecas/Icone.jsx';

const maiuscula = (t) => t.charAt(0).toUpperCase() + t.slice(1);

export default function Rumo({ roadmap, atual, abrir }) {
  const { visao, proximas, parados, horizonte } = roadmap;
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

      <ol className="proximas">
        {proximas.map((p, i) => (
          <li key={p.titulo} className="proxima-fase" data-agora={i === agoraIdx}>
            <span className="pf-num num" aria-hidden="true">
              {p.n}
            </span>
            <div className="pf-principal">
              <h3>
                <button onClick={() => abrir('ROADMAP.md', p.cabecalho)}>{p.titulo}</button>
                {i === agoraIdx && <span className="selo" data-s="agora">em andamento</span>}
              </h3>
              {p.objetivo && (
                <p className="pf-objetivo">
                  <Md texto={maiuscula(p.objetivo.replace(/:$/, '.'))} origem="ROADMAP.md" abrir={abrir} inline />
                </p>
              )}
              {p.prontoQuando && (
                <p className="pf-pronto">
                  <b>Pronto quando:</b> <Md texto={p.prontoQuando} origem="ROADMAP.md" abrir={abrir} inline />
                </p>
              )}
            </div>
            {p.itens.length > 0 && (
              <ul className="pf-itens">
                {p.itens.map((item, k) => (
                  <li key={k}>
                    <Md texto={maiuscula(item.replace(/;$/, ''))} origem="ROADMAP.md" abrir={abrir} inline />
                  </li>
                ))}
              </ul>
            )}
          </li>
        ))}
      </ol>

      {visao && (visao.pilares.length > 0 || visao.fluxo.length > 0) && (
        <div className="visao-bloco">
          <h3 className="bloco-titulo">Como o mundo nasce</h3>
          {visao.fluxo.length > 0 && (
            <ol className="fluxo" aria-label="Da Steam ao Game Hub">
              {visao.fluxo.map((passo, i) => (
                <Fragment key={passo.nome}>
                  {i > 0 && (
                    <li className="fluxo-seta" aria-hidden="true">
                      <Icone nome="proxima" tamanho={16} />
                    </li>
                  )}
                  <li className="fluxo-passo" data-ultimo={i === visao.fluxo.length - 1}>
                    <b>{maiuscula(passo.nome)}</b>
                    {passo.nota && <small>{passo.nota}</small>}
                  </li>
                </Fragment>
              ))}
            </ol>
          )}
          {visao.pilares.length > 0 && (
            <ul className="pilares">
              {visao.pilares.map((p) => (
                <li key={p.titulo}>
                  <b>{p.titulo}</b>
                  <span>
                    <Md texto={maiuscula(p.texto)} origem="ROADMAP.md" abrir={abrir} inline />
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className="duas">
        <div className="bloco">
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
        <div className="bloco">
          <h3 className="bloco-titulo">
            Horizonte
            <small>Ideias guardadas, sem compromisso.</small>
          </h3>
          <div>
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
