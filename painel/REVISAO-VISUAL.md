# Fechamento do redesenho V1–V6

Revisão em 2026-11-07, na branch `fase-17`. Escopo: concluir a implementação existente do painel, preservar a direção aprovada e todas as alterações anteriores. Nenhuma alteração no mundo da Godot ou nos documentos do cofre.

## Resultado visual

A abertura apresenta o horizonte ilustrado, as três etapas do produto e o quadro V1–V6. Versões feitas e futuras se distinguem por imagem, texto e selo; o andamento leva à próxima subetapa. Navegação superior, Sora/Manrope/Literata e temas escuro/claro foram preservados.

A revisão independente considerou a direção e a composição compatíveis com `PRODUCT.md` e o contrato em `.impeccable/surfaces/src-app-jsx.md`. Trata-se de uma implementação guiada pelo código e pelo esboço escolhido pelo dono; não havia comp aprovada para comparação pixel a pixel nem QUALITY BAR card no estado persistido.

## Validação no navegador

Chrome em modo headless, com perfil temporário separado, contra o painel real no Docker em `http://localhost:4170`. O navegador integrado não iniciou por falha na configuração de seu sandbox; a alternativa foi um Chrome local de teste.

| Verificação | Resultado |
|---|---|
| Desktop 1440 × 1000, escuro e claro | Abertura, versões e controles renderizados; imagens carregadas |
| Intermediário 1024 × 900 | Três colunas e navegação recolhida |
| Pequeno 390 × 844 e 320 × 844 | Duas colunas, leitura e menu sem transbordamento horizontal da página |
| Página inteira, desktop e 390 px | Todas as seções capturadas após percorrer a página e concluir as entradas de animação |
| Busca Ctrl+K e `/` | Abre, aceita texto, navega com setas e abre resultado com Enter |
| Busca sem resultado | Mensagem de recuperação visível |
| Leitor desktop e móvel | Documento, links, tabelas e ações renderizados |
| Menu móvel | Abre, navega para Rumo e recolhe |
| Teclado após correção | 80 Tab e 80 Shift+Tab no leitor, 20 de cada na busca, sem fuga de foco |
| Fechamento | Esc funciona inclusive no resultado da busca; foco retorna ao controle anterior |
| Movimento desligado manualmente | Contador mostra o valor final, sem valores intermediários observados |
| Reduzir movimento do sistema | Preferência reconhecida; zero animações em execução ao final da estabilização |
| Dados ao vivo | Canal SSE conectado e indicador “Ao vivo” visível |
| Console no percurso final | Sem erros registrados |

As capturas e os registros de automação ficaram fora do repositório, em `%TEMP%/game-hub-painel-v1-v6-qa/`. Os valores do git variaram entre capturas porque o projeto continuou recebendo commits. Um registro intermediário contém a desconexão esperada do SSE durante a recriação do contêiner; a rodada posterior não registrou erros.

O escopo desta validação é Chrome com tamanhos emulados. Não certifica Firefox, Safari, leitor de tela, toque em aparelho físico ou desempenho. O canal ao vivo foi observado sem editar o cofre para simular eventos.

## Ajustes da revisão independente

1. **Teclado nos diálogos:** criado `useDialogo.js`, compartilhado pela busca e pelo leitor. Tab e Shift+Tab circulam no diálogo da frente; Esc fecha em qualquer elemento; o foco é restaurado. Cabeçalho e conteúdo de fundo recebem `inert` enquanto há diálogo aberto.
2. **Contadores:** o `animate()` imperativo passou a respeitar `MotionConfigContext`, além da preferência do sistema. Desligar as animações também interrompe a contagem animada.

Veredito inicial: `fix`, com esses dois itens. Veredito após o lote e as recapturas: **`ship`**, ambos `resolved`, `remaining: clear`. A segunda avaliação cobre os ajustes listados; não representa uma nova auditoria irrestrita de toda a aplicação.

## Verificações de código e imagens

- `npm test`: 9 testes passaram.
- `npm run build`: passou após as correções.
- `docker compose -f compose.yaml up -d --build`: imagem recompilada e contêiner atualizado.
- `git diff --check`: sem erros de espaços.
- Detector Impeccable, uma execução manual sobre `src/` e `index.html`: `[]`, nenhum finding. Os hooks do Claude não rodam nesta sessão do Codex.
- `impeccable embed-prompt --scan public`: 8 rasters, 0 sem proveniência. Os sete WebP da visão mantêm seus arquivos `.webp.json` de origem/prompt.

O sistema reutilizável está em `DESIGN.md` e `.impeccable/design.json`; a composição desta página permanece no surface brief. O README foi atualizado para descrever o painel entregue.

## Teste manual curto

1. Abra `http://localhost:4170` e confira V1–V6 e a próxima subetapa.
2. Alterne claro/escuro; desligue as animações e confira os números estáveis.
3. Aperte Ctrl+K, busque um documento, navegue com setas e abra com Enter. Use Tab, Shift+Tab e Esc: o foco deve ficar no diálogo e voltar ao fechar.
4. Estreite a janela e abra “Seções”; escolha Rumo e depois uma versão para ler o ROADMAP.

Para eventuais ajustes após o teste do dono, continue nesta sessão do Codex com o modelo e esforço atuais. Prompt: “Use Impeccable para ajustar o ponto observado no redesenho V1–V6. Leia REVISAO-VISUAL.md e DESIGN.md, preserve as demais alterações e valide só o fluxo afetado.” Não há trilha paralela ativa nem nova fase da Godot autorizada por este fechamento.
