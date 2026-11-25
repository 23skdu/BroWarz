class_name Minimap
extends Control

## Corner tactical map. Left-click jumps the camera; right-click issues the
## same move/attack-move order as a right-click on the world map.

signal camera_requested(world_pos: Vector2)
signal move_requested(world_pos: Vector2)
signal ping_requested(world_pos: Vector2)

const SIZE_PX: float = 164.0
const REFRESH_INTERVAL: float = 0.5

var game: Node2D = null
var _map_image: Image = null
var _map_texture: ImageTexture = null
var _refresh_timer: float = 0.0

func _game() -> Node:
	if is_instance_valid(game):
		return game
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SIZE_PX - 16.0
	offset_top = -SIZE_PX - 16.0
	offset_right = -16.0
	offset_bottom = -16.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_terrain()

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh_terrain()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var world_pos := _world_from_local(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_ALT):
			ping_requested.emit(world_pos)
		else:
			camera_requested.emit(world_pos)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		move_requested.emit(world_pos)
		accept_event()

func _world_from_local(local_pos: Vector2) -> Vector2:
	var scene := _game()
	var map: MapData = scene.get("map_data") if scene != null else null
	if map == null:
		return Vector2.ZERO
	var tile_size := 16.0
	var nx := clampf(local_pos.x / maxf(1.0, size.x), 0.0, 1.0)
	var ny := clampf(local_pos.y / maxf(1.0, size.y), 0.0, 1.0)
	return Vector2(nx * float(map.width) * tile_size, ny * float(map.height) * tile_size)

func _refresh_terrain() -> void:
	var scene := _game()
	var map: MapData = scene.get("map_data") if scene != null else null
	if map == null:
		return
	if _map_image == null or _map_image.get_width() != map.width or _map_image.get_height() != map.height:
		_map_image = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
		_map_texture = ImageTexture.create_from_image(_map_image)
	var fog: FogOfWar = scene.get("fog") if scene != null else null
	for y in range(map.height):
		for x in range(map.width):
			var col := _terrain_color(map.get_terrain(x, y))
			if fog != null and GameManager.fog_enabled and not fog.is_explored(x, y):
				col = Color(0.03, 0.03, 0.04, 1.0)
			elif fog != null and GameManager.fog_enabled and not fog.is_visible(x, y):
				col = col.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.55)
			_map_image.set_pixel(x, y, col)
	_map_texture.update(_map_image)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.92), true)
	if _map_texture != null:
		draw_texture_rect(_map_texture, Rect2(Vector2.ZERO, size), false)
	var scene := _game()
	var map: MapData = scene.get("map_data") if scene != null else null
	if map == null:
		return
	var tile_size := 16.0
	var sx := size.x / (float(map.width) * tile_size)
	var sy := size.y / (float(map.height) * tile_size)
	var local_team := GameManager.local_team
	var palette := SettingsManager.colorblind_palette()
	var fog: FogOfWar = scene.get("fog") if scene != null else null
	var deposits: Array = scene.get("resource_deposits") if scene != null else []
	for rd in deposits:
		if not (rd is Dictionary):
			continue
		var dep_pos: Vector2 = rd.get("pos", Vector2.ZERO)
		var dep: ResourceDeposit = rd.get("deposit", null) as ResourceDeposit
		if dep == null or dep.is_depleted():
			continue
		var dep_col: Color = [
			Color(0.2, 0.65, 1.0), Color(0.85, 0.85, 0.9),
			Color(0.35, 0.95, 0.55), Color(1.0, 0.75, 0.25),
		][clampi(dep.type, 0, 3)]
		draw_circle(Vector2(dep_pos.x * sx, dep_pos.y * sy), 2.0, dep_col)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or ("is_exploding" in b and b.is_exploding):
			continue
		var bcol := Faction.colorblind_color_of(clampi(int(b.team), 0, 3), palette, 0)
		if GameManager.is_allied(local_team, int(b.team)):
			_draw_blip(b.global_position, sx, sy, bcol, 3.0)
		elif fog == null or not GameManager.fog_enabled or _is_visible(fog, b.global_position, tile_size):
			_draw_blip(b.global_position, sx, sy, bcol.lightened(0.15), 3.0)
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or ("is_exploding" in u and u.is_exploding):
			continue
		var ucol := Faction.colorblind_color_of(clampi(int(u.team), 0, 3), palette, 0)
		if GameManager.is_allied(local_team, int(u.team)):
			_draw_blip(u.global_position, sx, sy, ucol, 2.0)
		elif fog == null or not GameManager.fog_enabled or _is_visible(fog, u.global_position, tile_size):
			_draw_blip(u.global_position, sx, sy, ucol.lightened(0.15), 2.0)
	var cam: Camera2D = scene.get("camera") if scene != null else null
	if cam != null:
		var view := get_viewport_rect().size / maxf(cam.zoom.x, 0.01)
		var rect := Rect2(
			Vector2((cam.position.x - view.x * 0.5) * sx, (cam.position.y - view.y * 0.5) * sy),
			Vector2(view.x * sx, view.y * sy),
		)
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.75), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.65, 0.7, 0.85), false, 1.5)

func _draw_blip(world_pos: Vector2, sx: float, sy: float, col: Color, radius: float) -> void:
	var p := Vector2(world_pos.x * sx, world_pos.y * sy)
	draw_rect(Rect2(p - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), col, true)

func _is_visible(fog: FogOfWar, world_pos: Vector2, tile_size: float) -> bool:
	return fog.is_visible(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

func _terrain_color(t: int) -> Color:
	match t:
		MapData.Terrain.PLAINS: return Color(0.35, 0.55, 0.25)
		MapData.Terrain.FOREST: return Color(0.18, 0.40, 0.18)
		MapData.Terrain.SWAMP: return Color(0.30, 0.35, 0.20)
		MapData.Terrain.RIVER: return Color(0.20, 0.40, 0.75)
		MapData.Terrain.SEA: return Color(0.10, 0.25, 0.55)
		MapData.Terrain.MOUNTAIN: return Color(0.50, 0.50, 0.50)
		MapData.Terrain.URBAN: return Color(0.45, 0.40, 0.35)
		MapData.Terrain.ROAD: return Color(0.60, 0.55, 0.40)
		MapData.Terrain.BRIDGE: return Color(0.60, 0.50, 0.30)
		MapData.Terrain.WASTELAND: return Color(0.35, 0.20, 0.15)
		MapData.Terrain.DESERT: return Color(0.76, 0.65, 0.38)
		MapData.Terrain.HILLS: return Color(0.45, 0.50, 0.28)
	return Color(0.30, 0.30, 0.30)
