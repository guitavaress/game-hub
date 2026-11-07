// O painel inteiro: a barra lateral, as seções, o leitor, a busca e os avisos ao vivo.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, LayoutGroup, MotionConfig, motion } from 'motion/react';
import { useCofre } from './dados.js';
import Icone from './pecas/Icone.jsx';
import Leitor from './pecas/Leitor.jsx';
import Paleta from './pecas/Paleta.jsx';
import Avisos from './pecas/Avisos.jsx';
import Agora from './secoes/Agora.jsx';
import FaseAtual from './secoes/FaseAtual.jsx';
import Rumo from './secoes/Rumo.jsx';
import LinhaDoTempo from './secoes/LinhaDoTempo.jsx';
import OQueFalta from './secoes/OQueFalta.jsx';
import Ideias from './secoes/Ideias.jsx';
import Atividade from './secoes/Atividade.jsx';
import Documentos from './secoes/Documentos.jsx';
import { lerPreferencia, salvarPreferencia, tempoRelativo } from './util.js';

const SECOES = [
  { id: 'agora', nome: 'Agora', icone: 'agora' },
  { id: 'fase', nome: 'Fase atual', icone: 'fase' },
  { id: 'rumo', nome: 'Rumo', icone: 'rumo' },
  { id: 'tempo', nome: 'Linha do tempo', icone: 'tempo' },
  { id: 'falta', nome: 'O que falta', icone: 'falta', conta: (d) => d.tarefas.length },
  { id: 'ideias', nome: 'Ideias', icone: 'ideia', conta: (d) => d.ideias.length },
  { id: 'atividade', nome: 'Atividade', icone: 'atividade' },
  { id: 'docs', nome: 'Documentos', icone: 'docs', conta: (d) => d.docs.length },
];

// Qual seção está no meio da tela (para acender o item da barra lateral).
function useSecaoVisivel(pronto) {
  const [atual, setAtual] = useState('agora');
  useEffect(() => {
    if (!pronto) return;
    const obs = new IntersectionObserver(
      (entradas) => {
        for (const e of entradas) if (e.isIntersecting) setAtual(e.target.id);
      },
      { rootMargin: '-35% 0px -60% 0px' },
    );
    SECOES.forEach((s) => {
      const el = document.getElementById(s.id);
      if (el) obs.observe(el);
    });
    return () => obs.disconnect();
  }, [pronto]);
  return atual;
}

