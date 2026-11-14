// O MODELO de perto de uma árvore (Fase 19.2; em uso desde a 19.3): a malha feita no Blender
// (tools/blender/gerar_arvore.py), desenhada numa MultiMesh por material
// (a casca e as folhas usam este mesmo shader, com "foliage" diferente).
//
//   - vento: a árvore toda enverga para o lado do vento (cresce com a altura
//     ao quadrado: o pé fica parado) e os galhos tremem um pouco, mais na
//     ponta. Casca e folhas fazem a MESMA conta, então a folha não se solta
//     do galho;
//   - folhas: o "cartão" de agulhas é recortado pela transparência da foto;
//     a normal aponta para fora da copa (a copa ganha volume, em vez de
//     cartões chapados); a cor dos vértices (do Blender) escurece o miolo;
//   - troca pela impostora: de longe quem desenha é a foto (tree_impostor),
//     e as duas trocam numa faixa de "swap_band" m em volta de
//     "swap_distance", com um pontilhado que se completa (cada ponto da tela
//     é de uma OU da outra). A distância é sempre a da câmera do jogador,
//     também na sombra (MAIN_CAM_INV_VIEW_MATRIX). 19.3: cada árvore troca
//     na sua distância (swap_jitter, sorteado pela posição dela, a mesma
//     conta da impostora): andando, elas trocam uma de cada vez.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
// true nas folhas (recorte, normal da copa, cor dos vértices, luz por trás).
uniform bool foliage = false;
uniform vec3 tint : source_color = vec3(1.0);
// Largura da foto das folhas (px): de longe, a transparência é engrossada
// para as agulhas não sumirem nas versões menores da textura.
uniform float texture_size = 512.0;
uniform float alpha_cut = 0.5;
// Medidas do modelo, sem a escala da cópia (m).
uniform float tree_height = 10.0;
uniform float crown_radius = 2.5;
// Vento: quanto a ponta anda (m, na altura do modelo), a velocidade e o tremor.
uniform float sway_amount = 0.18;
uniform float sway_speed = 1.1;
uniform float flutter_amount = 0.035;
uniform vec2 wind_direction = vec2(0.8, 0.6);
// A troca pela impostora (m). 0 = sem troca (o modelo sempre).
uniform float swap_distance = 0.0;
uniform float swap_band = 4.0;
// Quanto a distância da troca de cada árvore varia (fração, para cada lado).
uniform float swap_jitter = 0.0;

// 0 = só o modelo; 1 = só a impostora (por cópia).
varying flat float far_weight;

// Ruído de tela que não forma desenho (o mesmo na impostora).
float dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

// A distância da troca desta árvore (a mesma conta no tree_impostor.gdshader).
float own_swap_distance(vec3 origin, float base, float jitter) {
	float pick = fract(sin(dot(origin.xz, vec2(39.3468, 11.1353))) * 24634.6345);
	return base * (1.0 + jitter * (pick * 2.0 - 1.0));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[1].xyz);
	far_weight = 0.0;
	if (swap_distance > 0.0) {
		float d = distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz, origin);
		float own = own_swap_distance(origin, swap_distance, swap_jitter);
		far_weight = smoothstep(own - swap_band, own + swap_band, d);
	}
	if (far_weight >= 1.0) {
		// Longe: a cópia toda vira um ponto (nada para desenhar).
		VERTEX = origin;
	} else {
		vec3 local = VERTEX - origin;
		// Cada árvore no seu tempo: a fase sai da posição dela.
		float phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;
		float h = clamp(local.y / (tree_height * scale), 0.0, 1.0);
		float wave = sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
		VERTEX.xz += normalize(wind_direction) * wave * sway_amount * scale * h * h;
		// O tremor dos galhos: nada no tronco, o máximo na ponta do galho.
		float reach = clamp(length(local.xz) / (crown_radius * scale), 0.0, 1.0);
		float shake = sin(TIME * 3.1 + phase + dot(local, vec3(1.7, 1.1, 1.3)));
		VERTEX += vec3(0.4, 1.0, 0.3) * shake * flutter_amount * scale * reach * reach;
		if (foliage) {
			// Para fora da copa (um pouco achatado: a copa é mais alta que larga).
			vec3 outward = vec3(local.x, (local.y - tree_height * scale * 0.45) * 0.5, local.z);
			NORMAL = normalize(mix(NORMAL, normalize(outward + vec3(0.0, 0.01, 0.0)), 0.7));
		}
	}
}

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	vec3 color = texel.rgb * tint;
	float alpha = 1.0;
	if (foliage) {
		color *= COLOR.rgb;
		// Quanto a textura está diminuída aqui (o nível do mipmap): de longe a
		// transparência engrossa, e a copa não fica rala.
		vec2 px = UV * texture_size;
		float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
		alpha = texel.a * (1.0 + 0.3 * lod);
		// A Godot vira a normal do lado de trás do cartão; a da copa vale dos dois lados.
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		BACKLIGHT = vec3(0.18, 0.22, 0.12) * tint;
	}
	ALBEDO = color;
	ROUGHNESS = foliage ? 0.8 : 0.95;
	// Agulha quase não reflete o céu (sem isso, o alto da copa fica pálido à noite).
	SPECULAR = foliage ? 0.2 : 0.4;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Na faixa da troca: os pontos da impostora saem daqui.
	if (far_weight > 0.0 && dither(FRAGCOORD.xy) < far_weight) {
		discard;
	}
}
