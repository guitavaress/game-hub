# Estudo: fase "8. Primeira e terceira pessoa"

> **Arquivo:** `docs/design/estudo-primeira-terceira-pessoa-2026-11-15.md`
> **Data:** 2026-11-15. **Escopo:** só leitura; nenhum código mudou. A Godot não foi aberta.
> **Base:** `bcd4cfe` (branch `worktree/estudo-visoes`, criada da `fase-19`; o `33df095` é ancestral).
> **Número da fase:** na ROADMAP ela se chama "8. Primeira e terceira pessoa", mas as fases 7 e 8 antigas já existem em "Feito" (World Profile e Escala). O plano decide o número real (a partir de 20).

**Como ler:** em cada seção, **Conferido** = li o arquivo e a função citados. **Suposição** = não conferi; precisa de teste ou de leitura da documentação da Godot 4.7 no plano. Não achei nada que exigisse inventar nome: onde não achei, está escrito "não achei".

---

## 0. O resumo para o dono

- **Dá para fazer, e a maior parte já está pronta.** O jogador já esconde o "corpo do espelho" da própria câmera por camada de desenho (`AvatarBody.REFLECTION_LAYER = 19`), e todo o "olhar para algo" já tem um contrato simples (`focus_on`, `get_camera_pose`, `interact`, `get_look_info`) que **não depende de a câmera estar na cabeça**.
- **O modelo tem uma só malha** (4.733 vértices, uma superfície): não dá para "desligar a cabeça" escondendo um pedaço. O jeito mais seguro é ter **duas cópias da mesma malha** no mesmo esqueleto (veja 1.3).
- **O passo vai deslizar se ligarmos a animação sem cuidado**: o jogador anda a 5 m/s (e corre a 9), mas as animações do modelo andam a cerca de **2 m/s (Walk)** e **4 m/s (Run)** (estimativa minha, veja 2.2). É preciso escolher um visual de passo; é uma decisão sua (seção 9).
- **O maior risco técnico é a luz dentro de casa** (veja 1.5): a casa tira a camada dela do sol; um corpo fora dessa camada seria iluminado como se não houvesse telhado.
- **A menor versão testável** (seção 10): a tecla alterna, o corpo aparece e anda, a câmera de terceira pessoa tem braço com colisão; **sem** o corpo em primeira pessoa e **sem** os braços, primeiro.

---

## 1. O corpo em primeira pessoa

### 1.1 O que existe (conferido)

| Fato | Onde |
|---|---|
| O jogador é um `CharacterBody3D` com cápsula de 0,4 m de raio e 1,8 m de altura, camada 2, máscara 1. A origem fica nos pés. | `player/player.tscn`, `player/player.gd` (cabeçalho) |
| A câmera é `Head/Camera3D`; a cabeça fica a **1,6 m** do chão. O `LookRay` (RayCast3D, máscara 5 = camadas 1 e 3, `collide_with_areas`) é **filho da câmera**. | `player/player.tscn` |
| A rotação para os lados gira o **Player inteiro** (`rotate_y`); a rotação para cima/baixo gira só o `Head` (limite 89°). | `player.gd: look_by`, `_look_with_stick` |
| `AvatarBody` é um `Node3D` genérico: carrega `animated_human.glb`, ajusta altura (1,7 m) e frente (+Z) em `_fit()`, pinta por zonas do UV, toca `Idle` e `Walk` em loop. A origem fica **nos pés**, olhando para +Z. | `components/avatar/avatar_body.gd` |
| `AvatarBody.set_render_layers(layers)` troca a camada de desenho de todas as malhas. O jogador já faz `_camera.cull_mask &= ~AvatarBody.reflection_layers()` no `_ready`. | `avatar_body.gd`, `player.gd:169` |
| Hoje o **espelho** (`HomeMirror`) cria o próprio `AvatarBody` (`ReflectionBody`, `cast_shadows = false`), o põe em cima do jogador a cada quadro (`_follow`) e troca Idle/Walk quando a velocidade passa de 0,6 m/s. | `worlds/home/home_mirror.gd: _build_body, _follow` |

### 1.2 Como prender o corpo ao jogador (proposta; a base está conferida)

- Um `AvatarBody` **filho do `Player`**, na origem (pés), com as cores do `AppConfig.get_avatar()` (`AvatarSpec.from_dict`) e ouvindo `AppConfig.settings_changed` (seção `avatar`), como o espelho já faz em `_on_settings_changed`.
- **O corpo gira à parte do jogador.** O `Player` continua girando com a câmera (assim a bússola, o mapa, `teleport_to` e `get_return_transform` do portal seguem iguais: `ui/compass.gd:43` e `ui/map_view.gd:68` leem `-player.global_basis.z`). O `AvatarBody` (visual) faz `lerp_angle` do próprio giro para a **direção do movimento** (parado: para onde a câmera olha). Isso evita o "corpo andando de costas" ao apertar S ou ao andar de lado. *Proposta, não existe hoje.*
- A altura de 1,7 m do `AvatarBody` bate com a cápsula (1,8 m) e a cabeça (1,6 m): nada a ajustar. *Conferido pelas constantes; o encaixe fino (olho x topo da cabeça) é suposição e se vê numa captura.*

### 1.3 Tirar a cabeça só da visão de quem olha

**Conferido (importante):** o `.glb` tem **uma só malha** (`Human_Mesh`, 1 superfície, 4.733 vértices, 51 nós, 1 `skin`). Li o JSON do arquivo. Os olhos e o cabelo só existem na cabeça (o `tests/check_avatar.gd` confere por osso dominante), mas a **pele** é a mesma zona de cabeça, mãos e pés, então **o shader por zona do UV não separa a cabeça** (`avatar_palette.gdshader`).

| Jeito | Prós | Contras |
|---|---|---|
| **A. Duas cópias da malha no mesmo esqueleto** (recomendado): uma **completa** e uma **sem cabeça** (sem os triângulos do osso `Head`/`HeadTop_End`, e talvez o pescoço). Mostra uma ou outra por `visible`; a completa fica com `cast_shadow = SHADOWS_ONLY` em primeira pessoa. | A sombra continua inteira; o reflexo e a terceira pessoa usam a completa; o custo é só 4,7 mil vértices a mais, sem segundo esqueleto. | Precisa gerar a malha sem cabeça (em código, uma vez, filtrando triângulos pelo osso dominante com `ARRAY_BONES`/`ARRAY_WEIGHTS`, que o `check_avatar.gd` já sabe ler; **ou** um script do Blender, que é o caminho do AGENTS.md para formas). |
| B. Escalar o osso `Head` a ~0 (`Skeleton3D.set_bone_pose_scale`, suposição de API) | Nenhuma malha nova. | O esqueleto é um só: o reflexo e a sombra **também** perdem a cabeça. Só serve com dois corpos inteiros (dois esqueletos e duas animações: mais caro que A). |
| C. `cull_mask` da câmera sozinho | Já está em uso para o reflexo. | Camada é **por objeto inteiro**, e a malha é uma só: não esconde "só a cabeça". Vale para escolher *qual cópia* aparece (A), não para cortar a cabeça. |
| D. Shader que recorta por peso de osso (`BONE_INDICES`/`BONE_WEIGHTS` no `vertex()`) | Uma malha só. | Suposição: não conferi que a Godot 4.7 entrega esses valores antes ou depois do skinning; é shader (Opus, só com captura). Deixar como plano B. |