export default function App() {
  const { dados, erro, conexao, mudanca } = useCofre();
  const [tema, setTema] = useState(() => document.documentElement.dataset.theme || 'dark');
  const [movimento, setMovimento] = useState(() => (lerPreferencia('painel-movimento', 'on') === 'off' ? 'off' : 'on'));
  const [leitor, setLeitor] = useState(null); // { arquivo, ancora }
  const [paleta, setPaleta] = useState(false);
  const [menu, setMenu] = useState(false);
  const [avisos, setAvisos] = useState([]);
  const [recentes, setRecentes] = useState(() => new Set());
  const [novosCommits, setNovosCommits] = useState(() => new Set());
  const [, setRelogio] = useState(0);
  const commitsAntes = useRef(null);
  const secao = useSecaoVisivel(!!dados);

  // tema e movimento ficam no <html> e são lembrados neste navegador
  useEffect(() => {
    document.documentElement.dataset.theme = tema;
    salvarPreferencia('painel-tema', tema);
  }, [tema]);
  useEffect(() => {
    document.documentElement.dataset.motion = movimento;
    salvarPreferencia('painel-movimento', movimento);
  }, [movimento]);

  // "lido há X" se atualiza sozinho
  useEffect(() => {
    const t = setInterval(() => setRelogio((n) => n + 1), 15000);
    return () => clearInterval(t);
  }, []);

  // guarda os commits da primeira leitura, para saber quais chegaram depois
  useEffect(() => {
    if (dados && !commitsAntes.current) commitsAntes.current = new Set(dados.git?.commits.map((c) => c.hash));
  }, [dados]);

  // o cofre mudou: aviso no canto e o que mudou acende por uns segundos
  useEffect(() => {
    if (!mudanca || !dados) return;
    const arquivos = mudanca.mudou.filter((a) => a !== '(git)');
    const doGit = mudanca.mudou.includes('(git)');
    const novos = (dados.git?.commits || []).filter((c) => commitsAntes.current && !commitsAntes.current.has(c.hash));
    if (novos.length) {
      novos.forEach((c) => commitsAntes.current.add(c.hash));
      setNovosCommits((s) => new Set([...s, ...novos.map((c) => c.hash)]));
    }
    const lista = [];
    if (arquivos.length) lista.push({ id: `${mudanca.versao}-a`, titulo: arquivos.length === 1 ? 'Documento atualizado' : `${arquivos.length} documentos atualizados`, arquivos });
    if (doGit && novos.length) lista.push({ id: `${mudanca.versao}-g`, titulo: novos.length === 1 ? 'Commit novo' : `${novos.length} commits novos`, arquivos: novos.map((c) => c.assunto) });
    if (!lista.length) return;
    setAvisos((a) => [...a, ...lista].slice(-4));
    setRecentes(new Set(arquivos));
    const t1 = setTimeout(() => setRecentes(new Set()), 3000);
    const t2 = setTimeout(() => setAvisos((a) => a.filter((x) => !lista.some((l) => l.id === x.id))), 6500);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
  }, [mudanca]); // eslint-disable-line react-hooks/exhaustive-deps

  const mudou = useCallback((arquivo) => recentes.has(arquivo), [recentes]);

  const abrir = useCallback((arquivo, ancora = '') => {
    setPaleta(false);
    setMenu(false);
    setLeitor({ arquivo, ancora });
  }, []);
  const fecharLeitor = useCallback(() => setLeitor(null), []);
  const fecharPaleta = useCallback(() => setPaleta(false), []);

  // Ctrl+K (ou /) abre a busca
  useEffect(() => {
    const tecla = (e) => {
      const digitando = /input|textarea|select/i.test(document.activeElement?.tagName || '');
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setPaleta((p) => !p);
      } else if (e.key === '/' && !digitando && !leitor) {
        e.preventDefault();
        setPaleta(true);
      }
    };
    window.addEventListener('keydown', tecla);
    return () => window.removeEventListener('keydown', tecla);
  }, [leitor]);

  const atual = useMemo(() => dados?.fases.find((f) => f.arquivo === dados.faseAtual) || null, [dados]);
  const docAberto = leitor && dados ? dados.docs.find((d) => d.arquivo === leitor.arquivo) : null;

  if (!dados) {
    return (
      <div className="carregando" role="status">
        <div>
          <img src="/logo.png" alt="" />
          <p>{erro ? `Não consegui ler o cofre (${erro}). O servidor do painel está rodando?` : 'Abrindo o cofre…'}</p>
        </div>
      </div>
    );
  }

  const textoConexao =
    conexao === 'ao-vivo' ? (
      <>
        <b>Ao vivo</b> · lido {tempoRelativo(dados.geradoEm)}
      </>
    ) : conexao === 'offline' ? (
      <>
        <b>Sem conexão</b> · tentando de novo
      </>
    ) : (
      <>Conectando…</>
    );

  const botoes = (
    <div className="ferramentas">
      <button className="botao cresce" onClick={() => setPaleta(true)} aria-label="Buscar nos documentos (Ctrl+K)">
        <Icone nome="busca" /> <span className="texto-busca">Buscar</span> <kbd>Ctrl K</kbd>
      </button>
      <button
        className="botao icone"
        onClick={() => setTema((t) => (t === 'dark' ? 'light' : 'dark'))}
        aria-label={tema === 'dark' ? 'Usar o tema claro' : 'Usar o tema escuro'}
        title={tema === 'dark' ? 'Tema claro' : 'Tema escuro'}
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.span key={tema} style={{ display: 'grid' }} initial={{ rotate: -90, opacity: 0 }} animate={{ rotate: 0, opacity: 1 }} exit={{ rotate: 90, opacity: 0 }} transition={{ duration: 0.2 }}>
            <Icone nome={tema === 'dark' ? 'sol' : 'lua'} />
          </motion.span>
        </AnimatePresence>
      </button>
      <button
        className="botao icone"
        onClick={() => setMovimento((m) => (m === 'on' ? 'off' : 'on'))}
        aria-pressed={movimento === 'off'}
        aria-label={movimento === 'on' ? 'Desligar as animações' : 'Ligar as animações'}
        title={movimento === 'on' ? 'Desligar as animações' : 'Ligar as animações'}
      >
        <Icone nome={movimento === 'on' ? 'movimento' : 'parado'} />
      </button>
    </div>
  );

  return (
    <MotionConfig reducedMotion={movimento === 'off' ? 'always' : 'user'}>
      <div className="casca">
        <header className="topo-movel">
          <a className="marca" href="#agora">
            <img src="/logo.png" alt="" />
            <span>
              <strong>Game Hub</strong>
            </span>
          </a>
          <div className="ferramentas">
            <button className="botao icone" onClick={() => setPaleta(true)} aria-label="Buscar nos documentos">
              <Icone nome="busca" />
            </button>
            <button className="botao icone" onClick={() => setMenu((m) => !m)} aria-label="Menu" aria-expanded={menu}>
              <Icone nome={menu ? 'fechar' : 'menu'} />
            </button>
          </div>
        </header>

        <nav className="lateral" data-aberta={menu} aria-label="Seções do painel">
          <a className="marca" href="#agora" onClick={() => setMenu(false)}>
            <img src="/logo.png" alt="" />
            <span>
              <strong>Game Hub</strong>
              <small>O cofre do projeto</small>
            </span>
          </a>
          <LayoutGroup id="nav">
            <ul className="nav">
              {SECOES.map((s) => (
                <li key={s.id}>
                  <a href={`#${s.id}`} aria-current={secao === s.id} onClick={() => setMenu(false)}>
                    {secao === s.id && <motion.span className="marcador" layoutId="marcador-nav" transition={{ type: 'spring', stiffness: 420, damping: 36 }} />}
                    <Icone nome={s.icone} />
                    {s.nome}
                    {s.conta && <span className="conta">{s.conta(dados)}</span>}
                  </a>
                </li>
              ))}
            </ul>
          </LayoutGroup>
          <div className="lateral-pe">
            <div className="ao-vivo" role="status">
              <span className="pulso" data-estado={conexao} aria-hidden="true" />
              <span>{textoConexao}</span>
            </div>
            {botoes}
          </div>
        </nav>

        <main className="conteudo">
          <Agora dados={dados} atual={atual} abrir={abrir} />
          <FaseAtual atual={atual} abrir={abrir} mudou={mudou} />
          <Rumo roadmap={dados.roadmap} atual={atual} abrir={abrir} />
          <LinhaDoTempo gantt={dados.inicio.gantt} fases={dados.fases} abrir={abrir} />
          <OQueFalta tarefas={dados.tarefas} docs={dados.docs} abrir={abrir} mudou={mudou} />
          <Ideias ideias={dados.ideias} abrir={abrir} mudou={mudou} />
          <Atividade git={dados.git} novos={novosCommits} />
          <Documentos docs={dados.docs} abrir={abrir} mudou={mudou} />
        </main>
      </div>

      <AnimatePresence>
        {leitor && docAberto && <Leitor key="leitor" doc={docAberto} ancora={leitor.ancora} abrir={abrir} fechar={fecharLeitor} />}
      </AnimatePresence>
      <AnimatePresence>{paleta && <Paleta key="paleta" docs={dados.docs} abrir={abrir} fechar={fecharPaleta} />}</AnimatePresence>
      <Avisos avisos={avisos} abrir={abrir} />
    </MotionConfig>
  );
}
