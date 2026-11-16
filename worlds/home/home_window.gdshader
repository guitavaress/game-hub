// O janelão da casa.
//
// A VISTA DE VERDADE (Fase 17.3): o retrato do mundo que o WindowView tira
// (components/window_view/) chega em view_texture. Para cada pixel, o raio que
// sai da câmera e atravessa o vidro vira um ponto do retrato, como num céu:
// o retrato fica "no infinito", e andando pela sala a vista muda de ângulo
// como uma paisagem de longe. Na frente dela fica o vidro: um véu frio, o
// reflexo quente da sala (mais forte de lado) e o brilho das lâmpadas
// refletido (reflection_lights), que acompanha quem anda.
//
// A VISTA DE RESERVA (Fase 9.9): enquanto não há retrato (o mundo ainda está
// montando, ou não ofereceu um ponto), um horizonte de prédios desenhado por
// código. O raio é seguido até três "fileiras" de prédios, a 110, 220 e
// 450 m atrás do vidro: andando pela sala, os prédios de perto se mexem mais
// que os de longe. De dia, céu claro; no pôr do sol, laranja; à noite, céu
// escuro e janelas acesas. "night" vem da casa (grupo city_night).
//
// A CHUVA NO VIDRO (Fase 19.6.1): com "rain" acima de 0 (a casa passa a força
// que o mundo avisa: 0,5 = chuva fraca, 1 = forte), por cima da vista e por
// baixo dos reflexos: os riscos da chuva caindo lá fora (três planos, a 2,5, 6
// e 14 m do vidro, que andam com quem anda pela sala), a névoa do vidro
// molhado, as gotas paradas no vidro e as que escorrem aos trancos, deixando
// um rastro limpo com gotinhas. Cada gota é uma lente: mostra a vista virada
// (de noite, as luzes da cidade aparecem nelas) e pega o brilho da sala. Tudo
// por conta (sorteio por número inteiro), sem textura. Com 0, nada disso roda.
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

// --- A chuva no vidro (Fase 19.6.1) ---
// 0 = sem chuva, 0,5 = chuva fraca, 1 = forte.
uniform float rain : hint_range(0.0, 1.0) = 0.0;
// A cor que os riscos e a névoa do vidro molhado somam à vista, de dia e de noite.
uniform vec3 rain_tint_day : source_color = vec3(0.6, 0.64, 0.7);
uniform vec3 rain_tint_night : source_color = vec3(0.16, 0.17, 0.21);
// O quanto a gota desvia o olhar (a gota é uma lente: no meio, quase nada;
// na borda, a vista do outro lado).
uniform float drop_refraction = 0.5;

// --- A vista de verdade (o WindowView preenche) ---
// O retrato da vez e o anterior (durante a troca de fase do dia).
uniform sampler2D view_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D view_previous : source_color, filter_linear, repeat_disable;
// 0 = vista de reserva, 1 = retrato (o fade de quando a cidade fica pronta).
// De dia é uma troca simples. À noite, a reserva se apaga primeiro e a cidade
// de verdade acende: as luzes (néon, janelas) antes do resto.
uniform float view_mix = 0.0;
// 0 = o anterior, 1 = o da vez.
uniform float view_blend = 1.0;
// tan(meia abertura) da lente do retrato, em x e em y.
uniform vec2 view_tan_half_fov = vec2(2.145, 1.072);
// Brilho do retrato. O retrato já vem com o "filme" de cor do mundo, e o da
// casa passa por cima: o ganho devolve o que ele escurece.
uniform float view_gain = 1.25;
// À noite o retrato vem mais escuro: um pouco mais de ganho, para a vista ler
// como cidade e não como um quadro preto. Era 2,2 quando a cidade à noite era
// quase preta (17.3); com a noite que se lê (17.5), 2,2 deixava a neve da
// montanha com cara de dia.
uniform float view_night_gain = 1.6;
// As luzes mais fortes do retrato (néon, janelas acesas) passam do branco e
// acendem o brilho (glow) da casa: a partir de que claridade, e quanto.
uniform float view_glow_from = 0.55;
uniform float view_glow = 1.6;

// --- O vidro (só por cima do retrato) ---
// Véu frio: o vidro tira um pouco do contraste da vista.
uniform vec3 glass_tint : source_color = vec3(0.32, 0.38, 0.46);
uniform float glass_veil = 0.07;
// Reflexo da sala: quente, fraco de frente e mais forte de lado (Fresnel).
uniform vec3 room_reflection : source_color = vec3(0.55, 0.36, 0.2);
uniform float reflection_strength = 0.05;
// Lâmpadas da sala refletidas no vidro: xyz = onde ela está (no espaço da
// janela, em m), w = força (0 = nenhuma).
uniform vec4 reflection_lights[4];
uniform vec3 reflection_light_color : source_color = vec3(1.0, 0.72, 0.45);

