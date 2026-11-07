// O leitor: uma gaveta que abre o documento formatado, com o título vindo
// do lugar onde você clicou (layoutId) e o botão "Abrir no Obsidian".

import { useEffect, useRef } from 'react';
import { motion } from 'motion/react';
import Icone from './Icone.jsx';
import Md from './Md.jsx';
import { linkObsidian, slug, tempoRelativo } from '../util.js';

export default function Leitor({ doc, ancora, abrir, fechar }) {
  const corpo = useRef(null);
  const botaoFechar = useRef(null);

  // Esc fecha; o foco vai para o botão de fechar e volta ao fechar.
  useEffect(() => {
    const antes = document.activeElement;
    botaoFechar.current?.focus({ preventScroll: true });
    const tecla = (e) => e.key === 'Escape' && fechar();
    window.addEventListener('keydown', tecla);
    return () => {
      window.removeEventListener('keydown', tecla);
      if (antes && antes.focus) antes.focus({ preventScroll: true });
    };
  }, [fechar]);

  // Vai até a âncora (#titulo) e acende o trecho por um instante.
  useEffect(() => {
    const el = corpo.current;
    if (!el) return;
    if (!ancora) {
      el.scrollTop = 0;
      return;
    }
    const id = slug(ancora);
    const t = setTimeout(() => {
      // 1) um título com esse id; 2) senão, o primeiro trecho que começa com o texto (ex.: uma subetapa).
      let alvo = el.querySelector(`[id="${CSS.escape(id)}"]`) || el.querySelector(`[id="${CSS.escape(ancora)}"]`);
      if (!alvo) {
        const procura = ancora.toLowerCase();
        alvo = [...el.querySelectorAll('li, p, h2, h3, h4, tr')].find((n) => n.textContent.trim().toLowerCase().startsWith(procura));
      }
      if (alvo) {
        alvo.scrollIntoView({ block: alvo.matches('h2, h3, h4') ? 'start' : 'center' });
        alvo.classList.remove('alvo');
        void alvo.offsetWidth;
        alvo.classList.add('alvo');
      }
    }, 260);
    return () => clearTimeout(t);
  }, [doc?.arquivo, ancora]);

  if (!doc) return null;

  return (
    <>
      <motion.div className="veu" onClick={fechar} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.18 } }} />
      <motion.aside
        className="leitor"
        role="dialog"
        aria-modal="true"
        aria-label={doc.titulo}
        initial={{ x: 48, opacity: 0, filter: 'blur(6px)' }}
        animate={{ x: 0, opacity: 1, filter: 'blur(0px)' }}
        exit={{ x: 32, opacity: 0, transition: { duration: 0.18, ease: [0.4, 0, 1, 1] } }}
        transition={{ duration: 0.42, ease: [0.16, 1, 0.3, 1] }}
      >
        <header className="leitor-topo">
          <div>
            <h2>{doc.titulo}</h2>
            <small>
              {doc.arquivo} · mudou {tempoRelativo(doc.modificado)}
            </small>
          </div>
          <div className="leitor-acoes">
            <a className="botao" href={linkObsidian(doc.arquivo)} title="Abrir esta nota no Obsidian">
              <Icone nome="fora" />
              <span className="texto-botao">Abrir no Obsidian</span>
            </a>
            <button ref={botaoFechar} className="botao icone" onClick={fechar} aria-label="Fechar o documento (Esc)">
              <Icone nome="fechar" />
            </button>
          </div>
        </header>
        <div className="leitor-corpo" ref={corpo}>
          <Md texto={doc.texto} origem={doc.arquivo} abrir={abrir} />
        </div>
      </motion.aside>
    </>
  );
}
