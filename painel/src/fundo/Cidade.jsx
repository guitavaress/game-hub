// O horizonte do projeto: cada fase da linha do tempo é um prédio,
// e cada janela acesa é uma subetapa feita. A fase em andamento tem a
// próxima janela piscando e um farol no topo; as próximas fases são só contorno.
// Na abertura, os prédios sobem do chão e as janelas acendem em onda.

import { useMemo, useState } from 'react';
import { motion, useMotionValue, useSpring, useTransform } from 'motion/react';

const JL = 7; // largura da janela
const JA = 9; // altura da janela
const GX = 5; // vão entre colunas
const GY = 6; // vão entre andares
const PAD = 8;
const TOPO = 14;
const VAO = 12; // entre prédios
const CHAO = 40; // faixa do chão embaixo
const CEU = 58; // céu acima do mais alto

// Número "aleatório" fixo por índice (o desenho não muda a cada abertura).
const rnd = (i) => {
  const x = Math.sin(i * 9301 + 49297) * 233280;
  return x - Math.floor(x);
};

function montarPredios(gantt, fases) {
  const porNumero = new Map(fases.map((f) => [f.numero, f]));
  return gantt.map((g, i) => {
    const plano = g.fase ? porNumero.get(g.fase) : null;
    let total = plano?.total || 0;
    let feitas = plano?.feitas || 0;
    if (!plano) {
      // Sem plano (as fases 1–6, o Visual v2, as futuras): um número de janelas que dá forma ao prédio.
      total = /1 a 6/.test(g.nome) ? 6 : g.estado === 'futura' ? 9 : 5;
      feitas = g.estado === 'feita' ? total : 0;
    }
    if (g.estado === 'feita') feitas = total;
    const cols = total > 20 ? 4 : 3;
    const andares = Math.max(3, Math.ceil(total / cols));
    const w = PAD * 2 + cols * JL + (cols - 1) * GX;
    const h = TOPO + andares * (JA + GY) - GY + PAD;
    return { ...g, chave: g.id || g.nome, i, plano, total, feitas, cols, andares, w, h, telhado: i % 3 };
  });
}

