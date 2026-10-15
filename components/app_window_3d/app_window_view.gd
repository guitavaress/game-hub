class_name AppWindowView
extends Control
## O CONTEÚDO do telão (Fase 14.19): desenha a imagem da janela do app e, por
## cima, o cursor e a barrinha do "segure Esc". O cursor é desenhado pelo hub
## (a janela do app não sabe onde está o mouse no mundo).

const CURSOR_COLOR := Color(1, 1, 1)
const CURSOR_EDGE := Color(0, 0, 0)

var texture: Texture2D = null
## Pixel do cursor, ou Vector2.INF se não for para desenhar.
var cursor: Vector2 = Vector2.INF
## 0 a 1: quanto do Esc longo já passou (0 = nada desenhado).
var exit_progress: float = 0.0
## Texto quando ainda não há imagem.
var idle_text: String = "Livre"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06))
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	else:
		var font := get_theme_default_font()
		var font_size := 48
		var text_size := font.get_string_size(idle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, (size - text_size) / 2.0 + Vector2(0.0, text_size.y * 0.7), idle_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.35))
	if exit_progress > 0.0:
		draw_rect(Rect2(0.0, size.y - 10.0, size.x * clampf(exit_progress, 0.0, 1.0), 10.0), Color(1.0, 0.75, 0.2))
	if cursor != Vector2.INF:
		var shape := PackedVector2Array([
				cursor, cursor + Vector2(0, 26), cursor + Vector2(7, 20),
				cursor + Vector2(13, 32), cursor + Vector2(18, 30),
				cursor + Vector2(12, 18), cursor + Vector2(21, 18)])
		draw_colored_polygon(shape, CURSOR_COLOR)
		draw_polyline(shape + PackedVector2Array([cursor]), CURSOR_EDGE, 2.0)
