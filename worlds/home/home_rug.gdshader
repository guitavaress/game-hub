// Tapete feito por código (Fase 9.9): borda, faixa e losangos, com uma trama
// fininha. Usa o UV do plano (0 a 1 nos dois lados).
shader_type spatial;

uniform vec3 field_color : source_color = vec3(0.33, 0.1, 0.08);
uniform vec3 border_color : source_color = vec3(0.78, 0.6, 0.38);
uniform vec3 accent_color : source_color = vec3(0.1, 0.14, 0.22);
// Quantos losangos cabem na largura e na profundidade.
uniform vec2 diamonds = vec2(8.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 q = abs(UV - 0.5) * 2.0;
	float ring = max(q.x, q.y);
	vec3 color = field_color;
	if (ring > 0.86) {
		color = border_color;
	}
	if (ring > 0.9 && ring < 0.94) {
		color = accent_color;
	}
	if (ring < 0.8) {
		vec2 cell = fract((UV - 0.5) * diamonds) - 0.5;
		float d = abs(cell.x) + abs(cell.y);
		if (d < 0.22) {
			color = mix(color, border_color, 0.75);
		} else if (d < 0.3) {
			color = mix(color, accent_color, 0.8);
		}
	}
	// Trama: pontinhos claros e escuros, bem leves.
	float weave = hash(floor(UV * vec2(900.0, 560.0)));
	ALBEDO = color * (0.92 + weave * 0.12);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
