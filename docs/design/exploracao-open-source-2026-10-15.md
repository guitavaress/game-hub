# Exploração: V-Sekai e outros projetos abertos (2026-10-15)

Pergunta do dono: **o que o V-Sekai e outros projetos open-source já resolveram daquilo que o ROADMAP quer fazer, e o que dá para trazer para o hub?**

Este documento é só exploração: nada foi baixado nem implementado. Tudo o que for adotado segue as regras do CLAUDE.md (licença permissiva, pedir permissão antes de baixar, spike numa branch, ponto único no projeto). Complementa a [avaliação de addons de 2026-10-13](addons-2026-10-13.md), que já cobriu Sky3D, Terrain3D, Debug Menu, GodotSteam e outros. Esses não se repetem aqui.

## Resumo em 6 linhas

1. **O V-Sekai é uma plataforma social de VR feita na Godot** (MIT). A maior parte do trabalho de avatar dele (IK, molas de cabelo e roupa, retarget) **já entrou na Godot oficial** (4.4 a 4.6). Dá para usar sem baixar nada.
2. **A ideia mais valiosa dele é de segurança:** conteúdo de usuário só é carregado depois de passar por uma **lista de tipos de nó permitidos**. Isso afeta direto a **Fase 18**, porque um `.tres` pode trazer código escondido.
3. **Avatar próprio:** o **godot-vrm** (MIT, do V-Sekai) abre avatares `.vrm` (os do VRoid Studio, por exemplo). Combina com o `AvatarSpec` da Fase 13 e com a V4.
4. **V4 ao vivo sem servidor próprio:** GodotSteam (lobbies e relay da Steam) + **netfox** (MIT, movimento suave) + **TwoVoIP** (MIT, voz com Opus). O V-Sekai usa servidor próprio (Uro, em Elixir), o que é pesado demais para nós.
5. **Fase 14.2:** ninguém fez "compositor Wayland dentro da Godot 4" de forma reaproveitável. O **Simula** (MIT, Godot 3 + wlroots) é o parente mais próximo e serve de referência de ideias (foco, teclado, tamanho das janelas).
6. **Produto parecido:** o **BOXROOM** (comercial, 2026) põe a biblioteca Steam como caixas num quarto. Confirma a ideia e mostra o diferencial do hub: cidade, bairros e amigos.

---

## 1. O V-Sekai

