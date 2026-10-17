# Game Hub

Um launcher para a biblioteca Steam em forma de **mundo 3D em primeira pessoa**, feito em [Godot 4](https://godotengine.org).

Você caminha por uma cidade onde **cada jogo instalado é um prédio**, com o banner do jogo no alto da fachada e o logo sobre a porta. Os prédios ficam agrupados em **bairros por categoria** (RPG, Sobrevivência e Terror, Cartas e Tabuleiro...), cada um com a sua cor de néon, a sua arquitetura e o seu nome em letreiro por cima dos telhados. Ao entrar na porta de um prédio, um anel enche em volta da mira; aí aparece a tela "Abrindo X…", o jogo abre pela Steam e o hub se minimiza. Quando você fecha o jogo, o hub volta com você na porta do mesmo prédio e um resumo da sessão ("1 h 12 min de Balatro").

## Situação do projeto

| Fase | O que é | Situação |
|---|---|---|
| 1 | Andar em primeira pessoa numa praça | ✅ pronta |
| 2 | Portal de jogo: entrar, abrir o jogo, voltar na porta | ✅ pronta |
| 3 | Cidade gerada da biblioteca, com bairros por categoria e capas | ✅ pronta |
| 4 | Launcher robusto: Steam fechada, jogos abertos por fora, vários monitores | ✅ pronta |
| 5 | Amigos da Steam como personagens na porta do jogo que estão jogando | ✅ pronta |
| 6 | Polimento: horas jogadas, capas HD, sons, som ambiente por bairro, modelos 3D, dia e noite | ✅ pronta |
| Visual v2 | Semi-realista com noite de néon: céus HDRI, materiais PBR, telas "Abrindo" e "Jogando", avisos, cartão do jogo | ✅ pronta |
| Visual v2, parte 2 | Menu de pausa, busca com Tab, abertura pelo céu, pórticos, prédios variados, horizonte, noite viva, identidade dos bairros | ✅ pronta |
| Linux | Roda no Linux (testado no Omarchy, com Hyprland): o jogo abre num workspace próprio e o hub se esconde num workspace oculto | ✅ pronta no Linux (falta a conferência final no Windows) |
| 7 | World Profile: cada bairro descrito por um perfil de dados (cores, som, enfeite, clima); chuva e invólucros de portal | ✅ pronta no Linux (falta a conferência no Windows) |
| 8 | Escala: viagem rápida, bússola, minimapa, mapa grande e metrô entre bairros, para centenas de jogos | ✅ pronta no Linux (falta a conferência de desempenho no desktop) |
| 9 | A casa: você nasce num loft com a estante da biblioteca, o mural dos amigos e o computador das configurações | ✅ pronta no Linux (falta a conferência no desktop) |
| 10 | Acabamento: texturas nítidas, bordas lisas, UI que escala com a tela, bairros com arquitetura e letreiro próprios, primeira vez guiada | ✅ pronta no Linux (falta a conferência no desktop) |
| 13 | Casa, parte 2: parede de estatísticas, temas (loft e cabana), cores das paredes e do néon, posições prontas dos móveis, e um avatar que você vê num espelho | ✅ pronta no Linux (falta a conferência no desktop) |
| 12 | Tema e controles: um tema único para todas as telas, menus pelo teclado e controle Xbox para jogar tudo, com as dicas trocando entre teclas e botões | ✅ pronta no Linux (falta a conferência com o controle no desktop) |
| 14 | O hub no Omarchy: painel do sistema (hora, bateria, Wi-Fi, volume), abrir o hub ao entrar no Omarchy, um atalho para chamá-lo de volta e **a mesa com três monitores**: o hub é um compositor Wayland, e os apps (terminal, Brave, a barra e o menu do Omarchy) aparecem nos monitores da casa, com os atalhos do Omarchy (como o Waylandcraft) | ✅ pronta no Linux (falta a medida no desktop e a conferência no Windows) |
| 11 | Sensação e marcos: câmera com peso, a porta que "pesa", torre do relógio e um marco alto por bairro, música, fundo da cidade, passos de madeira em casa, título ao entrar no bairro | ✅ pronta no Linux (falta a conferência no desktop) |

A ideia a longo prazo é que o hub vire um **desktop virtual em forma de mundo**, inspirado no PlayStation Home. A sua casa seria o computador, e a biblioteca decidiria como o mundo é: uma montanha de gelo para o Skyrim, uma pista de corrida onde se ouve o motor de longe. O caminho completo está no **[roadmap](docs/ROADMAP.md)**.

## Requisitos

- **Windows 10 ou 11**, ou **Linux** (testado no Omarchy, com Hyprland e Wayland).
- **Steam** instalada. No Linux, a Steam nativa; a do Flatpak deve funcionar, mas não foi testada.
- **Godot 4.7** ou mais nova (versão padrão, não a .NET).

## Como rodar

1. Clone o repositório:
   ```bash
   git clone https://github.com/guitavaress/game-hub.git
   ```
2. Abra a Godot, clique em **Importar** e escolha o arquivo `project.godot`.
3. **Desative a janela embutida.** Se ela ficar ligada, o hub não consegue se minimizar. Clique na aba **Game** do editor, abra o menu **⋮** e desmarque **Embed Game on Next Play**.
4. Aperte **F5**.

Na primeira vez, o hub busca na loja da Steam as tags e as capas dos seus jogos. Isso leva alguns segundos e depois fica guardado.

### No Linux

- **Godot:** baixe o binário oficial (`Godot_v4.7.2-stable_linux.x86_64.zip`, no site da Godot ou no GitHub), descompacte e copie para `~/.local/bin/godot`. Abra o editor com `godot --path ~/git/game-hub -e`.
- **Janela:** no Linux o hub usa o Wayland. No **Hyprland**, quando o jogo começa, ele vai para um workspace vazio (no monitor escolhido em `game_monitor`) e o hub se esconde num workspace oculto; quando o jogo fecha, o hub volta para onde estava.
- **Tela cheia:** por padrão, o próprio jogo decide. Use a opção de tela cheia do jogo (no Undertale, F4). Dá para o hub forçar com `game_fullscreen=true`, mas jogos antigos que não mudam de tamanho (como o Undertale) ficam desenhados num canto.
- **Steam no Omarchy:** para a janela da Steam não pular na frente quando um jogo abre, abra a Steam com `steam -silent` (ela fica na bandeja da barra) e impeça as janelas dela de roubar o foco. Veja [docs/PLATAFORMA.md](docs/PLATAFORMA.md).
- **Bússola e minimapa:** a faixa no topo mostra para onde você olha e o destino da busca, com a distância. O minimapa no canto mostra o quarteirão e o bairro onde você está. Esc › "Bússola e mapa" desliga os dois.

**Metrô:** há uma estação na praça (a noroeste do chafariz) e uma em cada bairro, no vão entre dois prédios. Bairros grandes ganham mais estações, para nenhuma porta ficar a mais de ~20 s correndo.

**Controle Xbox:** joga tudo.

| Botão | Ação |
|---|---|
| analógico esquerdo | Andar (apertar o analógico = correr) |
| analógico direito | Olhar |
| A | Pular; nos menus, escolher |
| X | Interagir; na busca, ir até a porta |
| Y | Busca |
| View | Mapa |
| Menu | Pausa |
| B | Voltar e fechar painéis; cancela a espera do jogo |
| direcional | Navegar nos menus e na lista da busca (que rola por todos os jogos) |
| LB e RB | Trocar de aba nos menus |

As dicas desenhadas na tela trocam sozinhas: no teclado mostram "Esc", "E" e "Tab"; ao tocar no controle, viram "B", "X" e "Y" (coloridos como o Xbox), e o cursor do mouse some. Em Esc › Controles há a **Sensibilidade do controle**.

**PC fraco?** Notebooks com gráfico integrado ficam bem melhores na qualidade **Leve** (menu Esc › Qualidade).

### Testes automáticos

A pasta `tests/` tem uma bateria que roda sem abrir janela e sem abrir jogo de verdade. Para rodar, use o Git Bash (no Windows) ou o terminal (no Linux):

```bash
bash tests/run_tests.sh               # todos
bash tests/run_tests.sh check_gates   # só um
```

O script procura a Godot em `C:\Godot` (Windows), no `PATH` e em `~/.local/bin/godot` (Linux). Se ela estiver em outro lugar, rode com `GODOT=/caminho/da/godot` antes do comando. No fim aparece `RESULTADO GERAL: TUDO OK` ou a lista do que falhou.

Alguns testes usam a biblioteca de verdade e esperam quatro jogos instalados: **Balatro, Skyrim, Valheim e Stardew Valley**. Num PC sem eles, esses testes falham por falta do jogo, e não por erro no hub.

## Amigos na cidade (opcional)

Seus amigos da Steam aparecem como hologramas com o avatar e o nome em cima:
- **jogando algo da sua biblioteca:** ficam ao lado da porta do prédio daquele jogo;
- **online sem jogar, ou jogando algo que você não tem:** ficam em volta do chafariz da praça;
- **offline:** não aparecem.

Para isso, o hub precisa de uma **chave da Steam Web API**:

1. Logado na Steam, entre em <https://steamcommunity.com/dev/apikey>. Em "domínio", pode escrever `localhost`. A Steam pode pedir confirmação no app Steam Guard.
2. No hub, aperte **Esc**, abra a aba **Amigos**, cole a chave e clique em **Salvar e conectar**. (Se preferir, dá para colar a chave direto no `config.cfg`, entre as aspas da linha `web_api_key=""`; veja [Configuração](#configuração).)

> ⚠️ **A chave é secreta.** Não mostre para ninguém e não envie para repositórios nem chats. Golpistas usam chaves vazadas para mexer em trocas de itens. Se ela vazar, apague a chave na mesma página. O hub guarda a chave só no `config.cfg`, na pasta de dados do usuário, fora do repositório; no menu, ela aparece só como bolinhas e nunca é mostrada de volta.

A Steam só mostra o jogo de um amigo se ele deixou **"Detalhes do jogo"** como público no perfil. Se não, ele aparece na praça como online. Se o hub avisar que não conseguiu ler sua lista de amigos, deixe **"Lista de amigos"** como pública em Steam → Perfil → Editar perfil → Configurações de privacidade.

## Controles

| Tecla | Ação |
|---|---|
| Mouse | Olhar |
| W A S D | Andar |
| Shift | Correr |
| Espaço | Pular |
| Setas, Enter, Esc | Navegar nos menus (pausa e computador) sem o mouse |
| Esc | Menu de pausa (som, vídeo, qualidade, hora da cidade, controles, amigos). Em casa, também devolve a câmera do computador |
| E | Interagir: porta (casa e praça), estante (segurar para jogar), mural dos amigos e computador |
| Tab | Achar um jogo: digite o nome e aperte Enter; uma faixa de luz no chão leva até a porta |
| Shift+Enter (na busca) | Ir direto até a porta do jogo (a tela escurece e você aparece na frente dela; o jogo não abre) |
| M | Mapa grande da cidade (M ou Esc fecham) |
| Pisar na escada de uma estação "M" | Metrô: escolha o bairro e viaje (setas ou 1 a 9, Enter; Esc fica) |
| F11 | Tela cheia |
| F8 | Adiantar o relógio da cidade em 3 horas (para ver a noite) |
| Ficar 1,5 s dentro da porta de um prédio | Abrir o jogo (recue antes do anel encher para cancelar) |
| Esc, enquanto o jogo está abrindo | Cancelar a espera |

**PC fraco?** No menu de pausa, em **Qualidade**, escolha **Leve**: desliga os reflexos, o sombreamento extra e a névoa, desenha o 3D em metade da resolução, usa o anti-aliasing mais barato (FXAA) e encurta a sombra do sol.

**Qualidades:** **Alta** liga tudo e alisa as bordas com MSAA 2x + SMAA; **Média** tira os reflexos na tela e usa SMAA; **Leve** é a de cima. As texturas do chão e das paredes têm mipmaps: o asfalto ao longe não "granula" nem cintila. A interface (menus, avisos, mapa) cresce junto com a janela, então ocupa a mesma parte da tela em 720p, 1080p ou 1440p.

**Primeira vez:** ao abrir o hub pela primeira vez, um cartão no pé da tela mostra as teclas principais (some no primeiro E ou depois de 15 s; não aparece de novo). Os outros avisos esperam ele sair. Quando a cidade termina de montar, aparece "A cidade está pronta", com um som curto.

**Sensação (Fase 11):** andando, a câmera balança de leve; ao pousar de um pulo, ela afunda; correndo, o campo de visão abre 5°. Na porta de um jogo, enquanto o anel enche, o FOV fecha, a câmera avança um pouco, o vão e o néon acendem mais forte, e o som da carga é um rumor grave. Em Esc › Controles dá para **desligar o balanço da câmera** (se der enjoo) e mudar a **sensibilidade do mouse** e o **campo de visão**, com efeito na hora.

**Marcos e títulos:** no meio do chafariz da praça há uma **torre do relógio** (~18 m) que marca a hora da cidade e aparece no minimapa. Cada bairro (menos a Simulação, cuja grua já é o marco) tem um **marco alto** no telhado do quarteirão do pórtico: torre de castelo no RPG, torre de refletores nos Esportes, roda-gigante no Casual, torre de rádio na Ação, dado de néon nas Cartas, caixa d'água no Terror, rei de xadrez na Estratégia, farol na Aventura e antena holográfica em Outros. Ao entrar num bairro, aparece o **nome dele e quantos jogos tem** por ~2,5 s.

**Som:** há um canal **Música** (com deslizador) onde tocam os jingles; a cidade tem um **fundo baixinho** de vento e trânsito ao longe, e o bairro Outros tem som próprio. Em casa, os passos são de **madeira, com um eco leve**; na rua, de concreto.

## Configuração

O hub cria na primeira execução o arquivo `config.cfg`, em `%APPDATA%\Godot\app_userdata\Game Hub\` no Windows e em `~/.local/share/godot/app_userdata/Game Hub/` no Linux. Cada sistema tem o seu: num PC com dual boot, a chave da API é colada uma vez em cada um. No editor, você também chega nele pelo menu **Projeto → Abrir Pasta de Dados do Usuário**. Ele é um arquivo de texto com comentários explicando cada opção. Som, vídeo e amigos também mudam pelo menu de pausa (Esc), que grava no mesmo arquivo e mantém os comentários:

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

## Como funciona

```
autoload/      sistemas globais, que não sabem nada sobre a cidade
  platform/    o que muda entre Windows e Linux (Steam, janela)
components/    peças reutilizáveis (GamePortal: "este lugar é um jogo")
player/        controle em primeira pessoa
ui/            HUD, avisos, menu de pausa, busca, telas "Abrindo"/"Jogando" e abertura
worlds/city/   a cidade: só monta o cenário e posiciona os portais
```

- **SteamLibrary** lê `libraryfolders.vdf` e os `appmanifest_*.acf` de todas as bibliotecas.
- **StoreInfo** busca as tags e os endereços das capas na API pública da loja (`IStoreBrowseService/GetItems`), sem chave e sem login. O resultado fica guardado por 30 dias.
- **GameCategories** escolhe o bairro de cada jogo: é a primeira tag, da mais votada para a menos votada, que aparece na tabela de bairros.
- **GameArt** procura o banner (hero), a capa e o logo primeiro no próprio cache, depois no cache local da Steam e, por último, baixa do CDN da Steam.
- **GameLauncher** abre o jogo com `steam://rungameid/<appid>` e pergunta ao **SteamClient** qual jogo está rodando, para saber quando ele fechou. No Windows, a resposta vem do registro (`RunningAppID`); no Linux, do processo `reaper` que a Steam cria para cada jogo. Também percebe jogos abertos por fora do hub.
- **HubWindow** esconde e pausa o hub enquanto você joga, e depois o traz de volta. No Windows, ele minimiza e volta no mesmo monitor; no Hyprland, usa um workspace oculto. Os detalhes de cada sistema estão em [docs/PLATAFORMA.md](docs/PLATAFORMA.md).
- **AppLibrary** e **AppLauncher** fazem pelos programas (navegador, terminal...) o que o SteamLibrary e o GameLauncher fazem pelos jogos. No Linux, a lista vem dos arquivos `.desktop` (menos os jogos da Steam, que já são prédios); no Windows, dos atalhos do Menu Iniciar. O app abre como o Omarchy abre (`uwsm-app`), o hub se esconde, e a sessão acaba quando a janela do app fecha (Hyprland) ou quando o hub volta a ter foco.
- **SystemStatus** pergunta a bateria, a rede e o volume ao sistema a cada 5 s (e para enquanto o hub dorme), para o painel da casa.
- **FriendsService** usa a Steam Web API (`GetFriendList` e `GetPlayerSummaries`) para saber quem está online e o que está jogando. Ele consulta a cada 60 s e para enquanto você joga. Os **GamePortals** mostram os amigos que jogam o jogo deles, e a cidade coloca os outros na praça.

**Seguro para a sua conta:** o hub só **lê** arquivos que a Steam deixa no PC e usa endereços públicos da Steam, além da Web API oficial com a sua própria chave. Ele não modifica jogos nem os arquivos da Steam, não injeta nada e não pede senha.

## A casa

Ao abrir o hub, você nasce dentro de um **loft** (de noite, com a cidade na janela), virado para a estante e o janelão, e a cidade monta lá fora; a porta mostra "Montando a cidade… N%" e destranca sozinha. Olhe para uma coisa e aperte **E**:

- **Estante:** uma caixa por jogo da biblioteca, com a capa. Olhar mostra o mesmo cartão do prédio (bairro, horas, amigos); **segurar E** abre o jogo, e ao fechar você volta para a frente da estante. As placas passam a página e trocam o filtro por bairro.
- **A mesa com três monitores** (no Linux): veja [A mesa](#a-mesa-com-três-monitores-linux). Sem o Linux (ou sem compilar o compositor), os monitores mostram "Sem sinal".
- **Painel do sistema** (na parede norte, acima do computador): a hora, a bateria, o Wi-Fi e o volume do computador, só para ver (não mexe em nada). O que o computador não tem, como a bateria de um desktop, some.
- **Mural:** um cartão por amigo online (foto, nome, situação e jogo), com quem está jogando primeiro. E num amigo leva até a porta do jogo dele na cidade (ou à praça, se for um jogo que você não tem). Sem chave ou sem amigos, o cartão diz "Configure os amigos no computador".
- **Mesa do computador:** três monitores (veja [A mesa](#a-mesa-com-três-monitores-linux)). As configurações (som e vídeo, controles, amigos, **Casa** e **Sistema**) ficam só no menu de pausa (Esc).
- **Estatísticas:** um quadro na parede sul (à esquerda da porta) com as **horas jogadas**, os **5 mais jogados**, as horas dos **maiores bairros** (na cor de cada um) e o **jogado por último**, com a capa. Conta só os jogos instalados. Sem horas (Steam sem conta logada) ou sem jogos, o quadro explica em vez de mostrar zeros. Atualiza quando você volta de um jogo (a Steam grava as horas com atraso: as da última sessão podem aparecer só na volta seguinte).
- **Espelho:** na parede sul, à direita da porta. Você se vê nele, com o seu avatar, e o reflexo acompanha o que você faz (só desenha de perto e de frente, para não pesar). **E** no espelho abre o **provador**: 5 visuais prontos e as cores de pele, olhos, cabelo, camiseta e calça. O avatar fica no `config.cfg` (seção `[avatar]`).
- **Menu de pausa, aba Sistema** (só no Linux): o interruptor **Abrir o hub ao entrar no Omarchy** (cria ou apaga `~/.config/autostart/game-hub.desktop`) o botão **Copiar a linha do atalho** e o botão **Copiar a linha da tecla de emergência** (veja a mesa). O hub nunca mexe na config do Hyprland: cole a linha no fim de `~/.config/hypr/bindings.lua` e o **SUPER + H** chama o hub. Com um app aberto, ele traz o hub de volta (o app continua aberto); com o hub em outro workspace, vai até ele; durante um jogo da Steam, nada muda.
- **Menu de pausa, aba Casa:** escolha o **tema** (Loft ou Cabana), a **posição dos móveis** (Padrão, Espelhada ou Estante na entrada) e a **cor das paredes e do néon** (8 cores prontas e "Do tema"). A casa muda na hora, atrás do monitor. Tudo fica na seção `[home]` do `config.cfg`.
- **Portas:** E na porta do loft ("E para sair") leva à praça; E na porta "Casa" da praça (ao lado do chafariz, com um néon "CASA" à noite) traz de volta. Em casa, a bússola e o minimapa somem, o som da cidade fica abafado, e a busca (Tab) e o mapa (M) se adaptam.

## A mesa com três monitores (Linux)

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

## Detalhes da cidade

- **Cartão do jogo:** ao olhar para um prédio, o HUD mostra o bairro, o nome, o tempo jogado e quando foi a última vez ("23 h jogadas · jogado ontem"), quais amigos estão jogando e como entrar ("Entre pela porta para jogar"). O hub lê as horas do `localconfig.vdf` da Steam, no seu PC, sem precisar da chave.
- **Arte da Steam:** o banner largo do jogo (hero) no alto da fachada e o logo sobre a porta; sem banner, a capa em pé.
- **Bairros com cara própria:** cada bairro tem um pórtico com o nome em néon na entrada, placas nas esquinas e **um letreiro grande acima dos telhados**, que se vê de longe. A **arquitetura** também muda: Estratégia e Simulação são altos; RPG e Aventura, baixos e de tijolo; Casual, baixo e claro; Terror, baixo e de concreto escuro. Alguns têm um elemento só deles: telões no de Ação, lâmpadas de cassino no de Cartas, néon falhando, névoa baixa e garoa à noite no de Terror.
- **Prédios variados:** andares, recuo no topo, marquise, tipo de janela e caixa d'água mudam de prédio para prédio (sempre iguais para o mesmo jogo).
- **Sons:** passos, pulo, um zumbido que sobe de tom na porta, um "whoosh" ao abrir o jogo e uma vinheta ao voltar. Cada bairro tem seu **som ambiente 3D**, que você ouve ao se aproximar da porta: motor no de Esportes e Corrida, cartas e fichas no de Cartas, vento no de Terror, passarinhos no de Aventura…
- **Dia e noite:** seguem o relógio do PC (ou ficam fixos, pelo menu). No pôr do sol o céu fica dourado e as janelas acendem uma a uma; à noite acendem os postes, o néon e as vitrines, e as poças refletem as luzes. No horizonte, uma silhueta de cidade.

### Como criar um tema de casa novo
Cada tema é um perfil em `profiles/homes/` (um `.tres`, o `HomeProfile`): materiais de piso, paredes e teto, luzes, a vista da janela, o néon e o script do enfeite (os móveis de decoração, em `worlds/home/themes/`). No editor, botão direito no `loft.tres` › Duplicar, mude o que quiser e acrescente o arquivo na lista **Homes** de `profiles/home_catalog.tres`; ele aparece na aba Casa do computador. A sala tem o mesmo tamanho em todos os temas. Para um enfeite novo, copie o `loft_decor.gd` (estende `HomeDecor`).

### Como criar um bairro novo
Cada bairro é um perfil em `profiles/districts/` (um arquivo `.tres`). Para criar um: no editor da Godot, botão direito num `.tres` › Duplicar, ajuste nome, cores, tags da Steam, sons, enfeite, clima e arquitetura no inspetor, e acrescente o arquivo na lista **Districts** de `profiles/world_profile.tres` (a ordem da lista é a ordem dos bairros). Não é preciso mexer em código.

## Créditos

- **Céus (HDRI):** [Poly Haven](https://polyhaven.com), **CC0** (domínio público): `kloofendal_48d_partly_cloudy_puresky` (dia), `qwantani_dusk_2_puresky` (pôr do sol) e `rogland_clear_night` (noite), em 2K. Detalhes em `assets/polyhaven/LICENSE.txt`.
- **Texturas (PBR):** [ambientCG](https://ambientcg.com), **CC0**: Bricks097, Concrete034, Concrete048, Road012A, Tiles139 e Tiles141, em 1K. Detalhes em `assets/ambientcg/LICENSE.txt`.
- **Pedra de calçamento (bairro Aventura):** `PavingStones070`, da [ambientCG](https://ambientcg.com) (**CC0**), em 1K.
- **Fonte:** Barlow e Barlow Condensed, de Jeremy Tribby ([Google Fonts](https://github.com/google/fonts)), licença **SIL Open Font License 1.1**. O texto da licença está em `assets/fonts/barlow/OFL.txt`.
- **Árvores:** fotos da `jacaranda_tree` da [Poly Haven](https://polyhaven.com) (**CC0**), tiradas em 8 ângulos por [`tools/make_tree_impostor.gd`](tools/make_tree_impostor.gd). O modelo original (215 MB) não fica no repositório; para refazer as fotos, baixe o glTF na Poly Haven e rode o script (as instruções estão no topo dele).
- **Avatar e hologramas dos amigos:** "Animated Human", da [Quaternius](https://quaternius.com) (**CC0**), baixado do [Poly Pizza](https://poly.pizza/m/c3Ibh9I3udk). Detalhes em `assets/quaternius/LICENSE.txt`.
- **Modelos e sons:** pacotes da [Kenney](https://kenney.nl), todos **CC0**. A licença de cada pacote está em `assets/kenney/<pacote>/License.txt`. Em uso: Nature Kit (arbustos), Impact Sounds, Interface Sounds, Sci-Fi Sounds, Casino Audio, RPG Audio e Music Jingles. City Kit Roads e Mini Characters vieram da primeira versão visual e continuam na pasta, sem uso no momento.
- **Menu de depuração (F3):** [Debug Menu](https://github.com/godot-extended-libraries/godot-debug-menu) v1.2.0, de Calinou, licença **MIT** (`addons/debug_menu/LICENSE.md`). F3 alterna entre FPS, tempos de quadro e hardware.
- **Céu Sky3D (opção Céu = Sky3D):** [Sky3D](https://github.com/TokisanGames/Sky3D) v2.1.0, de Cory Petkovsek, J. Cuéllar e colaboradores, licença **MIT** (`addons/sky_3d/LICENSE.txt`); o mapa da Lua (`MoonMap.png`) é de GPoSM, também **MIT**. A Via Láctea original do addon (CC BY 4.0) ficou de fora: as estrelas são geradas por [`tools/gerar_estrelas.gd`](tools/gerar_estrelas.gd) (CC0).
- O estalo da lareira da cabana (`fire_crackle.wav`) também é gerado pelo mesmo script, CC0. As toras, o tapete e a vista da floresta são shaders feitos por código (nada baixado).
- O vento, os passarinhos, o `metro_ride.wav` e o `city_bed.wav` (fundo da cidade) são gerados por [`assets/generated/make_sounds.py`](assets/generated/make_sounds.py), também CC0 (`assets/generated/LICENSE.txt`).

## Licença

[MIT](LICENSE). Este projeto não tem ligação com a Valve. Steam e os nomes e imagens dos jogos pertencem aos seus donos.