**Sombra e reflexo:**
- **Sombra inteira:** a cópia completa, com `cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY` (nome do enum é suposição; o código do projeto só usa `..._OFF`, em `avatar_body.gd:79`) em primeira pessoa; a sem cabeça com sombra desligada (para não sombrear duas vezes).
- **Reflexo no espelho:** o espelho já tem o corpo dele (`ReflectionBody`) na camada 19, que a câmera do espelho enxerga (`cull_mask = Home.INTERIOR_LAYER_MASK | AvatarBody.reflection_layers()`, `home_mirror.gd:350`) e a do jogador não. **Recomendo não mexer nisso na primeira entrega**: o corpo real do jogador **não** pode estar nas camadas 19 nem 20 *com visibilidade para a câmera do espelho*, ou aparece duas vezes. Hoje o `check_mirror.gd` exige que a câmera do espelho **não** veja a camada 1 (`mirror_camera.cull_mask & 1 == 0`).

### 1.4 Onde fica a câmera em relação ao pescoço

- **Hoje:** a câmera é a própria cabeça, a 1,6 m, sem deslocamento (`player.tscn`). O topo da cabeça do modelo fica a 1,7 m.
- **Em primeira pessoa com corpo:** a câmera deve ir **um pouco à frente e acima do pescoço** (algo como 8 a 12 cm à frente do osso `Head`), para o rosto, o cabelo e o `near` da câmera não aparecerem. Número é suposição (afina-se numa captura). O corpo sem cabeça já elimina o pior problema (olhar "de dentro" do crânio).
- **A câmera tem de ficar no `Head` do `Player`** (não no osso do modelo): senão o balanço da animação de respirar sacode a visão. `CameraFeel` mexe só em deslocamentos de poucos cm sobre `_camera_rest` (`camera_feel.gd`), e continua valendo.

### 1.5 Dentro de casa: a camada do interior (risco principal)

**Conferido:** `Home` põe **tudo o que desenha** na camada 20 (`_put_on_interior_layer`, `home.gd:845`), e o sol do mundo (e os dois spots do sol da casa) usam `light_cull_mask` para separar fora e dentro (`home.gd:532, 547`; o `check_home.gd:63,76` confere que o sol **não** ilumina as camadas 19 e 20). O jogador não está dentro do `Home` (é irmão), então o corpo dele fica na camada 1.

**Consequência (suposição a medir):** com o corpo na camada 1 dentro da casa, o **sol do mundo o ilumina como se não houvesse telhado** (corpo claro demais, sombra sem teto), e a **vista da janela** (que esconde a camada 20) mostraria o corpo na imagem lá de fora.
**Proposta:** quem já avisa o jogador de que ele entrou (`Player.set_indoors`, chamado pela `Home`, `home.gd:828-831`) também manda o corpo para a camada do interior (`body.set_render_layers(Home.INTERIOR_LAYER_MASK)`), e na saída volta à camada 1. Aí a câmera do **espelho** (que enxerga a camada 20) passaria a ver o corpo real **e** o `ReflectionBody` juntos: o plano tem de **esconder o `ReflectionBody` enquanto o corpo real estiver vivo**, e manter o `_stand_in_fitting_spot` do provador (a câmera sai do lugar do jogador, então o corpo real precisa ficar parado ou escondido enquanto o espelho foca). Esta é a parte mais delicada: **precisa de captura com o espelho** antes de aprovar. `player.gd` não importa `Home` (regra 1: sistemas não conhecem mundos), então a camada vem pelo argumento do `set_indoors` ou por um método genérico (ex.: `set_body_layers`); desenho a decidir no plano.

### 1.6 Olhar para baixo, pular e pousar

- **Olhar para baixo:** com o corpo e a câmera na cabeça, a 89° para baixo a câmera vê o **peito e os pés** do corpo sem cabeça. O que falta é o `near` da câmera e a barriga/ombros ocuparem a tela: ajustar o recuo da câmera e o ângulo. *Suposição, só vista em captura.*
- **Os braços:** o modelo tem as animações `Idle` e `Walk`, mas os braços ficam ao lado do corpo; **não há** pose de "braços para a frente". Olhar para baixo mostra o tronco e as pernas com os braços balançando nas laterais da visão. Isso basta para o pedido do dono ("tronco, braços, pernas e pés"). Não achei no repositório nada de IK de braço nem de "mãos na mira".
- **Pular:** o modelo tem uma animação `Jump` (1,0 s, conferi no `.glb`), mas o `AvatarBody` só tem `play_idle` e `play_walk`. Em primeira pessoa dá para usar `Jump` no pulo e `Idle`/`Walk` no chão; no ar (`is_on_floor() == false`) o certo é `Jump`.
- **Pousar:** `CameraFeel.land(falling_speed)` afunda a **câmera** até 5 cm e a devolve em ~0,25 s. O corpo não afunda (o `CharacterBody3D` não muda). Em primeira pessoa isso continua certo; o corpo sem cabeça fica parado enquanto a visão desce 5 cm, o que é o normal.

---

## 2. O passo

### 2.1 As animações que existem (conferido, lendo o JSON do `.glb`)

`Idle` (duração 10 s, 241 quadros), `Walk` (1,0 s, 25 quadros), `Run` (0,625 s, 16 quadros), `Jump` (1,0 s), `Punch`, `Working`, `Death` e uma `ArmatureAction.002`. O `AvatarBody` usa só `Idle` e `Walk` (`IDLE_ANIMATION`, `WALK_ANIMATION`, linhas 20-21). **Não existe `Run`/`Jump` no código**, só no arquivo. **Não conferi** se `Walk` e `Run` fazem um ciclo "fechado" (pé que volta ao lugar); a duração curta (1 s e 0,625 s) sugere que sim.

