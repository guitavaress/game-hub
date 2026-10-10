// Madeira feita por código (Fase 9.9): tábuas com veios, sem textura baixada.
// A posição vem do mundo (como um triplanar simples): a face de cima usa X e Z,
// as laterais usam a horizontal e a altura. Serve para o piso (com frestas
// entre as tábuas) e para os móveis (sem frestas: planks = false).
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.42, 0.27, 0.16);
// Largura e comprimento de uma tábua (m).
uniform float plank_width = 0.18;
uniform float plank_length = 1.6;
// Largura da fresta escura entre as tábuas (m).
uniform float gap = 0.004;
// Quanto o tom muda de uma tábua para outra (0 a 1).
uniform float variation = 0.16;
uniform float rough = 0.5;
uniform bool planks = true;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

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

void fragment() {
	// p.x = ao longo do veio, p.y = de través.
	vec3 n = abs(world_normal);
	vec2 p;
	if (n.y > n.x && n.y > n.z) {
		p = world_position.xz;
	} else if (n.x > n.z) {
		p = vec2(world_position.z, world_position.y);
	} else {
		p = world_position.xy;
	}
	float row = floor(p.y / plank_width);
	float along = p.x + hash(vec2(row, 3.0)) * plank_length;
	vec2 id = vec2(row, floor(along / plank_length));
	float tone = 1.0 + (hash(id) - 0.5) * 2.0 * variation;
	float fine = noise(vec2(along * 1.5, p.y * 70.0 + hash(id) * 10.0));
	float wide = noise(vec2(along * 0.35, p.y * 12.0 + hash(id) * 7.0));
	float grain = mix(0.8, 1.1, fine * 0.55 + wide * 0.45);
	float edge = 1.0;
	if (planks) {
		float across = fract(p.y / plank_width) * plank_width;
		float lengthwise = fract(along / plank_length) * plank_length;
		float d = min(min(across, plank_width - across), min(lengthwise, plank_length - lengthwise));
		edge = smoothstep(0.0, gap, d);
	}
	ALBEDO = base_color * tone * grain * mix(0.3, 1.0, edge);
	ROUGHNESS = mix(0.9, rough + (fine - 0.5) * 0.12, edge);
	SPECULAR = 0.4;
}
