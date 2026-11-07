// Um número que corre até o valor novo (na abertura e quando o cofre muda).

import { useEffect, useRef } from 'react';
import { animate, useInView, useReducedMotion } from 'motion/react';

export default function Contador({ valor }) {
  const ref = useRef(null);
  const anterior = useRef(0);
  const visivel = useInView(ref, { once: true });
  const reduzir = useReducedMotion();

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (!visivel) return; // fora da tela: fica o valor real, e a contagem espera
    if (reduzir) {
      el.textContent = String(valor);
      anterior.current = valor;
      return;
    }
    const controle = animate(anterior.current, valor, {
      duration: anterior.current === 0 ? 1.4 : 0.8,
      ease: [0.16, 1, 0.3, 1],
      onUpdate: (v) => {
        el.textContent = String(Math.round(v));
      },
    });
    anterior.current = valor;
    return () => controle.stop();
  }, [valor, visivel, reduzir]);

  // O valor real já vem no HTML: se o script falhar, o número aparece mesmo assim.
  return (
    <span ref={ref} className="num">
      {valor}
    </span>
  );
}