varying vec3 local_position;
varying vec3 local_camera;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Um sorteio de 0 a 1 por célula inteira (a chuva). Só conta com números
// inteiros: não perde precisão com o tempo, como o seno de números grandes.
float rand(ivec2 cell, int seed) {
	uint h = (uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u) ^ (uint(seed) * 83492791u);
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

// --- A chuva lá fora ---------------------------------------------------------
const float RAIN_SLANT = 0.1;      // o vento inclina a chuva (m de lado por m de queda)
const float RAIN_SPEED = 9.0;      // m/s
const float RAIN_PERIOD = 2.2;     // de quantos em quantos metros, numa coluna, pode cair um risco
const float RAIN_LENGTH = 0.8;     // o comprimento do risco (o borrão da queda), em m
const float RAIN_THICKNESS = 0.006;

// Os riscos de um plano a "depth" m atrás do vidro, em colunas de "width" m.
// Devolve quanto o pixel é risco (0 a 1). Longe, o risco fino fica com um
// pixel de largura e mais transparente (não pisca).
float streak_layer(vec3 dir, float depth, float width, float density, int seed) {
	float t = (-depth - local_camera.z) / dir.z;
	vec2 q = local_camera.xy + dir.xy * t;
	q.x += q.y * RAIN_SLANT;
	float pixel = fwidth(q.x);
	float column = floor(q.x / width);
	int c = int(column);
	float fall = q.y / RAIN_PERIOD + fract(TIME * RAIN_SPEED / RAIN_PERIOD) + rand(ivec2(c, 0), seed) * 7.0;
	int row = int(floor(fall));
	// 0 = a cabeça do risco (embaixo, mais forte), 1 = o fim dele.
	float along = fract(fall) * RAIN_PERIOD / RAIN_LENGTH;
	float present = step(rand(ivec2(c, row), seed + 1), density);
	float center = (column + 0.2 + 0.6 * rand(ivec2(c, row), seed + 2)) * width;
	float spread = max(RAIN_THICKNESS, pixel * 1.2);
	float line = (1.0 - smoothstep(0.0, spread, abs(q.x - center))) * (RAIN_THICKNESS / spread);
	float body = step(along, 1.0) * smoothstep(0.0, 0.06, along) * sqrt(max(1.0 - along, 0.0));
	return line * body * present;
}

// Os três planos juntos. A quantidade de riscos cresce com a força (na fraca,
// poucos; na forte, cheio).
float falling_rain(vec3 dir, float amount) {
	float density = amount * amount * 0.6;
	float near = streak_layer(dir, 2.5, 0.1, density, 101);
	float middle = streak_layer(dir, 6.0, 0.24, density, 211);
	float far = streak_layer(dir, 14.0, 0.56, density, 307);
	return clamp(near + middle * 0.8 + far * 0.6, 0.0, 1.0);
}

// --- As gotas no vidro (em metros, no plano do vidro) -------------------------
// Uma gota de raio "radius" em "center": em xy, onde o pixel está nela (0 no
// meio, 1 na borda: serve de "normal"); em z, quanto o pixel é gota (com a
// borda suavizada pelo tamanho do pixel).
vec3 drop_shape(vec2 p, vec2 center, vec2 radius) {
	vec2 d = (p - center) / radius;
	float len = length(d);
	float aa = max(fwidth(len), 0.001);
	return vec3(d, clamp((1.0 - len) / aa, 0.0, 1.0));
}

// Gotas paradas, uma por célula de "cell" m (algumas células, pela
// "presence"). Cada gota cai (aparece de uma vez), fica e seca devagar; depois
// cai outra no lugar ("rate": quantas vezes por segundo).
vec3 still_drops(vec2 p, float cell, vec2 radii, float presence, float rate, int seed) {
	ivec2 id = ivec2(floor(p / cell));
	float r = mix(radii.x, radii.y, pow(rand(id, seed), 2.0));
	vec2 jitter = vec2(rand(id, seed + 1), rand(id, seed + 2)) - 0.5;
	vec2 center = (vec2(id) + 0.5) * cell + jitter * max(cell - 2.0 * r, 0.0);
	float life = fract(TIME * rate + rand(id, seed + 3));
	float size = smoothstep(0.0, 0.015, life) * (1.0 - smoothstep(0.6, 1.0, life));
	vec3 drop = drop_shape(p, center, vec2(r * max(size, 0.4)));
	drop.z *= size * step(rand(id, seed + 4), presence);
	return drop;
}

// A gota que escorre (uma por coluna de 13 cm, pela "presence"): desce aos
// trancos, balançando um pouco, e deixa acima dela um rastro do vidro limpo.
// Em xyz, como em drop_shape; em w, o rastro (0 a 1).
vec4 sliding_drop(vec2 p, float presence, int seed) {
	const float WIDTH = 0.13;
	float column = floor(p.x / WIDTH);
	ivec2 id = ivec2(int(column), 0);
	float on = step(rand(id, seed), presence);
	float period = mix(4.0, 9.0, rand(id, seed + 1));
	float u = fract(TIME / period + rand(id, seed + 2));
	// Para, desce, para: a curva nunca volta para cima.
	float slide = u - sin(u * TAU * 4.0) / (TAU * 4.0);
	float y = mix(1.2, -1.8, slide);
	float phase = rand(id, seed + 3) * TAU;
	float x0 = (column + 0.5) * WIDTH + (rand(id, seed + 4) - 0.5) * 0.04;
	float r = mix(0.011, 0.017, rand(id, seed + 5));
	float x_drop = x0 + sin(y * 9.0 + phase) * 0.012;
	vec3 drop = drop_shape(p, vec2(x_drop, y), vec2(r, r * 1.3));
	float above = p.y - y;
	float x_trail = x0 + sin(p.y * 9.0 + phase) * 0.012;
	float trail = (1.0 - smoothstep(r * 0.35, r * 0.8, abs(p.x - x_trail)))
			* smoothstep(0.0, r, above) * (1.0 - smoothstep(0.05, 0.55, above));
	return vec4(drop.xy, drop.z * on, trail * on);
}

// Todas as gotas: em xy, a "normal" da gota mais forte no pixel; em z, quanto
// é gota; em w, o rastro limpo.
vec4 glass_rain(vec2 p, float amount) {
	float many = pow(amount, 1.5);
	vec3 best = still_drops(p, 0.075, vec2(0.007, 0.016), many * 0.6, 0.05, 11);
	vec3 small = still_drops(p + vec2(0.013, 0.021), 0.032, vec2(0.003, 0.006), many * 0.75, 0.09, 23);
	if (small.z > best.z) {
		best = small;
	}
	vec4 slide = sliding_drop(p, smoothstep(0.25, 1.0, amount) * 0.75, 37);
	if (slide.z > best.z) {
		best = slide.xyz;
	}
	// As gotinhas que a gota que desceu deixou no rastro.
	vec3 left = still_drops(p + vec2(0.007, 0.0), 0.016, vec2(0.0025, 0.004), 0.7, 0.0, 41);
	left.z *= step(0.2, slide.w);
	if (left.z > best.z) {
		best = left;
	}
	return vec4(best, slide.w);
}

// A chuva por cima da vista (antes do vidro): os riscos, a névoa do vidro
// molhado (limpa no rastro e nas gotas) e a borda escura da gota.
vec3 rain_over(vec3 color, vec4 wet, float streaks) {
	vec3 tint = mix(rain_tint_day, rain_tint_night, night);
	color += (color * 0.6 + tint * 0.5) * streaks;
	float haze = rain * 0.16 * (1.0 - max(wet.w, wet.z));
	color = mix(color, tint, haze);
	float rim = smoothstep(0.55, 1.0, length(wet.xy)) * wet.z;
	color *= (1.0 - rim * 0.6) * (1.0 + wet.z * 0.1);
	return color;
}

// O brilho da gota (por cima de tudo): o céu de dia, a sala de noite.
vec3 drop_glint(vec4 wet) {
	float glint = (1.0 - smoothstep(0.0, 0.42, length(wet.xy - vec2(-0.32, 0.4)))) * wet.z;
	vec3 color = mix(vec3(0.28, 0.3, 0.33), reflection_light_color * 0.3, night);
	return color * glint;
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

// A vista de reserva: o horizonte desenhado por código.
vec3 fallback_view(vec3 dir, vec2 uv) {
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
	color += vec3(0.025, 0.028, 0.032) * (1.0 - uv.y) * (1.0 - night * 0.5);
	return color;
}

// Um ângulo que passa da lente do retrato: até "knee" fica igual; dali até
// 90° ele é apertado aos poucos para dentro de "edge" (sem cortar seco, que
// esticaria a última coluna do retrato por toda a janela). Fase 19.6.1: com a
// lente de 130°, quase ninguém chega aqui, e o aperto começa só em 92% da
// lente (era 80%: com a de 100°, a faixa apertada escorregava pela janela
// quando se andava pela sala).
float fit_angle(float angle, float edge) {
	float knee = edge * 0.92;
	float over = abs(angle) - knee;
	if (over <= 0.0) {
		return angle;
	}
	float room = edge - knee;
	return sign(angle) * (knee + room * tanh(over / room));
}

// A vista de verdade: o ponto do retrato na direção do olhar. O -Z da janela
// é o -Z da câmera do retrato (para onde o ponto do mundo olha). Quem olha a
// janela muito de lado (encostado num canto) passa da lente: o ângulo é
// apertado (fit_angle), e a vista fica um pouco comprimida nas beiradas. Em
// "lights", o quanto o ponto é uma luz (0 = fundo, 1 = néon ou janela acesa).
// Em "outside", o quanto a direção passou da lente (0 = dentro; 1 = bem fora).
vec3 portrait_view(vec3 dir, out float lights, out float outside) {
	vec2 edge = atan(view_tan_half_fov);
	vec2 raw = vec2(atan(dir.x, -dir.z), atan(dir.y, -dir.z));
	vec2 past = abs(raw) / edge;
	outside = smoothstep(1.0, 1.35, max(past.x, past.y));
	vec2 angle = vec2(fit_angle(raw.x, edge.x), fit_angle(raw.y, edge.y));
	vec2 ndc = tan(angle) / view_tan_half_fov;
	vec2 uv = clamp(vec2(0.5 + 0.5 * ndc.x, 0.5 - 0.5 * ndc.y), vec2(0.0), vec2(1.0));
	vec3 now = texture(view_texture, uv).rgb;
	vec3 before = texture(view_previous, uv).rgb;
	vec3 color = mix(before, now, view_blend) * mix(view_gain, view_night_gain, night);
	// O que já era claro no retrato passa do branco e brilha (glow).
	float bright = max(max(color.r, color.g), color.b);
	lights = smoothstep(0.25, 0.6, bright);
	color *= 1.0 + view_glow * smoothstep(view_glow_from, 1.0, bright);
	return color;
}

// O vidro por cima do retrato: véu, reflexo da sala e das lâmpadas.
vec3 glass(vec3 color, vec3 dir, vec2 uv) {
	color = mix(color, glass_tint * (0.25 + 0.75 * (1.0 - night)), glass_veil);
	// Fresnel: de frente o vidro reflete pouco; de lado, bem mais.
	float facing = clamp(-dir.z, 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	// De dia, o reflexo some na claridade de fora.
	float shows = 0.3 + 0.7 * night;
	// Um pouco mais claro embaixo (o peitoril e o chão, perto da luz).
	color += room_reflection * reflection_strength * (0.6 + 6.0 * fresnel) * (0.6 + 0.4 * uv.y) * shows;
	// O raio refletido volta para a sala: onde ele passa perto de uma lâmpada,
	// aparece o brilho dela no vidro.
	vec3 back = vec3(dir.x, dir.y, -dir.z);
	for (int i = 0; i < 4; i++) {
		vec4 lamp = reflection_lights[i];
		if (lamp.w <= 0.0) {
			continue;
		}
		float close = max(dot(back, normalize(lamp.xyz - local_position)), 0.0);
		// Um ponto pequeno (a lâmpada) e um halo curto e fraco em volta.
		float glint = exp((close - 1.0) * 20000.0) * 0.9 + exp((close - 1.0) * 1500.0) * 0.06;
		color += reflection_light_color * glint * lamp.w * shows;
	}
	return color;
}

void fragment() {
	vec3 dir = normalize(local_position - local_camera);
	if (dir.z > -0.01) {
		dir.z = -0.01;
	}
	// A chuva (Fase 19.6.1): as gotas no vidro e os riscos lá fora. A vista é
	// vista através da gota (o olhar desviado pela "normal" dela).
	vec4 wet = vec4(0.0);
	float streaks = 0.0;
	vec3 view_dir = dir;
	if (rain > 0.001) {
		wet = glass_rain(local_position.xy, rain);
		streaks = falling_rain(dir, rain);
		view_dir = normalize(vec3(dir.xy - wet.xy * wet.z * drop_refraction, dir.z));
	}
	float m = view_mix;
	vec3 color = vec3(0.0);
	if (m < 1.0) {
		// À noite, a reserva some no primeiro terço da entrada.
		float leaving = mix(1.0 - m, 1.0 - smoothstep(0.0, 0.35, m), night);
		color = rain_over(fallback_view(view_dir, UV), wet, streaks) * leaving;
	}
	if (m > 0.0) {
		float lights = 0.0;
		float outside = 0.0;
		vec3 seen = portrait_view(view_dir, lights, outside);
		// Muito de lado o vidro vira quase espelho: fora da lente do retrato,
		// em vez da beirada comprimida, um véu escuro do vidro.
		seen = mix(seen, glass_tint * (0.12 + 0.6 * (1.0 - night)), outside);
		lights *= 1.0 - outside;
		vec3 view = glass(rain_over(seen, wet, streaks), dir, UV);
		float lit = mix(smoothstep(0.5, 1.0, m), smoothstep(0.3, 0.75, m), lights);
		color += view * mix(m, lit, night);
	}
	ALBEDO = color + drop_glint(wet);
}
