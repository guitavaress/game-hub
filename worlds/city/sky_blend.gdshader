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

// Direção de olhar -> coordenada na foto panorâmica (formato equiretangular).
vec2 panorama_uv(vec3 direction) {
	float u = atan(direction.x, -direction.z) / (2.0 * PI) + 0.5 + rotation;
	float v = acos(clamp(direction.y, -1.0, 1.0)) / PI;
	return vec2(fract(u), v);
}

void sky() {
	vec2 uv = panorama_uv(EYEDIR);
	// textureLod(..., 0.0): sem mipmap, para não aparecer uma "costura" no céu.
	vec3 color = textureLod(day_sky, uv, 0.0).rgb * day_weight
			+ textureLod(sunset_sky, uv, 0.0).rgb * sunset_weight
			+ textureLod(night_sky, uv, 0.0).rgb * night_weight;
	COLOR = color * energy;
}
