# scripts/game/map_editor.gd
extends Node2D

var map_data: MapData
var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_sprite: Sprite2D
var camera: Camera2D
var selected_terrain: int = MapData.Terrain.PLAINS
var brush_radius: int = 1
var painting: bool = false
var hover_tile: Vector2i = Vector2i(-1, -1)

enum Tool { TERRAIN, FLOOD_FILL, HQ, DEPOSIT, ERASE }
var selected_tool: int = Tool.TERRAIN
var selected_team: int = 0
var selected_resource: int = 0

var mirror_x: bool = false
var mirror_y: bool = false
var show_grid: bool = false
var dirty: bool = false
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var _stroke_recorded: bool = false
var _pending_confirm_action: String = ""
var _pending_save_path: String = ""

const MAX_UNDO_STEPS: int = 30
const MIN_ZOOM: float = 0.45
const MAX_ZOOM: float = 2.0
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

var workspace_split: HSplitContainer
var editor_title_label: Label
var map_name_edit: LineEdit
var author_edit: LineEdit
var map_path_edit: LineEdit
var saved_map_picker: OptionButton
var recent_maps_picker: OptionButton
var share_code_edit: LineEdit
var status_label: Label
var brush_btn: Button
var brush_slider: HSlider
var zoom_label: Label
var stats_label: Label
var validation_panel: PanelContainer
var validation_label: Label
var undo_btn: Button
var redo_btn: Button
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var _file_dialog_mode: String = "save"

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
	_refresh_inspector()
	_refresh_undo_buttons()

