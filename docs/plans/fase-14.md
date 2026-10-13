# Fase 14: Consolidação

**Status:** em andamento; plano aprovado no pedido de implementação de 2026-10-12.
**Branch:** `fase-14` (partiu de `fase-linux`). Trilha única, sem worktrees.

## Contexto
Consolidar as fases 1–13 antes de aplicativos e biomas: testes confiáveis,
isolamento dos dados pessoais, câmera estável e medições da abertura normal.
Os contratos de GameLauncher, SteamClient, WindowHost e GamePortal permanecem.
Direção: [ROADMAP](../ROADMAP.md).

## Pronto quando
- Importação com erro, saída não zero, timeout depois de sucesso e resultado ausente reprovam; logs completos e testes pulados ficam identificados.
- Bateria determinística sem Steam nem rede, com dados temporários, independente de tema/qualidade pessoais; retratos existentes preservados.
- Mola limitada e em repouso a 10/15/30/60/120 FPS e quadros de 100–250 ms.
- Launcher cobre sucesso, cancelamento, timeout, saída rápida e nova tentativa do mesmo jogo com consulta anterior pendente.
- CI executa a bateria em Linux/Windows. Medidor separa abertura, caminhada, casa, espelho e suspensão; registra resolução, qualidade, p99 e memória.
- Conferência no desktop concluída: Ryzen 5 5600, RTX 4070, 32 GB, 1440p/60 FPS, Alta, biblioteca real e 200 jogos; p99 inicial ≤25 ms na navegação e pior quadro ≤50 ms na montagem, com primeira execução e cache aquecido separados.

## Decisões de arquitetura
- Dados de teste e substitutos de integração ficam em `tests/`; nenhum mundo recebe lógica de Steam.
- Solução analítica criticamente amortecida para a câmera; sensação a 60 FPS preservada por limites de amplitude/retorno.
- Integração real, controle físico, áudio percebido e desempenho com janela continuam conferências separadas.

## Subetapas
- [ ] **14.1 Runner confiável**: status do processo, timeout, contrato uniforme, pulados e logs; teste do runner com executável falso. Manual: abrir logs de uma falha. Commit: `Fase 14.1: tornar o runner confiável`.
- [ ] **14.2 Testes isolados**: dados temporários, biblioteca e imagens sintéticas, corrigir retrato e coordenadas, regressão de consultas pendentes do launcher. Manual: rodar com preferências pessoais diferentes e conferir preservação. Commit: `Fase 14.2: isolar a bateria da Steam e das preferências`.
- [ ] **14.3 Câmera estável**: mola analítica e quedas de FPS. Manual: andar/pular com limites de FPS. Commit: `Fase 14.3: estabilizar a mola de pouso`.
- [ ] **14.4 CI ampliada**: bateria determinística nos dois sistemas e logs como artefatos. Manual: ler resultado dos jobs após push autorizado. Commit: `Fase 14.4: ampliar a bateria na CI`.
- [ ] **14.5 Medições completas**: abertura normal, suspensão, contexto da medida e investigação do encerramento. Manual: executar com janela, notebook na tomada e sem programas pesados (avisar antes); desktop pendente. Commit: `Fase 14.5: medir abertura e suspensão do hub`.
- [ ] **14.6 Fechamento documental**: resultados, referências e fases futuras 14–18 renumeradas para 15–19. Manual: navegar README/roadmap/planos. Commit: `Fase 14.6: registrar a consolidação e as conferências pendentes`.

Cada commit exige bateria inteira com `RESULTADO GERAL: TUDO OK`. Se a primeira
subetapa continuar bloqueada por falhas conhecidas, corrigir a 14.2 no diretório
antes de registrar os commits separados, sem declarar uma árvore intermediária validada.

## Riscos e fora do escopo
- Sem desktop/Windows/controle físico não se encerra a fase; implementação não significa validação no hardware alvo.
- Sem novos assets, aplicativos, biomas ou acabamento visual. Busca direta por dados e movimento reduzido ficam para planos posteriores.
- Mudanças locais anteriores (`project.godot`, `AGENTS.md`, `docs/GUIA_TECNICO.md`, `nimbalyst-local/`) preservadas e fora dos commits.

## Decisões tomadas durante a fase
- 2026-10-12: autorização veio do plano fornecido pelo dono; não é necessário novo pedido de aprovação do plano.

## Checklist manual de encerramento
1. Editor → Game → ⋮ → desmarcar Embed Game on Next Play; F5.
2. Casa, Tab, M, metrô e espelho com teclado e controle.
3. Abrir/fechar jogo: voltar ao lugar correto, com foco e mouse funcionando.
4. Repetir Windows/Linux; ouvir com fones e caixas; medir no desktop nas condições acima.
