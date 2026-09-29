# Planos das fases

Cada fase do [roadmap](../ROADMAP.md) ganha um plano aqui **antes** de qualquer código:

- o arquivo se chama `fase-N.md` (por exemplo, `fase-7.md`);
- ele é escrito no modo plan (Opus) e **aprovado pelo dono**;
- depois disso, a execução segue o plano (Sonnet).

Se durante a execução aparecer uma decisão de arquitetura que o plano não previa, ou o mesmo erro se repetir duas vezes, volta-se ao modo plan e o arquivo é atualizado.

## Modelo

Copie o bloco abaixo para um `fase-N.md` novo e preencha.

```markdown
# Fase N: <nome>

## Contexto
Por que esta fase existe, o que ela resolve e como fica o hub quando ela acabar.

## Passos
1. <passo>: arquivos que mudam ou são criados.
2. ...
(Um commit por passo testável.)

## Verificação
- Import e editor da Godot sem erros (modo headless).
- Testes automáticos, se houver.
- Capturas de tela, se a mudança for visual.

## Checklist de teste manual
1. O que abrir.
2. O que apertar.
3. O que deve acontecer.

## Mensagem de commit
`<mensagem sugerida>`
```