func _exit_tree() -> void:
	undo_stack.clear()
	redo_stack.clear()

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "EditorUI"
	add_child(ui)

	var root := VBoxContainer.new()
	root.name = "EditorRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# --- Top Menu & Action Bar ------------------------------------------------
	var top_panel := PanelContainer.new()
	top_panel.name = "TopBar"
	root.add_child(top_panel)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_bar)

	editor_title_label = Label.new()
	editor_title_label.name = "EditorTitleLabel"
	editor_title_label.text = "Map Editor — %s" % map_data.name
	top_bar.add_child(editor_title_label)

	_add_btn(top_bar, "New", _request_new_map)
	_add_btn(top_bar, "Save", _save_map)
	_add_btn(top_bar, "Save As…", _open_save_dialog)
	_add_btn(top_bar, "Browse…", _open_load_dialog)
	_add_btn(top_bar, "Load", _load_map)
	_add_btn(top_bar, "Quick Map", _load_default_map)

	undo_btn = _add_btn(top_bar, "Undo [Ctrl+Z]", undo)
	undo_btn.name = "UndoButton"
	redo_btn = _add_btn(top_bar, "Redo [Ctrl+Y]", redo)
	redo_btn.name = "RedoButton"

	_add_btn(top_bar, "Validate", _validate_current_map)
	_add_btn(top_bar, "Play vs AI", _test_play_map)
	_add_btn(top_bar, "Main Menu", func(): SceneManager.goto_scene("res://scenes/main_menu.tscn"))

	# --- Three-Pane HSplitContainer Workspace ---------------------------------
	workspace_split = HSplitContainer.new()
	workspace_split.name = "WorkspaceSplit"
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(workspace_split)

	# Left Pane: Tool Rail
	var left_panel := PanelContainer.new()
	left_panel.name = "ToolRail"
	left_panel.custom_minimum_size = Vector2(226, 0)
	workspace_split.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(210, 0)
	left_box.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_box)

	_add_heading(left_box, "Tools")
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	left_box.add_child(tool_grid)
	_add_btn(tool_grid, "Terrain Brush", func(): _select_tool(Tool.TERRAIN, 0, 0))
	_add_btn(tool_grid, "Flood Fill", func(): _select_tool(Tool.FLOOD_FILL, 0, 0))
	_add_btn(tool_grid, "Erase Marker", func(): _select_tool(Tool.ERASE, 0, 0))
	_add_btn(tool_grid, "Fill All", _fill_entire_map)

	_add_heading(left_box, "Terrain Palette")
	var terrain_grid := GridContainer.new()
	terrain_grid.columns = 2
	left_box.add_child(terrain_grid)
	var terrains := [
		["Plains", MapData.Terrain.PLAINS],
		["Forest", MapData.Terrain.FOREST],
		["Desert", MapData.Terrain.DESERT],
		["Water (Sea)", MapData.Terrain.SEA],
		["River", MapData.Terrain.RIVER],
		["Mountain", MapData.Terrain.MOUNTAIN],
		["Hills", MapData.Terrain.HILLS],
		["Swamp", MapData.Terrain.SWAMP],
		["Urban", MapData.Terrain.URBAN],
		["Road", MapData.Terrain.ROAD],
		["Bridge", MapData.Terrain.BRIDGE],
		["Wasteland", MapData.Terrain.WASTELAND],
	]
	for t in terrains:
		var tid: int = int(t[1])
		_add_btn(terrain_grid, String(t[0]), func():
			selected_terrain = tid
			if selected_tool != Tool.FLOOD_FILL:
				selected_tool = Tool.TERRAIN
			_set_status("Selected terrain: %s" % MapData.terrain_name(tid))
		)

	_add_heading(left_box, "Brush & Symmetry")
	brush_btn = _add_btn(left_box, "Tile Brush: 1", _cycle_brush_size)
	brush_slider = HSlider.new()
	brush_slider.name = "BrushSizeSlider"
	brush_slider.min_value = 1.0
	brush_slider.max_value = 4.0
	brush_slider.step = 1.0
	brush_slider.value = float(brush_radius)
	brush_slider.value_changed.connect(func(v: float):
		brush_radius = clampi(int(round(v)), 1, 4)
		if is_instance_valid(brush_btn):
			brush_btn.text = "Tile Brush: %d" % brush_radius
	)
	left_box.add_child(brush_slider)

	var mirror_x_btn := CheckButton.new()
	mirror_x_btn.name = "MirrorXToggle"
	mirror_x_btn.text = "Mirror-X Symmetry"
	mirror_x_btn.toggled.connect(func(on: bool):
		mirror_x = on
		_set_status("Mirror-X symmetry %s." % ("enabled" if on else "disabled"))
	)
	left_box.add_child(mirror_x_btn)

	var mirror_y_btn := CheckButton.new()
	mirror_y_btn.name = "MirrorYToggle"
	mirror_y_btn.text = "Mirror-Y Symmetry"
	mirror_y_btn.toggled.connect(func(on: bool):
		mirror_y = on
		_set_status("Mirror-Y symmetry %s." % ("enabled" if on else "disabled"))
	)
	left_box.add_child(mirror_y_btn)

	var grid_btn := CheckButton.new()
	grid_btn.name = "GridOverlayToggle"
	grid_btn.text = "Tile Grid Overlay"
	grid_btn.toggled.connect(func(on: bool):
		show_grid = on
		queue_redraw()
	)
	left_box.add_child(grid_btn)

	_add_heading(left_box, "Zoom Controls")
	var zoom_row := HBoxContainer.new()
	left_box.add_child(zoom_row)
	_add_btn(zoom_row, "-", func(): _adjust_zoom(0.85))
	zoom_label = Label.new()
	zoom_label.name = "ZoomLabel"
	zoom_label.text = "100%"
	zoom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(zoom_label)
	_add_btn(zoom_row, "+", func(): _adjust_zoom(1.18))
	_add_btn(zoom_row, "1:1", func(): _set_zoom(1.0))

	_add_heading(left_box, "HQ Spawns & Deposits")
	var hq_grid := GridContainer.new()
	hq_grid.columns = 2
	left_box.add_child(hq_grid)
	for team in range(MapData.MAX_TEAMS):
		var t_idx: int = team
		_add_btn(hq_grid, "HQ Team %d" % team, func(): _select_tool(Tool.HQ, t_idx, 0))
	var dep_grid := GridContainer.new()
	dep_grid.columns = 2
	left_box.add_child(dep_grid)
	for resource in range(RESOURCE_NAMES.size()):
		var r_idx: int = resource
		_add_btn(dep_grid, RESOURCE_NAMES[resource], func(): _select_tool(Tool.DEPOSIT, 0, r_idx))

	# Center + Right split so the center canvas stays click-through and right inspector docks cleanly
	var right_split := HSplitContainer.new()
	right_split.name = "CanvasInspectorSplit"
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace_split.add_child(right_split)

	var canvas_spacer := Control.new()
	canvas_spacer.name = "CanvasViewport"
	canvas_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_split.add_child(canvas_spacer)

	# Right Pane: Inspector (Metadata, Stats, Live Validation, Files, Recent Maps)
	var right_panel := PanelContainer.new()
	right_panel.name = "InspectorPane"
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_split.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_scroll)

	var right_box := VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(262, 0)
	right_box.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right_box)

	_add_heading(right_box, "Metadata")
	map_name_edit = LineEdit.new()
	map_name_edit.name = "MapNameEdit"
	map_name_edit.placeholder_text = "Map Name"
	map_name_edit.text = map_data.name
	map_name_edit.text_changed.connect(func(_v: String): _mark_dirty())
	right_box.add_child(map_name_edit)

	author_edit = LineEdit.new()
	author_edit.name = "AuthorEdit"
	author_edit.placeholder_text = "Author"
	author_edit.text = map_data.author
	author_edit.text_changed.connect(func(_v: String): _mark_dirty())
	right_box.add_child(author_edit)

	_add_heading(right_box, "Map File & Recent Maps")
	map_path_edit = LineEdit.new()
	map_path_edit.name = "MapPathEdit"
	map_path_edit.placeholder_text = "user://maps/my_map.bwm"
	map_path_edit.text = "%s/%s.bwm" % [MapSerializer.MAPS_DIR, MapSerializer.sanitize_filename(map_data.name)]
	right_box.add_child(map_path_edit)

	saved_map_picker = OptionButton.new()
	saved_map_picker.name = "SavedMapPicker"
	saved_map_picker.item_selected.connect(_on_saved_map_selected)
	right_box.add_child(saved_map_picker)
	_refresh_saved_map_picker()

	recent_maps_picker = OptionButton.new()
	recent_maps_picker.name = "RecentMapsPicker"
	recent_maps_picker.item_selected.connect(_on_recent_map_selected)
	right_box.add_child(recent_maps_picker)
	_refresh_recent_maps_picker()

	_add_heading(right_box, "Share Code (BWM1)")
	share_code_edit = LineEdit.new()
	share_code_edit.name = "ShareCodeEdit"
	share_code_edit.placeholder_text = "Paste or Copy Share Code (BWM1:...)"
	right_box.add_child(share_code_edit)
	var share_row := HBoxContainer.new()
	right_box.add_child(share_row)
	_add_btn(share_row, "Copy Code", _export_share_code)
	_add_btn(share_row, "Import Code", _import_share_code)

	_add_heading(right_box, "Map Stats")
	stats_label = Label.new()
	stats_label.name = "MapStatsLabel"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(stats_label)

	_add_heading(right_box, "Live Validation")
	validation_panel = PanelContainer.new()
	validation_panel.name = "ValidationPanel"
	right_box.add_child(validation_panel)
	validation_label = Label.new()
	validation_label.name = "ValidationChecklistLabel"
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_panel.add_child(validation_label)

	# --- Bottom Status Bar ----------------------------------------------------
	var status_panel := PanelContainer.new()
	status_panel.name = "StatusBar"
	root.add_child(status_panel)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Map Editor — LMB Paint/Place | Wheel Zoom | WASD/Arrows Pan | Ctrl+Z/Y Undo/Redo"
	status_panel.add_child(status_label)

	# --- Native FileDialog & ConfirmationDialog -------------------------------
	file_dialog = FileDialog.new()
	file_dialog.name = "MapFileDialog"
	file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.filters = PackedStringArray(["*.bwm ; BroWarz Map"])
	file_dialog.current_dir = MapSerializer.MAPS_DIR
	file_dialog.file_selected.connect(_on_file_dialog_selected)
	ui.add_child(file_dialog)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.name = "EditorConfirmDialog"
	confirm_dialog.confirmed.connect(_on_confirm_accepted)
	ui.add_child(confirm_dialog)

