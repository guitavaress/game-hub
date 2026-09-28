# Game Hub

Um launcher para a biblioteca Steam em forma de **mundo 3D em primeira pessoa**, feito em [Godot 4](https://godotengine.org).

Você caminha por uma cidade onde **cada jogo instalado é um prédio**, com a capa do jogo na fachada. Os prédios ficam agrupados em **bairros por categoria** (RPG, Sobrevivência e Terror, Cartas e Tabuleiro...). Ao entrar pela porta de um prédio, a tela escurece, o hub se minimiza e o jogo abre pela Steam. Quando você fecha o jogo, o hub volta com você na porta do mesmo prédio.

## Situação do projeto

| Fase | O que é | Situação |
|---|---|---|
| 1 | Andar em primeira pessoa numa praça | ✅ pronta |
| 2 | Portal de jogo: entrar, abrir o jogo, voltar na porta | ✅ pronta |
| 3 | Cidade gerada da biblioteca, com bairros por categoria e capas | ✅ pronta |
| 4 | Launcher robusto: Steam fechada, jogos abertos por fora, vários monitores | ✅ pronta |
| 5 | Amigos da Steam como personagens na porta do jogo que estão jogando | ✅ pronta |
| 6 | Polimento: horas jogadas, capas HD, sons, som ambiente por bairro, modelos 3D, dia e noite | ✅ pronta |

A ideia a longo prazo é reaproveitar os mesmos sistemas num mundo aberto maior. Por exemplo: uma montanha de gelo para o Skyrim, ou uma pista de corrida onde se ouve o motor de longe.

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

## Amigos na cidade (opcional)

Seus amigos da Steam aparecem como bonequinhos com o avatar e o nome em cima:
- **jogando algo da sua biblioteca:** ficam ao lado da porta do prédio daquele jogo;
- **online sem jogar, ou jogando algo que você não tem:** ficam em volta do chafariz da praça;
- **offline:** não aparecem.

Para isso, o hub precisa de uma **chave da Steam Web API**:

1. Logado na Steam, entre em <https://steamcommunity.com/dev/apikey>. Em "domínio", pode escrever `localhost`. A Steam pode pedir confirmação no app Steam Guard.
2. Abra o `config.cfg` (veja [Configuração](#configuração)) e cole a chave **entre as aspas** da linha `web_api_key=""`.
3. Abra o hub de novo.

> ⚠️ **A chave é secreta.** Não mostre para ninguém e não envie para repositórios nem chats. Golpistas usam chaves vazadas para mexer em trocas de itens. Se ela vazar, apague a chave na mesma página. O `config.cfg` fica na pasta de dados do usuário, fora do repositório.

A Steam só mostra o jogo de um amigo se ele deixou **"Detalhes do jogo"** como público no perfil. Se não, ele aparece na praça como online. Se o hub avisar que não conseguiu ler sua lista de amigos, deixe **"Lista de amigos"** como pública em Steam → Perfil → Editar perfil → Configurações de privacidade.

## Controles

| Tecla | Ação |
|---|---|
| Mouse | Olhar |
| W A S D | Andar |
| Shift | Correr |
| Espaço | Pular |
| Esc | Soltar o mouse (clique na janela para prender de novo) |
| F11 | Tela cheia |
| F8 | Adiantar o relógio da cidade em 3 horas (para ver a noite) |
| Ficar 1,5 s dentro da porta de um prédio | Abrir o jogo |
| Esc, enquanto o jogo está abrindo | Cancelar a espera |

## Configuração

O hub cria na primeira execução o arquivo `%APPDATA%\Godot\app_userdata\Game Hub\config.cfg`. No editor, você também chega nele pelo menu **Projeto → Abrir Pasta de Dados do Usuário**. Ele é um arquivo de texto com comentários explicando cada opção:

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
```

Bairros disponíveis: `esportes`, `rpg`, `sobrevivencia`, `simulacao`, `estrategia`, `acao`, `cartas`, `aventura`, `casual` e `outros`. A tabela que liga as tags da Steam aos bairros fica em [`autoload/game_categories.gd`](autoload/game_categories.gd).

## Como funciona

```
autoload/      sistemas globais, que não sabem nada sobre a cidade
components/    peças reutilizáveis (GamePortal: "este lugar é um jogo")
player/        controle em primeira pessoa
ui/            HUD e a "cortina" preta das transições
worlds/city/   a cidade: só monta o cenário e posiciona os portais
```

- **SteamLibrary** lê `libraryfolders.vdf` e os `appmanifest_*.acf` de todas as bibliotecas.
- **StoreInfo** busca as tags e os endereços das capas na API pública da loja (`IStoreBrowseService/GetItems`), sem chave e sem login. O resultado fica guardado por 30 dias.
- **GameCategories** escolhe o bairro de cada jogo: é a primeira tag, da mais votada para a menos votada, que aparece na tabela de bairros.
- **GameArt** procura a capa primeiro no próprio cache, depois no cache local da Steam e, por último, baixa do CDN da Steam.
- **GameLauncher** abre o jogo com `steam://rungameid/<appid>` e acompanha o valor `RunningAppID` no registro do Windows para saber quando ele fechou. Também percebe jogos abertos por fora do hub.
- **HubWindow** minimiza e pausa o hub enquanto você joga, e depois o traz de volta no mesmo monitor.
- **FriendsService** usa a Steam Web API (`GetFriendList` e `GetPlayerSummaries`) para saber quem está online e o que está jogando. Ele consulta a cada 60 s e para enquanto você joga. Os **GamePortals** mostram os amigos que jogam o jogo deles, e a cidade coloca os outros na praça.

**Seguro para a sua conta:** o hub só **lê** arquivos que a Steam deixa no PC e usa endereços públicos da Steam, além da Web API oficial com a sua própria chave. Ele não modifica jogos nem os arquivos da Steam, não injeta nada e não pede senha.

## Detalhes da cidade

- **Horas jogadas:** ao olhar para um prédio, o HUD mostra o tempo jogado e quando foi a última vez (por exemplo, "Balatro — 23 h jogadas · jogado ontem"). O hub lê isso do `localconfig.vdf` da Steam, no seu PC, sem precisar da chave.
- **Capas em HD:** o prédio mostra na hora a capa do cache da Steam (300×450) e baixa a versão 600×900 uma vez só.
- **Sons:** passos, pulo, um zumbido que sobe de tom na porta, um "whoosh" ao abrir o jogo e uma vinheta ao voltar. Cada bairro tem seu **som ambiente 3D**, que você ouve ao se aproximar da porta: motor no de Esportes e Corrida, cartas e fichas no de Cartas, vento no de Terror, passarinhos no de Aventura…
- **Dia e noite:** seguem o relógio do PC. À noite, os postes e as janelas acendem e as capas brilham.

## Créditos

- **Céus (HDRI):** [Poly Haven](https://polyhaven.com), **CC0** (domínio público): `kloofendal_48d_partly_cloudy_puresky` (dia), `qwantani_dusk_2_puresky` (pôr do sol) e `rogland_clear_night` (noite), em 2K. Detalhes em `assets/polyhaven/LICENSE.txt`.
- **Texturas (PBR):** [ambientCG](https://ambientcg.com), **CC0**: Bricks097, Concrete034, Concrete048, Road012A, Tiles139 e Tiles141, em 1K. Detalhes em `assets/ambientcg/LICENSE.txt`.
- **Fonte:** Barlow e Barlow Condensed, de Jeremy Tribby ([Google Fonts](https://github.com/google/fonts)), licença **SIL Open Font License 1.1**. O texto da licença está em `assets/fonts/barlow/OFL.txt`.
- **Modelos e sons:** pacotes da [Kenney](https://kenney.nl), todos **CC0**. A licença de cada pacote está em `assets/kenney/<pacote>/License.txt`. Em uso: Nature Kit (arbustos), Impact Sounds, Interface Sounds, Sci-Fi Sounds, Casino Audio, RPG Audio e Music Jingles. City Kit Roads e Mini Characters vieram da primeira versão visual e continuam na pasta, sem uso no momento.
- O vento e os passarinhos são gerados por [`assets/generated/make_sounds.py`](assets/generated/make_sounds.py), também CC0.

## Licença

[MIT](LICENSE). Este projeto não tem ligação com a Valve. Steam e os nomes e imagens dos jogos pertencem aos seus donos.
