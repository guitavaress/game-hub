// Fachada dos prédios: material realista (PBR da ambientCG, CC0) + janelas de
// vidro + faixas de néon na cor do bairro. Tudo calculado aqui, pela posição
// no mundo: o prédio (uma caixa CSG) não precisa de coordenadas de textura.
//
//   - Paredes: textura de concreto/tijolo repetida a cada "texture_size" metros,
//     com um "macro-ruído" de 8 m que quebra a repetição.
//   - Térreo: faixa de concreto escuro do chão até "ground_floor_height" (é o
//     que separa "caixa" de "edifício"), com vitrines de loja (acesas à noite).
//   - Janelas: uma grade de "window_cell" metros; o vidro reflete o céu.
//     À noite, parte delas acende (sorteio fixo por janela), uma a uma: luz com
//     degradê (mais clara no alto), algumas com cortina, em 3 temperaturas.
//   - Néon: uma faixa no topo do prédio e outra acima do térreo (loja).
shader_type spatial;

uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_roughness : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wall_tint : source_color = vec3(1.0);
// Tamanho, em metros, de uma repetição da textura da parede.
uniform float texture_size = 3.0;

// Térreo: outra textura (concreto), tingida de escuro.
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_roughness : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 base_tint : source_color = vec3(0.37, 0.41, 0.51);
uniform float base_texture_size = 3.0;

// Janelas: tamanho da "célula" (largura, altura) e a parte dela que é vidro.
uniform vec2 window_cell = vec2(3.0, 3.5);
uniform vec2 window_fraction = vec2(0.5, 0.56);
// Tom do vidro (cada prédio sorteia um: neutro, azulado ou bronze).
uniform vec3 glass_color : source_color = vec3(0.051, 0.071, 0.09);
// Altura do térreo (sem janelas: fica a porta e a vitrine) e do prédio.
uniform float ground_floor_height = 3.6;
uniform float building_height = 15.0;
// Número do prédio, para cada um ter um "sorteio" de janelas acesas diferente.
uniform float seed = 0.0;

// Noite: 0 = dia, 1 = noite.
uniform float night = 0.0;
// Janelas: 0 = todas apagadas, 1 = todas as sorteadas acesas (vão acendendo
// uma a uma no caminho).
uniform float windows_on = 0.0;
// Parte das janelas que acende à noite, e a força da luz delas.
uniform float lit_fraction = 0.3;
uniform float window_energy = 0.9;
// As três temperaturas de luz das janelas: quente, neutra e fria.
uniform vec3 warm_light : source_color = vec3(1.0, 0.78, 0.5);    // #FFC780
uniform vec3 soft_light : source_color = vec3(1.0, 0.89, 0.72);   // #FFE3B8
uniform vec3 cool_light : source_color = vec3(0.81, 0.89, 1.0);   // #CFE3FF

// Néon na cor do bairro. De dia é quase só tinta (emissão 0,15); à noite,
// 3,2 (o glow faz o halo). Mesmos valores de CityDecor.NEON_DAY/NEON_NIGHT.
uniform vec3 neon_color : source_color = vec3(0.2, 0.8, 1.0);
const float NEON_DAY = 0.15;
const float NEON_NIGHT = 3.2;
// Tamanho (m) das manchas do macro-ruído e quanto ele clareia/escurece.
const float MACRO_SIZE = 8.0;
const float MACRO_STRENGTH = 0.1;

