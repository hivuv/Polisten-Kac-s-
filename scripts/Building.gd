class_name Building
extends StaticBody2D

## Görüşü kesen ve hareketi engelleyen şehir bloğu.

var rect := Rect2()
var block_color := Color("4a4a55")
var is_shop := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	position = rect.position

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	add_child(cs)


func _draw() -> void:
	# Side face and roof lip give the city blocks a subtle faux-3D depth.
	draw_rect(Rect2(Vector2(10, 10), rect.size), Color(0.05, 0.06, 0.09, 0.55))
	draw_rect(Rect2(Vector2.ZERO, rect.size), block_color)
	draw_rect(Rect2(0, 0, rect.size.x, 12.0), block_color.lightened(0.2))
	draw_rect(Rect2(18, 32, rect.size.x - 36, 6), block_color.darkened(0.3))
	for x in range(28, int(rect.size.x) - 20, 58):
		draw_rect(Rect2(x, 52, 26, 30), Color("#263848"))
		draw_rect(Rect2(x + 2, 54, 22, 2), Color("#8bc6d8"))
	if is_shop:
		draw_rect(Rect2(70, 112, rect.size.x - 140, 48), Color("#b8463a"))
		draw_string(ThemeDB.fallback_font, Vector2(132, 145), "SILAH DUKKANI", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0, 0, 0, 0.45), false, 3.0)
