Olá de novo! Esta é a **segunda rodada** do design do Game Hub: um launcher da biblioteca Steam em forma de cidade 3D em primeira pessoa, feito em **Godot 4.7 (GDScript)**.

Na primeira versão o visual usava assets Kenney e ficou **infantil**. Então fizemos uma **prova jogável** de uma direção nova: **"semi-realista + noite elegante"**.
- **Céu:** 3 céus HDRI reais da Poly Haven.
- **Chão e fachadas:** materiais PBR da ambientCG (concreto, tijolo, asfalto, piso).
- **Detalhes da cidade:** janelas de vidro, **néon na cor de cada bairro**, **logo do jogo** como letreiro, asfalto molhado à noite, postes modernos.
- **Amigos:** viraram **hologramas**.
- **Interface:** fonte Barlow e um HUD com cartão.

Tudo é CC0 ou OFL e implementado com shaders simples na Godot.

Anexei:
- `storyboard-brief.md` (v2): **leia primeiro**, principalmente as seções 2 (ferramentas e limites), 5 (o que ainda incomoda) e 7 (o que eu quero).
- `comparacao/01…09`: **antes × prova**, lado a lado e com o mesmo enquadramento.
- `prova_1-3/01…09`: os prints da prova em tamanho grande (os amigos nos prints são fictícios).

O que eu preciso, nesta ordem:
1. **Valide e refine a direção** e monte um **guia de estilo curto**:
   - paleta neutra + néon por bairro;
   - tipografia Barlow / Barlow Condensed, com tamanhos e pesos;
   - materiais;
   - clima de dia, pôr do sol e noite.
2. Um **storyboard de 12 a 14 quadros**, desenhado sobre os prints da prova: abertura → praça → bairro → olhar um prédio → amigos → entrar na porta → "Abrindo…" → "Jogando…" → volta do jogo → avisos → noite → (futuro) bioma de mundo aberto. Cada quadro com:
   - enquadramento;
   - o que aparece na tela;
   - som;
   - o que muda;
   - **como fazer na Godot** (nó ou recurso + asset);
   - prioridade: P1 (rápido e de alto impacto), P2 ou P3.
3. **Mockups de UI em 1280×720**, no estilo do cartão e dos avisos atuais:
   - tela de abertura;
   - **"Abrindo X…" e "Jogando X…" usando o hero (1920×620) e o logo do jogo**;
   - volta do jogo;
   - avisos;
   - menu de pausa/configurações.
4. **Soluções para os 11 pontos da seção 5** do briefing. Entre eles:
   - transições pretas;
   - logo repetido na fachada;
   - prédios iguais;
   - árvores low-poly;
   - pôr do sol enevoado;
   - hologramas em forma de "pílula";
   - orientação com muitos jogos;
   - identidade de cada bairro;
   - horizonte e muro no fim do mapa;
   - falta de menu.
5. Uma **lista final priorizada** (P1 → P3), com uma frase de "como fazer" em cada item.

Regras:
- Nada de assets pagos nem modelagem 3D manual. Os modelos realistas da Poly Haven são pesados demais: o hub fica aberto junto com os jogos e precisa ser leve.
- Quem implementa tem conhecimento básico de programação: mudanças **modulares**, uma de cada vez.
- A mesma linguagem visual precisa servir para o futuro **mundo aberto** com biomas por gênero.
- Escreva tudo em **português do Brasil**, com medidas em metros e pixels.
