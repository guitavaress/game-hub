# Estudo: instalar jogos pelo hub (fase 7)

Data: 2026-11-15 · Trilha B (só leitura) · Base: `33df095`

Este estudo **não muda código**. Ele responde às perguntas da fase "7. Instalar jogos pelo hub" da [ROADMAP](../ROADMAP.md) e termina com decisões para o dono, a menor versão testável e uma divisão em duas trilhas.

Convenção: **[conferido]** = li no código ou vi nos arquivos da Steam desta máquina (digo onde). **[suposição]** = conhecimento geral ou dedução, que o plano precisa confirmar antes de depender dele.

Privacidade: aqui entram só nomes de arquivo relativos à pasta da Steam e nomes de campo. Nenhum caminho de usuário, SteamID, nome de conta ou lista de jogos. Os números da biblioteca do dono aparecem só como ordem de grandeza.

## Resumo (o que muda para quem usa)

1. **Dá para listar os jogos não instalados sem chave nenhuma.** A Steam guarda em `appcache/packageinfo.vdf` os pacotes que a conta tem, e em `appcache/appinfo.vdf` o nome e o tipo (`game`, `dlc`, `tool`...) de cada app. Li os dois nesta máquina e batem: todos os apps instalados estavam na lista, e todos os appids dos pacotes estavam no `appinfo`. Os formatos são binários e não documentados (risco: a Valve pode mudar).
2. **A porcentagem sai do `appmanifest`**: os campos `BytesToDownload`/`BytesDownloaded` (baixar) e `BytesToStage`/`BytesStaged` (gravar no disco) existem de verdade. Mas, enquanto baixa, o jogo **não conta como instalado** para o hub de hoje (o `_read_manifest` descarta o que não tem o bit 4 do `StateFlags`).
3. **Pedir a instalação é uma linha**: `steam://install/<id>` pelo `OS.shell_open`, igual ao `steam://rungameid/<id>` que o hub já usa. A janela de instalação é da Steam.
4. **O ponto difícil é a cidade, não a Steam.** A cidade monta uma vez só, no `_ready` do `city.gd`, e a planta (`SectorLayout`) depende da contagem de quarteirões. Para um prédio nascer sem reabrir, o plano precisa **reservar terreno** para os não instalados (planta estável). O custo é a cidade ficar várias vezes maior para quem tem uma biblioteca grande: é a decisão nº 1 do dono.
5. **O portal em obras cabe no `GamePortal`** se o estado ("sem jogo", "em obras", "pronto") morar no portal e a aparência morar na casca (`PortalShell`), do jeito que o `charge_changed` já funciona hoje.

## 1. A lista dos jogos não instalados

### 1.1 Pelos arquivos locais da Steam (sem chave)

O que **conferi** na pasta da Steam desta máquina (só nomes):

| Arquivo (relativo à pasta da Steam) | O que é | Serve? |
|---|---|---|
| `steamapps/appmanifest_<id>.acf` (texto) | um por app **instalado** (ou baixando) | só os instalados: é o que o hub já lê |
| `steamapps/libraryfolders.vdf` (texto) | pastas de biblioteca | não lista jogos fora do disco |
| `appcache/packageinfo.vdf` (binário) | **os pacotes (licenças) da conta**, cada um com a lista `appids` | **sim: é a lista do que a conta tem** |
| `appcache/appinfo.vdf` (binário) | dados de cada app que a Steam já baixou: `common/type`, `common/name` | **sim: filtra o que é jogo e dá o nome** |
| `appcache/librarycache/<id>/` | arte de cada app (capa, hero, logo) | serve para a **capa** dos não instalados |
| `userdata/<conta>/config/localconfig.vdf` (texto) | tempo jogado por app | **não serve de lista**: só tem os apps que já foram tocados (cerca de uma dezena aqui) |
| `userdata/<conta>/config/licensecache` | licenças | **não serve**: não é legível (parece cifrado; não tentei abrir) |

