// Contém o teclado no diálogo da frente e devolve o foco ao fechar.
import { useEffect } from 'react';

const FOCAVEIS = 'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])';
const daFrente = () => [...document.querySelectorAll('[role="dialog"]')].at(-1);

export default function useDialogo(dialogo, inicial, fechar) {
  useEffect(() => {
    const antes = document.activeElement;
    const el = dialogo.current;
    inicial.current?.focus({ preventScroll: true });
    const tecla = (e) => {
      if (daFrente() !== el) return;
      if (e.key === 'Escape') {
        e.preventDefault();
        e.stopImmediatePropagation();
        fechar();
      } else if (e.key === 'Tab') {
        const itens = [...el.querySelectorAll(FOCAVEIS)].filter((n) => n.getClientRects().length);
        const primeiro = itens[0];
        const ultimo = itens.at(-1);
        if (!primeiro) return;
        if (!el.contains(document.activeElement) || (e.shiftKey ? document.activeElement === primeiro : document.activeElement === ultimo)) {
          e.preventDefault();
          (e.shiftKey ? ultimo : primeiro).focus();
        }
      }
    };
    window.addEventListener('keydown', tecla, true);
    return () => {
      window.removeEventListener('keydown', tecla, true);
      // Aguarda a desmontagem: busca pode estar dando lugar ao leitor.
      requestAnimationFrame(() => {
        const frente = daFrente();
        if (antes?.isConnected && (!frente || frente.contains(antes))) antes.focus({ preventScroll: true });
      });
    };
  }, [dialogo, inicial, fechar]);
}
