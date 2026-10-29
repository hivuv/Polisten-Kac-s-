class_name Building
extends StaticBody2D

## Görüşü kesen ve hareketi engelleyen şehir bloğu.

var rect := Rect2()
var block_color := Color("4a4a55")


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
	draw_rect(Rect2(Vector2.ZERO, rect.size), block_color)
	draw_rect(Rect2(0, 0, rect.size.x, 8.0), block_color.lightened(0.15))
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0, 0, 0, 0.45), false, 3.0)
