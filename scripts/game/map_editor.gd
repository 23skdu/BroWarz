# scripts/game/map_editor.gd
extends Node2D

var map_data: MapData
var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_sprite: Sprite2D
var camera: Camera2D
var hex_grid: HexGrid = HexGrid.new(16.0)
var selected_terrain: int = MapData.Terrain.PLAINS
var brush_radius: int = 1
var painting: bool = false
var hover_hex: Vector2i = Vector2i(-1, -1)

const TILE_SIZE: float = 16.0
const TERRAIN_PPT: int = 4

var map_name_edit: LineEdit
var author_edit: LineEdit
var share_code_edit: LineEdit
var status_label: Label
var brush_btn: Button

func _ready() -> void:
	if GameManager.current_map != null and GameManager.match_mode == GameManager.Mode.MAP_EDITOR:
		map_data = GameManager.current_map
	else:
		map_data = MapData.new(128, 128)
		map_data.name = "Custom Battlefield"
		map_data.author = "Commander"
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)

	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_sprite = Sprite2D.new()
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.texture = terrain_texture
	terrain_sprite.scale = Vector2(TILE_SIZE / float(TERRAIN_PPT), TILE_SIZE / float(TERRAIN_PPT))
	terrain_sprite.centered = false
	terrain_sprite.z_index = -5
	add_child(terrain_sprite)

	_build_ui()

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var top_vbox := VBoxContainer.new()
	top_vbox.position = Vector2(12, 10)
	ui.add_child(top_vbox)

	# Row 1: Terrain Hex Brushes (Desert, Water Sea/River, Forest, Plains, Mountain, Hills, Swamp, Urban, Road, Bridge)
	var terrain_bar := HBoxContainer.new()
	top_vbox.add_child(terrain_bar)

	var terrains := [
		["Desert", MapData.Terrain.DESERT],
		["Water (Sea)", MapData.Terrain.SEA],
		["Water (River)", MapData.Terrain.RIVER],
		["Forest", MapData.Terrain.FOREST],
		["Plains", MapData.Terrain.PLAINS],
		["Mountain", MapData.Terrain.MOUNTAIN],
		["Hills", MapData.Terrain.HILLS],
		["Swamp", MapData.Terrain.SWAMP],
		["Urban", MapData.Terrain.URBAN],
		["Road", MapData.Terrain.ROAD],
		["Bridge", MapData.Terrain.BRIDGE],
	]
	for t in terrains:
		var b := Button.new()
		b.text = String(t[0])
		var tid: int = int(t[1])
		b.pressed.connect(func():
			selected_terrain = tid
			_set_status("Selected terrain brush: %s" % MapData.terrain_name(tid))
		)
		terrain_bar.add_child(b)

	brush_btn = Button.new()
	brush_btn.text = "Hex Brush: 1"
	brush_btn.pressed.connect(_cycle_brush_size)
	terrain_bar.add_child(brush_btn)

	var fill_btn := Button.new()
	fill_btn.text = "Fill Map"
	fill_btn.pressed.connect(_fill_entire_map)
	terrain_bar.add_child(fill_btn)

	# Row 2: Map Metadata, Save/Load File, Share Code Export/Import, Test Play, Main Menu
	var action_bar := HBoxContainer.new()
	top_vbox.add_child(action_bar)

	map_name_edit = LineEdit.new()
	map_name_edit.placeholder_text = "Map Name"
	map_name_edit.text = map_data.name
	map_name_edit.custom_minimum_size = Vector2(160, 0)
	action_bar.add_child(map_name_edit)

	author_edit = LineEdit.new()
	author_edit.placeholder_text = "Author"
	author_edit.text = map_data.author
	author_edit.custom_minimum_size = Vector2(120, 0)
	action_bar.add_child(author_edit)

	var save_btn := Button.new()
	save_btn.text = "Save Map (.bwm)"
	save_btn.pressed.connect(_save_map)
	action_bar.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Map (.bwm)"
	load_btn.pressed.connect(_load_map)
	action_bar.add_child(load_btn)

	share_code_edit = LineEdit.new()
	share_code_edit.placeholder_text = "Paste or Copy Share Code (BWM1:...)"
	share_code_edit.custom_minimum_size = Vector2(260, 0)
	action_bar.add_child(share_code_edit)

	var export_share_btn := Button.new()
	export_share_btn.text = "Copy Share Code"
	export_share_btn.pressed.connect(_export_share_code)
	action_bar.add_child(export_share_btn)

	var import_share_btn := Button.new()
	import_share_btn.text = "Import Share Code"
	import_share_btn.pressed.connect(_import_share_code)
	action_bar.add_child(import_share_btn)

	var play_btn := Button.new()
	play_btn.text = "Play vs AI"
	play_btn.pressed.connect(_test_play_map)
	action_bar.add_child(play_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Validate Map"
	validate_btn.pressed.connect(_validate_current_map)
	action_bar.add_child(validate_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func(): SceneManager.goto_scene("res://scenes/main_menu.tscn"))
	action_bar.add_child(menu_btn)

	status_label = Label.new()
	status_label.text = "Hex Map Editor — Paint hexes with LMB, Pan camera with WASD/Arrows, Save or Export Share Code."
	top_vbox.add_child(status_label)

func _set_status(msg: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg

func _cycle_brush_size() -> void:
	brush_radius = 1 if brush_radius >= 4 else (brush_radius + 1)
	if is_instance_valid(brush_btn):
		brush_btn.text = "Hex Brush: %d" % brush_radius

func _fill_entire_map() -> void:
	for i in range(map_data.tiles.size()):
		map_data.tiles[i] = selected_terrain
	_refresh_image()
	_set_status("Filled entire map with %s." % MapData.terrain_name(selected_terrain))

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos + camera.position - get_viewport_rect().size * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = event.pressed
			if painting:
				_paint_at_screen(event.position)
	elif event is InputEventMouseMotion:
		var world_pos := _screen_to_world(event.position)
		hover_hex = hex_grid.world_to_hex(world_pos)
		if painting:
			_paint_at_screen(event.position)
		queue_redraw()

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector2.ZERO:
		camera.position += pan * 520.0 * delta

func _paint_at_screen(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var center_tx := int(world_pos.x / TILE_SIZE)
	var center_ty := int(world_pos.y / TILE_SIZE)
	var changed := false
	var r := brush_radius - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + 1:
				var tx := center_tx + dx
				var ty := center_ty + dy
				if map_data.set_terrain(tx, ty, selected_terrain):
					_update_tile_pixels(tx, ty)
					changed = true
	if changed:
		terrain_texture.update(terrain_image)
		queue_redraw()

func _update_tile_pixels(tx: int, ty: int) -> void:
	var t := map_data.get_terrain(tx, ty)
	var h_noise := float(((tx * 73856093) ^ (ty * 19349663)) & 255) / 127.5 - 1.0
	var base_c := UnitVisual.terrain_base_color(t, h_noise)
	var bx := tx * TERRAIN_PPT
	var by := ty * TERRAIN_PPT
	for py in range(TERRAIN_PPT):
		for px in range(TERRAIN_PPT):
			terrain_image.set_pixel(bx + px, by + py, base_c)

func _refresh_image() -> void:
	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_sprite.texture = terrain_texture
	queue_redraw()

func _sync_metadata() -> void:
	if is_instance_valid(map_name_edit) and not map_name_edit.text.strip_edges().is_empty():
		map_data.name = map_name_edit.text.strip_edges()
	if is_instance_valid(author_edit) and not author_edit.text.strip_edges().is_empty():
		map_data.author = author_edit.text.strip_edges()

func _save_map() -> void:
	_sync_metadata()
	var err := MapSerializer.save_to_file(map_data)
	if err == OK:
		var fname := MapSerializer.sanitize_filename(map_data.name)
		_set_status("Saved map '%s' to user://maps/%s.bwm (and user://custom_map.bwm)." % [map_data.name, fname])
	else:
		_set_status("Failed to save map (error %d)." % err)

func _load_map() -> void:
	_sync_metadata()
	var fname := MapSerializer.sanitize_filename(map_data.name)
	var candidate := "%s/%s.bwm" % [MapSerializer.MAPS_DIR, fname]
	var loaded := MapSerializer.load_from_file(candidate)
	if loaded == null:
		loaded = MapSerializer.load_from_file("user://custom_map.bwm")
	if loaded != null:
		map_data = loaded
		if is_instance_valid(map_name_edit):
			map_name_edit.text = map_data.name
		if is_instance_valid(author_edit):
			author_edit.text = map_data.author
		_refresh_image()
		_set_status("Loaded map '%s' by %s." % [map_data.name, map_data.author])
	else:
		_set_status("No saved map found for '%s'." % map_data.name)

func _export_share_code() -> void:
	_sync_metadata()
	var code := MapSerializer.to_share_code(map_data)
	if is_instance_valid(share_code_edit):
		share_code_edit.text = code
	DisplayServer.clipboard_set(code)
	_set_status("Share code generated and copied to clipboard (%d chars)!" % code.length())

func _import_share_code() -> void:
	var code := ""
	if is_instance_valid(share_code_edit) and not share_code_edit.text.strip_edges().is_empty():
		code = share_code_edit.text.strip_edges()
	else:
		code = DisplayServer.clipboard_get().strip_edges()
	var imported := MapSerializer.from_share_code(code)
	if imported != null:
		map_data = imported
		if is_instance_valid(map_name_edit):
			map_name_edit.text = map_data.name
		if is_instance_valid(author_edit):
			author_edit.text = map_data.author
		_refresh_image()
		_set_status("Imported shared map '%s' by %s!" % [map_data.name, map_data.author])
	else:
		_set_status("Invalid share code. Must start with BWM1:...")

func _validate_current_map() -> void:
	_sync_metadata()
	var res := MapData.validate_map(map_data)
	var prefix := "VALID" if bool(res["ok"]) else "INVALID"
	_set_status("%s: %s (Land: %d, Water: %d)" % [prefix, String(res["reason"]), int(res["land_tiles"]), int(res["water_tiles"])])

func _test_play_map() -> void:
	_sync_metadata()
	MapSerializer.save_to_file(map_data)
	GameManager.map_type = 3  # Custom map
	GameManager.start_single_player(GameManager.ai_difficulty, map_data, GameManager.player_faction, GameManager.ai_faction)
	SceneManager.goto_scene("res://scenes/game.tscn")

func _draw() -> void:
	# Draw hex cursor outline at hover_hex so the user can see exact hex alignment
	if hover_hex.x >= 0 and hover_hex.y >= 0:
		var center := hex_grid.hex_to_world(hover_hex)
		var pts := PackedVector2Array()
		var rad := hex_grid.size * float(brush_radius)
		for i in range(7):
			var ang := deg_to_rad(60.0 * float(i) - 30.0)
			pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
		draw_polyline(pts, Color(1.0, 0.95, 0.3, 0.9), 2.0)
