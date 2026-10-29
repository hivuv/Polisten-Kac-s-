class_name Police
extends CharacterBody2D

## Oyuncuyu görüş hattında yakalarsa takip eder; oyuncu saklanıp
## 5 saniye yakalanmadan kalırsa takibi bırakıp devriyeye döner.

enum State { PATROL, CHASE }

signal defeated(at_position: Vector2)

const CHASE_SPEED := 210.0
const PATROL_SPEED := 90.0
const SIGHT_RANGE := 420.0
const LOSE_CHASE_TIME := 5.0
const BODY_RADIUS := 15.0

var player: Player
var bounds := Rect2(Vector2.ZERO, Vector2(1900, 1150))
var state := State.PATROL
var lose_timer := 0.0
var health := 3
var active := true

var _last_seen := Vector2.ZERO
var _patrol_target := Vector2.ZERO
var _patrol_wait := 0.0
var _has_target := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	z_index = 4
	add_to_group("police")

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BODY_RADIUS
	cs.shape = shape
	add_child(cs)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if player == null or not is_instance_valid(player):
		return

	var can_see := _has_line_of_sight()
	if can_see:
		_last_seen = player.global_position

	match state:
		State.PATROL:
			if can_see:
				state = State.CHASE
				lose_timer = 0.0
			else:
				_patrol(delta)
		State.CHASE:
			if can_see:
				lose_timer = 0.0
			else:
				lose_timer += delta
				if lose_timer >= LOSE_CHASE_TIME:
					state = State.PATROL
					_has_target = false
					return
			_chase()

	queue_redraw()


func take_hit(damage: int) -> void:
	health -= damage
	if health <= 0:
		defeated.emit(global_position)
		queue_free()


func _chase() -> void:
	var to_target := _last_seen - global_position
	if to_target.length() > 10.0:
		velocity = to_target.normalized() * CHASE_SPEED
	else:
		# Son görülen noktadayız; oyuncu görünmüyor, kaçış sayacı işliyor.
		velocity = Vector2.ZERO
	move_and_slide()


func _patrol(delta: float) -> void:
	if not _has_target:
		_pick_patrol_target()
		return
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		velocity = Vector2.ZERO
		return

	var to_target := _patrol_target - global_position
	if to_target.length() < 12.0:
		_patrol_wait = randf_range(0.8, 2.0)
		_pick_patrol_target()
		return

	velocity = to_target.normalized() * PATROL_SPEED
	move_and_slide()


func _pick_patrol_target() -> void:
	for i in 10:
		var candidate := Vector2(
			randf_range(80.0, bounds.size.x - 80.0),
			randf_range(80.0, bounds.size.y - 80.0)
		)
		if not _point_blocked(candidate):
			_patrol_target = candidate
			_has_target = true
			return
	_patrol_target = global_position
	_has_target = true


func _point_blocked(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	var space := get_world_2d().direct_space_state
	return not space.intersect_point(query).is_empty()


func _has_line_of_sight() -> bool:
	var dist := global_position.distance_to(player.global_position)
	if dist > SIGHT_RANGE:
		return false
	var space := get_world_2d().direct_space_state
	# Işın sadece binaların bulunduğu katmana çarpar; oyuncu saklanınca görüş kesilir.
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	return space.intersect_ray(query).is_empty()


func _draw() -> void:
	var body_color := Color(0.18, 0.32, 0.9) if state == State.CHASE else Color(0.25, 0.3, 0.55)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 20, Color(0.05, 0.1, 0.25), 2.0)
	var facing := velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
	draw_line(Vector2.ZERO, facing * (BODY_RADIUS + 7.0), Color(0.85, 0.9, 1.0), 3.0)
	if state == State.CHASE:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 6.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.3, 0.8), 2.0)