Detalhe: o `play_walk` faz `loop_mode = LOOP_LINEAR` e `seek` a cada chamada (`_play_loop`), então **chamá-lo todo quadro reinicia a animação**; só se troca quando o estado muda (como o espelho já faz com `_walking`).

### 2.2 A velocidade do passo (estimativa minha, a medir)

O jogador anda a **5 m/s** (`walk_speed`) e corre a **9 m/s** (`sprint_speed`) (`player.gd:23-24`). Fiz uma conta rápida no `.glb` (cinemática direta dos ossos, sem interpolar os quadros): a altura do modelo é 5,225 unidades e o pé percorre cerca de **3,0 unidades no `Walk`** e **3,9 no `Run`**. Escalando para 1,7 m de altura: o pé anda ~1,0 m (`Walk`) e ~1,3 m (`Run`) para trás durante o apoio. Isso dá, **grosso modo, ~2 m/s no `Walk` e ~4 m/s no `Run`**. **É uma estimativa**, não uma medida: a conta foi feita fora da Godot, com 25 quadros. A calibração de verdade é um passo do plano (um script em `tools/` que mede a velocidade do pé plantado no esqueleto já ajustado a 1,7 m).

**Consequência:** casar `Walk` com 5 m/s exigiria tocá-lo ~2,5x mais rápido (parece desenho animado); casar `Run` com 5 m/s pede ~1,25x (aceitável), e com 9 m/s ~2,2x (rápido demais). Opções (decisão do dono, seção 9):
1. **Usar `Run` a partir de ~3 m/s e `Walk` abaixo disso**, com `speed_scale = velocidade / velocidade_natural` limitado (por exemplo entre 0,7 e 1,6). Aceita um leve escorregar na corrida forte.
2. **Reduzir o `walk_speed`** do jogador para algo perto de 3 a 3,5 m/s (muda o ritmo do hub; não é desta fase, só se o dono quiser).
3. **Pôr os pés no chão com IK**: não precisa em calçada plana; o estudo dos amigos citou um `Skeleton3DIK` que **não conferi** e que esta fase também não deve exigir.

**A API:** `AnimationPlayer.speed_scale` ou o argumento de velocidade de `play()` existe na Godot (suposição de que vale igual na 4.7; **não achei** nenhum uso de `speed_scale`/`playback_speed`/`AnimationTree` no repositório, então seria o primeiro). Troca suave: `play(nome, custom_blend)`.

### 2.3 O que serve igual aos amigos andando (fase 6), para fazer uma vez só em `components/avatar/`

Conferi o estudo `estudo-amigos-andando-2026-11-15.md` e o código antes de repetir. O que ele diz do avatar **bate**: `Idle` e `Walk` existem (`avatar_body.gd:20-21`), `play_idle(start)` e `play_walk(start)` existem, o osso `Head` e o `HeadTop_End` são usados em `_fit`. O que **não** vale como estava:
- ele diz que o `_process` do `FriendNpc` "só flutua", e é isso mesmo (`friend_npc.gd: _process`), mas ele **não menciona** que o `AvatarBody` não tem controle de velocidade nem `Run`/`Jump`;
- o "IK dos pés" ele mesmo não conferiu (a coordenadora também apontou);
- ele diz que o `AvatarBody` ganharia `set_walk_velocity(velocity)`. É a **mesma ideia** que proponho abaixo (confere com esta fase).

**A API única que as duas fases usam** (nova, só em `components/avatar/avatar_body.gd`):
- `set_motion(horizontal_speed: float, on_floor: bool)`: decide `Idle`, `Walk`, `Run` ou `Jump`, ajusta `speed_scale` com os números calibrados e troca com `custom_blend` (~0,15 s) para não "pular". A decisão de qual clipe tocar é **uma função pura** (testável sem cena);
- `face_towards(direction: Vector3, delta: float)` (gira o corpo suavemente com `lerp_angle`), usado tanto pelo jogador quanto pelos amigos;
- `set_first_person(on: bool)` (mostra a malha sem cabeça e põe a completa só com sombra): só o jogador usa, mas fica no mesmo arquivo porque é do corpo;
- as **constantes de calibração** (velocidade natural de `Walk` e `Run`) ficam **uma vez** no `AvatarBody`, e os amigos usam as mesmas.

O que **não** serve aos amigos: a camada do reflexo e o esconder-a-cabeça (só jogador). Os amigos têm `override_material`/`overlay_material` de holograma, que a segunda malha (sem cabeça) também precisaria respeitar se um dia se quisesse esconder a cabeça de um amigo: não é necessário agora.

---

## 3. A câmera em terceira pessoa

### 3.1 O que existe (conferido)

- Nada de `SpringArm3D` no repositório (`grep` em todos os `.gd`: não achei). A única câmera do jogador é a `Camera3D` fixa no `Head`. A câmera é movida por código em dois lugares: `CameraFeel.update` (deslocamento pequeno sobre `_camera_rest`) e `Player._slide_camera` (foco: anima `_camera.global_transform` até uma pose do mundo).
- **Fato que simplifica tudo:** `_camera_rest` é a **única âncora** da câmera. `leave_focus` volta para `_head.global_transform * _camera_rest` e `_end_focus` faz `_camera.transform = _camera_rest` (`player.gd:538, 569`). O `CameraFeel.setup(camera, rest)` recebe esse `rest` **uma vez**, no `_ready` (`player.gd:190`).

### 3.2 Como seria o braço (proposta; API do `SpringArm3D` é suposição para a 4.7)

- Um `SpringArm3D` filho do `Head` (ou de um nó pivô na altura do pescoço), com `spring_length` (~2,5 a 3 m), uma forma simples (esfera pequena) para a câmera não entrar em quina, `collision_mask = 1` (o mesmo do corpo: mundo, prédios, árvores, rochas, casa), e a `Camera3D` como filha. Quando bate, o braço encurta sozinho.
- **Alternativa** (se o `SpringArm3D` der problema com a física Jolt do projeto): um raio próprio, `PhysicsRayQueryParameters3D` (o código da luneta já faz exatamente isso em `lookout_telescope.gd: get_camera_pose`, com `RAY_START` e `CLEARANCE`), do pescoço até a posição desejada, recuando `CLEARANCE`. Dá controle total (e é testável em `check_*` sem cena). **Não conferi** o comportamento do `SpringArm3D` com Jolt; vale um spike curto antes de escolher.
- **Distância, altura e ombro (suposição, afinar em captura):** ~2,6 m atrás, ~0,4 m acima da cabeça, ~0,5 m para o lado direito (ombro). O ombro é uma decisão visual do dono (centralizado ou sobre o ombro).
- A câmera olha para o ponto de mira (o centro da tela) e **o pivô gira com o mouse e o controle** do jeito de sempre (`look_by`, `_look_with_stick`), então **o `rotate_y` do jogador e o `rotation.x` do `Head` continuam sendo o "olhar"**. Nada muda no `_unhandled_input`.

