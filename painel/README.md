# Painel do cofre

O painel visual do `docs/` (o cofre do Obsidian): a fase atual, o rumo, a linha do tempo, o que falta, as ideias, a atividade do git e todos os documentos. Feito em React + Motion e rodando no Docker. **Ele só lê:** o repositório entra no contêiner como somente leitura.

## Abrir
Com o Docker Desktop aberto, na pasta do projeto:

```
docker compose -f painel/compose.yaml up -d --build
```

Depois abra **http://localhost:4170**. O painel volta sozinho quando o Docker abre (`restart: unless-stopped`).

- **Parar:** `docker compose -f painel/compose.yaml down`
- **Depois de mudar o código do painel:** o mesmo `up -d --build`.
- **Teste do leitor do cofre:** `docker compose -f painel/compose.yaml run --rm --no-deps painel npm test`

## O que ele faz
- **Ao vivo:** a cada 2 s o servidor confere os `.md` e o git. Quando algo muda (um `[x]` marcado, uma ideia nova, um commit), aparece um aviso e o que mudou acende.
- **A visão V1–V6:** seis versões do produto com ilustrações e os estados do ROADMAP. As futuras ficam dessaturadas; a abertura mostra as três etapas do produto, a fase em andamento, a próxima subetapa e o ritmo de commits.
- **Leitor:** clique em qualquer fase, tarefa, ideia ou documento. Os links entre notas abrem dentro do painel, e "Abrir no Obsidian" abre a nota no cofre.
- **Busca:** `Ctrl+K` ou `/`.
- **Tema claro/escuro e animações:** os botões na barra superior. O painel também respeita o "reduzir movimento" do sistema, inclusive nos contadores. Em telas menores, o botão “Seções” abre a navegação.
- **Teclado nos diálogos:** Tab e Shift+Tab ficam na busca ou no leitor; Esc fecha e devolve o foco ao controle anterior.

## Como funciona
| Parte | Onde |
|---|---|
| Leitor do cofre (fases, ROADMAP, Início, ideias, tarefas, documentos) | `server/ler-cofre.js` |
| Git (branch, commits e commits por dia; nunca o e-mail) | `server/git.js` |
| Vigia (confere os arquivos a cada 2 s) | `server/vigia.js` |
| Servidor (site, `/api/painel`, `/api/eventos`) | `server/index.js` |
| Interface (React + Motion) | `src/` (uma seção por arquivo em `src/secoes/`) |

O servidor não tem dependências. O `marked`, o React e o Motion só entram na compilação do site, dentro do Docker; a imagem final tem o Node, o git e o site pronto.

Para mexer na interface com recarga instantânea (opcional, precisa do Node 22+ na máquina): `npm install`, depois `npm start` num terminal e `npm run dev` noutro, e abra http://localhost:5173.

## Pacotes
Versões fixadas no `package.json` (e no `package-lock.json`):

| Pacote | Versão | Licença |
|---|---|---|
| react, react-dom | 19.2.9 | MIT |
| motion | 12.43.0 | MIT |
| marked | 16.4.2 | MIT |
| vite (só para compilar) | 7.3.7 | MIT |
| @vitejs/plugin-react (só para compilar) | 5.2.0 | MIT |
| imagem `node:22.23.4-alpine3.24` | — | MIT (Node) |

Entre os pacotes indiretos da compilação, o `caniuse-lite` é CC-BY-4.0. Ele não vai para o site.

As fontes Sora (títulos), Manrope (interface) e Literata (leitura) vêm do Google Fonts; sem internet, o painel usa Segoe UI/system-ui e Georgia no leitor.

## Créditos
- **Identidade visual:** o `game-hub-brand-kit/` (cores e logo). `public/logo.png` é o logo original reduzido a 512 px; `public/simbolo.svg` é o símbolo flat. A tipografia do painel foi escolhida no redesenho.
- **Ilustrações:** sete imagens geradas no ComfyUI local (modelo `flux3-image-klein-int8-convrot`), em `public/visao/`. Cada WebP tem um arquivo `.webp.json` com o prompt e a origem. São ilustrações da visão, não capturas do hub nem capas de jogos.
- **Impeccable** (skill de design só deste painel, em `.claude/skills/impeccable/`): © Paul Bakaus, [Apache-2.0](.claude/skills/impeccable/LICENSE), de https://github.com/pbakaus/impeccable (commit `687bc38`, skill 4.8.0). Também vêm dela os agentes revisores em `.claude/agents/impeccable-*.md` e os hooks em `.claude/settings.json` (o detector de design roda depois de cada edição de UI).

## Usar a Impeccable
- **Abra o Claude Code dentro de `painel/`** (ex.: `cd painel` e depois `claude`). Só assim a skill, os agentes e os hooks carregam; aberta na raiz do projeto, a sessão não enxerga nada disso.
- O que a skill sabe do produto está em `PRODUCT.md` (quem usa, para quê, o que é obrigatório do brand kit). O sistema visual está em [DESIGN.md](DESIGN.md), com componentes e extensões em `.impeccable/design.json`; a composição específica está em `.impeccable/surfaces/src-app-jsx.md`.
- O motor (`impeccable.exe` 0.1.18, ~20 MB, do GitHub do projeto) é baixado sozinho na primeira vez, com o checksum conferido, e fica em `%USERPROFILE%\.impeccable\`, fora do repositório. A telemetria dele está desligada (`impeccable telemetry off`).
- Os arquivos que a skill cria em `.impeccable/` (surfaces, design.json, config) vão para o git; as pastas de trabalho dela (`questions/`, `mocks/`, `review/`) se ignoram sozinhas.

O fechamento do redesenho V1–V6, as verificações no navegador e o teste manual estão em [REVISAO-VISUAL.md](REVISAO-VISUAL.md).
