// Lê o cofre (docs/) e monta um único objeto com tudo o que o painel mostra.
// Regra: nunca quebrar. O que não for achado vira lista vazia ou null.
// Só lê arquivos; não escreve nada em lugar nenhum.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, sep, basename } from 'node:path';

// Pastas do cofre que o painel ignora: config do Obsidian, imagens coladas,
// modelos de nota e as capturas de referência (podem ter capas de jogos).
const PASTAS_IGNORADAS = new Set(['.obsidian', '_anexos', '_modelos', 'referencias', '.claude', 'node_modules', '.trash']);

// ---------- utilidades ----------

function lerTexto(caminho) {
  try {
    return readFileSync(caminho, 'utf8').replace(/\r\n/g, '\n');
  } catch {
    return '';
  }
}

// Caminho relativo ao cofre, sempre com "/" (no Windows o sep é "\").
function rel(raiz, caminho) {
  return relative(raiz, caminho).split(sep).join('/');
}

// Lista todos os .md do cofre, pulando as pastas ignoradas.
export function listarMarkdown(raiz) {
  const saida = [];
  const andar = (pasta) => {
    let itens = [];
    try {
      itens = readdirSync(pasta, { withFileTypes: true });
    } catch {
      return;
    }
    for (const item of itens) {
      if (item.isDirectory()) {
        if (!PASTAS_IGNORADAS.has(item.name)) andar(join(pasta, item.name));
      } else if (item.isFile() && item.name.toLowerCase().endsWith('.md')) {
        saida.push(join(pasta, item.name));
      }
    }
  };
  andar(raiz);
  return saida.sort();
}