### 3.3 Dentro da casa e junto de prédios, árvores e arcos

- **Casa:** o interior mede **9 x 3 x 7 m** (`Home.ROOM_SIZE`, `home.gd:39`); o teto fica a 3 m. Com o pivô a 1,6 m, o braço de 2,6 m **cabe** em quase toda a sala, mas **bate nas paredes e no teto** ao olhar para cima. Isso é o que o `SpringArm3D`/raio faz (a casa tem colisão sólida nos móveis e nas paredes via `HomeDecor.make_box(... solid ...)`; **não conferi a camada de colisão** dessas caixas, e o projeto não tem teste que diga). A câmera chega a ficar **colada ao jogador** em corredor estreito; é o esperado. **Proposta:** dentro de casa, um braço mais curto (por exemplo 1,8 m), escolhido em `set_indoors`.
- **Cidade:** prédios, árvores e rochas têm `StaticBody3D` (o `biome_scatter` coloca um com `CylinderShape3D`; **conferi pelo estudo dos amigos e por `check_biome`**, não pelo código do espalhador) e os arcos/pórticos têm colisão própria. O braço encurta contra todos, o que é bom; o risco é a câmera **tremer** ao passar por galhos ou grades finas. Mitigação: forma de esfera, suavizar só o **encurtar rápido e esticar devagar**.
- **Hologramas dos amigos** são `StaticBody3D` na camada 1 (`friend_npc.gd: _build_collision`): o braço **encurtaria** ao passar atrás de um amigo. Se isso incomodar, os amigos podem ficar fora da máscara do braço (decisão do plano; **não conferi** o efeito).
- **O `LookRay`** (alcance de 30 m, máscara 5) hoje sai da câmera. Veja a seção 4.

### 3.4 `CameraFeel` em terceira pessoa

`CameraFeel` mexe só em **deslocamento pequeno** da câmera sobre `_camera_rest` (balanço 2,5 cm, lateral 1,2 cm, afundada 5 cm, FOV +5° correndo, "avanço" de 12 cm ao carregar a porta). **Recomendo:**
- **Balanço e afundada: desligados na terceira pessoa** (balançar uma câmera a 2,5 m do corpo só enjoa; o corpo já anda). Pelo código: `update(...)` com `active = false` zera o estado e **não mexe na câmera** (é o caminho do foco e da viagem). O `Player` só precisa passar `active = false` em terceira pessoa, **mas** isso também desliga o FOV de corrida e a "porta carregando" (`CHARGE_*`), que são úteis; então melhor um parâmetro novo `first_person` no `CameraFeel` que corta só o balanço e a afundada. **Isso muda a assinatura de `update`, que o `tests/check_camera_feel.gd` chama** (veja seção 8).
- **FOV de corrida e a porta carregando: ficam** (são FOV e movimento curto, valem nas duas).
- **O ponto delicado:** o `CameraFeel` escreve `_camera.transform = Transform3D(_rest.basis, _rest.origin + offset)`, ou seja, **assume que a câmera mora em `_rest`**. Em terceira pessoa a posição da câmera vem do braço. Opções: (a) a câmera vira filha do braço (a posição dela é `Vector3.ZERO`/o braço decide) e o `rest` passado ao `CameraFeel` é a transformação **local** dela; (b) o `Player` chama `CameraFeel.setup` de novo ao trocar de visão. A (a) mexe pouco; **suposição**: conferir o `check_camera_feel.gd` e o foco (a luneta e o espelho deslizam a câmera em coordenadas do mundo, então não são afetados).

---

## 4. O que depende de para onde a câmera olha

| Interação | De onde sai o raio/a pose hoje (conferido) | O que muda na terceira pessoa | Onde a visão deve voltar à primeira |
|---|---|---|---|
| **"E para interagir"** | `player.gd: _update_interact` usa o `LookRay` (filho da câmera). Sobe pela árvore até quem tem `interact()`. Alcance de 30 m. | O raio sairia **de trás do ombro**: dá para interagir com o que está mais longe que o corpo, ou **atrás do prédio** que o braço atravessou. **Proposta:** raio **do `Head` (olho) na direção da câmera** (o raio da câmera acha o ponto que se vê; depois um segundo raio da cabeça até lá). *Truque conhecido; suposição de que basta aqui.* | não precisa |
| **Cartão do que se olha** (`get_look_info`/`get_look_label`) | O mesmo `LookRay`, em `_update_look_target`. | Igual ao acima: o cartão e o "E" usam o mesmo raio. | não |
| **GamePortal** (olhar a porta, segurar E, entrar) | `GamePortal` usa a **área de entrada** (`body_entered`, grupo `"player"`, linhas 222-228) para saber se o jogador está perto; o olhar vem do `LookRay` via `get_hold_seconds/set_hold/interact`. `get_return_transform` posiciona o `Player` (não a câmera). | Nada na lógica. A "vinheta + anel" (`DoorCharge`) é UI de tela, igual. O `CameraFeel` "porta carregando" empurra a câmera 12 cm para a frente: funciona também. | não |
| **Luneta do mirante** | `lookout_telescope.gd: interact` → `player.focus_on(self)`; a pose vem de `get_camera_pose` (`EYEPIECE` no mundo + raio `PhysicsRayQueryParameters3D`, máscara 1). | A câmera já **desliza para uma pose do mundo** (`_slide_camera`), independente da cabeça: serve. Mas em terceira pessoa o corpo ficaria parado no mirante olhando a luneta de fora. | **Sim, voltar à primeira ao entrar no foco e restaurar a escolha ao sair** (escondendo o corpo durante o foco é o mais simples: o foco já bloqueia andar e HUD). |
| **Sentar na mesa / monitores** | `computer_desk.gd` + `desk_monitor_3d.gd: get_camera_pose` (três monitores) e `_aim_camera`; o mouse vira raio **da câmera em uso** (`camera.project_ray_origin`, linha 290-294); `get_viewport().get_camera_3d()`. | O **foco** já governa a câmera por completo (`focus_on` → `_focus_screen`, `_is_movement_locked`). A pose é do mundo. Só falta decidir o corpo (some, ou "senta"). | **Sim**, voltar à primeira (ou esconder o corpo) durante o foco e devolver depois. |
| **Telas 3D (`Screen3D`)** | `screen_3d.gd: get_camera_pose` + `_to_viewport_event` com `camera.project_ray_*` da câmera ativa (linhas 210-213). | Sem mudança: usa `get_viewport().get_camera_3d()`, que continua sendo a câmera atual (a do braço). | Mesma regra do foco. |
| **Espelho (provador)** | `home_mirror.gd: interact` → `player.focus_on(self)`; `get_camera_pose`, e o corpo do **espelho** se põe no `FITTING_SPOT`. | A pose é do mundo; o espelho usa `player.get_viewport().get_camera_3d().global_position` como "olho" para calcular o reflexo (`_process`, linha 102/111). **Em terceira pessoa o "olho" passa a ser a câmera atrás do ombro**: o reflexo mostraria o ponto de vista da câmera de trás, não o do rosto (e `_should_draw` conta a distância da câmera ao vidro). Na prática: dentro de casa **não dá para usar o espelho em terceira pessoa sem ajuste**. | **Sim, recomendo forçar a primeira pessoa dentro de casa** (veja 3.3 e seção 9) ou, no mínimo, usar a posição do `Head`, e não da câmera, como "olho" do espelho. |
| **Portas de viagem** (`TravelDoor`) | `travel_door.gd: get_look_info`, `interact(player)` → `player.travel_to(destination)`. | Nenhum raio próprio. | não |
| **Metrô** (`TransitStop`) | Área com `body_entered` do grupo `"player"` (linhas 99-108); abre o painel. | Nenhuma. | não |
| **Placas de bairro** (`DistrictSign._process`) | Gira em Y para acompanhar a **direção** da câmera (`get_viewport().get_camera_3d()`, `-basis.z`, linha 97-102). | Funciona igual (usa a câmera atual). | não |
| **Bússola, minimapa, mapa (M)** | `-player.global_basis.z` (`compass.gd:43`, `map_view.gd:68`). | Funciona se o `Player` continuar girando com a câmera (por isso a proposta 1.2). | não |
| **Clima/atmosfera do bioma** | `district_weather.gd:180` e `BiomeAtmosphere` recebem o nó do jogador (posição). | A **posição do jogador**, não da câmera: igual. (Chuva em volta da câmera: **não conferi** se algum efeito segue a *câmera* e não o *jogador*; vale uma leitura no plano.) | não |
| **Janela da casa** (`WindowView`) | Tem a **própria** câmera, que tira retrato do mundo (`window_view.gd:247`). | Nada, **mas** o corpo na camada 20 some do retrato (que esconde a 20): é o que se quer (1.5). | não |