**Conferi lendo os dois binários** (script Python descartável, fora do repositório; só contagens foram impressas):
- `packageinfo.vdf`: cabeçalho `0x06565528` (versão 40). Cada entrada tem `packageid`, um hash de 20 bytes, o `changenumber`, um token de 8 bytes e um valor binário (formato "KeyValues" da Valve) com a chave `appids`. Li **todos os pacotes** sem erro. Resultado: **mais de mil appids distintos** numa conta com algumas centenas de pacotes. Os 20 jogos instalados estavam **todos** dentro.
- `appinfo.vdf`: cabeçalho `0x07564429` (versão 41, com **tabela de textos no fim do arquivo**, e as chaves de cada app são índices nessa tabela). Cada app tem `common/type` e, na maioria, `common/name`. **Todos** os appids do `packageinfo` estavam no `appinfo`.
- O `type` desses appids se divide, grosso modo, em **cerca de um terço `game`**, e o resto é `dlc` (a maior parte), `tool`, `config`, `demo`, `beta`, `application` e uns sem tipo. Ou seja: **sem filtrar por `type`, a lista seria três vezes maior do que a biblioteca de verdade**, cheia de DLC e ferramentas.
- A pasta `appcache/librarycache/` tinha arte para quase todos os appids dos pacotes (823 de 825 pastas estavam na lista). Para a capa dos não instalados, o hub já sabe onde olhar (`GameArt._find_in_steam_cache`).

**Suposições:**
- Os mesmos arquivos e formatos existem no Linux, no mesmo caminho relativo (`<Steam>/appcache/`). Só conferi no Windows.
- O `packageinfo` só atualiza quando a Steam sincroniza (ao entrar na conta). Um jogo comprado agora pode demorar a aparecer, ou só aparecer depois de reabrir a Steam.
- Licenças do "Compartilhamento em família" podem ou não estar ali. Não conferi.
- Os formatos são **internos e sem contrato**: uma versão nova da Steam pode mudar o cabeçalho (o `appinfo` já ganhou a tabela de textos na versão 41). O leitor precisa **conferir a versão do cabeçalho e desligar a função** (mostrar só os instalados, sem erro na cara do usuário) quando não a reconhecer.
- Tempo de leitura em GDScript: o `appinfo` aqui tem ~4 MB e o `packageinfo` ~0,1 MB. Uma conta grande pode ter um `appinfo` bem maior. Dá para pular o corpo dos apps que a conta não tem (cada entrada diz o próprio tamanho) e ler só os da conta. **Não medi em GDScript** (a Godot não pôde abrir). Fazer numa thread (`WorkerThreadPool`, como a `GameArt`) e guardar o resultado em `user://cache/` com a data do arquivo.

Filtros que o hub **já tem** e que valem aqui: `SteamLibrary.EXCLUDED_APP_IDS`/`EXCLUDED_NAME_PARTS` (ferramentas) e `AppConfig.get_excluded_app_ids()` (o que o dono escondeu). Falta filtrar por `common/type == game`.

Categoria e capa dos não instalados: o `StoreInfo` usa `IStoreBrowseService/GetItems/v1` **sem chave** (`store_info.gd:20`), 50 apps por pedido, cache de 30 dias em `user://cache/store_info.json`. Funciona para qualquer appid, então o bairro e a capa dos não instalados vêm do mesmo caminho dos instalados.

### 1.2 Pela Steam Web API (`GetOwnedGames`)

- **O que já está pronto no hub [conferido]:** `FriendsService` guarda a chave via `AppConfig.get_web_api_key()` (`friends_service.gd:82`), usa um `HTTPRequest` com timeout de 15 s, um pedido por vez, tem `needs_key()` (estado "falta a chave", sem erro na tela) e descobre o SteamID por `SteamLibrary.get_current_steam_id()`. Falta só uma URL nova (`IPlayerService/GetOwnedGames/v1/`, hoje a constante é a de `ISteamUser/`) e o leitor da resposta.
- **O que devolve [suposição, de conhecimento geral; não chamei, porque não pude usar a chave]:** `response.games[]` com `appid`, `name`, `playtime_forever`, `rtime_last_played` e, com `include_appinfo=1`, o nome e os ícones. **Só jogos** (sem DLC e sem ferramentas), então não precisa filtrar por tipo. Com a chave e o SteamID da **própria** conta, deve devolver a lista mesmo com o perfil privado (a confirmar com a chave do dono, sem imprimi-la).
- **Custo:** um pedido só, resposta de alguns centenas de KB para uma biblioteca grande.
- **Contras:** exige a chave (hoje opcional, e quem baixa o hub não tem), exige internet, e a lista só atualiza quando se pergunta (não vem de graça como o arquivo local).

### 1.3 Recomendação

