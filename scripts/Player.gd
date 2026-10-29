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
const DASH_SPEED := 620.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 1.1

const WEAPON_STATS := {
	"Pistol": {"range": 190.0, "cooldown": 0.42, "damage": 1, "color": Color("#ffd166")},
	"AK-47": {"range": 280.0, "cooldown": 0.12, "damage": 1, "color": Color("#ff8066")},
	"AWM": {"range": 520.0, "cooldown": 0.9, "damage": 3, "color": Color("#8be9fd")},
}

var health := float(MAX_HEALTH)
var attack_cooldown := 0.0
var attack_flash := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var _facing := Vector2.RIGHT
var weapon_name := "Pistol"
var controls_enabled := true
var shot_flash := 0.0

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
	if not controls_enabled:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	attack_flash = maxf(attack_flash - delta, 0.0)
	shot_flash = maxf(shot_flash - delta, 0.0)
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)

	var move_input := _read_move_input()
	if move_input != Vector2.ZERO:
		_facing = move_input
	if Input.is_physical_key_pressed(KEY_SHIFT) and dash_cooldown <= 0.0 and move_input != Vector2.ZERO:
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
	velocity = _facing * (DASH_SPEED if dash_timer > 0.0 else SPEED)
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


func restore_health(amount: int) -> void:
	if _dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(int(ceil(health)))


func _try_attack() -> void:
	var stats: Dictionary = WEAPON_STATS[weapon_name]
	if attack_cooldown > 0.0:
		return
	attack_cooldown = stats["cooldown"]
	attack_flash = ATTACK_FLASH_TIME
	shot_flash = ATTACK_FLASH_TIME
	for node in get_tree().get_nodes_in_group("police"):
		var police := node as Police
		if police == null:
			continue
		var offset := police.global_position - global_position
		if offset.length() > stats["range"] or _facing.dot(offset.normalized()) < 0.45:
			continue
		police.take_hit(stats["damage"])
		break


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
	draw_set_transform(Vector2(2, 7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.35, 0.85, 1.0))
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(0.1, 0.2, 0.3), 2.0)
	var facing := _facing
	var weapon_color: Color = WEAPON_STATS[weapon_name]["color"]
	draw_line(facing * 7.0, facing * 27.0, Color("#35333b"), 7.0)
	draw_line(facing * 8.0, facing * 26.0, weapon_color, 3.0)
	if shot_flash > 0.0:
		draw_line(facing * 27.0, facing * 43.0, Color(1.0, 0.9, 0.55, 0.9), 4.0)
	if dash_timer > 0.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 7.0, 0.0, TAU, 24, Color(0.3, 0.9, 1.0, 0.8), 3.0)
