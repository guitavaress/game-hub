shader_type canvas_item;
// Vinheta que "fecha" das bordas para o centro.
//   amount = 0: nada escuro;  amount = 1: tela toda preta.
// A borda da escuridão é uma elipse (acompanha o formato da tela) que anda
// dos cantos até o centro; smoothstep deixa a transição suave.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Largura da parte "degradê" entre o claro e o escuro.
uniform float softness = 0.28;

void fragment() {
	float distance_to_center = length(UV - vec2(0.5)) * 1.41421;  // 0 no centro, 1 nos cantos
	float edge = mix(1.05, -softness - 0.02, amount);
	float darkness = smoothstep(edge, edge + softness, distance_to_center);
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
