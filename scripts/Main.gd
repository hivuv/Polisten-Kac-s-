class_name Main
extends Node2D

## Üstten görünümlü şehir sahnesini kurar, HUD'ı ve oyun sonu ekranını yönetir.

const WORLD_SIZE := Vector2(1900, 1150)
const GROUND_COLOR := Color("23232b")
const BUILDING_COLORS := [
	Color("4a4a55"),
	Color("3e3e49"),
	Color("52525e"),
]

# Sokaklar binalar arasında kalsın diye düzenlenmiş blok yerleşimi.
var building_rects: Array[Rect2] = [
	Rect2(120, 100, 340, 240),
	Rect2(560, 100, 340, 240),
	Rect2(1000, 100, 340, 240),
	Rect2(1440, 100, 340, 240),
	Rect2(120, 440, 340, 240),
	Rect2(560, 440, 340, 240),
	Rect2(1000, 440, 340, 240),
	Rect2(1440, 440, 340, 240),
	Rect2(120, 780, 340, 240),
	Rect2(560, 780, 340, 240),
	Rect2(1000, 780, 340, 240),
	Rect2(1440, 780, 340, 240),
]

var game_over := false

var player: Player
var health_label: Label
var status_label: Label
var game_over_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var ground := ColorRect.new()
	ground.color = GROUND_COLOR
	ground.size = WORLD_SIZE
	ground.z_index = -10
	add_child(ground)

	for i in building_rects.size():
		var building := Building.new()
		building.rect = building_rects[i]
		building.block_color = BUILDING_COLORS[i % BUILDING_COLORS.size()]
		add_child(building)

	_build_borders()

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2(510, 390)
	add_child(player)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	for spawn in [Vector2(1500, 390), Vector2(300, 720), Vector2(1100, 1050)]:
		var police := Police.new()
		police.process_mode = Node.PROCESS_MODE_PAUSABLE
		police.position = spawn
		police.player = player
		police.bounds = Rect2(Vector2.ZERO, WORLD_SIZE)
		add_child(police)

	_build_hud()


func _process(_delta: float) -> void:
	if game_over:
		return
	var chasers := 0
	var min_timer := -1.0
	for node in get_tree().get_nodes_in_group("police"):
		var police := node as Police
		if police and police.state == Police.State.CHASE:
			chasers += 1
			min_timer = police.lose_timer if min_timer < 0.0 else minf(min_timer, police.lose_timer)
	if chasers > 0:
		var remaining := maxf(Police.LOSE_CHASE_TIME - min_timer, 0.0)
		status_label.text = "TAKİP EDİLİYORSUN! Saklan — %.1f sn" % remaining
		status_label.modulate = Color(1.0, 0.45, 0.45)
	else:
		status_label.text = "Saklan, polisten uzak dur"
		status_label.modulate = Color(0.8, 1.0, 0.8)


func _input(event: InputEvent) -> void:
	if not game_over:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_restart()


func _build_borders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var thickness := 100.0
	var defs := [
		[Vector2(WORLD_SIZE.x / 2.0, -thickness / 2.0), Vector2(WORLD_SIZE.x + thickness * 2.0, thickness)],
		[Vector2(WORLD_SIZE.x / 2.0, WORLD_SIZE.y + thickness / 2.0), Vector2(WORLD_SIZE.x + thickness * 2.0, thickness)],
		[Vector2(-thickness / 2.0, WORLD_SIZE.y / 2.0), Vector2(thickness, WORLD_SIZE.y + thickness * 2.0)],
		[Vector2(WORLD_SIZE.x + thickness / 2.0, WORLD_SIZE.y / 2.0), Vector2(thickness, WORLD_SIZE.y + thickness * 2.0)],
	]
	for def in defs:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = def[1]
		cs.shape = shape
		cs.position = def[0]
		body.add_child(cs)
	add_child(body)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	health_label = Label.new()
	health_label.position = Vector2(16, 12)
	health_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(health_label)
	_update_health_label(Player.MAX_HEALTH)

	status_label = Label.new()
	layer.add_child(status_label)
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_top = 12.0
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 22)

	var hint := Label.new()
	layer.add_child(hint)
	hint.text = "WASD / Oklar: hareket    Boşluk: saldır    Binaların arkasına saklan, 5 sn yakalanmadan kal!"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_top = -44.0
	hint.offset_left = 16.0
	hint.add_theme_font_size_override("font_size", 16)

	game_over_panel = Control.new()
	game_over_panel.visible = false
	layer.add_child(game_over_panel)
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	game_over_panel.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH

	var title := Label.new()
	title.text = "YAKALANDIN!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	box.add_child(title)

	var button := Button.new()
	button.text = "Tekrar Oyna (R)"
	button.custom_minimum_size = Vector2(220, 48)
	button.pressed.connect(_restart)
	box.add_child(button)


func _on_player_health_changed(health: int) -> void:
	_update_health_label(health)


func _update_health_label(health: int) -> void:
	health_label.text = "Can: %d" % maxi(health, 0)


func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	game_over_panel.visible = true
	get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
