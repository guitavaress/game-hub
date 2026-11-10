// Busca os dados do cofre e escuta o canal "ao vivo".
// Quando o servidor avisa que um .md mudou, busca de novo e conta o que mudou.

import { useEffect, useRef, useState, useCallback } from 'react';

export function useCofre() {
  const [dados, setDados] = useState(null);
  const [erro, setErro] = useState(null);
  const [conexao, setConexao] = useState('conectando'); // conectando | ao-vivo | offline
  const [mudanca, setMudanca] = useState(null); // { versao, mudou: [...] }
  const versaoRef = useRef(0);

  const buscar = useCallback(async () => {
    try {
      const r = await fetch('/api/painel', { cache: 'no-store' });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const d = await r.json();
      setDados(d);
      setErro(null);
      return d;
    } catch (e) {
      setErro(e.message);
      return null;
    }
  }, []);

  useEffect(() => {
    buscar().then((d) => {
      if (d) versaoRef.current = d.versao;
    });
    const fonte = new EventSource('/api/eventos');
    fonte.addEventListener('ola', async (e) => {
      setConexao('ao-vivo');
      // Reconectou depois de uma queda: se a versão mudou, atualiza.
      const { versao } = JSON.parse(e.data);
      if (versaoRef.current && versao !== versaoRef.current) {
        const d = await buscar();
        if (d) versaoRef.current = d.versao;
      }
    });
    fonte.addEventListener('mudou', async (e) => {
      const ev = JSON.parse(e.data);
      const d = await buscar();
      if (d) {
        versaoRef.current = d.versao;
        setMudanca({ versao: ev.versao, mudou: ev.mudou, quando: Date.now() });
      }
    });
    fonte.onerror = () => setConexao('offline');
    fonte.onopen = () => setConexao('ao-vivo');
    return () => fonte.close();
  }, [buscar]);

  return { dados, erro, conexao, mudanca };
}
