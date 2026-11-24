# scripts/game/map_editor.gd
extends Node2D

var map_data: MapData
var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_sprite: Sprite2D
var selected_terrain: int = MapData.Terrain.PLAINS
var painting: bool = false

const TILE_SIZE: float = 16.0

func _ready():
	map_data = MapData.new(128, 128)
	terrain_image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_sprite = Sprite2D.new()
	terrain_sprite.texture = terrain_texture
	terrain_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	terrain_sprite.centered = false
	add_child(terrain_sprite)
	_refresh_image()
	_build_ui()

func _build_ui():
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := HBoxContainer.new()
	panel.position = Vector2(10, 10)
	ui.add_child(panel)
	var terrains := [
		["Plains", MapData.Terrain.PLAINS],
		["Forest", MapData.Terrain.FOREST],
		["Swamp", MapData.Terrain.SWAMP],
		["River", MapData.Terrain.RIVER],
		["Sea", MapData.Terrain.SEA],
		["Mountain", MapData.Terrain.MOUNTAIN],
		["Urban", MapData.Terrain.URBAN],
		["Road", MapData.Terrain.ROAD],
	]
	for t in terrains:
		var b := Button.new()
		b.text = t[0]
		var tid: int = t[1]
		b.pressed.connect(func(): selected_terrain = tid)
		panel.add_child(b)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_map)
	panel.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_map)
	panel.add_child(load_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func(): SceneManager.goto_scene("res://scenes/main_menu.tscn"))
	panel.add_child(menu_btn)

func _input(event):
	if event is InputEventMouseButton:
		painting = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if painting:
			_paint(event.position)
	elif event is InputEventMouseMotion and painting:
		_paint(event.position)

func _paint(screen_pos: Vector2):
	var world_pos := screen_pos + (get_viewport().get_camera_2d().position if get_viewport().get_camera_2d() else Vector2.ZERO) - get_viewport_rect().size / 2.0
	# simpler: assume camera at origin for editor
	world_pos = screen_pos
	var tx := int(world_pos.x / TILE_SIZE)
	var ty := int(world_pos.y / TILE_SIZE)
	if map_data.set_terrain(tx, ty, selected_terrain):
		terrain_image.set_pixel(tx, ty, _terrain_color(selected_terrain))
		terrain_texture.update(terrain_image)

func _terrain_color(t: int) -> Color:
	match t:
		MapData.Terrain.PLAINS: return Color(0.35, 0.55, 0.25)
		MapData.Terrain.FOREST: return Color(0.18, 0.4, 0.18)
		MapData.Terrain.SWAMP: return Color(0.3, 0.35, 0.2)
		MapData.Terrain.RIVER: return Color(0.2, 0.4, 0.75)
		MapData.Terrain.SEA: return Color(0.1, 0.25, 0.55)
		MapData.Terrain.MOUNTAIN: return Color(0.5, 0.5, 0.5)
		MapData.Terrain.URBAN: return Color(0.45, 0.4, 0.35)
		MapData.Terrain.ROAD: return Color(0.6, 0.55, 0.4)
		MapData.Terrain.BRIDGE: return Color(0.6, 0.5, 0.3)
		MapData.Terrain.WASTELAND: return Color(0.35, 0.2, 0.15)
	return Color(0.3, 0.3, 0.3)

func _refresh_image():
	for y in range(map_data.height):
		for x in range(map_data.width):
			terrain_image.set_pixel(x, y, _terrain_color(map_data.get_terrain(x, y)))
	terrain_texture.update(terrain_image)

func _save_map():
	var d := MapSerializer.to_dict(map_data)
	var f := FileAccess.open("user://custom_map.bwm", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

func _load_map():
	if not FileAccess.file_exists("user://custom_map.bwm"):
		return
	var f := FileAccess.open("user://custom_map.bwm", FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and MapSerializer.validate(parsed):
		map_data = MapSerializer.from_dict(parsed)
		_refresh_image()
