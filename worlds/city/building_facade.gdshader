// Fachada dos prédios: material realista (PBR da ambientCG, CC0) + janelas de
// vidro + faixas de néon na cor do bairro. Tudo calculado aqui, pela posição
// no mundo: o prédio (uma caixa CSG) não precisa de coordenadas de textura.
//
//   - Paredes: textura de concreto/tijolo repetida a cada "texture_size" metros.
//   - Janelas: uma grade de "window_cell" metros; o vidro reflete o céu.
//     À noite ("night" = 1), parte delas acende (sorteio fixo por janela).
//   - Néon: uma faixa no topo do prédio e outra acima do térreo (loja).
shader_type spatial;

uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_roughness : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wall_tint : source_color = vec3(1.0);
// Tamanho, em metros, de uma repetição da textura da parede.
uniform float texture_size = 3.0;

// Janelas: tamanho da "célula" (largura, altura) e a parte dela que é vidro.
uniform vec2 window_cell = vec2(3.0, 3.5);
uniform vec2 window_fraction = vec2(0.5, 0.56);
uniform vec3 glass_color : source_color = vec3(0.05, 0.07, 0.09);
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
uniform vec3 window_light : source_color = vec3(1.0, 0.78, 0.5);
uniform float lit_fraction = 0.45;

// Néon na cor do bairro. De dia é quase só tinta (emissão 0,15); à noite,
// 3,2 (o glow faz o halo). Mesmos valores de CityDecor.NEON_DAY/NEON_NIGHT.
uniform vec3 neon_color : source_color = vec3(0.2, 0.8, 1.0);
const float NEON_DAY = 0.15;
const float NEON_NIGHT = 3.2;

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

void fragment() {
	vec3 n = normalize(world_normal);
	bool is_wall = abs(n.y) < 0.5;
	// Coordenada "na parede": horizontal (x ou z, conforme a face) e altura.
	float across = abs(n.x) > abs(n.z) ? world_position.z : world_position.x;
	vec2 wall_uv = is_wall ? vec2(across, -world_position.y) : world_position.xz;
	vec2 texture_uv = wall_uv / texture_size;

	vec3 albedo = texture(wall_albedo, texture_uv).rgb * wall_tint;
	float roughness = texture(wall_roughness, texture_uv).g;
	vec3 normal_map = texture(wall_normal, texture_uv).rgb;
	float metallic = 0.0;
	vec3 emission = vec3(0.0);

	if (is_wall) {
		float height = world_position.y;
		// Faixas de néon: no topo e logo acima do térreo.
		bool neon_top = height > building_height - 0.45 && height < building_height - 0.2;
		bool neon_shop = height > ground_floor_height - 0.25 && height < ground_floor_height - 0.1;
		if (neon_top || neon_shop) {
			albedo = neon_color;
			roughness = 0.3;
			emission = neon_color * mix(NEON_DAY, NEON_NIGHT, night);
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
				// Luz da janela: umas mais quentes, outras mais frias.
				vec3 light = mix(window_light, vec3(0.85, 0.82, 0.75), step(0.7, hash(cell.yx + seed)));
				emission = light * lit * 1.3;
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
