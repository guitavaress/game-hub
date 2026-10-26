# Fase 15.15b — rascunho do README e do ROADMAP

Este arquivo é um rascunho para a 15.15c. Ele não muda o status da fase: a
trilha A confere os pontos marcados, aplica o texto final e registra as medidas.

## README — o que mudou para o usuário

### Fase 15: Primeiro bioma, o bairro RPG na montanha [confirmar na 15.15c]

O bairro RPG agora é uma montanha nevada dentro da própria cidade. Os jogos
continuam no chão plano, mas o asfalto virou neve com calçada de pedra e os
prédios viraram arcos de pedra que mostram a capa de cada jogo. Há pinheiros,
rochas, neve caindo, névoa, vento e passos na neve.

Atrás do bairro, fora da mureta da cidade, começa a montanha. Uma trilha passa
por uma abertura na mureta e sobe até um mirante com a torre do RPG
[A PREENCHER: confirmar mirante e torre da 15.10]. A cidade também passou a ser
organizada em setores: cada bairro ocupa uma fatia contínua, da praça até sua
própria borda, preparada para ter seu bioma.

**Como testar:** abra `worlds/city/city.tscn` e aperte **F6**; vá ao bairro
RPG, encontre a abertura na mureta e suba a trilha. Aperte **M** para conferir
no mapa as fatias dos bairros. [confirmar na 15.15c]

**Créditos a acrescentar no README:** no item de Kenney, citar também os passos
na neve `footstep_snow_000` a `footstep_snow_004`, do pacote Impact Sounds,
CC0. Os demais assets da Fase 15 já aparecem nos créditos: `Snow010A` e
`Rock058` (ambientCG), `moon_rock_02` e `fir_sapling_medium` (Poly Haven, com
o pinheiro gerado como impostor); todos CC0.

## ROADMAP — texto para a Fase 15

### Fase 15: Primeiro bioma, o bairro RPG na montanha [confirmar na 15.15c]

**Versão:** V3. **Onde testar:** notebook (Leve) + desktop (Alta).

**O que entregou:** o bairro RPG prova que a biblioteca pode decidir o mundo.
Os portais ficaram no chão plano nevado, com calçada de pedra, arcos que usam a
capa do jogo, pinheiros e rochas; há neve, névoa, vento e passos próprios.
Atrás do setor do RPG, uma montanha feita por código tem uma trilha caminhável
até o mirante e a torre do bairro [A PREENCHER: confirmar entrega da 15.10].
Todos os bairros agora ocupam setores contínuos da praça até a borda, sem mudar
seus jogos, variantes ou decoração.

**Medida:** [A PREENCHER: resultado da medida no desktop, Alta, incluindo
resolução, hardware, 0/200 jogos, montagem, caminhada, subida e giro no
mirante; confirmar o pior quadro de até 50 ms]. No notebook (Leve), a medida é
apenas uma comparação antes/depois, sem virar meta [A PREENCHER: resultado ou
pendência].

**Falta fora da fase:** a pendência de desempenho no desktop, se houver, entra
na **Trilha do desktop**. Ela também mantém a medida da mesa da Fase 14 na
Alta, as conferências pendentes de Windows, controle e som das fases anteriores
e a luz que depende dessas medidas. Ajustes escolhidos na revisão visual da
15.13 que não entrarem aqui seguem para a Fase 16 ou para a Trilha do desktop
[confirmar na 15.15c].

### Ajuste da tabela de versões

Na tabela inicial do ROADMAP, trocar a linha V3 por:

| **V3** Mundo dinâmico | Biomas e arquitetura gerados a partir dos jogos | 🟡 primeiro bioma na [Fase 15](#fase-15-primeiro-bioma-o-bairro-rpg-na-montanha); mais biomas e escolhas pela biblioteca na [Fase 16](#fase-16-biomas-pela-biblioteca) |

### Complemento da Trilha do desktop

Acrescentar em **Conferências pendentes**:

- **Fase 15:** a medida da montanha na Alta, caso não tenha sido concluída na
  15.15c (pior quadro da montagem até 50 ms, caminhada, subida e giro no
  mirante, com 0 e 200 jogos); o notebook Leve continua sendo só comparação.
- Os ajustes visuais ou de desempenho da revisão 15.13 que o dono não escolher
  para a Fase 16 [confirmar na 15.15c].

### Encaminhamento para a Fase 16

A Fase 16 continua responsável pelos outros biomas (floresta, pista e
garagens, neblina e abandono), pelo crescimento do bairro com as horas jogadas
e pela escolha do bioma no `config.cfg`. Ela também recebe, se aprovado, o que
sobrar da revisão visual da 15.13 e fizer mais sentido como evolução de biomas,
não como medida do desktop [confirmar na 15.15c].

## Lacunas para a trilha A preencher na 15.15c

- [A PREENCHER: números completos da medida no desktop Alta e comparação no
  notebook Leve, ou a pendência explícita na Trilha do desktop].
- [A PREENCHER: confirmação de que a 15.9.2 e a 15.9.3 concluíram terreno,
  percurso, limites, sinalização e material da trilha].
- [A PREENCHER: confirmação do mirante e da torre da 15.10, incluindo a vista
  voltada para a praça].
- [A PREENCHER: resultado da 15.14 para terreno e enfeites nas qualidades Leve
  e Alta].
- [A PREENCHER: ajustes visuais escolhidos na 15.13, inclusive névoa, vento,
  céu noturno e a decisão de destino para cada ajuste].
- [A PREENCHER: aprovação do dono para as capturas finais dos três pontos, de
  dia, pôr do sol e noite].
- [A PREENCHER: revisão adversarial do Astra da 15.7, ainda pendente no plano].
