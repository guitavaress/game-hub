# Estudo: Fase 6 — Amigos andando pela cidade

> **Revisão da coordenadora (2026-11-15).** Este estudo foi escrito por um modelo grátis (OpenCode, `omniroute/free-reasoning`) e serve de ponto de partida, não de plano. Conferi por amostra o que ele cita do código (as animações `Idle` e `Walk` do `AvatarBody`, o `route_points` e o `street_line` do `CityRouteGuide`, a praça em `city.gd`): bate. O que **não** vale como dado:
> - **A tabela de custo da seção 6.1 é chute:** nada foi medido (a trilha não abriu a Godot), nem o "custo atual". A medida é do plano, no desktop.
> - **O "144 FPS (p99 13 ms)"** citado como base não foi conferido contra a ROADMAP.
> - **O IK dos pés** (`Skeleton3DIK`) é um nome que não conferi na Godot 4.7; a calçada é plana, então a primeira versão não precisa dele.
> - **O corte das trilhas tem uma contradição:** a 6.4 põe o `ui/map_view.gd` na trilha B, e a tabela de arquivos o põe na A. O plano decide.
> - **O número da fase:** não é "fase-6"; a fase ganha o próximo número livre (a partir de 20) quando começar.

> **Arquivo:** `docs/design/estudo-amigos-andando-2026-11-15.md`  
> **Data:** 2026-11-15  
> **Escopo:** apenas leitura — nenhum código muda.  
> **Base:** commit `33df095` (branch `fase-19`)

---

## 1. O que a cidade já sabe sobre onde se pode andar

### 1.1 Grade, ruas, calçadas e quarteirões  (`worlds/city/city_layout.gd`)

- **Quarteirão:** 28 × 28 m (`BLOCK_SIZE = LOT_SIZE * 2 = 28`).  
- **Rua:** 10 m de largura (`STREET_WIDTH = 10.0`).  
- **Calçada:** 1,5 m em volta do quarteirão (`SIDEWALK_WIDTH = 1.5` em `city_decor.gd`).  
- **Pitch do quarteirão (centro a centro):** 38 m (`BLOCK_PITCH = BLOCK_SIZE + STREET_WIDTH`).  
- **Praça:** quarteirão central `(0, 0)` — piso de pedra, chafariz, floreiras nos cantos.  
- **Lotes:** 4 por quarteirão (2 × 2), cada um 14 × 14 m. A porta do prédio fica virada para a rua.

### 1.2 Prédios, portas e marcos

- **Prédios (`city_building.gd`):** ocupam o lote; a porta está no meio da face virada para a rua.  
- **Pórticos de bairro (`_build_gate` em `city.gd`):** arco na rua de entrada do bairro.  
- **Estações de metrô (`TransitStop`):** boca na calçada, com área livre ao redor (`keep_out_areas` no `BiomeScatter`).  
- **Torres/marcos (`_build_anchored_landmarks`):** torre do relógio na praça, outros nos bairros.  
- **Casa (`_build_home`):** porta na praça (lado sul), com área de chegada reservada (`_plaza_reserved` em `city.gd:126`).

### 1.3 Árvores, rochas e áreas "keep_out"  (`worlds/city/biome/biome_scatter.gd`)

- **Regiões plantáveis:** miolo de neve de cada quarteirão e vaga (`regions` = retângulos encolhidos pela `walkable_clearance`).  
- **Pontos `keep_out` (Array[Vector3] = x, z, raio):** portas dos prédios (raio livre), cada uma com seu raio.  
- **Áreas `keep_out_areas` (Array[Rect2]):** boca de cada estação do metrô.  
- **Copa das árvores (19.7):** raio da copa + `CROWN_GAP (0,5 m)` também não pode encostar em prédio, metrô, marco ou porta.  
- **Colisão:** cada árvore/rocha ganha um `StaticBody3D` com `CylinderShape3D` (tronco ou vértice mais longe da rocha).

> **Conferido no código:** `city_layout.gd` (grade), `city_decor.gd` (calçada `SIDEWALK_WIDTH`, praça), `city.gd` (`_build_block`, `_build_gate`, `_plaza_reserved`), `biome_scatter.gd` (`setup`, `plan`, `_blocked`, `keep_out`, `keep_out_areas`, `CROWN_GAP`).

