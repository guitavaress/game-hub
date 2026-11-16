// A troca modelo/foto das árvores (Fase 19.3), num lugar só: o tree_model.gdshader
// e o tree_impostor.gdshader incluem este arquivo, para as duas metades da troca
// fazerem SEMPRE a mesma conta (se uma mudasse sozinha, sobraria um buraco ou
// uma árvore em dobro na faixa da troca).

// Ruído de tela que não forma desenho: o modelo apaga os pontos abaixo do peso
// e a foto, os de cima; juntos, cobrem a tela uma vez só.
float tree_swap_dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

// Um número de 0 a 1 pela posição da árvore, com conta de números inteiros
// (exata em qualquer placa). A conta antiga, com seno de números grandes,
// podia arredondar diferente nos dois shaders (revisão da 19.3).
float tree_swap_pick(vec3 origin) {
	// Quadradinhos de 25 cm; o deslocamento deixa tudo positivo.
	uvec2 q = uvec2(ivec2(floor(origin.xz * 4.0)) + ivec2(1048576));
	uint h = (q.x * 1597334677u) ^ (q.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = h ^ (h >> 13u);
	return float(h >> 8u) / 16777216.0;
}

// A distância da troca desta árvore: a base, mais ou menos a variação.
float tree_swap_distance(vec3 origin, float base, float jitter) {
	return base * (1.0 + jitter * (tree_swap_pick(origin) * 2.0 - 1.0));
}