// Divide o texto em linhas marcando quais estão dentro de blocos de código (```).
function linhasComCodigo(texto) {
  let dentro = false;
  let lingua = '';
  return texto.split('\n').map((linha) => {
    const cerca = linha.match(/^\s*```(\S*)/);
    if (cerca) {
      const abrindo = !dentro;
      dentro = !dentro;
      lingua = abrindo ? cerca[1] : '';
      return { linha, codigo: true, cerca: true, lingua: abrindo ? cerca[1] : '' };
    }
    return { linha, codigo: dentro, cerca: false, lingua: dentro ? lingua : '' };
  });
}

// Pega o trecho de uma seção "## Título" até a próxima seção do mesmo nível ou maior.
function secao(texto, titulo, nivel = 2) {
  const linhas = linhasComCodigo(texto);
  const marca = '#'.repeat(nivel) + ' ';
  let inicio = -1;
  for (let i = 0; i < linhas.length; i++) {
    const { linha, codigo } = linhas[i];
    if (codigo) continue;
    if (inicio < 0) {
      if (linha.startsWith(marca) && linha.slice(marca.length).trim().toLowerCase().startsWith(titulo.toLowerCase())) {
        inicio = i + 1;
      }
    } else {
      const m = linha.match(/^(#{1,6}) /);
      if (m && m[1].length <= nivel) {
        return linhas.slice(inicio, i).map((l) => l.linha).join('\n');
      }
    }
  }
  return inicio < 0 ? '' : linhas.slice(inicio).map((l) => l.linha).join('\n');
}

// Lê uma tabela markdown (a primeira do trecho) como lista de listas de células.
function tabela(trecho) {
  const linhas = trecho.split('\n').filter((l) => l.trim().startsWith('|'));
  if (linhas.length < 2) return [];
  return linhas
    .filter((l) => !/^\s*\|[\s:|-]+\|\s*$/.test(l)) // a linha |---|---|
    .slice(1) // o cabeçalho
    .map((l) =>
      l
        .trim()
        .replace(/^\|/, '')
        .replace(/\|$/, '')
        .split('|')
        .map((c) => c.trim()),
    );
}

// Itens de lista do primeiro nível ("- texto"), juntando as linhas de continuação.
function itensDeLista(trecho) {
  const itens = [];
  for (const linha of trecho.split('\n')) {
    if (/^- /.test(linha)) itens.push(linha.slice(2).trim());
    else if (/^\s{2,}\S/.test(linha) && itens.length && !/^\s*- /.test(linha)) itens[itens.length - 1] += ' ' + linha.trim();
  }
  return itens;
}

// Tira a marcação do markdown, para a busca e os resumos.
export function textoPuro(md) {
  return md
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/[*_`>#|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function frontmatter(texto) {
  const m = texto.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!m) return { dados: {}, corpo: texto };
  const dados = {};
  for (const linha of m[1].split('\n')) {
    const kv = linha.match(/^([\w-]+):\s*(.*)$/);
    if (kv) dados[kv[1]] = kv[2].replace(/^["']|["']$/g, '').trim();
  }
  return { dados, corpo: texto.slice(m[0].length) };
}

function primeiroParagrafo(trecho) {
  const blocos = trecho
    .replace(/<!--[\s\S]*?-->/g, '')
    .split(/\n\s*\n/)
    .map((b) => b.trim())
    .filter(Boolean);
  return blocos[0] || '';
}

// ---------- planos das fases ----------

function situacaoDaFase(status) {
  const s = status.toLowerCase();
  if (s.includes('em andamento')) return 'andamento';
  if (s.includes('reaberta')) return 'reaberta';
  if (s.includes('concluída') || s.includes('feita')) return 'feita';
  if (s.includes('em planejamento')) return 'planejamento';
  if (s.includes('aprovado')) return 'aprovada';
  return 'outra';
}

// Uma linha de subetapa: "- [x] **17.4 Objetos da casa** (`b4a68f2`) (grande · trilha A, ...) — texto"
function lerSubetapa(linha, numeroLinha) {
  const m = linha.match(/^- \[( |x|X)\] \*\*([^*]+)\*\*(.*)$/);
  if (!m) return null;
  const titulo = m[2].trim();
  const resto = m[3];
  const idm = titulo.match(/^([\w.]+(?:\.\d+)*[a-z]?)\s+(.*)$/);
  const id = idm ? idm[1] : '';
  const nome = idm ? idm[2] : titulo;
  const grupos = [...resto.matchAll(/\(([^()]*(?:\([^()]*\)[^()]*)*)\)/g)].map((g) => g[1]);
  let tamanho = '';
  for (const g of grupos) {
    const t = g.match(/^(grande|pequena|só de docs|só docs)/i);
    if (t) {
      tamanho = t[1].toLowerCase();
      break;
    }
  }
  const hashes = [...resto.matchAll(/`([0-9a-f]{7,10})`/g)].map((h) => h[1]);
  const riscado = /~~/.test(titulo);
  return { id, nome: nome.replace(/~~/g, ''), feita: m[1].toLowerCase() === 'x', tamanho, hashes, riscada: riscado, linha: numeroLinha };
}

export function lerPlano(raiz, caminho) {
  const texto = lerTexto(caminho);
  const arquivo = rel(raiz, caminho);
  const titulo = (texto.match(/^# (.+)$/m) || [, basename(caminho, '.md')])[1].trim();
  const ehFase = /^plans\/fase-/.test(arquivo);
  let numero = '';
  let nome = titulo;
  const tm = titulo.match(/^Fase\s+(\d+|Linux)\s*:\s*(.+)$/i);
  if (tm) {
    numero = tm[1];
    nome = tm[2].trim();
    nome = nome.charAt(0).toUpperCase() + nome.slice(1);
  }
  const status = (texto.match(/^\*\*Status:\*\*\s*(.+)$/m) || [, ''])[1].trim();
  const branch = (texto.match(/^\*\*Branch:\*\*\s*`([^`]+)`/m) || [, ''])[1];

  const subetapas = [];
  linhasComCodigo(texto).forEach(({ linha, codigo }, i) => {
    if (codigo) return;
    const s = lerSubetapa(linha, i + 1);
    if (s) subetapas.push(s);
  });
  const validas = subetapas.filter((s) => !s.riscada);
  const paraODono = itensDeLista(secao(texto, 'Para o dono'));

  return {
    arquivo,
    titulo,
    numero,
    nome,
    ehFase,
    status: status.replace(/\*\*/g, ''),
    situacao: situacaoDaFase(status),
    branch,
    paraODono,
    subetapas,
    feitas: validas.filter((s) => s.feita).length,
    total: validas.length,
  };
}

// ---------- ROADMAP ----------

function situacaoDaVersao(texto) {
  if (texto.includes('✅')) return 'feita';
  if (texto.includes('🟡')) return 'parcial';
  if (texto.includes('🔜')) return 'proxima';
  if (texto.includes('⏸')) return 'parada';
  return 'horizonte';
}

export function lerRoadmap(texto) {
  const produto = tabela(secao(texto, 'O caminho do produto', 3)).map(([etapa, paraQuem, chegaQuando]) => ({
    etapa,
    paraQuem,
    chegaQuando,
  }));

  const versoes = tabela(secao(texto, 'As versões da visão', 3)).map(([versao, oQue, situacao]) => {
    const m = (versao || '').match(/\*\*(V\d)\*\*\s*(.*)/);
    return {
      id: m ? m[1] : versao,
      nome: m ? m[2].trim() : '',
      oQue: oQue || '',
      situacao: situacaoDaVersao(situacao || ''),
      texto: (situacao || '').replace(/^(✅|🟡|🔜|⏸️|⏸)\s*/u, ''),
    };
  });

  const blocoProximas = secao(texto, 'Próximas fases');
  const proximas = [];
  const partes = blocoProximas.split(/^### /m).slice(1);
  for (const parte of partes) {
    const [cab, ...corpo] = parte.split('\n');
    const m = cab.match(/^(\d+)\.\s*(.+)$/);
    const corpoTexto = corpo.join('\n');
    const objetivo = (corpoTexto.match(/\*\*Objetivo:\*\*\s*([^\n]+)/) || [, ''])[1].trim();
    const pronto = (corpoTexto.match(/\*\*Pronto quando:\*\*\s*([^\n]+)/) || [, ''])[1].trim();
    const entregas = itensDeLista(corpoTexto);
    proximas.push({ n: m ? Number(m[1]) : proximas.length + 1, titulo: m ? m[2].trim() : cab.trim(), cabecalho: cab.trim(), objetivo, prontoQuando: pronto, itens: entregas });
  }

  const parados = tabela(secao(texto, 'Parados')).map(([oQue, porQue]) => ({ oQue, porQue }));
  const feito = tabela(secao(texto, 'Feito')).map(([fase, entregou, plano]) => ({ fase, entregou, plano }));
  const horizonte = itensDeLista(secao(texto, 'Horizonte')).map((item) => {
    const m = item.match(/^\*\*([^*]+?):?\*\*:?\s*(.*)$/);
    return m ? { titulo: m[1].replace(/:$/, ''), texto: m[2] } : { titulo: '', texto: item };
  });
  const decisoes = itensDeLista(secao(texto, 'Decisões registradas'));

  return { visao: lerVisao(texto), produto, versoes, proximas, parados, feito, horizonte, decisoes };
}

// A seção "Visão" do ROADMAP, antes do primeiro "###": a frase, os pilares,
// o parágrafo do "uau" e o fluxo do bloco de código (Steam → … → Game Hub).
function lerVisao(texto) {
  const bloco = secao(texto, 'Visão').split(/^### /m)[0];
  const semCodigo = bloco.replace(/```[\s\S]*?```/g, '');
  const paragrafos = semCodigo
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter((p) => p && !p.startsWith('- '));
  const pilares = itensDeLista(semCodigo).map((item) => {
    const m = item.match(/^\*\*([^*]+?):?\*\*:?\s*(.*)$/);
    return m ? { titulo: m[1].replace(/:$/, ''), texto: m[2] } : { titulo: '', texto: item };
  });
  const codigo = (bloco.match(/```[^\n]*\n([\s\S]*?)```/) || [, ''])[1];
  return { frase: paragrafos[0] || '', uau: paragrafos[1] || '', pilares, fluxo: lerFluxo(codigo) };
}

// O desenho em texto do fluxo: a 1ª linha tem os passos separados por "→";
// as linhas de baixo têm notas "(...)" alinhadas embaixo de cada passo.
function lerFluxo(codigo) {
  const linhas = codigo.split('\n').filter((l) => l.trim());
  if (!linhas.length || !linhas[0].includes('→')) return [];
  const passos = [];
  const re = /[^→]+/g;
  let m;
  while ((m = re.exec(linhas[0]))) {
    const nome = m[0].trim();
    if (nome) passos.push({ nome, coluna: m.index + m[0].indexOf(nome), nota: '' });
  }
  const abre = linhas[1] ? [...linhas[1].matchAll(/\(/g)].map((x) => x.index) : [];
  abre.forEach((col, i) => {
    const fim = abre[i + 1] ?? Infinity;
    const nota = linhas
      .slice(1)
      .map((l) => l.slice(col, fim).trim())
      .join(' ')
      .replace(/^\(|\)$/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    const dono = [...passos].reverse().find((p) => p.coluna <= col + 2);
    if (dono && nota) dono.nota = nota;
  });
  return passos.map(({ nome, nota }) => ({ nome, nota }));
}

// ---------- Início.md (Agora e a linha do tempo) ----------

const UM_DIA = 24 * 60 * 60 * 1000;
const ESTADOS_GANTT = new Set(['done', 'active', 'crit', 'milestone']);

export function lerGantt(texto) {
  const linhas = linhasComCodigo(texto);
  const tarefas = [];
  const porId = new Map();
  let dentro = false;
  let secaoAtual = '';
  for (const l of linhas) {
    if (l.cerca) {
      dentro = l.lingua === 'mermaid';
      continue;
    }
    if (!dentro || !l.codigo) continue;
    const linha = l.linha.trim();
    if (!linha || /^(gantt|title|dateFormat|axisFormat|%%)/.test(linha)) continue;
    if (linha.startsWith('section ')) {
      secaoAtual = linha.slice(8).trim();
      continue;
    }
    const dois = linha.indexOf(':');
    if (dois < 0) continue;
    const nome = linha.slice(0, dois).trim();
    const tokens = linha
      .slice(dois + 1)
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);
    const estados = tokens.filter((t) => ESTADOS_GANTT.has(t));
    const resto = tokens.filter((t) => !ESTADOS_GANTT.has(t));
    let id = '';
    let ini = '';
    let fim = '';
    if (resto.length >= 3) [id, ini, fim] = resto;
    else if (resto.length === 2) [ini, fim] = resto;
    else if (resto.length === 1) [fim] = resto;

    let inicio = null;
    const depois = ini.match(/^after\s+(\S+)/);
    if (depois && porId.has(depois[1])) inicio = porId.get(depois[1]).fimMs;
    else if (/^\d{4}-\d{2}-\d{2}$/.test(ini)) inicio = Date.parse(ini + 'T00:00:00Z');
    else if (tarefas.length) inicio = tarefas[tarefas.length - 1].fimMs;
    let fimMs = null;
    const dur = fim.match(/^(\d+)d$/);
    if (dur && inicio != null) fimMs = inicio + Number(dur[1]) * UM_DIA;
    else if (/^\d{4}-\d{2}-\d{2}$/.test(fim)) fimMs = Date.parse(fim + 'T00:00:00Z');
    if (inicio == null || fimMs == null) continue;

    const faseM = nome.match(/^Fase\s+(\d+|Linux)\b/i);
    const t = {
      id,
      nome,
      secao: secaoAtual,
      estado: estados.includes('done') ? 'feita' : estados.includes('active') ? 'andamento' : 'futura',
      semData: secaoAtual.toLowerCase().includes('sem data'),
      fase: faseM ? faseM[1] : '',
      inicio: new Date(inicio).toISOString().slice(0, 10),
      fim: new Date(fimMs).toISOString().slice(0, 10),
      fimMs,
    };
    tarefas.push(t);
    if (id) porId.set(id, t);
  }
  return tarefas.map(({ fimMs, ...t }) => t);
}

export function lerInicio(texto) {
  return { agora: itensDeLista(secao(texto, 'Agora')), gantt: lerGantt(texto) };
}

// ---------- ideias ----------

function tituloDoArquivo(nome) {
  const t = nome.replace(/\.md$/i, '').replace(/[-_]+/g, ' ').trim();
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export function lerIdeia(raiz, caminho) {
  const texto = lerTexto(caminho);
  const { dados, corpo } = frontmatter(texto);
  return {
    arquivo: rel(raiz, caminho),
    titulo: (corpo.match(/^# (.+)$/m) || [, tituloDoArquivo(basename(caminho))])[1].trim(),
    status: (dados.status || 'crua').toLowerCase(),
    versao: dados.versao || '',
    custo: dados.custo || '',
    data: dados.data || '',
    resumo: primeiroParagrafo(secao(corpo, 'O que é')),
    menorVersao: primeiroParagrafo(secao(corpo, 'Menor versão')),
  };
}

// ---------- tarefas abertas (o que o plugin Tasks fazia) ----------

export function lerTarefas(raiz, caminho) {
  const texto = lerTexto(caminho);
  const arquivo = rel(raiz, caminho);
  const tarefas = [];
  let titulo = '';
  linhasComCodigo(texto).forEach(({ linha, codigo }, i) => {
    if (codigo) return;
    const h = linha.match(/^#{2,4} (.+)$/);
    if (h) titulo = h[1].trim();
    const t = linha.match(/^\s*- \[ \] (.+)$/);
    if (t && !t[1].includes('~~')) {
      tarefas.push({ arquivo, linha: i + 1, secao: titulo, texto: t[1].trim(), recuo: (linha.match(/^\s*/) || [''])[0].length });
    }
  });
  return tarefas;
}

// ---------- todos os documentos ----------

export function lerDocumento(raiz, caminho) {
  const texto = lerTexto(caminho);
  const arquivo = rel(raiz, caminho);
  let st = null;
  try {
    st = statSync(caminho);
  } catch {
    /* sem stat, segue sem data */
  }
  const { corpo } = frontmatter(texto);
  const titulos = [];
  linhasComCodigo(corpo).forEach(({ linha, codigo }) => {
    if (codigo) return;
    const h = linha.match(/^(#{2,3}) (.+)$/);
    if (h) titulos.push({ nivel: h[1].length, texto: h[2].trim() });
  });
  const pasta = arquivo.includes('/') ? arquivo.slice(0, arquivo.lastIndexOf('/')) : '';
  return {
    arquivo,
    pasta,
    titulo: (corpo.match(/^# (.+)$/m) || [, tituloDoArquivo(basename(caminho))])[1].trim(),
    titulos,
    texto,
    resumo: textoPuro(primeiroParagrafo(corpo.replace(/^# .+$/m, ''))).slice(0, 220),
    tamanho: Buffer.byteLength(texto),
    modificado: st ? st.mtime.toISOString() : null,
  };
}

// ---------- tudo junto ----------

export function lerCofre(raiz) {
  const arquivos = listarMarkdown(raiz);
  const doCofre = (p) => rel(raiz, p);

  const planos = arquivos.filter((p) => /^plans\//.test(doCofre(p)) && !/README\.md$/i.test(p));
  const fases = planos.map((p) => lerPlano(raiz, p));
  const ordemNum = (f) => (f.numero === 'Linux' ? 13.5 : Number(f.numero) || 999);
  const soFases = fases.filter((f) => f.ehFase).sort((a, b) => ordemNum(a) - ordemNum(b));
  const outros = fases.filter((f) => !f.ehFase);
  const atual = soFases.find((f) => f.situacao === 'andamento') || null;

  const ideias = arquivos
    .filter((p) => /^ideias\//.test(doCofre(p)) && !/README\.md$/i.test(p))
    .map((p) => lerIdeia(raiz, p));

  const tarefas = planos
    .filter((p) => /^plans\/(fase-|conferencia)/.test(doCofre(p)))
    .flatMap((p) => lerTarefas(raiz, p));

  const roadmap = lerRoadmap(lerTexto(join(raiz, 'ROADMAP.md')));
  const inicio = lerInicio(lerTexto(join(raiz, 'Início.md')));
  const docs = arquivos.map((p) => lerDocumento(raiz, p));

  return {
    fases: soFases,
    outrosPlanos: outros,
    faseAtual: atual ? atual.arquivo : null,
    roadmap,
    inicio,
    ideias,
    tarefas,
    docs,
  };
}
