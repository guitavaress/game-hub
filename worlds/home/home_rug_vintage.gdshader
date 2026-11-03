// Tapete antigo, feito por código (Fase 17.4): borda em faixas com uma fileira
// de florzinhas, um medalhão no meio e cantos ornados, tudo gasto (o desenho
// some aos poucos onde mais se pisa) e com o pelo em relevo. As medidas são em
// metros (rug_size), então a borda tem a mesma largura em qualquer tamanho.
// O tapete da cabana segue com o home_rug.gdshader.
shader_type spatial;

uniform vec3 field_color : source_color = vec3(0.24, 0.26, 0.29);
uniform vec3 pattern_color : source_color = vec3(0.64, 0.6, 0.54);
uniform vec3 dark_color : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 accent_color : source_color = vec3(0.42, 0.22, 0.16);
uniform vec2 rug_size = vec2(3.2, 2.4);
// Quanto do desenho está gasto (0 = novo, 1 = quase apagado).
uniform float wear : hint_range(0.0, 1.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

// Uma linha fina (1 perto de "d" = 0, até "w" de largura).
float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * rug_size;          // metros, com o meio em 0
	vec2 from_edge = rug_size * 0.5 - abs(p); // distância até a borda em x e em y
	float edge = min(from_edge.x, from_edge.y);

	vec3 color = field_color;
	float design = 0.0;  // 1 onde há desenho claro
	float darkness = 0.0; // 1 onde há desenho escuro

	// Borda: faixa escura de fora, filetes claros e a fileira de florzinhas.
	darkness += 1.0 - smoothstep(0.035, 0.045, edge);
	design += line(edge - 0.065, 0.012);
	design += line(edge - 0.25, 0.012);
	if (edge > 0.075 && edge < 0.24) {
		// Coordenada ao longo da borda (troca de eixo no lado que estiver mais perto).
		float along = from_edge.x < from_edge.y ? p.y : p.x;
		vec2 cell = vec2(fract(along / 0.16) - 0.5, (edge - 0.1575) / 0.16);
		float petals = length(cell) - 0.28 - 0.08 * cos(atan(cell.y, cell.x) * 6.0);
		design += 1.0 - smoothstep(0.0, 0.03, petals);
		darkness += line(length(cell) - 0.08, 0.05);
	}
	// O campo: um medalhão de pétalas no meio (cheio de escuro, com contorno
	// claro e uma roseta), os cantos ornados e uma treliça de losangos bem leve.
	if (edge > 0.26) {
		vec2 m = p / vec2(0.8, 0.55);
		float r = length(m);
		float a = atan(m.y, m.x);
		float lobes = r - 0.05 * cos(a * 8.0) - 0.02 * cos(a * 16.0);
		float inside = 1.0 - smoothstep(0.84, 0.86, lobes);
		darkness += inside * 0.55;
		design += line(lobes - 0.88, 0.025) + line(lobes - 0.8, 0.015);
		// Pontinhos em volta do contorno.
		vec2 dot_cell = vec2(fract(a / TAU * 32.0) - 0.5, (lobes - 0.94) * 12.0);
		design += (1.0 - smoothstep(0.18, 0.26, length(dot_cell))) * step(abs(lobes - 0.94), 0.06);
		float petal = r - 0.12 * abs(cos(a * 4.0));
		design += line(petal - 0.3, 0.025) + line(r - 0.5, 0.012);
		color = mix(color, accent_color, (1.0 - smoothstep(0.14, 0.2, petal)) * 0.85);
		vec2 corner = (rug_size * 0.5 - 0.26) - abs(p);
		float spandrel = length(corner / vec2(0.7, 0.55));
		float spandrel_lobes = spandrel - 0.04 * cos(atan(corner.y, corner.x) * 10.0);
		darkness += (1.0 - smoothstep(0.62, 0.64, spandrel_lobes)) * 0.45;
		design += line(spandrel_lobes - 0.66, 0.025);
		vec2 diamond = p * mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) / 0.2;
		vec2 lattice = abs(fract(diamond) - 0.5);
		design += line(min(lattice.x, lattice.y), 0.03) * 0.12 * (1.0 - inside);
	}
	color = mix(color, dark_color, clamp(darkness, 0.0, 1.0));
	color = mix(color, pattern_color, clamp(design, 0.0, 1.0));

	// O gasto: onde o ruído passa do limiar, o desenho volta para o campo e o pelo
	// fica mais claro (a base aparece). O meio e a frente do sofá gastam mais.
	float worn = fbm(p * 2.6) * 0.75 + fbm(p * 5.5 + 2.3) * 0.35;
	// Manchas grandes e suaves: o tapete não é da mesma cor em todo lugar.
	color *= 0.9 + fbm(p * 0.9 + 3.1) * 0.2;
	worn += (1.0 - smoothstep(0.0, 1.3, length(p * vec2(0.8, 1.2)))) * 0.15;
	float fade = smoothstep(0.55 - wear * 0.3, 1.0 - wear * 0.3, worn);
	color = mix(color, mix(field_color, pattern_color, 0.28), fade * 0.75);

	// O pelo: pontinhos de fio claros e escuros, e um relevo que acompanha.
	float fiber = hash(floor(p * 420.0));
	float tuft = noise(p * 90.0);
	color *= 0.86 + fiber * 0.12 + tuft * 0.1;
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
	NORMAL_MAP = vec3(0.5 + (noise(p * 140.0) - 0.5) * 0.5, 0.5 + (noise(p * 140.0 + 7.3) - 0.5) * 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
