class_name Player
extends CharacterBody2D

## WASD veya ok tuşlarıyla hareket eder, boşluk tuşuyla yakındaki düşmanlara
## saldırır; polis temasından hasar alır, canı bitince ölür.

signal health_changed(health: int)
signal died

const MAX_HEALTH := 100
const SPEED := 260.0
const BODY_RADIUS := 16.0
const ATTACK_RANGE := 80.0
const ATTACK_COOLDOWN := 0.6
const ATTACK_FLASH_TIME := 0.18
const TOUCH_DAMAGE_PER_SECOND := 25.0

var health := float(MAX_HEALTH)
var attack_cooldown := 0.0
var attack_flash := 0.0

var _damage_area: Area2D
var _dead := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	z_index = 5

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BODY_RADIUS
	cs.shape = shape
	add_child(cs)

	_damage_area = Area2D.new()
	_damage_area.collision_layer = 0
	_damage_area.collision_mask = 4
	var dcs := CollisionShape2D.new()
	var dshape := CircleShape2D.new()
	dshape.radius = BODY_RADIUS + 6.0
	dcs.shape = dshape
	_damage_area.add_child(dcs)
	add_child(_damage_area)


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	attack_flash = maxf(attack_flash - delta, 0.0)

	velocity = _read_move_input() * SPEED
	move_and_slide()

	if Input.is_physical_key_pressed(KEY_SPACE):
		_try_attack()

	_apply_contact_damage(delta)
	queue_redraw()


func _read_move_input() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO


func _try_attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = ATTACK_COOLDOWN
	attack_flash = ATTACK_FLASH_TIME
	for node in get_tree().get_nodes_in_group("police"):
		var police := node as Police
		if police and global_position.distance_to(police.global_position) <= ATTACK_RANGE:
			police.knock_out()


func _apply_contact_damage(delta: float) -> void:
	var touching := false
	for body in _damage_area.get_overlapping_bodies():
		if body is Police:
			touching = true
			break
	if not touching or _dead:
		return

	health = maxf(health - TOUCH_DAMAGE_PER_SECOND * delta, 0.0)
	health_changed.emit(int(ceil(health)))
	if health <= 0.0:
		_dead = true
		died.emit()


func _draw() -> void:
	if attack_flash > 0.0:
		draw_arc(Vector2.ZERO, ATTACK_RANGE, -0.6, 0.6, 24, Color(1.0, 1.0, 0.6, 0.8), 4.0)
		draw_arc(Vector2.ZERO, ATTACK_RANGE - 8.0, -0.45, 0.45, 20, Color(1.0, 1.0, 0.6, 0.4), 3.0)
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.35, 0.85, 1.0))
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(0.1, 0.2, 0.3), 2.0)
	var facing := velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
	draw_line(Vector2.ZERO, facing * (BODY_RADIUS + 8.0), Color(0.9, 0.95, 1.0), 3.0)