// Vitrines no térreo: onde fica o prédio e a porta (a vitrine pula a porta e
// as quinas). O CityBuilding preenche.
uniform vec3 building_center = vec3(0.0, -1000.0, 0.0);
uniform float building_half = 5.0;
uniform vec3 door_normal = vec3(0.0, 0.0, 1.0);
const float SHOP_BOTTOM = 0.5;
const float SHOP_TOP = 3.0;
const float SHOP_CELL = 3.2;
const float SHOP_GLASS = 0.78;     // parte da célula que é vidro
const float SHOP_LIT = 0.6;        // parte das lojas acesas à noite
const float SHOP_ENERGY = 0.5;
const float SHOP_TRANSOM = 2.35;   // altura da travessa (caixilho horizontal)

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Número "aleatório" fixo para cada janela (mesma janela = mesmo número).
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruído suave (0 a 1): "manchas" grandes que variam devagar.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 n = normalize(world_normal);
	bool is_wall = abs(n.y) < 0.5;
	// Coordenada "na parede": horizontal (x ou z, conforme a face) e altura.
	float across = abs(n.x) > abs(n.z) ? world_position.z : world_position.x;
	vec2 wall_uv = is_wall ? vec2(across, -world_position.y) : world_position.xz;
	float height = world_position.y;
	bool is_base = is_wall && height < ground_floor_height;

	vec3 albedo;
	float roughness;
	vec3 normal_map;
	if (is_base) {
		vec2 base_uv = wall_uv / base_texture_size;
		albedo = texture(base_albedo, base_uv).rgb * base_tint;
		roughness = texture(base_roughness, base_uv).g;
		normal_map = texture(base_normal, base_uv).rgb;
	} else {
		vec2 texture_uv = wall_uv / texture_size;
		albedo = texture(wall_albedo, texture_uv).rgb * wall_tint;
		roughness = texture(wall_roughness, texture_uv).g;
		normal_map = texture(wall_normal, texture_uv).rgb;
	}
	// Macro-ruído: a repetição da textura some no meio das manchas.
	vec2 macro_offset = vec2(fract(seed * 0.618), fract(seed * 0.382)) * 10.0;
	albedo *= mix(1.0 - MACRO_STRENGTH, 1.0 + MACRO_STRENGTH, value_noise(wall_uv / MACRO_SIZE + macro_offset));
	float metallic = 0.0;
	vec3 emission = vec3(0.0);

	if (is_wall) {
		// Faixas de néon: no topo e logo acima do térreo.
		bool neon_top = height > building_height - 0.45 && height < building_height - 0.2;
		bool neon_shop = height > ground_floor_height - 0.25 && height < ground_floor_height - 0.1;
		if (neon_top || neon_shop) {
			albedo = neon_color;
			roughness = 0.3;
			emission = neon_color * mix(NEON_DAY, NEON_NIGHT, night);
		} else if (is_base && height > SHOP_BOTTOM - 0.06 && height < SHOP_TOP + 0.06) {
			// Vitrines: células de 3,2 m contadas a partir do meio da face
			// (na frente, a célula do meio é a porta).
			vec3 from_center = world_position - building_center;
			float along = abs(n.x) > abs(n.z) ? from_center.z : from_center.x;
			float cell_index = floor(along / SHOP_CELL + 0.5);
			float inside = along / SHOP_CELL + 0.5 - cell_index;  // 0 a 1 na célula
			bool front = dot(n, door_normal) > 0.9;
			bool usable = !(front && cell_index == 0.0) && abs(along) < building_half - 0.6;
			float glass_half = SHOP_GLASS * 0.5;
			bool in_glass = abs(inside - 0.5) < glass_half && height > SHOP_BOTTOM && height < SHOP_TOP;
			bool in_frame = abs(inside - 0.5) < glass_half + 0.03;
			// Caixilhos: um no meio (vertical) e uma travessa perto do alto.
			bool mullion = abs(inside - 0.5) < 0.012 || abs(height - SHOP_TRANSOM) < 0.04;
			if (usable && in_glass && !mullion) {
				albedo = glass_color * 0.8;
				roughness = 0.08;
				metallic = 0.5;
				normal_map = vec3(0.5, 0.5, 1.0);
				// "Interior" de loja: manchas borradas de luz, prateleiras e um
				// degradê (mais claro no alto). Sorteio fixo por loja.
				vec2 shop = vec2(cell_index, dot(n.xz, vec2(3.0, 7.0))) + seed;
				float lit = step(hash(shop), SHOP_LIT) * smoothstep(0.0, 0.3, windows_on);
				float pick = hash(shop.yx + 1.7);
				vec3 light = pick < 0.5 ? warm_light : (pick < 0.85 ? soft_light : cool_light);
				// Manchas bem marcadas (objetos e cantos escuros), prateleiras e
				// o teto da loja mais claro (luminárias).
				float blobs = value_noise(vec2(along * 1.6, height * 2.0) + shop * 5.0);
				float interior = 0.12 + 0.88 * blobs * blobs;
				float shelves = 0.6 + 0.4 * step(0.2, fract(height * 2.2));
				float ceiling = smoothstep(SHOP_TRANSOM - 0.4, SHOP_TOP, height) * 0.8;
				emission = light * (interior * shelves + ceiling) * lit * SHOP_ENERGY;
			} else if (usable && (in_frame || (in_glass && mullion))) {
				albedo = vec3(0.08);
				roughness = 0.4;
				metallic = 0.5;
			}
		} else if (height > ground_floor_height && height < building_height - 0.8) {
			// Janelas nos andares de cima.
			vec2 cell_position = vec2(across, height - ground_floor_height) / window_cell;
			vec2 cell = floor(cell_position);
			vec2 inside = fract(cell_position);
			vec2 margin = (1.0 - window_fraction) * 0.5;
			bool in_window = inside.x > margin.x && inside.x < 1.0 - margin.x
					&& inside.y > margin.y && inside.y < 1.0 - margin.y;
			// Moldura: uma borda fina e escura em volta do vidro.
			vec2 frame = window_fraction * 0.06;
			bool in_frame = inside.x > margin.x - frame.x && inside.x < 1.0 - margin.x + frame.x
					&& inside.y > margin.y - frame.y && inside.y < 1.0 - margin.y + frame.y;
			if (in_window) {
				albedo = glass_color;
				roughness = 0.06;
				metallic = 0.6;
				normal_map = vec3(0.5, 0.5, 1.0);  // vidro liso
				// Sorteio fixo por janela: só as de número < lit_fraction acendem,
				// e cada uma tem a sua "vez" (acendem uma a uma, com windows_on).
				float draw = hash(cell + vec2(seed, seed * 1.7));
				float turn_on = draw / max(lit_fraction, 0.001);
				// (com windows_on = 0 nenhuma acende; com 1, todas as sorteadas)
				float lit = step(draw, lit_fraction)
						* smoothstep(turn_on, turn_on + 0.08, windows_on * 1.1);
				// Temperatura da luz: 45% quente, 40% neutra, 15% fria.
				float pick = hash(cell.yx + seed);
				vec3 light = pick < 0.45 ? warm_light : (pick < 0.85 ? soft_light : cool_light);
				// Posição dentro do vidro (0 embaixo, 1 no alto).
				float glass_y = (inside.y - margin.y) / window_fraction.y;
				float gradient = mix(0.7, 1.15, glass_y);
				// Cortina: em 60% das janelas, cobre o alto até 30-70% da altura
				// (a luz passa mais fraca e mais quente pelo tecido).
				float curtain_edge = mix(0.3, 0.7, hash(cell + vec2(seed * 0.3, 7.1)));
				bool has_curtain = hash(cell + vec2(3.3, seed)) < 0.6;
				vec3 curtain = (has_curtain && glass_y > curtain_edge) ? vec3(0.5, 0.42, 0.34) : vec3(1.0);
				emission = light * curtain * gradient * lit * window_energy;
			} else if (in_frame) {
				albedo = vec3(0.08);
				roughness = 0.4;
				metallic = 0.5;
			}
		}
	} else {
		// Telhado: a mesma textura, mais escura.
		albedo *= 0.55;
	}

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = 0.7;
	EMISSION = emission;
}