Fazer **um ponto único**, `OwnedGames` (autoload), que devolve `Array[OwnedGame]` (appid, nome) e esconde de onde veio. Ordem: **arquivos locais primeiro** (sem chave, sem internet, igual para todo mundo), **Web API só como segunda fonte** (se a leitura local falhar e houver chave). A 1ª versão faz **só a leitura local**. A Web API entra depois, se a leitura local se mostrar frágil.

Onde mora o código: o leitor binário é independente de sistema operacional (o formato é o mesmo no Linux e no Windows), então fica ao lado do `vdf.gd` (`autoload/binary_vdf.gd`, só funções estáticas), e quem decide o caminho da Steam continua sendo o `SteamClient`.

## 2. A porcentagem ao vivo

### 2.1 Campos do `appmanifest`

Conferi num `appmanifest_<id>.acf` de um jogo instalado, nesta máquina. Campos de `AppState`:
`appid`, `universe`, `LauncherPath`, `name`, `StateFlags`, `installdir`, `LastUpdated`, `LastPlayed`, `SizeOnDisk`, `StagingSize`, `buildid`, `LastOwner`, `DownloadType`, `UpdateResult`, **`BytesToDownload`**, **`BytesDownloaded`**, **`BytesToStage`**, **`BytesStaged`**, `TargetBuildID`, `AutoUpdateBehavior`, `AllowOtherDownloadsWhileRunning`, `ScheduledAutoUpdate`, e os blocos `InstalledDepots`, `UserConfig` e `MountedConfig`.

Num jogo **terminado**, os pares ficam iguais (`BytesToDownload` = `BytesDownloaded`, `BytesToStage` = `BytesStaged`) e o `StateFlags` é `4` (os 20 manifestos daqui estavam todos em `4`). **Não consegui ver um download em andamento** (nada estava baixando e não vou instalar nada para testar), então o que vem abaixo sobre o comportamento durante o download é **suposição** a confirmar com um download de verdade, de preferência de um jogo pequeno.

### 2.2 O que o hub leria

- **Porcentagem [suposição, a confirmar]:** a Steam baixa (`BytesDownloaded`/`BytesToDownload`) e depois grava no disco (`BytesStaged`/`BytesToStage`). Para uma barra só: `(baixados + gravados) / (a baixar + a gravar)`, travando em 0 se o divisor for 0.
  - O total (`BytesToDownload`) **pode crescer** no começo (a Steam descobre o tamanho aos poucos), então a barra pode voltar. Regra simples: a porcentagem mostrada **nunca diminui** (guardar o maior valor visto).
- **Estado [suposição, conhecimento comum da comunidade]:** `StateFlags` é uma máscara de bits. O `4` é "instalado". Alguns outros: `2` (precisa de atualização), `256`/`1024` (atualizando, baixando), `512` (pausado), `2048` (desinstalando), `1048576` (baixando), `2097152` (gravando). Os valores exatos que a Steam grava na fila e na pausa precisam ser **observados** num download real.
- **Quando o arquivo aparece:** a suposição é que a Steam cria o `appmanifest_<id>.acf` assim que o pedido entra na fila (com o bit 4 desligado), e que existe uma pasta `steamapps/downloading/` (conferi que existe; não vi o que há dentro).
- **De quanto em quanto tempo:** a cada **2 s, só enquanto há uma instalação pedida** (nenhum custo no resto do tempo). É um arquivo de ~1 KB. Se a leitura falhar no meio (a Steam está gravando), usa o valor anterior. **Não** ler com a Godot em pausa (o hub dorme quando um jogo abre): o `Timer` pausável do `FriendsService` mostra o padrão a copiar.

### 2.3 Fila, pausa e atualização

| Situação | O que o hub mostra [suposição] |
|---|---|
| Pedido feito, a Steam ainda não criou o manifesto | "Pedido enviado" (sem %), com um tempo limite (ex.: 60 s) e a mensagem "abra a Steam e confirme a instalação" |
| Na fila (manifesto sem bytes) | "Na fila" |
| Baixando | a porcentagem |
| Pausada (bit 512, ou os bytes param) | "Pausado" e a última porcentagem |
| Terminou (bit 4 ligado) | "Pronto": o portal vira prédio |
| **Atualização de um jogo já instalado** (bit 4 **e** bytes a baixar) | continua "pronto" (dá para jogar). Não voltar para "em obras" |
| Desinstalou (manifesto some) | o prédio volta a ser terreno |
| O dono cancelou na janela da Steam | o manifesto não aparece (ou some): o portal volta a "terreno" depois do tempo limite |

