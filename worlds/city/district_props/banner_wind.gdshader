// Estandarte de tecido (bairro RPG): balança ao vento, preso no topo (quanto
// mais embaixo, mais ele mexe). Cada estandarte é uma cópia numa MultiMesh:
// INSTANCE_CUSTOM.x = qual símbolo (0 espada, 1 escudo, 2 losango) e
// INSTANCE_CUSTOM.y = a "fase" do vento (para os estandartes não balançarem juntos).
// De noite, uma luz falsa "de baixo para cima" (sem luz de verdade): o tecido
// clareia perto da barra e o símbolo brilha mais.
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Os 3 símbolos lado a lado (a cor já vem desenhada; o alfa é o formato).
uniform sampler2D symbols : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 cloth_color : source_color = vec3(0.1, 0.07, 0.15);
uniform vec3 trim_color : source_color = vec3(0.58, 0.3, 1.0);
// 0 = dia, 1 = noite (já suavizado: acompanha o acender dos postes).
uniform float night = 0.0;
uniform float sway = 0.05;
uniform float wind_speed = 1.6;
uniform float wind_wave = 3.0;
// Brilho do símbolo de dia e de noite (a luz do néon).
uniform float glow_day = 0.15;
uniform float glow_night = 1.6;

// Tamanho do estandarte, em metros (para a borda ter espessura certa).
const vec2 BANNER_SIZE = vec2(1.0, 3.0);
const float SYMBOL_COUNT = 3.0;

varying flat float symbol_index;

void vertex() {
	symbol_index = INSTANCE_CUSTOM.x;
	// UV.y = 0 no topo (preso) e 1 embaixo (solto).
	VERTEX.x += sin(TIME * wind_speed + UV.y * wind_wave + INSTANCE_CUSTOM.y) * sway * UV.y;
}

void fragment() {
	vec2 uv = UV;
	// Visto por trás, o símbolo não pode sair espelhado.
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}

	// Rabo de andorinha: um V cortado na barra de baixo.
	float from_center = abs(uv.x * 2.0 - 1.0);
	if (uv.y > 1.0 - 0.09 * (1.0 - from_center)) {
		discard;
	}

	// Tecido com fios verticais quase invisíveis.
	float weave = 0.9 + 0.1 * sin(uv.x * 220.0) * sin(uv.y * 70.0);
	vec3 cloth = cloth_color * weave;

	// Faixa no topo e friso fino nas laterais, na cor do bairro.
	float side = min(uv.x, 1.0 - uv.x) * BANNER_SIZE.x;
	float trim = step(uv.y * BANNER_SIZE.y, 0.22);
	trim = max(trim, step(0.05, side) * step(side, 0.09));

	// Símbolo: pega a fatia dele no atlas.
	vec2 symbol_uv = vec2((uv.x + symbol_index) / SYMBOL_COUNT, uv.y);
	vec4 symbol = texture(symbols, symbol_uv);

	// Luz de baixo para cima: forte perto da barra (UV.y = 1), some no meio.
	float uplight = smoothstep(0.3, 1.0, uv.y) * night;

	vec3 base = mix(cloth, trim_color * 0.5, trim);
	ALBEDO = mix(base, symbol.rgb, symbol.a);
	ROUGHNESS = 0.9;

	float glow = mix(glow_day, glow_night, night) * (1.0 + uplight);
	vec3 lit_cloth = cloth_color * 2.0 * uplight;
	EMISSION = lit_cloth + trim_color * trim * glow * 0.25 + symbol.rgb * symbol.a * glow;
}
