# Game Hub — orientações para o Codex

Launcher da biblioteca Steam em um mundo 3D em primeira pessoa, feito em Godot. A biblioteca gera uma cidade com bairros por categoria; a casa reúne biblioteca, amigos, configurações e avatar. O norte é um desktop virtual inspirado no PlayStation Home.

## Leitura no início de cada tarefa

1. Leia [CLAUDE.md](CLAUDE.md): contexto e regras compartilhados do projeto. Este arquivo complementa essa base para o Codex.
2. Consulte [docs/GUIA_TECNICO.md](docs/GUIA_TECNICO.md) para localizar os sistemas e os testes da tarefa. Abra somente as partes relevantes do código.
3. Confira a branch, o estado do Git e o plano relacionado em [docs/plans/](docs/plans/README.md). Retome pelo progresso registrado no plano, sem presumir uma branch ou fase ativa.
4. Use [README.md](README.md) para comportamento e uso, [docs/ROADMAP.md](docs/ROADMAP.md) para direção e ordem das fases, [docs/PLATAFORMA.md](docs/PLATAFORMA.md) para Steam/SO e [tests/README.md](tests/README.md) antes de alterar testes.

Os planos são a memória entre sessões. Não crie um roadmap ou registro de progresso paralelo. Se documentação e código divergirem, confira a implementação e o histórico, relate a diferença e corrija a documentação pertinente dentro do escopo autorizado.

## Comunicação e código

- O dono tem conhecimento básico de programação. Explique decisões em português simples e escreva comentários de código em português.
- Use GDScript com tipagem estática e siga o estilo dos arquivos próximos. A versão de referência do projeto e da CI é Godot 4.7.2 padrão, sem .NET; renderer Forward+ e física Jolt.
- Prefira nós criados por código; mantenha cenas `.tscn` simples.
- Entregue um resumo curto, o resultado real das verificações e um checklist manual: o que abrir, o que apertar e o que deve acontecer. Para alterações só em documentação, o checklist pode ser de leitura e navegação.
- Quando houver uma etapa no editor, explique o passo a passo. Para testes com janela, desative o jogo embutido no editor conforme o README.

## Limites de arquitetura

- Sistemas em `autoload/` não referenciam `worlds/`. A comunicação com o cenário usa sinais e grupos.
- Mundos montam cenário e posicionam componentes; não recebem lógica de integração Steam.
- `GamePortal` é genérico e não depende de prédios. A aparência fica nas cascas de portal e nos mundos.
- Dados de bairros, casa e avatar ficam em `profiles/`. Consulte os catálogos existentes antes de introduzir ids ou decisões de tema no código.
- Registro do Windows, `tasklist`, `/proc` e `hyprctl` ficam em `autoload/platform/`. Use `SteamClient` e `WindowHost` em vez de duplicar backends.
- A UI usa `HubTheme`, suas variações e `HubTheme.tint` para cores vindas de dados. As dicas de teclado/controle usam `InputDevice` e `KeyHint`.

## Fluxo de trabalho e Git

- Preserve mudanças locais de outras tarefas; confira o diff antes de editar e antes de entregar.
- Uma fase nova exige plano em `docs/plans/fase-N.md`, seguindo o modelo existente, e aprovação antes de implementar. Nada do “Horizonte” do roadmap vira código sem uma fase.
- Use uma branch por fase e subetapas pequenas. Cada subetapa concluída e testada termina em commit; marque seu progresso e hash no plano.
- Se aparecer uma decisão de arquitetura fora do plano ou o mesmo erro ocorrer duas vezes seguidas, revise o plano antes de continuar a implementação.
- No fim de uma fase, atualize README e ROADMAP. Push e merge na `main` somente quando o dono pedir.
- Commits locais usam o e-mail `32810557+guitavaress@users.noreply.github.com` tanto para autoria quanto para committer; não altere o Git global nem use e-mail pessoal.
- Não use os botões Commit/Merge do Nimbalyst: siga o fluxo de teste e commit descrito em CLAUDE.md. Consulte o plano antes de criar ou integrar worktrees.
- As escolhas Opus/Sonnet, `/model` e `/effort` no CLAUDE.md são específicas do Claude; não são comandos ou requisitos de modelo do Codex.

## Verificação

Na raiz do projeto, em Bash (Git Bash no Windows):

```bash
bash tests/run_tests.sh check_platform check_steam_linux check_window_host check_steam_windows
bash tests/run_tests.sh check_theme check_menu_keyboard  # exemplo de seleção por tarefa
bash tests/run_tests.sh                                # bateria inteira antes de commit
```

O runner importa o projeto e encontra a Godot em `C:\Godot`, no `PATH` ou em `~/.local/bin/godot`. Para outro local, use `GODOT=/caminho/da/godot bash tests/run_tests.sh`.

- Antes de cada commit, a bateria inteira deve terminar com `RESULTADO GERAL: TUDO OK`. Relate falhas e limitações; não declare uma plataforma validada com base em testes de outra.
- Durante a implementação, rode os testes relacionados. Recurso novo ganha `tests/check_<nome>.gd` conforme o contrato em tests/README.md.
- Alguns testes exigem Balatro, Skyrim, Valheim e Stardew Valley instalados. Distingua ausência de pré-requisito de regressão e prefira dados falsos em testes novos.
- Rode uma bateria por vez: `user://` é compartilhado entre worktrees. O runner usa `flock` quando disponível; comandos `godot -s` avulsos não participam dessa trava.
- Testes que alteram configurações ou cache devem guardar e restaurar os dados do usuário. Use Steam falsa nos testes do launcher e os helpers existentes para biblioteca/amigos.
- Mudanças visuais exigem conferência com janela e captura em pasta temporária fora do repositório. Testes headless não comprovam aparência nem FPS.

## Privacidade, assets e referências

- A chave Steam Web API fica somente em `user://config.cfg`. Nunca peça a chave no chat, imprima seu conteúdo ou inclua o segredo em logs, avisos, testes ou commits.
- Não escreva nas pastas da Steam. Os dados locais da biblioteca são lidos pelo hub.
- Capturas com capas de jogos ficam fora do repositório público; use a pasta temporária da sessão.
- Para novos assets de jogo, siga a regra CC0 do CLAUDE.md, com licença na origem e crédito no README. Preserve as licenças específicas já existentes, como a OFL das fontes.
- Antes de baixar assets, peça autorização com nome, origem e tamanho. Fontes pesadas ficam fora do repositório; inclua somente o que o jogo usa.
- Consulte o [índice das skills do Claude](.claude/skills/README.md) quando a tarefa pedir uma referência de Godot/design. Leia o `SKILL.md` pertinente explicitamente: não presuma que o Codex carregue `.claude/skills/` automaticamente. Preserve licenças e avisos; os scripts auxiliares de assets só rodam quando o dono pedir.
- Mantenha este arquivo curto. Detalhes técnicos ficam no guia e decisões/progresso nos documentos existentes.
