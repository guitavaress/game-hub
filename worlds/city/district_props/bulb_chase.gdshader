// Lâmpadas de letreiro de cassino (bairro Cartas): cada lâmpada é uma cópia
// numa MultiMesh; a "corrida" de luz em volta do painel é feita aqui, pelo
// número da cópia (INSTANCE_ID) e pelo tempo.
shader_type spatial;

uniform vec3 bulb_color : source_color = vec3(1.0, 0.85, 0.62);
// Quantas lâmpadas tem ESTA moldura (cada prédio tem a sua).
instance uniform float bulb_count = 60.0;
// Quantas "ondas" de luz dão a volta ao mesmo tempo, e a velocidade.
uniform float runs = 6.0;
uniform float speed = 0.9;
uniform float energy = 1.5;

varying flat float bulb_index;

void vertex() {
	bulb_index = float(INSTANCE_ID);
}

void fragment() {
	float phase = fract(bulb_index / bulb_count * runs - TIME * speed);
	float on = mix(0.12, 1.0, smoothstep(0.35, 0.5, phase) * (1.0 - smoothstep(0.85, 1.0, phase)));
	ALBEDO = bulb_color;
	ROUGHNESS = 0.3;
	EMISSION = bulb_color * energy * on;
}
