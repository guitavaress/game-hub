// A abertura: a visão do produto (a frase do ROADMAP e as 3 etapas), o quadro das
// versões V1–V6 com uma ilustração cada, a fase em andamento, as próximas fases e o ritmo.

import { useMemo } from 'react';
import Contador from '../pecas/Contador.jsx';
import Md from '../pecas/Md.jsx';
import Icone from '../pecas/Icone.jsx';
import { slug } from '../util.js';

// As ilustrações (geradas no ComfyUI, em public/visao/). Versão sem imagem fica só com cor.
const IMAGENS = new Set(['V1', 'V2', 'V3', 'V4', 'V5', 'V6']);

export const SITUACAO = {
  feita: { texto: 'feita', icone: 'ok' },
  parcial: { texto: 'em parte', icone: 'meia' },
  proxima: { texto: 'a seguir', icone: 'proxima' },
  parada: { texto: 'parada', icone: 'pausa' },
  horizonte: { texto: 'horizonte', icone: 'horizonte' },
};
const FUTURO = new Set(['proxima', 'parada', 'horizonte']);

// "V1 e V2" / "V1, V2 e V3"
const juntar = (ids) => (ids.length < 2 ? ids.join('') : `${ids.slice(0, -1).join(', ')} e ${ids.at(-1)}`);

function resumoDasVersoes(versoes) {
  const feitas = versoes.filter((v) => v.situacao === 'feita').map((v) => v.id);
  const parte = versoes.filter((v) => v.situacao === 'parcial').map((v) => v.id);
  const proxima = versoes.find((v) => v.situacao === 'proxima');
  const frases = [];
  if (feitas.length) frases.push(`${juntar(feitas)} ${feitas.length > 1 ? 'estão feitas' : 'está feita'}`);
  if (parte.length) frases.push(`${juntar(parte)} já começou`);
  let texto = frases.join(', e ');
  if (proxima) texto += `${texto ? '. ' : ''}A próxima é ${proxima.id}, ${proxima.nome.toLowerCase()}`;
  return texto ? `${texto}.` : '';
}

