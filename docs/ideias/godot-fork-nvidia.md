---
status: crua
versao: V1
custo: M
data: "2026-11-14"
---

## Resumo para o dono
> Escrito pelo modelo grátis (`omniroute/free-reasoning`, OpenCode) e revisado pelo Opus em 2026-11-14. Os fatos do fork (versões do DLSS, tamanhos, data do último commit) vêm das fontes do fim da nota e **têm de ser conferidos de novo no dia do spike**. É uma ideia: só vira trabalho se entrar na ROADMAP como fase.

O fork da NVIDIA (NVIDIA-RTX/godot, branch `nvidia-pt-dlss`) adiciona **path tracing em tempo real** + **DLSS 4.5** (Super Sampling, Frame Generation, DLAA, Ray Reconstruction) ao Godot 4.x. O hub ganharia iluminação global realista, reflexos e sombras fisicamente corretos sem baking — o "uau" visual que falta. Custo do teste: uma branch spike, compilar ou baixar binário (~120 MB Windows, ~80 MB Linux), rodar a bateria e as ferramentas de desempenho/captura lado a lado. **Não há binário oficial da NVIDIA**; o build de referência vem do itch.io do JohnLogostini.

## O que se sabe do fork (com fonte)
| Item | O que se sabe | Fonte |
|------|---------------|-------|
| Licença | MIT (mesma da Godot) | GitHub repo `NVIDIA-RTX/godot` |
| Base Godot | Godot 4.x (demos citam "Godot 4.7"; **NAO CONFERIDO** se é 4.7.2 exato) | itch.io Godot RTX, Ziva.sh blog |
| Acréscimos | Path tracing (Monte Carlo GI), DLSS SR/FG/DLAA, DLSS Ray Reconstruction (denoiser), integração RTX Kit (NRD, OMM, RTXDI, RTXGI, SHaRC) | RTXPT Design.md, RTX-Kit, Ziva.sh |
| GPU exigida | Path tracer: GPU-agnóstico (Vulkan RT). DLSS/DLAA/DLRR: **RTX 20-series+** (fechado). Denoiser atual = DLRR (só NVIDIA); NRD para AMD/Intel **em desenvolvimento** | Godot Forum (JohnLogostini), itch.io, Omniverse reqs |
| Binário pronto | **Não oficial da NVIDIA**. Builds Windows/Linux no itch.io do JohnLogostini (Windows 121 MB, Linux 77 MB, Source 72 MB) | itch.io Godot RTX |
| Precisa compilar | Sim, se não usar o build do itch.io. SConstruct padrão, Vulkan SDK 1.3.296+, VS2022/CMake 3.24+ (Windows) | RTX-Kit README, RTXPT README |
| Atualizado? | Repo ativo: último commit **28 jul 2026** na branch `nvidia-pt-dlss` | GitHub org NVIDIA-RTX, commits nvidia-pt-dlss |

## Compatibilidade com o hub (tabela risco/conferência)

| Item do hub | Risco | Como conferir no spike |
|-------------|-------|------------------------|
| Godot 4.7.2 do projeto vs base do fork | **Alto**: fork pode estar em 4.7-dev ou 4.8-dev; API pode ter mudado | Abrir `project.godot` no fork; ver erros de import; rodar `tests/run_tests.sh` |
| GDScript tipado estático | Baixo: linguagem não muda | A importação do `run_tests.sh` acusa erro de script |
| Física Jolt | Baixo: Jolt é módulo separado | Andar na cidade (colisão, escadas do metrô); a bateria completa |
| Renderer Forward+ | **Médio**: path tracing substitui o pipeline; shaders de tela podem quebrar | Ligar path tracing off (se houver fallback) e comparar visual |
| Shaders próprios (`.gdshader`/`gdshaderinc` em `worlds/`) | **Alto**: os shaders do hub (`building_facade`, `sky_blend`, `tree_model`, `tree_impostor`, `rain_streak`, `snow_cover`, a janela da casa) assumem rasterização | Carregar a cidade e a casa; ver erros de shader; `check_textures`, `check_trees`, `check_window_view` |
| MultiMesh das árvores | Baixo: MultiMesh é instancing de malha | `check_trees` ou captura da praça |
| Addon sky_3d | Baixo: só GDScript/shader | Trocar céu no menu; `check_sky3d` |
| Addon debug_menu (F3) | Baixo: só GDScript | Abrir F3; ver overlay |
| GDExtension Rust do compositor (`native/compositor`, só Linux) | **Médio**: ABI da GDExtension pode mudar entre versões Godot | `check_compositor` (pula se sem `.so`); compilar crates no fork |
| Exportação Windows/Linux | **Alto**: templates de exportação do fork precisam ser gerados/baixados | `bash tools/empacotar_windows.sh`; testar `--main-pack` |
| Notebook fraco (Radeon 610M, qualidade Leve) | **Muito alto**: sem RT, path tracing não roda; fallback incerto | Rodar `tools/medir_desempenho.gd -- 0 leve 13` no notebook |
| Desktop RTX 4070 (qualidade Alta) | **Baixo**: alvo do fork | Rodar `tools/medir_desempenho.gd -- 0 alta 22` no desktop |

## Plano de teste (spike em branch própria)

