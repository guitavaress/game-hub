// O chão da montanha (Fase 15.8): neve onde o chão olha para cima e rocha
// onde a encosta é mais inclinada que "snow_slope". A neve é projetada de
// cima; a rocha, dos três lados ("triplanar"), para não esticar nas encostas.
// Na Leve, "triplanar" fica desligado: a rocha também vem só de cima.
//
// A malha (terrain_mesh.gd) manda na cor de cada vértice:
//   COLOR.r = quanto é trilha ou mirante (neve batida, mais escura e lisa);
//   COLOR.g = quanto escurece no pé da montanha (até a cor do chão de fora).
//
// As texturas vêm das pastas do TerrainSpec (snow_folder, rock_folder). Sem
// elas, a neve e a rocha ficam só com a cor ("greybox").
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// Neve fria, levemente azulada, sem estourar o branco (albedo <= 0,85).
uniform vec3 snow_tint : source_color = vec3(0.80, 0.83, 0.88);
uniform vec3 rock_tint : source_color = vec3(0.42, 0.42, 0.45);
uniform vec3 path_tint : source_color = vec3(0.55, 0.56, 0.60);
// A cor do chão de fora (CitySkyline.OUTSKIRTS_COLOR).
uniform vec3 base_color : source_color = vec3(0.082, 0.090, 0.110);
// Tamanho de uma repetição da textura, em metros.
uniform float snow_meters = 4.0;
uniform float rock_meters = 6.0;
// Acima disto (a normal apontando para cima), é neve.
uniform float snow_slope : hint_range(0.0, 1.0) = 0.75;
uniform float snow_blend : hint_range(0.0, 0.5) = 0.08;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool triplanar = true;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Normal da textura (0 a 1) virada para -1 a 1, com a força ajustável.
vec3 unpack_normal(vec3 texel) {
	vec3 n = texel * 2.0 - 1.0;
	return vec3(n.xy * normal_strength, n.z);
}

void fragment() {
	vec3 n = normalize(world_normal);

	// Neve: projetada de cima.
	vec2 snow_uv = world_position.xz / snow_meters;
	vec3 snow_color = texture(snow_albedo, snow_uv).rgb * snow_tint;
	float snow_rough = texture(snow_roughness, snow_uv).r;
	vec3 snow_n = unpack_normal(texture(snow_normal, snow_uv).rgb);
	// "Whiteout": soma a inclinação da textura à normal do chão (vista de cima).
	vec3 snow_world = normalize(vec3(snow_n.x + n.x, abs(snow_n.z) * n.y, snow_n.y + n.z));

	// Rocha: dos três lados (pesos pela normal) ou só de cima.
	vec3 rock_color;
	float rock_rough;
	vec3 rock_world;
	vec2 uv_y = world_position.xz / rock_meters;
	vec3 tn_y = unpack_normal(texture(rock_normal, uv_y).rgb);
	vec3 from_y = vec3(tn_y.x + n.x, abs(tn_y.z) * n.y, tn_y.y + n.z);
	if (triplanar) {
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec2 uv_x = world_position.zy / rock_meters;
		vec2 uv_z = world_position.xy / rock_meters;
		rock_color = texture(rock_albedo, uv_x).rgb * w.x
				+ texture(rock_albedo, uv_y).rgb * w.y
				+ texture(rock_albedo, uv_z).rgb * w.z;
		rock_rough = texture(rock_roughness, uv_x).r * w.x
				+ texture(rock_roughness, uv_y).r * w.y
				+ texture(rock_roughness, uv_z).r * w.z;
		vec3 tn_x = unpack_normal(texture(rock_normal, uv_x).rgb);
		vec3 tn_z = unpack_normal(texture(rock_normal, uv_z).rgb);
		vec3 from_x = vec3(abs(tn_x.z) * n.x, tn_x.y + n.y, tn_x.x + n.z);
		vec3 from_z = vec3(tn_z.x + n.x, tn_z.y + n.y, abs(tn_z.z) * n.z);
		rock_world = normalize(from_x * w.x + from_y * w.y + from_z * w.z);
	} else {
		rock_color = texture(rock_albedo, uv_y).rgb;
		rock_rough = texture(rock_roughness, uv_y).r;
		rock_world = normalize(from_y);
	}
	rock_color *= rock_tint;

	// Neve por cima, rocha nas encostas.
	float snow = smoothstep(snow_slope - snow_blend, snow_slope + snow_blend, n.y);
	vec3 color = mix(rock_color, snow_color, snow);
	float rough = mix(rock_rough, snow_rough, snow);
	vec3 normal_world = normalize(mix(rock_world, snow_world, snow));

	// Trilha e mirante: neve batida (mais escura e mais lisa), sem rocha.
	float path = COLOR.r;
	color = mix(color, path_tint * (0.75 + 0.25 * texture(snow_albedo, snow_uv).rgb), path);
	rough = mix(rough, 0.7, path);
	normal_world = normalize(mix(normal_world, snow_world, path));

	// Pé da montanha: escurece até a cor do chão de fora.
	float foot = COLOR.g;
	color = mix(color, base_color, foot);
	rough = mix(rough, 1.0, foot);

	ALBEDO = color;
	ROUGHNESS = rough;
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
}