func _add_heading(parent: Node, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = Color(0.76, 0.88, 1.0, 1.0)
	parent.add_child(lbl)
	return lbl

func _add_btn(parent: Node, label_text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label_text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _set_status(msg: String, severity: int = STATUS_INFO) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg
		var tint: Color = STATUS_COLORS[clampi(severity, 0, STATUS_COLORS.size() - 1)]
		status_label.modulate = tint

func _mark_dirty() -> void:
	dirty = true
	_refresh_title()

func _clear_dirty() -> void:
	dirty = false
	_refresh_title()

func _refresh_title() -> void:
	if is_instance_valid(editor_title_label):
		var mname := map_name_edit.text.strip_edges() if is_instance_valid(map_name_edit) and not map_name_edit.text.strip_edges().is_empty() else map_data.name
		editor_title_label.text = "Map Editor — %s%s" % [mname, " *" if dirty else ""]

func _capture_snapshot() -> Dictionary:
	return {
		"tiles": map_data.tiles.duplicate(),
		"hq_spawns": map_data.hq_spawns.duplicate(true),
		"deposits": map_data.deposits.duplicate(true),
	}

func _restore_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	map_data.tiles = (snap["tiles"] as PackedByteArray).duplicate()
	map_data.hq_spawns = (snap["hq_spawns"] as Array).duplicate(true)
	map_data.deposits = (snap["deposits"] as Array).duplicate(true)
	_refresh_image()
	_refresh_inspector()

func push_undo_snapshot() -> void:
	undo_stack.append(_capture_snapshot())
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	redo_stack.clear()
	_refresh_undo_buttons()

func undo() -> bool:
	if undo_stack.is_empty():
		_set_status("Nothing to undo.", STATUS_WARN)
		return false
	redo_stack.append(_capture_snapshot())
	if redo_stack.size() > MAX_UNDO_STEPS:
		redo_stack.pop_front()
	var prev: Dictionary = undo_stack.pop_back()
	_restore_snapshot(prev)
	_mark_dirty()
	_refresh_undo_buttons()
	_set_status("Undid last map edit (%d undo left)." % undo_stack.size(), STATUS_INFO)
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		_set_status("Nothing to redo.", STATUS_WARN)
		return false
	undo_stack.append(_capture_snapshot())
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	var nxt: Dictionary = redo_stack.pop_back()
	_restore_snapshot(nxt)
	_mark_dirty()
	_refresh_undo_buttons()
	_set_status("Redid map edit (%d redo left)." % redo_stack.size(), STATUS_INFO)
	return true

func _refresh_undo_buttons() -> void:
	if is_instance_valid(undo_btn):
		undo_btn.disabled = undo_stack.is_empty()
	if is_instance_valid(redo_btn):
		redo_btn.disabled = redo_stack.is_empty()

func _refresh_inspector() -> void:
	_refresh_title()
	var res := MapData.validate_map(map_data)
	var valid := bool(res["ok"])
	if is_instance_valid(stats_label):
		stats_label.text = "Size: %dx%d | Land: %d | Water: %d\nSpawns: %d | Deposits: %d" % [
			map_data.width, map_data.height, int(res["land_tiles"]), int(res["water_tiles"]),
			int(res["spawns"]), int(res["deposits"]),
		]
	if is_instance_valid(validation_label):
		var dim_ok := map_data.width >= 16 and map_data.height >= 16 and map_data.tiles.size() == map_data.width * map_data.height
		var land_ok := int(res["land_tiles"]) >= 64
		var spawns_ok := int(res["spawns"]) >= 2
		var path_ok := bool(res["connected"])
		var bal_ok := bool(res["balanced"])
		var lines := PackedStringArray([
			"[%s] Dimensions %dx%d" % ["PASS" if dim_ok else "FAIL", map_data.width, map_data.height],
			"[%s] Playable Land >= 64 (%d)" % ["PASS" if land_ok else "FAIL", int(res["land_tiles"])],
			"[%s] HQ Spawns >= 2 (%d)" % ["PASS" if spawns_ok else "FAIL", int(res["spawns"])],
			"[%s] Spawn Connectivity" % ("PASS" if path_ok else "FAIL"),
			"[%s] Resource Balance" % ("PASS" if bal_ok else "FAIL"),
			"Summary: %s" % String(res["reason"]),
		])
		validation_label.text = "\n".join(lines)
		validation_label.modulate = STATUS_COLORS[STATUS_OK] if valid else STATUS_COLORS[STATUS_WARN]

func _cycle_brush_size() -> void:
	brush_radius = 1 if brush_radius >= 4 else (brush_radius + 1)
	if is_instance_valid(brush_btn):
		brush_btn.text = "Tile Brush: %d" % brush_radius
	if is_instance_valid(brush_slider):
		brush_slider.set_value_no_signal(float(brush_radius))

func _set_zoom(z: float) -> void:
	if camera == null:
		return
	var clamped := clampf(z, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(clamped, clamped)
	if is_instance_valid(zoom_label):
		zoom_label.text = "%d%%" % int(round(clamped * 100.0))
	queue_redraw()

func _adjust_zoom(factor: float) -> void:
	if camera == null:
		return
	_set_zoom(camera.zoom.x * factor)

func _select_tool(tool: int, team: int, resource: int) -> void:
	selected_tool = tool
	selected_team = team
	selected_resource = resource
	match tool:
		Tool.TERRAIN:
			_set_status("Terrain brush selected (%s)." % MapData.terrain_name(selected_terrain))
		Tool.FLOOD_FILL:
			_set_status("Flood fill selected (%s). Click any region to fill." % MapData.terrain_name(selected_terrain))
		Tool.HQ:
			_set_status("Click a tile to place Team %d's HQ spawn." % team)
		Tool.DEPOSIT:
			_set_status("Click a tile to place a %s deposit." % RESOURCE_NAMES[resource])
		Tool.ERASE:
			_set_status("Click a tile to erase an HQ spawn or deposit marker.")

func _symmetric_coords(tx: int, ty: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = [Vector2i(tx, ty)]
	var mx := map_data.width - 1 - tx
	var my := map_data.height - 1 - ty
	if mirror_x:
		var p := Vector2i(mx, ty)
		if not pts.has(p):
			pts.append(p)
	if mirror_y:
		var p2 := Vector2i(tx, my)
		if not pts.has(p2):
			pts.append(p2)
	if mirror_x and mirror_y:
		var p3 := Vector2i(mx, my)
		if not pts.has(p3):
			pts.append(p3)
	return pts

func flood_fill(start_x: int, start_y: int, new_terrain: int) -> int:
	if map_data == null or not map_data.in_bounds(start_x, start_y):
		return 0
	var seeds := _symmetric_coords(start_x, start_y)
	var total_filled := 0
	for seed_pt in seeds:
		var target_terrain := map_data.get_terrain(seed_pt.x, seed_pt.y)
		if target_terrain == new_terrain:
			continue
		var queue: Array[Vector2i] = [seed_pt]
		var visited: Dictionary = {seed_pt: true}
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			if map_data.set_terrain(cur.x, cur.y, new_terrain):
				total_filled += 1
			for nb in [
				Vector2i(cur.x + 1, cur.y), Vector2i(cur.x - 1, cur.y),
				Vector2i(cur.x, cur.y + 1), Vector2i(cur.x, cur.y - 1),
			]:
				if visited.has(nb) or not map_data.in_bounds(nb.x, nb.y):
					continue
				if map_data.get_terrain(nb.x, nb.y) == target_terrain:
					visited[nb] = true
					queue.append(nb)
	if total_filled > 0:
		_refresh_image()
		_mark_dirty()
		_refresh_inspector()
	return total_filled

func _fill_entire_map() -> void:
	push_undo_snapshot()
	for i in range(map_data.tiles.size()):
		map_data.tiles[i] = selected_terrain
	_refresh_image()
	_mark_dirty()
	_refresh_inspector()
	_set_status("Filled entire map with %s." % MapData.terrain_name(selected_terrain))

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera == null:
		return screen_pos
	var offset := screen_pos - get_viewport_rect().size * 0.5
	return camera.position + Vector2(offset.x / maxf(0.01, camera.zoom.x), offset.y / maxf(0.01, camera.zoom.y))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_key_pressed(KEY_CTRL):
			if event.keycode == KEY_Z:
				if Input.is_key_pressed(KEY_SHIFT):
					redo()
				else:
					undo()
				return
			elif event.keycode == KEY_Y:
				redo()
				return
			elif event.keycode == KEY_S:
				_save_map()
				return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(1.12)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.89)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = event.pressed
			if painting:
				_stroke_recorded = false
				_paint_at_screen(event.position)
			else:
				_stroke_recorded = false
	elif event is InputEventMouseMotion:
		var world_pos := _screen_to_world(event.position)
		hover_tile = Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))
		if painting and selected_tool == Tool.TERRAIN:
			_paint_at_screen(event.position)
		queue_redraw()

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(SettingsManager.hotkey("camera_up")) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_down")) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_left")) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_right")) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector2.ZERO and camera != null:
		camera.position += pan * float(SettingsManager.get_setting("camera_speed", 420.0)) * delta / maxf(0.25, camera.zoom.x)
		if show_grid:
			queue_redraw()

