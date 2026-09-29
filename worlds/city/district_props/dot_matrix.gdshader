// Placar de LED (bairro Esportes): uma imagem minúscula (cada pixel = um LED)
// vira uma grade de pontos redondos. LED aceso = cor do bairro, com o centro
// mais forte que a borda; LED apagado = quase preto. A emissão faz o brilho
// (o "glow" da cidade cuida do halo à noite).
shader_type spatial;
render_mode shadows_disabled;

// Um pixel por LED: só o canal vermelho importa (1 = aceso, 0 = apagado).
uniform sampler2D matrix : filter_nearest, repeat_disable, hint_default_black;
// Quantos LEDs cabem na largura e na altura do painel.
uniform vec2 grid = vec2(64.0, 16.0);
uniform vec3 led_color : source_color = vec3(0.3, 1.0, 0.53);
uniform float brightness = 1.0;
// Raio de cada LED dentro da sua célula (0,5 = encosta no vizinho).
uniform float radius = 0.38;

void fragment() {
	vec2 cell = UV * grid;
	vec2 local = fract(cell) - 0.5;
	// Centro da célula: é ali que a imagem é lida (um pixel por LED).
	float on = texture(matrix, (floor(cell) + 0.5) / grid).r;
	float dist = length(local);

	// Borda suave que cresce com a distância: de longe os LEDs viram um
	// tom médio, em vez de tremer (moiré).
	float edge = clamp((fwidth(cell.x) + fwidth(cell.y)) * 0.5, 0.03, 0.5);
	float shape = 1.0 - smoothstep(radius - edge, radius + edge, dist);
	// Gradiente do LED: mais forte no meio, mais fraco na borda.
	float glow = mix(0.55, 1.0, pow(1.0 - clamp(dist / radius, 0.0, 1.0), 0.7));

	ALBEDO = vec3(0.012, 0.014, 0.014);
	ROUGHNESS = 0.45;
	// O LED apagado ainda aparece de leve (3%), como uma lente de plástico.
	EMISSION = led_color * shape * (on * glow * brightness + 0.03);
}
