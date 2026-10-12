// O vidro do espelho (Fase 13.10): mostra a imagem da câmera do espelho
// (um SubViewport), espelhada na horizontal, sem luz própria. Um toque frio e
// um escurecido nas bordas dão cara de vidro.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D reflection : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(0.93, 0.96, 1.0);

void fragment() {
	// A imagem da câmera vem "de dentro do espelho": a direita dela é a
	// esquerda de quem olha. Por isso o x é invertido.
	vec3 color = texture(reflection, vec2(1.0 - UV.x, UV.y)).rgb;
	vec2 edge = min(UV, 1.0 - UV);
	float vignette = smoothstep(0.0, 0.06, min(edge.x, edge.y));
	ALBEDO = color * tint * mix(0.75, 1.0, vignette);
}