Atenção ao código de hoje: `SteamLibrary._read_manifest` (`steam_library.gd:265`) devolve `null` se o bit 4 não está ligado. Por isso um jogo em obras **não aparece** em `get_installed_games()` (bom: nada do que é "instalado" muda), e o estado da instalação precisa de uma leitura **própria** (`SteamLibrary.install_state(app_id)`), que lê o mesmo arquivo sem esse corte.

O `GameLauncher.launch` já confere `is_installed` antes de abrir, então "só abre aos 100%" já vale: o portal em obras nem chega a chamá-lo.

## 3. Pedir a instalação

- **Windows e Linux [suposição, conhecimento comum]:** o endereço `steam://install/<appid>` pede à Steam. Se a Steam está fechada, ela abre; ela mostra a **própria janela** "Instalar" (escolha do disco, atalhos, espaço) e o dono confirma lá. O hub não escolhe pasta, não baixa e não escreve em `steamapps`.
- O hub **já faz isso** para abrir jogo: `game_launcher.gd:68` guarda `url_opener = Callable(OS, "shell_open")` e chama `steam://rungameid/<id>` (linha 160). A Godot usa o abridor de endereços do sistema (no Linux, `xdg-open`). **O mesmo mecanismo serve para o `install`.** Vale conferir no Linux, mas o `rungameid` já prova que o `steam://` chega à Steam por esse caminho.
- **Regra 5 (plataforma isolada):** o `GameLauncher` chama o `shell_open` direto, fora de `autoload/platform/` (é um endereço `steam://`, igual nos dois sistemas). Para a fase ficar certinha, a proposta é uma função **`SteamClient.request_install(app_id: int) -> int`** (e um `url_opener` trocável nos testes, como o do launcher), em `autoload/platform/steam_client.gd`. O `tests/check_platform.gd` não deve reclamar.
- **O que o hub NÃO sabe** ao pedir: se o dono confirmou ou cancelou. Só descobre pelo manifesto (seção 2). Por isso o estado "Pedido enviado" e o tempo limite.
- Um jogo não instalado pode ser **de outra plataforma** (só Windows, rodando no Linux via Proton) ou **sem espaço em disco**. A janela da Steam trata os dois. O hub só mostra o que a Steam avisa por manifesto.

## 4. A cidade crescer na hora

### 4.1 Como é hoje [conferido, `city.gd`]

- A cidade é montada **uma vez**, no `_ready` (`city.gd:179`): `SteamLibrary.get_installed_games()` (linha 192) → `_update_store_info` → `_group_into_districts` → `_build_districts` → metrô, montanha, muros, clima, chão do bioma.
- `_build_districts` (linha 472) calcula `counts` (quarteirões por bairro = jogos ÷ `LOTS_PER_BLOCK`, que é 4), e chama `SectorLayout.plan(counts, focus, levels)`. A planta é **determinística**: o mesmo `counts` dá sempre a mesma planta.
- O anel `R` (o tamanho da cidade) sai de `base_ring(counts)`, **só dos quarteirões**. O que não é quarteirão do bairro vira **vaga** (`_build_vacant`, só o chão). Isso já existe e o `plan` documenta (19.9: as horas dão território, não prédio).
- Cada prédio é `Building_<app_id>` (o nome é igual para prédio e arco). Mas `_build_block` calcula o terreno (`lots_facing_center_first`) **na hora e não guarda**: não existe hoje "o terreno do jogo X".
- Quem **lê a lista de prédios uma vez** e não saberia de um prédio novo: `DistrictProps.decorate(self, categoria, cell, buildings)` (os enfeites do bairro usam fachada e néon dos prédios), `_build_landmark`, `_build_metro` (usa os portais do grupo no momento da montagem, `city.gd:654`), o `CityMap` (`add_block`) e o `BiomeBuilder` (linha 269, também por grupo).
- Quem usa o grupo **`game_portal`** (e passaria a enxergar os terrenos): a busca (Tab, `ui/game_search.gd:201`), o mural de amigos da casa (`friends_wall.gd:107`), o metrô e o bioma.
- Quem usa `get_installed_games()` e **não** deve ver os não instalados: `LibraryStats` (as horas e os níveis dos bairros), a estante da casa (`library_shelf.gd`), o relatório de feedback e a medição.

