shader_type spatial;
// Escada do metrô "de mentira" (Fase 8.7): o chão da cidade não é cortado.
// Este shader desenha, num retângulo no chão, a vista de uma escada que desce:
// para cada ponto, segue o raio da câmera para dentro de um poço imaginário e
// pinta o que ele acertaria (degrau, espelho do degrau ou parede). É a técnica
// de "interior mapping": parece fundo de verdade e custa só este retângulo.
//
// Coordenadas do retângulo (QuadMesh deitado): x = largura, z = comprimento;
// a borda da frente (topo da escada) fica em z = +comprimento/2 e a escada
// desce para -z.

render_mode unshaded, cull_back, shadows_disabled;

uniform vec2 opening = vec2(1.6, 2.6);
uniform float step_depth = 0.37;
uniform float step_height = 0.25;
uniform vec3 stone_color : source_color = vec3(0.55, 0.56, 0.58);
uniform vec3 wall_color : source_color = vec3(0.30, 0.31, 0.34);
// Luz geral: 1 de dia, menos à noite (o script troca).
uniform float light = 1.0;
// Brilho na cor da linha lá no fundo (as luzes da plataforma).
uniform vec3 glow_color : source_color = vec3(0.4, 0.6, 1.0);

varying vec3 local_vertex;

void vertex() {
	local_vertex = VERTEX;
}

// Altura do degrau na posição z (z = 0 no topo, negativo para trás).
float stair_y(float z) {
	return -ceil(max(-z, 0.0) / step_depth) * step_height;
}

bool solid(vec3 q) {
	return abs(q.x) > opening.x * 0.5 || q.z < -opening.y || q.z > 0.0 || q.y < stair_y(q.z);
}

void fragment() {
	vec3 camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 start = local_vertex;
	vec3 dir = normalize(start - camera);
	start.z -= opening.y * 0.5;  // topo da escada em z = 0
	start.y = -0.0005;

	// Anda pelo raio até entrar em algo sólido; depois afina (busca binária).
	float t = 0.0;
	float stride = 0.03;
	for (int i = 0; i < 160; i++) {
		if (solid(start + dir * t)) {
			break;
		}
		t += stride;
	}
	float low = max(t - stride, 0.0);
	float high = t;
	for (int i = 0; i < 6; i++) {
		float mid = (low + high) * 0.5;
		if (solid(start + dir * mid)) {
			high = mid;
		} else {
			low = mid;
		}
	}
	vec3 q = start + dir * high;

	vec3 color;
	if (abs(q.x) > opening.x * 0.5 - 0.002 || q.z < -opening.y + 0.002 || q.z > -0.002) {
		color = wall_color;  // paredes do poço
	} else if (q.y - stair_y(q.z) > -0.004) {
		// A quina da frente de cada degrau tem uma faixa clara, com um toque da
		// cor da linha (como a fita antiderrapante de uma escada de verdade).
		float along = fract(-q.z / step_depth);
		color = along < 0.08 ? mix(stone_color * 1.3, glow_color, 0.35) : stone_color * 0.95;
	} else {
		color = stone_color * 0.6;  // espelho (a parte em pé) do degrau
	}
	float depth = -q.y;
	float fade = exp(-depth * 0.8);
	vec3 glow = glow_color * smoothstep(1.2, 2.0, depth) * 0.2;
	ALBEDO = color * fade * light + glow;
}
