---
name: revisao-do-hub
description: >
  Roteiro de revisão do Game Hub (Godot 4.7, cidade 3D em primeira pessoa). Liga as
  skills genéricas de jogos e design às regras deste projeto e gera um relatório, sem
  implementar nada. Use quando o pedido for revisar, avaliar, criticar ou melhorar o
  visual, a sensação (game feel), a orientação na cidade, os bairros, a casa, a UI
  (HUD, busca, mapa, menus), o som ou o desempenho do hub, ou quando o dono disser
  que algo está "sem graça", "fraco" ou "abaixo".
---

# Revisão do Game Hub

Esta skill **não implementa nada**. Ela olha o hub com as lentes certas e entrega um relatório. O que o dono aprovar vira subetapa ou fase no ROADMAP antes de qualquer código.

## 1. Contexto primeiro
Leia, nesta ordem:
1. `CLAUDE.md`: visão, mapa do projeto e as **6 regras de arquitetura**.
2. `docs/ROADMAP.md`: o que já está feito e o que já está planejado (não sugira o que já está na fila; aponte para a fase).
3. O plano da fase atual em `docs/plans/` (o de número mais alto, ou o que o dono indicar).

Depois abra só os arquivos que a lente escolhida precisa (use o mapa do CLAUDE.md).

## 2. Escolha as lentes
Pegue só as que o pedido toca. Para cada lente, carregue a skill ligada a ela e use os critérios dela.

| Lente | Skill | Onde olhar no hub |
|---|---|---|
| Porta, carga da porta e fade | `game-feel` | `components/game_portal/`, `ui/door_charge.gd`, `ui/screen_fade.gd`, `ui/game_screen.gd` |
| Bairros, marcos, caminhos e metrô | `level-design` | `worlds/city/`, `worlds/city/district_props/`, `profiles/districts/*.tres` |
| HUD, busca, mapa e menus | `game-ui-ux` | `ui/`, `player/` |
| Luz, céu, dia e noite | `godot-3d-essentials` | `worlds/city/` (dia e noite), `worlds/home/`, `profiles/` (clima) |
| Qualidade Leve e FPS | `performance-optimization` | `autoload/graphics_quality.gd`, `tools/medir_desempenho.gd` |
| Coerência dos assets CC0 | `create-game-assets` | `assets/` (só CC0, com LICENSE) |
| Som e mixagem | `audio-design` | `components/ambient_emitter/`, `profiles/` (som do bairro) |
| Olhar e movimento em 1ª pessoa | `camera-systems` | `player/` |

Para detalhes de Godot (código, sinais, `.tres`, UI, shaders), use as skills `godot-*`.

## 3. Evidência
- **Capturas com janela** (sem `--headless`), salvas na **pasta temporária da sessão**. Nunca no repositório.
- **Nunca** mostre ou salve captura com capas de jogos fora da pasta temporária (o repositório é público). Para a cidade, prefira a biblioteca falsa (`tests/fake_library.gd`).
- **Desempenho:** meça com `tools/medir_desempenho.gd`. A régua é o desktop (Ryzen 5 5600 + RTX 4070); o notebook só serve para comparar antes e depois.
- Se não der para capturar ou medir, diga isso no relatório. Não invente número.

## 4. Relatório (em português simples)
1. **O que está bom** (curto, para não mexer no que funciona).
2. **Problemas**, cada um com:
   - o que se vê ou se sente, e a evidência (captura, medida ou trecho de código);
   - **impacto** (alto, médio, baixo) × **esforço** (pequeno, médio, grande);
   - **onde mexer**: perfil de bairro `.tres` (dado) ou código (qual arquivo);
   - qual **regra de arquitetura** a sugestão respeita. Se quebrar alguma, descarte ou proponha outro caminho.
3. **Ordem sugerida**: primeiro alto impacto com esforço pequeno.
4. **Próximo passo**: quais itens viram subetapa da fase atual e quais viram fase nova no ROADMAP. Quem decide é o dono.

## Regras que não mudam
- Diferença entre bairros é **dado no perfil** (regra 4), não `match` no código.
- Nada em `autoload/` passa a conhecer `worlds/` (regra 1). O `GamePortal` continua genérico (regra 3).
- Asset novo só CC0, e **antes de baixar, peça permissão** com nome, origem e tamanho.
- Os scripts Python de `create-game-assets` só rodam se o dono pedir (precisam de Pillow).