### 1.4 O que **não** existe hoje

- **NavigationRegion3D / NavigationAgent3D:** não há nenhum no projeto (`grep` não achou).  
- **NavMesh** ou grafo de navegação pronto.  
- **Sistema de waypoints** ou pontos de passagem nas calçadas.  
- **Áreas de "não andar"** explícitas além dos `keep_out` do bioma (portas, metrô, copa das árvores).

---

## 2. Dois caminhos para "por onde andar"

| Critério | **NavigationRegion3D + NavigationAgent3D (Godot)** | **Rede simples de pontos na calçada (da planta)** |
|---|---|---|
| **O que precisa construir** | Um `NavigationRegion3D` cobrindo ruas + calçadas + praça; `NavigationAgent3D` em cada amigo. | Extrair da `CityMap` / `SectorLayout` os centros das calçadas (linhas paralelas às ruas, a 1,5 m do meio-fio) e interligações nas esquinas; um A* leve sobre esse grafo. |
| **Custo de memória** | NavMesh 3D da cidade inteira (até ~200 quarteirões = ~7 600 células de grade) → alguns MB. | Grafo 2D: ~8 nós por quarteirão (4 esquinas × 2 lados de calçada) → poucos KB. |
| **Custo de CPU (por frame)** | `NavigationAgent3D.get_next_path_position()` a cada frame para cada amigo. | A* só quando o amigo **troca de alvo** (cada 10–30 s); no frame só `move_toward` no segmento atual. |
| **Evita prédio/porta/metrô/árvore** | Sim, se o NavMesh for gerado **depois** de colocar tudo (bake em `_ready` ou `call_deferred`). | Sim, se o grafo só incluir arestas nas calçadas livres (já sabemos onde são ruas, calçadas, praça). |
| **Lida com bioma (neve/floresta/deserto)** | Precisa rebake do NavMesh quando o bioma cobre ruas (`cover_streets` em `BiomeSpec`). | O grafo já nasce da planta; ruas cobertas = arestas removidas (a cidade passa `skip` para `BiomeScatter` e `add_street_markings`). |
| **Integração com `CityRouteGuide`** | O `CityRouteGuide` já calcula rota **pelas ruas** (`route_points` em `city_route_guide.gd:110`). Poderia reaproveitar a mesma lógica. | O `CityRouteGuide` **é** a rede de pontos das ruas (linhas `street_line`). A calçada é paralela a ela, offset ±(STREET_WIDTH/2 + SIDEWALK_WIDTH). |
| **Determinismo** | NavMesh da Godot pode dar micro-diferenças entre plataformas/versões. | Totalmente determinístico: a grade é fixa, a conta é pura (`SectorLayout`, `CityLayout`). |
| **Esforço de implementação** | Alto: bake, atualização quando bioma muda, sincronismo com `CityRouteGuide`. | Baixo: a planta já existe; basta gerar o grafo 2D uma vez no `_ready` da cidade. |

### **Conclusão: a rede simples de pontos na calçada é mais barata**

- **Por quê:** a cidade **já tem** a grade, as ruas, as calçadas, a praça e os `keep_out` como dados puros (`CityLayout`, `SectorLayout`, `CityMap`, `biome_scatter.gd`). Não há NavMesh hoje; criá-lo e mantê-lo sincronizado com biomas que cobrem ruas (`cover_streets`) custa mais CPU e memória do que um grafo 2D leve derivado da mesma planta.  
- **Como ficaria:** um `WalkableGraph` (Resource ou autoload) com nós = centros de calçada (pontos a cada ~2 m nas retas, esquinas, travessias) e arestas = segmentos de calçada livre. O amigo anda por `move_toward` no segmento atual; quando chega no nó, pega a próxima aresta do A* até o alvo.  
- **O `CityRouteGuide` já faz isso para o jogador** (`route_points` usa `street_line`); o mesmo código serve de base para o grafo dos amigos.

> **Suposição:** que o grafo 2D consiga representar travessias de rua (faixa de pedestres) e a praça sem casos especiais demais. A praça hoje é um bloco só; as calçadas são retas. Parece viável.

---

## 3. O corpo andando — `AvatarBody` e `FriendNpc` hoje

