---
status: crua
versao: V1
custo: M
data: "2026-11-11"
---

<!-- status: crua | madura | virou-fase | descartada · versao: V1 a V6 · custo: P | M | G -->

## O que é
Assinar o `GameHub.exe` para o Windows parar de mostrar o aviso azul do SmartScreen ("O Windows protegeu o computador"). Veio do teste do zip da [Fase 18](../plans/fase-18.md) (18.6): o dono perguntou como tornar o `.exe` confiável em qualquer máquina.

**Decidido pelo dono (2026-11-11): quando isso virar fase, o caminho é o SignPath Foundation.** Ele assina de graça projetos de código aberto, e o repositório é público e MIT.

## Para quem / por que importa
Para o amigo que baixa o zip do Release. Hoje ele precisa ler o LEIA-ME e clicar em "Mais informações › Executar assim mesmo". Para 2 ou 3 amigos isso basta. Se o hub for para mais gente, o aviso afasta quem não conhece o dono.

O aviso só aparece em arquivo baixado da internet. No PC do dono, o zip gerado ali mesmo abre sem aviso, então o teste local não mostra o que o amigo vê.

## Menor versão que já dá para testar
- Pedir a entrada do projeto no SignPath Foundation (precisa de aprovação).
- O build do Windows passa a sair do CI do GitHub (o job `exportar` já exporta) e é assinado lá, em nome da fundação.
- Baixar o zip assinado pelo navegador num PC que nunca abriu o hub e ver se o aviso some ou muda.

## Dúvidas
- O SignPath exige que o build venha do CI. Hoje o zip do Release é feito no desktop por `tools/empacotar_windows.sh` e testado à mão. Como a trava do pacote (a conferência de chave, capas e licenças) roda no CI?
- Mesmo assinado, o aviso pode continuar por um tempo, até o certificado ganhar reputação com os downloads.
- É ferramenta nova: só entra quando virar fase, com o fluxo liberado para isso.

## Caminhos descartados
- **Certificado comprado:** algumas centenas de dólares por ano, exige um token físico, e o aviso ainda aparece até ganhar reputação.
- **Assinatura da Microsoft na nuvem (Azure Trusted Signing):** cerca de US$ 10 por mês; a disponibilidade para pessoa física fora dos EUA e do Canadá não foi conferida.
- **Microsoft Store:** sem aviso nenhum, mas pede outro formato de pacote e a revisão da loja.
