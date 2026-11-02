// Pedra com "neve por cima" (Fase 15.7): rochas e arcos do bioma.
// A textura da pedra é projetada pela posição no mundo (triplanar, como os
// materiais da cidade), e a textura de neve vai por cima só onde a superfície
// aponta para cima (pela normal do mundo). A neve é fixa: não acumula com o
// tempo. O quanto de neve vem do bioma (BiomeSpec.snow_cover):
// 0 = nenhuma; 0,7 = tudo que estiver a menos de ~70° do "para cima".
shader_type spatial;

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 stone_tint : source_color = vec3(1.0);
// Tamanho de uma repetição da textura, em metros.
uniform float stone_meters = 2.0;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 snow_tint : source_color = vec3(0.74, 0.77, 0.82);
uniform float snow_meters = 3.0;
uniform float snow_cover : hint_range(0.0, 1.0) = 0.7;
// Largura da transição pedra -> neve (em "quanto a face aponta para cima").
uniform float snow_edge = 0.1;
uniform float normal_strength = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A normal com a inversa transposta do MODEL_MATRIX: certa mesmo com escala
	// diferente por eixo (as rochas são esticadas para os lados). Numa MultiMesh,
	// o MODEL_NORMAL_MATRIX da Godot junta a cópia sem a inversa e entorta a
	// normal (revisão do Astra, 15.7.1).
	world_normal = normalize(transpose(inverse(mat3(MODEL_MATRIX))) * NORMAL);
}

// Quanto cada um dos três planos (X, Y e Z) pesa, pela normal: a face que olha
// para cima usa a projeção de cima; as laterais, as de lado.
vec3 plane_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

vec4 sample_3(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

// O relevo (normal map) nas três projeções, juntado à normal do mundo pelo
// método "whiteout" (Ben Golus, "Normal Mapping for a Triplanar Shader").
// O mapa comprimido guarda só X e Y: o Z é refeito.
vec3 tangent_normal(sampler2D tex, vec2 uv, float strength) {
	vec2 xy = (texture(tex, uv).xy * 2.0 - 1.0) * strength;
	return vec3(xy, sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0)));
}

vec3 normal_3(sampler2D tex, vec3 p, vec3 n, vec3 w, float strength) {
	vec3 tx = tangent_normal(tex, p.zy, strength);
	vec3 ty = tangent_normal(tex, p.xz, strength);
	vec3 tz = tangent_normal(tex, p.xy, strength);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = plane_weights(n);
	vec3 ps = world_pos / stone_meters;
	vec3 pn = world_pos / snow_meters;

	vec3 stone = sample_3(stone_albedo, ps, w).rgb * stone_tint;
	float stone_rough = sample_3(stone_roughness, ps, w).g;
	vec3 stone_n = normal_3(stone_normal, ps, n, w, normal_strength);
	vec3 snow = sample_3(snow_albedo, pn, w).rgb * snow_tint;
	float snow_rough = sample_3(snow_roughness, pn, w).g;
	vec3 snow_n = normal_3(snow_normal, pn, n, w, normal_strength * 0.6);

	// Onde a neve assenta: quanto mais a face aponta para cima, mais neve. O
	// relevo da pedra entra pela metade, para a borda da neve não sair reta.
	float up = mix(n.y, stone_n.y, 0.5);
	float threshold = 1.0 - snow_cover;
	float mask = smoothstep(threshold - snow_edge, threshold + snow_edge, up);
	mask *= step(0.001, snow_cover);

	ALBEDO = mix(stone, snow, mask);
	ROUGHNESS = mix(stone_rough, snow_rough, mask);
	vec3 final_n = normalize(mix(stone_n, snow_n, mask));
	NORMAL = normalize((VIEW_MATRIX * vec4(final_n, 0.0)).xyz);
}
