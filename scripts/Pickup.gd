class_name Pickup
extends Area2D

var pulse := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse += delta * 4.0
	queue_redraw()

func _draw() -> void:
	var radius := 13.0 + sin(pulse) * 2.0
	draw_circle(Vector2.ZERO, radius, Color(0.25, 1.0, 0.55, 0.25))
	draw_circle(Vector2.ZERO, radius - 4.0, Color(0.25, 1.0, 0.55))
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color.WHITE, 3.0)
	draw_line(Vector2(0, -6), Vector2(0, 6), Color.WHITE, 3.0)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.restore_health(25)
		queue_free()
