# Fase 19: Biomas baratos, árvores e céu vivo

**Status:** aprovado em 2026-11-12; em andamento
**Branch:** `fase-19`, criada da `main` (`bccc8eb`).

## Para o dono (até 10 linhas)
- **O que você vai ver quando a fase acabar:** árvores de verdade (feitas no Blender) nas floreiras, no RPG e na vista da cabana. O dia passa por nascer do sol, manhã, tarde, pôr do sol e noite, sem pulo. O tempo muda sozinho (abre, fecha, chove) e a chuva é outra: riscos de verdade, respingo, chão molhado e som. A Aventura é uma floresta e a Sobrevivência, um deserto. O bairro que você mais joga ocupa mais terreno e tem o marco mais alto.
- **Agora:** 19.1 feita (`79594e5`): o código já aceita mais de um bairro com bioma; nada muda na tela. A revisão (segundo Opus) não achou nada grave. A próxima é a 19.2, a amostra do pinheiro no Blender.
- **Ordem:** o código deixa de ser "só neve" → a amostra de uma árvore → todas as árvores → o dia em gradiente → a chuva nova → o clima dinâmico → a floresta → o deserto → os bairros crescem → o marco cresce → as sobras da montanha → fechamento.
- **Para testar:** cada subetapa traz o próprio checklist.
- **Decisões que esperam você:** aprovar a árvore da amostra (19.2); aprovar a chuva da amostra (19.5); prédios ou arcos no bairro com bioma (19.7); os downloads das 2 texturas de chão (19.7 e 19.8).

