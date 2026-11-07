// O que o painel mostra do git: a branch, os últimos commits e quantos por dia.
// Só leitura (git log / rev-parse). O e-mail do autor nunca é lido.

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

async function git(repo, args) {
  // safe.directory: no contêiner o repositório pertence a outro usuário (o do Windows).
  const { stdout } = await exec('git', ['-c', 'safe.directory=*', '-C', repo, ...args], {
    maxBuffer: 8 * 1024 * 1024,
    timeout: 10_000,
  });
  return stdout.trim();
}

export async function lerGit(repo) {
  try {
    const [branch, total, log, dias] = await Promise.all([
      git(repo, ['rev-parse', '--abbrev-ref', 'HEAD']),
      git(repo, ['rev-list', '--count', 'HEAD']),
      git(repo, ['log', '-n', '15', '--date=iso-strict', '--format=%h%x09%ad%x09%s']),
      git(repo, ['log', '--since=17 weeks ago', '--date=short', '--format=%ad']),
    ]);
    const commits = log
      .split('\n')
      .filter(Boolean)
      .map((l) => {
        const [hash, data, ...assunto] = l.split('\t');
        return { hash, data, assunto: assunto.join('\t') };
      });
    const porDia = {};
    for (const d of dias.split('\n').filter(Boolean)) porDia[d] = (porDia[d] || 0) + 1;
    return { branch, total: Number(total) || 0, commits, porDia };
  } catch (erro) {
    return { branch: '', total: 0, commits: [], porDia: {}, erro: 'git indisponível' };
  }
}
