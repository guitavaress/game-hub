// Cor por parte do corpo, sem textura (Fase 13.6). O modelo da Quaternius
// (animated_human.glb) tem o UV de cada vértice numa de 5 faixas na vertical,
// uma por parte; aqui cada faixa ganha a sua cor. Os limites ficam entre as
// faixas (v ~0,12 / 0,30 / 0,42 / 0,63 / 0,86); quem os define é o
// AvatarBody.ZONE_LIMITS, que os passa em "zone_limits".
shader_type spatial;

uniform vec4 zone_limits = vec4(0.2, 0.36, 0.5, 0.72);
uniform vec3 skin_color : source_color = vec3(0.776, 0.557, 0.392);
uniform vec3 eyes_color : source_color = vec3(0.169, 0.114, 0.078);
uniform vec3 hair_color : source_color = vec3(0.231, 0.165, 0.125);
uniform vec3 shirt_color : source_color = vec3(0.290, 0.482, 0.816);
uniform vec3 pants_color : source_color = vec3(0.184, 0.231, 0.322);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	float v = UV.y;
	vec3 color = pants_color;
	if (v < zone_limits.x) {
		color = skin_color;
	} else if (v < zone_limits.y) {
		color = eyes_color;
	} else if (v < zone_limits.z) {
		color = hair_color;
	} else if (v < zone_limits.w) {
		color = shirt_color;
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
}
