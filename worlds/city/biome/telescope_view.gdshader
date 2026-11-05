shader_type canvas_item;
// O campo da luneta (Fase 17.8): um círculo claro no meio da tela, a borda
// escura e macia em volta e um anel fino de latão no limite. Só escurece:
// o que fica dentro do círculo é a vista de verdade (a câmera).

uniform float radius : hint_range(0.1, 0.8) = 0.43;   // em alturas de tela
uniform float softness : hint_range(0.0, 0.2) = 0.035;
uniform vec4 rim_color : source_color = vec4(0.62, 0.45, 0.2, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * vec2(size.x / size.y, 1.0);
	float d = length(p);
	float outside = smoothstep(radius - softness, radius + softness * 0.5, d);
	// O anel de latão, logo na borda.
	float rim = smoothstep(radius - softness * 1.4, radius - softness * 0.5, d)
			* (1.0 - smoothstep(radius - softness * 0.2, radius + softness * 0.4, d));
	vec3 color = mix(vec3(0.0), rim_color.rgb * 0.45, rim);
	COLOR = vec4(color, clamp(outside + rim * 0.6, 0.0, 1.0) * strength);
}
