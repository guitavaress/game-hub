---
status: crua
versao: V3
custo: P
data: "2026-11-14"
---

<!-- status: crua | madura | virou-fase | descartada · versao: V1 a V6 · custo: P | M | G -->

## O que é
Na cabana, quando chove na cidade, o vidro da janela mostra **neve** em vez de chuva: flocos brancos caindo devagar e de lado, e flocos grudados no vidro, sem gota escorrendo. Veio da [19.6.1](../plans/fase-19.md) (a janela na chuva), que fez a chuva no vidro das duas casas.

## Para quem / por que importa
A cabana é a casa da montanha, e na montanha a chuva da cidade vira neve. Hoje a janela dela mostra a chuva, porque o retrato que ela mostra é o da cidade.

## Menor versão que já dá para testar
- Um campo no perfil da casa (ex.: `rain_kind`: `chuva` ou `neve`), lido pela casa e passado ao shader da janela como um número.
- No `home_window.gdshader`: com neve, os riscos ficam curtos, brancos e lentos, com balanço de lado; as gotas paradas viram flocos (sem a lente); não há gota escorrendo.
- O `cabana.tres` muda pelo gerador (`gerar_cabana.gd`), nunca à mão.

## Dúvidas
- A vista da cabana mostra a cidade (que chove). Neve no vidro com chuva na vista pode ficar estranho; talvez só valha junto com a [janela de verdade](../ROADMAP.md#5-a-janela-de-verdade).

## Caminhos descartados
- Nenhum por enquanto.
