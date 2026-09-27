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
| 5 | Amigos da Steam como personagens na porta do jogo que estão jogando | ⏳ a fazer |
| 6 | Polimento: sons, iluminação, modelos 3D, horas jogadas | ⏳ a fazer |

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

## Controles

| Tecla | Ação |
|---|---|
| Mouse | Olhar |
| W A S D | Andar |
| Shift | Correr |
| Espaço | Pular |
| Esc | Soltar o mouse (clique na janela para prender de novo) |
| F11 | Tela cheia |
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

**Seguro para a sua conta:** o hub só **lê** arquivos que a Steam deixa no PC e usa endereços públicos da Steam. Ele não modifica jogos nem os arquivos da Steam, não injeta nada e não pede senha.

## Licença

[MIT](LICENSE). Este projeto não tem ligação com a Valve. Steam e os nomes e imagens dos jogos pertencem aos seus donos.
