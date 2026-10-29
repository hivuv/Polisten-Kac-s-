extends Node2D

var fade := 1.0
var blotches: Array[Vector3] = []

func _ready() -> void:
	z_index = 2
	for i in 7:
		blotches.append(Vector3(randf_range(-13.0, 13.0), randf_range(-8.0, 8.0), randf_range(2.0, 5.0)))

func _process(delta: float) -> void:
	fade = maxf(fade - delta / 24.0, 0.0)
	if fade <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	for spot in blotches:
		draw_circle(Vector2(spot.x, spot.y), spot.z, Color(0.48, 0.035, 0.055, 0.65 * fade))
