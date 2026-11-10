// Os avisos "ao vivo" no canto da tela: o que mudou no cofre.

import { AnimatePresence, motion } from 'motion/react';
import Icone from './Icone.jsx';

export default function Avisos({ avisos, abrir }) {
  return (
    <div className="avisos" role="status" aria-live="polite">
      <AnimatePresence initial={false}>
        {avisos.map((a) => (
          <motion.div
            key={a.id}
            layout
            className="aviso"
            initial={{ opacity: 0, y: 24, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, x: 40, transition: { duration: 0.2 } }}
            transition={{ type: 'spring', stiffness: 380, damping: 30 }}
          >
            <Icone nome="vivo" />
            <div>
              <b>{a.titulo}</b>
              <span>
                {a.arquivos.slice(0, 3).map((arq, i) => (
                  <span key={arq}>
                    {i > 0 && ', '}
                    {arq.endsWith('.md') ? (
                      <a href="#" onClick={(e) => (e.preventDefault(), abrir(arq))}>
                        {arq}
                      </a>
                    ) : (
                      arq
                    )}
                  </span>
                ))}
                {a.arquivos.length > 3 && ` e mais ${a.arquivos.length - 3}`}
              </span>
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
