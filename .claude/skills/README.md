# Skills do Claude Code

Skills são instruções que o Claude Code carrega sozinho quando o pedido combina com a descrição delas. Ficam aqui, no repositório, para valer no Windows, no Linux e em qualquer worktree. Elas carregam **no início da sessão**: depois de mudar algo aqui, abra uma sessão nova.

## O que tem aqui

**Própria do projeto (em português):**
- `revisao-do-hub`: roteiro de revisão do hub (visual, sensação, orientação, UI, som, desempenho). Liga as skills abaixo às regras do AGENTS.md e entrega um relatório; não implementa nada.

**De jogos e design** (20, copiadas de [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)):

| Grupo | Skills |
|---|---|
| Godot (miram a 4.7) | `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups`, `godot-resources`, `godot-3d-essentials`, `godot-ui-control`, `godot-audio`, `godot-animation`, `godot-shaders`, `godot-physics`, `godot-gdscript-headless-testing` |
| Design | `game-feel`, `game-ui-ux`, `level-design`, `camera-systems`, `audio-design`, `performance-optimization`, `input-systems`, `shader-programming`, `create-game-assets` |

- **Origem:** commit `0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd`, copiado sem mudanças. Só a estrutura foi achatada: `skills/godot/godot-gdscript/` virou `godot-gdscript/` (o Claude Code só procura `.claude/skills/<nome>/SKILL.md`).
- **Ficaram de fora:** `router` (lista as 74 skills e apontaria para as que não estão aqui), gêneros, Unity, Unreal, web e Roblox.
- **Scripts:** os dois `.py` de `create-game-assets/scripts/` só leem imagens locais (precisam de Pillow). Só rodam se o dono pedir.
- **Licença:** Apache-2.0. O texto está em [LICENSE-apache-2.0.txt](LICENSE-apache-2.0.txt) e o aviso de origem em [NOTICE-awesome-gamedev-agent-skills.txt](NOTICE-awesome-gamedev-agent-skills.txt). Os dois precisam ficar aqui enquanto as skills estiverem.

## Como atualizar
1. Escolha um commit novo no repositório de origem e leia o que mudou.
2. Numa pasta nova e vazia, fora do repositório, baixe e extraia:
   ```bash
   mkdir /tmp/claude-skills-src
   gh api repos/gamedev-skills/awesome-gamedev-agent-skills/tarball/<SHA> > /tmp/claude-skills-src.tar.gz
   tar -xzf /tmp/claude-skills-src.tar.gz -C /tmp/claude-skills-src
   ```
   Não rode nada de dentro dela.
3. Confira que nenhum `SKILL.md` ganhou `allowed-tools`, hooks ou comandos que rodem sozinhos.
4. Para cada skill da tabela, apague a pasta daqui e copie a nova, achatada (`skills/<grupo>/<nome>/` → `.claude/skills/<nome>/`). Copie de novo o `LICENSE` e o `NOTICE`.
5. Troque o commit nesta página, rode a bateria (`bash tests/run_tests.sh`) e faça o commit.