### 3.1 O que existe (`components/avatar/avatar_body.gd`, `components/friend_npc/friend_npc.gd`)

| Item | Estado atual |
|---|---|
| **Modelo** | `animated_human.glb` (Quaternius, CC0) — tem esqueleto e animações. |
| **Animações** | `Idle` (respiração) e `Walk` (caminhada) — `IDLE_ANIMATION` e `WALK_ANIMATION` em `avatar_body.gd:20-21`. |
| **Métodos de animação** | `play_idle(start)`, `play_walk(start)` — tocam em loop linear (`_play_loop` em `avatar_body.gd:120`). |
| **Esqueleto** | `Skeleton3D` com ossos incluindo `"Head"` (usado para posicionar o avatar da Steam no rosto) e `"HeadTop_End"`, `"LeftToe_End"` (usados no `_fit` para escalar/rotacionar o modelo). |
| **Holograma** | `FriendNpc` usa `AvatarBody` com `ShaderMaterial` de holograma por cima (`override_material` ou `overlay_material`). |
| **Movimento** | **Nenhum.** `_process` do `FriendNpc` só faz flutuar 1,5 cm (`sin`) e acompanhar a cabeça com o billboard do avatar (`friend_npc.gd:65-72`). |
| **Rotação** | Na praça, o `FriendNpc` nasce virado para o chafariz (`city.gd:1293: npc.rotation.y = atan2(-npc.position.x, -npc.position.z)`). Não vira depois. |

### 3.2 O que **falta** para um passo que não pareça deslizar

1. **Trocar animação Idle → Walk** quando começa a andar, e Walk → Idle quando para.  
2. **Velocidade da animação casada com a velocidade de deslocamento** (senão o pé "patina" no chão).  
   - Hoje `play_walk` toca a animação na velocidade original do modelo. Precisa de `AnimationPlayer.playback_speed = velocidade_desejada / velocidade_original_do_walk`.  
3. **Foot placement / IK básico** (opcional mas recomendado):  
   - O modelo Quaternius tem ossos de pé (`LeftToe_End`, `RightToe_End`). Um `Skeleton3DIK` simples nos dois pés, alvo no chão (`raycast` para baixo), evita pé flutuando ou afundando em rampas/calçadas irregulares.  
   - Sem IK, em chão plano (calçada/praça) o deslize visual é só a velocidade da animação vs. translacao.  
4. **Rotação suave do corpo** na direção do movimento (não snap).  
   - `rotation.y = lerp_angle(rotation.y, target_angle, aceleração * delta)`.  
5. **Transição Idle ↔ Walk** (crossfade de ~0,15 s) para não "pular".  
   - `AnimationPlayer` da Godot suporta `cross_fade` ou `advance` manual.  
6. **Parâmetros de andar** no `AvatarBody`:  
   - `walk_speed` (m/s), `walk_anim_speed_ref` (velocidade original da animação Walk no modelo).  
   - Método `set_walk_velocity(velocity: Vector3)` que ajusta `playback_speed` e rotação.  

> **Conferido no código:** `avatar_body.gd:112-126` (play_idle/play_walk/_play_loop), `avatar_body.gd:60-80` (_ready carrega AnimationPlayer e Skeleton3D), `friend_npc.gd:128-149` (_build_figure cria AvatarBody e toca play_idle).  
> **Suposição:** a animação `Walk` do modelo Quaternius tem velocidade constante e pés que tocam o chão no loop (modelo CC0 padrão costuma ter). Se não tiver, precisaria de um modelo diferente ou ajuste no Blender — mas isso é da fase de assets, não do estudo.

---

## 4. Achar o amigo — mapa (M), minimapa e busca

### 4.1 Como funciona hoje (`ui/map_view.gd`, `ui/world_map.gd`)

- **`MapView`** (usada no minimapa e no mapa grande):  
  - Lê `get_map_data()` de quem estiver no grupo `"world_map"` (`CityMap`).  
  - Desenha: limites, praça, bairros (rects + zones), marcos (metrô, casa, marco, trilha), **jogador** (seta branca), **destino da busca** (losango colorido via `RouteGuide`).  
  - **Não desenha amigos.**  
  - Atualiza a cada `REFRESH_SECONDS = 0,2 s` (`_process` em `map_view.gd:54-58`).  

