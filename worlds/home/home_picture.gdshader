// O quadro da parede (Fase 17.4): uma gravura de montanhas ao entardecer,
// feita por código. Céu em faixas, três planos de serra (o de trás claro e frio,
// o da frente escuro), um sol baixo e quente e o papel com grão. Combina com a
// paleta das referências: base fria e um acento âmbar. Usa o UV do quadro.
shader_type spatial;

uniform vec3 sky_top : source_color = vec3(0.16, 0.24, 0.32);
uniform vec3 sky_low : source_color = vec3(0.78, 0.55, 0.36);
uniform vec3 far_hills : source_color = vec3(0.4, 0.46, 0.52);
uniform vec3 mid_hills : source_color = vec3(0.22, 0.28, 0.34);
uniform vec3 near_hills : source_color = vec3(0.1, 0.13, 0.17);
uniform vec3 sun_color : source_color = vec3(0.95, 0.68, 0.38);

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Perfil de serra: soma de senos e um ruído de picos (y da crista em cada x).
float ridge(float x, float base, float height, float seed) {
	float y = base;
	y += sin(x * 3.1 + seed) * height * 0.5;
	y += sin(x * 7.3 + seed * 2.0) * height * 0.22;
	float cell = floor(x * 9.0);
	float f = fract(x * 9.0);
	float peak = mix(hash(cell + seed), hash(cell + 1.0 + seed), smoothstep(0.0, 1.0, f));
	return y + peak * height * 0.35;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y); // y = 0 embaixo
	vec3 color = mix(sky_low, sky_top, smoothstep(0.25, 0.95, uv.y));
	// Faixas de nuvem bem leves, como numa gravura.
	color = mix(color, sky_low * 1.05, (1.0 - smoothstep(0.0, 0.012, abs(fract(uv.y * 9.0 + sin(uv.x * 5.0) * 0.2) - 0.5) - 0.46)) * 0.25 * step(0.5, uv.y));
	float sun = length((uv - vec2(0.68, 0.46)) * vec2(1.0, 1.35));
	color = mix(color, sun_color, 1.0 - smoothstep(0.075, 0.085, sun));
	color += sun_color * (1.0 - smoothstep(0.08, 0.32, sun)) * 0.18;
	if (uv.y < ridge(uv.x, 0.48, 0.16, 1.3)) {
		color = mix(far_hills, sky_low, 0.25);
	}
	if (uv.y < ridge(uv.x * 0.8, 0.36, 0.14, 4.1)) {
		color = mid_hills;
	}
	if (uv.y < ridge(uv.x * 0.6, 0.2, 0.12, 8.7)) {
		color = near_hills;
	}
	// O papel: grão e a borda um pouco mais escura.
	vec2 q = abs(UV - 0.5) * 2.0;
	color *= 0.93 + hash2(floor(UV * 600.0)) * 0.07;
	color *= 1.0 - smoothstep(0.85, 1.0, max(q.x, q.y)) * 0.12;
	ALBEDO = color;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