---

## 5. Controles e dados

**Conferido no `project.godot` (seção `[input]`, linhas 54-176):**

| Ação | Teclado | Controle |
|---|---|---|
| `move_*` | W A S D | analógico esquerdo |
| `jump` | Espaço | botão 0 (A) |
| `sprint` | Shift | botão 7 (L3) |
| `interact` | E | botão 2 (X) |
| `search_game` | Tab | botão 3 (Y) |
| `open_map` | M | botão 4 (View) |
| `release_mouse` | Esc | botão 6 (Menu) |
| `ui_cancel` | Esc | botão 1 (B) |
| `tab_prev` / `tab_next` | — | botões 9 / 10 (LB / RB) |
| `toggle_fullscreen` | F11 | — |
| `advance_time` | F8 | — |
| `look_*` | — | analógico direito (eixos 2 e 3) |

**Livres (conferido pela lista acima e por `grep` de `KEY_*` em `autoload`, `ui`, `player`, `components`, `worlds`, `addons/debug_menu`):**
- **Teclado:** `V` (de "vista") e `C`. O `F3` é do `debug_menu` (addon). O `KEY_V`/`KEY_C` que apareceram são só a **tabela de teclas do compositor** (`app_compositor.gd:42-43`), que repassa teclas ao app sentado na mesa, **não** é uma ação do hub. Na mesa o `DeskMonitor3D._input` consome as teclas (`set_input_as_handled`), então a tecla nova não vaza.
- **Controle:** o **clique do analógico direito (R3, botão 8 da Godot)**. É o par natural do L3 do `sprint`. O botão 5 (Guide) o sistema costuma pegar. O direcional (11-14) só é usado nos menus (`ui_*`), então também está livre no jogo, mas é pior (fácil de apertar sem querer). **Suposição:** o índice 8 = R3 segue a convenção da Godot (`JOY_BUTTON_RIGHT_STICK`); **não o conferi na documentação local**.
- **Proposta:** ação nova `toggle_camera` (`V` e R3), adicionada ao `project.godot` **na trilha A** (a trilha B não mexe nesse arquivo).

**Dicas de tecla:** `InputDevice.HINTS` (`input_device.gd:27-41`) é o dicionário `nome → [teclado, controle]`: ganha `"view": [["V"], ["R3"]]` (o nome do botão do analógico direito é "R3"; o `sprint` já escreve "L3"). `KeyHint.create("view")` troca sozinho com o aparelho.

**O menu:**
- `ui/settings_view.gd`: a aba **Controles** tem a lista `CONTROL_ROWS` (linhas 38-49, vira uma linha `[["V"], ["R3"]], "primeira / terceira pessoa"`) e a seção **CÂMERA** com o "Balanço da câmera" (um `CheckButton`, linhas 435-443). A opção nova ("Visão: primeira / terceira pessoa", e talvez "Ombro") entra ali, no mesmo padrão (`_row` + `CheckButton` + `_refreshing`, e a atualização em `_refresh` perto da linha 630).
- O `KEYBOARD_ONLY_TIP` (linha 51) só diz F8/F11/L3: não precisa mudar.

**O `config.cfg`:** o padrão já existe: `AppConfig.get_camera_motion()`/`set_camera_motion(on)` usa `_set_option("controls", "camera_motion", on)`, e quem escuta recebe `settings_changed(section, key)` (como o `CameraFeel` e o `Player`). **Proposta:** `[controls] view = "first"` (ou `"third"`), com `get_view()`/`set_view(mode)` validando contra a lista, como `get_quality()`. **Não achei** um lugar no código que já guarde "a visão". Mudança em `AppConfig` é **dado salvo**, então a subetapa é **grande** pelo AGENTS.md.

**O cartão de controles da primeira vez:** `ui/controls_hint.gd` (`KEYS`, linhas 31-38) tem 6 dicas (andar, correr, usar, buscar, mapa, menu), 15 s, e grava "visto" (`AppConfig.set_seen_controls_hint`). Entrar com `["view", "visão"]` deixa o cartão com 7 itens: **a faixa fica mais larga** (cabe em telas largas; a verificação visual é uma captura em janela pequena). Quem já viu o cartão não o vê de novo: o menu de Controles fica como o lugar fixo da dica.