1. **Pedir ao dono antes de baixar/compilar**: confirmar nome (`NVIDIA-RTX/godot`), origem (GitHub), branch (`nvidia-pt-dlss`), versão (commit hash ou tag), e tamanho do download (binário ~120 MB Windows / ~80 MB Linux) ou tempo de compilação (~30–60 min).
2. **Copiar o projeto sem estragar o original**: `git worktree add ../godot-rtx-spike fase-N` (branch da fase atual) → abrir a cópia no fork (editor do fork aponta para `../godot-rtx-spike`).
3. **Importar no fork**: deixar a Godot do fork importar o projeto (pode fechar na 1ª importação — defeito conhecido tipo Terrain3D). Reabrir.
4. **Rodar bateria básica**: primeiro um recorte rápido, `bash tests/run_tests.sh check_gates check_trees check_sky3d check_daynight check_window_view check_compositor`; passando, a **bateria completa** (`bash tests/run_tests.sh`), até `RESULTADO GERAL: TUDO OK`. Uma Godot por vez.
5. **Medir desempenho (COM JANELA)**:  
   - Desktop (RTX 4070, Alta): `godot --path . -s tools/medir_desempenho.gd -- 200 alta 13` e `-- 200 alta 22` (200 jogos falsos, como nas medidas das fases)  
   - Notebook (Leve): `godot --path . -s tools/medir_desempenho.gd -- 200 leve 13` e `-- 200 leve 22` (só para ver se abre; o notebook não é meta)  
   Comparar com os números atuais da branch `fase-N` (mesmo commit-base).
6. **Capturas lado a lado (COM JANELA, pasta FORA do repo)**:  
   `godot --path . -s tools/capturar_pontos.gd -- <pasta> 200 rpg 13,22 alta`, e `tools/capturar_casa.gd -- <pasta> 200 13,22 alta cabana` para a casa  
   Pontos: `praca`, `portico`, `cima`, `mirante` (se trilha montanha existir). Repetir no fork e no original; mesmo horário (13 h e 22 h), mesma qualidade.
7. **Testar exportação**: `bash tools/empacotar_windows.sh` no fork; rodar `check_exported_build` (precisa do `.pck` gerado).
8. **Path tracing ON vs OFF**: se o fork tem fallback raster, repetir passos 5–6 com path tracing desligado (verificar se há opção no menu ou `GraphicsQuality`).

## Critérios de decisão

| Decisão | Quando |
|---------|--------|
| **Migrar** | Bateria `TUDO OK` no fork; path tracing OFF: caminhada no desktop **não cai > 5 %** vs original; path tracing ON: roda no desktop (4070) com FPS médio ≥ 30 em Alta; exportação Windows/Linux funciona; shaders próprios rodam sem erro (ou ajustes triviais < 1 dia); compositor Rust compila e `check_compositor` passa. |
| **Não migrar** | Qualquer teste da bateria falha por mudança de API; path tracing OFF cai > 5 % no desktop; shaders precisam reescrita grande; exportação quebra; compositor não compila; notebook não abre nem no Leve (fallback inexistente). |
| **Esperar** | Bateria passa mas path tracing ON está instável (crashes, ruído excessivo sem DLRR); NRD denoiser não saiu; fork está em base Godot > 4.7.2 (ex.: 4.8-dev) e a migração viraria upgrade de versão; dono decide que o ganho visual não justifica o risco agora. |

## Riscos e o que fica de fora
- **Fork ≠ mainline**: manutenção por conta da NVIDIA; PR prometido mas sem data. Atualizações de segurança/bugs da Godot 4.7.x não chegam automaticamente.
- **DLSS/RR fechados**: só NVIDIA; AMD/Intel dependem do NRD (ainda não integrado no fork).
- **Path tracing não é "grátis"**: os shaders do hub (céu, fachadas, árvores, chuva, janela) talvez precisem ser reescritos ou desligados no modo path tracing.
- **Export templates**: precisam ser compilados para o fork (Windows + Linux x86_64) e guardados fora do repositório.
- **Notebook (Radeon 610M)**: **fora da meta**. Se o fork não tem fallback raster estável, o hub não abre no notebook de viagem.
- **O que NÃO entra no teste**: integração contínua, CI do GitHub Actions, build do compositor Rust no Linux (precisa toolchain Rust + Smithay), testes de amigos/Steam (precisam chave/API), migração de dados `user://`.

## Fontes
- Repositório: https://github.com/NVIDIA-RTX/godot/tree/nvidia-pt-dlss
- Ziva.sh "Godot Ray Tracing: The NVIDIA RTX Fork": https://ziva.sh/blogs/godot-ray-tracing
- RTXPT Design (denoiser, pipeline): https://github.com/NVIDIA-RTX/RTXPT/blob/main/Docs/Design.md
- RTX Kit (SDKs, requisitos): https://github.com/NVIDIA-RTX/RTX-Kit
- Godot Forum (JohnLogostini, GPU-agnóstico, NRD a caminho): https://forum.godotengine.org/t/godot-rtx-nvidia-fork-path-tracing/135657
- itch.io builds (binários Windows/Linux): https://johnlogostini.itch.io/godot-rtx
- Omniverse technical requirements (GPU matrix DLSS-RR): https://docs.omniverse.nvidia.com/dev-guide/latest/common/technical-requirements.html