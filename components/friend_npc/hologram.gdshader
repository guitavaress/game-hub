// Holograma: translúcido, com a borda mais forte ("fresnel"), linhas de
// varredura subindo e um leve tremor. Soma luz ao que está atrás (blend_add),
// como uma projeção.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.35, 0.75, 1.0);
uniform float intensity = 1.6;
// Linhas de varredura: quantas por metro e a velocidade.
uniform float scan_density = 28.0;
uniform float scan_speed = 0.6;

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// Mais forte nas bordas (onde a superfície fica "de lado" para a câmera).
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float scan = 0.6 + 0.4 * sin(height * scan_density - TIME * scan_speed * TAU);
	float flicker = 0.93 + 0.07 * sin(TIME * 21.0 + height * 3.0);
	ALBEDO = color * intensity;
	ALPHA = clamp((0.08 + edge * 0.9) * scan * flicker, 0.0, 1.0);
}
