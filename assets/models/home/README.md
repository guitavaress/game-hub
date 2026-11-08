# Modelos da cabana — Fase 17.9.1b

Modelos originais do Game Hub, gerados no Blender 5.2.3 LTS. Licença **MIT**, como o projeto (texto em `LICENSE` nesta pasta). Os scripts em `tools/blender/` são GPL-3.0 por usarem a API do Blender. Nenhum asset foi baixado nesta subetapa.

## Contrato para a integração (17.9.2)

Todos os valores abaixo estão em **metros, nos eixos da Godot (Y para cima)**. Raiz e nós das malhas têm transformação identidade: extrair a malha diretamente preserva o referencial. Cada nome abaixo identifica **um nó MeshInstance3D, uma malha e um material, com uma superfície**. O GLB não contém colisões, luzes, câmeras, animações nem texturas embutidas.

| Arquivo | Malhas/materiais | AABB: mínimo → máximo | Tamanho X × Y × Z | Disco |
|---|---|---|---|---|
| `armchair.glb` | `wood`, `fabric` | (−0,35; 0; −0,35) → (0,35; 0,99; 0,35) | 0,70 × 0,99 × 0,70 | 265.372 bytes / 259,2 KiB |
| `fireplace.glb` | `stone`, `wood`, `soot`, `iron` | (0; 0; −1) → (1,06; 1,57; 1) | 1,06 × 1,57 × 2,00 | 233.848 bytes / 228,4 KiB |

Tolerância de importação: 5 mm. AABB medida pelo `check_home_models`; os limites da poltrona são os de `_add_armchair`, e os da lareira são os de `_add_fireplace` **sem chaminé e lampião**. A lareira mantém os pilares de 1,8 m de largura e o consolo de 2 m, a 1,57 m do chão; a soleira avança até X=1,06. Poltrona: 10.764 triângulos; lareira: 9.118. Orçamentos: 300 KiB e 800 KiB, sem exceção.

### Poltrona

Origem no chão e no centro da pegada; **frente −Z**. Assento a aproximadamente Y=0,49, encosto em +Z, topo em Y=0,99. Usa-se o mesmo modelo duas vezes, com os giros/posições atuais. A manta de uma das poltronas continua em código. Estrutura de madeira aparente, almofadas arredondadas e vivos de 1,5 mm; não há tecido ou manta novo para baixar.

### Lareira

Origem na parede, no centro da largura e no chão: **parede X=0, frente +X, centro Z=0**. Mantém-se o giro `-PI/2` do nó da cabana. Nenhum giro extra deve ser aplicado ao modelo.

- Abertura: Z entre −0,50 e +0,50; Y entre 0,30 e 1,17; pilares até X=0,70. O fundo de fuligem ocupa X=0 a 0,10; seu piso tem topo em Y=0,32.
- Fogo/lenha/chamas: manter `_add_fire(..., Vector3(0.32, 0.32, 0.0))`; a luz e o som também permanecem em código. A boca está vazia no modelo.
- Grade baixa já incluída: barras em X=0,73, até Y=0,6725. Remover a grade feita por caixas ao integrar para não duplicá-la.
- Lampião do consolo: manter a base em `(0.3, 1.57, -0.65)`, escala 0,7, pelo código atual.
- **Chaminé fora do GLB:** manter a peça dinâmica feita por código: tamanho `(0.5, Home.ROOM_SIZE.y - 1.57, 1.4)`, centro `(0.25, 1.57 + (Home.ROOM_SIZE.y - 1.57) / 2, 0)`. Não esticar o corpo do modelo. A altura continua dependente da sala.
- Colisões continuam responsabilidade da Godot. Manter as caixas sólidas de pilares, base, verga e consolo com as medidas atuais, sem desenhá-las por cima do modelo.

### Materiais compartilhados

**A casa deve ter seu leitor próprio**, sem depender de `worlds/city/biome/trail_models.gd`. O contrato de cor é o mesmo dos modelos da trilha: `COLOR.rgb` contém tom × oclusão dividido por **1,6**; habilitar a cor de vértice como albedo e multiplicar o tint do material por 1,6. São cores lineares (`vertex_color_is_srgb = false`). Os tons podem ser escolhidos pela casa sem refazer o modelo.

- `wood`: **Wood049** (`assets/ambientcg/Wood049/`, CC0/ambientCG), os três mapas existentes (Color, NormalGL, Roughness). UV em metros, U ao longo da peça; escala 1 m por repetição. Sugestão de tint linear `(0.35, 0.25, 0.18)` antes do ganho, roughness 0,6; a prévia usa esse tom.
- `stone`: **Rock058** (`assets/ambientcg/Rock058/`, CC0/ambientCG), projetada de modo triplanar, 1 m por repetição; tint da prévia `(0.70, 0.66, 0.59)`. A geometria já faz as juntas; evita aplicar uma segunda divisão de pedras da PavingStones070 por cima. O grão e o normal podem seguir o material PBR compartilhado.
- `fabric`: tecido procedural existente em `HomeMaterials.fabric`, duplicado para habilitar cor de vértice e o ganho acima. Tint linear da prévia `(0.34, 0.22, 0.16)`, roughness 1. O UV não é necessário porque o tecido da casa usa triplanar. A paleta final é da A.
- `soot`: fosco, tint linear `(0.035, 0.029, 0.024)`, roughness 1 e cor de vértice com ganho.
- `iron`: metal, tint linear `(0.075, 0.070, 0.065)`, metallic 0,7, roughness 0,65 e cor de vértice com ganho.

Os materiais do GLB são marcadores de integração e dão uma visualização básica sem texturas. A prévia Blender aplica as texturas **depois** da exportação. Licença/créditos das PBR: `assets/ambientcg/LICENSE.txt` e README da mesma pasta. Nenhuma textura faltante bloqueia a integração; a Rock058 produz uma pedra escura e veio aparente, a avaliar sob a iluminação final da cabana.

## Na casa (17.9.2)

O leitor é `worlds/home/home_models.gd` (`HomeModels`): abre cada `.glb` uma vez, guarda as malhas e põe cada uma num `MeshInstance3D` com o material da casa (um desenho por material; as duas poltronas dividem as mesmas malhas). Os tons finais estão em `worlds/home/themes/cabin_decor.gd`: a pedra ficou cinza-fria (a Rock058 com um tom quente acendia os veios em laranja sob o fogo), a madeira das poltronas mais escura e o tecido de lã crua. A chaminé de código usa a PavingStones070 de pé (a Rock058 lisa numa caixa daquele tamanho virava um rochedo só).

## Conferência manual

1. Abra `poltrona_frente.png` e `poltrona_tres_quartos.png` em `C:/Projetos/game-hub-referencias/uau/depois-17.9.1b/`: o assento fica livre, com encosto atrás, madeira aparente e costuras assentadas no tecido.
2. Abra `lareira_frente.png` e `lareira_tres_quartos.png`: boca aberta, grade baixa, juntas e soleira visíveis; fogo e chaminé serão acrescentados pela Godot.
3. No FileSystem da Godot, abra cada GLB em **Nova cena herdada**, sem salvar: verifique os nomes das malhas e a escala. A versão texturizada na sala só aparece depois da integração 17.9.2.
