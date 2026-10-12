// O janelão da casa (Fase 9.9): um horizonte de prédios desenhado por código,
// com profundidade de verdade. Para cada pixel, o raio que sai da câmera e
// atravessa o vidro é seguido até três "fileiras" de prédios, a 110, 220 e
// 450 m atrás do vidro: andando pela sala, os prédios de perto se mexem mais
// que os de longe. De dia, céu claro; no pôr do sol, laranja; à noite, céu
// escuro e janelas acesas. "night" vem da casa (grupo city_night).
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// 0 = dia, 1 = noite.
uniform float night = 0.0;
// A que altura da rua fica o meio da janela (o loft é num andar alto), em m.
uniform float window_height = 42.0;
uniform vec3 day_zenith : source_color = vec3(0.32, 0.52, 0.82);
uniform vec3 day_horizon : source_color = vec3(0.76, 0.84, 0.93);
uniform vec3 night_zenith : source_color = vec3(0.01, 0.012, 0.03);
uniform vec3 night_horizon : source_color = vec3(0.07, 0.07, 0.12);
uniform vec3 dusk_color : source_color = vec3(1.0, 0.5, 0.25);
uniform vec3 day_building : source_color = vec3(0.34, 0.39, 0.47);
uniform vec3 night_building : source_color = vec3(0.025, 0.03, 0.045);
uniform vec3 lit_window : source_color = vec3(1.0, 0.74, 0.45);

varying vec3 local_position;
varying vec3 local_camera;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Uma fileira de prédios a "depth" m do vidro. Devolve a cor em rgb e, em a,
// 1 se o raio bateu num prédio (0 = passou por cima).
vec4 row_of_buildings(vec3 origin, vec3 dir, float depth, float width, vec2 heights, float seed, float haze, vec3 sky) {
	float t = (-depth - origin.z) / dir.z;
	vec3 hit = origin + dir * t;
	float height = hit.y + window_height;  // altura em relação à rua
	float column = floor(hit.x / width);
	float h = hash(vec2(column, seed));
	float top = mix(heights.x, heights.y, h * h);
	// Um vão de vez em quando (prédio baixinho), para o horizonte respirar.
	if (hash(vec2(column, seed + 9.0)) < 0.15) {
		top *= 0.35;
	}
	if (height > top) {
		return vec4(0.0);
	}
	vec3 wall = mix(day_building, night_building, night) * (0.85 + hash(vec2(column, seed + 3.0)) * 0.3);
	// Janelas: uma grade de 3 x 3,5 m; algumas acendem (muitas mais à noite).
	vec2 cell = vec2(hit.x / 3.0, height / 3.5);
	vec2 inside = fract(cell);
	float is_window = step(0.25, inside.x) * step(inside.x, 0.75) * step(0.3, inside.y) * step(inside.y, 0.75);
	float lit = step(hash(floor(cell) + vec2(seed * 13.0, column)), 0.42);
	// De longe, a grade vira chuvisco: troca pela média, para não piscar.
	float blur = clamp(fwidth(cell.x) * 2.0, 0.0, 1.0);
	// De dia, todas as janelas são só um vidro azulado, um pouco mais escuro
	// que a parede; à noite, as sorteadas acendem.
	vec3 day_glass = wall * 0.75 + vec3(0.04, 0.06, 0.1);
	vec3 day_color = mix(wall, day_glass, mix(is_window, 0.25, blur));
	vec3 night_color = mix(wall, lit_window * 2.2, mix(is_window * lit, 0.25 * 0.42, blur));
	vec3 color = mix(day_color, night_color, night);
	color = mix(color, sky, haze);
	return vec4(color, 1.0);
}

void fragment() {
	vec3 dir = normalize(local_position - local_camera);
	if (dir.z > -0.01) {
		dir.z = -0.01;
	}
	float dusk = 1.0 - abs(night * 2.0 - 1.0);
	vec3 horizon = mix(day_horizon, night_horizon, night);
	horizon = mix(horizon, dusk_color, dusk * 0.55);
	vec3 zenith = mix(day_zenith, night_zenith, night);
	float elevation = dir.y / length(dir.xz);
	vec3 sky = mix(horizon, zenith, smoothstep(0.0, 0.7, elevation));

	vec4 near = row_of_buildings(local_camera, dir, 110.0, 18.0, vec2(15.0, 75.0), 1.0, 0.08, horizon);
	vec4 middle = row_of_buildings(local_camera, dir, 220.0, 24.0, vec2(18.0, 100.0), 2.0, 0.25, horizon);
	vec4 far = row_of_buildings(local_camera, dir, 450.0, 30.0, vec2(25.0, 130.0), 3.0, 0.5, horizon);
	vec3 color = sky;
	// Abaixo do horizonte, sem prédio: a rua lá embaixo, na névoa.
	if (elevation < 0.0) {
		color = mix(horizon, mix(vec3(0.2, 0.21, 0.23), vec3(0.09, 0.06, 0.05), night), 0.6);
	}
	if (far.a > 0.0) {
		color = far.rgb;
	}
	if (middle.a > 0.0) {
		color = middle.rgb;
	}
	if (near.a > 0.0) {
		color = near.rgb;
	}
	// Um reflexo bem leve no vidro, mais claro em cima (UV.y = 0 no alto).
	color += vec3(0.025, 0.028, 0.032) * (1.0 - UV.y) * (1.0 - night * 0.5);
	ALBEDO = color;
}
