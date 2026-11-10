// Ícones desenhados para o painel: traço de 1,75 px e cantos arredondados (brand kit).

const CAMINHOS = {
  agora: <path d="M4 20V10.5L12 4l8 6.5V20M9.5 20v-6.5l5-2.5v9" />,
  fase: (
    <>
      <circle cx="6" cy="6" r="2" />
      <circle cx="6" cy="18" r="2" />
      <path d="M6 8v8M10 6h10M10 18h10M10 12h6" />
    </>
  ),
  rumo: (
    <>
      <circle cx="5" cy="12" r="2.2" />
      <circle cx="19" cy="12" r="2.2" />
      <path d="M7.2 12h9.6M12 9v6" />
    </>
  ),
  tempo: (
    <>
      <path d="M4 7h9M4 12h14M4 17h6" />
      <path d="M17 4v6M20 14v6" />
    </>
  ),
  falta: (
    <>
      <rect x="4" y="4" width="6" height="6" rx="1.5" />
      <rect x="4" y="14" width="6" height="6" rx="1.5" />
      <path d="M13.5 7h6.5M13.5 17h6.5" />
    </>
  ),
  ideia: <path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.6 10.8c.6.5 1 1.2 1 2V16h5.2v-.2c0-.8.4-1.5 1-2A6 6 0 0 0 12 3Z" />,
  atividade: <path d="M3 12h4l2.5-6 5 12L17 12h4" />,
  docs: (
    <>
      <path d="M7 3h7l5 5v13H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
      <path d="M14 3v5h5M9 13h6M9 17h6" />
    </>
  ),
  busca: (
    <>
      <circle cx="11" cy="11" r="6.5" />
      <path d="m20 20-4.2-4.2" />
    </>
  ),
  sol: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4" />
    </>
  ),
  lua: <path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10Z" />,
  movimento: <path d="M4 8c3 0 3 8 6 8s3-8 6-8 3 8 4 8M4 16h2" />,
  parado: (
    <>
      <path d="M4 12h16" />
      <circle cx="12" cy="12" r="2.5" />
    </>
  ),
  fechar: <path d="M6 6l12 12M18 6 6 18" />,
  fora: (
    <>
      <path d="M14 4h6v6M20 4l-9 9" />
      <path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" />
    </>
  ),
  seta: <path d="m9 6 6 6-6 6" />,
  menu: <path d="M4 7h16M4 12h16M4 17h16" />,
  ok: <path d="m5 12.5 4.5 4.5L19 7.5" />,
  meia: (
    <>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 4a8 8 0 0 1 0 16Z" fill="currentColor" />
    </>
  ),
  proxima: <path d="M5 12h14M13 6l6 6-6 6" />,
  pausa: <path d="M9 6v12M15 6v12" />,
  horizonte: <path d="M3 16h18M6 16a6 6 0 0 1 12 0M12 5v2M5 8.5l1.4 1.4M19 8.5l-1.4 1.4" />,
  vivo: <path d="M12 3v3M12 18v3M3 12h3M18 12h3M12 9a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z" />,
  commit: (
    <>
      <circle cx="12" cy="12" r="3.5" />
      <path d="M3 12h5.5M15.5 12H21" />
    </>
  ),
};

export default function Icone({ nome, tamanho = 18, ...resto }) {
  return (
    <svg
      width={tamanho}
      height={tamanho}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...resto}
    >
      {CAMINHOS[nome]}
    </svg>
  );
}