- **`WorldMap`** (tecla M):  
  - Instancia `MapView` com `follow_player = false`, `show_labels = true`.  
  - Pausa o jogo, mostra legenda.  

- **`GameSearch` (Tab):**  
  - Busca jogos pelos portais (`group "game_portal"`).  
  - Ao escolher, chama `show_route()` no grupo `"route_guide"` → `CityRouteGuide` acende faixa no chão.  
  - **Não busca amigos.**

### 4.2 O que precisaria mudar para mostrar amigo andando

| Componente | Mudança |
|---|---|
| **`MapView.refresh()`** (`map_view.gd:62-74`) | Além de `player` e `_target`, iterar `FriendsService.get_online_friends()` e, para cada um que **não está num portal** (`friend.game_id == 0` ou `SteamLibrary.get_game(friend.game_id) == null`), ler a posição do `FriendNpc` correspondente na cidade e desenhar um marcador (ex.: círculo pequeno na cor do status). |
| **`MapView._draw()`** (`map_view.gd:129-199`) | Desenhar marcadores de amigos **depois** dos marcos e **antes** do jogador (para o jogador ficar por cima). Usar `to_pixel(Vector2(npc.global_position.x, npc.global_position.z))`. |
| **`WorldMap`** | Herda de `MapView` — já funciona se `MapView` desenhar. |
| **`GameSearch`** (`game_search.gd`) | Opcional: adicionar aba/segmento "Amigos" na lista (hoje só jogos). Ao escolher amigo, chamar `show_route()` até a posição atual dele (o `RouteGuide` já aceita `Vector3` como alvo? Hoje aceita `GamePortal` — precisaria estender ou criar alvo genérico). |
| **`CityRouteGuide`** (`city_route_guide.gd:43-69`) | `show_route(player, portal)` hoje usa `portal.global_position`. Poderia ter `show_route_to_position(player, target: Vector3, color: Color)` genérico. |

> **Conferido no código:** `map_view.gd` (refresh, _draw, to_pixel), `world_map.gd` (abre MapView), `game_search.gd` (_measure_distances, _choose, _travel), `city_route_guide.gd` (show_route, route_points).  
> **Suposição:** o `FriendNpc` na cidade tem `global_position` acessível (hoje nasce em `_plaza_friend_position`; se andar, a cidade move o nó). A busca de amigo → posição funciona igual a jogo: `FriendsService` dá a lista, a cidade acha o `FriendNpc` correspondente (hoje `_plaza_friends` Array).

---

## 5. A arquitetura — andar como peça genérica em `components/`

### 5.1 Regra 1 do AGENTS.md: "Sistemas não conhecem mundos"

- `autoload/` **não** referencia `worlds/`.  
- Comunicação por **sinais e grupos** (`game_portal`, `route_guide`, `city_night`, `world_map`).  
- `FriendNpc` já está em `components/friend_npc/` — genérico, não sabe que é cidade.  
- `AvatarBody` em `components/avatar/` — genérico, serve a holograma e espelho.

### 5.2 O que a cidade entrega à peça de andar

| O que a cidade **tem** (dados puros) | Como entrega ao componente genérico |
|---|---|
| **Grafo de calçadas** (nós + arestas) | `WalkableGraph` (Resource ou autoload) publicado no grupo `"walkable_graph"` ou sinal `walkable_graph_ready(graph)`. |
| **Áreas proibidas** (portas, metrô, copa, prédios) | Já embutidas no grafo (arestas não existem lá). Ou `Array[Vector3] keep_out_points`, `Array[Rect2] keep_out_areas` — mesmo formato do `BiomeScatter.setup`. |
| **Posição inicial** (onde o amigo nasce) | A cidade instancia `FriendNpc` e define `global_position` + `rotation`. |
| **Alvos de passeio** (praça, esquinas, marcos, bancos, fronteiras de bairro) | `Array[Vector3] walk_targets` — a cidade sabe onde são "lugares interessantes" (praça, pórticos, estações, marcos, bancos dos parques). |
| **Mudança de bioma / ruas cobertas** | Sinal `walkable_graph_changed` quando `BiomeBuilder` cobre/descobre ruas (`cover_streets`). |

### 5.3 Componente genérico proposto: `components/friend_walker/`

