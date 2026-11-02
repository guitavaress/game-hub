# Dia de conferência no desktop

**Status:** aberto
**Decisão:** revisão da ROADMAP, 2026-11-02 (pergunta 13): as fases feitas que diziam "falta a conferência no desktop" viram este checklist único, feito num dia só.

## Para o dono
- **O que é:** uma tarde no desktop (Windows, qualidade Alta) conferindo o que ficou pendente das fases 7 a 15.
- **Como:** siga a lista na ordem e marque `[x]`. Se algo falhar, anote na linha. O agente da próxima sessão lê e corrige.
- **Fica de fora, por decisão sua:** ouvir os sons (Fase 11), a meta de 50 ms na montagem (Fase 15), a mesa com três monitores (Fase 14, em pausa) e o controle Xbox (Fase 12, conferido por você em 2026-11-02).

## Checklist

### 1. Abrir um jogo de verdade no Windows (Fase Linux)
- [ ] Abra o hub, ande até a porta de um jogo instalado e segure E.
  - Deve acontecer: a tela escurece, o hub some e o jogo abre pela Steam.
- [ ] Feche o jogo.
  - Deve acontecer: o hub volta sozinho, na mesma porta.

### 2. Desempenho na Alta (fases 8 a 13)
- [ ] Feche navegador e vídeos e rode no terminal, na pasta do projeto:
  `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . -s tools/medir_desempenho.gd -- 200 alta 22`
  - Deve acontecer: abre uma janela, a câmera anda sozinha e o terminal imprime as linhas `MEDIDA`, `MEDIDA_CASA`, `MEDIDA_ESPELHO` e a da trilha.
- [ ] Cole as linhas no fim deste arquivo. O agente compara com a Fase 15 (caminhada: 145 FPS e p99 de 13 ms na Alta).

### 3. Olhar com calma (fases 7, 9, 10 e 13)
- [ ] **Bordas na Alta** (Fase 10): prédios e postes ao longe sem serrilhado.
- [ ] **Garoa do Terror à noite** (Fase 7): pause, coloque a hora em Noite e entre no bairro Terror. Deve cair uma garoa leve só lá dentro.
- [ ] **Casa** (fases 9 e 13): troque loft ↔ cabana pelo computador da casa e olhe no espelho. A troca é na hora, e o espelho mostra o seu avatar.

### 4. Opcional: comparação no notebook (Fase 15)
- [ ] Só se o notebook estiver à mão: a mesma medida na Leve, na versão de antes da Fase 15 (`ed834cd`) e na de agora, no mesmo dia. Serve só para comparar; o notebook nunca é meta.

## Resultados
(cole aqui as linhas da medida e o que deu errado)