### 4.2 O risco para a planta

Se o prédio novo **precisa de um quarteirão novo**, `counts` muda, e o `SectorLayout.plan` pode:
- crescer o anel `R` (a mureta, o metrô e a montanha mudam de lugar);
- redistribuir a borda e as cunhas (todos os bairros podem andar).

Ou seja: **reconstruir a cidade a cada instalação** custa ~11 s com 200 jogos (medido, `docs/plans/fase-17.md:403`) e mexe no mundo debaixo dos pés do jogador. Não serve como regra.

### 4.3 Três caminhos

| | A) Reservar terreno para todos os possíveis | B) O bairro cresce a cada instalação | C) Só reserva o que o dono "marcou" |
|---|---|---|---|
| Planta | **estável** (conta os não instalados no `counts`) | muda a cada instalação | estável (conta só os marcados) |
| Instalar | troca o terreno pelo prédio **no mesmo lugar** | refaz tudo, ou precisa de vagas sobrando | idem A para os marcados |
| Tamanho da cidade | **cresce muito** com uma biblioteca grande (poucos instalados viram algumas centenas de jogos) | só o que se instala | controlado pelo dono |
| Risco | custo e tamanho da cidade | planta que pula (o risco que a ROADMAP quer evitar) | mais uma tela de "marcar" |

**Recomendação: A**, com o terreno **bem mais leve que um prédio** (veja seção 6), e com a decisão do dono sobre o tamanho (decisão nº 1). Com A:
- `_build_districts` passa a receber **instalados + não instalados** (cada um com `state`);
- cada terreno (`Plot_<app_id>` ou `Building_<app_id>`) fica **guardado em um dicionário** `app_id → {lote, bairro, nó}`;
- instalar vira: `city.promote_plot(app_id)` = tira o terreno, chama `_build_game_building(lote, game, bairro)` no **mesmo lote**. Uma peça por vez (já existe o `await _keep_frame_light()` para dividir quadros);
- os enfeites do bairro (`DistrictProps`) que dependem de prédios **não** se refazem (limite aceito: o enfeite fica como estava; vale conferir cada um dos 10 bairros no plano);
- o `LibraryStats` continua usando só os instalados, então o nível dos bairros (e o território) **não** pula com a instalação. Isso já está certo por construção.

A planta com A ainda **muda uma vez**, quando o dono liga a função ou compra jogo novo (a lista muda). Aceitável: acontece ao abrir o hub, não com o hub aberto.

**Um jogo novo na conta com o hub aberto** (não é o caso de instalar) fica para a abertura seguinte.

## 5. O portal em obras

### 5.1 O que o `GamePortal` é hoje [conferido, `game_portal.gd`]

Um nó que cuida da **porta** (área de entrada, carga de 1,5 s, tela escurecendo, som) e do **cartão** (`get_look_info`). A aparência é da casca (`PortalShell`, com `CityBuilding` e `ArchShell`), que escuta o sinal `charge_changed(ratio)` para acender o vão. O portal já respeita a regra 3: não sabe se está num prédio ou num arco.

### 5.2 Proposta: estado no portal, aparência na casca

Adicionar ao `GamePortal`:

```
enum State { READY, NOT_INSTALLED, INSTALLING }   # "pronto", "terreno", "em obras"
signal state_changed(state: State)
signal progress_changed(ratio: float)             # 0..1, só em INSTALLING
var state: State = READY
func set_state(new_state, ratio := 0.0) -> void
```

Regras no portal (valem para qualquer casca):
- `NOT_INSTALLED` e `INSTALLING`: a porta **não abre o jogo**. Em `_process`, o `_charge` não sobe. Estar na porta em `NOT_INSTALLED` pode pedir a instalação (ver decisão nº 3); em `INSTALLING` não faz nada.
- `get_look_info()` devolve o cartão com a ação certa: "Aperte E para instalar", "Instalando… 42%", "Entre pela porta para jogar". O `GameInfo.look_info` continua igual.
- `get_look_label()` e o cartão **usam o nome da biblioteca de posses**, não do `SteamLibrary.get_game_name` (que só conhece instalados: hoje devolveria "Jogo N (não encontrado na Steam)"). Pequeno ajuste no `GameInfo.game_name`: olhar também o `OwnedGames`.
- O grupo `game_portal` fica como está. A busca (Tab) e o mural decidem se mostram os não instalados lendo `portal.state` (decisão nº 4).

