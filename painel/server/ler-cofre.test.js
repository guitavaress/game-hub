// Teste do leitor do cofre contra o docs/ de verdade.
// Rodar: npm test (no contêiner ou na máquina, com o Node 22+).
// Ele confere a forma dos dados, não números que mudam a cada dia.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { lerCofre, lerGantt, lerPlano, textoPuro } from './ler-cofre.js';

const aqui = dirname(fileURLToPath(import.meta.url));
const DOCS = resolve(process.env.DOCS || join(aqui, '..', '..', 'docs'));
const cofre = lerCofre(DOCS);

test('acha as fases e exatamente uma em andamento', () => {
  assert.ok(cofre.fases.length >= 10, `só ${cofre.fases.length} fases`);
  const emAndamento = cofre.fases.filter((f) => f.situacao === 'andamento');
  assert.equal(emAndamento.length, 1);
  assert.equal(cofre.faseAtual, emAndamento[0].arquivo);
  const atual = emAndamento[0];
  assert.ok(atual.numero, 'a fase atual tem número');
  assert.ok(atual.total > 0 && atual.feitas <= atual.total);
  assert.ok(atual.paraODono.length > 0, 'o bloco "Para o dono" foi lido');
});

test('as subetapas têm id, nome e hash quando feitas', () => {
  const f17 = cofre.fases.find((f) => f.numero === '17');
  assert.ok(f17, 'a Fase 17 existe');
  const s = f17.subetapas.find((x) => x.id === '17.4');
  assert.ok(s && s.feita && s.nome.startsWith('Objetos da casa'));
  assert.equal(s.tamanho, 'grande');
  assert.ok(s.hashes.includes('b4a68f2'));
});

test('lê o ROADMAP: versões, próximas fases, parados e feito', () => {
  const { versoes, proximas, parados, feito, produto, horizonte } = cofre.roadmap;
  assert.deepEqual(
    versoes.map((v) => v.id),
    ['V1', 'V2', 'V3', 'V4', 'V5', 'V6'],
  );
  assert.equal(versoes[0].situacao, 'feita');
  assert.ok(proximas.length >= 3 && proximas[0].objetivo);
  assert.ok(parados.length >= 3 && parados[0].porQue);
  assert.ok(feito.length >= 10);
  assert.equal(produto.length, 3);
  assert.ok(horizonte.some((h) => h.titulo));
});

test('lê a visão do ROADMAP: frase, pilares e o fluxo', () => {
  const { visao } = cofre.roadmap;
  assert.match(visao.frase, /launcher/);
  assert.equal(visao.pilares.length, 3);
  assert.ok(visao.pilares.every((p) => p.titulo && p.texto));
  const nomes = visao.fluxo.map((p) => p.nome);
  assert.equal(nomes[0], 'Steam');
  assert.equal(nomes.at(-1), 'Game Hub');
  assert.ok(visao.fluxo.find((p) => p.nome === 'perfil do mundo').nota.includes('bioma'));
});

test('a linha do tempo do Início vira barras com datas', () => {
  const g = cofre.inicio.gantt;
  assert.ok(g.length >= 15);
  assert.ok(g.every((t) => /^\d{4}-\d{2}-\d{2}$/.test(t.inicio) && t.fim >= t.inicio));
  assert.ok(g.some((t) => t.estado === 'andamento'));
  assert.ok(g.some((t) => t.semData));
  assert.ok(cofre.inicio.agora.length > 0);
});

test('gantt: "after" e duração em dias', () => {
  const g = lerGantt('```mermaid\ngantt\n  section A\n  Um :done, a, 2026-01-01, 2026-01-05\n  Dois :b, after a, 3d\n```');
  assert.equal(g.length, 2);
  assert.equal(g[1].inicio, '2026-01-05');
  assert.equal(g[1].fim, '2026-01-08');
  assert.equal(g[0].estado, 'feita');
});

test('ideias com status e resumo; tarefas fora dos blocos de código', () => {
  assert.ok(cofre.ideias.length >= 1);
  assert.ok(cofre.ideias.every((i) => i.status && i.titulo));
  // plans/README.md tem "- [ ]" só dentro do modelo (bloco de código): não pode aparecer.
  assert.ok(!cofre.tarefas.some((t) => t.arquivo === 'plans/README.md'));
  assert.ok(cofre.tarefas.some((t) => t.arquivo === 'plans/conferencia-desktop.md'));
});

test('documentos: nada da .obsidian, de _modelos nem de referencias', () => {
  assert.ok(cofre.docs.length >= 20);
  assert.ok(cofre.docs.every((d) => !/(^|\/)(\.obsidian|_modelos|referencias)\//.test(d.arquivo)));
  assert.ok(cofre.docs.some((d) => d.arquivo === 'Início.md'));
});

test('arquivo que não existe não quebra', () => {
  const p = lerPlano(DOCS, join(DOCS, 'plans', 'nao-existe.md'));
  assert.equal(p.subetapas.length, 0);
  assert.equal(textoPuro('**a** [b](c.md) `d`'), 'a b d');
});
