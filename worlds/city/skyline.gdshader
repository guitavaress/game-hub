// Skyline do horizonte (veja skyline.gd): silhuetas numa cor só, com
// janelinhas acesas à noite. Sem luz, sem neblina (a cor já vem da neblina).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Vermelho = prédio; verde = janela; azul = janela que acende à noite.
uniform sampler2D silhouettes : filter_nearest, repeat_enable;
uniform vec3 haze_color : source_color = vec3(0.45, 0.48, 0.52);
uniform vec3 night_color : source_color = vec3(0.043, 0.051, 0.078);
uniform vec3 window_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float night = 0.0;
// Altura do cilindro (m): o UV vem da posição, não do mesh.
uniform float ring_height = 120.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Volta em torno do anel (0 a 1) e altura (0 = topo, 1 = base).
	vec2 uv = vec2(atan(local_position.x, local_position.z) / TAU + 0.5,
			0.5 - local_position.y / ring_height);
	vec4 mask = texture(silhouettes, uv);
	if (mask.r < 0.5) {
		discard;  // céu
	}
	vec3 color = mix(haze_color, night_color, night);
	// Janelas: um tiquinho mais claras de dia; as sorteadas acendem à noite.
	color = mix(color, color * 1.15, mask.g * (1.0 - night));
	color = mix(color, window_color * 1.1, mask.b * night);
	ALBEDO = color;
}