```
components/friend_walker/
  friend_walker.gd          # Node3D, anexado ao FriendNpc (ou herdado)
  walkable_graph.gd         # Resource: nós (Vector3), arestas (int[] vizinhos), A* leve
  walk_state.gd             # Enum: IDLE, WALKING, PAUSED, TRANSITION
```

- **Não conhece cidade:** recebe `WalkableGraph` + `walk_targets` via `@export` ou método `setup(graph, targets)`.  
- **Escolhe alvo aleatório** da lista, pede caminho no grafo, anda até lá, espera `randf_range(5, 20)` s, repete.  
- **Evita colisão com outros amigos:** raio de separação simples (boid leve) ou ignora — são hologramas, podem se sobrepor levemente.  
- **Sinal `position_changed`** para o mapa/minimapa redesenhar (ou o `MapView` lê direto do `global_position` no `refresh`).

> **Conferido no código:** `components/friend_npc/friend_npc.gd` (já genérico), `city.gd` (_update_plaza_friends cria e posiciona), `city_map.gd` (get_map_data, grupo world_map), `biome_scatter.gd` (keep_out format).  
> **Suposição:** que a cidade consiga gerar o `WalkableGraph` uma vez no `_ready` e atualizar só quando bioma muda ruas (`cover_streets`). O grafo é 2D (x, z), o Y vem do chão (raycast ou altura fixa = 0).

---

## 6. O custo — quantos amigos andando e o que desligar de longe

### 6.1 Números de referência (desktop: Ryzen 5 5600 + RTX 4070, qualidade Alta)

| Item | Custo atual (parado na praça) | Custo estimado andando |
|---|---|---|
| **1 FriendNpc** | ~0,05 ms/frame (idle anim + flutuar + billboard avatar) | +0,1–0,2 ms (A* ocacional + move_toward + play_walk + rotação) |
| **10 amigos** | ~0,5 ms | ~1–2 ms |
| **50 amigos** | ~2,5 ms | **~5–10 ms** (pode pesar) |
| **100 amigos** | ~5 ms | **~15–20 ms** (perto do orçamento de 16 ms/frame para 60 FPS) |

> **Base:** hoje a cidade com 200 jogos falsos roda a 144 FPS (p99 13 ms) no desktop (ROADMAP, Fase 17). O orçamento de frame é ~16 ms. Amigos são **além** disso.

### 6.2 Estratégia de LOD (Level of Detail) para amigos distantes

| Distância do jogador | Comportamento |
|---|---|
| **< 30 m** | Anda completo: A*, animação Walk, rotação suave, IK pés (se tiver). |
| **30–80 m** | Anda simplificado: `move_toward` no segmento, **sem IK**, animação Walk com `playback_speed` fixo, atualização de alvo a cada 5 s. |
| **> 80 m** | **Para** (fica em Idle no último waypoint alcançado) — ou some (despawn) e renasce perto quando o jogador chega. |
| **Fora da vista (frustum culling)** | Godot já faz culling de `MeshInstance3D`; o `FriendNpc` continua processando `_process`. Adicionar `VisibilityNotifier3D` para pausar `_process` quando fora da tela. |

### 6.3 O que desligar de longe (ordem de prioridade)

1. **IK dos pés** (mais caro por frame).  
2. **Rotação suave** (lerp_angle) → snap imediato.  
3. **Animação Walk** → volta para Idle (parado).  
4. **Processamento de caminho** (A*) → só recalcula quando o jogador se aproxima.  
5. **Spawn/despawn dinâmico** — amigos além de 120 m não existem; a cidade mantém só a lista lógica (`FriendsService.get_online_friends()`) e instancia `FriendNpc` sob demanda (pool).

> **Suposição:** o dono tem poucos amigos online simultâneos (Steam típico: 10–30). O limite de 50–100 é cenário extremo. A estratégia de LOD garante que mesmo no extremo o frame não estoure.

---

## 7. O que **não muda**

> **ROADMAP, Fase 6:** "Quem está jogando um jogo da sua biblioteca continua na porta desse jogo: isso não muda."

- **Amigo jogando jogo da sua biblioteca** → `FriendNpc` no `GamePortal` (a porta do prédio).  
  - `GamePortal` já gerencia isso (`components/game_portal/`).  
  - O `FriendNpc` lá tem `show_game_name = false` (rótulo fica "Jogando agora").  
  - Não anda, não sai do portal.  
