shader_type spatial;
// A chama da fogueira (Fase 17.7): planos cruzados com ruído que sobe, somando
// luz (blend_add), sem textura e sem ordenar transparência. UV.y = 0 em cima.
// UV2.x muda o desenho de cada plano, para eles não repetirem.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// 0 = apagada (de dia), 1 = acesa.
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float speed = 1.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 mid_color : source_color = vec3(0.95, 0.48, 0.16);
uniform vec3 edge_color : source_color = vec3(0.55, 0.12, 0.03);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amount = 0.5;
	for (int k = 0; k < 4; k++) {
		value += amount * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amount *= 0.5;
	}
	return value;
}

void fragment() {
	float h = 1.0 - UV.y;            // 0 embaixo, 1 em cima
	float seed = UV2.x * 13.0;
	float t = TIME * speed;
	// A chama balança mais em cima do que embaixo.
	float sway = (noise(vec2(h * 2.5 - t * 1.3, seed)) - 0.5) * 0.55 * h;
	float x = (UV.x - 0.5) * 2.0 + sway;
	// Forma de gota: larga embaixo, fina em cima.
	float width = mix(0.9, 0.12, pow(h, 1.3));
	float body = 1.0 - smoothstep(width * 0.3, width, abs(x));
	// Línguas: ruído que sobe e rasga a borda de cima.
	float n = fbm(vec2(UV.x * 3.2 + seed, h * 2.2 - t * 1.9));
	float heat = body * smoothstep(0.0, 0.06, h) * clamp(n * 2.1 - h * 1.25 + 0.22, 0.0, 1.0);
	vec3 color = mix(edge_color, mid_color, smoothstep(0.08, 0.45, heat));
	color = mix(color, core_color, smoothstep(0.5, 0.95, heat));
	ALBEDO = color * heat * 1.5 * strength;
}
