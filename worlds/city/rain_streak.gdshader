// Os riscos da chuva (Fase 19.5). Cada gota é um quad fino ESTICADO na direção
// da queda (com o vento) e virado para a câmera só em volta desse eixo: de
// qualquer ângulo, o risco aparece inclinado do mesmo jeito.
//
// A cor é a do que está ATRÁS da gota, um pouco mais clara (a gota é uma lente
// pequena), misturada com uma tinta: contra o céu claro o risco aparece, contra
// a parede escura quase some, e perto do néon ele pega a cor do néon. É assim
// que a chuva aparece de verdade, e não precisa de luz nova.
//
// Longe, o risco não fica mais fino que ~1,5 pixel (senão pisca): ele alarga e
// fica mais transparente, na mesma conta. Perto do olho ele some (uma gota a
// 20 cm da câmera seria um borrão do tamanho da tela).
//
// Usado pelo DistrictWeather (draw_pass_1 das partículas "Rain").
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, world_vertex_coords;

// Direção da queda, já com o vento (normalizada).
uniform vec3 fall_direction = vec3(0.0, -1.0, 0.0);
// Comprimento e largura do risco, em metros (o comprimento varia ±30% por gota).
uniform float streak_length = 0.7;
uniform float streak_width = 0.012;
// A tinta e a opacidade (alfa) do risco. O DistrictWeather troca pela hora.
uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.88, 0.3);
// Quanto da cor vem do que está atrás (0 = só a tinta).
uniform float refraction : hint_range(0.0, 1.0) = 0.5;
// Largura mínima na tela, em radianos (~1,5 pixel a 1080p com o FOV do jogador).
uniform float min_angle = 0.0018;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

varying float v_alpha;

// Um número de 0 a 1 por gota (sempre o mesmo para a mesma gota).
float gota(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float h = gota(uint(INSTANCE_ID));
	vec3 to_camera = CAMERA_POSITION_WORLD - center;
	float dist = max(length(to_camera), 0.001);
	vec3 side = cross(fall_direction, to_camera / dist);
	// Olhando exatamente na direção da queda o "lado" some: qualquer um serve.
	side = length(side) > 0.0001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float width = max(streak_width, dist * min_angle);
	float len = streak_length * (0.7 + 0.6 * h);
	vec2 corner = vec2(UV.x - 0.5, 0.5 - UV.y);
	VERTEX = center + side * corner.x * width + fall_direction * corner.y * len;
	NORMAL = to_camera / dist;
	// Mais largo = mais transparente (a mesma "quantidade" de gota na tela);
	// some perto do olho; cada gota tem um brilho um pouco diferente.
	v_alpha = (streak_width / width) * smoothstep(0.35, 1.4, dist) * (0.55 + 0.45 * h);
}

void fragment() {
	// UV.y = 0 é a ponta de baixo (a cabeça da gota); o rabo vai sumindo.
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.1, UV.y) * (1.0 - smoothstep(0.3, 1.0, UV.y));
	vec3 behind = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(tint.rgb, behind * 1.6 + tint.rgb * 0.08, refraction);
	ALPHA = clamp(across * across * along * tint.a * v_alpha, 0.0, 1.0);
}