---

## 6. Estado, quedas e coisas pequenas que a troca precisa tratar

*(conferido na leitura; a maioria é proposta)*
- **A troca da visão** (`V`): bloqueada na abertura, em viagem, com painel aberto e durante o foco (mesmas regras de `_can_interact()` e `_is_movement_locked()`). **Dentro de casa**, ver a decisão da seção 9.
- **Esc/pausa:** `PauseMenu` abre pelo `release_mouse`; não depende da câmera.
- **O jogo abrindo** (`GameLauncher.game_started`): `leave_focus(true)` já existe; em terceira pessoa o hub minimiza igual.
- **A viagem rápida** (`travel_to` → `teleport_to`): o `Player` teletransporta e zera `_head.rotation.x`; o corpo (filho) vai junto. O **braço** deve ser reposto na hora (sem "voar" da posição antiga durante o fade).
- **`player.gd: teleport_to`** também gira o `Player`: o corpo precisa **copiar o giro na hora** (e não girar suavemente no teleporte).
- **A viagem** e a **abertura** (`in_intro`) hoje desligam o `_physics_process`; o corpo e o braço também devem ficar parados.

---

## 7. O custo

**Hoje não há corpo do jogador no mundo**, só o `ReflectionBody` do espelho (desligado fora de casa). O que a fase acrescenta, **sempre** ligado:
- 1 `Skeleton3D` e 1 `AnimationPlayer` a mais (o `animated_human` tem 51 nós, **~1.600 triângulos** segundo o `LICENSE.txt`, 4.733 vértices; 698 KB de `.glb`);
- na versão com duas malhas, **a mesma malha desenhada 1 vez para a câmera + 1 vez para a sombra** (sombra do sol com `directional_shadow_max_distance` 120 m na Alta e 70 m na Leve, `graphics_quality.gd:22-23, 72`): ~3.200 triângulos por quadro e mais **uma passada de sombra**;
- o `SpringArm3D` (ou o raio): 1 consulta de física por quadro.

**Número:** **não medi** (a Godot ficou fechada). A ordem de grandeza é pequena perto do resto da cidade, mas **o plano mede no desktop (Ryzen 5 5600 + RTX 4070, Alta)**, como manda o AGENTS.md; o notebook só compara antes e depois.

**O que desligar na qualidade Leve (proposta, a medir):**
- **a sombra do corpo** (`cast_shadow` desligado): a Leve já reduz a sombra do sol (70 m, atlas 2048). É a primeira coisa a sair;
- **a animação** do corpo em **primeira pessoa** quando ele não aparece (câmera olhando para cima/frente): não conferi como cortar a animação só então; **suposição**: `AnimationPlayer.active = false` (o espelho já usa `get_animation_player().active = on`, `home_mirror.gd:230`);
- **uma cópia só da malha** (a sem cabeça) na primeira pessoa quando a sombra é desligada.

A sombra do corpo é **o único** custo que o dono "vê" no desempenho; o corpo em si é barato.

---

## 8. Os testes (`tests/check_*.gd`)

**Conferido por `grep`** nos testes que citam `player`, `Head`, `LookRay`, `CameraFeel`, `focus_on` ou a camada do reflexo. Os `tests/check_*.gd` que **dependem de coisas que a fase muda** (e por quê):

| Teste | Por que pode quebrar |
|---|---|
| `check_camera_feel.gd` | Lê `player._camera_rest.origin.y` (linha 110), `player._camera_feel` e `Head/Camera3D`; chama `update(...)` direto. **Mudar a assinatura de `CameraFeel.update` ou a âncora da câmera quebra.** Também confere "em foco, a câmera não é mexida". |
| `check_mirror.gd`, `check_avatar_panel.gd`, `check_home.gd` | Conferem que a câmera do jogador **não** vê a camada 19, que a do espelho **não** vê a camada 1, que o sol **não** ilumina as camadas 19/20, que o `ReflectionBody` tem **só** malhas na camada do reflexo (`check_home.gd:75`) e que ele **segue o jogador** (`check_avatar_panel.gd:129`). **Tocar em camadas ou no `ReflectionBody` (1.5) é o que mais pode quebrar.** |
| `check_avatar.gd` | Fixa `REFLECTION_LAYER == 19`, o `_fit`, as zonas por osso e a altura (`HeadTop_End`). **Uma segunda malha mudaria a contagem de malhas** que ele confere; ajustar, não apagar. |
| `check_look_card.gd`, `check_interact.gd`, `check_gamepad.gd`, `check_first_run.gd`, `check_first_time.gd`, `check_door_charge.gd`, `check_screen_3d.gd` | Giram `player.get_node("Head").rotation.x` e/ou usam `Head/Camera3D` (a posição do `LookRay` e da câmera). **Se a câmera/raio mudar de lugar em terceira pessoa, só quebram se o teste rodar com a visão = terceira**; com a primeira como padrão, **devem continuar passando** (o padrão da escolha é a primeira, por isso a decisão 1 da seção 9). |
| `check_footsteps.gd` | Usa o `Player`; só quebra se o `_update_footsteps` mudar de lugar. |
| `check_lookout.gd`, `check_desk_monitors.gd`, `check_pause_menu.gd`, `check_input_device.gd` | Tocam `focus_on`/`HINTS`/o menu. Quebram só se `HINTS` ou `CONTROL_ROWS` ganharem itens que o teste confere por **tamanho** (não li esses números; **suposição**). |
| `check_holograms.gd`, `check_friends_wall.gd` | Usam o `AvatarBody` dos amigos: quebram só se a API do corpo mudar (a proposta mantém `play_idle`/`play_walk`). |

**Testes novos (propostos):**
- `check_avatar_motion.gd`: a escolha de clipe e de `speed_scale` por velocidade, no chão e no ar (função pura); a calibração (a velocidade natural dentro de uma faixa); o corpo não troca de clipe a cada quadro.
- `check_first_person_body.gd`: o corpo existe no jogador; a malha sem cabeça aparece em primeira pessoa e a completa só faz sombra; em terceira, o inverso; a câmera do jogador não vê o corpo do espelho; a camada do corpo muda ao entrar e sair de casa.
- `check_third_person_camera.gd`: o braço encurta contra uma parede; não atravessa o teto da casa; volta ao tamanho; no foco (luneta, mesa, espelho) a visão volta à primeira e é restaurada ao sair; `teleport_to` não deixa a câmera "voar".
- `check_view_setting.gd` (ou dentro de `check_pause_menu`/`check_camera_feel`): `AppConfig.get_view`/`set_view`, valor inválido volta ao padrão, e o `settings_changed` chega; o menu e o cartão têm a dica nova.
- Todos no formato de `tests/README.md` (não li o arquivo: **suposição** de que o formato é o dos `check_*.gd` existentes).