**O que é:** "o primeiro VR social totalmente aberto na Godot". Três partes: o jogo ([v-sekai-game](https://github.com/V-Sekai/v-sekai-game), MIT, ativo em 2026), o editor de mapas (um fork da Godot) e o servidor ([uro](https://github.com/V-Sekai/uro), Elixir). O próprio README avisa que é experimental e que **não recomenda hospedar instâncias públicas**.

**Por que não dá para "usar o V-Sekai" inteiro:** ele precisa de uma **Godot modificada** (fork), é feito para VR e o servidor é outro mundo (Elixir, banco, contas). O hub usa a Godot 4.7.2 oficial e roda no monitor. Então o caminho é **pegar peças e ideias**, não a base.

### 1.1 O que já virou Godot oficial (custo zero)

Vários membros do V-Sekai trabalham na própria Godot. O resultado entrou no motor, e o hub já tem tudo isso na 4.7.2:

| Nó da Godot | Desde | Uso no hub |
|---|---|---|
| `LookAtModifier3D` | 4.4 | Os hologramas dos amigos e o avatar no espelho **viram a cabeça para você** quando você chega perto. Toque pequeno, efeito grande. |
| `RetargetModifier3D` + `BoneMap` | 4.4 | Usar animações de outro pacote (ex.: a Universal Animation Library, seção 4) no `animated_human.glb` da Quaternius. |
| `SpringBoneSimulator3D` | 4.5 | Cabelo, cachecol e roupa balançando no avatar, sem física pesada. |
| `TwoBoneIK3D` e outros IK | 4.6 | **Pés no chão na subida da montanha** (Fase 15) e na escada; a mão encostando na porta ao entrar. |

O [many_bone_ik](https://github.com/V-Sekai/many_bone_ik) e o [renik](https://github.com/V-Sekai/renik) do V-Sekai são a origem disso. **Não precisam ser baixados.** O [artigo oficial](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/) explica os nós de IK.

### 1.2 Peças do V-Sekai que servem

| Peça | Licença | Ajuda em | O que fazer |
|---|---|---|---|
| **Validador de conteúdo** (`vsk_map_validator.gd`, `vsk_avatar_validator.gd`) e `background_loader` com lista de permitidos | MIT | **Fase 18**, V6 | Copiar a **ideia** (veja a seção 2). A lista de nós permitidos deles é um bom ponto de partida. |
| [godot-vrm](https://github.com/V-Sekai/godot-vrm) (importa `.vrm` e o shader MToon) | MIT | Fase 13 (avatar), V4, Fase 18 | Spike: carregar um `.vrm` em tempo de execução e pôr no espelho. Seção 3. |
| [canvas_plane](https://github.com/V-Sekai/canvas_plane) (UI em 3D) | MIT | já temos | O nosso `Screen3D` faz o mesmo. Só vale olhar como eles repassam o mouse, se aparecer bug. |
| [lasso](https://github.com/V-Sekai-archive/lasso) (escolher o objeto mesmo com mira ruim) | MIT | Fase 12 (controle), Fase 14.2 (telões) | Só a **ideia**: em vez de um raio fino, escolher o objeto interativo mais perto do centro **dentro de um cone**. Com o controle Xbox, mirar num telão ou numa porta fica bem mais fácil. É um módulo C++, então seria reescrito em GDScript. |
| `fade_manager`, `navigation_controller` (pilha de menus) | MIT | já temos | O hub já tem fade e menus; nada a trazer. |
| `extended_kinematic_body` (subir degraus e rampas) | MIT | Fase 15 | Olhar a ideia se o jogador travar nos morros. |
| [godot-speech](https://github.com/V-Sekai/godot-speech) (voz) | MIT | V4 | **Arquivado.** Use o TwoVoIP (seção 5). |
| `uro` (servidor) e `network_manager` | MIT | V4 ao vivo | Pesado demais (servidor próprio, contas). Seção 5 tem um caminho mais barato. |
| [godot-whisper](https://github.com/appsinacup/godot-whisper) (voz → texto, local) | MIT | Horizonte | "Abrir Balatro" falando com a busca. Modelo grande, só como curiosidade. |
| xr_vignette, sar1_vr_manager, xr-grid | MIT/Apache | — | Só fazem sentido com óculos de VR. Fora do roadmap. |

---

## 2. Achado importante para a Fase 18: `.tres` do usuário pode rodar código

A Fase 18 prevê "uma pasta de perfis do usuário em `user://` (bairros, biomas e temas de casa), lida junto com os do projeto". Se esses perfis forem `.tres` carregados com `load()`, **um perfil baixado da internet pode trazer um script embutido**, e a Godot executa esse script ao carregar. Na V6 (trocar perfis entre usuários), isso vira uma porta para código malicioso.

O V-Sekai resolve isso com duas camadas, e o hub pode copiar a ideia:

1. **Carregar com filtro:** antes de usar, o arquivo é lido como texto e recusado se citar `Script`, `GDScript` ou qualquer recurso fora de uma lista de permitidos. Existe um addon pronto para isso, o [godot-safe-resource-loader](https://github.com/derkork/godot-safe-resource-loader) (MIT, 2026). Outra saída é usar **JSON ou `ConfigFile`** para os perfis do usuário, que não executam nada.
2. **Validar o conteúdo:** mesmo sem script, só aceitar tipos esperados (cores, números, caminhos dentro de uma pasta). Para cenas de usuário (enfeites, V6), uma **lista de tipos de nó permitidos**, como a do `vsk_map_validator.gd`.

Para o Horizonte (enfeites com comportamento feitos pela comunidade): o [godot-sandbox](https://github.com/libriscv/godot-sandbox) (BSD-3, muito ativo) roda código de terceiros numa caixa fechada (RISC-V). É o caminho que projetos de conteúdo de usuário estão seguindo.

**Sugestão:** escrever isso no plano da Fase 18 quando ela começar ("perfis do usuário nunca passam por `load()` direto").

---

## 3. Avatar: VRM

**O que é:** VRM é o formato aberto de avatar humanoide usado por VRChat, cluster, VSeeFace e outros. O [VRoid Studio](https://vroid.com/en/studio) (grátis) cria um avatar com rosto, cabelo e roupa em minutos.

**Por que combina:** a Fase 13 criou o `AvatarSpec` justamente como "o formato que a V4 vai trocar". Hoje ele é o boneco da Quaternius com cores. Um campo "arquivo `.vrm`" deixaria a pessoa trazer o **próprio rosto**, que é o espírito do PlayStation Home.

**Custo e riscos:**
- O godot-vrm é MIT, mas cada **modelo** `.vrm` tem a própria licença. Nenhum avatar de terceiros entra no repositório: o `.vrm` fica em `user://`.
- O shader MToon (visual de anime) pesa mais que o material atual. A medida é na Alta, no desktop.
- Carregar um `.vrm` **em tempo de execução** (fora do editor) precisa ser confirmado no spike: o addon é feito principalmente para importar no editor.
- Avatar de outra pessoa (V4) é conteúdo não confiável: passa pelo mesmo validador da seção 2.

**Avatares CC0 para testar:** o projeto **100Avatars** (Polygonal Mind) publicou centenas de avatares em VRM. A licença indicada é CC0, a conferir ao pedir permissão.

**Onde:** um spike depois da Fase 14, ou dentro da Fase 17/V4.

---

## 4. Por fase do ROADMAP

### Fase 14, parte 2: janelas no mundo

| Projeto | Licença | O que já resolveu | Uso |
|---|---|---|---|
| [Simula](https://github.com/SimulaVR/Simula) | MIT | Desktop Linux em VR **rodando na Godot** (Godot 3 + wlroots, código em Haskell). Janelas como painéis 3D, foco pelo olhar, teclado preso à janela olhada, Xwayland. | Referência de **ideias** de interação: quando o teclado vai para a janela, como redimensionar, como lidar com popups. O código não serve direto (outra linguagem e Godot 3). |
| [Stardust XR](https://github.com/StardustXR/server) | servidor GPL-2.0; [flatland](https://github.com/StardustXR/flatland) MIT | Compositor XR em Rust. | O servidor é GPL: **só ideias**, como no Waylandcraft. O flatland (MIT) mostra como transformar janelas 2D em painéis. |
| Waylandcraft | GPL-3.0 | A referência do dono. | Já é regra: só ideias. |

A pesquisa não achou nenhuma GDExtension pública que já faça "Smithay dentro da Godot 4". O caminho da Fase 14 (extensão própria em `native/compositor/`) continua sendo o certo.

### Fases 15 e 16: biomas

Terrain3D e Sky3D já foram avaliados ([addons](addons-2026-10-13.md)). Além deles:

- **IK dos pés** (`TwoBoneIK3D`, seção 1.1): o avatar e os hologramas não "flutuam" na encosta.
- **Assets CC0** para a montanha e os outros biomas: seção 6.

### Fase 17 e V4: visitar e ver os amigos

A Fase 17 (visitar a cidade gerada da biblioteca pública de um amigo) **não precisa de nada novo**: é a Steam Web API que o hub já usa.

Para a **V4 ao vivo** (Horizonte), o V-Sekai mostra o caminho caro: servidor próprio, contas, banco. Um caminho mais barato, que usa o que os amigos já têm (a Steam):

| Peça | Licença | Para quê |
|---|---|---|
| GodotSteam (agora no [Codeberg](https://codeberg.org/godotsteam/godotsteam)) | MIT | Lobby entre amigos da Steam e conexão pelo **relay da Steam**, sem servidor nosso. Já está na avaliação de addons, com a ressalva de rodar como app da Steam (app ID próprio para distribuir). |
| [netfox](https://github.com/foxssake/netfox) | MIT | Movimento suave dos outros jogadores (interpolação, relógio comum). Tem o **noray** para conexão direta sem a Steam. |
| [TwoVoIP](https://github.com/goatchurchprime/two-voip-godot-4) | MIT | Voz com Opus e redução de ruído (RNNoise), GDExtension ativa em 2026. Substitui o godot-speech do V-Sekai. |
| [Nakama](https://github.com/heroiclabs/nakama) + [cliente Godot](https://github.com/heroiclabs/nakama-godot) | Apache-2.0 | Se um dia houver servidor: amigos, presença, chat, salas. Hospedagem própria. |

### Fase 18 e V6: mundos abertos

Seção 2 (segurança dos perfis) e o godot-sandbox para o Horizonte. O [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader) (CC0) existe, mas carrega **scripts**, o oposto do que a Fase 18 quer (perfis sem código).

### Fora do roadmap, mas perto: outras bibliotecas além da Steam

A Fase 17 já cria a ideia de "fonte de biblioteca". Outros launchers abertos já leem bibliotecas de GOG, Epic e Amazon:

- [Heroic](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher) e [Lutris](https://github.com/lutris/lutris) (Linux, GPL-3.0): **só ler os arquivos de dados deles** (a lista de jogos instalados) para pôr esses jogos na cidade. Nenhum código copiado.
- [Playnite](https://github.com/JosefNemec/Playnite) (Windows, MIT): idem, e ainda dá para olhar como ele junta metadados.

Ideia para o Horizonte: "jogos da Epic e da GOG viram prédios também".

---

## 5. Produtos e projetos parecidos com o hub

| Projeto | Aberto? | O que é | O que aprender |
|---|---|---|---|
| **BOXROOM** (Nested Loop, 2026) | Não (pago, acesso antecipado) | Montar um quarto com os jogos da Steam como caixas físicas e abrir por ali. | Valida a ideia de "biblioteca como lugar". O hub vai além: cidade, bairros por categoria, amigos e desktop. |
| [Mozilla Hubs](https://github.com/Hubs-Foundation/hubs) | MPL-2.0 | Salas sociais 3D no navegador. | Referência de convite por link e de moderação. |
| [Overte](https://github.com/overte-org/overte) | Apache-2.0 | Mundos virtuais abertos (antigo High Fidelity). | Referência de mundos que se conectam. |
| [Pegasus](https://github.com/mmatyas/pegasus-frontend) | GPL-3.0 | Frontend de biblioteca de jogos com temas. | Só ideia: temas como dado, igual à Fase 7. |

---

## 6. Assets CC0 candidatos

Nada baixado. Cada um precisa de permissão antes, com nome do arquivo, origem e tamanho.

| Pacote | Origem | Ajuda em |
|---|---|---|
| **Universal Animation Library** 1 e 2 (120+ e 130+ animações, rig humanoide universal) | [Quaternius](https://quaternius.com/packs/universalanimationlibrary.html), CC0 | Avatar e hologramas: sentar no sofá da casa, acenar, dançar, emotes (com `RetargetModifier3D`). A versão gratuita tem 45 animações. |
| Pinheiros, rochas e plantas (Stylized Nature MegaKit e similares) | Quaternius, CC0 | Fase 15 (montanha). Comparar com o `kenney/nature-kit` que já está no projeto. |
| City Kit Commercial, Suburban e Industrial | Kenney, CC0 | Mais variedade de prédios (o projeto já usa o `city-kit-roads`). |
| KayKit (City Builder Bits, Forest Nature Pack) | Kay Lousberg, CC0 | Alternativa de estilo para os biomas. |
| Neve, pedra e gelo | Poly Haven e ambientCG, CC0 | Chão da Fase 15. As duas fontes já estão no projeto. |
| 100Avatars (VRM) | Polygonal Mind (CC0 a conferir) | Testar VRM e variar os hologramas. |

---

## 7. Sugestão de ordem (o dono decide)

1. **Já, sem baixar nada** (cabe numa subetapa pequena depois da Fase 14): `LookAtModifier3D` nos hologramas e no espelho, e a mira em cone (ideia do lasso) para o controle Xbox.
2. **No plano da Fase 15:** IK dos pés na encosta e os assets CC0 da montanha.
3. **No plano da Fase 18:** perfis do usuário nunca via `load()` direto (safe loader, ou JSON/`ConfigFile`) e a lista de permitidos do V-Sekai.
4. **Spike de avatar VRM** (godot-vrm + um avatar CC0), antes da V4.
5. **Horizonte:** V4 ao vivo com GodotSteam + netfox + TwoVoIP; outras lojas (Heroic, Lutris, Playnite) como fontes de biblioteca; godot-sandbox para enfeites com comportamento.

## Fontes

- [V-Sekai no GitHub](https://github.com/V-Sekai), [awesome-v-sekai](https://github.com/V-Sekai/awesome-v-sekai), [CODEBASE.md do v-sekai-game](https://github.com/V-Sekai/v-sekai-game/blob/main/CODEBASE.md)
- [Inverse kinematics returns to Godot 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)
- [OSArch sobre o V-Sekai](https://osarch.org/2021/04/27/godot-engine-is-growing-potential-for-the-aec-industry/)
- [BOXROOM na Engadget](https://www.engadget.com/gaming/boxroom-lets-you-build-a-cozy-game-room-for-your-steam-library-215349560.html), [na GamingOnLinux](https://www.gamingonlinux.com/2026/04/boxroom-is-a-clever-casual-room-builder-to-give-your-steam-games-a-shelf/)
- [Universal Animation Library (itch.io)](https://quaternius.itch.io/universal-animation-library), [UAL 2 (OpenGameArt)](https://opengameart.org/content/universal-animation-library-2)
- Licenças e atividade conferidas pela API do GitHub em 2026-10-15.
