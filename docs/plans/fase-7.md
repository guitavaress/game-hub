# Fase 7: World Profile

**Status:** em andamento (7.1)
**Branch:** `fase-7` (criada a partir de `fase-linux`, que está no PR #1 em rascunho; quando ela for juntada na `main`, `git rebase --onto main fase-linux fase-7`)

## Contexto
O dono segue no Linux até 18/10, então a próxima fase do [ROADMAP](../ROADMAP.md) é a **Fase 7**, que é do mundo e não depende de plataforma. Hoje o que muda de um bairro para outro está espalhado em vários `match` e ids fixos no código. A fase move tudo isso para **dados num perfil por bairro**, base da V3 (biomas) e do "criar um bairro novo sem mexer em código". Entram também o **clima por bairro** (garoa no Terror) e o **PortalShell** (o invólucro da porta deixa de ser só "prédio").

Levantamento feito (só leitura), com arquivo:linha:
- **Tabela** `GameCategories.CATEGORIES` (`autoload/game_categories.gd:22-199`): `{id, name, color, neon, tags}` ×10, ordem = ordem dos bairros na cidade (`city.gd:224`). API: `get_category_id` (override do config → tags → `outros`), `get_category_ids`, `has_category`, `get_category_name`, `get_category_color`, `get_neon_color`. Lida por `city.gd`, `city_building.gd`, `game_portal.gd`, `game_search.gd`, `city_route_guide.gd`, `game_screen.gd` e enfeites.
- **Som:** `match` em `components/ambient_emitter/category_ambience.gd:20-58`, chamado só em `city_building.gd:317`.
- **Enfeite:** `match` em `worlds/city/district_props/district_props.gd:24-46` (o caso `_` dá `AddressTotem`), chamado só em `city.gd:363`, **uma vez por quarteirão**.
- **Ids fixos:** `rpg_banners.gd:46-47` (`"rpg"`), `sports_scoreboard.gd:79` (`"esportes"`), `strategy_table.gd:25` (`"estrategia"`), `string_lights.gd:151` (procura o nó `DistrictProps_casual_x_y`), `app_config.gd:112-114` (lista de bairros no texto do config).
- **Terror:** névoa, néon falhando e poste apagado moram dentro de `terror_mood.gd` (um enfeite).
- **Arquitetura hoje não depende da categoria:** andares (`building_variant.gd:24,56-69`, `FLOOR_WEIGHTS`) e parede (`city_building.gd:53-57,345-349`, `WALL_STYLES`) saem de um sorteio pelo App ID. Densidade fixa em 4 jogos por quarteirão (`city_layout.gd:27`). O único landmark é o chafariz da praça (`city_decor.gd:190`).
- **Clima:** não existe chuva. O ciclo dia/noite mexe no Environment global (`day_night.gd:115-162`) e o grupo `city_night` liga/desliga 14 tipos de nó (`city.gd:185`). A qualidade só mexe no Environment (`graphics_quality.gd`).
- **Portal:** `GamePortal` já não sabe de prédio; quem o cria é `city_building.gd:307-314`, e o som do bairro é pendurado dentro dele (:317). 8 testes procuram `Building_<id>/GamePortal`.

## Pronto quando
- Criar um bairro novo = **um `.tres` novo** na lista do mundo (+ um script de enfeite opcional), sem tocar em `match`. Um teste varre o código e falha se aparecer id de bairro fora de `profiles/`.
- A cidade fica **idêntica** à de hoje, exceto: garoa no bairro Terror à noite.
- A bateria completa passa (25 testes de hoje + os novos).
- O `PortalShell` existe, o prédio é a casca padrão e há uma segunda casca (arco) coberta por teste.

## Decisões de arquitetura
- **Formato: arquivos `.tres` + inspetor** (escolha do dono). Dado puro, editável no inspetor, e bairros/biomas novos são só arquivos. *Descartado:* perfis em GDScript (mistura dado com código).
- **Onde moram: `profiles/` na raiz do projeto, não em `worlds/`.** O `GameCategories` é autoload e a regra 1 do CLAUDE.md proíbe `autoload/` conhecer `worlds/`. Conteúdo:
  - `profiles/district_profile.gd` (`DistrictProfile`, Resource): `id`, `display_name`, `color`, `neon` (transparente = calcular, como hoje), `tags` (`PackedInt32Array`), `ambience` (lista de `AmbienceSpec`), `props_script` (caminho, "" = nenhum), `weather` (`WeatherSpec`), `shell` (`"building"` por padrão), `wall_styles` e `floor_weights` (padrão = o sorteio de hoje), e os campos **reservados** `density` (4) e `landmark_script` ("") sem efeito ainda.
  - `profiles/ambience_spec.gd`, `profiles/weather_spec.gd` (sub-recursos simples).
  - `profiles/world_profile.gd` (`WorldProfile`, Resource) com `districts: Array[DistrictProfile]` **em ordem** (a ordem da lista é a ordem dos bairros). `profiles/world_profile.tres` é o mundo "cidade". Adicionar um bairro = novo `.tres` + um item nessa lista (no inspetor ou no texto). Futuros biomas = outros `WorldProfile`.
  - `profiles/districts/*.tres` (10 arquivos: `esportes`, `rpg`, `sobrevivencia`, `simulacao`, `estrategia`, `acao`, `cartas`, `aventura`, `casual`, `outros`).
  - `profiles/profiles.gd` (`Profiles`, estático): carrega e guarda o mundo; devolve o perfil por id.
- **`GameCategories` continua existindo com a mesma API** (fachada): só passa a ler os perfis. Nenhum chamador muda.
- **O mundo repassa o perfil, o enfeite não adivinha:** `DistrictProps.decorate` recebe o perfil e cria o script de `props_script`; os enfeites que citavam o próprio id (`rpg_banners`, `sports_scoreboard`, `strategy_table`, `string_lights`) passam a ler o id e as cores do perfil recebido.
- **Névoa do Terror fica no enfeite** (`terror_mood.gd`); o clima novo é só chuva. *Motivo:* o teste `check_district_props` procura `GroundMist` ali, e névoa por quarteirão já funciona.
- **Clima = um `DistrictWeather` por bairro, criado uma vez** (no 1º quarteirão, como o pórtico), e não por quarteirão. Uma `Area3D` cobre o bairro (máscara do jogador, igual à `EntryArea`) e **uma** caixa de partículas (`GPUParticles3D`, ~30×15×30 m, sem luz, sem sombra) acompanha o jogador **enquanto ele está dentro e é noite** (grupo `city_night`). *Motivo:* custo constante e independente do tamanho do bairro, e nunca mexe no `Environment` global (a neblina e o ciclo são globais).
- **Qualidade também vale para o clima:** `GraphicsQuality.weather_amount(level)` (alta 100%, média 60%, leve 25%), aplicada pelo clima ao ouvir `AppConfig.settings_changed`. Necessário porque o notebook (Radeon 610M) já roda ~9 FPS na alta.
- **PortalShell:** classe base `PortalShell` (Node3D) com "monte-se e diga onde fica a porta, o tamanho do alvo e onde pendurar o som". **`CityBuilding` passa a estendê-la**, e o `city.gd` pergunta ao perfil qual casca usar por uma fábrica. Segunda casca: `ArchShell` (arco simples). Os **nomes de nó não mudam** (`Building_<id>/GamePortal`, `DistrictProps_<id>_x_y`), porque 8 testes dependem deles; o som continua filho do portal.
- **Arquitetura agora; densidade e landmark só como campos** (escolha do dono): o perfil escolhe pesos de parede e de andares (padrão = hoje, então nada muda de visível). `density` e `landmark_script` ficam definidos e documentados, sem uso. *Motivo:* densidade mexe em `block_cells`, pórtico, skyline, rota e vários testes.

## Subetapas
Ordem: primeiro o que não muda nada visível, depois o que usa a estrutura, o visual por último. Cada uma tem teste, commit e `[x]`.

- [x] **7.0 Preparação** (Opus · high)
  - Faz: `git checkout -b fase-7` a partir de `fase-linux`; salva este plano como `docs/plans/fase-7.md` (formato de `docs/plans/README.md`); **grava o "retrato" do comportamento de hoje** (tabela, ordem, sons por categoria) em `tests/fixtures/profiles_atuais.json`, rodando um script uma vez sobre o código atual, para os testes das próximas subetapas compararem com ele.
  - Feito: o retrato é gravado por `tools/retrato_perfis.gd` (rodado uma vez, sobre o commit `3b8c3fc`): as 10 categorias em ordem (nome, cor, neon, tags), os sons de cada bairro (tipo, arquivos, volume, distância, intervalo, tom), o enfeite de cada um (script, nome do nó, se tem `cell`) e, para 517 App IDs, os andares e o estilo de parede sorteados. Duas rodadas deram arquivos idênticos, e as cores conferem com o código.
  - Commit: `Fase 7.0: plano e retrato do comportamento atual`
- [x] **7.1 Perfis e `GameCategories` lendo deles** (Sonnet · medium)
  - Faz: `DistrictProfile`, `AmbienceSpec`, `WeatherSpec`, `WorldProfile`, `Profiles`; os 10 `.tres` com os dados atuais (cores convertidas do hexa para `Color(r, g, b, 1)`); `GameCategories` vira fachada. Ordem preservada.
  - Teste: `tests/check_profiles.gd`: os 10 perfis carregam, ids únicos, **mesma ordem, nome, cor, neon e tags do retrato**, API do `GameCategories` igual; todo id do texto do config existe; `get_category_id` com override e `outros`.
  - Feito: as classes têm desde já os campos de todas as subetapas (som, enfeite, clima, casca, pesos de arquitetura, `density` e `landmark_script` reservados), mas só os de identidade (nome, cores, tags) têm dados; assim os `.tres` não mudam de formato a cada passo. Os 10 `.tres` e o `world_profile.tres` foram gerados pela própria Godot (`ResourceSaver`) a partir da tabela antiga, para não errar um dígito de cor à mão. Cada perfil ganhou `tag_names` (o nome de cada tag, tirado dos comentários da tabela antiga), para ler no inspetor. A tabela `CATEGORIES` saiu do `GameCategories`.
  - Commit: `Fase 7.1: perfis de bairro em .tres e GameCategories como fachada`
- [ ] **7.2 Som vindo do perfil** (Sonnet · medium)
  - Faz: `CategoryAmbience.create(id)` monta os emissores a partir de `profile.ambience`; some o `match`. Mesma assinatura, **mesma ordem** de emissores.
  - Teste: `check_phase6_audio` (inalterado) + `check_profiles` confere por categoria: tipo (loop/avulsos), volume, distância, intervalo e quantidade, contra o retrato.
  - Commit: `Fase 7.2: som ambiente por perfil`
- [ ] **7.3 Enfeite vindo do perfil** (Sonnet · medium)
  - Faz: `DistrictProps.decorate(..., profile)` cria `props_script`; some o `match`; `rpg_banners`, `sports_scoreboard`, `strategy_table`, `string_lights` leem id/cores do perfil recebido (`string_lights` deixa de procurar `DistrictProps_casual_*` pelo nome fixo).
  - Teste: `check_district_props` (inalterado) + em `check_profiles`, **varredura estática**: nenhum arquivo fora de `profiles/`, `tests/` e do comentário do `app_config` cita os ids dos bairros entre aspas (modelo: `check_platform`).
  - Commit: `Fase 7.3: enfeite do bairro por perfil`
- [ ] **7.4 PortalShell** (Opus · high: mexe na hierarquia mais testada)
  - Faz: `PortalShell` base; `CityBuilding` a estende; fábrica por `profile.shell`; `ArchShell`; a criação do portal sai de `city_building.gd:307-314` para a base. Nomes de nó e som iguais.
  - Teste: `check_portal_regression`, `door_charge`, `gates`, `search`, `look_card`, `session_summary`, `phase4`, `phase5` (todos inalterados) + `tests/check_portal_shell.gd`: o prédio é um `PortalShell`, o arco também tem `GamePortal` com `get_return_transform`, e entrar pela porta do arco dispara o `GameLauncher` falso.
  - Commit: `Fase 7.4: PortalShell e casca de arco`
- [ ] **7.5 Arquitetura por perfil** (Sonnet · medium)
  - Faz: `building_variant.gd` e `city_building.gd` leem `floor_weights` e `wall_styles` do perfil (padrão = tabela atual). `density` e `landmark_script` ficam como campos documentados, sem uso.
  - Teste: `check_variants` (inalterado: 3–7 andares, variedade, mesmo jogo = mesmo prédio) + `check_profiles`: com os 10 perfis padrão, a distribuição de andares e paredes de uma biblioteca de exemplo é **idêntica** à de antes; um perfil de teste com pesos diferentes muda o resultado.
  - Commit: `Fase 7.5: arquitetura por perfil`
- [ ] **7.6 Clima: garoa no Terror** (Sonnet · medium; Opus se o visual teimar)
  - Faz: `DistrictWeather` (Area3D + `GPUParticles3D`, só dentro do bairro e à noite), criado uma vez por bairro com clima no perfil; `weather_amount` no `GraphicsQuality`; o perfil `sobrevivencia` ganha `weather = garoa`. Só o Terror muda de visível.
  - Teste: `tests/check_weather.gd`: só o Terror tem `DistrictWeather`; chove só à noite e só com o jogador dentro; `amount` por qualidade (100/60/25%); não mexe em `environment.fog_*`; trocar a qualidade em jogo atualiza. Captura de tela com janela (fora do repositório), à noite, nas qualidades Alta e Leve, e conferir o FPS no notebook.
  - Commit: `Fase 7.6: garoa por bairro (Terror)`
- [ ] **7.7 Docs** (Sonnet · low)
  - Faz: README (o que muda para o usuário: garoa no Terror; "como criar um bairro novo"), ROADMAP (Fase 7 feita), CLAUDE.md (mapa: `profiles/`; regra 4 em vigor), `docs/plans/fase-7.md` (marcado) e `tests/README.md` (retrato e testes novos).
  - Commit: `Fase 7.7: documentação`

## Riscos
- **Nomes de nó** (`Building_<id>/GamePortal`, `DistrictProps_<id>_x_y`, `GroundMist`) são usados por muitos testes: ficam como estão; a 7.4 roda todos eles.
- **Ordem dos bairros e dos emissores** muda o layout e o `check_phase6_audio` (que pega o primeiro emissor): o retrato e os testes da 7.1 e 7.2 travam isso.
- **Cores:** converter hexa para `Color(r, g, b, 1)` à mão pode errar um dígito; o teste compara com o retrato.
- **`.tres` escrito à mão:** erro de sintaxe só aparece ao importar; o teste e o `--import` do `run_tests.sh` pegam.
- **Clima global x local:** nunca mexer em `environment.fog_*` nem no `city_night` além de ligar/desligar as partículas.
- **Desempenho no notebook:** partículas transparentes custam; por isso a escala por qualidade e a medida de FPS na 7.6.
- **Sem Windows até 18/10:** tudo aqui é independente de plataforma; no desktop, repetir a bateria e dar uma olhada no Terror à noite.

## Fora do escopo
- Densidade e landmark com efeito (ficam como campos reservados; vão para "Depois" no ROADMAP).
- Som de chuva, outros climas (tempestade, neve) e névoa migrada para o sistema de clima.
- Biomas (montanha de gelo etc.) e viagem rápida/minimapa (Fase 8).
- Push e merge: nada vai para o GitHub sem o dono pedir.

## Decisões tomadas durante a fase
- 2026-10-05: perfis em `.tres` (dono). Arquitetura agora; densidade e landmark só como campos (dono).
- 2026-10-05: **na 7.5, os sorteios têm de continuar idênticos** com os perfis padrão. Andares: semente `app_id * 7919 + 13` e `rand_weighted(FLOOR_WEIGHTS)` como 1º sorteio; parede: semente `app_id` e `randi_range(0, 2)` como 1º sorteio. Trocar `randi_range` por um sorteio com pesos mudaria a parede de quase todo prédio; com pesos iguais, o código deve seguir pelo `randi_range` (7.0).
- 2026-10-05: o enfeite de esportes (`sports_scoreboard`) também tem o campo `cell`; o retrato registra quais têm (7.0).
- 2026-10-05: o `tools/retrato_perfis.gd` só funciona no código de antes da 7.1 (lia a tabela antiga); para regravar, voltar ao commit `3b8c3fc` (7.1).
- 2026-10-05: scripts de ferramenta (`-s`) que usam a cidade carregam `CityBuilding`, `DistrictProps` etc. com `load()` depois dos autoloads; citar a classe direto os compila cedo demais e os enfeites que usam `GameCategories` falham (7.0).

## Checklist de teste manual (fim da fase)
No notebook (Omarchy), qualidade **Leve**:
1. F5. A cidade tem os mesmos bairros, cores e sons de antes (andar pela praça e por 2 bairros).
2. F8 até a noite. Entrar no bairro **Terror** (Sobrevivência): garoa em volta de você; sair do bairro: a garoa para.
3. Esc › Qualidade: Alta mostra mais chuva que Leve, sem travar.
4. Em outro bairro (ex.: Cartas), nunca chove.
5. Tab, buscar um jogo: a faixa de luz leva até a porta; entrar abre o jogo e o hub volta ao fechar (Undertale e Balatro).

No desktop com Windows (a partir de 18/10): o mesmo, mais `bash tests/run_tests.sh`.

## Verificação
1. `bash tests/run_tests.sh` ao fim de cada subetapa e no fim da fase: `RESULTADO GERAL: TUDO OK`.
2. `check_profiles` com a varredura "nenhum id de bairro fora de `profiles/`".
3. Capturas de tela da 7.6 só na pasta temporária da sessão (mostram capas de jogos), nunca no repositório.