func _paint_at_screen(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var center_tx := int(world_pos.x / TILE_SIZE)
	var center_ty := int(world_pos.y / TILE_SIZE)
	if not map_data.in_bounds(center_tx, center_ty):
		return
	if selected_tool == Tool.FLOOD_FILL:
		push_undo_snapshot()
		var filled := flood_fill(center_tx, center_ty, selected_terrain)
		if filled > 0:
			_set_status("Flood-filled %d tile(s) with %s." % [filled, MapData.terrain_name(selected_terrain)], STATUS_OK)
		return
	if selected_tool != Tool.TERRAIN:
		push_undo_snapshot()
		_place_marker(center_tx, center_ty)
		return
	var changed := false
	var r := brush_radius - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + 1:
				for pt in _symmetric_coords(center_tx + dx, center_ty + dy):
					if not map_data.in_bounds(pt.x, pt.y):
						continue
					if map_data.get_terrain(pt.x, pt.y) == selected_terrain:
						continue
					if not _stroke_recorded:
						push_undo_snapshot()
						_stroke_recorded = true
					if map_data.set_terrain(pt.x, pt.y, selected_terrain):
						_update_tile_pixels(pt.x, pt.y)
						changed = true
	if changed:
		terrain_texture.update(terrain_image)
		_mark_dirty()
		_refresh_inspector()
		queue_redraw()

func _place_marker(tx: int, ty: int) -> void:
	if not map_data.in_bounds(tx, ty):
		return
	var pts := _symmetric_coords(tx, ty)
	var changed := false
	match selected_tool:
		Tool.HQ:
			if map_data.set_hq_spawn(selected_team, tx, ty):
				changed = true
				_set_status("Team %d HQ spawn placed at (%d, %d)." % [selected_team, tx, ty])
			if (mirror_x or mirror_y) and pts.size() > 1:
				var pair_team := (selected_team + 1) % MapData.MAX_TEAMS
				var mp := pts[pts.size() - 1]
				if map_data.set_hq_spawn(pair_team, mp.x, mp.y):
					changed = true
		Tool.DEPOSIT:
			for pt in pts:
				if map_data.add_deposit(selected_resource, pt.x, pt.y):
					changed = true
			if changed:
				_set_status("%s deposit placed at (%d, %d)." % [RESOURCE_NAMES[selected_resource], tx, ty])
		Tool.ERASE:
			var removed := false
			for pt in pts:
				for team in range(MapData.MAX_TEAMS):
					if map_data.get_hq_spawn(team) == pt:
						removed = map_data.remove_hq_spawn(team) or removed
				removed = map_data.clear_deposits_at(pt.x, pt.y) or removed
			if removed:
				changed = true
				_set_status("Marker erased at (%d, %d)." % [tx, ty])
	if changed:
		_mark_dirty()
		_refresh_inspector()
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

func _refresh_saved_map_picker() -> void:
	if not is_instance_valid(saved_map_picker):
		return
	var paths := MapSerializer.list_saved_maps()
	saved_map_picker.clear()
	saved_map_picker.add_item("Saved maps…")
	for path in paths:
		saved_map_picker.add_item(path.get_file())
	saved_map_picker.set_item_metadata(0, "")

func _refresh_recent_maps_picker() -> void:
	if not is_instance_valid(recent_maps_picker):
		return
	var recents: Array = SettingsManager.recent_maps()
	recent_maps_picker.clear()
	recent_maps_picker.add_item("Recent maps…")
	for item in recents:
		var path := String(item)
		recent_maps_picker.add_item(path.get_file())
		recent_maps_picker.set_item_metadata(recent_maps_picker.item_count - 1, path)

func _record_recent_map(path: String) -> void:
	SettingsManager.add_recent_map(path)
	SettingsManager.save_settings()
	_refresh_recent_maps_picker()

func _on_saved_map_selected(index: int) -> void:
	if index <= 0 or not is_instance_valid(saved_map_picker):
		return
	var paths := MapSerializer.list_saved_maps()
	if index > paths.size():
		return
	if is_instance_valid(map_path_edit):
		map_path_edit.text = paths[index - 1]
	_load_map()

func _on_recent_map_selected(index: int) -> void:
	if index <= 0 or not is_instance_valid(recent_maps_picker):
		return
	var path := String(recent_maps_picker.get_item_metadata(index))
	if path.is_empty():
		return
	if is_instance_valid(map_path_edit):
		map_path_edit.text = path
	_load_map()

func _request_new_map() -> void:
	if dirty and is_instance_valid(confirm_dialog):
		_pending_confirm_action = "new"
		confirm_dialog.title = "Discard Unsaved Changes?"
		confirm_dialog.dialog_text = "You have unsaved map edits. Create a fresh blank map and discard changes?"
		confirm_dialog.popup_centered(Vector2i(420, 150))
		return
	_create_new_map()

func _create_new_map() -> void:
	var fresh := MapData.new(128, 128)
	fresh.name = "Untitled Battlefield"
	fresh.author = "Commander"
	undo_stack.clear()
	redo_stack.clear()
	_apply_loaded_map(fresh, "Created new 128x128 blank map.")
	_refresh_undo_buttons()

func _open_save_dialog() -> void:
	if not is_instance_valid(file_dialog):
		_save_map()
		return
	DirAccess.make_dir_recursive_absolute(MapSerializer.MAPS_DIR)
	_file_dialog_mode = "save"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save BroWarz Map As…"
	file_dialog.current_path = _map_path()
	file_dialog.popup_centered(Vector2i(640, 440))

func _open_load_dialog() -> void:
	if not is_instance_valid(file_dialog):
		_load_map()
		return
	DirAccess.make_dir_recursive_absolute(MapSerializer.MAPS_DIR)
	_file_dialog_mode = "load"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Open BroWarz Map…"
	file_dialog.current_dir = MapSerializer.MAPS_DIR
	file_dialog.popup_centered(Vector2i(640, 440))

func _on_file_dialog_selected(path: String) -> void:
	if _file_dialog_mode == "save":
		var target := path if path.to_lower().ends_with(".bwm") else (path + ".bwm")
		if FileAccess.file_exists(target) and is_instance_valid(confirm_dialog):
			_pending_confirm_action = "overwrite"
			_pending_save_path = target
			confirm_dialog.title = "Overwrite Existing Map?"
			confirm_dialog.dialog_text = "Overwrite '%s'?" % target.get_file()
			confirm_dialog.popup_centered(Vector2i(400, 140))
			return
		if is_instance_valid(map_path_edit):
			map_path_edit.text = target
		_save_map()
	else:
		if is_instance_valid(map_path_edit):
			map_path_edit.text = path
		_load_map()

func _on_confirm_accepted() -> void:
	var action := _pending_confirm_action
	_pending_confirm_action = ""
	if action == "new":
		_create_new_map()
	elif action == "overwrite" and not _pending_save_path.is_empty():
		if is_instance_valid(map_path_edit):
			map_path_edit.text = _pending_save_path
		_pending_save_path = ""
		_save_map()

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
	if map_data.name != previous_name and is_instance_valid(map_path_edit):
		if map_path_edit.text.strip_edges().is_empty() or map_path_edit.text.strip_edges() == _default_map_path(previous_name):
			map_path_edit.text = _default_map_path()

func _apply_loaded_map(loaded: MapData, message: String, loaded_path: String = "") -> void:
	map_data = loaded
	GameManager.current_map = loaded
	if is_instance_valid(map_name_edit):
		map_name_edit.text = map_data.name
	if is_instance_valid(author_edit):
		author_edit.text = map_data.author
	if is_instance_valid(map_path_edit):
		map_path_edit.text = loaded_path if not loaded_path.is_empty() else _default_map_path()
	_clear_dirty()
	_refresh_image()
	_refresh_inspector()
	_set_status(message, STATUS_OK)

func _save_map() -> void:
	_sync_metadata()
	var path := _map_path()
	var result := MapSerializer.save_with_result(map_data, path)
	if not bool(result.get("ok", false)):
		_set_status("Save failed: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	var saved_path := str(result.get("path", path))
	if is_instance_valid(map_path_edit):
		map_path_edit.text = saved_path
	_clear_dirty()
	_refresh_saved_map_picker()
	_record_recent_map(saved_path)
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
	undo_stack.clear()
	redo_stack.clear()
	_apply_loaded_map(loaded, str(result.get("reason", "Map loaded.")), path)
	_refresh_undo_buttons()
	_record_recent_map(path)
	if not bool(result.get("playable", false)):
		_set_status("Loaded '%s', but it is not playable: %s" % [
			loaded.name, str(result.get("playability_reason", "unknown issue")),
		], STATUS_WARN)

func _load_default_map() -> void:
	var result := MapSerializer.load_with_result("user://custom_map.bwm")
	if not bool(result.get("ok", false)):
		_set_status("Quick map unavailable: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	undo_stack.clear()
	redo_stack.clear()
	_apply_loaded_map(result.get("map") as MapData, str(result.get("reason", "Quick map loaded.")), "user://custom_map.bwm")
	_refresh_undo_buttons()

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
	var imported := result.get("map") as MapData
	undo_stack.clear()
	redo_stack.clear()
	_apply_loaded_map(imported, "Imported shared map '%s'." % imported.name)
	_refresh_undo_buttons()
	var check: Dictionary = MapData.validate_map(imported)
	if not bool(check.get("ok", false)):
		_set_status("Imported '%s' is not playable: %s" % [
			imported.name, String(check.get("reason", "unknown issue")),
		], STATUS_WARN)

func _validate_current_map() -> void:
	_sync_metadata()
	_refresh_inspector()
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
	var check: Dictionary = MapData.validate_map(map_data)
	if not bool(check.get("ok", false)):
		_set_status("Cannot test play: %s" % String(check.get("reason", "unknown issue")), STATUS_ERROR)
		return
	var result := MapSerializer.save_with_result(map_data, "", false)
	if not bool(result.get("ok", false)):
		_set_status("Cannot test play: %s" % str(result.get("reason", "unknown error")), STATUS_ERROR)
		return
	GameManager.start_single_player(
		GameManager.ai_difficulty, map_data,
		clampi(GameManager.player_faction, 0, 3),
		clampi(GameManager.ai_faction, 0, 7), 3,
	)
	SceneManager.goto_scene("res://scenes/game.tscn")

func _draw() -> void:
	# Optional tile grid overlay culled to the visible camera viewport
	if show_grid and map_data != null and camera != null:
		var vr: Rect2 = UnitVisual.camera_world_rect(camera.position, get_viewport_rect().size, camera.zoom, 32.0)
		var x0 := clampi(int(floor(vr.position.x / TILE_SIZE)), 0, map_data.width)
		var x1 := clampi(int(ceil((vr.position.x + vr.size.x) / TILE_SIZE)), 0, map_data.width)
		var y0 := clampi(int(floor(vr.position.y / TILE_SIZE)), 0, map_data.height)
		var y1 := clampi(int(ceil((vr.position.y + vr.size.y) / TILE_SIZE)), 0, map_data.height)
		var gcol := Color(1.0, 1.0, 1.0, 0.16)
		for tx in range(x0, x1 + 1):
			var wx := float(tx) * TILE_SIZE
			draw_line(Vector2(wx, float(y0) * TILE_SIZE), Vector2(wx, float(y1) * TILE_SIZE), gcol, 1.0)
		for ty in range(y0, y1 + 1):
			var wy := float(ty) * TILE_SIZE
			draw_line(Vector2(float(x0) * TILE_SIZE, wy), Vector2(float(x1) * TILE_SIZE, wy), gcol, 1.0)

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

	# Draw the tile footprint (plus mirrored cursors when symmetry is active).
	if hover_tile.x >= 0 and hover_tile.y >= 0 and map_data.in_bounds(hover_tile.x, hover_tile.y):
		var half := TILE_SIZE * (0.5 if selected_tool != Tool.TERRAIN else maxf(0.5, float(brush_radius) - 0.5))
		for pt in _symmetric_coords(hover_tile.x, hover_tile.y):
			var center := Vector2((float(pt.x) + 0.5) * TILE_SIZE, (float(pt.y) + 0.5) * TILE_SIZE)
			var col := Color(1.0, 0.95, 0.3, 0.9) if pt == hover_tile else Color(0.35, 0.95, 1.0, 0.75)
			draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, 2.0)
