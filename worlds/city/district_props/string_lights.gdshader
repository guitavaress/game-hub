// Lâmpadas do varal (bairro Casual e Festa): a cor de cada lâmpada vem da
// MultiMesh (uma cor por cópia, "use_colors") e a luz própria (energy) muda com
// o dia e a noite: fraquinha de dia, forte à noite.
shader_type spatial;
render_mode shadows_disabled;

uniform float energy = 1.0;

void fragment() {
	// COLOR = cor da cópia (a vertex color da esfera é branca). A MultiMesh
	// guarda a cor "como se vê" (sRGB); o shader trabalha em linear, então
	// convertemos, senão as cores ficam desbotadas.
	vec3 lamp = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = lamp;
	ROUGHNESS = 0.3;
	EMISSION = lamp * energy;
}