---

## 9. Decisões que ficam para o dono (linguagem simples, com sugestão)

1. **Qual visão é a padrão ao abrir o hub?** *Sugestão: primeira pessoa* (é o que existe hoje, e todos os testes e o jeito de jogar continuam iguais). A terceira é uma opção que fica guardada no `config.cfg`.
2. **Dentro de casa pode usar a terceira pessoa?** A sala é pequena (9 x 3 x 7 m), e o espelho só funciona certo com a câmera na altura dos olhos. *Sugestão: em casa a visão volta sozinha para a primeira, e volta à terceira ao sair.* Se quiser a terceira em casa, é mais trabalho (braço curto, espelho olhando pela cabeça).
3. **A câmera fica atrás da cabeça ou "sobre o ombro"?** *Sugestão: sobre o ombro direito, um pouco acima* (dá melhor noção do que está à frente); é só um valor.
4. **Que passo o corpo faz ao andar e ao correr?** O jogador é rápido (5 m/s andando, 9 correndo) e a animação de andar do modelo é mais lenta. *Sugestão: andar usa a animação "Run" em velocidade reduzida e correr usa "Run" mais acelerada; aceitamos um leve escorregar na corrida forte.* Alternativa: deixar o jogador mais lento (não é desta fase).
5. **Os braços em primeira pessoa:** só aparecem os braços "caídos" do modelo. *Sugestão: aceitar assim (o pedido é "ver o corpo olhando para baixo")*; braços "na frente" pedem uma animação nova (Blender) e ficam para depois.
6. **Os amigos andando (fase 6) usam o mesmo passo?** *Sugestão: sim, e a calibração do passo é feita uma vez, nesta fase ou na 6, o que vier primeiro.* Se as duas fases vão em paralelo, **uma delas** é dona do `avatar_body.gd`; combine qual.
7. **Na terceira pessoa, o corpo gira com a câmera ou com o movimento?** *Sugestão: com o movimento* (o corpo vira para onde anda; parado, olha para onde a câmera olha). É o mais natural, e a bússola e as portas continuam iguais.
8. **O espelho:** *Sugestão: não mexer no espelho agora* e cuidar só de o corpo real não aparecer em dobro (1.5). Se aparecer, mudar na subetapa seguinte.

---

## 10. A menor versão que já dá para testar

**"A tecla troca de visão e eu me vejo andar":**
1. `toggle_camera` (`V`; R3 no controle), com a escolha em memória (ainda **sem** `config.cfg`).
2. Um `AvatarBody` filho do `Player` com as cores do avatar, **corpo inteiro** (sem esconder a cabeça ainda), visível **só em terceira pessoa**; em primeira fica escondido (como hoje).
3. Animação `Idle` parado e `Walk`/`Run` conforme a velocidade, com `speed_scale` casado **por uma conta simples** (sem calibrar fino), e o corpo girando para onde anda.
4. Câmera em terceira pessoa **com braço** (`SpringArm3D` ou raio) para trás do corpo, com o `CameraFeel` sem balanço.
5. O foco (mesa, luneta, telas, espelho) e a **casa** forçam a primeira pessoa.
6. **Fora desta versão:** corpo em primeira pessoa, sem cabeça, sombra inteira, `config.cfg`, menu, cartão, qualidade Leve.

**Teste manual:** abrir o hub; apertar `V` (ou R3); ver o avatar por trás andando pela rua sem a câmera entrar em prédio; chegar a uma árvore e ver o braço encurtar; entrar em casa e ver a primeira pessoa voltar; sentar na mesa; apertar `V` de novo; abrir um jogo e voltar.

---

## 11. Subetapas cortadas para duas trilhas em paralelo

**Regra:** arquivos **diferentes** por trilha. A trilha B **não** toca `.tres`, `.tscn`, `city.gd` nem `project.godot`. O número é provisório (o plano define).

**Divisão de arquivos**

| Trilha | Mexe | Só lê |
|---|---|---|
| **A (principal)** | `player/player.gd`, `player/player.tscn` (se o braço precisar de nó na cena; senão, tudo por código), `player/camera_feel.gd`, `project.godot` (ação `toggle_camera`), `autoload/app_config.gd`, `autoload/input_device.gd`, `ui/settings_view.gd`, `ui/controls_hint.gd`, `worlds/home/home.gd` e `home_mirror.gd` (camada e espelho) | `components/avatar/` |
| **B (paralela)** | `components/avatar/avatar_body.gd` (a API do passo e a cópia sem cabeça), os `tests/check_avatar_motion.gd` e o `check_avatar.gd`, `tools/` (script de calibração do passo) | `player/player.gd` |

**Contrato entre as trilhas** (a B entrega, a A usa): em `AvatarBody`: `set_motion(horizontal_speed: float, on_floor: bool)`, `face_towards(direction: Vector3, delta: float)`, `set_first_person(on: bool)`, `set_render_layers(layers)` (já existe), `play_idle/play_walk` (continuam). Nomes são a proposta; a A só os chama.