// A etapa do produto que vem a seguir é a que aponta para uma das próximas fases;
// a de agora é a anterior a ela. Sem esse link, nenhuma é marcada.
function etapaDeAgora(produto, proximas) {
  const ancoras = new Set(proximas.map((p) => slug(p.cabecalho)));
  const iProxima = produto.findIndex((e) => [...e.chegaQuando.matchAll(/\]\(#([^)]+)\)/g)].some((m) => ancoras.has(m[1])));
  return iProxima > 0 ? iProxima - 1 : -1;
}

// "2 ou 3 amigos instalam e usam (fase [Mostrar…](#…))" → "2 ou 3 amigos instalam e usam"
const primeiraFrase = (md) =>
  md
    .replace(/\s*\([^()]*\[[^\]]*\]\([^)]*\)\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .split(/\.\s/)[0]
    .replace(/\.$/, '');

const DIA = 864e5;
const isoLocal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const diaCurto = (d) => d.toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' }).replace('.', '');

export default function Agora({ dados, atual, abrir, mudou }) {
  const { roadmap, fases, git } = dados;
  const { visao, produto, versoes, proximas } = roadmap;
  const agoraEtapa = etapaDeAgora(produto, proximas);
  const resumo = resumoDasVersoes(versoes);

  const validas = atual ? atual.subetapas.filter((s) => !s.riscada) : [];
  const iProxima = validas.findIndex((s) => !s.feita);
  const proxima = iProxima >= 0 ? validas[iProxima] : null;

  // as próximas fases do ROADMAP, sem a que já está em andamento
  const seguintes = useMemo(() => {
    const nomeAtual = atual?.nome.toLowerCase().slice(0, 10) || '\u0000';
    return proximas
      .filter((p) => !p.titulo.toLowerCase().includes(nomeAtual))
      .map((p) => ({ ...p, plano: fases.find((f) => f.situacao !== 'feita' && p.titulo.toLowerCase().includes(f.nome.toLowerCase().slice(0, 10))) }));
  }, [proximas, fases, atual]);

  // commits por dia nos últimos 30 dias (hoje incluído)
  const ritmo = useMemo(() => {
    const porDia = git?.porDia || {};
    const hoje = new Date();
    hoje.setHours(12, 0, 0, 0);
    const dias = Array.from({ length: 30 }, (_, i) => {
      const d = new Date(hoje.getTime() - (29 - i) * DIA);
      return { d, n: porDia[isoLocal(d)] || 0 };
    });
    const total = dias.reduce((s, x) => s + x.n, 0);
    const maior = Math.max(1, ...dias.map((x) => x.n));
    return { dias, total, maior };
  }, [git]);

  const comPlano = fases.filter((f) => f.ehFase);
  const feitasTodas = comPlano.reduce((s, f) => s + f.feitas, 0);
  const totalTodas = comPlano.reduce((s, f) => s + f.total, 0);
  const semPlano = seguintes.filter((p) => !p.plano).length;

  return (
    <section id="agora" className="agora" aria-labelledby="titulo-agora">
      <div className="abre">
        <div className="abre-imagem" aria-hidden="true">
          <img src="/visao/abertura.webp" alt="" width="1600" height="900" fetchPriority="high" />
          <span className="legenda-ilustracao">ilustração</span>
        </div>
        <div className="abre-texto">
          <h1 id="titulo-agora">Game Hub</h1>
          {visao?.frase && (
            <p className="lema">
              <Md texto={visao.frase.replace(/^O Game Hub é um/, 'Um')} origem="ROADMAP.md" abrir={abrir} inline />
            </p>
          )}
          {resumo && <p className="resumo-visao">{resumo}</p>}
          {produto.length > 0 && (
            <ol className="etapas" aria-label="O caminho do produto">
              {produto.map((e, i) => (
                <li key={e.etapa} className="etapa" data-estado={i === agoraEtapa ? 'agora' : i < agoraEtapa ? 'feita' : 'depois'}>
                  <b>
                    <span className="num">{e.etapa}</span> {e.paraQuem}
                    {i === agoraEtapa && <span className="aqui">agora</span>}
                  </b>
                  <span>{primeiraFrase(e.chegaQuando)}</span>
                </li>
              ))}
            </ol>
          )}
        </div>
      </div>

      <ol className="quadro-visao" aria-label="As versões da visão">
        {versoes.map((v, i) => {
          const s = SITUACAO[v.situacao] || SITUACAO.horizonte;
          return (
            <li key={v.id} className="versao" data-s={v.situacao} data-futuro={FUTURO.has(v.situacao)} style={{ '--i': i }}>
              <figure className="versao-imagem" aria-hidden="true">
                {IMAGENS.has(v.id) ? <img src={`/visao/${v.id.toLowerCase()}.webp`} alt="" width="800" height="450" loading="lazy" /> : <span className="sem-imagem" />}
              </figure>
              <span className="versao-id" aria-hidden="true">
                {v.id}
              </span>
              <div className="versao-corpo">
                <span className="selo" data-s={v.situacao}>
                  <Icone nome={s.icone} tamanho={13} /> {s.texto}
                </span>
                <h3>
                  <button onClick={() => abrir('ROADMAP.md', 'As versões da visão')}>
                    <span className="sr">{v.id}: </span>
                    {v.nome}
                  </button>
                </h3>
                <p>{v.oQue}.</p>
                {v.texto && (
                  <p className="versao-fases">
                    <Md texto={v.texto.charAt(0).toUpperCase() + v.texto.slice(1)} origem="ROADMAP.md" abrir={abrir} inline />
                  </p>
                )}
              </div>
            </li>
          );
        })}
      </ol>

      <div className="faixa">
        <div className="faixa-bloco">
          <h2>Em andamento</h2>
          {atual ? (
            <div className={`em-andamento ${mudou(atual.arquivo) ? 'mudou' : ''}`}>
              <button className="ea-nome" onClick={() => abrir(atual.arquivo)}>
                <span className="ea-num num">{atual.numero}</span>
                <span>
                  <b>{atual.nome}</b>
                  <small>
                    <span className="num">{atual.feitas}</span> de <span className="num">{atual.total}</span> subetapas
                    {atual.branch && (
                      <>
                        {' · '}branch <code>{atual.branch}</code>
                      </>
                    )}
                  </small>
                </span>
              </button>
              <div className="regua" role="img" aria-label={`${atual.feitas} de ${atual.total} subetapas feitas`}>
                {validas.map((s, k) => (
                  <i key={s.id + k} data-e={s.feita ? 'feita' : k === iProxima ? 'proxima' : 'aberta'} title={`${s.id} ${s.nome}`} />
                ))}
              </div>
              {proxima && (
                <button className="botao-claro" onClick={() => abrir(atual.arquivo, `${proxima.id} ${proxima.nome}`)}>
                  <span>
                    <small>Próxima subetapa{proxima.tamanho ? ` · ${proxima.tamanho}` : ''}</small>
                    <b>
                      <span className="num">{proxima.id}</span> {proxima.nome}
                    </b>
                  </span>
                  <Icone nome="proxima" />
                </button>
              )}
            </div>
          ) : (
            <p className="vazio">Nenhuma fase em andamento nos planos.</p>
          )}
        </div>

        <div className="faixa-bloco">
          <h2>Depois desta</h2>
          {seguintes.length ? (
            <ol className="seguintes">
              {seguintes.map((p) => (
                <li key={p.titulo}>
                  <button onClick={() => abrir('ROADMAP.md', p.cabecalho)}>
                    <span className="num">{p.n}</span>
                    <b>{p.titulo}</b>
                    <small>{p.plano ? 'com plano' : 'sem plano ainda'}</small>
                  </button>
                </li>
              ))}
            </ol>
          ) : (
            <p className="vazio">O ROADMAP não lista próximas fases.</p>
          )}
          <p className="nota-faixa">
            <span className="num">{feitasTodas}</span> de <span className="num">{totalTodas}</span> subetapas feitas nas fases com plano
            {semPlano > 0 && <>; {semPlano === 1 ? 'a fase seguinte ainda não tem plano' : `as ${semPlano} seguintes ainda não têm plano`}</>}.
          </p>
        </div>

        <div className="faixa-bloco">
          <h2>
            <Contador valor={ritmo.total} /> commits em 30 dias
          </h2>
          <div className="ritmo" role="img" aria-label={`Commits por dia nos últimos 30 dias: ${ritmo.total} no total`}>
            {ritmo.dias.map((x) => (
              <i key={x.d.getTime()} style={{ '--h': x.n ? Math.max(6, (x.n / ritmo.maior) * 100) : 0 }} data-zero={!x.n} title={`${diaCurto(x.d)}: ${x.n} commit${x.n === 1 ? '' : 's'}`} />
            ))}
          </div>
          <div className="ritmo-eixo" aria-hidden="true">
            <span>{diaCurto(ritmo.dias[0].d)}</span>
            <span>{diaCurto(ritmo.dias[15].d)}</span>
            <span>hoje</span>
          </div>
        </div>
      </div>

      {dados.inicio.agora.length > 0 && (
        <div className="do-inicio">
          <h2>
            Do <button onClick={() => abrir('Início.md', 'Agora')}>Início</button>
          </h2>
          <ul>
            {dados.inicio.agora.map((item, i) => (
              <li key={i}>
                <Md texto={item} origem="Início.md" abrir={abrir} inline />
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
