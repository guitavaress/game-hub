// Céu feito com três fotos panorâmicas (HDRI da Poly Haven, CC0):
// dia, pôr do sol e noite. O DayNight muda os "pesos" conforme a hora e o
// céu mistura as três fotos aos poucos.
shader_type sky;

uniform sampler2D day_sky : filter_linear, repeat_enable;
uniform sampler2D sunset_sky : filter_linear, repeat_enable;
uniform sampler2D night_sky : filter_linear, repeat_enable;
// Quanto de cada foto aparece (o DayNight garante que somam ~1).
uniform float day_weight = 1.0;
uniform float sunset_weight = 0.0;
uniform float night_weight = 0.0;
// Brilho geral do céu (também afeta a luz ambiente e os reflexos).
uniform float energy = 1.0;
// Gira as fotos (em voltas: 0.25 = 90 graus), para alinhar o sol da foto.
uniform float rotation = 0.0;
// Giro extra só da foto do pôr do sol: o brilho dela fica do lado do sol
// (oeste à tarde, leste de manhã). O DayNight ajusta.
uniform float sunset_rotation = 0.0;
// Brilho próprio da foto do pôr do sol (cada foto vem com uma exposição
// diferente; isto deixa as três no mesmo "nível").
uniform float sunset_gain = 1.0;
// A foto da noite tem morros de deserto marrons no horizonte (15.13.2): de
// baixo até "night_ground_top" (a altura do olhar, de 0 a 1) ela é trocada por
// esta cor, uma silhueta azul-escura; acima disso as estrelas ficam como são.
uniform vec3 night_ground_color : source_color = vec3(0.004, 0.007, 0.018);
uniform float night_ground_top = 0.7;

// Direção de olhar -> coordenada na foto panorâmica (formato equiretangular).
vec2 panorama_uv(vec3 direction, float turn) {
	float u = atan(direction.x, -direction.z) / (2.0 * PI) + 0.5 + turn;
	float v = acos(clamp(direction.y, -1.0, 1.0)) / PI;
	return vec2(fract(u), v);
}

// A foto da noite sem o chão dela: abaixo do horizonte e nos morros vira a cor
// azul-escura, e some aos poucos até as estrelas (a transição é suave).
vec3 night_color(vec2 uv, float height) {
	vec3 photo = textureLod(night_sky, uv, 0.0).rgb;
	float stars = pow(smoothstep(0.05, night_ground_top, height), 2.0);
	return mix(night_ground_color, photo, stars);
}

void sky() {
	vec2 uv = panorama_uv(EYEDIR, rotation);
	vec2 sunset_uv = panorama_uv(EYEDIR, rotation + sunset_rotation);
	// textureLod(..., 0.0): sem mipmap, para não aparecer uma "costura" no céu.
	vec3 color = textureLod(day_sky, uv, 0.0).rgb * day_weight
			+ textureLod(sunset_sky, sunset_uv, 0.0).rgb * sunset_weight * sunset_gain
			+ night_color(uv, EYEDIR.y) * night_weight;
	COLOR = color * energy;
}