- **Só amigos ONLINE que NÃO estão num portal da cidade** (jogando outra coisa, ou só online) → andam pela cidade.  
  - Hoje ficam parados na praça (`_update_plaza_friends` em `city.gd:1277`).  
  - A fase 6 troca "parados na praça" por "andando pelas calçadas".

---

## 8. Decisões que ficam para o dono

| Decisão | Opções | Impacto |
|---|---|---|
| **Grau de realismo do andar** | (A) Só `move_toward` + animação Walk na velocidade certa (sem IK) — mais barato, aceitável em chão plano. <br> (B) + IK simples nos dois pés (raycast para chão) — evita pé flutuando em rampas/calçadas, custa ~0,05 ms/amigo. | (A) é suficiente pra calçada/praça plana. (B) se quiser "uau" no primeiro andar. |
| **Amigos se evitam?** | (A) Não — hologramas podem se atravessar (são projeções). <br> (B) Separação leve (boid: empurra se distância < 1 m). | (A) mais simples, zero custo extra. (B) evita "amigos fantasmas se fundindo". |
| **Alvos de passeio** | (A) Só praça + esquinas + pórticos + estações + marcos (fixos, ~20–30 pontos). <br> (B) + bancos dos parques (`CityDecor.add_park` cria 2 bancos por vaga) + fronteiras de bairro. | (A) cobre o básico. (B) mais "vivo", precisa a cidade listar os bancos. |
| **Despawn/pool de amigos distantes** | (A) Sempre instanciados (máx. ~30 online típico) — simples. <br> (B) Pool: spawn quando jogador < 100 m, despawn quando > 120 m. | (A) OK pra < 30 amigos. (B) se vier a ter 100+ amigos online. |
| **Busca (Tab) acha amigo andando?** | (A) Sim — aparece na lista "Amigos" (nova aba), escolher acende caminho até ele. <br> (B) Não — só mapa/minimapa mostram. | (A) mais útil, precisa estender `GameSearch` e `CityRouteGuide`. (B) mais simples. |
| **Grafo de calçada: quem gera?** | (A) `CityMap` no `_ready` publica no grupo `"walkable_graph"`. <br> (B) Autoload `WalkableGraph` (sistema) — mas sistemas não conhecem mundos (regra 1). | (A) segue a arquitetura: mundo gera, componente consome. |

---

## 9. Menor versão que já dá para testar (MVP)

> **Objetivo:** ver amigo andando na calçada, não atravessando prédio, mapa mostra onde ele está.

| Passo | O que faz | Arquivos (novos ou mudados) |
|---|---|---|
| **1. Grafo de calçada** | No `_ready` de `city.gd`, gerar `WalkableGraph` (Resource) a partir da grade: nós = centros de calçada (a cada ~2 m nas retas, esquinas, travessias), arestas = segmentos livres. Publicar no grupo `"walkable_graph"`. | `city.gd` (novo método `_build_walkable_graph`), `components/friend_walker/walkable_graph.gd` (novo Resource). |
| **2. Componente `FriendWalker`** | Node3D que anexa ao `FriendNpc` (ou herda). Recebe `WalkableGraph` + `walk_targets`. Escolhe alvo aleatório, A* no grafo, `move_toward` no segmento, `play_walk`/`play_idle`, rotação suave. Emite `position_changed` ao mover. | `components/friend_walker/friend_walker.gd` (novo). |
| **3. Integrar na praça** | Em `_update_plaza_friends` (`city.gd`), em vez de posição fixa no círculo, instanciar `FriendNpc` + `FriendWalker`, dar `walk_targets = [praça, pórticos, estações, marcos]`, deixar andar. | `city.gd` (muda `_update_plaza_friends`). |
| **4. Mapa/minimapa mostra amigo** | Em `MapView.refresh`, iterar `FriendsService.get_online_friends()`, achar o `FriendNpc` correspondente (filho da cidade), desenhar marcador (círculo cor do status). | `ui/map_view.gd` (muda `refresh` e `_draw`). |
| **5. LOD básico** | `VisibilityNotifier3D` no `FriendNpc` pausa `_process` do `FriendWalker` quando fora da tela. | `components/friend_npc/friend_npc.gd` (adiciona notifier), `friend_walker.gd` (respeita `process_mode`). |

