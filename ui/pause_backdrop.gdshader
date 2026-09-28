shader_type canvas_item;
// Fundo do menu de pausa: a cidade que está atrás, desfocada e escurecida.
// Desfoque barato: lê a imagem da tela numa versão reduzida (mipmap).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Quanto desfocar (cada +1 = imagem com metade do tamanho) e escurecer.
uniform float blur = 3.5;
uniform float darkness = 0.5;

void fragment() {
	vec3 color = textureLod(screen_texture, SCREEN_UV, blur).rgb;
	COLOR = vec4(color * (1.0 - darkness), 1.0);
}
