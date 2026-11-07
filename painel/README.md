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
- **A cidade:** cada fase da linha do tempo do `Início.md` é um prédio, e cada janela acesa é uma subetapa feita. A próxima janela pisca.
- **Leitor:** clique em qualquer fase, tarefa, ideia ou documento. Os links entre notas abrem dentro do painel, e "Abrir no Obsidian" abre a nota no cofre.
- **Busca:** `Ctrl+K` ou `/`.
- **Tema claro/escuro e animações:** os botões no pé da barra lateral. O painel também respeita o "reduzir movimento" do sistema.

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

As fontes (Space Grotesk e Inter) vêm do Google Fonts; sem internet, o painel usa a Segoe UI.

## Créditos
- **Identidade visual:** o `game-hub-brand-kit/` (cores, logo e fontes). `public/logo.png` é o logo original reduzido a 512 px; `public/simbolo.svg` é o símbolo flat.
- **Impeccable** (skill de design só deste painel, em `.claude/skills/impeccable/`): © Paul Bakaus, [Apache-2.0](.claude/skills/impeccable/LICENSE), de https://github.com/pbakaus/impeccable (commit `687bc38`, skill 4.8.0). Instalada à mão: sem o hook e sem o lançador do programa.