export default function Cidade({ gantt, fases, abrir, aoFocar }) {
  const predios = useMemo(() => montarPredios(gantt, fases), [gantt, fases]);
  const [foco, setFoco] = useState(null);

  const largura = predios.reduce((s, p) => s + p.w + VAO, 0) - VAO + 48;
  const maisAlto = Math.max(...predios.map((p) => p.h), 120);
  const altura = maisAlto + CEU + CHAO;
  const chao = altura - CHAO;

  // posição x de cada prédio
  let x = 24;
  const pos = predios.map((p) => {
    const px = x;
    x += p.w + VAO;
    return px;
  });

  // parallax: a fileira do fundo acompanha o mouse devagar
  const mx = useMotionValue(0);
  const suave = useSpring(mx, { stiffness: 60, damping: 20 });
  const fundoX = useTransform(suave, [-1, 1], [14, -14]);
  const estrelasX = useTransform(suave, [-1, 1], [6, -6]);

  const estrelas = useMemo(
    () =>
      Array.from({ length: 46 }, (_, i) => ({
        x: rnd(i) * largura,
        y: 8 + rnd(i + 100) * (CEU + maisAlto * 0.45),
        r: rnd(i + 200) > 0.85 ? 1.3 : 0.75,
        d: rnd(i + 300) * 6,
      })),
    [largura, maisAlto],
  );

  // a fileira distante: silhuetas baixas, sem janelas
  const distantes = useMemo(() => {
    const lista = [];
    let dx = -20;
    let k = 0;
    while (dx < largura + 40) {
      const w = 26 + rnd(k + 500) * 38;
      const h = 30 + rnd(k + 600) * (maisAlto * 0.55);
      lista.push({ x: dx, w, h });
      dx += w + 4;
      k += 1;
    }
    return lista;
  }, [largura, maisAlto]);

  const focar = (p) => {
    setFoco(p?.chave ?? null);
    aoFocar(p);
  };

  return (
    <svg
      className="cidade"
      viewBox={`0 0 ${largura} ${altura}`}
      preserveAspectRatio="xMidYMax meet"
      role="group"
      aria-label="A cidade do projeto: um prédio por fase; cada janela acesa é uma subetapa feita"
      onPointerMove={(e) => {
        const r = e.currentTarget.getBoundingClientRect();
        mx.set(((e.clientX - r.left) / r.width) * 2 - 1);
      }}
      onPointerLeave={() => {
        mx.set(0);
        focar(null);
      }}
    >
      <defs>
        <linearGradient id="reflexo" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#24baf5" stopOpacity="0.28" />
          <stop offset="1" stopColor="#24baf5" stopOpacity="0" />
        </linearGradient>
        <linearGradient id="corpo-feito" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#132d49" />
          <stop offset="1" stopColor="#0c1d31" />
        </linearGradient>
        <linearGradient id="corpo-ativo" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#17406a" />
          <stop offset="1" stopColor="#0e2440" />
        </linearGradient>
        <radialGradient id="halo">
          <stop offset="0" stopColor="#67e8f9" stopOpacity="0.9" />
          <stop offset="1" stopColor="#67e8f9" stopOpacity="0" />
        </radialGradient>
      </defs>

      <motion.g style={{ x: estrelasX }}>
        {estrelas.map((s, i) => (
          <circle key={i} className="estrela" cx={s.x} cy={s.y} r={s.r} fill="#cfefff" opacity="0.55" style={{ animationDelay: `${s.d}s` }} />
        ))}
      </motion.g>

      <motion.g style={{ x: fundoX }} opacity="0.55">
        {distantes.map((d, i) => (
          <motion.rect
            key={i}
            x={d.x}
            y={chao - d.h}
            width={d.w}
            height={d.h}
            fill="#0b1b2d"
            style={{ originY: 1 }}
            initial={{ scaleY: 0 }}
            animate={{ scaleY: 1 }}
            transition={{ duration: 1.1, delay: 0.05 + rnd(i) * 0.25, ease: [0.16, 1, 0.3, 1] }}
          />
        ))}
      </motion.g>

      {/* chão e o reflexo das luzes */}
      <rect x="0" y={chao} width={largura} height={CHAO} fill="url(#reflexo)" />
      <motion.line
        x1="0"
        x2={largura}
        y1={chao}
        y2={chao}
        stroke="#24baf5"
        strokeOpacity="0.55"
        strokeWidth="1"
        initial={{ pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 1.2, ease: [0.16, 1, 0.3, 1] }}
      />

      {predios.map((p, n) => {
        const px = pos[n];
        const topo = chao - p.h;
        const ativo = p.estado === 'andamento';
        const futuro = p.estado === 'futura';
        const atraso = 0.12 + n * 0.045;
        const rotulo = `${p.nome}: ${futuro ? 'fase futura' : `${p.feitas} de ${p.total} subetapas`}${ativo ? ', em andamento' : ''}`;
        const janelas = [];
        for (let k = 0; k < p.total; k++) {
          const col = k % p.cols;
          const andarDeBaixo = Math.floor(k / p.cols);
          const jx = px + PAD + col * (JL + GX);
          const jy = chao - PAD - (andarDeBaixo + 1) * (JA + GY) + GY;
          const acesa = k < p.feitas;
          const proxima = ativo && k === p.feitas;
          janelas.push(
            <motion.rect
              key={k}
              x={jx}
              y={jy}
              width={JL}
              height={JA}
              rx="1.2"
              fill={futuro ? 'none' : acesa ? '#67e8f9' : proxima ? '#67e8f9' : '#1a3350'}
              stroke={futuro ? '#3a5a7b' : 'none'}
              strokeDasharray={futuro ? '2 2' : undefined}
              className={proxima ? 'proxima-janela' : acesa && rnd(n * 50 + k) > 0.86 ? 'tremula' : undefined}
              style={acesa ? { animationDelay: `${rnd(k + n) * 5}s` } : undefined}
              initial={{ opacity: 0 }}
              animate={{ opacity: futuro ? 0.8 : acesa ? 0.55 + rnd(n * 31 + k) * 0.45 : 1 }}
              transition={{ duration: 0.5, delay: atraso + 0.55 + andarDeBaixo * 0.06 + col * 0.02 }}
            />,
          );
        }
        return (
          <g
            key={p.chave}
            className="predio"
            tabIndex={0}
            role="button"
            aria-label={rotulo}
            onPointerEnter={() => focar(p)}
            onFocus={() => focar(p)}
            onBlur={() => focar(null)}
            onClick={() => (p.plano ? abrir(p.plano.arquivo) : abrir('ROADMAP.md', 'Próximas fases'))}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                p.plano ? abrir(p.plano.arquivo) : abrir('ROADMAP.md', 'Próximas fases');
              }
            }}
          >
            <motion.g
              style={{ originY: 1 }}
              initial={{ scaleY: 0, opacity: futuro ? 0 : 1 }}
              animate={{ scaleY: 1, opacity: 1 }}
              transition={{ duration: 0.9, delay: atraso, ease: [0.16, 1, 0.3, 1] }}
            >
              {/* telhado: plano, antena ou degrau (varia por prédio) */}
              {p.telhado === 2 && !futuro && (
                <rect x={px + p.w * 0.22} y={topo - 9} width={p.w * 0.56} height="10" fill={ativo ? 'url(#corpo-ativo)' : 'url(#corpo-feito)'} stroke="#24405e" />
              )}
              {(p.telhado === 1 || ativo) && !futuro && <line x1={px + p.w / 2} x2={px + p.w / 2} y1={topo} y2={topo - (ativo ? 26 : 14)} stroke="#3b6a93" strokeWidth="1.5" />}
              <rect
                className="casca-predio"
                x={px}
                y={topo}
                width={p.w}
                height={p.h}
                rx="2"
                fill={futuro ? 'rgba(13,28,46,0.35)' : ativo ? 'url(#corpo-ativo)' : 'url(#corpo-feito)'}
                stroke={futuro ? '#3a5a7b' : ativo ? '#2f6ea3' : '#24405e'}
                strokeDasharray={futuro ? '4 3' : undefined}
                strokeWidth="1"
                style={{ transition: 'stroke 150ms, filter 220ms' }}
              />
              {foco === p.chave && <rect x={px - 3} y={topo - 3} width={p.w + 6} height={p.h + 6} rx="4" fill="none" stroke="#67e8f9" strokeOpacity="0.35" />}
            </motion.g>
            {janelas}
            {ativo && (
              <g>
                <circle className="farol" cx={px + p.w / 2} cy={topo - 27} r="9" fill="url(#halo)" />
                <circle className="farol" cx={px + p.w / 2} cy={topo - 27} r="2.4" fill="#67e8f9" />
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
}
