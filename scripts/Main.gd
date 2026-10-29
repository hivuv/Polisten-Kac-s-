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
var game_started := false
var shop_position := Vector2(510, 560)
var menu_panel: Control
var weapon_label: Label
var selected_weapon := "Pistol"
var weapons := ["Pistol", "AK-47", "AWM"]
var shop_hint: Label
var event_timer := 18.0
var event_label: Label
var event_message := ""
var event_message_timer := 0.0

var player: Player
var health_label: Label
var status_label: Label
var weapon_hud_label: Label
var game_over_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var ground := ColorRect.new()
	ground.color = GROUND_COLOR
	ground.size = WORLD_SIZE
	ground.z_index = -10
	add_child(ground)
	queue_redraw()

	for i in building_rects.size():
		var building := Building.new()
		building.rect = building_rects[i]
		building.block_color = BUILDING_COLORS[i % BUILDING_COLORS.size()]
		building.is_shop = i == 5
		add_child(building)

	_build_borders()

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2(510, 390)
	player.controls_enabled = false
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
		police.active = false
		police.bounds = Rect2(Vector2.ZERO, WORLD_SIZE)
		police.defeated.connect(_on_police_defeated)
		add_child(police)

	_build_hud()
	_build_start_menu()
	_build_shop_marker()


func _process(delta: float) -> void:
	if game_over or not game_started:
		return
	event_timer -= delta
	event_message_timer = maxf(event_message_timer - delta, 0.0)
	if event_timer <= 0.0:
		_start_random_event()
		event_timer = randf_range(24.0, 34.0)
	event_label.text = event_message if event_message_timer > 0.0 else "Etkinlik: %.0f sn" % event_timer
	shop_hint.visible = player.global_position.distance_to(shop_position) < 100.0
	weapon_hud_label.text = "Silah: " + player.weapon_name
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
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if game_over and event.physical_keycode == KEY_R:
		_restart()
	elif game_started and event.physical_keycode == KEY_E and player.global_position.distance_to(shop_position) < 100.0:
		_cycle_shop_weapon()


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

	weapon_hud_label = Label.new()
	weapon_hud_label.position = Vector2(16, 44)
	weapon_hud_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(weapon_hud_label)

	event_label = Label.new()
	layer.add_child(event_label)
	event_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	event_label.offset_top = 48.0
	event_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 18)

	var hint := Label.new()
	layer.add_child(hint)
	hint.text = "WASD / Oklar: hareket    Shift: atılma    Boşluk: ateş (yönüne)    E: silah dükkânı"
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



func _start_random_event() -> void:
	var event := randi_range(0, 2)
	match event:
		0:
			var pickup := Pickup.new()
			pickup.position = _find_open_spot()
			add_child(pickup)
			event_message = "TEDARİK DÜŞTÜ! Yeşil işarete ulaş: +25 can"
		1:
			player.restore_health(15)
			event_message = "İLK YARDIM! +15 can"
		2:
			for node in get_tree().get_nodes_in_group("police"):
				var police := node as Police
				if police and police.state == Police.State.CHASE:
					police.lose_timer += 2.5
			event_message = "SİS BASTI! Polislerin takibi yavaşladı"
	event_message_timer = 4.0


func _find_open_spot() -> Vector2:
	for attempt in 20:
		var candidate := Vector2(randf_range(80.0, WORLD_SIZE.x - 80.0), randf_range(80.0, WORLD_SIZE.y - 80.0))
		var blocked := false
		for rect in building_rects:
			if rect.grow(30.0).has_point(candidate):
				blocked = true
				break
		if not blocked:
			return candidate
	return Vector2(510, 390)



func _draw() -> void:
	# City streets, lane markings and raised-looking pavements under every block.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#303841"))
	for rect in building_rects:
		draw_rect(rect.grow(14.0), Color("#a6a39a"))
		draw_rect(rect.grow(8.0), Color("#686b68"))
	for y in [390.0, 730.0, 1070.0]:
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color("#d2b96c", 0.45), 3.0)
		for x in range(0, int(WORLD_SIZE.x), 90):
			draw_line(Vector2(x, y), Vector2(x + 42, y), Color("#e8dfb9", 0.72), 3.0)
	for x in [500.0, 940.0, 1380.0]:
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color("#d2b96c", 0.45), 3.0)
		for y in range(0, int(WORLD_SIZE.y), 90):
			draw_line(Vector2(x, y), Vector2(x, y + 42), Color("#e8dfb9", 0.72), 3.0)
	draw_circle(shop_position, 22.0, Color("#e8a84a"))
	draw_string(ThemeDB.fallback_font, shop_position + Vector2(-12, 7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#29231c"))


func _build_start_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu_panel = Control.new()
	menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.06, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.add_child(shade)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 430)
	menu_panel.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-215, -215)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "SON ÇIKIŞ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Kaç, saklan ve silahını seç"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	weapon_label = Label.new()
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(weapon_label)
	for weapon in weapons:
		var button := Button.new()
		button.text = weapon + "  —  " + _weapon_description(weapon)
		button.custom_minimum_size.y = 48
		button.pressed.connect(_select_weapon.bind(weapon))
		stack.add_child(button)
	var start_button := Button.new()
	start_button.text = "ŞEHRE GİR"
	start_button.custom_minimum_size.y = 54
	start_button.pressed.connect(_start_game)
	stack.add_child(start_button)
	_select_weapon(selected_weapon)


func _select_weapon(weapon: String) -> void:
	selected_weapon = weapon
	if weapon_label:
		weapon_label.text = "Başlangıç silahı: " + weapon


func _start_game() -> void:
	game_started = true
	menu_panel.visible = false
	player.weapon_name = selected_weapon
	player.controls_enabled = true
	for node in get_tree().get_nodes_in_group("police"):
		var police := node as Police
		if police:
			police.active = true


func _weapon_description(weapon: String) -> String:
	match weapon:
		"AK-47": return "hızlı otomatik"
		"AWM": return "uzun menzil"
		_: return "dengeli"


func _build_shop_marker() -> void:
	shop_hint = Label.new()
	shop_hint.visible = false
	shop_hint.text = "E: dükkândan sonraki silahı al"
	shop_hint.add_theme_font_size_override("font_size", 18)
	var layer := get_node_or_null("HUDLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "HUDLayer"
		add_child(layer)
	layer.add_child(shop_hint)
	shop_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	shop_hint.offset_top = -76.0
	shop_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cycle_shop_weapon() -> void:
	var index := weapons.find(player.weapon_name)
	player.weapon_name = weapons[(index + 1) % weapons.size()]
	_select_weapon(player.weapon_name)
	if event_label:
		event_message = "DÜKKÂN: " + player.weapon_name
		event_message_timer = 2.0


func _on_police_defeated(at_position: Vector2) -> void:
	var blood := preload("res://scripts/Blood.gd").new()
	blood.position = at_position
	add_child(blood)