**Tempo estimado:** 3–4 subetapas pequenas (trilha A) + 1 subetapa média (trilha B — grafo e walker).  
**Teste manual:** abrir hub, ter 2+ amigos online (sem jogar seus jogos), ver eles andando na praça/calçadas, abrir mapa (M) e minimapa — ver marcadores se movendo.

---

## 10. Proposta de subetapas cortadas para duas trilhas em paralelo

> **Regra da trilha B (paralela):** arquivos **diferentes** por trilha, **sem `.tres`**, **sem `city.gd`** na trilha B.

| # | Trilha | Subetapa | Arquivos | Tamanho | Esforço | Modelo |
|---|---|---|---|---|---|---|
| **6.1** | **A** | **Grafo de calçada no `city.gd`** — gerar `WalkableGraph` no `_ready` a partir de `CityLayout` + `SectorLayout` + `keep_out` do bioma. Publicar no grupo `"walkable_graph"`. | `city.gd` (novo `_build_walkable_graph`), `components/friend_walker/walkable_graph.gd` (novo Resource) | Grande | High | Opus |
| **6.2** | **B** | **Componente `FriendWalker`** — Node3D genérico em `components/friend_walker/`. Recebe `WalkableGraph` + `walk_targets[]`, faz A* leve, `move_toward`, `play_walk`/`play_idle`, rotação suave, `VisibilityNotifier3D` para LOD. **Não conhece cidade.** | `components/friend_walker/friend_walker.gd` (novo), `components/friend_walker/walkable_graph.gd` (lê, não escreve) | Grande | High | Opus (ou Sonnet se Opus ocupado) |
| **6.3** | **A** | **Integrar na praça** — `_update_plaza_friends` usa `FriendWalker`: instanciar, passar `walk_targets = [praça, pórticos, estações, marcos, bancos]`, remover posição fixa no círculo. | `city.gd` (muda `_update_plaza_friends`, `_plaza_friend_position` vira alvo inicial) | Pequena | Medium | Sonnet |
| **6.4** | **B** | **Mapa/minimapa desenha amigos** — `MapView.refresh` lê `FriendsService.get_online_friends()`, acha `FriendNpc` na cidade (grupo `"friend_npc"` ou referência), desenha marcador na cor do status. `WorldMap` herda. | `ui/map_view.gd` (muda `refresh`, `_draw`), `ui/world_map.gd` (sem mudança) | Pequena | Medium | Sonnet (ou modelo grátis) |
| **6.5** | **A** | **Busca (Tab) opcional: aba "Amigos"** — `GameSearch` ganha toggle Jogos/Amigos. Escolher amigo → `CityRouteGuide.show_route_to_position(player, npc.global_position, cor)`. | `ui/game_search.gd` (nova aba), `worlds/city/city_route_guide.gd` (novo `show_route_to_position`) | Pequena | Medium | Sonnet |
| **6.6** | **A** | **LOD + pool** — `FriendWalker` respeita `VisibilityNotifier3D`; cidade faz spawn/despawn por distância (pool de `FriendNpc`). | `components/friend_walker/friend_walker.gd`, `city.gd` (pool simples) | Pequena | Medium | Sonnet |
| **6.7** | **A** | **Teste manual + captura** — 3 amigos online andando, mapa/minimapa mostram, nenhum atravessa prédio/porta/metrô/árvore. Captura de tela. | — | Pequena (só docs) | Low | Haiku (atualiza plano/ROADMAP) |

### Divisão de arquivos por trilha

| Trilha | Arquivos que **mexe** | Arquivos que **só lê** |
|---|---|---|
| **A (principal)** | `city.gd`, `ui/map_view.gd`, `ui/game_search.gd`, `worlds/city/city_route_guide.gd`, `components/friend_npc/friend_npc.gd` | `components/friend_walker/walkable_graph.gd`, `components/friend_walker/friend_walker.gd` |
| **B (paralela)** | `components/friend_walker/friend_walker.gd`, `components/friend_walker/walkable_graph.gd` | `city.gd` (só lê a grade via `CityLayout`/`SectorLayout` — **não edita `city.gd`**), `ui/map_view.gd` (só lê para teste) |

