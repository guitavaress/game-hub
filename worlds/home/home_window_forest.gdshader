// A janela da CABANA (Fase 13.12): morros e pinheiros em silhueta, desenhados
// por código, com profundidade de verdade (como o home_window.gdshader do
// loft). Para cada pixel, o raio que sai da câmera e atravessa o vidro é
// seguido até quatro "fileiras": pinheiros a 45 e 110 m, um morro com mata a
// 300 m e as montanhas a 900 m. Andando pela sala, o que está perto se mexe
// mais. De dia, céu azul e névoa clara; no pôr do sol, laranja; à noite, céu
// escuro com estrelas e a lua. "night" vem da casa (grupo city_night).
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// 0 = dia, 1 = noite.
uniform float night = 0.0;
// A que altura do chão fica o meio da janela (a cabana é térrea), em m.
uniform float window_height = 1.65;
uniform vec3 day_zenith : source_color = vec3(0.3, 0.52, 0.8);
uniform vec3 day_horizon : source_color = vec3(0.8, 0.86, 0.88);
uniform vec3 night_zenith : source_color = vec3(0.02, 0.03, 0.07);
uniform vec3 night_horizon : source_color = vec3(0.12, 0.16, 0.24);
uniform vec3 dusk_color : source_color = vec3(1.0, 0.52, 0.26);
uniform vec3 day_pine : source_color = vec3(0.09, 0.17, 0.12);
uniform vec3 night_pine : source_color = vec3(0.008, 0.012, 0.018);
uniform vec3 day_meadow : source_color = vec3(0.24, 0.3, 0.15);
uniform vec3 night_meadow : source_color = vec3(0.03, 0.04, 0.05);
uniform vec3 moon_color : source_color = vec3(0.92, 0.94, 1.0);

varying vec3 local_position;
varying vec3 local_camera;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), f);
}

// Onde o raio cruza o plano a "depth" m do vidro: x ao longo da fileira e a
// altura em relação ao chão.
vec2 hit_on_plane(vec3 origin, vec3 dir, float depth) {
	float t = (-depth - origin.z) / dir.z;
	vec3 hit = origin + dir * t;
	return vec2(hit.x, hit.y + window_height);
}

// Uma fileira de pinheiros: cada árvore é um triângulo em três camadas de
// galhos, de altura sorteada. Devolve 1 se o raio bateu numa árvore. "ground"
// é a altura do chão da fileira (num morro, a árvore nasce mais alto).
float pines(vec2 hit, float spacing, vec2 heights, float seed, float ground) {
	float column = floor(hit.x / spacing);
	float inside = 0.0;
	// A árvore da coluna e as vizinhas (a copa larga invade a do lado).
	for (int k = -1; k <= 1; k++) {
		float c = column + float(k);
		float center = (c + 0.2 + 0.6 * hash(vec2(c, seed))) * spacing;
		float top = mix(heights.x, heights.y, hash(vec2(c, seed + 5.0)));
		float y = (hit.y - ground) / top;  // 0 no pé, 1 na ponta
		if (y < 0.0 || y > 1.0) {
			continue;
		}
		// Três camadas de galhos: o triângulo "serrilhado" na borda.
		float tier = fract(y * 3.0);
		float half_width = (1.0 - y) * 0.34 * top * (0.75 + 0.25 * (1.0 - tier));
		float trunk = y < 0.08 ? 0.05 * top : 0.0;
		if (abs(hit.x - center) < max(half_width, trunk)) {
			inside = 1.0;
		}
	}
	return inside;
}

void fragment() {
	vec3 dir = normalize(local_position - local_camera);
	if (dir.z > -0.01) {
		dir.z = -0.01;
	}
	float dusk = 1.0 - abs(night * 2.0 - 1.0);
	vec3 horizon = mix(day_horizon, night_horizon, night);
	horizon = mix(horizon, dusk_color, dusk * 0.5);
	vec3 zenith = mix(day_zenith, night_zenith, night);
	float elevation = dir.y / length(dir.xz);
	vec3 sky = mix(horizon, zenith, smoothstep(0.0, 0.6, elevation));

	// Estrelas (só à noite): pontinhos sorteados numa grade do céu.
	vec2 star_cell = floor(vec2(atan(dir.x, -dir.z), elevation) * 260.0);
	float star = step(0.996, hash(star_cell)) * smoothstep(0.02, 0.2, elevation);
	sky += vec3(star) * night * 0.9;
	// A lua, à esquerda e no alto, com um halo.
	vec3 moon_dir = normalize(vec3(-0.3, 0.2, -1.0));
	float moon_dot = dot(dir, moon_dir);
	float moon = smoothstep(0.9992, 0.9995, moon_dot);
	float halo = pow(max(moon_dot, 0.0), 300.0) * 0.35;
	sky = mix(sky + moon_color * halo * night, moon_color * 1.4, moon * night);

	vec3 pine_color = mix(day_pine, night_pine, night);
	vec3 color = sky;

	// Montanhas lá longe (900 m): um contorno suave, quase da cor do céu.
	vec2 far_hit = hit_on_plane(local_camera, dir, 900.0);
	float ridge = 90.0 + 110.0 * noise(far_hit.x / 260.0) + 35.0 * noise(far_hit.x / 70.0 + 4.0);
	if (far_hit.y < ridge) {
		color = mix(pine_color * 1.6, sky, 0.62);
	}
	// O morro com mata (260 m): o chão sobe e desce, e os pinheiros nascem nele.
	vec2 hill_hit = hit_on_plane(local_camera, dir, 300.0);
	float hill = 12.0 + 30.0 * noise(hill_hit.x / 120.0 + 9.0);
	if (hill_hit.y < hill || pines(hill_hit, 9.0, vec2(14.0, 24.0), 3.0, hill - 2.0) > 0.0) {
		color = mix(pine_color * 1.25, sky, 0.38);
	}
	// O campo até as árvores (abaixo do horizonte): grama na névoa.
	if (elevation < 0.0) {
		vec3 meadow = mix(day_meadow, night_meadow, night);
		color = mix(meadow, horizon, clamp(1.0 + elevation * 25.0, 0.0, 1.0) * 0.6);
	}
	// Pinheiros do meio (90 m) e os de perto (30 m).
	if (pines(hit_on_plane(local_camera, dir, 110.0), 6.0, vec2(12.0, 20.0), 2.0, 0.0) > 0.0) {
		color = mix(pine_color * 1.1, sky, 0.22);
	}
	if (pines(hit_on_plane(local_camera, dir, 45.0), 10.0, vec2(9.0, 15.0), 1.0, 0.0) > 0.0) {
		color = pine_color;
	}
	// Um reflexo bem leve no vidro, mais claro em cima (UV.y = 0 no alto).
	color += vec3(0.025, 0.028, 0.032) * (1.0 - UV.y) * (1.0 - night * 0.5);
	ALBEDO = color;
}
