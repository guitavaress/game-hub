// Árvore "impostora": um retângulo que sempre vira para a câmera (girando só
// em volta do eixo vertical) e mostra a FOTO da árvore tirada do ângulo mais
// parecido com o de quem olha. As 8 fotos ficam num atlas 4 x 2, gerado uma
// vez por tools/make_tree_impostor.gd. São 2 triângulos por árvore.
//
// Fase 15.7: o mesmo shader serve a outro atlas (o pinheiro do bioma), com
// tinta, a escala de cada instância (numa MultiMesh, cada pinheiro tem a sua
// altura) e um balanço ao vento. Com tinta branca, escala 1 e sem vento (os
// valores padrão), as árvores da cidade ficam iguais a antes.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float frames = 8.0;
uniform float columns = 4.0;
uniform float alpha_cut = 0.45;
// Cor multiplicada na foto (o pinheiro fica mais escuro e frio).
uniform vec3 tint : source_color = vec3(1.0);
// Vento: quanto a ponta da árvore anda para o lado (metros, sem a escala da
// instância). 0 = parada (as árvores da cidade).
uniform float sway_amount = 0.0;
// Velocidade do balanço (radianos por segundo).
uniform float sway_speed = 1.1;
// Altura da árvore no retângulo (metros, sem a escala): a base não se mexe e
// o balanço cresce até a ponta.
uniform float sway_height = 1.0;

varying flat float frame;

void vertex() {
	// Escala da instância (o nó ou a cópia da MultiMesh). Sem escala = 1.
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	if (sway_amount > 0.0) {
		// Cada árvore no seu tempo: a fase sai da posição dela.
		float phase = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;
		float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
		float wave = sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
		// h * h: a base fica parada e a ponta é a que mais anda.
		VERTEX.x += wave * sway_amount * h * h;
	}
	// Vira para a câmera só em Y (a árvore fica sempre em pé).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)) * scale_x, 0.0),
			vec4(0.0, scale_y, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))) * scale_x, 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// De que lado da árvore a câmera está (descontando o giro do nó, que muda
	// de árvore para árvore) -> qual foto usar.
	vec3 to_camera = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	float yaw = atan(MODEL_MATRIX[2].x, MODEL_MATRIX[2].z);
	float angle = atan(to_camera.x, to_camera.z) - yaw;
	frame = mod(round(angle / (TAU / frames)), frames);
}

void fragment() {
	vec2 cell = vec2(mod(frame, columns), floor(frame / columns));
	vec4 color = texture(atlas, (cell + UV) / vec2(columns, frames / columns));
	ALBEDO = color.rgb * tint;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.9;
	// Normal um pouco para cima: a copa pega o sol de cima; e um pouco de luz
	// "atravessando" as folhas quando o sol está atrás.
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.5));
	BACKLIGHT = vec3(0.25, 0.3, 0.2) * tint;
}
