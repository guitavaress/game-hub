// Tampo holográfico da mesa do bairro Estratégia: uma grade fina (uma linha a
// cada 25 m do mundo), a moldura da mesa, o contorno do quarteirão e uma faixa
// de luz que varre a mesa de um lado ao outro. Soma luz ao que está atrás
// (blend_add), no mesmo estilo do holograma dos amigos (hologram.gdshader).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.3, 0.58, 1.0);
uniform float intensity = 1.4;
// Lado do plano (m) e distância entre as linhas da grade (m).
uniform float plane_size = 4.0;
uniform float grid_step = 0.25;
uniform float line_width = 0.008;
// Metade do quarteirão na escala do mapa (28 m / 25 / 2).
uniform float block_half = 0.56;
// Voltas da faixa de varredura por segundo.
uniform float scan_speed = 0.3;

// Distância (em metros) até a linha de grade mais próxima.
float grid_distance(vec2 p, float step_size) {
	vec2 g = abs(fract(p / step_size + 0.5) - 0.5) * step_size;
	return min(g.x, g.y);
}

void fragment() {
	// Posição no tampo, em metros, a partir do centro.
	vec2 p = (UV - 0.5) * plane_size;
	float square_dist = max(abs(p.x), abs(p.y));

	float thin = 1.0 - smoothstep(line_width * 0.5, line_width, grid_distance(p, grid_step));
	float thick = 1.0 - smoothstep(line_width, line_width * 2.0, grid_distance(p, grid_step * 4.0));
	float frame = 1.0 - smoothstep(0.015, 0.035, plane_size * 0.5 - square_dist);
	float block = 1.0 - smoothstep(0.006, 0.016, abs(square_dist - block_half));
	float block_fill = 1.0 - smoothstep(block_half - 0.02, block_half, square_dist);

	// Faixa de luz que anda de uma ponta à outra do tampo.
	float bar = mix(-plane_size * 0.5, plane_size * 0.5, fract(TIME * scan_speed));
	float scan = smoothstep(0.4, 0.0, abs(p.y - bar));

	float alpha = 0.05 + block_fill * 0.07 + thin * 0.35 + thick * 0.35 + frame + block * 0.9;
	alpha += scan * (0.14 + thin * 0.5);
	float flicker = 0.95 + 0.05 * sin(TIME * 17.0);
	ALBEDO = color * intensity;
	ALPHA = clamp(alpha * flicker, 0.0, 1.0);
}
