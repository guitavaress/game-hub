<p align="center">
  <img src="assets/brand/icone.svg" alt="Símbolo do Game Hub: uma casa com uma porta azul" width="88">
</p>

# Game Hub

**Sua biblioteca Steam é um lugar. Entre para jogar.**

Um launcher em forma de **mundo 3D em primeira pessoa**, inspirado no PlayStation Home e feito em Godot. Você começa em casa, sai para uma cidade construída com os seus jogos e encontra os amigos como hologramas pelo caminho.

Cada jogo instalado tem uma porta. Entre, espere o anel da mira encher e o jogo abre pela Steam. O hub se minimiza; quando você fecha o jogo, volta ao mesmo lugar, com um resumo da sessão.

[Experimentar](#experimentar) · [Explorar o mundo](#um-passeio-pelo-hub) · [Controles](#controles) · [Rodar pelo código](#rodar-pelo-código) · [Roadmap](docs/ROADMAP.md)

## Um passeio pelo hub

### Comece em casa

Luz quente, um sofá, um canto de leitura e **a cidade de verdade na janela**. Na estante, cada caixa tem a capa de um jogo seu: olhe para ela e segure **E** para jogar sem sair de casa.

O mural reúne os amigos online. Na parede, suas estatísticas mostram as horas jogadas, os mais jogados e os maiores bairros. No espelho, você escolhe o visual do avatar. Em **Esc › Casa**, troque entre **loft e cabana**, mude as cores e escolha a posição dos móveis.

### Saia para a sua biblioteca

Os jogos se agrupam em **dez bairros por categoria**, com arquitetura, cores, marcos e sons próprios. Cartas tem luzes de cassino; Terror tem néon falhando, névoa e garoa à noite. Fachadas mostram a arte dos jogos, e olhar para uma porta revela as horas jogadas e os amigos que estão ali.

A cidade acompanha o relógio do computador: o céu muda, as janelas acendem e o néon toma conta da noite. Você também pode fixar dia ou noite pelo menu.

Quer ir direto ao que interessa? **Tab** encontra o jogo e desenha uma rota no chão. **Shift + Enter**, na busca, leva direto até a porta. Há bússola, minimapa, mapa grande e **metrô entre os bairros**.

### Suba até o mirante

No bairro RPG, o asfalto dá lugar à **neve, aos pinheiros e aos arcos de pedra**. Atrás dele, uma trilha sobe a montanha, com paradas, bancos e fogueira. No alto, o mirante destaca o seu RPG mais jogado; a luneta e a torre de pedra completam a vista da cidade lá embaixo.

Esse é o primeiro bioma do projeto: o começo da ideia de que **o que você joga molda o mundo**.

### Veja onde os amigos estão

Com a integração opcional da Steam, amigos aparecem como **hologramas com seus avatares**, na porta do jogo que estão jogando. Quem está online sem jogar, ou num jogo que você não tem, fica na praça.

Hoje eles mostram a presença da Steam. **Visitar e conversar com amigos dentro do hub é uma próxima etapa**, ainda em estudo.

## Experimentar

**Projeto pessoal em desenvolvimento · versão no código: 0.18.0 · atualizado em 11/11/2026.**

A Fase 17, *O momento uau*, já está na `main`. A **Fase 18, Mostrar para amigos**, está em andamento: o pacote do Windows está pronto, com instruções, licenças e um botão de feedback. **O primeiro Release para os amigos ainda está pendente de publicação.**

### Pacote do Windows

Quando publicado, o zip estará na página de [Releases](https://github.com/guitavaress/game-hub/releases). Para usar o pacote, você não precisa instalar a Godot.

Você precisa de **Windows 10 ou 11 de 64 bits**, **Steam com pelo menos um jogo instalado** e **placa de vídeo com suporte a Vulkan**. A primeira abertura usa internet para buscar capas e categorias; depois, esses dados ficam em cache.

1. Descompacte `GameHub-<versão>-windows.zip` numa pasta sua.
2. Abra a Steam e execute `GameHub.exe`. Mantenha o `.exe` e o `GameHub.pck` juntos.
3. Como o executável ainda não tem assinatura digital, o Windows pode mostrar o SmartScreen. Confira a origem do pacote; para executar a cópia baixada deste projeto, use **Mais informações › Executar assim mesmo**.

Na primeira abertura, a porta da casa mostra o progresso da preparação da cidade. **A chave da Steam é opcional:** você pode explorar e abrir seus jogos sem configurar os amigos.

O `LEIA-ME.txt` do pacote explica o primeiro uso e como apagar os dados. Em **Esc › Contar o que achei**, você responde três perguntas, confere o resumo e copia para enviar a quem te passou o hub. O botão não envia nada sozinho.

### Windows e Linux

| Plataforma | Situação |
|---|---|
| **Windows** | Editor e executável testados no desktop. Primeiro pacote para amigos na Fase 18. |
| **Linux** | Testado no Omarchy, com Hyprland e Wayland, rodando pelo código. A Steam nativa é a opção testada; Flatpak ainda não foi conferido. |
| **Mesa com apps dentro do mundo** | Recurso experimental só do Linux, com extensão nativa compilada à parte. O desenvolvimento do desktop virtual está em pausa. |

O foco atual é **abrir jogos e encontrar os amigos**. Depois do teste com amigos, vêm o estudo de visitas com V-Sekai e novos biomas. O [roadmap](docs/ROADMAP.md) reúne o histórico, as próximas fases e as pendências de validação.

## Controles

### Teclado e mouse

| Controle | Ação |
|---|---|
| Mouse / **W A S D** | Olhar / andar |
| **Shift** / **Espaço** | Correr / pular |
| **E** | Interagir com portas, mural e espelho; **segure** na estante para abrir um jogo |
| **Tab** | Buscar um jogo; **Enter** traça a rota, **Shift + Enter** vai até a porta |
| **M** | Abrir ou fechar o mapa da cidade |
| **Esc** | Pausa e configurações; voltar ou fechar painéis; cancelar a espera de um jogo |
| **Setas / Enter** | Navegar e escolher nos menus |
| **F11** | Alternar tela cheia |
| **F8** | Adiantar o relógio da cidade em três horas |

**Para jogar pela cidade:** fique dentro da porta por 1,5 segundo, até o anel da mira encher. Recue antes para cancelar. Para usar o metrô, pise na escada de uma estação **M** e escolha o destino.

### Controle Xbox

| Controle | Ação |
|---|---|
| Analógicos esquerdo / direito | Andar / olhar; aperte o esquerdo para correr |
| **A** / **X** | Pular ou confirmar / interagir |
| **Y** / **View** / **Menu** | Busca / mapa / pausa |
| **B** | Voltar; fechar painéis; cancelar a espera do jogo |
| Direcional / **LB e RB** | Navegar / trocar de aba nos menus |

As dicas da tela mudam automaticamente entre teclado e controle.

### Ajuste ao seu jeito

Em **Esc › Som e vídeo › Qualidade**, escolha **Alta**, **Média** ou **Leve**. A Leve reduz efeitos, sombras e a resolução do 3D, mantendo a interface nítida. Para notebook com gráfico integrado, comece por ela.

Em **Esc › Controles**, ajuste a sensibilidade do mouse e do controle, o campo de visão e o balanço da câmera. Em **Som e vídeo**, ajuste os volumes e a hora da cidade.

## Amigos da Steam (opcional)

Sem chave, o mural da casa mostra os passos para conectar. Aperte **E** nele para abrir a aba Amigos.

1. Entre na [página oficial da Steam Web API](https://steamcommunity.com/dev/apikey), com sua conta. No campo de domínio, use `localhost`.
2. No hub, em **Esc › Amigos**, cole a chave e escolha **Salvar e conectar**.

**Guarde a chave em segredo.** Ela fica apenas no `config.cfg`, na pasta de dados do usuário, fora do repositório. Não cole a chave em chats, relatos de problema ou commits. No menu, ela aparece mascarada.

Os hologramas dependem da privacidade da Steam: **Lista de amigos** precisa estar pública para a consulta, e **Detalhes do jogo** para mostrar o que cada amigo joga. Amigos offline não aparecem.

## Rodar pelo código

Use a **Godot 4.7.2 padrão, sem .NET**, a versão adotada e testada pelo projeto, com renderer Forward+ e suporte a Vulkan.

```bash
git clone https://github.com/guitavaress/game-hub.git
```

1. Na Godot, clique em **Importar** e escolha `project.godot`.
2. **Desative a janela embutida**, para o hub conseguir se minimizar: na aba **Game**, abra **⋮** e desmarque **Embed Game on Next Play**.
3. Aperte **F5**. Você começa em casa enquanto a cidade é preparada.

No Linux, com a Godot em `~/.local/bin/godot`, abra o editor com `godot --path /caminho/game-hub -e`. No Hyprland, o jogo abre num workspace próprio e o hub se esconde até ele fechar. Configuração de monitores, foco da Steam e tela cheia estão em [Plataforma](docs/PLATAFORMA.md).

### Como o projeto se organiza

```text
Steam → biblioteca, categorias e capas → perfis → mundo 3D
```

A separação principal é simples: **os sistemas abrem jogos e acompanham sessões; os mundos posicionam e decoram as portas**. O mesmo portal pode ser a entrada de um prédio ou um arco na neve.

| Pasta | Responsabilidade |
|---|---|
| `autoload/` | Biblioteca, capas, launcher, amigos e configurações |
| `autoload/platform/` | Tudo o que depende de Windows ou Linux |
| `profiles/` | Dados dos bairros, biomas, casas e avatares |
| `components/` | Peças reutilizáveis: portais, hologramas, telas e portas de viagem |
| `worlds/` | Casa, cidade e bioma da montanha |
| `player/` e `ui/` | Primeira pessoa, HUD, mapas, busca e menus |
| `tests/` e `tools/` | Testes, geração de assets, medição e empacotamento |
| `docs/` e `painel/` | Cofre do projeto e seu painel visual; o painel é separado do hub |

O hub lê a biblioteca e as horas dos arquivos locais da Steam, busca categorias e arte nos serviços da Steam e abre jogos por `steam://rungameid/<appid>`. Não pede sua senha nem modifica os arquivos da Steam ou dos jogos. Os amigos usam a Web API oficial, com a chave opcional do usuário.

### Testes e pacote

No Git Bash ou no terminal Linux:

```bash
bash tests/run_tests.sh                         # bateria completa
bash tests/run_tests.sh check_gates             # um teste
bash tools/empacotar_windows.sh                 # pacote do Windows
```

No PowerShell, chame o Git Bash explicitamente:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh
```

A bateria roda sem janela e sem abrir jogos. Alguns testes exigem **Balatro, Skyrim, Valheim e Stardew Valley** instalados. Antes de rodar, confira se outra sessão está testando: os worktrees compartilham os dados do usuário e, no Windows, não há trava automática. Comandos, pré-requisitos e formato dos testes estão em [tests/README.md](tests/README.md).

O empacotador exporta e confere o conteúdo antes de gerar o zip em `C:\Projetos\game-hub-builds\`, fora do repositório. Inclui o [LEIA-ME](tools/pacote/LEIA-ME.txt) e as [licenças](tools/pacote/licencas.txt), e recusa arquivos pessoais, capas em cache e pastas de desenvolvimento no pacote.

### Personalização por perfis

- **Bairro novo:** no editor, duplique um perfil em `profiles/districts/`, ajuste os dados e acrescente-o à lista **Districts** de `profiles/world_profile.tres`.
- **Tema de casa novo:** duplique um `HomeProfile` em `profiles/homes/` e acrescente-o à lista **Homes** de `profiles/home_catalog.tres`. Enfeites próprios estendem `HomeDecor`.
- **Bioma:** chão, clima, enfeites e terreno são dados de um `BiomeSpec`. O primeiro é `profiles/biomes/montanha.tres`, ligado ao RPG. Em bibliotecas muito grandes, a montanha pode ser omitida para caber no mapa; o bairro continua nevado.

<details>
<summary><strong>Configuração avançada e pasta de dados</strong></summary>

O hub cria na primeira execução o arquivo `config.cfg`, em `%APPDATA%\Godot\app_userdata\Game Hub\` no Windows e em `~/.local/share/godot/app_userdata/Game Hub/` no Linux. Cada sistema tem o seu: num PC com dual boot, a chave da API é colada uma vez em cada um. No editor, você também chega nele pelo menu **Projeto → Abrir Pasta de Dados do Usuário**. Ele é um arquivo de texto com comentários explicando cada opção. O exemplo abaixo mostra algumas delas; a maioria pode ser alterada pelo menu. Som, vídeo e amigos também mudam pelo menu de pausa (Esc), que grava no mesmo arquivo e mantém os comentários:

```ini
[library]
; Apps que NÃO devem virar prédio
excluded_app_ids=[431960, 993090]

[categories]
; Forçar o bairro de um jogo (ex.: Stardew Valley no bairro de RPG)
overrides={ 413150: "rpg" }

[steam]
; Chave da Steam Web API (para os amigos). SEGREDO!
web_api_key=""
; Seu SteamID64. Vazio = descobrir sozinho pela Steam.
steam_id=""
; false = não mostrar amigos
friends_enabled=true

[audio]
; Volumes de 0.0 (mudo) a 1.0 (máximo)
master_volume=0.8
effects_volume=1.0
ambience_volume=0.8

[video]
; Qualidade do 3D: "alta", "media" ou "leve"
quality="alta"
; Hora da cidade: "relogio" (relógio do PC), "dia" ou "noite"
time_of_day="relogio"

[apps]
; Programas que NÃO aparecem na estante de apps (ids dos arquivos .desktop, sem a
; extensão, separados por vírgula). O hub guarda em "ultimos" os apps abertos
; por último, que sobem para o começo da estante.
ocultos="avahi-discover,bvnc"

[window]
; Só no Linux com Hyprland: monitor onde os jogos abrem (nome do "hyprctl monitors").
; Vazio = o monitor em foco.
game_monitor="HDMI-A-1"
; true = o hub força o jogo para a tela cheia (jogos antigos podem quebrar).
game_fullscreen=false
```

Bairros disponíveis: `esportes`, `rpg`, `sobrevivencia`, `simulacao`, `estrategia`, `acao`, `cartas`, `aventura`, `casual` e `outros`. A tabela que liga as tags da Steam aos bairros fica em [`autoload/game_categories.gd`](autoload/game_categories.gd).

</details>

<details>
<summary><strong>Mesa com três monitores no Linux (experimental, desenvolvimento em pausa)</strong></summary>

No Linux, o hub é também um **compositor Wayland** (Rust + [Smithay](https://github.com/Smithay/smithay), uma GDExtension): os programas abertos pelo hub desenham as janelas **dentro** do mundo, nos três monitores da mesa do computador. A ideia vem do Waylandcraft (só a ideia: nenhuma linha dele foi copiada).

**Compilar (uma vez, e depois de mudar o Rust):** `bash tools/linux/compilar_compositor.sh` (precisa do `cargo`; a biblioteca fica em `native/bin/`, fora do git). Sem ela, o hub funciona como antes e os monitores mostram "Sem sinal".

**Usar:**
- Olhe para um monitor e aperte **E**: você senta, e a câmera enquadra os três. O mouse anda pelos três e os apps recebem o teclado.
- **SUPER + Z** aproxima a câmera do monitor da janela em foco (de novo, volta a ver os três). Com o zoom ligado, a câmera acompanha o monitor ativo: `SUPER + ←/→` vão para a janela vizinha e, sem janela do lado, andam de monitor em monitor (mesmo vazio); `SUPER + 1/2/3` e o clique numa janela também.
- **Segure Esc** (0,6 s) para levantar. Um Esc curto vai para o app. O botão B do controle faz o mesmo.
- Os monitores mostram o **fundo, a barra e o menu do Omarchy** (o Quickshell, rodando dentro do hub). Sentado, os **atalhos do Omarchy** funcionam ali: `SUPER + Enter` (terminal), `SUPER + Shift + B` (navegador), `SUPER + Space` (menu), `SUPER + W` (fechar), `SUPER + F` (tela cheia), `SUPER + setas` (foco, inclusive entre monitores), `SUPER + 1/2/3` (focar o monitor), `SUPER + Shift + 1/2/3` (mandar a janela para o monitor). As janelas se dividem sozinhas (até 3 por monitor). O que não é atalho vai para o app.
- Os apps abrem **dentro** do hub. Para abrir um de fora, em outro terminal: `env WAYLAND_DISPLAY=gamehub-0 foot`.

**Tecla de emergência:** sentado, o Hyprland de fora fica num modo quase vazio (para os atalhos `SUPER` chegarem ao hub). Cole a linha de **Esc › Sistema › Copiar a linha da tecla de emergência** no seu `~/.config/hypr/bindings.lua`: **SUPER + SHIFT + ESC** devolve os atalhos ao Hyprland mesmo se o hub travar (e o Hyprland sai sozinho do modo em 20 s se o hub parar). O hub nunca escreve na sua config.

**Limites conhecidos:** os números de workspace da barra ficam parados; não há bloqueio de tela nem idle lá dentro; apps que só falam X11 abrem fora do hub; a área de transferência não é compartilhada com o Omarchy de fora; no Windows não existe.

</details>

## Créditos

- **Céus (HDRI):** [Poly Haven](https://polyhaven.com), **CC0** (domínio público): `kloofendal_48d_partly_cloudy_puresky` (dia), `qwantani_dusk_2_puresky` (pôr do sol) e `rogland_clear_night` (noite), em 2K. Detalhes em `assets/polyhaven/LICENSE.txt`.
- **Texturas (PBR):** [ambientCG](https://ambientcg.com), **CC0**: Bricks097, Concrete034, Concrete048, Road012A, Tiles139 e Tiles141, em 1K. Detalhes em `assets/ambientcg/LICENSE.txt`.
- **Bioma montanha (Fase 15):** neve `Snow010A` e rocha `Rock058` da [ambientCG](https://ambientcg.com), em 1K; rocha 3D `moon_rock_02` e fotos do pinheiro `fir_sapling_medium` da [Poly Haven](https://polyhaven.com), tiradas por [`tools/make_tree_impostor.gd`](tools/make_tree_impostor.gd). Tudo **CC0**. O modelo do pinheiro (78 MB) não fica no repositório.
- **Pedra de calçamento (bairro Aventura):** `PavingStones070`, da [ambientCG](https://ambientcg.com) (**CC0**), em 1K.
- **Madeira dos modelos (Fase 17):** `Wood049`, da [ambientCG](https://ambientcg.com) (**CC0**), em 1K: o veio dos modelos feitos no Blender (deque, abrigo, bancos).
- **Ícone (Fase 18):** o símbolo casa-portal do estudo de marca do próprio Game Hub (versão flat), em `assets/brand/icone.svg`. É arte do projeto, sob a mesma licença **MIT** (`assets/brand/LICENSE.txt`).
- **Fonte:** Barlow e Barlow Condensed, de Jeremy Tribby ([Google Fonts](https://github.com/google/fonts)), licença **SIL Open Font License 1.1**. O texto da licença está em `assets/fonts/barlow/OFL.txt`.
- **Árvores:** fotos da `jacaranda_tree` da [Poly Haven](https://polyhaven.com) (**CC0**), tiradas em 8 ângulos por [`tools/make_tree_impostor.gd`](tools/make_tree_impostor.gd). O modelo original (215 MB) não fica no repositório; para refazer as fotos, baixe o glTF na Poly Haven e rode o script (as instruções estão no topo dele).
- **Avatar e hologramas dos amigos:** "Animated Human", da [Quaternius](https://quaternius.com) (**CC0**), baixado do [Poly Pizza](https://poly.pizza/m/c3Ibh9I3udk). Detalhes em `assets/quaternius/LICENSE.txt`.
- **Modelos e sons:** pacotes da [Kenney](https://kenney.nl), todos **CC0**. A licença de cada pacote está em `assets/kenney/<pacote>/License.txt`. Em uso: Nature Kit (arbustos), Impact Sounds (inclusive os passos na neve, `footstep_snow_000` a `004`), Interface Sounds, Sci-Fi Sounds, Casino Audio, RPG Audio e Music Jingles. City Kit Roads e Mini Characters vieram da primeira versão visual e continuam na pasta, sem uso no momento.
- **Menu de depuração (F3):** [Debug Menu](https://github.com/godot-extended-libraries/godot-debug-menu) v1.2.0, de Calinou, licença **MIT** (`addons/debug_menu/LICENSE.md`). F3 alterna entre FPS, tempos de quadro e hardware.
- **Céu Sky3D (opção Céu = Sky3D):** [Sky3D](https://github.com/TokisanGames/Sky3D) v2.1.0, de Cory Petkovsek, J. Cuéllar e colaboradores, licença **MIT** (`addons/sky_3d/LICENSE.txt`); o mapa da Lua (`MoonMap.png`) é de GPoSM, também **MIT**. A Via Láctea original do addon (CC BY 4.0) ficou de fora: as estrelas são geradas por [`tools/gerar_estrelas.gd`](tools/gerar_estrelas.gd) (CC0).
- O estalo da lareira da cabana (`fire_crackle.wav`) é gerado por [`assets/generated/make_sounds.py`](assets/generated/make_sounds.py), CC0. As toras, o tapete e a vista da floresta são shaders feitos por código (nada baixado).
- **A fogueira, o terraço de pedra, os bancos e o monte de pedras da trilha** (Fase 17.7.1) são modelos feitos no [Blender](https://www.blender.org) só por script, por [`tools/blender/`](tools/blender/README.md) (os scripts são GPL-3.0, porque usam a API do Blender; os `.glb` gerados, em `assets/models/trail/`, são nossos, MIT). Nada baixado: a textura da lenha e da brasa é assada no próprio Blender, e os bancos usam a madeira feita por código da casa.
- O vento, os passarinhos, o `metro_ride.wav` e o `city_bed.wav` (fundo da cidade) são gerados por [`assets/generated/make_sounds.py`](assets/generated/make_sounds.py), também CC0 (`assets/generated/LICENSE.txt`).

## Licença

[MIT](LICENSE). Este projeto não tem ligação com a Valve. Steam e os nomes e imagens dos jogos pertencem aos seus donos.