Na **casca** (a parte visual), cada casca decide como se vê em obras:
- `PortalShell` ganha o gancho `set_construction(ratio: float)` e a regra "se o estado não é `READY`, mostra o tapume em vez de, ou junto com, o prédio";
- `CityBuilding` e `ArchShell` implementam o tapume do jeito deles (o prédio sobe do chão com o `ratio`: altura da caixa × `ratio`, andaime, a capa fosca; o arco levanta as pedras). **Geometria e shader**: é trabalho de Opus, e não de modelo menor (AGENTS.md).

### 5.3 Dois jeitos de começar (o que o plano decide)

1. **O terreno é um portal** (`GamePortal` em `NOT_INSTALLED`, numa casca "terreno com tapume"): um único código para a porta, o cartão e a instalação. A casca de terreno é barata (sem hero, logo, atlas de janelas). Ao terminar, troca a casca por `_build_game_building` no mesmo lote, **reaproveitando** o portal ou criando outro.
2. **O terreno é só chão com placa**, e só o prédio tem portal. A instalação vira uma peça à parte (`PlotMarker`), que não é `GamePortal`.

Recomendação: **1**. Mantém a regra 3 inteira ("o portal é o jogo") e a busca/mural/metrô enxergam tudo pelo mesmo grupo.

## 6. O custo

### 6.1 O que **conferi** como ponto de partida
- Biblioteca falsa de 200 jogos (`tests/fake_library.gd`, `tests/check_scale.gd`): monta a cidade (`play_intro = false`), confere que cada jogo tem `Building_<id>/GamePortal`, que não houve rede (`GameArt.allow_downloads = false`) e que `user://cache` ficou intacto. **O teste não abre capas novas**: os appids vêm da pasta `appcache/librarycache`, então com a Steam cheia de capas ele é fiel; sem elas, o prédio mostra o nome.
- Desktop (Alta, 2560 × 1440), 200 jogos: **~151 FPS na caminhada (p99 12 ms)** e **~11 s** de montagem (`docs/plans/fase-17.md:403` e `fase-18.md:135`). A meta da fase 19 é não cair mais de 5% disso.

### 6.2 O que muda com a fase
- **Número de terrenos.** Uma conta com algumas centenas de jogos faz a cidade passar de ~20 prédios a **algumas centenas de portais**. A medida de referência (200 prédios completos) é do mesmo tamanho. A diferença é que o terreno deve ser **mais barato** do que o prédio: chão + tapume + uma placa com a capa. Meta: **o conjunto não ficar mais pesado que os 200 prédios completos**.
- **Capas.** Os não instalados quase sempre têm arte local (`librarycache`, seção 1.1). Para os que não têm, o `GameArt` já baixa com no máximo 4 ao mesmo tempo e anota a falha por 7 dias. A `StoreInfo` pede 50 apps por vez: algumas centenas = poucos pedidos, e fica 30 dias em cache.
- **Hero e logo** (as imagens grandes, comprimidas em S3TC): **não carregar** para terrenos. Só a capa pequena (ou nem isso, só o nome). O hero/logo carrega ao virar prédio.
- **Abertura.** A ordem de construção hoje é um quarteirão por quadro. Mais quarteirões = abertura mais longa. A medir.
- **Leitura dos binários da Steam** (seção 1.1): numa thread, uma vez por mudança do arquivo.

### 6.3 A medida do desktop
**Pendente, e é a trilha do desktop** (a meta é sempre o desktop; o notebook só compara o mesmo código antes e depois). Antes da fase, medir a base (`tools/medir_desempenho.gd`, com 0 e 200 jogos) e, depois de cada subetapa que mexe no mundo, repetir no mesmo dia e na mesma máquina. Esta trilha **não** abriu a Godot e **não** mediu nada.

## 7. Decisões que ficam para o dono

