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

enum Tool { TERRAIN, HQ, DEPOSIT, ERASE }
var selected_tool: int = Tool.TERRAIN
var selected_team: int = 0
var selected_resource: int = 0

const TILE_SIZE: float = 16.0
const TERRAIN_PPT: int = 4
const RESOURCE_NAMES := ["Oil", "Iron", "Geothermal", "Food"]
const RESOURCE_COLORS := [
	Color(0.15, 0.65, 1.0), Color(0.85, 0.85, 0.9),
	Color(0.35, 0.95, 0.55), Color(1.0, 0.75, 0.25),
]
const STATUS_INFO := 0
const STATUS_OK := 1
const STATUS_WARN := 2
const STATUS_ERROR := 3
const STATUS_COLORS := [
	Color(0.85, 0.89, 0.95), Color(0.48, 0.94, 0.62),
	Color(1.0, 0.82, 0.38), Color(1.0, 0.45, 0.42),
]

var map_name_edit: LineEdit
var author_edit: LineEdit
var map_path_edit: LineEdit
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

	# Row 1b: HQ spawn points (Team 0..3) and resource deposit markers.
	var marker_bar := HBoxContainer.new()
	top_vbox.add_child(marker_bar)

	var terrain_tool_btn := Button.new()
	terrain_tool_btn.text = "Terrain Brush"
	terrain_tool_btn.pressed.connect(func(): _select_tool(Tool.TERRAIN, 0, 0))
	marker_bar.add_child(terrain_tool_btn)

	for team in range(MapData.MAX_TEAMS):
		var hq_btn := Button.new()
		hq_btn.text = "HQ Team %d" % team
		var t: int = team
		hq_btn.pressed.connect(func(): _select_tool(Tool.HQ, t, 0))
		marker_bar.add_child(hq_btn)

	for resource in range(RESOURCE_NAMES.size()):
		var dep_btn := Button.new()
		dep_btn.text = "%s Deposit" % RESOURCE_NAMES[resource]
		var r: int = resource
		dep_btn.pressed.connect(func(): _select_tool(Tool.DEPOSIT, 0, r))
		marker_bar.add_child(dep_btn)

	var erase_btn := Button.new()
	erase_btn.text = "Erase Marker"
	erase_btn.pressed.connect(func(): _select_tool(Tool.ERASE, 0, 0))
	marker_bar.add_child(erase_btn)

	# Row 1c: explicit file path so loading is never guessed from the map name.
	var file_bar := HBoxContainer.new()
	top_vbox.add_child(file_bar)
	var path_label := Label.new()
	path_label.text = "Map File:"
	file_bar.add_child(path_label)
	map_path_edit = LineEdit.new()
	map_path_edit.name = "MapPathEdit"
	map_path_edit.placeholder_text = "user://maps/my_map.bwm"
	map_path_edit.text = "%s/%s.bwm" % [MapSerializer.MAPS_DIR, MapSerializer.sanitize_filename(map_data.name)]
	map_path_edit.custom_minimum_size = Vector2(320, 0)
	file_bar.add_child(map_path_edit)

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
	save_btn.text = "Save As…"
	save_btn.pressed.connect(_save_map)
	action_bar.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_map)
	action_bar.add_child(load_btn)

	var load_default_btn := Button.new()
	load_default_btn.text = "Load Quick Map"
	load_default_btn.pressed.connect(_load_default_map)
	action_bar.add_child(load_default_btn)

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

func _set_status(msg: String, severity: int = STATUS_INFO) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg
		var tint: Color = STATUS_COLORS[clampi(severity, 0, STATUS_COLORS.size() - 1)]
		status_label.modulate = tint

func _cycle_brush_size() -> void:
	brush_radius = 1 if brush_radius >= 4 else (brush_radius + 1)
	if is_instance_valid(brush_btn):
		brush_btn.text = "Hex Brush: %d" % brush_radius

func _select_tool(tool: int, team: int, resource: int) -> void:
	selected_tool = tool
	selected_team = team
	selected_resource = resource
	match tool:
		Tool.TERRAIN:
			_set_status("Terrain brush selected (%s)." % MapData.terrain_name(selected_terrain))
		Tool.HQ:
			_set_status("Click a hex to place Team %d's HQ spawn." % team)
		Tool.DEPOSIT:
			_set_status("Click a hex to place a %s deposit." % RESOURCE_NAMES[resource])
		Tool.ERASE:
			_set_status("Click a hex to erase an HQ spawn or deposit marker.")

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
	if Input.is_key_pressed(SettingsManager.hotkey("camera_up")) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_down")) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_left")) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_right")) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector2.ZERO:
		camera.position += pan * float(SettingsManager.get_setting("camera_speed", 420.0)) * delta