## Contexto
É a fase [3. Biomas baratos (PoC)](../ROADMAP.md#3-biomas-baratos-poc): provar o coração da V3 ("o que você joga molda o lugar") sem o custo da montanha. Ela passou à frente de "Visitar amigos" em 2026-11-12, quando o dono viu que o jogo do V-Sekai está parado (o registro está na ROADMAP). No planejamento, o dono pediu mais duas coisas, que entram aqui porque mexem nas mesmas peças: **todas as árvores como modelos do Blender** (inclusive as da janela da cabana) e **o céu vivo** (o dia em gradiente, com nascer e pôr do sol e uma tarde; o clima dinâmico; a chuva refeita, que hoje "está horrível").

O que já existe (exploração de 2026-11-12):
- **Biomas:** o `BiomeSpec` (`profiles/biome_spec.gd`) já é quase genérico (chão, calçada, passos, casca, enfeites, clima, névoa). Só o RPG usa (`profiles/biomes/montanha.tres`, gerado por `tools/gerar_bioma.gd`). O que ainda é "só neve" ou "só um bioma":
  - `city.gd` (`_build_biome_covers`) liga a névoa e o vento **só do primeiro** bioma, porque o `DayNight.set_fog_overlay` aceita uma mistura só;
  - a `BiomeAtmosphere` toca sempre o vento (`WIND_STREAM` fixo) e ignora os arquivos do `ambience_bed` do perfil;
  - o `BiomeScatter` desvia das portas e do metrô, mas não dos **prédios** (o RPG usa arcos). O grupo `scatter_keep_out` (com `footprint()`) já existe para os marcos;
  - os passos: o `player.gd` tem o conjunto "snow"; falta conferir grama e areia no `kenney/impact-sounds`.
- **Árvores:** todas são "impostoras", um retângulo com 8 fotos de um modelo pesado da Poly Haven (`worlds/city/tree_impostor.gd`; atlas em `assets/generated/`, feito por `tools/make_tree_impostor.gd`). De longe funciona; de perto é uma foto chapada. A jacarandá fica nas floreiras (`CityDecor.add_planter`, um nó por árvore) e o pinheiro, no RPG (`BiomeScatter`, numa MultiMesh). A **janela da cabana** é um retrato do mundo de verdade (`WindowView`, desde a 17.9): as árvores dela são as do mundo. O `home_window_forest.gdshader` não é mais usado por nenhum perfil.
- **Dia e noite:** o `DayNight` (`worlds/city/day_night.gd`) segue o relógio do PC e mistura **três** estados (dia, pôr do sol, noite) com as três fotos do céu. O amanhecer (6 às 7 h) reaproveita o pôr do sol, e das 7 às 17h30 o dia é um só: não há manhã nem tarde. Cerca de 30 scripts ouvem o grupo `city_night` (`set_night`, de 0 a 1).
- **Clima:** o `DistrictWeather` é fixo por bairro: garoa só na Sobrevivência e só à noite, neve no RPG o dia todo. A garoa são caixas finas de 1,5 cm × 60 cm que caem retas, sem respingo, sem som e sem molhar o chão. O céu não muda quando chove.
- **Horas:** o `city.gd` (`_build_districts`) dá `ceil(jogos / 4)` quarteirões por bairro e o `SectorLayout.plan(counts, focus)` reparte a borda em proporção. O `LibraryStats.compute()` já soma os minutos por bairro.
- **Sobras da Fase 15** (aceitas em 2026-11-01): pinheiros e rochas na encosta, o canto côncavo da divisa e a torre de dia.

## Pronto quando
- Nenhuma árvore do hub é uma foto chapada de perto: floreiras, RPG e floresta usam os modelos de `assets/models/trees/`, cada um com o script em `tools/blender/`. A janela da cabana mostra as árvores novas.
- Com o F8, dá para ver o nascer do sol, a manhã, a tarde, o pôr do sol e a noite, e nenhuma passagem tem pulo de luz. O que acende à noite continua acendendo na mesma hora.
- O tempo muda sozinho ao longo de uma sessão, e cada bioma mostra o mesmo tempo do seu jeito (chuva na cidade, neve na montanha, poeira no deserto). Dá para desligar pelo menu.
- A chuva passou na sua comparação de antes e depois, nas capturas e no jogo.
- A floresta e o deserto existem como perfis (`.tres`), e o deserto entrou **sem mudar nenhum `.gd`** (se precisar, fica registrado qual e por quê).
- Com 200 jogos falsos e horas diferentes por bairro, dá para ver no mapa (M) e andando um bairro maior que outro e o marco dele mais alto. Sem horas conhecidas, a planta é **igual à de hoje**.
- Desktop, Alta, 200 jogos: a caminhada não cai mais que 5% em relação à medida do começo da fase, com o mesmo comando (`tools/medir_desempenho.gd`), com tempo limpo; com chuva forte, a queda fica registrada. A referência da 18.2 era 151 FPS, p99 12 ms.

## Decisões de arquitetura
- **Bioma é dado** (regra 4): tudo o que distingue floresta de deserto mora no `BiomeSpec`; nenhum `match` de bioma no código.
- **Uma atmosfera por bioma, uma voz no céu.** Cada bairro com bioma tem a sua `BiomeAtmosphere`; só a de maior peso onde o jogador está fala com o `DayNight`.
  Descartado: somar névoas no `DayNight` (mexe no contrato do céu sem necessidade).
- **O som de fundo vem do perfil** (`ambience_bed.files`); o vento é o padrão de quem não diz nada.
- **Prédios entram no `scatter_keep_out`**, e "prédios ou arcos" vira só o campo `shell` do perfil.
- **`snow_cover` mantém o nome** (trocar campo quebra o `.tres`); o comentário passa a dizer "o chão do bioma por cima da pedra".
- **Árvore: perto é modelo, longe é a foto do mesmo modelo.**
  - O Blender faz a forma: `tools/blender/gerar_arvore.py`, uma função por espécie (árvore de rua, pinheiro, árvore da floresta), saída em `assets/models/trees/<espécie>.glb`, uma malha por material (`bark`, `leaves`), com a casca do `comum.py` e a textura de folha assada dentro do `.glb` (como a lenha da fogueira). Sem `.blend` no repositório.
  - A Godot faz o resto: um `TreeModel` em `worlds/city/` desenha as árvores de perto em MultiMesh (uma por material, com o vento no shader) e troca para a impostora ao longe. O atlas distante é refeito a partir do `.glb` novo com o `tools/make_tree_impostor.gd`, que já aceita glTF.
  - O `ScatterSpec` ganha o tipo `"tree"`, e as floreiras passam pelo mesmo `TreeModel`.
  - Orçamento: até 800 KB por espécie; a forma vem antes do tamanho. A distância da troca segue a qualidade gráfica.
  - A janela da cabana não ganha código: ela é um retrato do mundo. O `home_window_forest.gdshader`, sem uso, sai.
- **O dia é uma lista de momentos, e não três estados.** Um recurso de dado (`DayCycleSpec`, em `profiles/`) guarda os momentos do dia (madrugada, nascer do sol, manhã, tarde, pôr do sol, anoitecer, noite), cada um com a hora e os valores (cor e força do sol, névoa, exposição, luz ambiente, pesos das fotos do céu). O `DayNight` só interpola entre o momento de antes e o de depois.
  - As fotos do céu continuam três (dia, pôr do sol, noite): o nascer usa a do pôr do sol com o brilho do lado leste e um tom mais rosado; a tarde usa a do dia com luz dourada e sombras longas. Foto nova só se a captura pedir, com pedido de download.
  - **O contrato `set_night` (0 a 1) não muda**, e o `DayNight.night_amount(hora)` continua dando o mesmo valor de hoje: os ~30 scripts que acendem à noite não são tocados. Quem quiser saber o momento do dia pergunta ao `DayNight`.
  - O relógio segue sendo o do PC, com o F8 adiantando. A opção "Hora" do menu continua (automática, dia, noite).
  Descartado: mais `const` e mais um peso no `_mix3` (cada momento novo viraria código em vez de dado).
- **O clima é do mundo; a cara dele é do bioma.** Um `WeatherDirector` (em `worlds/city/`, um por cidade) decide o **tempo** de agora: limpo, nublado, chuva fraca, chuva forte, com passagens suaves e duração sorteada. Ele não desenha nada: publica o estado (grupo `city_weather`, `set_weather(estado, força)`).
  - Cada bairro traduz o tempo pela `WeatherSpec` dele: chuva na cidade, neve e nevasca na montanha, poeira no deserto, chuva com folhas na floresta. A tradução é dado, no perfil.
  - O céu responde ao tempo pelo `DayNight`: mais névoa, menos sol e céu mais escuro quando fecha (nas fotos e no Sky3D).
  - O sorteio é determinístico (semente pela data e pela hora da cidade), para o teste e a captura repetirem o mesmo tempo; `tools/capturar_pontos.gd` ganha um argumento para fixar o tempo.
  - Opção nova no menu, "Clima": dinâmico (padrão), sempre limpo. Gravada no `config.cfg` (`[video] weather`).
  Descartado: clima por bairro independente (choveria num quarteirão e faria sol no vizinho).
- **A chuva é um efeito em camadas**, cada uma ligada pela qualidade gráfica: os riscos (quads esticados na direção da queda, com textura macia e vento), o respingo no chão perto do jogador, o chão molhado (o material da rua fica mais liso e escuro com a força da chuva, e as poças que já existem aparecem mais), o som (um loop gerado pelo `assets/generated/make_sounds.py`, sem download) e o céu fechado. Nenhuma luz nova.
- **Crescer é terreno, não prédio:** os quarteirões seguem os jogos. As horas dão um **nível** por bairro (0 a 3, por faixas da fatia de horas), que aumenta o peso do bairro na partilha da borda: mais território, que vira vaga com o chão e os enfeites do bairro. Faixas, para a planta não mudar a cada hora jogada. O nível vem de uma função pura do `LibraryStats`.
- **O marco cresce com o mesmo nível** (um fator na altura), sem luz nova.
- **Assets:** 2 texturas CC0 da ambientCG (1K-JPG, cerca de 3 MB cada), pedidas antes com nome e tamanho. Se a amostra da árvore aprovar modelo CC0 em vez de script, o pedido de download vem junto.

## Subetapas
Trilha A (Claude, checkout principal). Trilha B (OpenCode com modelo grátis, em teste na 19.11; worktree próprio, criado da `fase-19`). Desde 2026-11-13 não há Codex: as revisões de risco são de um segundo Opus, só de leitura, num worker separado. Uma Godot por vez; o Blender não conta. A sessão coordenadora dispara os workers pelo Orca, faz os docs, revisa o diff da B e faz os merges.

- [x] **19.0 Branch, docs e plano** (só de docs · coordenador · medium) — 2026-11-12; `57f2472` (docs da Fase 18) e o commit `Docs: plano da Fase 19`
  - Faz: a branch `fase-19`; a Fase 18 como "publicada, esperando os amigos"; a ROADMAP com a ordem nova; a nota no estudo de 15/10; este plano.
- [x] **19.1 O código deixa de ser "só neve"** (grande · Opus, A · high · revisão: segundo Opus, pelo contrato entre a atmosfera e o céu) — `79594e5`, 2026-11-13; bateria completa ok (96 testes); capturas do RPG antes e depois iguais (13 e 22 h, Alta, 200 jogos); revisão do segundo Opus: nada grave
  - Faz: várias atmosferas com uma voz; som de fundo do perfil; passos de grama e areia (com o que o `kenney/impact-sounds` tiver; senão, pedido de asset); prédios como `scatter_keep_out`; `gerar_bioma.gd` com uma função por bioma, sem regravar o que existe. Os climas novos ficam para a 19.6.
  - Arquivos: `worlds/city/city.gd` (`_build_biome_covers`), `worlds/city/biome/biome_atmosphere.gd`, `worlds/city/biome/biome_builder.gd`, `worlds/city/city_building.gd`, `player/player.gd`, `tools/gerar_bioma.gd`, `tests/check_biome.gd`, `tests/check_biome_atmosphere.gd`.
  - Teste: bateria completa; um bioma de teste em memória num segundo bairro (duas atmosferas, a de maior peso manda; nenhum enfeite dentro de prédio). Capturas do RPG antes e depois: iguais.
  - Manual: a cidade e a montanha como antes.
  - Commit: `Fase 19.1: o bioma deixa de ser so neve`
- [ ] **19.2 Amostra: uma árvore no Blender** (grande: modelo e shader · Opus, A · high) — a parte do Blender pode correr junto com a 19.1; as capturas esperam
  - Faz: o **pinheiro** (é o que aparece no RPG e na janela da cabana), pelo `gerar_arvore.py`; o `TreeModel` mínimo; o atlas distante refeito. Capturas lado a lado com o pinheiro de hoje: de perto, a 30 m, a 150 m e pela janela da cabana, às 13 e às 22 h. Medida com as cópias do bairro do RPG.
  - O dono decide: segue por script; ou troca para um modelo CC0 reduzido no Blender (com o pedido de download); ou fica como está. A regra das plantas no AGENTS.md ("por script, ficam fracas") é acertada conforme a resposta.
  - Arquivos: `tools/blender/gerar_arvore.py` (novo), `tools/blender/comum.py` (só funções novas), `tools/blender/README.md`, `assets/models/trees/pine.glb`, `worlds/city/tree_model.gd` (novo), `worlds/city/tree_model.gdshader` (novo), `tests/check_trees.gd`.
  - Teste: bateria completa; capturas fora do repositório.
  - Commit: `Fase 19.2: o pinheiro do Blender (amostra)`
- [ ] **19.3 Todas as árvores** (grande · Opus, A · high · revisão: segundo Opus, só leitura, pelo custo de desenho na cidade inteira)
  - Faz: a árvore de rua nas floreiras e na praça (`CityDecor.add_planter` passa ao `TreeModel`), o pinheiro no RPG (`ScatterSpec` tipo `"tree"`, `montanha.tres` regerado pelo script), os dois atlas refeitos, o `home_window_forest.gdshader` removido.
  - Arquivos: `worlds/city/city_decor.gd`, `worlds/city/tree_impostor.gd`, `worlds/city/biome/biome_scatter.gd`, `profiles/scatter_spec.gd`, `profiles/biomes/montanha.tres` (pelo script), `assets/models/trees/street_tree.glb`, `assets/generated/*_impostor.*`, `tests/check_trees.gd`, `tests/check_biome.gd`, `README.md` (créditos).
  - Teste: bateria completa; medida no desktop contra a do começo da fase; capturas da praça, do RPG e das duas casas (a janela da cabana com os pinheiros novos).
  - Commit: `Fase 19.3: as arvores viram modelos`
- [ ] **19.4 O dia em gradiente** (grande: contrato do céu e dado novo · Opus, A · high · revisão: segundo Opus, só leitura, porque ~30 scripts dependem do `DayNight`)
  - Faz: o `DayCycleSpec` e o `.tres` dele, gerado por script com os valores de hoje como ponto de partida; o `DayNight` interpola entre os momentos; entram o nascer do sol (lado leste, tom rosado), a manhã (luz fria e limpa) e a tarde (luz dourada, sombras longas). `night_amount` e `set_night` iguais aos de hoje. O Sky3D recebe os mesmos momentos no que for dele (força do sol, névoa, exposição).
  - Arquivos: `profiles/day_cycle_spec.gd` (novo), `profiles/day_cycle.tres` (por script), `tools/gerar_ciclo_do_dia.gd` (novo), `worlds/city/day_night.gd`, `worlds/city/sky_blend.gdshader` (se o lado do brilho precisar), `tests/check_daynight.gd`, `tests/check_day_cycle.gd` (novo: nenhuma passagem com salto maior que um limite entre dois minutos seguidos; `night_amount` igual ao de antes em 24 horas).
  - Teste: bateria completa; capturas da praça, do pórtico do RPG e das duas casas às 6h30, 9, 13, 16, 18 e 22 h, nos dois céus.
  - Manual: F8 várias vezes na praça; cada toque muda a luz sem pulo.
  - Commit: `Fase 19.4: o dia em gradiente`
- [ ] **19.5 A chuva nova (amostra)** (grande: shader e partículas · Opus, A · high)
  - Faz: a chuva em camadas (riscos, respingo, chão molhado, som, céu fechado), em duas forças (fraca e forte), ainda **no lugar da garoa de hoje** (Sobrevivência, à noite) e com um argumento de captura para forçar a chuva de dia na praça. Capturas e um vídeo curto de antes e depois; o dono aprova antes de a chuva ir para a cidade toda.
  - Arquivos: `worlds/city/district_weather.gd`, `worlds/city/rain_streak.gdshader` (novo), `worlds/city/city_decor.gd` (o molhado no material da rua e das poças), `assets/generated/make_sounds.py` e `rain_loop.wav`, `autoload/graphics_quality.gd` (as camadas por qualidade), `tools/capturar_pontos.gd`, `tests/check_weather.gd`.
  - Teste: bateria completa; medida da caminhada com chuva forte (Alta) e na Leve do notebook só para comparar antes e depois.
  - Commit: `Fase 19.5: a chuva nova`
- [ ] **19.6 O clima dinâmico** (grande: arquitetura e dado salvo · Opus, A · high · revisão: segundo Opus, só leitura e adversarial, pelo contrato novo entre o clima, o céu e os bairros)
  - Faz: o `WeatherDirector`; os tempos (limpo, nublado, chuva fraca, chuva forte) com passagens; o `DayNight` fecha o céu; a `WeatherSpec` passa a dizer como o bairro traduz cada tempo, com os tipos "folhas" e "poeira" na tabela; a montanha traduz chuva em neve e nevasca; a opção "Clima" no menu e no `config.cfg`.
  - Arquivos: `worlds/city/weather_director.gd` (novo), `worlds/city/district_weather.gd`, `worlds/city/day_night.gd` (`set_weather_overlay`), `worlds/city/city.gd`, `profiles/weather_spec.gd`, `profiles/districts/*.tres` e `profiles/biomes/montanha.tres` (pelos scripts), `autoload/app_config.gd`, `ui/settings_view.gd`, `tests/check_weather_director.gd` (novo), `tests/check_weather.gd`, `tests/check_settings_view.gd`.
  - Teste: bateria completa. Mesma semente, mesmo tempo; as passagens não têm salto; "sempre limpo" desliga tudo; a casa ouve a chuva pela janela só se for barato (senão, vira ideia).
  - Manual: ficar 10 minutos na cidade com o tempo acelerado por um argumento de teste; ver o tempo abrir e fechar.
  - Commit: `Fase 19.6: o clima muda sozinho`
- [ ] **19.7 A floresta na Aventura** (grande: `.tres` e visual · Opus, A · high)
  - Faz: pedido da textura de grama; a árvore da floresta no `gerar_arvore.py`; `profiles/biomes/floresta.tres` pelo script (grama, calçada de pedra, árvores, rochas, pássaros de `assets/generated/`, chuva com folhas, névoa verde leve), ligado em `aventura.tres`. Capturas às 9, 16 e 22 h nas duas cascas (prédios e arcos): o dono escolhe, e vale para o deserto.
  - Teste: bateria completa; capturas.
  - Commit: `Fase 19.7: a Aventura vira floresta`
- [ ] **19.8 O deserto na Sobrevivência** (grande pela regra do `.tres`, mas curta · Sonnet, A · medium)
  - Faz: pedido da textura de areia; `deserto.tres` (areia, rochas maiores com areia por cima, vento, poeira no lugar da chuva, névoa quente, sem árvores), ligado em `sobrevivencia.tres`. Sem tocar em `.gd` além do gerador; se precisar, para e registra.
  - Teste: bateria completa; capturas.
  - Commit: `Fase 19.8: a Sobrevivencia vira deserto`
- [ ] **19.9 O bairro cresce com as horas** (grande · Opus, A · high · revisão: segundo Opus, só leitura e adversarial, porque muda a planta da cidade)
  - Faz: `LibraryStats.district_levels()`; `SectorLayout.plan` aceita o peso por bairro; `city.gd` passa os níveis; horas falsas na biblioteca de teste, se faltarem.
  - Arquivos: `components/library_stats/library_stats.gd`, `worlds/city/sector_layout.gd`, `worlds/city/city.gd`, `tests/check_library_stats.gd`, `tests/check_sector_layout.gd`, `tests/check_city_map.gd`.
  - Teste: bateria completa. Sem horas, planta idêntica; com horas, o nível 3 tem mais território que o 0, todo bairro contíguo e com borda, mesma entrada = mesma planta.
  - Manual: mapa (M) com a sua biblioteca.
  - Commit: `Fase 19.9: o bairro cresce com as horas`
- [ ] **19.10 O marco cresce** (pequena · Sonnet, A · medium)
  - Arquivos: `worlds/city/district_landmarks/district_landmark.gd`, `worlds/city/city.gd` (`_build_landmark`), `tests/check_landmarks.gd`.
  - Teste: `check_landmarks check_city_map`; captura da praça.
  - Commit: `Fase 19.10: o marco cresce com as horas`
- [ ] **19.11 Canto côncavo e torre de dia** (pequena · modelo grátis no OpenCode, B, worktree `divisa` · revisão: Opus, diff antes do merge) — depois da 19.1, em paralelo com a A. **É o teste da trilha grátis:** se a entrega ficar abaixo do Sonnet, a subetapa volta para o Sonnet na A e o resultado fica registrado aqui
  - Faz: `covered_rects` sem o quadrado de neve no cruzamento cercado por três zonas; a `RpgTower` ganha a bandeira grande para se destacar de dia.
  - Arquivos da B: `worlds/city/biome/biome_builder.gd` (só `covered_rects`), `worlds/city/district_landmarks/rpg_tower.gd`, `tests/check_divisa.gd` (novo). Sem `.tres`, sem `city.gd`.
  - Teste: os da B mais `check_biome check_landmarks`; capturas do canto e da torre às 13 h.
  - Commit: `Fase 19.11: canto da divisa e torre de dia`
- [ ] **19.12 Encosta com pinheiros e rochas** (grande: geometria · Opus, A · high) — depois da 19.3, para já usar o pinheiro novo
  - Faz: as famílias `on_backdrop` na encosta com `BiomeScatter.plan()`, fora da trilha, do mirante e da vista da luneta; quantidade pela qualidade.
  - Arquivos: `worlds/city/biome/backdrop_terrain.gd`, `worlds/city/biome/biome_scatter.gd`, `tests/check_backdrop_scatter.gd` (novo).
  - Teste: bateria completa; capturas da praça, do mirante e da janela da cabana; medida.
  - Commit: `Fase 19.12: pinheiros e rochas na encosta`
- [ ] **19.13 Medida e fechamento** (só de docs + medida · coordenador e o dono · medium)
  - Faz: bateria completa; medida no desktop (Alta, 200 jogos, 13 e 22 h, tempo limpo e chuva forte); README (árvores, o dia, o clima, os biomas, créditos), ROADMAP (fase feita; V3), `Início.md`. PR e merge só quando o dono pedir.
  - Commit: `Docs: fechamento da Fase 19`

## Riscos
- **A fase ficou grande** (13 subetapas, três assuntos). Linha de corte combinada: se pesar, as horas (19.9 e 19.10) viram a Fase 20, sem prejuízo do resto.
- **Árvore por script fica fraca** (é o que a regra do AGENTS.md avisa). Por isso a 19.2 é uma amostra com saída: modelo CC0 passado pelo Blender, ou ficar como está.
- **Árvores 3D e chuva em camadas derrubam o FPS.** Modelo só de perto, MultiMesh por material, camadas da chuva pela qualidade, e medida na 19.2, 19.3, 19.5 e no fim.
- **O dia novo desmancha o que a Fase 17 afinou** (a casa à noite, o contraste do dia). O gerador parte dos valores de hoje nas horas que já existem, e as capturas das 13 e das 22 h têm que bater com as da Fase 17.
- **O clima vira incômodo** (chove demais, escurece a cidade). As durações e as chances são dado; a opção "sempre limpo" existe desde a 19.6.
- **Teste que depende da hora ou do tempo fica instável.** O clima é determinístico e os testes fixam hora e tempo.
- **A floresta parece "cidade com grama":** a 19.7 compara prédios e arcos antes de seguir.
- **O deserto exige código:** corrigir na generalização (19.1 ou 19.6), não com um `if` no deserto.
- **A planta muda e o dono estranha a cidade:** níveis por faixa; sem horas, nada muda.
- **Tudo o que é difícil sai da cota do Claude Pro** (o ChatGPT Plus acabou em 2026-11-13): um worker grande por vez, a revisão depois da entrega, e a fase pausa se a cota esgotar. A linha de corte das horas (19.9 e 19.10) ajuda aqui também.
- **O modelo grátis entrega mal a 19.11.** É uma subetapa pequena, revisada pelo Opus antes do merge; se falhar, o Sonnet refaz e a trilha B fica sem uso nesta fase.

## Fora do escopo
- Terreno novo (morros, dunas com relevo) e água; trovão e raio; nuvens com volume; estações do ano; o clima de verdade da sua cidade pela internet (viram ideias em `docs/ideias/` se você quiser).
- Arbustos, flores e as plantas de dentro de casa; os prédios no Blender ([ideia](../ideias/predios-no-blender.md)).
- Mais de dois biomas novos; o parque do Casual vira ideia.
- Céu diferente por bioma, fotos de céu novas (salvo pedido na 19.4) e a qualidade Leve da montanha (15.13.6).
- Visitar amigos (fase 4 da ROADMAP) e o fechamento da Fase 18.

## Decisões tomadas durante a fase
- 2026-11-13 (fluxo): a assinatura ChatGPT Plus do dono acabou e o Codex recusa o Astra e o Sol. Decisão do dono: **Claude + OpenCode com modelos grátis**. O [AGENTS.md](../../AGENTS.md#modelos-e-esforço) foi refeito. Nesta fase: as cinco revisões de risco passam a um segundo Opus só de leitura; a 19.11 vira o teste do modelo grátis (primeiro candidato: `omniroute/free-coding`); a 19.12 passa ao Opus na trilha A.
- 2026-11-13 (19.1): o que saiu diferente do plano.
  - **Na divisa entre dois biomas, a névoa passa pela da cidade.** A atmosfera que tem a voz usa o quanto o peso dela passa do da segunda colocada, para a névoa não dar degrau. Com um bioma só, é o peso dele, como antes.
  - **O volume original do fundo da cidade fica guardado no próprio nó** (meta `biome_bed_base_db`), para qualquer atmosfera que vire a voz saber para onde voltar.
  - **`tools/gerar_bioma.gd`:** uma função por bioma; nunca regrava um `.tres` que existe; para regravar de propósito, `-- --refazer=montanha`. A função da montanha dá o `montanha.tres` de hoje sem diferença.
  - **Teste novo:** `tests/check_biome_second.gd` (a Ação ganha, só na memória, um bioma de teste com prédios: duas atmosferas, a de maior peso manda, nenhuma rocha dentro de prédio).
  - **Passos de grama e areia não entraram:** o `assets/kenney/impact-sounds` do projeto só tem concreto, madeira e neve. O pacote Kenney Impact Sounds (CC0) tem `footstep_grass_000` a `004`: pede a permissão do dono antes da 19.7. Ele não tem areia: a 19.8 decide entre outra fonte CC0 e usar o som da neve.
  - **Revisão:** feita por um segundo Opus, como worker do Orca e só de leitura (o Astra e o Sol foram recusados pela conta). **Nada grave:** sempre há exatamente uma voz; com um bioma só, o efeito é o de antes; a troca de qualidade não refaz a atmosfera; o `gerar_bioma.gd` não regrava o `montanha.tres`. Achados leves, que ficam para quando forem caso real:
    1. se uma atmosfera for refeita sozinha (pode acontecer no clima dinâmico da 19.6), por até 0,1 s a névoa volta à da cidade e o fundo fica 6 dB mais alto; correção: no `_exit_tree`, chamar `update_now()` nas outras do grupo. **A 19.6 confere isso.**
    2. o `check_biome_atmosphere` não testa a ordem inversa de atualização nem a névoa logo depois de um `setup()` na voz;
    3. o `check_biome` junta as plantas dos prédios com as das estações: uma estação que encolhesse sem sumir não seria pega.
  - A Godot dá um segfault ao fechar depois das capturas (as capturas saem completas); já acontecia antes da 19.1.
- 2026-11-12 (planejamento, respostas do dono):
  - a fase "Visitar amigos (V-Sekai)" fica adiada e a Fase 19 é a de biomas baratos;
  - os biomas novos são Floresta (Aventura) e Deserto (Sobrevivência);
  - todas as árvores passam a ser modelos do Blender, inclusive as da janela da cabana, começando por uma amostra;
  - entram o dia em gradiente (nascer e pôr do sol, tarde), o clima dinâmico e a chuva refeita;
  - a sessão coordenadora orquestra pelo Orca.

## Checklist de teste manual (fim da fase)
1. `bash tests/run_tests.sh` até `RESULTADO GERAL: TUDO OK`.
2. Na praça, chegue perto de uma floreira: a árvore tem tronco e copa de verdade, e de longe não "pula" ao trocar.
3. Na cabana, olhe pela janela: os pinheiros são os novos.
4. Na praça, aperte F8 até dar a volta no dia: nascer do sol, manhã, tarde, pôr do sol e noite, sem pulo; os postes e as janelas acendem como antes.
5. Fique alguns minutos andando: o tempo fecha e abre; na chuva, veja os riscos, o respingo, o chão molhado e ouça o som. Suba ao RPG: lá o mesmo tempo é neve. Em Esc › Som e vídeo, "Clima: sempre limpo" para tudo.
6. Aventura: grama, árvores, pássaros; nada atravessando prédio ou porta. Sobrevivência: areia, rochas, vento e poeira; a névoa muda na divisa sem degrau.
7. M: o bairro mais jogado ocupa mais terreno; da praça, o marco dele é o mais alto.
8. Trilha do RPG: pinheiros e rochas na encosta, nada no caminho nem na frente da luneta; a torre aparece de dia.
9. F3 na caminhada da praça, Alta, tempo limpo: perto da medida do começo da fase.