| # | Trilha | Subetapa | Tamanho | Modelo e esforço |
|---|---|---|---|---|
| 8.0 | A | **Plano da fase** (`docs/plans/`) e o spike do braço (`SpringArm3D` x raio próprio com Jolt) e da luz de casa com o corpo (1.5), com capturas | Grande | Opus, high (sessão nova, modo plano) |
| 8.1 | B | **O passo, uma vez só em `components/avatar/`:** `set_motion` (escolha pura de `Idle`/`Walk`/`Run`/`Jump` e `speed_scale`), `face_towards`, `custom_blend`, e o script de calibração da velocidade natural de `Walk`/`Run` em `tools/` (medida no esqueleto a 1,7 m); `tests/check_avatar_motion.gd` | Grande (mexe em contrato que a fase 6 também usa) | Opus (ou Sonnet na parte do teste), medium; revisão do Opus antes do merge |
| 8.2 | A | **A tecla e a escolha:** ação `toggle_camera` (`V`/R3), a dica `view` em `InputDevice.HINTS`, o estado da visão no `Player`; **ainda sem** `config.cfg` | Pequena | Sonnet, medium |
| 8.3 | A | **O corpo do jogador (terceira pessoa):** o `AvatarBody` filho do `Player`, cores do avatar, ouvindo `settings_changed[avatar]`; gira para onde anda; chama a API da 8.1 | Grande (integração) | Opus, high |
| 8.4 | A | **A câmera em terceira pessoa:** braço com colisão, distância/altura/ombro, `CameraFeel` sem balanço, `teleport_to`, foco que volta à primeira e restaura; casa força a primeira; o raio do olhar sai da cabeça | Grande (câmera, contrato de foco) | Opus, high |
| 8.5 | B | **A cópia sem cabeça e a sombra inteira:** a malha sem cabeça (em código, ou script do Blender em `tools/blender/` se o dono preferir), `set_first_person`, sombra só com a completa; `check_avatar.gd` ajustado | Grande (geometria) | Opus, high; **começa depois da 8.1** (mesmo arquivo) |
| 8.6 | A | **O corpo em primeira pessoa:** liga a 8.5 no `Player`, posição da câmera junto ao pescoço, olhar para baixo, camadas de casa (1.5) e o `ReflectionBody` sem duplicar; captura com o espelho | Grande (camadas e luz) | Opus, high; **revisão de risco por um segundo Opus (só leitura)** |
| 8.7 | A | **Dados e interface:** `[controls] view` no `config.cfg` (`get_view`/`set_view`), opção no menu (aba Controles), `CONTROL_ROWS`, o cartão da primeira vez | Grande (dado salvo) | Sonnet, medium |
| 8.8 | B | **O custo e a qualidade Leve:** medida no desktop (Alta, com e sem corpo), o que desligar na Leve (sombra do corpo, animação parada), `GraphicsQuality` | Pequena a média | Sonnet, medium (a medida é do desktop; sem ele, fica pendente) |
| 8.9 | A | **Testes novos e a bateria completa**, atualização do plano, da ROADMAP e do `Início.md` | Pequena (docs) | Haiku, low (texto) + Sonnet (rodar e relatar a bateria) |

**Ordem:** 8.0 → (8.1 ‖ 8.2) → 8.3 → 8.4 → (8.5 ‖ nada na A) → 8.6 → 8.7 → 8.8 → 8.9. A 8.1 e a 8.2 rodam em paralelo (arquivos diferentes). A 8.5 (B) só começa depois da 8.1 (B) e pode andar junto da 8.4 (A). A **bateria completa** roda **uma vez por merge**, feita pela coordenadora.

**Primeiro marco que o dono já vê** (8.1 + 8.2 + 8.3 + 8.4): a tecla, o corpo, o passo e a câmera com braço, que é a "menor versão" da seção 10.

---

## 12. Resumo: conferido x suposição

| Tópico | Conferido (arquivo e função) | Suposição |
|---|---|---|
| O jogador, a cabeça (1,6 m), o `LookRay` na câmera, o giro | `player.tscn`, `player.gd: look_by, _look_with_stick, _update_look_target` | — |
| O corpo e suas animações | `avatar_body.gd`; o JSON do `animated_human.glb` (1 malha, 4.733 vértices, `Idle`/`Walk`/`Run`/`Jump`...) | Que `Walk` e `Run` são ciclos "fechados" |
| A velocidade natural do passo | Cinemática direta dos ossos do `.glb` (estimativa fora da Godot) | ~2 m/s (`Walk`) e ~4 m/s (`Run`): **a medir** |
| Esconder a cabeça (A/B/C/D) | A malha é uma só; o `check_avatar.gd` já lê pesos por osso | `SHADOWS_ONLY` na 4.7; `set_bone_pose_scale`; `BONE_*` no shader |
| Camada 19/20, sol e casa | `avatar_body.gd`, `home.gd: _put_on_interior_layer, _build_sun`, `home_mirror.gd`, `check_home.gd` | O corpo na camada 1 em casa ser iluminado pelo sol (risco), e a regra do corte de sombra pelo `light_cull_mask` |
| `CameraFeel` e `_camera_rest` | `camera_feel.gd`, `player.gd: _ready, leave_focus, _end_focus, _slide_camera`, `check_camera_feel.gd` | Que a câmera filha do braço resolve o `rest` |
| Raios e foco por interação | `player.gd`, `game_portal.gd`, `lookout_telescope.gd`, `desk_monitor_3d.gd`, `screen_3d.gd`, `home_mirror.gd`, `district_sign.gd`, `travel_door.gd`, `transit_stop.gd` | Raio da cabeça "até o ponto da câmera" basta |
| Teclas e botões livres | `project.godot` (`[input]`), `grep KEY_*`, `input_device.gd` | R3 = botão 8; o enum da Godot |
| Menu, `config.cfg`, cartão | `settings_view.gd` (`CONTROL_ROWS`, a seção CÂMERA), `app_config.gd` (`get_camera_motion`), `controls_hint.gd` (`KEYS`) | Largura do cartão com 7 itens |
| `SpringArm3D` com Jolt | Não achei nenhum no repositório | Funciona e serve; um spike decide |
| Custo | `graphics_quality.gd` (sombra), `LICENSE.txt` (triângulos) | Os números: **nada foi medido** |
| Testes | `grep` nos `tests/*.gd` (nomes e linhas acima) | Que `HINTS`/`CONTROL_ROWS` não são conferidos por tamanho |
| O estudo dos amigos | Li o texto e o `avatar_body.gd`/`friend_npc.gd`: o que ele diz do avatar bate | O resto do estudo dele (custos, IK) não foi conferido |

---

## 13. Entrega (para a coordenadora)

- **Hash-base:** `bcd4cfe` (o `33df095` é ancestral: `git merge-base --is-ancestor 33df095 HEAD` passou).
- **Hash do commit:** informado na mensagem de entrega (um arquivo não pode conter o próprio hash).
- **Arquivo novo:** só `docs/design/estudo-primeira-terceira-pessoa-2026-11-15.md`.
- **Como conferi:** leitura direta dos arquivos da tarefa, `grep`/`rg` por `camera`, `get_camera_3d`, `focus_on`, `KEY_*`, `SpringArm`, `speed_scale`, camadas; leitura do JSON do `animated_human.glb` com um script Python **só de leitura** (animações, durações, nós, uma malha de 4.733 vértices e a estimativa do passo). **Não abri a Godot** (nem testes, nem capturas).
- **Pendências:** medir a velocidade natural do passo (script em `tools/`, 8.1); spike do braço com Jolt e da luz de casa com o corpo (8.0); o custo no desktop (8.8); as decisões do dono (seção 9).
- **Próximo passo:** sessão **nova** do Opus, em modo plano (high), para escrever `docs/plans/fase-N.md` a partir deste estudo, depois da resposta do dono à seção 9. A trilha B (8.1) só pode começar depois do plano aprovado.