> **Nota:** a trilha B **não toca `city.gd`**. Ela cria o componente genérico e o Resource `WalkableGraph`. A trilha A integra na cidade. O contrato entre elas é: `WalkableGraph` (Resource) + grupo `"walkable_graph"` + método `FriendWalker.setup(graph, targets)`.

---

## 11. Resumo do que foi conferido vs. suposição

| Tópico | Conferido no código (arquivo:função/linha) | Suposição |
|---|---|---|
| Grade, ruas, calçadas, quarteirões | `city_layout.gd:21-25, 79-80` | — |
| Praça, chafariz, floreiras | `city_decor.gd:281-328` | — |
| Prédios, portas, pórticos | `city.gd:940-977` (`_build_block`, `_build_game_building`), `city.gd:784-820` (`_build_gate`) | — |
| Metrô, estações, `keep_out_areas` | `city.gd:648-705` (`_build_metro`), `biome_scatter.gd:80` (`setup` recebe `keep_out_areas`) | — |
| Árvores/rochas, `keep_out`, copa | `biome_scatter.gd:103-190` (`plan`, `_blocked`), `biome_scatter.gd:58` (`CROWN_GAP`) | — |
| **Não há NavigationRegion3D/NavMesh** | `grep` no projeto | — |
| `CityRouteGuide` usa ruas (`street_line`) | `city_route_guide.gd:110-156` (`route_points`, `street_line`) | — |
| `AvatarBody` tem Idle e Walk | `avatar_body.gd:20-21, 112-126` | Animação Walk tem velocidade constante e pés no chão |
| `FriendNpc` usa `AvatarBody` + holograma | `friend_npc.gd:128-149` (`_build_figure`) | — |
| `FriendNpc` **não anda** hoje | `friend_npc.gd:65-72` (`_process` só flutua) | — |
| `MapView`/`WorldMap` desenham jogador + marcos + rota | `map_view.gd:62-199`, `world_map.gd:17-134` | — |
| `MapView` **não desenha amigos** | `map_view.gd:129-199` | — |
| `GameSearch` busca só jogos | `game_search.gd:196-224` (`_update_results`) | — |
| Arquitetura: sistemas não conhecem mundos | `AGENTS.md` regra 1, `city.gd` usa grupos/sinais | — |
| Amigo no portal **não muda** | `ROADMAP.md` fase 6, `city.gd:231-234` | — |
| Custo desktop (144 FPS, 200 jogos) | `ROADMAP.md` fase 17 | Estimativa de custo por amigo andando baseada em perfil típico de Godot 4.7 |

---

## 12. Entrega (para o coordenador)

- **Hash-base:** `33df095`  
- **Hash do commit:** (será gerado ao commitar este arquivo)  
- **Arquivos criados/mudados:** apenas `docs/design/estudo-amigos-andando-2026-11-15.md`  
- **Como conferi:** leitura direta dos arquivos listados na tarefa + `grep` por termos-chave (`NavigationRegion`, `NavigationAgent`, `friend`, `walk`, `map_view`, `route_guide`, `biome_scatter`, `city_layout`, `city_decor`).  
- **Pendências:** nenhuma — estudo completo. Próximo passo: dono aprova/rejeita decisões da seção 8, depois planeja a fase 6 em `docs/plans/fase-6.md`.

---

**Checklist de teste manual (para quando a fase for implementada):**

1. Abrir o hub no desktop (qualidade Alta).  
2. Ter ≥ 2 amigos online na Steam **sem jogar jogos da sua biblioteca**.  
3. Ver os amigos aparecendo na praça e **começando a andar** pelas calçadas.  
4. Confirmar que **nenhum atravessa** prédio, porta, boca do metrô, marco, árvore ou rocha.  
5. Abrir o mapa grande (M) — ver marcadores dos amigos se movendo.  
6. Olhar o minimapa — ver marcadores dos amigos se movendo.  
7. (Opcional) Busca (Tab) → aba "Amigos" → escolher um → faixa de luz acende até ele.  
8. Andar longe (> 100 m) — amigos distantes param/despawnam, FPS não cai.  
9. Voltar perto — amigos reaparecem/continuam andando.  
10. Medir FPS no desktop: deve ficar ≥ 120 FPS (margem sobre 60).