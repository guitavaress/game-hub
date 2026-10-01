# Game Hub

Um launcher para a biblioteca Steam em forma de **mundo 3D em primeira pessoa**, feito em [Godot 4](https://godotengine.org).

Você caminha por uma cidade onde **cada jogo instalado é um prédio**, com o banner do jogo no alto da fachada e o logo sobre a porta. Os prédios ficam agrupados em **bairros por categoria** (RPG, Sobrevivência e Terror, Cartas e Tabuleiro...), cada um com a sua cor de néon e o seu jeito. Ao parar na porta de um prédio, um anel enche em volta da mira; aí aparece a tela "Abrindo X…", o jogo abre pela Steam e o hub se minimiza. Quando você fecha o jogo, o hub volta com você na porta do mesmo prédio e um resumo da sessão ("1 h 12 min de Balatro").

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
| 7 | World Profile: cada bairro descrito por um perfil de dados (cores, som, enfeite, clima); chuva e invólucros de portal | 🔜 próxima |
| 8 | Escala: viagem rápida, bússola, minimapa e transporte entre bairros, para centenas de jogos | 🗓️ planejada |
| 9 | A casa: um interior onde ficam a biblioteca, os amigos e as configurações | 🗓️ planejada |

A ideia a longo prazo é que o hub vire um **desktop virtual em forma de mundo**, inspirado no PlayStation Home. A sua casa seria o computador, e a biblioteca decidiria como o mundo é: uma montanha de gelo para o Skyrim, uma pista de corrida onde se ouve o motor de longe. Um dia, o hub também rodaria no Linux. O caminho completo está no **[roadmap](docs/ROADMAP.md)**.

## Requisitos

- **Windows 10 ou 11**: o hub lê o registro do Windows para achar a Steam.
- **Steam** instalada.
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

### Testes automáticos

A pasta `tests/` tem uma bateria que roda sem abrir janela e sem abrir jogo de verdade. Para rodar, use o Git Bash:

```bash
bash tests/run_tests.sh               # todos
bash tests/run_tests.sh check_gates   # só um
```

O script procura a Godot em `C:\Godot`. Se ela estiver em outro lugar, rode com `GODOT=/caminho/da/godot.exe` antes do comando. No fim aparece `RESULTADO GERAL: TUDO OK` ou a lista do que falhou.

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
| Esc | Menu de pausa (som, vídeo, qualidade, hora da cidade, amigos) |
| Tab | Achar um jogo: digite o nome e aperte Enter; uma faixa de luz no chão leva até a porta |
| F11 | Tela cheia |
| F8 | Adiantar o relógio da cidade em 3 horas (para ver a noite) |
| Ficar 1,5 s dentro da porta de um prédio | Abrir o jogo (recue antes do anel encher para cancelar) |
| Esc, enquanto o jogo está abrindo | Cancelar a espera |

**PC fraco?** No menu de pausa, em **Qualidade**, escolha **Leve**: desliga os reflexos, o sombreamento extra e a névoa, e desenha o 3D em metade da resolução.

## Configuração

O hub cria na primeira execução o arquivo `%APPDATA%\Godot\app_userdata\Game Hub\config.cfg`. No editor, você também chega nele pelo menu **Projeto → Abrir Pasta de Dados do Usuário**. Ele é um arquivo de texto com comentários explicando cada opção. Som, vídeo e amigos também mudam pelo menu de pausa (Esc), que grava no mesmo arquivo e mantém os comentários:

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
```

Bairros disponíveis: `esportes`, `rpg`, `sobrevivencia`, `simulacao`, `estrategia`, `acao`, `cartas`, `aventura`, `casual` e `outros`. A tabela que liga as tags da Steam aos bairros fica em [`autoload/game_categories.gd`](autoload/game_categories.gd).

## Como funciona

```
autoload/      sistemas globais, que não sabem nada sobre a cidade
components/    peças reutilizáveis (GamePortal: "este lugar é um jogo")
player/        controle em primeira pessoa
ui/            HUD, avisos, menu de pausa, busca, telas "Abrindo"/"Jogando" e abertura
worlds/city/   a cidade: só monta o cenário e posiciona os portais
```

- **SteamLibrary** lê `libraryfolders.vdf` e os `appmanifest_*.acf` de todas as bibliotecas.
- **StoreInfo** busca as tags e os endereços das capas na API pública da loja (`IStoreBrowseService/GetItems`), sem chave e sem login. O resultado fica guardado por 30 dias.
- **GameCategories** escolhe o bairro de cada jogo: é a primeira tag, da mais votada para a menos votada, que aparece na tabela de bairros.
- **GameArt** procura o banner (hero), a capa e o logo primeiro no próprio cache, depois no cache local da Steam e, por último, baixa do CDN da Steam.
- **GameLauncher** abre o jogo com `steam://rungameid/<appid>` e acompanha o valor `RunningAppID` no registro do Windows para saber quando ele fechou. Também percebe jogos abertos por fora do hub.
- **HubWindow** minimiza e pausa o hub enquanto você joga, e depois o traz de volta no mesmo monitor.
- **FriendsService** usa a Steam Web API (`GetFriendList` e `GetPlayerSummaries`) para saber quem está online e o que está jogando. Ele consulta a cada 60 s e para enquanto você joga. Os **GamePortals** mostram os amigos que jogam o jogo deles, e a cidade coloca os outros na praça.

**Seguro para a sua conta:** o hub só **lê** arquivos que a Steam deixa no PC e usa endereços públicos da Steam, além da Web API oficial com a sua própria chave. Ele não modifica jogos nem os arquivos da Steam, não injeta nada e não pede senha.

## Detalhes da cidade

- **Cartão do jogo:** ao olhar para um prédio, o HUD mostra o bairro, o nome, o tempo jogado e quando foi a última vez ("23 h jogadas · jogado ontem") e quais amigos estão jogando. O hub lê as horas do `localconfig.vdf` da Steam, no seu PC, sem precisar da chave.
- **Arte da Steam:** o banner largo do jogo (hero) no alto da fachada e o logo sobre a porta; sem banner, a capa em pé.
- **Bairros com cara própria:** cada bairro tem um pórtico com o nome em néon na entrada e placas nas esquinas. Alguns têm um elemento só deles: telões no de Ação, lâmpadas de cassino no de Cartas, néon falhando e névoa baixa no de Terror.
- **Prédios variados:** andares, recuo no topo, marquise, tipo de janela e caixa d'água mudam de prédio para prédio (sempre iguais para o mesmo jogo).
- **Sons:** passos, pulo, um zumbido que sobe de tom na porta, um "whoosh" ao abrir o jogo e uma vinheta ao voltar. Cada bairro tem seu **som ambiente 3D**, que você ouve ao se aproximar da porta: motor no de Esportes e Corrida, cartas e fichas no de Cartas, vento no de Terror, passarinhos no de Aventura…
- **Dia e noite:** seguem o relógio do PC (ou ficam fixos, pelo menu). No pôr do sol o céu fica dourado e as janelas acendem uma a uma; à noite acendem os postes, o néon e as vitrines, e as poças refletem as luzes. No horizonte, uma silhueta de cidade.

## Créditos

- **Céus (HDRI):** [Poly Haven](https://polyhaven.com), **CC0** (domínio público): `kloofendal_48d_partly_cloudy_puresky` (dia), `qwantani_dusk_2_puresky` (pôr do sol) e `rogland_clear_night` (noite), em 2K. Detalhes em `assets/polyhaven/LICENSE.txt`.
- **Texturas (PBR):** [ambientCG](https://ambientcg.com), **CC0**: Bricks097, Concrete034, Concrete048, Road012A, Tiles139 e Tiles141, em 1K. Detalhes em `assets/ambientcg/LICENSE.txt`.
- **Pedra de calçamento (bairro Aventura):** `PavingStones070`, da [ambientCG](https://ambientcg.com) (**CC0**), em 1K.
- **Fonte:** Barlow e Barlow Condensed, de Jeremy Tribby ([Google Fonts](https://github.com/google/fonts)), licença **SIL Open Font License 1.1**. O texto da licença está em `assets/fonts/barlow/OFL.txt`.
- **Árvores:** fotos da `jacaranda_tree` da [Poly Haven](https://polyhaven.com) (**CC0**), tiradas em 8 ângulos por [`tools/make_tree_impostor.gd`](tools/make_tree_impostor.gd). O modelo original (215 MB) não fica no repositório; para refazer as fotos, baixe o glTF na Poly Haven e rode o script (as instruções estão no topo dele).
- **Hologramas dos amigos:** "Animated Human", da [Quaternius](https://quaternius.com) (**CC0**), baixado do [Poly Pizza](https://poly.pizza/m/c3Ibh9I3udk). Detalhes em `assets/quaternius/LICENSE.txt`.
- **Modelos e sons:** pacotes da [Kenney](https://kenney.nl), todos **CC0**. A licença de cada pacote está em `assets/kenney/<pacote>/License.txt`. Em uso: Nature Kit (arbustos), Impact Sounds, Interface Sounds, Sci-Fi Sounds, Casino Audio, RPG Audio e Music Jingles. City Kit Roads e Mini Characters vieram da primeira versão visual e continuam na pasta, sem uso no momento.
- O vento e os passarinhos são gerados por [`assets/generated/make_sounds.py`](assets/generated/make_sounds.py), também CC0.

## Licença

[MIT](LICENSE). Este projeto não tem ligação com a Valve. Steam e os nomes e imagens dos jogos pertencem aos seus donos.
