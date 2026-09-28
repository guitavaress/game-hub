// Telão de LED (bairro Ação): mostra uma fatia do banner do jogo, que anda
// devagar de um lado para o outro, com linhas de telão. "blend" faz a troca
// para o próximo jogo.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D current_art : source_color, filter_linear_mipmap;
uniform sampler2D next_art : source_color, filter_linear_mipmap;
uniform float current_aspect = 3.1;
uniform float next_aspect = 3.1;
uniform float blend = 0.0;
uniform bool has_art = false;
uniform float brightness = 1.0;
uniform float pan_offset = 0.0;
// Largura / altura do telão (3 x 6 m).
const float SCREEN_ASPECT = 0.5;

vec3 art_slice(sampler2D art, float aspect, vec2 uv, float time) {
	// A imagem cobre a altura do telão; mostramos uma fatia da largura dela.
	float slice = clamp(SCREEN_ASPECT / aspect, 0.0, 1.0);
	float pan = (0.5 + 0.5 * sin(time * 0.12 + pan_offset)) * (1.0 - slice);
	return texture(art, vec2(pan + uv.x * slice, uv.y)).rgb;
}

void fragment() {
	vec3 color = vec3(0.02, 0.025, 0.03);
	if (has_art) {
		color = mix(art_slice(current_art, current_aspect, UV, TIME),
				art_slice(next_art, next_aspect, UV, TIME), blend);
		// Na troca, um "flash" escuro rápido no meio da transição.
		color *= 1.0 - 0.6 * sin(blend * PI);
	}
	// Linhas do telão e uma grade bem fina de LEDs.
	float scan = 0.8 + 0.2 * step(0.45, fract(UV.y * 200.0));
	float grid = 0.9 + 0.1 * step(0.35, fract(UV.x * 100.0));
	ALBEDO = color * scan * grid * brightness;
}