1. **Quantos terrenos?** Todos os jogos da conta, só os que ainda não foram jogados, ou só os que o dono **marcar**? É a decisão que mais pesa no tamanho da cidade. (Para o mínimo testável, a sugestão é um limite pequeno e fixo, por exemplo **10 terrenos**, até medir.)
2. **A lista vem de onde?** Arquivos locais da Steam (sem chave, mas num formato interno que pode quebrar numa atualização) ou a Web API (documentada, mas exige a chave). Sugestão: local primeiro.
3. **O que acontece ao pisar na porta de um terreno?** Instala na hora (como o jogo abre hoje), pede uma confirmação ("Instalar X? E para confirmar"), ou só mostra o cartão? Sugestão: **pedir confirmação**, porque a instalação ocupa disco e banda.
4. **A busca (Tab) e o mural de amigos mostram os não instalados?** Sugestão: a busca mostra, com a marca "não instalado"; o mural dos amigos só leva ao que está pronto.
5. **O terreno é um jogo "de verdade" no mapa e no metrô?** Sugestão: aparece no mapa com a cor apagada; o metrô não ganha parada nova.
6. **O que fazer quando a instalação some** (o dono cancela na Steam)? Sugestão: voltar a terreno sem aviso.
7. **O texto da ROADMAP** diz que a leitura do `appmanifest` fica "só em `autoload/platform/`". Mas ela é igual nos dois sistemas e hoje o `SteamLibrary` já lê manifestos. Sugestão: manter a leitura do manifesto em `SteamLibrary` (arquivo de texto da Steam, igual em todo SO) e deixar em `platform/` só o que **muda por sistema ou fala com a Steam em execução** (pedir a instalação, saber se a Steam está aberta). Confirmar, ou corrigir a ROADMAP.

## 8. A menor versão que já dá para testar

**"Um terreno que instala."** Sem a lista da conta toda e sem mexer na planta:

1. Uma configuração em `user://config.cfg` (ou uma constante de teste) com **um appid** de um jogo **pequeno** que o dono tem e não instalou.
2. A cidade ganha **um terreno** com tapume ao lado da praça (num lugar fixo), com o cartão "Instalar X?".
3. O dono confirma: o hub chama `steam://install/<id>`, a Steam mostra a janela dela.
4. O hub lê o `appmanifest` a cada 2 s e a **barra sobe no tapume** (sem animação de prédio ainda).
5. Ao chegar o bit 4, o terreno vira prédio ali mesmo.

Isso prova de uma vez: o pedido, a leitura do download real (os campos e os `StateFlags` de verdade), a troca ao vivo e o estado do portal. Não mexe na planta (o terreno fica fora dos setores), não precisa da lista da conta e não depende da decisão nº 1.

Depois dele, na ordem: a lista da conta → os terrenos em todos os bairros (decisão nº 1) → o tapume bonito (prédio subindo).

## 9. Subetapas, cortadas para duas trilhas

Regras do corte (AGENTS.md): a trilha **A** é a principal e a dona do mundo (`city.gd`, builders, `.tres`, o plano). A trilha **B** mexe só nos arquivos que o plano dá a ela, **sem `.tres` e sem `city.gd`**. O corte abaixo põe na B tudo o que é código novo, em arquivos novos, com testes próprios.