func _paint_at_screen(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var center_tx := int(world_pos.x / TILE_SIZE)
	var center_ty := int(world_pos.y / TILE_SIZE)
	if selected_tool != Tool.TERRAIN:
		_place_marker(center_tx, center_ty)
		return
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

func _place_marker(tx: int, ty: int) -> void:
	if not map_data.in_bounds(tx, ty):
		return
	match selected_tool:
		Tool.HQ:
			if map_data.set_hq_spawn(selected_team, tx, ty):
				_set_status("Team %d HQ spawn placed at (%d, %d)." % [selected_team, tx, ty])
		Tool.DEPOSIT:
			if map_data.add_deposit(selected_resource, tx, ty):
				_set_status("%s deposit placed at (%d, %d)." % [RESOURCE_NAMES[selected_resource], tx, ty])
		Tool.ERASE:
			var removed := false
			for team in range(MapData.MAX_TEAMS):
				if map_data.get_hq_spawn(team) == Vector2i(tx, ty):
					removed = map_data.remove_hq_spawn(team) or removed
			removed = map_data.clear_deposits_at(tx, ty) or removed
			if removed:
				_set_status("Marker erased at (%d, %d)." % [tx, ty])
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

func _default_map_path(map_name: String = "") -> String:
	var title := map_name if not map_name.is_empty() else map_data.name
	return "%s/%s.bwm" % [MapSerializer.MAPS_DIR, MapSerializer.sanitize_filename(title)]

func _map_path() -> String:
	if is_instance_valid(map_path_edit):
		var typed := map_path_edit.text.strip_edges()
		if not typed.is_empty():
			return typed
	return _default_map_path()

func _sync_metadata() -> void:
	var previous_name := map_data.name
	if is_instance_valid(map_name_edit) and not map_name_edit.text.strip_edges().is_empty():
		map_data.name = map_name_edit.text.strip_edges()
	if is_instance_valid(author_edit) and not author_edit.text.strip_edges().is_empty():
		map_data.author = author_edit.text.strip_edges()
	# Follow a renamed map unless the user typed a deliberate custom path.
	if map_data.name != previous_name and is_instance_valid(map_path_edit):
		if map_path_edit.text.strip_edges().is_empty() or map_path_edit.text.strip_edges() == _default_map_path(previous_name):
			map_path_edit.text = _default_map_path()

func _apply_loaded_map(loaded: MapData, message: String) -> void:
	map_data = loaded
	GameManager.current_map = loaded
	if is_instance_valid(map_name_edit):
		map_name_edit.text = map_data.name
	if is_instance_valid(author_edit):
		author_edit.text = map_data.author
	if is_instance_valid(map_path_edit):
		map_path_edit.text = _default_map_path()
	_refresh_image()
	_set_status(message, STATUS_OK)

func _save_map() -> void:
	_sync_metadata()
	var path := _map_path()
	var result := MapSerializer.save_with_result(map_data, path)
	if not bool(result.get("ok", false)):
		_set_status("Save failed: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	if is_instance_valid(map_path_edit):
		map_path_edit.text = str(result.get("path", path))
	_set_status("%s (quick-load map updated)." % str(result.get("reason", "Map saved.")), STATUS_OK)

func _load_map() -> void:
	_sync_metadata()
	var path := _map_path()
	var result := MapSerializer.load_with_result(path)
	if not bool(result.get("ok", false)):
		_set_status("Load failed: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	var loaded: MapData = result.get("map", null) as MapData
	if loaded == null:
		_set_status("Load failed: map data could not be reconstructed.", STATUS_ERROR)
		return
	_apply_loaded_map(loaded, str(result.get("reason", "Map loaded.")))
	if not bool(result.get("playable", false)):
		_set_status("Loaded '%s', but it is not playable: %s" % [
			loaded.name, str(result.get("playability_reason", "unknown issue")),
		], STATUS_WARN)

func _load_default_map() -> void:
	var result := MapSerializer.load_with_result("user://custom_map.bwm")
	if not bool(result.get("ok", false)):
		_set_status("Quick map unavailable: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	_apply_loaded_map(result.get("map") as MapData, str(result.get("reason", "Quick map loaded.")))

func _export_share_code() -> void:
	_sync_metadata()
	var code := MapSerializer.to_share_code(map_data)
	if code.is_empty():
		_set_status("Could not generate a share code for this map.", STATUS_ERROR)
		return
	if is_instance_valid(share_code_edit):
		share_code_edit.text = code
	var copied := false
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(code)
		copied = true
	_set_status("Share code generated (%d chars)%s." % [
		code.length(), " and copied to clipboard" if copied else " (clipboard unavailable)",
	], STATUS_OK if copied else STATUS_WARN)

func _import_share_code() -> void:
	var code := ""
	if is_instance_valid(share_code_edit) and not share_code_edit.text.strip_edges().is_empty():
		code = share_code_edit.text.strip_edges()
	elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		code = DisplayServer.clipboard_get().strip_edges()
	var result := MapSerializer.from_share_code_detailed(code)
	if not bool(result.get("ok", false)):
		_set_status("Import failed: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	_apply_loaded_map(result.get("map") as MapData, "Imported shared map '%s'." % (result.get("map") as MapData).name)

func _validate_current_map() -> void:
	_sync_metadata()
	var res := MapData.validate_map(map_data)
	var valid := bool(res["ok"])
	var prefix := "VALID" if valid else "INVALID"
	_set_status("%s: %s (Land: %d, Water: %d, Spawns: %d, Deposits: %d, Path: %s, Balance: %s)" % [
		prefix, String(res["reason"]), int(res["land_tiles"]), int(res["water_tiles"]),
		int(res["spawns"]), int(res["deposits"]),
		"OK" if bool(res["connected"]) else "FAIL",
		"OK" if bool(res["balanced"]) else "FAIL",
	], STATUS_OK if valid else STATUS_ERROR)

func _test_play_map() -> void:
	_sync_metadata()
	# Test-play the in-memory map without overwriting the quick-load default
	# used by the main menu's "Custom Map" option.
	var result := MapSerializer.save_with_result(map_data, "", false)
	if not bool(result.get("ok", false)):
		_set_status("Cannot test play: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	GameManager.start_single_player(
		GameManager.ai_difficulty, map_data,
		GameManager.player_faction, GameManager.ai_faction, 3,
	)
	SceneManager.goto_scene("res://scenes/game.tscn")

func _draw() -> void:
	# HQ spawn markers: team-colored diamonds with a team label.
	for s in map_data.hq_spawns:
		var team := int(s.get("team", 0))
		var center := Vector2((int(s.get("x", 0)) + 0.5) * TILE_SIZE, (int(s.get("y", 0)) + 0.5) * TILE_SIZE)
		var color := Faction.colorblind_color_of(team % 4, SettingsManager.colorblind_palette())
		var pts := PackedVector2Array([
			center + Vector2(0, -11), center + Vector2(11, 0),
			center + Vector2(0, 11), center + Vector2(-11, 0),
		])
		draw_colored_polygon(pts, color)
		draw_polyline(pts, Color(1, 1, 1, 1), 1.5, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 4), str(team), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 1))

	# Resource deposit markers: colored discs with the resource initial.
	for d in map_data.deposits:
		var type := clampi(int(d.get("type", 0)), 0, RESOURCE_COLORS.size() - 1)
		var center := Vector2((int(d.get("x", 0)) + 0.5) * TILE_SIZE, (int(d.get("y", 0)) + 0.5) * TILE_SIZE)
		draw_circle(center, 7.0, RESOURCE_COLORS[type])
		draw_arc(center, 7.0, 0.0, TAU, 16, Color(0, 0, 0, 1), 1.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-3, 4), RESOURCE_NAMES[type].substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 1))

	# Draw hex cursor outline at hover_hex so the user can see exact hex alignment
	if hover_hex.x >= 0 and hover_hex.y >= 0:
		var center := hex_grid.hex_to_world(hover_hex)
		var pts := PackedVector2Array()
		var rad := hex_grid.size * float(brush_radius)
		for i in range(7):
			var ang := deg_to_rad(60.0 * float(i) - 30.0)
			pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
		draw_polyline(pts, Color(1.0, 0.95, 0.3, 0.9), 2.0)