| # | Subetapa | Trilha | Tamanho | Modelo | Arquivos |
|---|---|---|---|---|---|
| 7.1 | **Observar um download de verdade** (descobrir os `StateFlags` e o comportamento da fila, da pausa e do cancelamento) num jogo pequeno; registrar as observações no plano | dono + A | pequena | Opus (com o dono) | só `docs/` |
| 7.2 | **Estado da instalação**: `SteamLibrary.install_state(app_id) -> Dictionary` (`state`, `ratio`, `paused`), com a porcentagem monotônica; `SteamClient.request_install` + `url_opener` trocável | **B** | pequena/grande (dados de teste simulados) | Sonnet | `autoload/steam_library.gd`, `autoload/platform/steam_client.gd`, `tests/check_install_state.gd` (novo) |
| 7.3 | **Acompanhar** (`InstallWatcher`, autoload ou nó): lê o manifesto a cada 2 s só com instalação ativa; sinais `progress` e `finished`; tempo limite do "pedido enviado" | **B** | pequena | Sonnet | `autoload/install_watcher.gd` (novo), `project.godot` (autoload: **a A registra**), `tests/check_install_watcher.gd` (novo) |
| 7.4 | **Leitor da lista da conta**: `BinaryVdf` (só funções estáticas), `OwnedGames` (filtro `type == game`, ferramentas, escondidos, cache em `user://cache/`, thread, desliga sem erro se o cabeçalho for desconhecido) | **B** | **grande** (formato binário, dado salvo) | Opus (ou Sonnet com revisão do Opus) | `autoload/binary_vdf.gd` (novo), `autoload/owned_games.gd` (novo), `tests/check_owned_games.gd` (novo), `tests/data/` com um `packageinfo`/`appinfo` **mínimos e inventados** (nunca o da conta do dono) |
| 7.5 | **Estado no `GamePortal`** (`State`, `set_state`, sinais, cartão com a ação certa, porta fechada fora de `READY`) e o gancho `set_construction` no `PortalShell` | **A** | **grande** (contrato entre sistemas) | Opus | `components/game_portal/game_portal.gd`, `game_info.gd`, `components/portal_shell/portal_shell.gd`, `tests/check_game_portal.gd` |
| 7.6 | **A menor versão** (seção 8): um terreno fixo na cidade, ligado ao 7.2/7.3 | **A** | grande | Opus | `worlds/city/city.gd`, um novo `worlds/city/plot_shell.gd` |
| 7.7 | **Terrenos em todos os bairros** (planta estável, `promote_plot`, o dicionário de lotes, os grupos e as leituras da seção 4.1) | **A** | **grande, de risco** (planta, revisão cruzada) | Opus (+ segundo Opus só de leitura) | `worlds/city/city.gd`, `worlds/city/sector_layout.gd`, perfis (`.tres`), `tests/check_scale.gd` |
| 7.8 | **O tapume e o prédio subindo** (prédio e arco) | **A** | grande (geometria, shader) | Opus | `worlds/city/city_building.gd`, `components/portal_shell/arch_shell.gd`, shader novo |
| 7.9 | **Ajustes de busca, mapa e mural** (marca "não instalado") | **B** | pequena | Sonnet | `ui/game_search.gd`, `worlds/home/friends_wall.gd` |
| 7.10 | **Medida no desktop** (0 e 200 jogos, com e sem os terrenos) e o checklist do dono | **A**, no desktop | pequena | Opus | `docs/` |

Dependências e ordem de integração:
- **B (7.2, 7.3, 7.4)** pode andar **em paralelo com a A (7.5)** desde o primeiro dia: os arquivos são diferentes e o contrato entre as duas é só este (combinado antes): `install_state(app_id) -> {state, ratio, paused}` e os sinais `InstallWatcher.progress(app_id, ratio)` / `finished(app_id)`.
- A **7.6** (A) espera o 7.2, o 7.3 e o 7.5. A **7.7** espera o 7.4 e a decisão nº 1. A **7.9** (B) espera o 7.5 e o 7.7.
- `project.godot` (para registrar os autoloads novos) e qualquer `.tres` ficam com a A.
- Cada trilha roda só os testes do que mudou; a bateria completa roda uma vez por merge (AGENTS.md).

Na trilha B, **nunca** pôr no prompt nada de `user://`, `config.cfg`, chave, SteamID, nome de amigo ou caminho pessoal. Os arquivos de teste da 7.4 têm de ser **inventados** (appids como `9000001...`, como o `FakeLibrary`), não cópias dos binários da Steam do dono.

## 10. Como conferi (para refazer)

- **Código lido:** `autoload/steam_library.gd`, `steam_game.gd`, `store_info.gd`, `friends_service.gd`, `game_art.gd`, `game_launcher.gd` (o trecho do `launch`), `autoload/platform/steam_client*.gd`, `components/game_portal/game_portal.gd` e `game_info.gd`, `components/portal_shell/portal_shell.gd`, `worlds/city/city.gd` (`_ready`, `_build_districts`, `_build_block`, `_build_game_building`, `_build_vacant`), o começo do `worlds/city/sector_layout.gd`, `tests/fake_library.gd` e `tests/check_scale.gd`.
- **Arquivos da Steam desta máquina (só leitura):** os nomes e os campos de um `appmanifest`, os valores de `StateFlags` dos manifestos instalados (todos `4`), o conteúdo de `appcache/` e de `userdata/<conta>/config/`, e a leitura dos dois binários com um script Python temporário (fora do repositório), que imprimiu **só contagens**. Não li o `config.cfg` do hub e não imprimi chave nem SteamID.
- **Não fiz:** abrir a Godot, medir qualquer coisa, chamar a Web API, instalar ou baixar algo, ver um download em andamento.
- **Pendências para a 7.1:** observar um download real (os `StateFlags` da fila, da pausa e do cancelamento; se o manifesto aparece na fila; o que há em `steamapps/downloading/`), conferir `steam://install/<id>` no Linux, conferir os binários no Linux e se o Compartilhamento em família entra no `packageinfo`.
