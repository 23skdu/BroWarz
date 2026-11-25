# scripts/game/game.gd
extends Node2D

const WildlifeRef := preload("res://scripts/core/wildlife.gd")
const BuildingInspectorRef := preload("res://scripts/ui/building_inspector.gd")
const LockstepDialogRef := preload("res://scripts/ui/lockstep_dialog.gd")

var map_data: MapData
var selected_units: Array = []
var selected_building: Node2D = null
var control_groups: Dictionary = {}  # key 0..9 -> Array of Unit
var occupied_tiles: Dictionary = {}  # Vector2i -> bool for Placement.can_place_building
var pending_build_id: String = ""
var pending_target_action: String = ""
var resource_deposits: Array[Dictionary] = []
var team_unlocked_tech: Dictionary = {0: [], 1: []}
# instance id -> {team, rates: Dictionary, cap: int}: production bonuses that
# must be revoked if the granting structure is destroyed or overwritten.
var building_bonuses: Dictionary = {}
var tactical_pings: Array[Dictionary] = []
# Corvette-dropped sonar buoys and their per-ship cooldown timestamps.
var sonar_buoys: Array[Dictionary] = []
var sonar_cooldowns: Dictionary = {}
# Per-team knowledge state: each AI sees only what its own side can observe.
var team_fogs: Dictionary = {}
var camera: Camera2D
var match_over: bool = false
var elapsed_time: float = 0.0
var economy_timer: float = 0.0
var ai_timer: float = 0.0
var ai_tech_tier: int = 1
var player_tech_tier: int = 1
var ai_tactical_state: String = "rally"
# Last time (elapsed seconds) each AI unit was ordered to retreat, so damaged
# units rejoin the fight instead of being re-ordered home on every AI tick.
var ai_retreat_until: Dictionary = {}
# Next elapsed times at which the AI may build/train/issue fresh orders.
var ai_next_build_time: float = 0.0
var ai_next_train_time: float = 0.0
var ai_order_until: Dictionary = {}
# Per-team AI state for co-op and AI-vs-AI spectator matches. Team 1 keeps the
# legacy fields above synchronized for existing saves/tests.
var ai_states: Dictionary = {}
var ai_command_seq: int = 0
var replay_log := Replay.new()  # match command record (Step 15)
var match_duration: float = 0.0
var drag_selecting: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO
# Single spatial hash grid shared by scene combat, turrets and AOE queries.
var spatial_unit_positions: Array = []
var spatial_unit_nodes: Array = []
var spatial_unit_grid: Dictionary = {}
var minimap: Minimap = null
var building_inspector: BuildingInspectorRef = null
var lockstep_dialog: LockstepDialogRef = null
var bark_subtitle_label: Label = null
var bark_subtitle_timer: float = 0.0
var desync_count: int = 0
var last_state_checksum: int = 0
var _checksum_timer: float = 0.0
var pause_panel: Control = null
var victory_panel: Control = null
var research_dialog: ResearchDialog = null
var diplomacy_dialog: DiplomacyDialog = null
var laser_cooldown: float = 0.0
var nuke_cooldown: float = 0.0
var laser_cooldowns: Dictionary = {}  # team -> remaining seconds
var nuke_cooldowns: Dictionary = {}   # team -> remaining seconds
var active_vfx: Array = []      # Array of Dictionary {type, pos, radius, max_radius, color, timer, duration}
var active_tracers: Array = []  # Array of Dictionary {from, to, color, width, timer, duration}
var scorch_marks: Array = []    # Array of Dictionary {pos, radius, alpha}

var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_sprite: Sprite2D
var forest_multimesh: MultiMeshInstance2D = null
var forest_decorations: Array = []  # Array of Dictionary {pos, kind, radius, shade}
var wildlife_herd: Array[Dictionary] = []

const TILE_SIZE: float = 16.0
const TERRAIN_PPT: int = 4
var fog: FogOfWar
var fog_image: Image
var fog_texture: ImageTexture
var fog_sprite: Sprite2D

@onready var units_container = $Units
@onready var ui = $UI
@onready var status_label = $UI/StatusLabel

var hud_label: Label
var ai_status_label: Label
var help_label: Label

func _ready():
	if GameManager.registry.units.is_empty():
		GameManager.registry.populate_defaults()
	map_data = MapData.new(128, 128)
	_generate_map(GameManager.map_type)
	replay_log.seed = GameManager.match_seed
	replay_log.map_name = map_data.name
	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_sprite = Sprite2D.new()
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.texture = terrain_texture
	terrain_sprite.scale = Vector2(TILE_SIZE / float(TERRAIN_PPT), TILE_SIZE / float(TERRAIN_PPT))
	terrain_sprite.centered = false
	terrain_sprite.z_index = -5
	add_child(terrain_sprite)
	_rebuild_forest_decorations()
	_spawn_resource_deposits()
	wildlife_herd = WildlifeRef.spawn_ambient_herd(map_data, GameManager.match_seed, 10)
	GameManager.active_clouds = Cover.spawn_clouds(float(map_data.width) * TILE_SIZE, float(map_data.height) * TILE_SIZE, GameManager.match_seed, 8)
	fog = FogOfWar.new(map_data.width, map_data.height, map_data)
	fog_image = Image.create(map_data.width, map_data.height, false, Image.FORMAT_RGBA8)
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = fog_texture
	fog_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	fog_sprite.centered = false
	fog_sprite.z_index = 10
	add_child(fog_sprite)
	camera = $Camera2D
	_apply_camera_bounds()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	# Final position follows the resolved player HQ in _spawn_starting_bases().
	camera.position = _clamp_camera(Vector2(360, 300))
	_setup_hud()
	_init_economies()
	_spawn_starting_bases()
	_init_team_fogs()
	GameManager.start_match(map_data)
	NetworkManager.attach_game(self)
	if not NetworkManager.state_hash_received.is_connected(_on_remote_state_hash):
		NetworkManager.state_hash_received.connect(_on_remote_state_hash)
	AudioManager.reset_bark_cooldowns()
	if not AudioManager.bark_subtitle.is_connected(_on_bark_subtitle):
		AudioManager.bark_subtitle.connect(_on_bark_subtitle)
	AudioManager.set_music("battle")

func _exit_tree() -> void:
	# Autoloads outlive the match scene. Drop the command sink and per-match
	# state here so a later session cannot observe a freed node or stale map.
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.disconnect(_on_viewport_resized)
	if NetworkManager.state_hash_received.is_connected(_on_remote_state_hash):
		NetworkManager.state_hash_received.disconnect(_on_remote_state_hash)
	if AudioManager.bark_subtitle.is_connected(_on_bark_subtitle):
		AudioManager.bark_subtitle.disconnect(_on_bark_subtitle)
	if NetworkManager.game_node == self:
		NetworkManager.attach_game(null)
	GameManager.clear_match_state()
	UnitVisual.clear_shared_cache()
	BuildingVisual.clear_cache()
	team_fogs.clear()
	sonar_buoys.clear()
	sonar_cooldowns.clear()
	selected_units.clear()
	selected_building = null
	control_groups.clear()
	occupied_tiles.clear()
	resource_deposits.clear()
	team_unlocked_tech.clear()
	building_bonuses.clear()
	tactical_pings.clear()
	ai_retreat_until.clear()
	ai_order_until.clear()
	ai_states.clear()
	laser_cooldowns.clear()
	nuke_cooldowns.clear()
	spatial_unit_positions.clear()
	spatial_unit_nodes.clear()
	spatial_unit_grid.clear()
	active_vfx.clear()
	active_tracers.clear()
	scorch_marks.clear()
	forest_decorations.clear()
	wildlife_herd.clear()
	if minimap != null and is_instance_valid(minimap):
		minimap.game = null
		if minimap.camera_requested.is_connected(_on_minimap_camera):
			minimap.camera_requested.disconnect(_on_minimap_camera)
		if minimap.move_requested.is_connected(_on_minimap_order):
			minimap.move_requested.disconnect(_on_minimap_order)
		if minimap.ping_requested.is_connected(_on_minimap_ping):
			minimap.ping_requested.disconnect(_on_minimap_ping)
	if building_inspector != null and is_instance_valid(building_inspector):
		if building_inspector.train_requested.is_connected(_player_train_unit):
			building_inspector.train_requested.disconnect(_player_train_unit)
		if building_inspector.cancel_queue_requested.is_connected(_cancel_selected_building_queue):
			building_inspector.cancel_queue_requested.disconnect(_cancel_selected_building_queue)
		if building_inspector.reset_rally_requested.is_connected(_reset_selected_building_rally):
			building_inspector.reset_rally_requested.disconnect(_reset_selected_building_rally)
		if building_inspector.demolish_requested.is_connected(_demolish_selected_building):
			building_inspector.demolish_requested.disconnect(_demolish_selected_building)
		building_inspector = null
	lockstep_dialog = null

func _generate_map(map_type: int = 2) -> void:
	# Only an explicitly supplied custom map may override generated terrain.
	# No silent disk fallback: that let an old editor session leak into matches.
	if map_type == 3 and GameManager.current_map != null:
		var authored: MapData = GameManager.current_map.duplicate(true)
		var check: Dictionary = MapData.validate_map(authored)
		if bool(check.get("ok", false)):
			map_data = authored
			return
		if is_instance_valid(status_label):
			status_label.text = "Custom map invalid (%s); using Forest." % str(check.get("reason", "unknown error"))
	var gen := TerrainGenerator.generate_forest(128, 128, GameManager.match_seed)
	match map_type:
		0:
			gen = TerrainGenerator.generate_desert(128, 128, GameManager.match_seed)
		1:
			gen = TerrainGenerator.generate_islands(128, 128, GameManager.match_seed)
		_:
			gen = TerrainGenerator.generate_forest(128, 128, GameManager.match_seed)
	map_data = gen

func spawn_combat_tracer(from_pos: Vector2, to_pos: Vector2, dmg_type: int, _team: int) -> void:
	var col := Color(1.0, 0.92, 0.4, 0.95)
	var w := 2.2
	var dur := 0.14
	match dmg_type:
		Damage.DamageType.EXPLOSIVE:
			col = Color(1.0, 0.55, 0.15, 0.95)
			w = 3.2
			dur = 0.22
		Damage.DamageType.ENERGY:
			col = Color(0.25, 0.95, 1.0, 0.95)
			w = 2.8
			dur = 0.18
		Damage.DamageType.EMP:
			col = Color(0.55, 0.8, 1.0, 0.95)
			w = 2.6
			dur = 0.2
		Damage.DamageType.THERMAL:
			col = Color(1.0, 0.3, 0.1, 0.95)
			w = 3.6
			dur = 0.24
	active_tracers.append({
		"from": from_pos,
		"to": to_pos,
		"color": col,
		"width": w,
		"timer": dur,
		"duration": dur,
	})
	_affect_wildlife_from_fire(from_pos, to_pos, 14.0)
	queue_redraw()

func _affect_wildlife_from_fire(from_pos: Vector2, to_pos: Vector2, dmg: float) -> void:
	for cr in wildlife_herd:
		if not bool(cr.get("alive", true)):
			continue
		var cpos: Vector2 = cr["pos"]
		if cpos.distance_to(to_pos) <= 20.0:
			var died: bool = WildlifeRef.apply_damage(cr, dmg, from_pos)
			if died:
				spawn_explosion_vfx(cpos, 10.0)
		elif cpos.distance_to(to_pos) <= 130.0 or cpos.distance_to(from_pos) <= 130.0:
			cr["flee_timer"] = 3.0
			var away := (cpos - to_pos).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.RIGHT
			cr["vel"] = away * WildlifeRef.flee_speed(int(cr["kind"]))

func spawn_explosion_vfx(world_pos: Vector2, max_radius: float = 24.0) -> void:
	active_vfx.append({
		"type": "explosion",
		"pos": world_pos,
		"radius": max_radius,
		"color": Color(1.0, 0.5, 0.12, 0.85),
		"timer": 0.55,
		"duration": 0.55,
	})
	scorch_marks.append({
		"pos": world_pos,
		"radius": max_radius * 0.65,
		"alpha": 0.45,
	})
	if scorch_marks.size() > 64:
		scorch_marks.pop_front()
	queue_redraw()

func _setup_hud() -> void:
	hud_label = Label.new()
	hud_label.name = "HudLabel"
	hud_label.position = Vector2(20, 50)
	ui.add_child(hud_label)

	ai_status_label = Label.new()
	ai_status_label.name = "AiStatusLabel"
	ai_status_label.position = Vector2(20, 80)
	ui.add_child(ai_status_label)

	help_label = Label.new()
	help_label.name = "HelpLabel"
	help_label.position = Vector2(20, 110)
	help_label.text = (
		"[LMB/Drag] Select | [RMB] Move (hold A: Attack) | [1-7] Train | [Ctrl+0-9] Set group | "
		+ "[Ctrl+Shift+0-9] Recall group | [F/G/M] Fortify | [C] Capture | [Del] Demolish | "
		+ "[E/U] Embark/Disembark | [B/V/P] Build | [K] Sonar Buoy | [T/R] Tech | [L/N] Orbital/Nuke | [Esc] Pause"
	)
	ui.add_child(help_label)

	var btn_bar := HBoxContainer.new()
	btn_bar.name = "CommandBar"
	btn_bar.position = Vector2(20, 140)
	ui.add_child(btn_bar)

	_add_cmd_button(btn_bar, "Train Riflebot [1]", func(): _player_train_unit("riflebot"))
	_add_cmd_button(btn_bar, "Train Rocketbot [2]", func(): _player_train_unit("rocketbot"))
	_add_cmd_button(btn_bar, "Train Stealthbot [3]", func(): _player_train_unit("stealthbot"))
	_add_cmd_button(btn_bar, "Train Tank [4]", func(): _player_train_unit("mbt"))
	_add_cmd_button(btn_bar, "Train AA [5]", func(): _player_train_unit("aa_vehicle"))
	_add_cmd_button(btn_bar, "Train Fighter [6]", func(): _player_train_unit("fighter_drone"))
	_add_cmd_button(btn_bar, "Train Hovercraft [7]", func(): _player_train_unit("hovercraft"))
	_add_cmd_button(btn_bar, "Wall [F]", func(): _enter_build_mode("wall"))
	_add_cmd_button(btn_bar, "Barbed Wire [G]", func(): _enter_build_mode("barbed_wire"))
	_add_cmd_button(btn_bar, "Missile Tower [M]", func(): _enter_build_mode("missile_tower"))
	_add_cmd_button(btn_bar, "Embark [E]", func(): _player_embark_selected())
	_add_cmd_button(btn_bar, "Disembark [U]", func(): _player_disembark_selected())
	_add_cmd_button(btn_bar, "Sonar Buoy [K]", func(): _enter_target_mode("sonar_buoy"))
	_add_cmd_button(btn_bar, "Build Extractor [B]", func(): _enter_build_mode("extractor"))
	_add_cmd_button(btn_bar, "Build Turret [V]", func(): _enter_build_mode("turret"))
	_add_cmd_button(btn_bar, "Build Power [P]", func(): _enter_build_mode("power_plant"))
	_add_cmd_button(btn_bar, "Cancel Queue [X]", func(): _cancel_selected_building_queue())
	_add_cmd_button(btn_bar, "Tech Up [T]", func(): _player_upgrade_tech())
	_add_cmd_button(btn_bar, "Research [R]", func(): _open_research_dialog())
	_add_cmd_button(btn_bar, "Orbital Laser [L]", func(): _enter_target_mode("laser"))
	_add_cmd_button(btn_bar, "Nuclear Strike [N]", func(): _enter_target_mode("nuke"))
	_add_cmd_button(btn_bar, "Diplomacy", func(): _open_diplomacy_dialog())
	_add_cmd_button(btn_bar, "Save [F5]", func(): quicksave_match())
	_add_cmd_button(btn_bar, "Load [F9]", func(): quickload_match())
	_add_cmd_button(btn_bar, "Settings", func(): _open_settings())
	_add_cmd_button(btn_bar, "Pause [Esc]", func(): toggle_pause())

	_build_full_palette()
	_build_pause_panel()
	_build_victory_panel()

	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.game = self
	ui.add_child(minimap)
	# Modal panels are created before the minimap; keep the minimap below them
	# so pause/victory dimming still covers the whole screen.
	var pause_node := ui.get_node_or_null("PausePanel")
	if pause_node != null:
		ui.move_child(minimap, pause_node.get_index())
	minimap.camera_requested.connect(_on_minimap_camera)
	minimap.move_requested.connect(_on_minimap_order)
	minimap.ping_requested.connect(_on_minimap_ping)

	building_inspector = BuildingInspectorRef.new()
	ui.add_child(building_inspector)
	if pause_node != null:
		ui.move_child(building_inspector, pause_node.get_index())
	building_inspector.train_requested.connect(_player_train_unit)
	building_inspector.cancel_queue_requested.connect(_cancel_selected_building_queue)
	building_inspector.reset_rally_requested.connect(_reset_selected_building_rally)
	building_inspector.demolish_requested.connect(_demolish_selected_building)

	bark_subtitle_label = Label.new()
	bark_subtitle_label.name = "BarkSubtitleLabel"
	bark_subtitle_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bark_subtitle_label.offset_left = -320.0
	bark_subtitle_label.offset_top = -54.0
	bark_subtitle_label.offset_right = 320.0
	bark_subtitle_label.offset_bottom = -18.0
	bark_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bark_subtitle_label.visible = false
	ui.add_child(bark_subtitle_label)
	if pause_node != null:
		ui.move_child(bark_subtitle_label, pause_node.get_index())
	if GameManager.is_spectator:
		help_label.text = "SPECTATOR — VIEW ONLY | Camera: drag/wheel | [F12] Screenshot | [Esc] Pause"
		var bar := ui.get_node_or_null("CommandBar")
		if bar != null:
			bar.visible = false
		var palette := ui.get_node_or_null("FullPaletteScroll")
		if palette != null:
			palette.visible = false

func _build_full_palette() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "FullPaletteScroll"
	scroll.position = Vector2(20, 190)
	scroll.custom_minimum_size = Vector2(215, 340)
	ui.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.name = "FullPalette"
	scroll.add_child(vbox)
	var unit_ids: Array = GameManager.registry.units.keys()
	unit_ids.sort()
	for uid in unit_ids:
		var s: UnitStats = GameManager.registry.get_unit(str(uid))
		if s != null and s.ai_only:
			continue
		var label := s.display_name if s != null else str(uid)
		var b := _add_cmd_button(vbox, "Train %s" % label, func(): _player_train_unit(str(uid)))
		b.name = "Train_%s" % str(uid)
	var building_ids: Array = GameManager.registry.buildings.keys()
	building_ids.sort()
	for bid in building_ids:
		var bs: BuildingStats = GameManager.registry.get_building(str(bid))
		var label := bs.display_name if bs != null else str(bid)
		var b := _add_cmd_button(vbox, "Place %s" % label, func(): _enter_build_mode(str(bid)))
		b.name = "Build_%s" % str(bid)

func _build_pause_panel() -> void:
	pause_panel = Control.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	ui.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	pause_panel.add_child(dim)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -170.0
	vbox.offset_top = -190.0
	vbox.offset_right = 170.0
	vbox.offset_bottom = 190.0
	vbox.add_theme_constant_override("separation", 8)
	pause_panel.add_child(vbox)
	var title := Label.new()
	title.text = "SYSTEM MENU — PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_add_cmd_button(vbox, "Resume", func(): toggle_pause())
	_add_cmd_button(vbox, "Save Match [F5]", func(): quicksave_match())
	_add_cmd_button(vbox, "Load Match [F9]", func(): quickload_match())
	_add_cmd_button(vbox, "Diplomacy", func(): _open_diplomacy_dialog())
	_add_cmd_button(vbox, "Settings", func(): _open_settings())
	_add_cmd_button(vbox, "Lockstep Soak Check", func(): _open_lockstep_dialog())
	_add_cmd_button(vbox, "Save Replay", func(): save_replay())
	_add_cmd_button(vbox, "Watch Replay", func(): _open_replay_viewer())
	_add_cmd_button(vbox, "Main Menu", func():
		resume_game()
		SceneManager.goto_scene("res://scenes/main_menu.tscn")
	)

func _build_victory_panel() -> void:
	var panel := Control.new()
	victory_panel = panel
	panel.name = "MatchEndPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_top = -140.0
	panel.offset_right = 300.0
	panel.offset_bottom = 140.0
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	ui.add_child(panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	panel.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.name = "ResultLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var detail := Label.new()
	detail.name = "ScoreLabel"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(detail)
	_add_cmd_button(vbox, "Save Replay", func(): save_replay())
	_add_cmd_button(vbox, "Watch Replay", func(): _open_replay_viewer())
	_add_cmd_button(vbox, "Main Menu", func():
		resume_game()
		SceneManager.goto_scene("res://scenes/main_menu.tscn")
	)

func _add_cmd_button(parent: Node, label_text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label_text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _open_settings() -> void:
	var existing := ui.get_node_or_null("SettingsDialog")
	if existing != null and is_instance_valid(existing):
		(existing as AcceptDialog).popup_centered(Vector2i(620, 640))
		return
	var dialog := SettingsDialog.new()
	dialog.name = "SettingsDialog"
	ui.add_child(dialog)
	dialog.popup_centered(Vector2i(620, 640))

func _open_replay_viewer() -> void:
	var viewer := ui.get_node_or_null("ReplayViewer")
	if viewer == null:
		viewer = ReplayViewer.new()
		viewer.name = "ReplayViewer"
		ui.add_child(viewer)
	viewer.popup_centered(Vector2i(720, 560))

func _open_research_dialog() -> void:
	if research_dialog != null and is_instance_valid(research_dialog):
		research_dialog.queue_free()
	research_dialog = ResearchDialog.new()
	ui.add_child(research_dialog)
	research_dialog.populate(
		team_unlocked_tech.get(GameManager.local_team, []),
		ResourceManager.get_wallet(GameManager.local_team),
		_team_has_research_lab(GameManager.local_team),
	)
	research_dialog.research_selected.connect(_on_research_selected)
	research_dialog.popup_centered(Vector2i(620, 560))

func _open_diplomacy_dialog() -> void:
	if diplomacy_dialog != null and is_instance_valid(diplomacy_dialog):
		diplomacy_dialog.queue_free()
	diplomacy_dialog = DiplomacyDialog.new()
	ui.add_child(diplomacy_dialog)
	diplomacy_dialog.refresh()
	diplomacy_dialog.popup_centered(Vector2i(620, 520))

func _open_lockstep_dialog() -> void:
	if lockstep_dialog == null or not is_instance_valid(lockstep_dialog):
		lockstep_dialog = LockstepDialogRef.new()
		lockstep_dialog.name = "LockstepDialog"
		ui.add_child(lockstep_dialog)
	last_state_checksum = compute_match_checksum()
	lockstep_dialog.refresh_live_status(last_state_checksum, desync_count)
	lockstep_dialog.popup_centered(Vector2i(600, 340))

func _on_bark_subtitle(text: String) -> void:
	if is_instance_valid(bark_subtitle_label) and SettingsManager.subtitles_enabled():
		bark_subtitle_label.text = text
		bark_subtitle_label.visible = true
		bark_subtitle_timer = 3.2

## Deterministic snapshot checksum for live P2P desync detection and the
## in-game Lockstep Verification dialog.
func compute_match_checksum() -> int:
	var gs := GameState.new()
	gs.tick = int(elapsed_time * 20.0)
	for pid in _economy_team_ids():
		gs.resources[pid] = ResourceManager.get_wallet(pid).duplicate()
	var unit_records: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.stats != null:
			unit_records.append({
				"net_id": int(u.net_id), "id": u.stats.id, "team": int(u.team),
				"x": roundi(u.global_position.x), "y": roundi(u.global_position.y),
				"hp": int(u.hp),
			})
	unit_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["net_id"]) < int(b["net_id"]))
	gs.units = unit_records
	var bld_records: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.stats != null:
			bld_records.append({
				"id": b.stats.id, "team": int(b.team),
				"x": roundi(b.global_position.x), "y": roundi(b.global_position.y),
				"hp": int(b.hp),
			})
	bld_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["x"]) != int(b["x"]):
			return int(a["x"]) < int(b["x"])
		return int(a["y"]) < int(b["y"])
	)
	gs.buildings = bld_records
	return gs.checksum()

func _on_remote_state_hash(peer_id: int, remote_hash: int) -> void:
	var local_hash := compute_match_checksum()
	last_state_checksum = local_hash
	if remote_hash != local_hash:
		desync_count += 1
		if is_instance_valid(status_label):
			status_label.text = "Desync warning vs peer %d (local 0x%X != remote 0x%X)" % [
				peer_id, local_hash, remote_hash,
			]
	if is_instance_valid(lockstep_dialog):
		lockstep_dialog.refresh_live_status(local_hash, desync_count)

func _on_research_selected(node_id: String) -> void:
	if not submit_player_command({"type": "tech", "id": node_id}):
		return
	if is_instance_valid(research_dialog):
		research_dialog.call_deferred("populate",
			team_unlocked_tech.get(GameManager.local_team, []),
			ResourceManager.get_wallet(GameManager.local_team),
			_team_has_research_lab(GameManager.local_team),
		)

func _on_minimap_camera(world_pos: Vector2) -> void:
	if camera != null:
		camera.position = _clamp_camera(world_pos)

func _on_minimap_order(world_pos: Vector2) -> void:
	_issue_move_order(world_pos, Input.is_key_pressed(KEY_A))

func _on_minimap_ping(world_pos: Vector2) -> void:
	tactical_pings.append({"pos": world_pos, "timer": 4.0})
	queue_redraw()

func _map_world_size() -> Vector2:
	if map_data == null:
		return Vector2.ONE
	return Vector2(float(map_data.width) * TILE_SIZE, float(map_data.height) * TILE_SIZE)

## Zooming out past this level would expose empty space beyond the terrain.
func _min_cover_zoom() -> float:
	var view := get_viewport_rect().size
	var world := _map_world_size()
	if view.x <= 0.0 or view.y <= 0.0 or world.x <= 0.0 or world.y <= 0.0:
		return 0.45
	return maxf(0.45, maxf(view.x / world.x, view.y / world.y))

func _clamp_camera_zoom(zoom: Vector2) -> Vector2:
	var minimum := _min_cover_zoom()
	var maximum := maxf(2.0, minimum)
	return Vector2(clampf(zoom.x, minimum, maximum), clampf(zoom.y, minimum, maximum))

func _apply_camera_bounds() -> void:
	if camera == null:
		return
	camera.zoom = _clamp_camera_zoom(camera.zoom)
	var world := _map_world_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.x)
	camera.limit_bottom = int(world.y)
	camera.position = _clamp_camera(camera.position)

func _on_viewport_resized() -> void:
	_apply_camera_bounds()

func _clamp_camera(pos: Vector2) -> Vector2:
	if map_data == null or camera == null:
		return pos
	var world := _map_world_size()
	var half_view := get_viewport_rect().size * 0.5 / maxf(camera.zoom.x, 0.01)
	return Vector2(
		clampf(pos.x, half_view.x, world.x - half_view.x),
		clampf(pos.y, half_view.y, world.y - half_view.y)
	)

func toggle_pause() -> void:
	if pause_panel == null:
		return
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible
	pending_build_id = ""
	pending_target_action = ""

func resume_game() -> void:
	if pause_panel != null:
		pause_panel.visible = false
	get_tree().paused = false

func _team_building_total(team: int) -> int:
	var total := 0
	for count in _get_team_building_counts(team).values():
		total += int(count)
	return total

func _team_score(team: int) -> Dictionary:
	var wallet := ResourceManager.get_wallet(team)
	var eco_sum := 0
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		eco_sum += int(wallet.get(res, 0))
	var mil := Score.military_score(_get_team_units(team).size(), _team_building_total(team))
	var eco := Score.economic_score(eco_sum)
	return {"military": mil, "economic": eco, "total": Score.total(mil, eco)}

## Team seats are data-driven: co-op and four-seat matches must not leave
## seats 2/3 with an empty wallet or drop their economy on quicksave.
func _economy_team_ids() -> Array:
	var ids: Dictionary = {}
	for value in GameManager.teams:
		ids[int(value)] = true
	for value in ResourceManager.wallets.keys():
		ids[int(value)] = true
	var out: Array = ids.keys()
	out.sort()
	return out

func _init_economies() -> void:
	var start_res := {
		Economy.Res.OIL: 200,
		Economy.Res.IRON: 320,
		Economy.Res.GEOTHERMAL: 100,
		Economy.Res.FOOD: 150,
	}
	for pid in _economy_team_ids():
		ResourceManager.init_player(pid, start_res)
		var mult := 1.0
		if GameManager.is_ai_team(pid):
			mult = AI.income_multiplier(GameManager.difficulty_for_team(pid))
		_set_base_rates(pid, mult)
		ResourceManager.caps[pid] = 20

func _set_base_rates(pid: int, mult: float) -> void:
	# Slower income gives both sides time to scout and field a first wave.
	ResourceManager.set_rate(pid, Economy.Res.OIL, int(round(9.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.IRON, int(round(16.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.GEOTHERMAL, int(round(5.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.FOOD, int(round(8.0 * mult)))

const MIN_SPAWN_SEPARATION: int = 24  # tiles; prevents instant base-to-base contact

func _spawn_starting_bases() -> void:
	var spawns := _resolve_hq_tiles()
	var starters: Array = []
	# Every team, including multiplayer seats 2/3, begins with exactly one HQ.
	# Production, economy and defense structures must be built or captured.
	for team in GameManager.teams:
		var team_tile: Vector2i = spawns.get(team, Vector2i(4, 4))
		var facing := 1 if team % 2 == 0 else -1
		starters.append(_spawn_building_by_id("hq", _tile_world(team_tile), team))
		# A small escort lets new players scout and defend while they expand;
		# these are units, not additional starting buildings.
		_spawn_unit_by_id("riflebot", _tile_world(team_tile + Vector2i(4 * facing, 4 * facing)), team)
		_spawn_unit_by_id("riflebot", _tile_world(team_tile + Vector2i(6 * facing, 4 * facing)), team)
		_spawn_unit_by_id("rocketbot", _tile_world(team_tile + Vector2i(4 * facing, 6 * facing)), team)
		_spawn_unit_by_id("sapperbot", _tile_world(team_tile + Vector2i(2 * facing, 4 * facing)), team)
		# A starting recon platform gives both human and AI sides a way to
		# pierce fog immediately without granting any extra starting building.
		_spawn_unit_by_id("scout_drone", _tile_world(team_tile + Vector2i(2 * facing, 8 * facing)), team)

	# Starting buildings occupy their tiles so players cannot build on top of them.
	for b in starters:
		if is_instance_valid(b) and b.stats != null:
			var origin := Vector2i(int(b.global_position.x / TILE_SIZE), int(b.global_position.y / TILE_SIZE))
			Placement.occupy(occupied_tiles, b.stats.footprint, origin)

	# Open the camera on the player's actual spawn rather than a fixed corner.
	if camera != null:
		camera.position = _clamp_camera(_tile_world(spawns.get(0, Vector2i(4, 4))))

func _tile_world(tile: Vector2i) -> Vector2:
	var t := tile
	if map_data != null:
		t.x = clampi(t.x, 0, map_data.width - 1)
		t.y = clampi(t.y, 0, map_data.height - 1)
	return Vector2((float(t.x) + 0.5) * TILE_SIZE, (float(t.y) + 0.5) * TILE_SIZE)

func _resolve_hq_tiles() -> Dictionary:
	if map_data == null:
		return {0: Vector2i(4, 4), 1: Vector2i(64, 52)}
	var player_fallback := Vector2i(4, 4)
	var ai_fallback := Vector2i(maxi(5, map_data.width - 5), maxi(5, map_data.height - 5))
	var authored_player := map_data.get_hq_spawn(0)
	var authored_ai := map_data.get_hq_spawn(1)
	if authored_player.x >= 0 and authored_player.y >= 0:
		player_fallback = authored_player
	if authored_ai.x >= 0 and authored_ai.y >= 0:
		ai_fallback = authored_ai
	var player_tile := _nearest_vehicle_tile(player_fallback)
	var reachable := _reachable_vehicle_tiles(player_tile)
	var ai_tile := _choose_ai_tile(ai_fallback, player_tile, reachable)
	var result := {0: player_tile, 1: ai_tile}
	for team in GameManager.teams:
		if int(team) in [0, 1] or result.has(int(team)):
			continue
		var preferred := map_data.get_hq_spawn(int(team)) if map_data != null else Vector2i(-1, -1)
		if preferred.x < 0 or preferred.y < 0:
			preferred = Vector2i(
				map_data.width - 5 - int(team) * 4 if map_data != null else 16,
				5 + int(team) * 4
			)
		var team_tile := _nearest_vehicle_tile(preferred)
		var team_reachable := _reachable_vehicle_tiles(team_tile)
		if team_reachable.is_empty() and map_data != null:
			for y in range(map_data.height):
				for x in range(map_data.width):
					if MapData.is_passable(map_data.get_terrain(x, y), 1):
						team_reachable[Vector2i(x, y)] = true
		var best: Vector2i = team_tile
		var best_score := -1.0
		for tile in team_reachable.keys():
			var min_sep := 9999
			for used in result.values():
				min_sep = mini(min_sep, _tile_separation(tile, used))
			var score := float(min_sep) - float(_tile_separation(tile, preferred)) * 0.01
			if score > best_score:
				best_score = score
				best = tile
		result[int(team)] = best
	return result

func _choose_ai_tile(preferred: Vector2i, player_tile: Vector2i, reachable: Dictionary) -> Vector2i:
	# Honour authored spawns when they are already valid and well separated.
	if reachable.has(preferred) and _tile_separation(preferred, player_tile) >= MIN_SPAWN_SEPARATION:
		return preferred
	var pool: Array = []
	var far_enough := false
	for tile in reachable.keys():
		pool.append(tile)
		if _tile_separation(tile, player_tile) >= MIN_SPAWN_SEPARATION:
			far_enough = true
	# Disconnected or tiny passable regions: pick any passable tile far away.
	if not far_enough and map_data != null:
		pool.clear()
		for y in range(map_data.height):
			for x in range(map_data.width):
				if MapData.is_passable(map_data.get_terrain(x, y), 1):
					pool.append(Vector2i(x, y))
	var best: Vector2i = preferred
	var best_score := -1.0
	for tile in pool:
		var score := float(_tile_separation(tile, player_tile)) - float(_tile_separation(tile, preferred)) * 0.01
		if score > best_score:
			best_score = score
			best = tile
	return best

func _tile_separation(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _reachable_vehicle_tiles(origin: Vector2i) -> Dictionary:
	var seen := {}
	if map_data == null or not _is_vehicle_tile(origin):
		return seen
	var queue: Array[Vector2i] = [origin]
	seen[origin] = true
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var nb: Vector2i = cur + d
			if seen.has(nb) or not _is_vehicle_tile(nb):
				continue
			seen[nb] = true
			queue.append(nb)
	return seen

func _is_vehicle_tile(tile: Vector2i) -> bool:
	return map_data != null and map_data.in_bounds(tile.x, tile.y) \
		and MapData.is_passable(map_data.get_terrain(tile.x, tile.y), 1)

func _nearest_vehicle_tile(origin: Vector2i) -> Vector2i:
	if map_data == null:
		return origin
	var max_radius := maxi(map_data.width, map_data.height)
	for radius in range(0, max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var t := origin + Vector2i(dx, dy)
				if _is_vehicle_tile(t):
					return t
	return origin

func _spawn_unit(pos: Vector2, team: int) -> void:
	_spawn_unit_by_id("riflebot", pos, team)

## Chess-style variant used for mirrored corporations (black/white).
func color_variant_for_team(team: int) -> int:
	var fac_id := GameManager.faction_for_team(team)
	return Faction.color_for_team(fac_id, _color_variant_count(team))

func _color_variant_count(team: int) -> int:
	# When several teams run the same corporation, later teams get a
	# black-or-white variant so players can tell them apart (chess colors).
	var count := 0
	var uf := GameManager.faction_for_team(team)
	for t in GameManager.teams:
		if int(t) >= team:
			break
		var other := GameManager.faction_for_team(int(t))
		if other == uf:
			count += 1
	return count

func _spawn_unit_by_id(uid: String, pos: Vector2, team: int) -> Node2D:
	var u = preload("res://scenes/unit.tscn").instantiate()
	var s: UnitStats = GameManager.registry.get_unit(uid)
	if s == null:
		s = UnitStats.new()
		s.id = uid
		s.display_name = uid.capitalize()
	u.setup(s, team)
	var uf = GameManager.faction_for_team(team)
	var variant := color_variant_for_team(team)
	var body = u.get_node_or_null("Body")
	if body:
		body.color = Faction.colorblind_color_of(uf, SettingsManager.colorblind_palette(), variant)
	u.global_position = pos
	units_container.add_child(u)
	return u

func _spawn_building_by_id(bid: String, pos: Vector2, team: int) -> Node2D:
	var b = preload("res://scenes/building.tscn").instantiate()
	var s: BuildingStats = GameManager.registry.get_building(bid)
	if s == null:
		s = BuildingStats.new()
		s.id = bid
		s.display_name = bid.capitalize()
		s.is_hq = (bid == "hq")
	b.setup(s, team)
	var bf = GameManager.faction_for_team(team)
	var variant := color_variant_for_team(team)
	var bbody = b.get_node_or_null("Body")
	if bbody:
		bbody.color = Faction.colorblind_color_of(bf, SettingsManager.colorblind_palette(), variant)
	b.global_position = pos
	add_child(b)
	GameManager.register_fort_block(b)
	return b

func _world_mouse_pos(screen_pos: Vector2) -> Vector2:
	if camera == null:
		return screen_pos
	var offset := screen_pos - get_viewport_rect().size * 0.5
	# Undo the camera transform so orders/placement stay accurate while zoomed.
	return camera.position + Vector2(offset.x / camera.zoom.x, offset.y / camera.zoom.y)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_capture_screenshot()
		return
	if event is InputEventMouseButton:
		var world_pos := _world_mouse_pos(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and camera:
			camera.zoom = _clamp_camera_zoom(camera.zoom * 1.12)
			camera.position = _clamp_camera(camera.position)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and camera:
			camera.zoom = _clamp_camera_zoom(camera.zoom * 0.89)
			camera.position = _clamp_camera(camera.position)
			return
		# Spectators keep camera controls but cannot select, order or place.
		if GameManager.is_spectator:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.is_key_pressed(KEY_ALT):
				tactical_pings.append({"pos": world_pos, "timer": 4.0})
				queue_redraw()
				return
			if event.pressed and not pending_build_id.is_empty():
				var bid := pending_build_id
				var ctype := "fortify" if Fortification.is_fortification(bid) else "build"
				if submit_player_command({"type": ctype, "id": bid, "target_x": world_pos.x, "target_y": world_pos.y}):
					pending_build_id = ""
				return
			if event.pressed and not pending_target_action.is_empty():
				var action := pending_target_action
				var payload := {"type": action, "target_x": world_pos.x, "target_y": world_pos.y}
				if action == "sonar_buoy":
					payload["unit_ids"] = _selected_unit_ids()
				submit_player_command(payload)
				pending_target_action = ""
				return
			if event.pressed:
				drag_selecting = true
				drag_start = world_pos
				drag_current = world_pos
			else:
				drag_selecting = false
				_complete_selection(drag_start, world_pos, Input.is_key_pressed(KEY_SHIFT), event.double_click)
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not pending_build_id.is_empty() or not pending_target_action.is_empty():
				pending_build_id = ""
				pending_target_action = ""
				return
			if is_instance_valid(selected_building) and selected_building.team == 0:
				selected_building.set_rally(world_pos)
			else:
				_issue_move_order(world_pos, Input.is_key_pressed(KEY_A))
	elif event is InputEventMouseMotion and drag_selecting:
		drag_current = _world_mouse_pos(event.position)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkey(event)

func _complete_selection(start_p: Vector2, end_p: Vector2, additive: bool, double_click: bool = false) -> void:
	if not additive:
		for u in selected_units:
			if is_instance_valid(u):
				u.selected = false
		selected_units.clear()
		if is_instance_valid(selected_building):
			selected_building.selected = false
		selected_building = null

	if start_p.distance_to(end_p) < 12.0:
		var clicked = _unit_at(end_p)
		if clicked and clicked.team == 0:
			if double_click and clicked.stats:
				for u in _get_team_units(0):
					if u.stats and u.stats.id == clicked.stats.id:
						u.selected = true
						if not selected_units.has(u):
							selected_units.append(u)
				if camera != null:
					camera.position = _clamp_camera(clicked.global_position)
			else:
				clicked.selected = true
				if not selected_units.has(clicked):
					selected_units.append(clicked)
		else:
			var bld := _building_at(end_p)
			if bld and bld.team == 0:
				selected_building = bld
				bld.selected = true
	else:
		var rect := Rect2(start_p, end_p - start_p).abs()
		for u in units_container.get_children():
			if is_instance_valid(u) and not u.is_exploding and u.team == 0 and rect.has_point(u.global_position):
				u.selected = true
				if not selected_units.has(u):
					selected_units.append(u)
	if not selected_units.is_empty():
		AudioManager.play_bark("select", GameManager.faction_for_team(GameManager.local_team))

func _issue_move_order(target: Vector2, is_attack_move: bool = true) -> void:
	var ids := _selected_unit_ids()
	if ids.is_empty():
		return
	var cmd := {
		"type": "move", "team": 0, "unit_ids": ids,
		"target_x": target.x, "target_y": target.y,
		"attack_move": is_attack_move,
	}
	if submit_player_command(cmd):
		AudioManager.play_bark(
			"attack" if is_attack_move else "move",
			GameManager.faction_for_team(GameManager.local_team),
		)

func _set_control_group(index: int) -> void:
	control_groups[index] = selected_units.duplicate()
	if is_instance_valid(status_label):
		status_label.text = "Control group %d: %d units" % [index, control_groups[index].size()]

func _recall_control_group(index: int) -> void:
	if not control_groups.has(index):
		return
	for u in selected_units:
		if is_instance_valid(u):
			u.selected = false
	selected_units.clear()
	var centroid := Vector2.ZERO
	var count := 0
	var live_group: Array = []
	for u in control_groups[index]:
		if is_instance_valid(u) and not u.is_exploding:
			u.selected = true
			selected_units.append(u)
			live_group.append(u)
			centroid += u.global_position
			count += 1
	control_groups[index] = live_group
	if count > 0 and camera != null:
		camera.position = _clamp_camera(centroid / float(count))

func _handle_hotkey(event: InputEventKey) -> void:
	if GameManager.is_spectator:
		return
	if event.keycode >= KEY_0 and event.keycode <= KEY_9 and Input.is_key_pressed(KEY_CTRL):
		var grp := int(event.keycode - KEY_0)
		if Input.is_key_pressed(KEY_SHIFT):
			_recall_control_group(grp)
		else:
			_set_control_group(grp)
		return
	match event.keycode:
		KEY_1: _player_train_unit("riflebot")
		KEY_2: _player_train_unit("rocketbot")
		KEY_3: _player_train_unit("stealthbot")
		KEY_4: _player_train_unit("mbt")
		KEY_5: _player_train_unit("aa_vehicle")
		KEY_6: _player_train_unit("fighter_drone")
		KEY_7: _player_train_unit("hovercraft")
		KEY_C: _enter_target_mode("capture")
		KEY_DELETE:
			if is_instance_valid(selected_building):
				submit_player_command({
					"type": "demolish",
					"target_x": selected_building.global_position.x,
					"target_y": selected_building.global_position.y,
				})
		KEY_E: _player_embark_selected()
		KEY_U: _player_disembark_selected()
		KEY_X: _cancel_selected_building_queue()
		KEY_B: _enter_build_mode("extractor")
		KEY_V: _enter_build_mode("turret")
		KEY_P: _enter_build_mode("power_plant")
		KEY_F: _enter_build_mode("wall")
		KEY_G: _enter_build_mode("barbed_wire")
		KEY_M: _enter_build_mode("missile_tower")
		KEY_T: _player_upgrade_tech()
		KEY_R: _open_research_dialog()
		KEY_K: _enter_target_mode("sonar_buoy")
		KEY_L: _enter_target_mode("laser")
		KEY_N: _enter_target_mode("nuke")
		KEY_F5: quicksave_match()
		KEY_F9: quickload_match()
		KEY_H:
			var ids := _selected_unit_ids()
			if not ids.is_empty():
				submit_player_command({"type": "hold", "unit_ids": ids})

func _wallet_cost(s_cost: Dictionary) -> Dictionary:
	return {
		Economy.Res.OIL: int(s_cost.get("oil", 0)),
		Economy.Res.IRON: int(s_cost.get("iron", 0)),
		Economy.Res.GEOTHERMAL: int(s_cost.get("geo", 0)),
		Economy.Res.FOOD: int(s_cost.get("food", 0)),
	}

func _player_train_unit(uid: String) -> void:
	submit_player_command({"type": "train", "id": uid})

func _selected_unit_ids() -> Array:
	var ids: Array = []
	for u in selected_units:
		if is_instance_valid(u):
			ids.append(int(u.net_id))
	return ids

func _player_embark_selected() -> int:
	var ids := _selected_unit_ids()
	if ids.is_empty():
		return 0
	return ids.size() if submit_player_command({"type": "embark", "unit_ids": ids}) else 0

func _player_disembark_selected() -> int:
	var ids := _selected_unit_ids()
	if ids.is_empty():
		return 0
	return ids.size() if submit_player_command({"type": "disembark", "unit_ids": ids}) else 0

func _embark_units_for_team(team: int, candidates: Array) -> int:
	var transports: Array = []
	for u in _get_team_units(team):
		if u.has_method("transport_capacity") and u.transport_capacity() > 0:
			transports.append(u)
	if transports.is_empty():
		return 0
	var loaded := 0
	for u in candidates.duplicate():
		if not is_instance_valid(u) or u.is_exploding or u.team != team:
			continue
		if u.has_method("transport_capacity") and u.transport_capacity() > 0:
			continue
		var best_t: Node2D = null
		var best_d := 140.0
		for t in transports:
			var t_node: Node2D = t
			if t_node.can_load_passenger(u):
				var d: float = (u as Node2D).global_position.distance_to(t_node.global_position)
				if d <= best_d:
					best_d = d
					best_t = t_node
		if best_t != null and best_t.embark_passenger(u):
			selected_units.erase(u)
			loaded += 1
	if loaded > 0 and is_instance_valid(status_label):
		status_label.text = "Embarked %d unit(s) into transport" % loaded
	return loaded

func _disembark_units_for_team(team: int, candidates: Array) -> int:
	var unloaded := 0
	var list := candidates if not candidates.is_empty() else _get_team_units(team)
	for u in list:
		if is_instance_valid(u) and not u.is_exploding and u.team == team and u.has_method("disembark_all"):
			unloaded += u.disembark_all()
	if unloaded > 0 and is_instance_valid(status_label):
		status_label.text = "Disembarked %d unit(s)" % unloaded
	return unloaded

func _command_units(team: int, cmd: Dictionary) -> Array:
	var ids: Array = cmd.get("unit_ids", [])
	if ids.is_empty():
		return _get_team_units(team)
	var by_id: Dictionary = {}
	for u in _get_team_units(team):
		by_id[int(u.net_id)] = u
	var out: Array = []
	for value in ids:
		var unit: Node2D = by_id.get(int(value), null)
		if unit != null:
			out.append(unit)
	return out

## Corvettes lay a finite-lifetime sonar buoy at the ordered point. The
## command still travels through the host pipeline; this function only mutates
## host-side match state after validation.
func _deploy_sonar_buoys(team: int, units: Array, world_pos: Vector2) -> bool:
	if world_pos == Vector2.INF:
		return false
	var deployed := 0
	for value in units:
		var u: Node2D = value
		if not is_instance_valid(u) or u.is_exploding or u.stats == null:
			continue
		if not UnitRegistry.can_deploy_sonar_buoy(u.stats.id):
			continue
		if u.global_position.distance_to(world_pos) > SonarBuoy.DEPLOY_RANGE_PX:
			continue
		var net_id := int(u.net_id)
		if elapsed_time < float(sonar_cooldowns.get(net_id, -INF)):
			continue
		sonar_buoys.append(SonarBuoy.make(team, net_id, world_pos, elapsed_time))
		sonar_cooldowns[net_id] = elapsed_time + SonarBuoy.COOLDOWN_SEC
		deployed += 1
	if deployed > 0 and team == GameManager.local_team:
		AudioManager.play_bark("sonar_buoy", GameManager.faction_for_team(team))
		if is_instance_valid(status_label):
			status_label.text = "Deployed %d sonar buoy(s): submerged contacts are visible for %.0fs" % [
				deployed, SonarBuoy.LIFETIME_SEC,
			]
	return deployed > 0

func _cleanup_sonar_buoys() -> void:
	for i in range(sonar_buoys.size() - 1, -1, -1):
		if not SonarBuoy.is_active(sonar_buoys[i], elapsed_time):
			sonar_buoys.remove_at(i)
	# Cooldowns are keyed by ship net_id; expired keys must not accumulate
	# across a long match with many destroyed/rebuilt corvettes.
	for net_id in sonar_cooldowns.keys():
		if elapsed_time >= float(sonar_cooldowns[net_id]):
			sonar_cooldowns.erase(net_id)

## Called by unit targeting and fog rendering so a buoy reveals submarines to
## its owner and that owner's allies, never to the opposing side.
func sonar_reveals(observer_team: int, target_pos: Vector2) -> bool:
	for buoy in sonar_buoys:
		if SonarBuoy.reveals_sub(buoy, observer_team, target_pos, true):
			return true
	return false

func _capture_with_workers(team: int, units: Array, world_pos: Vector2) -> bool:
	var target := _building_at(world_pos)
	if target == null or GameManager.is_allied(team, int(target.team)) or target.stats == null:
		return false
	if not UnitRegistry.is_production_building(target.stats.id):
		if is_instance_valid(status_label) and team == GameManager.local_team:
			status_label.text = "Only damaged production buildings can be captured"
		return false
	var ordered := 0
	for u in units:
		if not is_instance_valid(u) or u.stats == null or not UnitRegistry.is_worker_unit(u.stats.id):
			continue
		u.stop_command()
		u.move_to(target.global_position + Vector2(18, 0), false)
		ordered += 1
	return ordered > 0

func _demolish_building_for_team(team: int, world_pos: Vector2) -> bool:
	var target := _building_at(world_pos)
	if target == null or int(target.team) != team or target.stats == null:
		return false
	if target.stats.is_hq:
		if is_instance_valid(status_label) and team == GameManager.local_team:
			status_label.text = "HQ cannot be demolished"
		return false
	var wallet := ResourceManager.get_wallet(team)
	var refund := _wallet_cost(target.stats.cost_dict())
	for res in refund.keys():
		var value := int(refund[res])
		wallet[int(res)] = int(wallet.get(int(res), 0)) + maxi(1, int(float(value) * 0.25))
	var pos := target.global_position
	target.take_damage(float(target.hp))
	if is_instance_valid(status_label) and team == GameManager.local_team:
		status_label.text = "Demolished %s at (%.0f, %.0f); 25%% refunded" % [target.stats.display_name, pos.x, pos.y]
	return true

func _apply_diplomacy(team: int, action: String, target_team: int) -> bool:
	var ok := GameManager.apply_diplomacy(team, action, target_team)
	if ok and team == GameManager.local_team and is_instance_valid(status_label):
		status_label.text = "Diplomacy %s with Team %d" % [action, target_team]
	return ok

## Funnel every human command through the secure host pipeline in P2P matches.
## The team is always derived from this client's lobby seat, and coordinates
## are mirrored into the `x`/`y` fields expected by `NetSecurity.sanitize_command`.
## Single-player still applies immediately; a relayed client verdict is async.
func _prepare_player_command(cmd: Dictionary) -> Dictionary:
	var full := cmd.duplicate()
	full["team"] = GameManager.local_team
	var target := _cmd_world_target(full)
	if is_finite(target.x) and is_finite(target.y):
		full["x"] = target.x
		full["y"] = target.y
	if String(full.get("type", "")) == "capture" and not full.has("unit_ids"):
		var workers: Array = []
		for u in selected_units:
			if is_instance_valid(u) and u.stats != null and UnitRegistry.is_worker_unit(u.stats.id):
				workers.append(int(u.net_id))
		full["unit_ids"] = workers
	return full

func submit_player_command(cmd: Dictionary) -> bool:
	var full := _prepare_player_command(cmd)
	if NetworkManager.is_network_match():
		return NetworkManager.send_command(full)
	return apply_command(full)

## `internal` is reserved for simulation-controlled AI commands: spectators
## have no human command authority, but the match still needs AI decisions.
func apply_command(cmd: Dictionary, internal: bool = false) -> bool:
	if GameManager.is_spectator and not internal:
		return false
	var ctype := String(cmd.get("type", ""))
	var team := int(cmd.get("team", GameManager.local_team))
	var ok := false
	match ctype:
		"train":
			ok = _train_unit_for_team(team, String(cmd.get("id", "")))
		"build", "fortify":
			ok = _build_structure_for_team(team, String(cmd.get("id", "")), _cmd_world_target(cmd))
		"embark":
			ok = _embark_units_for_team(team, _command_units(team, cmd)) > 0
		"disembark":
			ok = _disembark_units_for_team(team, _command_units(team, cmd)) > 0
		"move":
			var target := _cmd_world_target(cmd)
			var am := bool(cmd.get("attack_move", true))
			var units := _command_units(team, cmd)
			var offsets := Formation.grid_offsets(units.size(), 28.0)
			for i in range(units.size()):
				units[i].move_to(target + offsets[i], am)
			ok = not units.is_empty()
		"hold", "stop":
			for u in _command_units(team, cmd):
				u.stop_command()
				u.hold_position = (ctype == "hold")
			ok = true
		"tech":
			ok = _research_node(team, String(cmd.get("id", "")))
		"capture":
			ok = _capture_with_workers(team, _command_units(team, cmd), _cmd_world_target(cmd))
		"demolish":
			ok = _demolish_building_for_team(team, _cmd_world_target(cmd))
		"diplomacy":
			ok = _apply_diplomacy(team, String(cmd.get("action", "")), int(cmd.get("target_team", -1)))
		"sonar_buoy":
			ok = _deploy_sonar_buoys(team, _command_units(team, cmd), _cmd_world_target(cmd))
		"laser", "nuke":
			# Team ownership is enforced by the host pipeline for relayed input;
			# local input always carries this client's authoritative team.
			if not team_has_tech(team, "strategic_uplinks"):
				if is_instance_valid(status_label):
					status_label.text = "Research Strategic Uplinks (Orbital & Nuke) first"
				return false
			var target := _cmd_world_target(cmd)
			ok = _player_fire_orbital_laser(target, team) if ctype == "laser" else _player_fire_nuke(target, team)
	if ok:
		_record_replay_command(cmd, ctype, team)
	return ok

func _cmd_world_target(cmd: Dictionary) -> Vector2:
	if cmd.has("target_x") and cmd.has("target_y"):
		return Vector2(float(cmd.get("target_x", 0.0)), float(cmd.get("target_y", 0.0)))
	if cmd.has("x") and cmd.has("y"):
		return Vector2(float(cmd.get("x", 0.0)), float(cmd.get("y", 0.0)))
	return Vector2.INF

## Record accepted commands into the Replay log (Step 15).
func _record_replay_command(cmd: Dictionary, ctype: String, team: int) -> void:
	replay_log.seed = int(GameManager.match_seed)
	replay_log.map_name = ["Desert", "Island Chain", "Forest", "Custom"][clampi(GameManager.map_type, 0, 3)]
	var c := Command.new()
	match ctype:
		"train": c.type = Command.Type.TRAIN
		"build": c.type = Command.Type.BUILD
		"fortify": c.type = Command.Type.FORTIFY
		"embark": c.type = Command.Type.EMBARK
		"disembark": c.type = Command.Type.DISEMBARK
		"move": c.type = Command.Type.ATTACK_MOVE if bool(cmd.get("attack_move", true)) else Command.Type.MOVE
		"hold": c.type = Command.Type.HOLD
		"stop": c.type = Command.Type.STOP
		"tech": c.type = Command.Type.TECH
		"capture": c.type = Command.Type.CAPTURE
		"demolish": c.type = Command.Type.DEMOLISH
		"laser": c.type = Command.Type.ORBITAL
		"nuke": c.type = Command.Type.NUKE
		"diplomacy": c.type = Command.Type.DIPLOMACY
		"sonar_buoy": c.type = Command.Type.SONAR_BUOY
	c.tick = int(elapsed_time * 60.0)
	c.player_id = team
	c.target_pos = _cmd_world_target(cmd)
	if c.target_pos == Vector2.INF:
		c.target_pos = Vector2.ZERO
	c.build_type = String(cmd.get("id", "")) if ctype != "diplomacy" else String(cmd.get("action", ""))
	if ctype == "diplomacy":
		c.target_id = int(cmd.get("target_team", -1))
	var ids: Array = cmd.get("unit_ids", [])
	# Non-unit orders must not inherit whatever happened to be selected.
	if ids.is_empty() and ctype in ["move", "hold", "stop", "embark", "disembark"]:
		for u in selected_units:
			if is_instance_valid(u):
				ids.append(u.net_id)
	for v in ids:
		c.unit_ids.append(int(v))
	replay_log.record(c)

## Save the replay log to user://replays/match.json.
func save_replay() -> Error:
	DirAccess.make_dir_recursive_absolute("user://replays")
	var path := "user://replays/match.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(replay_log.to_dict()))
	f.close()
	if is_instance_valid(status_label):
		status_label.text = "Replay saved (%d commands)" % replay_log.command_count()
	return OK

func _train_unit_for_team(team: int, uid: String) -> bool:
	var s := GameManager.registry.get_unit(uid)
	if s == null:
		return false
	var fac_id := GameManager.faction_for_team(team)
	if s.ai_only:
		if not GameManager.is_ai_team(team) or fac_id != s.native_faction:
			if team == GameManager.local_team and is_instance_valid(status_label):
				status_label.text = "%s is exclusive to %s (AI only)" % [
					s.display_name, Faction.name_of(s.native_faction),
				]
			return false
	# Production tiers are enforced before spending: no free fallback spawn at
	# fixed coordinates when the required factory is missing.
	var valid_producers := UnitRegistry.producer_ids_for_unit(uid, s.unit_class)
	var producer: Node2D = null
	var best_q_len := 999999
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats != null:
			if String(b.stats.id) in valid_producers and b.has_method("enqueue_unit"):
				var q_len: int = b.production_queue.size() if "production_queue" in b else 0
				if q_len < best_q_len:
					best_q_len = q_len
					producer = b
	if producer == null:
		if team == GameManager.local_team and is_instance_valid(status_label):
			status_label.text = "%s requires: %s" % [uid, ", ".join(PackedStringArray(valid_producers))]
		return false
	var wallet := ResourceManager.get_wallet(team)
	var cost := _wallet_cost(Faction.effective_unit_cost(fac_id, s))
	if not Economy.spend(wallet, cost):
		return false
	producer.enqueue_unit(uid, s.build_time)
	return true

func _enter_build_mode(bid: String) -> void:
	pending_target_action = ""
	pending_build_id = bid
	if is_instance_valid(status_label):
		status_label.text = "Place %s: Left-Click map to build, Right-Click to cancel" % bid

func _enter_target_mode(action: String) -> void:
	pending_build_id = ""
	pending_target_action = action
	if is_instance_valid(status_label):
		status_label.text = "Target %s: Left-Click coordinates, Right-Click to cancel" % action.to_upper()

func _cancel_selected_building_queue() -> void:
	if is_instance_valid(selected_building) and selected_building.team == GameManager.local_team and selected_building.has_method("cancel_last_queued"):
		var cancelled: String = selected_building.cancel_last_queued()
		if not cancelled.is_empty() and is_instance_valid(status_label):
			status_label.text = "Cancelled queued %s" % cancelled

func _reset_selected_building_rally() -> void:
	if is_instance_valid(selected_building) and selected_building.team == GameManager.local_team:
		selected_building.has_rally = false
		selected_building.rally_point = selected_building.global_position + (Vector2(56, 56) if selected_building.team == 0 else Vector2(-56, -56))
		if is_instance_valid(status_label):
			status_label.text = "Reset rally point for %s" % selected_building.stats.display_name

func _demolish_selected_building() -> void:
	if is_instance_valid(selected_building) and selected_building.team == GameManager.local_team:
		submit_player_command({
			"type": "demolish",
			"target_x": selected_building.global_position.x,
			"target_y": selected_building.global_position.y,
		})

func _team_has_builder_for(team: int, bid: String) -> bool:
	if not UnitRegistry.requires_advanced_builder(bid):
		return true
	for u in _get_team_units(team):
		if u.stats and UnitRegistry.can_unit_construct(u.stats.id, bid):
			return true
	return false

func _team_has_worker_near(team: int, pos: Vector2) -> bool:
	for u in _get_team_units(team):
		if u.stats and UnitRegistry.is_worker_unit(u.stats.id) and u.global_position.distance_to(pos) <= 96.0:
			return true
	return false

func _near_resource_deposit(pos: Vector2) -> bool:
	for rd in resource_deposits:
		if pos.distance_to(Vector2(rd.get("pos", Vector2.ZERO))) <= 112.0:
			return true
	return false

func _bonus_for_building(b: Node2D) -> Dictionary:
	if not is_instance_valid(b) or b.stats == null:
		return {}
	var team := int(b.team)
	if b.stats.id == "extractor" and _near_resource_deposit(b.global_position):
		return {
			"team": team, "cap": 0,
			"rates": {
				Economy.Res.OIL: 8, Economy.Res.IRON: 12, Economy.Res.GEOTHERMAL: 5,
			},
		}
	if b.stats.id == "farm":
		return {"team": team, "cap": 8, "rates": {}}
	return {}

func _apply_building_bonus(b: Node2D, apply: bool) -> void:
	if not is_instance_valid(b):
		return
	var key := b.get_instance_id()
	if not apply:
		if not building_bonuses.has(key):
			return
		var old: Dictionary = building_bonuses[key]
		building_bonuses.erase(key)
		var old_team := int(old.get("team", b.team))
		for res in (old.get("rates", {}) as Dictionary).keys():
			var amount := int((old["rates"] as Dictionary)[res])
			ResourceManager.set_rate(old_team, int(res), maxi(0, ResourceManager.get_base_rate(old_team, int(res)) - amount))
		ResourceManager.caps[old_team] = maxi(0, int(ResourceManager.caps.get(old_team, 20)) - int(old.get("cap", 0)))
		return
	if building_bonuses.has(key):
		return
	var bonus := _bonus_for_building(b)
	if bonus.is_empty():
		return
	building_bonuses[key] = bonus
	var team := int(bonus.get("team", b.team))
	for res in (bonus.get("rates", {}) as Dictionary).keys():
		var amount := int((bonus["rates"] as Dictionary)[res])
		ResourceManager.set_rate(team, int(res), ResourceManager.get_base_rate(team, int(res)) + amount)
	ResourceManager.caps[team] = int(ResourceManager.caps.get(team, 20)) + int(bonus.get("cap", 0))

func _rebuild_building_bonuses() -> void:
	building_bonuses.clear()
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or ("is_exploding" in b and b.is_exploding):
			continue
		var bonus := _bonus_for_building(b)
		if not bonus.is_empty():
			building_bonuses[b.get_instance_id()] = bonus

func on_building_destroyed(b: Node2D) -> void:
	_apply_building_bonus(b, false)

## Anchor unplaced buildings to the team's own HQ. Fixed corner coordinates
## used to drop structures into unrelated terrain, which looked like random
## buildings appearing across the map once matches started with only an HQ.
func _building_anchor(team: int) -> Vector2:
	var hq := _find_team_hq(team)
	if hq != null:
		return hq.global_position
	var count := 0
	var sum := Vector2.ZERO
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and int(b.team) == team:
			sum += b.global_position
			count += 1
	if count > 0:
		return sum / float(count)
	return Vector2(160, 160) if team == 0 else Vector2(1080, 880)

## Deterministic ring search around a base. Every candidate must satisfy the
## same placement rules as a human click, so auto-placed AI structures never
## land on water, mountains or tiles occupied by another building.
func _find_free_build_tile(
	team: int, bid: String, footprint: Vector2i, anchor: Vector2,
	min_ring: int = 3, max_ring: int = -1
) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	var base := Vector2i(int(anchor.x / TILE_SIZE), int(anchor.y / TILE_SIZE))
	var start := wrapi(team * 5 + _count_team_buildings(team, bid) * 3, 0, 16)
	var limit := mini(map_data.width, map_data.height)
	if max_ring > 0:
		limit = mini(limit, max_ring + 1)
	for ring in range(maxi(1, min_ring), limit):
		for step in range(16):
			var angle := TAU * float((step + start) % 16) / 16.0
			var tile := base + Vector2i(
				roundi(cos(angle) * float(ring)), roundi(sin(angle) * float(ring))
			)
			if Placement.can_place_building(map_data, bid, footprint, tile, occupied_tiles):
				return tile
	return Vector2i(-1, -1)

func _build_structure_for_team(team: int, bid: String, world_pos: Vector2 = Vector2.INF) -> bool:
	var bs := GameManager.registry.get_building(bid)
	if bs == null:
		return false
	if bid in ["mech_factory_3", "advanced_shipyard", "aeries_2"] and not team_has_tech(team, "super_heavy"):
		if team == 0 and is_instance_valid(status_label):
			status_label.text = "Research Super-Heavy Chassis before building %s" % bid
		return false
	if not _team_has_builder_for(team, bid):
		return false
	var target_pos := world_pos
	var reserve_origin := Vector2i(-1, -1)
	if target_pos == Vector2.INF:
		var origin := _find_free_build_tile(team, bid, bs.footprint, _building_anchor(team))
		if origin.x < 0 or origin.y < 0:
			return false
		reserve_origin = origin
		target_pos = Vector2(
			float(origin.x) + float(bs.footprint.x) * 0.5,
			float(origin.y) + float(bs.footprint.y) * 0.5
		) * TILE_SIZE
	elif map_data != null:
		if Fortification.is_fortification(bid) and not _team_has_worker_near(team, target_pos):
			if team == 0 and is_instance_valid(status_label):
				status_label.text = "Move a sapper near the site to build %s" % bid
			return false
		var origin := Vector2i(int(target_pos.x / TILE_SIZE), int(target_pos.y / TILE_SIZE))
		if not Placement.can_place_building(map_data, bid, bs.footprint, origin, occupied_tiles):
			if team == 0 and is_instance_valid(status_label):
				status_label.text = "Cannot place %s here (blocked or invalid terrain)" % bid
			return false
		reserve_origin = origin
	var wallet := ResourceManager.get_wallet(team)
	var cost := _wallet_cost(bs.cost_dict())
	if not Economy.spend(wallet, cost):
		return false
	# Reserve tiles only after the cost is paid; a rejected order leaves no
	# invisible occupancy behind for later placement checks.
	if reserve_origin.x >= 0 and reserve_origin.y >= 0:
		Placement.occupy(occupied_tiles, bs.footprint, reserve_origin)
	var placed := _spawn_building_by_id(bid, target_pos, team)
	_apply_building_bonus(placed, true)
	if bid == "extractor" and not building_bonuses.has(placed.get_instance_id()) and team == GameManager.local_team and is_instance_valid(status_label):
		status_label.text = "Extractor built away from a deposit: no collection bonus or payout."
	return true

func _team_has_research_lab(team: int) -> bool:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats and b.stats.id == "research_lab":
			return true
	return false

func team_has_tech(team: int, node_id: String) -> bool:
	var unlocked: Array = team_unlocked_tech.get(team, [])
	return unlocked.has(node_id)

## Numeric combat modifiers granted by researched nodes, applied in unit.gd.
func team_tech_bonus(team: int, key: String) -> float:
	var bonus := 0.0
	if team_has_tech(team, "reactive_armor") and key == "armor_hp":
		bonus += 0.15
	if team_has_tech(team, "railgun_cal") and key == "weapon_damage":
		bonus += 0.15
	if team_has_tech(team, "cloak_caps") and key == "cloak_duration":
		bonus += 0.25
	return bonus

func _research_node(team: int, node_id: String) -> bool:
	var local_feedback := team == GameManager.local_team
	var info: Dictionary = Tech.node_info(node_id)
	if info.is_empty():
		if local_feedback and is_instance_valid(status_label):
			status_label.text = "Unknown research node: %s" % node_id
		return false
	if not _team_has_research_lab(team):
		if local_feedback and is_instance_valid(status_label):
			status_label.text = "Build a Research Lab before researching %s" % String(info.get("name", node_id))
		return false
	var unlocked: Array = team_unlocked_tech.get(team, [])
	if unlocked.has(node_id):
		return false
	if not Tech.can_research(unlocked, info.get("requires", [])):
		if local_feedback and is_instance_valid(status_label):
			status_label.text = "Prerequisites missing for %s" % String(info.get("name", node_id))
		return false
	var cost: Dictionary = info.get("cost", {})
	var wallet := ResourceManager.get_wallet(team)
	if not Tech.research_cost_affordable(wallet, cost):
		if local_feedback and is_instance_valid(status_label):
			status_label.text = "Not enough resources for %s" % String(info.get("name", node_id))
		return false
	Economy.spend(wallet, cost)
	Tech.unlock(unlocked, node_id)
	team_unlocked_tech[team] = unlocked
	if team == 0:
		player_tech_tier = mini(4, player_tech_tier + 1)
	elif team == 1:
		ai_tech_tier = mini(4, ai_tech_tier + 1)
	# Reactive armor also tops up existing units so the bonus is immediate.
	if node_id == "reactive_armor":
		for u in _get_team_units(team):
			if u.stats:
				u.hp = mini(u.effective_max_hp(), u.hp + maxi(1, int(float(u.stats.hp) * 0.15)))
	if local_feedback:
		AudioManager.play_bark("tech_complete", GameManager.faction_for_team(team), String(info.get("name", node_id)))
		if is_instance_valid(status_label):
			status_label.text = "Researched %s!" % String(info.get("name", node_id))
	else:
		AudioManager.play_sfx("tech_up")
	return true

func _player_upgrade_tech() -> void:
	var unlocked: Array = team_unlocked_tech.get(GameManager.local_team, [])
	var avail := Tech.available_nodes(unlocked)
	if avail.is_empty():
		if is_instance_valid(status_label):
			status_label.text = "Research tree complete"
		return
	submit_player_command({"type": "tech", "id": str(avail[0])})

func _team_laser_cooldown(team: int) -> float:
	if laser_cooldowns.has(team):
		return float(laser_cooldowns[team])
	return laser_cooldown if team == maxi(0, GameManager.local_team) else 0.0

func _team_nuke_cooldown(team: int) -> float:
	if nuke_cooldowns.has(team):
		return float(nuke_cooldowns[team])
	return nuke_cooldown if team == maxi(0, GameManager.local_team) else 0.0

func _player_fire_orbital_laser(world_target: Vector2 = Vector2.INF, team: int = -1) -> bool:
	var actor := team if team >= 0 else GameManager.local_team
	if _team_laser_cooldown(actor) > 0.0:
		return false
	var wallet := ResourceManager.get_wallet(actor)
	var uplifted := team_has_tech(actor, "strategic_uplinks")
	var uplink_mult := 0.75 if uplifted else 1.0
	if not Economy.spend(wallet, {
		Economy.Res.GEOTHERMAL: int(round(100.0 * uplink_mult)),
		Economy.Res.OIL: int(round(60.0 * uplink_mult)),
	}):
		return false
	var mods := Faction.modifiers(GameManager.faction_for_team(actor))
	var cd := 25.0 * float(mods.get("orbital_cooldown", 1.0)) * uplink_mult
	laser_cooldowns[actor] = cd
	if actor == maxi(0, GameManager.local_team):
		laser_cooldown = cd
	var target_pos := world_target
	if target_pos == Vector2.INF:
		target_pos = Vector2(1060, 860)
		var enemy := _find_priority_target_for_team(actor)
		if enemy != null:
			target_pos = enemy.global_position
	var dmg := Strategic.orbital_laser_damage(180.0, float(wallet.get(Economy.Res.GEOTHERMAL, 0)))
	if uplifted:
		dmg *= 1.2
	_apply_aoe_damage(target_pos, 95.0, dmg, actor)
	active_vfx.append({"type": "laser", "pos": target_pos, "radius": 95.0, "color": Color(0.2, 0.95, 1.0, 0.75), "timer": 1.2, "duration": 1.2})
	AudioManager.play_bark("orbital_laser", GameManager.faction_for_team(actor))
	return true

func _player_fire_nuke(world_target: Vector2 = Vector2.INF, team: int = -1) -> bool:
	var actor := team if team >= 0 else GameManager.local_team
	if _team_nuke_cooldown(actor) > 0.0:
		return false
	var wallet := ResourceManager.get_wallet(actor)
	var uplink_mult := 0.75 if team_has_tech(actor, "strategic_uplinks") else 1.0
	if not Economy.spend(wallet, {
		Economy.Res.GEOTHERMAL: int(round(200.0 * uplink_mult)),
		Economy.Res.IRON: int(round(300.0 * uplink_mult)),
		Economy.Res.OIL: int(round(180.0 * uplink_mult)),
	}):
		return false
	var cd := 45.0 * uplink_mult
	nuke_cooldowns[actor] = cd
	if actor == maxi(0, GameManager.local_team):
		nuke_cooldown = cd
	var target_pos := world_target
	if target_pos == Vector2.INF:
		target_pos = Vector2(1100, 900)
		var enemy_hq := _find_team_hq(1 if actor == 0 else 0)
		if enemy_hq != null:
			target_pos = enemy_hq.global_position
	_apply_aoe_damage(target_pos, 180.0, 650.0, actor)
	if Strategic.creates_fallout("nuke"):
		var rad := Strategic.nuke_fallout_radius(4, 1.0)
		var cx := clampi(int(target_pos.x / 16.0), 0, map_data.width - 1)
		var cy := clampi(int(target_pos.y / 16.0), 0, map_data.height - 1)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				map_data.set_terrain(cx + dx, cy + dy, MapData.Terrain.WASTELAND)
	_update_terrain_image()
	active_vfx.append({"type": "nuke", "pos": target_pos, "radius": 180.0, "color": Color(1.0, 0.45, 0.1, 0.8), "timer": 2.0, "duration": 2.0})
	AudioManager.play_bark("nuke_warning", GameManager.faction_for_team(actor))
	return true

func _apply_aoe_damage(center: Vector2, radius: float, dmg: float, attacker_team: int) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and not u.is_exploding and not GameManager.is_allied(attacker_team, int(u.team)) and u.global_position.distance_to(center) <= radius:
			u.take_damage(dmg)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and not GameManager.is_allied(attacker_team, int(b.team)) and b.global_position.distance_to(center) <= radius:
			b.take_damage(dmg)
	for cr in wildlife_herd:
		if bool(cr.get("alive", true)) and Vector2(cr["pos"]).distance_to(center) <= radius:
			WildlifeRef.apply_damage(cr, dmg, center)

func _find_team_hq(team: int) -> Node2D:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats and b.stats.is_hq:
			return b
	return null

func _find_priority_target_for_team(attacker_team: int) -> Node2D:
	var candidates: Array = []
	var node_map: Dictionary = {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and not GameManager.is_allied(attacker_team, int(b.team)):
			var id := b.get_instance_id()
			node_map[id] = b
			candidates.append({"id": id, "strength": float(b.hp)})
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and not u.is_exploding and not GameManager.is_allied(attacker_team, int(u.team)):
			var id := u.get_instance_id()
			node_map[id] = u
			candidates.append({"id": id, "strength": float(u.hp)})
	var picked_id := AI.choose_weakest_target(candidates)
	return node_map.get(picked_id, null)

func _init_team_fogs() -> void:
	team_fogs.clear()
	if map_data == null:
		return
	for value in GameManager.teams:
		var team := int(value)
		team_fogs[team] = FogOfWar.new(map_data.width, map_data.height, map_data)

## Each AI side gets its own knowledge fog. Spectator mode disables the human
## fog overlay, but AIs must still discover enemies through their own scouts.
func _refresh_team_fog(team: int) -> FogOfWar:
	var tf: FogOfWar = team_fogs.get(team, null)
	if tf == null and map_data != null:
		tf = FogOfWar.new(map_data.width, map_data.height, map_data)
		team_fogs[team] = tf
	if tf == null:
		return null
	tf.reset_visibility()
	for u in units_container.get_children():
		if not is_instance_valid(u) or u.is_exploding or not GameManager.is_allied(team, int(u.team)):
			continue
		var sight_tiles := 8
		if u.has_method("effective_sight"):
			sight_tiles = maxi(1, int(float(u.effective_sight()) / TILE_SIZE))
		elif u.stats:
			sight_tiles = maxi(1, int(u.stats.sight / TILE_SIZE))
		tf.mark_visible(
			int(u.global_position.x / TILE_SIZE), int(u.global_position.y / TILE_SIZE), sight_tiles
		)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.is_exploding or not GameManager.is_allied(team, int(b.team)):
			continue
		var range_px := _building_vision_px(b, team)
		if range_px <= 0.0:
			continue
		tf.mark_visible(
			int(b.global_position.x / TILE_SIZE), int(b.global_position.y / TILE_SIZE),
			maxi(1, ceili(range_px / TILE_SIZE)),
		)
	for buoy in sonar_buoys:
		if not SonarBuoy.is_active(buoy, elapsed_time):
			continue
		if not GameManager.is_allied(team, int(buoy.get("owner_team", -1))):
			continue
		var bpos: Vector2 = buoy.get("pos", Vector2.ZERO)
		tf.mark_visible(
			int(bpos.x / TILE_SIZE), int(bpos.y / TILE_SIZE),
			maxi(1, ceili(float(buoy.get("radius_px", SonarBuoy.RADIUS_PX)) / TILE_SIZE)),
		)
	return tf

## Structures normally see a short perimeter. Radar buildings (radar and
## sapper missile towers) sweep a limited range that collapses when unpowered.
func _building_vision_px(b: Node2D, team: int) -> float:
	if not is_instance_valid(b) or b.stats == null:
		return 80.0
	if b.stats.radar_range <= 0.0:
		return 80.0
	return b.stats.radar_range * clampf(get_team_power_efficiency(team), 0.0, 1.0)

## Best powered radar sweep covering an observer. Units use this to acquire
## cloaked contacts in the same limited area the radar reveals on the map.
func radar_support_range(observer_team: int, observer_pos: Vector2) -> float:
	var best := 0.0
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.is_exploding or not GameManager.is_allied(observer_team, int(b.team)):
			continue
		if b.stats == null or b.stats.radar_range <= 0.0:
			continue
		var sweep_range := _building_vision_px(b, observer_team)
		if sweep_range > 0.0 and b.global_position.distance_to(observer_pos) <= sweep_range:
			best = maxf(best, sweep_range)
	return best

func _node_visible_to_team(team: int, node: Node2D, tf: FogOfWar) -> bool:
	var node_team := int(node.get("team"))
	if node_team == team or GameManager.is_allied(team, node_team):
		return true
	var pos: Vector2 = node.global_position
	if tf != null:
		if not tf.is_visible(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE)):
			return false
	if not node.is_in_group("units"):
		return true
	if node.stats and node.stats.armor_class == Damage.ArmorClass.SUBMERGED:
		if sonar_reveals(team, pos):
			return true
		for ally in _get_team_units(team):
			if ally.stats == null:
				continue
			var has_sonar := Vision.is_sonar_unit(ally.stats.id)
			var ally_sight: float = float(ally.effective_sight()) if ally.has_method("effective_sight") else float(ally.stats.sight)
			if Vision.sub_detected(ally_sight, ally.global_position.distance_to(pos), has_sonar):
				return true
		return false
	if node.has_method("is_cloaked") and node.is_cloaked():
		for ally in _get_team_units(team):
			if ally.stats == null:
				continue
			var has_radar: bool = Vision.is_sonar_unit(ally.stats.id) or Vision.is_radar_unit(ally.stats.id)
			var ally_sight: float = float(ally.effective_sight()) if ally.has_method("effective_sight") else float(ally.stats.sight)
			if Vision.stealth_detected(ally_sight, ally.global_position.distance_to(pos), true, has_radar):
				return true
		for b in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(b) or b.is_exploding or not GameManager.is_allied(team, int(b.team)):
				continue
			if b.stats == null or b.stats.radar_range <= 0.0:
				continue
			var radar_px := _building_vision_px(b, team)
			if radar_px > 0.0 and Vision.stealth_detected(radar_px, b.global_position.distance_to(pos), true, true):
				return true
		return false
	return true

## Enemy units this side can actually observe. AI defense and counter-
## production must not use spectator knowledge or hidden enemy movements.
func _visible_enemy_units(team: int) -> Array:
	var knowledge_fog: FogOfWar = fog
	if GameManager.is_ai_team(team):
		knowledge_fog = _refresh_team_fog(team)
	var out: Array = []
	for u in _enemy_units(team):
		if _node_visible_to_team(team, u, knowledge_fog):
			out.append(u)
	return out

## Nearest enemy the team can currently see. Fog of war must not reveal
## unit/node positions to the AI, and distant weak targets must not override
## nearby contacts.
func _find_nearest_visible_enemy(team: int, from_pos: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_dist
	var knowledge_fog: FogOfWar = fog
	if GameManager.is_ai_team(team):
		knowledge_fog = _refresh_team_fog(team)
	var groups := ["units", "buildings"]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node.is_exploding:
				continue
			if int(node.get("team")) == team or GameManager.is_allied(team, int(node.get("team"))):
				continue
			if not _node_visible_to_team(team, node, knowledge_fog):
				continue
			var d := from_pos.distance_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best

func _unit_at(pos: Vector2):
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.global_position.distance_to(pos) < 18:
			return u
	return null

func _building_at(pos: Vector2) -> Node2D:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not ("is_exploding" in b and b.is_exploding) and b.global_position.distance_to(pos) < 28.0:
			return b
	return null

func get_team_power_summary(team: int) -> Dictionary:
	var bids: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not ("is_exploding" in b and b.is_exploding) and b.team == team and b.stats:
			bids.append(b.stats.id)
	return Power.team_power_summary(bids)

func get_team_power_efficiency(team: int) -> float:
	return float(get_team_power_summary(team).get("efficiency", 1.0))

func _spawn_resource_deposits() -> void:
	resource_deposits.clear()
	if map_data == null:
		return
	# Authored editor deposits take precedence; random deposits are only for
	# generated maps and must sit on passable tiles.
	if not map_data.deposits.is_empty():
		for d in map_data.deposits:
			var dep := ResourceDeposit.new()
			dep.type = clampi(int(d.get("type", 0)), 0, 3)
			dep.amount = maxi(1, int(d.get("amount", 1500)))
			dep.harvest_rate = maxf(0.1, float(d.get("rate", 10.0)))
			resource_deposits.append({
				"pos": _tile_world(Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))),
				"deposit": dep,
			})
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.match_seed ^ 0x10B4
	var min_x := mini(6, maxi(1, map_data.width - 2))
	var max_x := maxi(min_x, map_data.width - 7)
	var min_y := mini(6, maxi(1, map_data.height - 2))
	var max_y := maxi(min_y, map_data.height - 7)
	for i in range(16):
		var tx := rng.randi_range(min_x, max_x)
		var ty := rng.randi_range(min_y, max_y)
		if not MapData.is_passable(map_data.get_terrain(tx, ty), 1):
			var alt := _nearest_vehicle_tile(Vector2i(tx, ty))
			tx = alt.x
			ty = alt.y
		var dep := ResourceDeposit.new()
		dep.type = i % 4
		dep.amount = 1500
		dep.harvest_rate = 10.0
		resource_deposits.append({"pos": _tile_world(Vector2i(tx, ty)), "deposit": dep})

func _install_saved_map(raw: Variant) -> void:
	if not (raw is Dictionary) or map_data == null:
		return
	var saved := MapSerializer.from_dict(raw as Dictionary)
	if saved == null or saved.width <= 0 or saved.height <= 0:
		return
	map_data = saved
	GameManager.current_map = saved
	_update_terrain_image()
	_apply_camera_bounds()
	if fog != null:
		fog = FogOfWar.new(map_data.width, map_data.height, map_data)
		fog_image = Image.create(map_data.width, map_data.height, false, Image.FORMAT_RGBA8)
		fog_texture = ImageTexture.create_from_image(fog_image)
		if fog_sprite != null:
			fog_sprite.texture = fog_texture
	team_fogs.clear()

## Extractors pull a finite bonus from nearby deposits; depleted nodes stop
## paying out and disappear from the map (Step 2).
func _harvest_deposits(delta: float) -> void:
	for rd in resource_deposits:
		var dep: ResourceDeposit = rd["deposit"]
		if dep == null or dep.is_depleted():
			continue
		var collector_team := -1
		var pos: Vector2 = rd["pos"]
		for b in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(b) or b.is_exploding or b.stats == null or b.stats.id != "extractor":
				continue
			if b.global_position.distance_to(pos) <= 112.0:
				collector_team = int(b.team)
				break
		if collector_team < 0:
			continue
		var amount := dep.harvest(delta)
		if amount <= 0:
			continue
		if not ResourceManager.wallets.has(collector_team):
			ResourceManager.init_player(collector_team)
		ResourceManager.wallets[collector_team][dep.type] = int(ResourceManager.wallets[collector_team].get(dep.type, 0)) + amount
		if dep.is_depleted() and is_instance_valid(status_label) and GameManager.is_allied(GameManager.local_team, collector_team):
			status_label.text = "%s deposit depleted near your extractor" % ["Oil", "Iron", "Geo", "Food"][clampi(dep.type, 0, 3)]

func quicksave_match(path: String = "user://saves/quicksave.bws") -> Error:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var gs := GameState.new()
	gs.tick = int(elapsed_time * 20.0)
	for pid in _economy_team_ids():
		gs.resources[str(pid)] = ResourceManager.get_wallet(pid).duplicate()
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.stats:
			gs.units.append({
				"id": u.stats.id, "team": u.team, "x": u.global_position.x,
				"y": u.global_position.y, "hp": u.hp, "faction": u.faction,
				"net_id": u.net_id,
			})
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.stats:
			gs.buildings.append({
				"id": b.stats.id, "team": b.team, "x": b.global_position.x,
				"y": b.global_position.y, "hp": b.hp,
				"queue": b.production_queue.duplicate(true),
				"rally_x": b.rally_point.x, "rally_y": b.rally_point.y,
				"has_rally": b.has_rally,
			})
	var rates: Dictionary = {}
	var base_rates: Dictionary = {}
	var power_efficiency: Dictionary = {}
	var caps: Dictionary = {}
	var tech: Dictionary = {}
	for pid in _economy_team_ids():
		rates[str(pid)] = ResourceManager.rates.get(pid, Economy.empty_wallet()).duplicate()
		base_rates[str(pid)] = ResourceManager.base_rates.get(pid, Economy.empty_wallet()).duplicate()
		power_efficiency[str(pid)] = clampf(float(ResourceManager.power_efficiency.get(pid, 1.0)), 0.0, 1.0)
		caps[str(pid)] = int(ResourceManager.caps.get(pid, 20))
		tech[str(pid)] = team_unlocked_tech.get(pid, []).duplicate()
	var deposits: Array = []
	for i in range(resource_deposits.size()):
		deposits.append(int((resource_deposits[i]["deposit"] as ResourceDeposit).amount))
	var saved_buoys: Array = []
	for buoy in sonar_buoys:
		var bpos: Vector2 = buoy.get("pos", Vector2.ZERO)
		saved_buoys.append({
			"owner_team": int(buoy.get("owner_team", 0)),
			"owner_id": int(buoy.get("owner_id", 0)),
			"x": bpos.x, "y": bpos.y,
			"deployed_at": float(buoy.get("deployed_at", elapsed_time)),
			"expires_at": float(buoy.get("expires_at", elapsed_time)),
		})
	var sg := SaveGame.new()
	sg.game_state = gs.snapshot()
	sg.settings = {
		"elapsed_time": elapsed_time,
		"match_duration": match_duration,
		"player_tech_tier": player_tech_tier,
		"ai_tech_tier": ai_tech_tier,
		"tech": tech,
		"rates": rates,
		"base_rates": base_rates,
		"power_efficiency": power_efficiency,
		"caps": caps,
		"map_type": GameManager.map_type,
		"match_seed": GameManager.match_seed,
		"teams": GameManager.teams.duplicate(),
		"alliances": GameManager.alliances.duplicate(true),
		"alliance_proposals": GameManager.alliance_proposals.duplicate(true),
		"match_mode": GameManager.match_mode,
		"ai_enabled": GameManager.ai_enabled,
		"ai_teams": GameManager.ai_teams.duplicate(),
		"team_factions": GameManager.team_factions.duplicate(),
		"team_difficulties": GameManager.team_difficulties.duplicate(),
		"is_spectator": GameManager.is_spectator,
		"local_team": GameManager.local_team,
		"map": MapSerializer.to_dict(map_data) if map_data != null else {},
		"deposits": deposits,
		"sonar_buoys": saved_buoys,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(sg.to_dict()))
	f.close()
	if is_instance_valid(status_label):
		status_label.text = "Match saved (%d units, %d buildings)" % [gs.units.size(), gs.buildings.size()]
	return OK

func _normalized_wallet(raw: Variant) -> Dictionary:
	var out := Economy.empty_wallet()
	if not (raw is Dictionary):
		return out
	for k in (raw as Dictionary).keys():
		out[int(k)] = int((raw as Dictionary)[k])
	return out

func _reset_match_transients() -> void:
	match_over = false
	pending_build_id = ""
	pending_target_action = ""
	drag_selecting = false
	laser_cooldown = 0.0
	nuke_cooldown = 0.0
	laser_cooldowns.clear()
	nuke_cooldowns.clear()
	economy_timer = 0.0
	ai_timer = 0.0
	ai_tactical_state = "rally"
	ai_retreat_until.clear()
	ai_next_build_time = 0.0
	ai_next_train_time = 0.0
	ai_order_until.clear()
	ai_states.clear()
	ai_command_seq = 0
	sonar_buoys.clear()
	sonar_cooldowns.clear()
	control_groups.clear()
	active_vfx.clear()
	active_tracers.clear()
	tactical_pings.clear()
	scorch_marks.clear()
	replay_log = Replay.new()
	if is_instance_valid(victory_panel):
		victory_panel.hide()
	if is_instance_valid(pause_panel):
		pause_panel.hide()
	if is_instance_valid(research_dialog):
		research_dialog.hide()
	if is_instance_valid(diplomacy_dialog):
		diplomacy_dialog.hide()
	get_tree().paused = false

func quickload_match(path: String = "user://saves/quicksave.bws") -> bool:
	if not FileAccess.file_exists(path):
		if is_instance_valid(status_label):
			status_label.text = "No save file found at %s" % path
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		if is_instance_valid(status_label):
			status_label.text = "Cannot open save: %s" % error_string(FileAccess.get_open_error())
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		if is_instance_valid(status_label):
			status_label.text = "Save file is corrupt (invalid JSON)"
		return false
	var sg := SaveGame.from_dict(parsed as Dictionary)
	if sg.version != 1:
		if is_instance_valid(status_label):
			status_label.text = "Unsupported save version %d" % sg.version
		return false
	if not (sg.game_state is Dictionary) or not (sg.settings is Dictionary):
		if is_instance_valid(status_label):
			status_label.text = "Save file is corrupt (missing game state)"
		return false
	var snap := sg.game_state as Dictionary
	var settings := sg.settings as Dictionary
	if not (snap.get("units", []) is Array) or not (snap.get("buildings", []) is Array) or not (snap.get("resources", {}) is Dictionary):
		if is_instance_valid(status_label):
			status_label.text = "Save file is corrupt (invalid entity snapshot)"
		return false
	for section in ["rates", "base_rates", "power_efficiency", "caps", "tech", "deposits", "team_factions", "team_difficulties"]:
		if settings.has(section) and not (settings[section] is Array or settings[section] is Dictionary):
			if is_instance_valid(status_label):
				status_label.text = "Save file is corrupt (invalid %s)" % String(section)
			return false
	if settings.has("teams") and not (settings["teams"] is Array):
		if is_instance_valid(status_label):
			status_label.text = "Save file is corrupt (invalid teams)"
		return false
	if settings.has("ai_teams") and not (settings["ai_teams"] is Array):
		if is_instance_valid(status_label):
			status_label.text = "Save file is corrupt (invalid ai_teams)"
		return false
	for section in ["alliances", "alliance_proposals"]:
		if settings.has(section) and not (settings[section] is Dictionary):
			if is_instance_valid(status_label):
				status_label.text = "Save file is corrupt (invalid %s)" % String(section)
			return false
	var map_check := MapSerializer.validate_detailed(settings.get("map", {}))
	if not bool(map_check.get("ok", false)):
		if is_instance_valid(status_label):
			status_label.text = "Save map is invalid: %s" % String(map_check.get("reason", "unknown error"))
		return false
	var gs := GameState.from_snapshot(snap)

	# Clear transient match state before replaying the snapshot; loading after
	# a victory must not leave the end panel or stale orders active.
	_reset_match_transients()
	_install_saved_map(settings.get("map", {}))
	resource_deposits.clear()
	_spawn_resource_deposits()

	# Clear the live match before replaying the snapshot.
	for u in units_container.get_children():
		u.queue_free()
	for b in get_tree().get_nodes_in_group("buildings"):
		GameManager.unregister_fort_block(b)
		b.queue_free()
	occupied_tiles.clear()
	GameManager.fort_blocks.clear()
	building_bonuses.clear()
	selected_units.clear()
	selected_building = null

	for key in gs.resources.keys():
		var pid := int(key)
		ResourceManager.wallets[pid] = _normalized_wallet(gs.resources[key])
	var restored_rates: Dictionary = settings.get("rates", {})
	var restored_base: Dictionary = settings.get("base_rates", restored_rates)
	var restored_eff: Dictionary = settings.get("power_efficiency", {})
	for key in restored_base.keys():
		var pid2 := int(key)
		if not ResourceManager.wallets.has(pid2):
			ResourceManager.init_player(pid2)
		ResourceManager.base_rates[pid2] = _normalized_wallet(restored_base[key])
		ResourceManager.power_efficiency[pid2] = clampf(float(restored_eff.get(key, 1.0)), 0.0, 1.0)
		ResourceManager.refresh_rates(pid2)
	for key in settings.get("caps", {}).keys():
		ResourceManager.caps[int(key)] = int(settings["caps"][key])

	var saved_teams: Array = []
	for value in settings.get("teams", GameManager.teams):
		var saved_team := Alliance.team_id(value)
		if saved_team >= 0:
			saved_teams.append(saved_team)
	GameManager.set_diplomacy_state(
		settings.get("alliances", {}),
		settings.get("alliance_proposals", {}),
		saved_teams if not saved_teams.is_empty() else GameManager.teams,
	)
	GameManager.match_mode = clampi(int(settings.get("match_mode", GameManager.match_mode)), 0, 3)
	GameManager.is_spectator = bool(settings.get("is_spectator", false))
	GameManager.local_team = clampi(int(settings.get("local_team", GameManager.local_team)), -1, 7)
	GameManager.ai_enabled = bool(settings.get("ai_enabled", false))
	GameManager.ai_teams = []
	for value in settings.get("ai_teams", []):
		var ai_team := Alliance.team_id(value)
		if ai_team >= 0 and not GameManager.ai_teams.has(ai_team):
			GameManager.ai_teams.append(ai_team)
	GameManager.team_factions = {}
	for key in (settings.get("team_factions", {}) as Dictionary).keys():
		var fac_team := Alliance.team_id(key)
		if fac_team >= 0:
			var max_fac := 7 if (GameManager.ai_enabled and GameManager.ai_teams.has(fac_team)) else 3
			GameManager.team_factions[fac_team] = clampi(int((settings["team_factions"] as Dictionary)[key]), 0, max_fac)
	GameManager.team_difficulties = {}
	for key in (settings.get("team_difficulties", {}) as Dictionary).keys():
		var diff_team := Alliance.team_id(key)
		if diff_team >= 0:
			GameManager.team_difficulties[diff_team] = clampi(int((settings["team_difficulties"] as Dictionary)[key]), 0, 2)
	if not GameManager.team_factions.is_empty():
		GameManager.player_faction = GameManager.team_factions.get(0, GameManager.player_faction)
		GameManager.ai_faction = GameManager.team_factions.get(1, GameManager.ai_faction)
	ai_states.clear()

	team_unlocked_tech.clear()
	for value in GameManager.teams:
		team_unlocked_tech[int(value)] = []
	for key in sg.settings.get("tech", {}).keys():
		var list: Array = []
		for node_id in sg.settings["tech"][key]:
			list.append(str(node_id))
		team_unlocked_tech[int(key)] = list

	for rec in gs.units:
		var uid := str(rec.get("id", ""))
		if not GameManager.registry.has_unit(uid):
			continue
		var u := _spawn_unit_by_id(uid, Vector2(float(rec.get("x", 0)), float(rec.get("y", 0))), int(rec.get("team", 0)))
		var max_u_fac := 7 if GameManager.is_ai_team(int(u.team)) else 3
		u.faction = clampi(int(rec.get("faction", u.faction)), 0, max_u_fac)
		u.hp = clampi(int(rec.get("hp", u.hp)), 1, u.effective_max_hp())
		u.net_id = int(rec.get("net_id", 0))
	for rec in gs.buildings:
		var bid := str(rec.get("id", ""))
		if not GameManager.registry.has_building(bid):
			continue
		var pos := Vector2(float(rec.get("x", 0)), float(rec.get("y", 0)))
		var b := _spawn_building_by_id(bid, pos, int(rec.get("team", 0)))
		b.hp = clampi(int(rec.get("hp", b.hp)), 1, b.stats.hp)
		b.production_queue = (rec.get("queue", []) as Array).duplicate(true)
		b.rally_point = Vector2(float(rec.get("rally_x", pos.x)), float(rec.get("rally_y", pos.y)))
		b.has_rally = bool(rec.get("has_rally", false))
		if b.has_method("_refresh_queue_label"):
			b._refresh_queue_label()
		var origin := Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))
		Placement.occupy(occupied_tiles, b.stats.footprint, origin)
	# Base rates in the save already include these bonuses; re-track them so a
	# later demolition revokes exactly what was restored.
	_rebuild_building_bonuses()

	var saved_deposits: Array = sg.settings.get("deposits", [])
	for i in range(mini(saved_deposits.size(), resource_deposits.size())):
		(resource_deposits[i]["deposit"] as ResourceDeposit).amount = maxi(0, int(saved_deposits[i]))

	elapsed_time = float(sg.settings.get("elapsed_time", 0.0))
	match_duration = float(sg.settings.get("match_duration", 0.0))
	player_tech_tier = int(sg.settings.get("player_tech_tier", 1))
	ai_tech_tier = int(sg.settings.get("ai_tech_tier", 1))
	GameManager.match_seed = int(sg.settings.get("match_seed", GameManager.match_seed))
	sonar_buoys.clear()
	sonar_cooldowns.clear()
	for raw_buoy in sg.settings.get("sonar_buoys", []):
		if not (raw_buoy is Dictionary):
			continue
		var rec := raw_buoy as Dictionary
		var deployed_at := float(rec.get("deployed_at", elapsed_time))
		var buoy := SonarBuoy.make(
			int(rec.get("owner_team", 0)), int(rec.get("owner_id", 0)),
			Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0))), deployed_at,
		)
		if rec.has("expires_at"):
			buoy["expires_at"] = float(rec["expires_at"])
		if SonarBuoy.is_active(buoy, elapsed_time):
			sonar_buoys.append(buoy)
			var ready_at := deployed_at + SonarBuoy.COOLDOWN_SEC
			if ready_at > elapsed_time:
				sonar_cooldowns[int(buoy["owner_id"])] = ready_at
	_init_team_fogs()
	_rebuild_spatial_grid()
	queue_redraw()
	var hq := _find_team_hq(GameManager.local_team)
	if hq != null and camera != null:
		camera.position = _clamp_camera(hq.global_position)
	if is_instance_valid(status_label):
		status_label.text = "Loaded save (tick %d, %d units, %d buildings)" % [gs.tick, gs.units.size(), gs.buildings.size()]
	return true

func _process(delta):
	elapsed_time += delta
	_rebuild_spatial_grid()
	laser_cooldown = maxf(0.0, laser_cooldown - delta)
	nuke_cooldown = maxf(0.0, nuke_cooldown - delta)
	for tid in laser_cooldowns.keys():
		var rem: float = float(laser_cooldowns[tid]) - delta
		if rem <= 0.0:
			laser_cooldowns.erase(tid)
		else:
			laser_cooldowns[tid] = rem
	for tid in nuke_cooldowns.keys():
		var rem_n: float = float(nuke_cooldowns[tid]) - delta
		if rem_n <= 0.0:
			nuke_cooldowns.erase(tid)
		else:
			nuke_cooldowns[tid] = rem_n
	var local_t := maxi(0, GameManager.local_team)
	if laser_cooldowns.has(local_t):
		laser_cooldown = float(laser_cooldowns[local_t])
	if nuke_cooldowns.has(local_t):
		nuke_cooldown = float(nuke_cooldowns[local_t])
	_cleanup_sonar_buoys()

	for i in range(active_vfx.size() - 1, -1, -1):
		active_vfx[i]["timer"] = float(active_vfx[i]["timer"]) - delta
		if float(active_vfx[i]["timer"]) <= 0.0:
			active_vfx.remove_at(i)

	for i in range(active_tracers.size() - 1, -1, -1):
		active_tracers[i]["timer"] = float(active_tracers[i]["timer"]) - delta
		if float(active_tracers[i]["timer"]) <= 0.0:
			active_tracers.remove_at(i)

	_update_wildlife(delta)
	if map_data != null:
		Cover.step_clouds(GameManager.active_clouds, float(map_data.width) * TILE_SIZE, float(map_data.height) * TILE_SIZE, delta)
	for i in range(tactical_pings.size() - 1, -1, -1):
		tactical_pings[i]["timer"] = float(tactical_pings[i]["timer"]) - delta
		if float(tactical_pings[i]["timer"]) <= 0.0:
			tactical_pings.remove_at(i)
	queue_redraw()

	# Prune destroyed units from live selection so stale references never accumulate.
	for i in range(selected_units.size() - 1, -1, -1):
		var su = selected_units[i]
		if not is_instance_valid(su) or su.is_exploding:
			selected_units.remove_at(i)
	if selected_building != null and (not is_instance_valid(selected_building) or selected_building.is_exploding):
		selected_building = null

	if bark_subtitle_timer > 0.0:
		bark_subtitle_timer = maxf(0.0, bark_subtitle_timer - delta)
		if bark_subtitle_timer <= 0.0 and is_instance_valid(bark_subtitle_label):
			bark_subtitle_label.visible = false

	# Periodic lockstep state checksum broadcast in P2P matches.
	if NetworkManager.is_network_match():
		_checksum_timer += delta
		if _checksum_timer >= 3.0:
			_checksum_timer = 0.0
			last_state_checksum = compute_match_checksum()
			NetworkManager.broadcast_hash(last_state_checksum)

	# Economy 1s tick
	economy_timer += delta
	if economy_timer >= 1.0:
		ResourceManager.tick(1.0)
		_harvest_deposits(1.0)
		_tick_power()
		economy_timer -= 1.0

	# Host-driven AI tick: single player, co-op and local AI-vs-AI spectator.
	var ai_authority := not NetworkManager.is_network_match() or NetworkManager.is_host()
	if not match_over and ai_authority and GameManager.ai_enabled and not GameManager.ai_teams.is_empty():
		ai_timer += delta
		var interval := AI.decision_interval(GameManager.ai_difficulty)
		if ai_timer >= interval:
			ai_timer = 0.0
			_run_skirmish_ai_turn()

	# Hovercraft eel hazard
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.stats and u.stats.id == "hovercraft":
			if u.eel_timer <= 0.0 and randf() < 0.0008:
				u.trigger_eels()
				if is_instance_valid(status_label):
					status_label.text = "My Hovercraft is full of eels!"
				AudioManager.play_bark("eel_hazard", GameManager.faction_for_team(int(u.team)))
	_update_fog()
	_update_hud()
	_check_win()
	var pan = Vector2.ZERO
	if Input.is_key_pressed(SettingsManager.hotkey("camera_up")) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_down")) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_left")) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(SettingsManager.hotkey("camera_right")) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	camera.position += pan * float(SettingsManager.get_setting("camera_speed", 420.0)) * delta
	camera.position = _clamp_camera(camera.position)

## One decision tick for every AI side. Co-op and spectator use the same
## per-team path; single player simply has one AI team (team 1).
func _run_skirmish_ai_turn() -> void:
	for value in GameManager.ai_teams.duplicate():
		var team := int(value)
		if GameManager.is_ai_team(team):
			_run_ai_turn_for_team(team)

func _visible_enemy_buildings(team: int) -> Array:
	var knowledge_fog: FogOfWar = fog
	if GameManager.is_ai_team(team):
		knowledge_fog = _refresh_team_fog(team)
	var out: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or ("is_exploding" in b and b.is_exploding):
			continue
		if int(b.team) == team or GameManager.is_allied(team, int(b.team)):
			continue
		if _node_visible_to_team(team, b, knowledge_fog):
			out.append(b)
	return out

func _team_available_producers(team: int) -> Array:
	var out: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and int(b.team) == team and b.stats != null:
			if b.has_method("enqueue_unit") and not out.has(String(b.stats.id)):
				out.append(String(b.stats.id))
	return out

func _map_has_water_near(anchor: Vector2, radius_tiles: int = 28) -> bool:
	if map_data == null:
		return false
	var cx := clampi(int(anchor.x / TILE_SIZE), 0, map_data.width - 1)
	var cy := clampi(int(anchor.y / TILE_SIZE), 0, map_data.height - 1)
	var min_x := maxi(0, cx - radius_tiles)
	var max_x := mini(map_data.width - 1, cx + radius_tiles)
	var min_y := maxi(0, cy - radius_tiles)
	var max_y := mini(map_data.height - 1, cy + radius_tiles)
	for ty in range(min_y, max_y + 1, 2):
		for tx in range(min_x, max_x + 1, 2):
			var t := map_data.get_terrain(tx, ty)
			if t == MapData.Terrain.SEA or t == MapData.Terrain.RIVER:
				return true
	return false

func _find_unclaimed_deposit_pos(_team: int, anchor: Vector2, visible_enemies: Array) -> Vector2:
	var best_pos := Vector2.INF
	var best_dist := INF
	for rd in resource_deposits:
		var dep: ResourceDeposit = rd.get("deposit", null)
		if dep == null or dep.is_depleted():
			continue
		var pos: Vector2 = rd.get("pos", Vector2.INF)
		if pos == Vector2.INF:
			continue
		# Skip deposits already harvested by any extractor.
		var claimed := false
		for b in get_tree().get_nodes_in_group("buildings"):
			if is_instance_valid(b) and not b.is_exploding and b.stats != null and b.stats.id == "extractor":
				if b.global_position.distance_to(pos) <= 112.0:
					claimed = true
					break
		if claimed:
			continue
		# Avoid walking into an actively contested deposit with visible hostiles on it.
		var contested := false
		for eu in visible_enemies:
			if is_instance_valid(eu) and eu.global_position.distance_to(pos) <= 180.0:
				contested = true
				break
		if contested:
			continue
		var d := anchor.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best_pos = pos
	return best_pos

func _build_ai_structure(ai_team: int, bid: String, ai_base_pos: Vector2, enemy_units: Array) -> bool:
	if bid == "extractor":
		var bs := GameManager.registry.get_building("extractor")
		var dep_pos := _find_unclaimed_deposit_pos(ai_team, ai_base_pos, enemy_units)
		if bs != null and dep_pos != Vector2.INF:
			var tile := _find_free_build_tile(ai_team, "extractor", bs.footprint, dep_pos, 1, 6)
			if tile.x >= 0 and tile.y >= 0:
				var world_pos := Vector2(
					float(tile.x) + float(bs.footprint.x) * 0.5,
					float(tile.y) + float(bs.footprint.y) * 0.5
				) * TILE_SIZE
				if _issue_ai_command(ai_team, {
					"type": "build", "id": "extractor",
					"x": clampf(world_pos.x, 0.0, NetSecurity.MAX_COORD),
					"y": clampf(world_pos.y, 0.0, NetSecurity.MAX_COORD),
				}):
					return true
	return _issue_ai_command(ai_team, {"type": "build", "id": bid})

func _build_target_entries(enemy_units: Array, enemy_buildings: Array) -> Array:
	var entries: Array = []
	for eu in enemy_units:
		if not is_instance_valid(eu) or eu.is_exploding or eu.stats == null:
			continue
		var max_hp: float = float(eu.effective_max_hp()) if eu.has_method("effective_max_hp") else float(eu.stats.hp)
		var threat: float = AI.unit_combat_power(max_hp, float(eu.stats.base_damage), float(eu.stats.range_px), int(eu.stats.unit_class))
		entries.append({
			"node": eu,
			"id": String(eu.stats.id),
			"pos": eu.global_position,
			"hp": float(eu.hp),
			"max_hp": max_hp,
			"armor_class": int(eu.stats.armor_class),
			"unit_class": int(eu.stats.unit_class),
			"is_building": false,
			"is_hq": false,
			"is_production": false,
			"is_economy": false,
			"is_defense": false,
			"threat": threat,
		})
	for eb in enemy_buildings:
		if not is_instance_valid(eb) or eb.is_exploding or eb.stats == null:
			continue
		var bid := String(eb.stats.id)
		var b_threat := 65.0 if bid in AI.DEFENSE_BUILDINGS else (55.0 if eb.stats.is_hq else 30.0)
		entries.append({
			"node": eb,
			"id": bid,
			"pos": eb.global_position,
			"hp": float(eb.hp),
			"max_hp": float(eb.stats.hp),
			"armor_class": Damage.ArmorClass.STRUCTURE,
			"unit_class": 0,
			"is_building": true,
			"is_hq": bool(eb.stats.is_hq),
			"is_production": UnitRegistry.is_production_building(bid),
			"is_economy": bid in AI.ECONOMY_BUILDINGS,
			"is_defense": bid in AI.DEFENSE_BUILDINGS,
			"threat": b_threat,
		})
	return entries

func _issue_ai_move(ai_team: int, unit_ids: Array, target: Vector2, attack_move: bool) -> bool:
	if unit_ids.is_empty():
		return false
	return _issue_ai_command(ai_team, {
		"type": "move", "unit_ids": unit_ids,
		"target_x": clampf(target.x, 0.0, NetSecurity.MAX_COORD),
		"target_y": clampf(target.y, 0.0, NetSecurity.MAX_COORD),
		"attack_move": attack_move,
	})

func _collect_ready_ids(units: Array, state: Dictionary, difficulty: int, force: bool) -> Array:
	var ids: Array = []
	var order_until: Dictionary = state["order_until"]
	for u in units:
		var key := int(u.get_instance_id())
		if not force and elapsed_time < float(order_until.get(key, 0.0)):
			continue
		ids.append(int(u.net_id))
		order_until[key] = elapsed_time + AI.order_interval(difficulty)
	return ids

func _group_centroid(units: Array, fallback: Vector2) -> Vector2:
	if units.is_empty():
		return fallback
	var sum := Vector2.ZERO
	for u in units:
		sum += u.global_position
	return sum / float(units.size())

func _run_ai_worker_tactics(
	ai_team: int, workers: Array, ai_base_pos: Vector2, enemy_hint_pos: Vector2,
	enemy_buildings: Array, enemy_units: Array, enemy_comp: Dictionary,
	b_counts: Dictionary, ai_fac: int, difficulty: int, state: Dictionary
) -> void:
	if workers.is_empty() or difficulty < AI.Difficulty.NORMAL:
		return
	var order_until: Dictionary = state["order_until"]
	# 1. Opportunistically capture visible damaged enemy production buildings.
	for eb in enemy_buildings:
		if not is_instance_valid(eb) or eb.is_exploding or eb.stats == null:
			continue
		if not UnitRegistry.is_production_building(String(eb.stats.id)):
			continue
		if eb.hp > int(float(eb.stats.hp) * 0.5):
			continue
		var best_w: Node2D = null
		var best_d := 560.0
		for w in workers:
			var d: float = w.global_position.distance_to(eb.global_position)
			if d < best_d:
				best_d = d
				best_w = w
		if best_w != null:
			var wkey := int(best_w.get_instance_id())
			if elapsed_time >= float(order_until.get(wkey, 0.0)):
				if _issue_ai_command(ai_team, {
					"type": "capture", "unit_ids": [int(best_w.net_id)],
					"target_x": clampf(eb.global_position.x, 0.0, NetSecurity.MAX_COORD),
					"target_y": clampf(eb.global_position.y, 0.0, NetSecurity.MAX_COORD),
				}):
					order_until[wkey] = elapsed_time + AI.order_interval(difficulty) * 1.5
				return

	# 2. Repair damaged friendly structures near base.
	var repair_target: Node2D = null
	var lowest_ratio := 0.90
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.is_exploding or int(b.team) != ai_team or b.stats == null:
			continue
		var ratio := float(b.hp) / maxf(1.0, float(b.stats.hp))
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			repair_target = b
	if repair_target != null:
		var w_ids := _collect_ready_ids(workers, state, difficulty, false)
		_issue_ai_move(ai_team, w_ids, repair_target.global_position + Vector2(28, 0), false)
		return

	# 3. Construct forward perimeter fortifications (Hard, or FerroCore on Normal).
	var wants_fort := difficulty >= AI.Difficulty.HARD or ai_fac == Faction.Id.FERROCORE
	if wants_fort and elapsed_time >= 40.0 and enemy_units.is_empty():
		var fort_id := "missile_tower" if int(enemy_comp.get("air", 0)) >= 1 else str(AI.doctrine(ai_fac).get("fortify_pref", "missile_tower"))
		var existing_forts := int(b_counts.get("missile_tower", 0)) + int(b_counts.get("wall", 0))
		if existing_forts < 2:
			var site := AI.choose_fortification_site(map_data, ai_base_pos, enemy_hint_pos, occupied_tiles, fort_id)
			if site != Vector2.INF:
				var sapper: Node2D = workers[0]
				if sapper.global_position.distance_to(site) <= 92.0:
					_issue_ai_command(ai_team, {
						"type": "fortify", "id": fort_id,
						"target_x": clampf(site.x, 0.0, NetSecurity.MAX_COORD),
						"target_y": clampf(site.y, 0.0, NetSecurity.MAX_COORD),
					})
				else:
					var w_ids := _collect_ready_ids([sapper], state, difficulty, false)
					_issue_ai_move(ai_team, w_ids, site, false)

func _run_ai_strategic_weapons(
	ai_team: int, difficulty: int, enemy_units: Array, enemy_buildings: Array, state: Dictionary
) -> void:
	if difficulty < AI.Difficulty.NORMAL or not team_has_tech(ai_team, "strategic_uplinks"):
		return
	if elapsed_time < float(state.get("next_strategic_time", 0.0)):
		return
	var strike_entries: Array = []
	for eu in enemy_units:
		if not is_instance_valid(eu) or eu.is_exploding or eu.stats == null:
			continue
		var val := AI.unit_combat_power(float(eu.hp), float(eu.stats.base_damage), float(eu.stats.range_px), int(eu.stats.unit_class))
		strike_entries.append({"pos": eu.global_position, "value": val})
	for eb in enemy_buildings:
		if not is_instance_valid(eb) or eb.is_exploding or eb.stats == null:
			continue
		var bid := String(eb.stats.id)
		var val := 500.0 if eb.stats.is_hq else (260.0 if UnitRegistry.is_production_building(bid) else (180.0 if bid in AI.DEFENSE_BUILDINGS else 140.0))
		strike_entries.append({"pos": eb.global_position, "value": val})
	if strike_entries.is_empty():
		return
	if difficulty >= AI.Difficulty.HARD and _team_nuke_cooldown(ai_team) <= 0.0:
		var nuke_pos := AI.choose_strategic_strike_target(strike_entries, 180.0, 480.0)
		if nuke_pos != Vector2.INF:
			if _issue_ai_command(ai_team, {
				"type": "nuke",
				"x": clampf(nuke_pos.x, 0.0, NetSecurity.MAX_COORD),
				"y": clampf(nuke_pos.y, 0.0, NetSecurity.MAX_COORD),
			}):
				state["next_strategic_time"] = elapsed_time + 12.0
				return
	if _team_laser_cooldown(ai_team) <= 0.0:
		var laser_pos := AI.choose_strategic_strike_target(strike_entries, 95.0, 240.0)
		if laser_pos != Vector2.INF:
			if _issue_ai_command(ai_team, {
				"type": "laser",
				"x": clampf(laser_pos.x, 0.0, NetSecurity.MAX_COORD),
				"y": clampf(laser_pos.y, 0.0, NetSecurity.MAX_COORD),
			}):
				state["next_strategic_time"] = elapsed_time + 10.0

func _run_ai_turn_for_team(ai_team: int) -> void:
	var state := _ai_state(ai_team)
	var difficulty := GameManager.difficulty_for_team(ai_team)
	var spectator: bool = GameManager.is_spectator
	var ai_wallet := ResourceManager.get_wallet(ai_team)
	var b_counts := _get_team_building_counts(ai_team)
	var ai_units := _get_team_units(ai_team)
	# Enemy knowledge comes strictly from this side's own fog, never spectator vision.
	var enemy_units := _visible_enemy_units(ai_team)
	var enemy_buildings := _visible_enemy_buildings(ai_team)
	var pop_cap := int(ResourceManager.caps.get(ai_team, 20))
	var ai_fac := GameManager.faction_for_team(ai_team)
	var doctrine_cfg := AI.doctrine(ai_fac)
	var world_size := _map_world_size()

	var ai_hq := _find_team_hq(ai_team)
	var fallback_base := Vector2(1100, 900) if ai_team == 1 else Vector2(160, 160)
	var ai_base_pos := ai_hq.global_position if ai_hq != null else fallback_base
	var has_water := _map_has_water_near(ai_base_pos)

	var enemy_comp := _classify_units(enemy_units)
	var visible_forts := 0
	for eb in enemy_buildings:
		if is_instance_valid(eb) and eb.stats != null and (String(eb.stats.id) in AI.DEFENSE_BUILDINGS or String(eb.stats.id) == "wall"):
			visible_forts += 1
	enemy_comp["fortifications"] = visible_forts

	# 1. Power-aware, deposit-targeted, threat-reactive base expansion.
	var power_bal := float(get_team_power_summary(ai_team).get("balance", 0.0))
	var next_bld := AI.select_next_building(
		b_counts, ai_units.size(), pop_cap, ai_fac, power_bal, enemy_comp, has_water, int(state["tech_tier"])
	)
	if elapsed_time >= float(state["next_build_time"]) \
			and AI.should_expand(float(ResourceManager.rates[ai_team].get(Economy.Res.IRON, 0)), 10.0):
		var built := _build_ai_structure(ai_team, next_bld, ai_base_pos, enemy_units)
		if not built:
			var fallback_bld := AI.select_next_building(
				b_counts, ai_units.size(), pop_cap, -1, power_bal, enemy_comp, false, int(state["tech_tier"])
			)
			if fallback_bld != next_bld:
				built = _build_ai_structure(ai_team, fallback_bld, ai_base_pos, enemy_units)
		if built:
			state["next_build_time"] = elapsed_time + AI.build_interval(difficulty)

	# 2. Doctrine-guided tech progression (Easy caps at T2; Normal/Hard climb to T4).
	var unlocked: Array = team_unlocked_tech.get(ai_team, [])
	var available := Tech.available_nodes(unlocked)
	var max_tier := 2 if difficulty == AI.Difficulty.EASY else 4
	var tier_pace := 18.0 if difficulty == AI.Difficulty.HARD else 24.0
	if int(state["tech_tier"]) < max_tier and elapsed_time > tier_pace * float(state["tech_tier"]) and not available.is_empty():
		var tech_id := AI.choose_tech_node(available, ai_fac, enemy_comp)
		if not tech_id.is_empty() and _issue_ai_command(ai_team, {"type": "tech", "id": tech_id}):
			state["tech_tier"] = mini(4, int(state["tech_tier"]) + 1)

	# 3. Producer-aware counter-production (with dual-queue macro on Hard).
	var own_comp := _classify_units(ai_units)
	var producers := _team_available_producers(ai_team)
	var chosen_uid := AI.choose_production_unit(ai_wallet, enemy_comp, int(state["tech_tier"]), ai_fac, own_comp, producers)
	if elapsed_time >= float(state["next_train_time"]):
		var trained := _issue_ai_command(ai_team, {"type": "train", "id": chosen_uid})
		if not trained:
			var fallback_uid := AI.choose_production_unit(ai_wallet, enemy_comp, int(state["tech_tier"]), -1, own_comp, producers)
			if fallback_uid != chosen_uid:
				trained = _issue_ai_command(ai_team, {"type": "train", "id": fallback_uid})
		if trained:
			# Hard AI leverages parallel production across distinct factories when wealthy.
			if difficulty >= AI.Difficulty.HARD and producers.size() >= 2 \
					and int(ai_wallet.get(Economy.Res.IRON, 0)) >= 280:
				var used_prods := UnitRegistry.producer_ids_for_unit(chosen_uid, Faction.unit_class_for_id(chosen_uid))
				var alt_producers: Array = []
				for pid in producers:
					if not used_prods.has(pid):
						alt_producers.append(pid)
				if not alt_producers.is_empty():
					var second_uid := AI.choose_production_unit(
						ai_wallet, enemy_comp, int(state["tech_tier"]), ai_fac, own_comp, alt_producers
					)
					_issue_ai_command(ai_team, {"type": "train", "id": second_uid})
			state["next_train_time"] = elapsed_time + AI.train_interval(difficulty)

	# 4. Base & perimeter threat scan (protects HQ and all friendly structures).
	var friendly_buildings: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and int(b.team) == ai_team:
			friendly_buildings.append(b)

	var enemy_near_base := 0
	var closest_intruder: Node2D = null
	var best_intruder_score := -INF
	var hq_under_attack := false
	for eu in enemy_units:
		var d_hq: float = eu.global_position.distance_to(ai_base_pos)
		var threatens := d_hq <= 340.0
		if d_hq <= 240.0:
			hq_under_attack = true
		if not threatens:
			for fb in friendly_buildings:
				if eu.global_position.distance_to(fb.global_position) <= 240.0:
					threatens = true
					break
		if threatens:
			enemy_near_base += 1
			var threat_val: float = float(eu.stats.base_damage if eu.stats else 12) * 4.0 - d_hq * 0.25
			if threat_val > best_intruder_score:
				best_intruder_score = threat_val
				closest_intruder = eu

	# 5. Partition friendly units by combined-arms role.
	var workers: Array = []
	var scouts: Array = []
	var combat_units: Array = []
	var naval_units: Array = []
	var anti_air_units: Array = []
	var standoff_units: Array = []
	var raider_units: Array = []
	var vanguard_units: Array = []
	var repair_positions: Array = []
	var own_power := 0.0

	for u in ai_units:
		if u.stats == null:
			continue
		var role := AI.unit_role(String(u.stats.id), int(u.stats.unit_class), float(u.stats.range_px), bool(u.stats.stealth))
		match role:
			"worker":
				workers.append(u)
				repair_positions.append(u.global_position)
			"scout":
				scouts.append(u)
			_:
				combat_units.append(u)
				own_power += AI.unit_combat_power(
					float(u.hp), float(u.stats.base_damage), float(u.stats.range_px), int(u.stats.unit_class)
				)
				match role:
					"naval": naval_units.append(u)
					"anti_air": anti_air_units.append(u)
					"standoff": standoff_units.append(u)
					"raider": raider_units.append(u)
					_: vanguard_units.append(u)

	var enemy_power := 0.0
	for eu in enemy_units:
		if is_instance_valid(eu) and eu.stats != null:
			enemy_power += AI.unit_combat_power(
				float(eu.hp), float(eu.stats.base_damage), float(eu.stats.range_px), int(eu.stats.unit_class)
			)
	for eb in enemy_buildings:
		if is_instance_valid(eb) and eb.stats != null and String(eb.stats.id) in AI.DEFENSE_BUILDINGS:
			enemy_power += 140.0

	# Drop stale cooldown keys for units that died since the previous tick.
	var live_keys: Dictionary = {}
	for u in ai_units:
		live_keys[int(u.get_instance_id())] = true
	for key in (state["retreat_until"] as Dictionary).keys():
		if not live_keys.has(key):
			(state["retreat_until"] as Dictionary).erase(key)
	for key in (state["order_until"] as Dictionary).keys():
		if not live_keys.has(key):
			(state["order_until"] as Dictionary).erase(key)

	var wave_size := AI.attack_wave_threshold(difficulty, elapsed_time / 60.0, spectator, ai_fac)
	if enemy_near_base == 0 and elapsed_time < AI.rally_grace(difficulty, spectator):
		state["tactical_state"] = "rally"
	else:
		state["tactical_state"] = AI.choose_tactical_state(
			combat_units.size(), enemy_near_base, wave_size, own_power, enemy_power, ai_fac, difficulty
		)

	# Maintain fog-compliant last-known enemy contact memory (45 s TTL).
	var squad_pos := _group_centroid(combat_units, ai_base_pos)
	var target := _find_nearest_visible_enemy(ai_team, squad_pos, 1100.0)
	var memory: Dictionary = state["last_known_enemy"]
	if target != null:
		memory["x"] = target.global_position.x
		memory["y"] = target.global_position.y
		memory["expires_at"] = elapsed_time + 45.0
	elif not memory.is_empty() and elapsed_time >= float(memory.get("expires_at", 0.0)):
		memory.clear()

	var known_enemy_pos := Vector2.INF
	if target != null:
		known_enemy_pos = target.global_position
	elif not memory.is_empty():
		known_enemy_pos = Vector2(float(memory["x"]), float(memory["y"]))
	var default_far := Vector2(
		world_size.x * (0.8 if ai_base_pos.x < world_size.x * 0.5 else 0.2),
		world_size.y * (0.8 if ai_base_pos.y < world_size.y * 0.5 else 0.2),
	)
	var enemy_hint_pos := known_enemy_pos if known_enemy_pos != Vector2.INF else default_far

	# 6. Multi-sector scouting (with damaged-scout preservation).
	if not scouts.is_empty() and elapsed_time >= float(state["scout_order_until"]):
		var deposit_positions: Array = []
		for rd in resource_deposits:
			var dep: ResourceDeposit = rd.get("deposit", null)
			if dep != null and not dep.is_depleted():
				deposit_positions.append(Vector2(rd.get("pos", Vector2.ZERO)))
		var waypoints := AI.scout_waypoints(ai_base_pos, world_size, deposit_positions, known_enemy_pos)
		var active_scouts: Array = []
		var hurt_scouts: Array = []
		for scout in scouts:
			var smax := float(scout.effective_max_hp()) if scout.has_method("effective_max_hp") else float(scout.stats.hp)
			if float(scout.hp) / maxf(1.0, smax) < 0.40:
				hurt_scouts.append(int(scout.net_id))
			else:
				active_scouts.append(int(scout.net_id))
		var sent := false
		if not active_scouts.is_empty():
			var wp_idx := int(elapsed_time / 20.0) % waypoints.size()
			sent = _issue_ai_move(ai_team, active_scouts, waypoints[wp_idx], false)
		if not hurt_scouts.is_empty():
			var retreat_pt := AI.choose_retreat_point(
				ai_base_pos, ai_base_pos, 3, repair_positions, GameManager.active_clouds, world_size
			)
			sent = _issue_ai_move(ai_team, hurt_scouts, retreat_pt, false) or sent
		if sent:
			state["scout_order_until"] = elapsed_time + AI.order_interval(difficulty) * 2.0

	# 7. Worker tactics: capture damaged enemy factories, repair allies, fortify perimeter.
	_run_ai_worker_tactics(
		ai_team, workers, ai_base_pos, enemy_hint_pos, enemy_buildings, enemy_units,
		enemy_comp, b_counts, ai_fac, difficulty, state
	)

	# 8. Separate wounded units for independent retreat (never overwrites healthy squads!).
	var retreat_ratio := float(doctrine_cfg.get("retreat_hp", 0.28)) if difficulty >= AI.Difficulty.NORMAL else 0.25
	var retreat_until: Dictionary = state["retreat_until"]
	var healthy_vanguard: Array = []
	var healthy_raiders: Array = []
	var healthy_standoff: Array = []
	var healthy_aa: Array = []
	var healthy_naval: Array = []
	var retreat_ground_ids: Array = []
	var retreat_air_ids: Array = []
	var retreat_air_anchor := ai_base_pos
	var retreat_ground_anchor := ai_base_pos

	for role_pair in [
		[vanguard_units, healthy_vanguard],
		[raider_units, healthy_raiders],
		[standoff_units, healthy_standoff],
		[anti_air_units, healthy_aa],
		[naval_units, healthy_naval],
	]:
		var src: Array = role_pair[0]
		var dst: Array = role_pair[1]
		for u in src:
			var max_hp := float(u.effective_max_hp()) if u.has_method("effective_max_hp") else float(u.stats.hp)
			var hp_ratio := float(u.hp) / maxf(1.0, max_hp)
			var rkey := int(u.get_instance_id())
			var allow_retreat := not hq_under_attack
			if allow_retreat and AI.retreat_threshold(hp_ratio, retreat_ratio):
				if elapsed_time >= float(retreat_until.get(rkey, 0.0)):
					retreat_until[rkey] = elapsed_time + 8.0
					if int(u.stats.unit_class) == 3:
						retreat_air_ids.append(int(u.net_id))
						retreat_air_anchor = u.global_position
					else:
						retreat_ground_ids.append(int(u.net_id))
						retreat_ground_anchor = u.global_position
				continue
			retreat_until.erase(rkey)
			dst.append(u)

	if not retreat_ground_ids.is_empty():
		var g_retreat := AI.choose_retreat_point(
			retreat_ground_anchor, ai_base_pos, 0, repair_positions, [], world_size
		)
		_issue_ai_move(ai_team, retreat_ground_ids, g_retreat, false)
	if not retreat_air_ids.is_empty():
		var clouds_for_retreat: Array = GameManager.active_clouds if (difficulty >= AI.Difficulty.NORMAL or bool(doctrine_cfg.get("prefer_clouds", false))) else []
		var a_retreat := AI.choose_retreat_point(
			retreat_air_anchor, ai_base_pos, 3, repair_positions, clouds_for_retreat, world_size
		)
		_issue_ai_move(ai_team, retreat_air_ids, a_retreat, false)

	# 9. Role-coordinated squad maneuvers (terrain rally, flanking, standoff, AA, naval).
	var tactical := str(state["tactical_state"])
	var target_entries := _build_target_entries(enemy_units, enemy_buildings)
	var rally_inf := AI.choose_tactical_rally(map_data, ai_base_pos, enemy_hint_pos, 0, world_size)
	var rally_veh := AI.choose_tactical_rally(map_data, ai_base_pos, enemy_hint_pos, 1, world_size)
	var rally_naval := AI.choose_tactical_rally(map_data, ai_base_pos, enemy_hint_pos, 2, world_size)
	var primary_target_pos := known_enemy_pos if known_enemy_pos != Vector2.INF else rally_inf
	var force_order := tactical == "defend"

	# 9a. Naval task force & corvette sonar buoys.
	if not healthy_naval.is_empty():
		var naval_center := _group_centroid(healthy_naval, ai_base_pos)
		var naval_goal := rally_naval
		var naval_am := true
		if tactical == "defend" and closest_intruder != null:
			naval_goal = closest_intruder.global_position
		elif tactical in ["attack", "harass"]:
			var best_naval := AI.choose_best_target({
				"id": "corvette", "role": "naval",
				"damage_type": Damage.DamageType.EXPLOSIVE, "range_px": 320.0, "pos": naval_center,
			}, target_entries)
			if not best_naval.is_empty():
				naval_goal = Vector2(best_naval["pos"])
			elif known_enemy_pos != Vector2.INF:
				naval_goal = known_enemy_pos
		else:
			naval_am = false
		var naval_ids := _collect_ready_ids(healthy_naval, state, difficulty, force_order)
		_issue_ai_move(ai_team, naval_ids, naval_goal, naval_am)
		if difficulty >= AI.Difficulty.NORMAL:
			for ship in healthy_naval:
				if ship.stats != null and UnitRegistry.can_deploy_sonar_buoy(String(ship.stats.id)):
					var buoy_pos := AI.should_deploy_sonar(
						ship.global_position, enemy_hint_pos, sonar_buoys, ai_team, enemy_comp
					)
					if buoy_pos != Vector2.INF:
						_issue_ai_command(ai_team, {
							"type": "sonar_buoy", "unit_ids": [int(ship.net_id)],
							"target_x": clampf(buoy_pos.x, 0.0, NetSecurity.MAX_COORD),
							"target_y": clampf(buoy_pos.y, 0.0, NetSecurity.MAX_COORD),
						})
						break

	# 9b. Anti-air detachment prioritizes enemy air wings, otherwise escorts vanguard.
	if not healthy_aa.is_empty():
		var aa_center := _group_centroid(healthy_aa, ai_base_pos)
		var aa_goal := rally_veh
		var aa_am := true
		var best_aa := AI.choose_best_target({
			"id": "aa_vehicle", "role": "anti_air",
			"damage_type": Damage.DamageType.KINETIC, "range_px": 300.0, "pos": aa_center,
		}, target_entries)
		if not best_aa.is_empty() and (int(best_aa.get("unit_class", 0)) == 3 or tactical in ["defend", "attack", "harass"]):
			aa_goal = Vector2(best_aa["pos"])
		elif tactical == "defend" and closest_intruder != null:
			aa_goal = closest_intruder.global_position
		elif tactical == "attack":
			aa_goal = primary_target_pos
		else:
			aa_am = false
		var aa_ids := _collect_ready_ids(healthy_aa, state, difficulty, force_order)
		_issue_ai_move(ai_team, aa_ids, aa_goal, aa_am)

	# 9c. Long-range standoff support (artillery, siege mechs, snipers) keeps range & kites.
	if not healthy_standoff.is_empty():
		var st_center := _group_centroid(healthy_standoff, ai_base_pos)
		var st_goal := rally_inf
		var st_am := true
		var best_st := AI.choose_best_target({
			"id": "artillery", "role": "standoff",
			"damage_type": Damage.DamageType.EXPLOSIVE, "range_px": 400.0, "pos": st_center,
		}, target_entries)
		if tactical == "defend" and closest_intruder != null:
			st_goal = AI.standoff_position(st_center, closest_intruder.global_position, 360.0, world_size)
		elif tactical in ["attack", "harass"] and not best_st.is_empty():
			var st_target_pos := Vector2(best_st["pos"])
			var avg_rng := 380.0
			if difficulty >= AI.Difficulty.NORMAL:
				st_goal = AI.standoff_position(st_center, st_target_pos, avg_rng, world_size)
				# Kite backward without stopping to fire if enemies closed inside half range.
				st_am = st_center.distance_to(st_target_pos) >= avg_rng * 0.55
			else:
				st_goal = st_target_pos
		elif tactical == "attack":
			st_goal = primary_target_pos
		else:
			st_am = false
		var st_ids := _collect_ready_ids(healthy_standoff, state, difficulty, force_order)
		_issue_ai_move(ai_team, st_ids, st_goal, st_am)

	# 9d. Fast raiders / stealth infiltrators / strike bombers execute flanking economy raids.
	if not healthy_raiders.is_empty():
		var r_center := _group_centroid(healthy_raiders, ai_base_pos)
		var r_goal := rally_inf
		var r_am := true
		match tactical:
			"defend":
				r_goal = closest_intruder.global_position if closest_intruder != null else ai_base_pos
			"attack", "harass":
				var best_raid := AI.choose_best_target({
					"id": "stealthbot", "role": "raider",
					"damage_type": Damage.DamageType.ENERGY, "range_px": 220.0, "pos": r_center,
				}, target_entries)
				var raid_target := Vector2(best_raid["pos"]) if not best_raid.is_empty() else primary_target_pos
				if difficulty >= AI.Difficulty.NORMAL and r_center.distance_to(raid_target) > 320.0:
					var flank_side := 1 if (int(elapsed_time / 35.0) + ai_team) % 2 == 0 else -1
					r_goal = AI.flank_waypoint(r_center, raid_target, world_size, flank_side, 240.0)
				else:
					r_goal = raid_target
			_:
				r_am = false
		var r_ids := _collect_ready_ids(healthy_raiders, state, difficulty, force_order)
		_issue_ai_move(ai_team, r_ids, r_goal, r_am)

	# 9e. Main vanguard pushes prioritized primary target or holds cover-rich rally.
	if not healthy_vanguard.is_empty():
		var v_center := _group_centroid(healthy_vanguard, ai_base_pos)
		var v_goal := rally_inf
		var v_am := true
		match tactical:
			"defend":
				v_goal = closest_intruder.global_position if closest_intruder != null else ai_base_pos
			"attack":
				var best_v := AI.choose_best_target({
					"id": "mbt", "role": "vanguard",
					"damage_type": Damage.DamageType.EXPLOSIVE, "range_px": 220.0, "pos": v_center,
				}, target_entries)
				v_goal = Vector2(best_v["pos"]) if not best_v.is_empty() else primary_target_pos
			"harass":
				# During harass, if raiders exist let raiders probe while vanguard pressures forward;
				# if no dedicated raiders exist, vanguard itself probes the contact point.
				if healthy_raiders.is_empty():
					v_goal = primary_target_pos
				else:
					v_goal = rally_inf.lerp(primary_target_pos, 0.45)
			"regroup":
				v_goal = rally_veh if own_comp.get("vehicle", 0) > own_comp.get("infantry", 0) else rally_inf
				v_am = false
			_:
				v_goal = rally_veh if own_comp.get("vehicle", 0) > own_comp.get("infantry", 0) else rally_inf
				v_am = false
		var v_ids := _collect_ready_ids(healthy_vanguard, state, difficulty, force_order)
		_issue_ai_move(ai_team, v_ids, v_goal, v_am)

	# 10. Late-game fog-compliant Orbital Laser / Nuclear strikes on high-value clusters.
	_run_ai_strategic_weapons(ai_team, difficulty, enemy_units, enemy_buildings, state)
	_sync_legacy_ai_state(ai_team, state)

## AI decisions always leave the host through the normal command pipeline so
## co-op peers receive the same builds, research and orders.
func _issue_ai_command(team: int, cmd: Dictionary) -> bool:
	ai_command_seq += 1
	var full := cmd.duplicate()
	full["team"] = team
	full["seq"] = ai_command_seq
	var clean := NetSecurity.sanitize_command(full)
	if clean.is_empty():
		return false
	if NetworkManager.is_network_match() and NetworkManager.is_host():
		return NetworkManager.apply_host_command(clean)
	return apply_command(clean, true)

func _ai_state(team: int) -> Dictionary:
	if ai_states.has(team):
		return ai_states[team]
	var state: Dictionary = {
		"tech_tier": 1,
		"tactical_state": "rally",
		"retreat_until": {},
		"next_build_time": 0.0,
		"next_train_time": 0.0,
		"next_strategic_time": 0.0,
		"order_until": {},
		"scout_order_until": 0.0,
		"last_known_enemy": {},
	}
	if team == 1:
		state["tech_tier"] = ai_tech_tier
		state["tactical_state"] = ai_tactical_state
		state["retreat_until"] = ai_retreat_until
		state["next_build_time"] = ai_next_build_time
		state["next_train_time"] = ai_next_train_time
		state["order_until"] = ai_order_until
	ai_states[team] = state
	return state

func _sync_legacy_ai_state(team: int, state: Dictionary) -> void:
	if team != 1:
		return
	ai_tech_tier = int(state["tech_tier"])
	ai_tactical_state = str(state["tactical_state"])
	ai_retreat_until = state["retreat_until"]
	ai_next_build_time = float(state["next_build_time"])
	ai_next_train_time = float(state["next_train_time"])
	ai_order_until = state["order_until"]

func _enemy_teams(team: int) -> Array:
	var out: Array = []
	for value in GameManager.teams:
		var other := int(value)
		if other != team and not GameManager.is_allied(team, other) and not out.has(other):
			out.append(other)
	return out

func _enemy_units(team: int) -> Array:
	var out: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and int(u.team) != team and not GameManager.is_allied(team, int(u.team)):
			out.append(u)
	return out

func _get_team_units(team: int) -> Array:
	var res: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.team == team:
			res.append(u)
	return res

func _classify_units(unit_list: Array) -> Dictionary:
	var counts := {
		"infantry": 0, "vehicle": 0, "naval": 0, "air": 0,
		"stealth": 0, "submerged": 0, "worker": 0, "scout": 0,
		"anti_air": 0, "siege": 0, "total": 0,
	}
	for u in unit_list:
		if not is_instance_valid(u) or u.stats == null:
			counts["infantry"] += 1
			counts["total"] += 1
			continue
		counts["total"] += 1
		var uid := String(u.stats.id)
		var uclass := int(u.stats.unit_class)
		match uclass:
			1, 7: counts["vehicle"] += 1
			2, 4: counts["naval"] += 1
			3: counts["air"] += 1
			_: counts["infantry"] += 1
		if bool(u.stats.stealth):
			counts["stealth"] += 1
		if int(u.stats.armor_class) == Damage.ArmorClass.SUBMERGED:
			counts["submerged"] += 1
		var role := AI.unit_role(uid, uclass, float(u.stats.range_px), bool(u.stats.stealth))
		if role == "worker":
			counts["worker"] += 1
		elif role == "scout":
			counts["scout"] += 1
		elif role == "anti_air":
			counts["anti_air"] += 1
		elif role == "standoff":
			counts["siege"] += 1
	return counts

func _get_team_building_counts(team: int) -> Dictionary:
	var d: Dictionary = {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats:
			var bid: String = b.stats.id
			d[bid] = int(d.get(bid, 0)) + 1
	return d

func _count_team_buildings(team: int, bid: String) -> int:
	return int(_get_team_building_counts(team).get(bid, 0))

## Live power grid: each building has a power delta (production/consumption);
## a deficit applies Power.efficiency() to that team's rates.
func _tick_power() -> void:
	for t in GameManager.teams:
		var bids := _get_team_building_ids(t)
		var summary := Power.team_power_summary(bids)
		var eff := Power.efficiency(float(summary["balance"]))
		ResourceManager.set_power_efficiency(t, eff)

## Spatial hash over unit positions for fast radius queries (Step 20).
## Positions and nodes stay index-aligned so callers receive actual units.
func _rebuild_spatial_grid() -> void:
	spatial_unit_positions.clear()
	spatial_unit_nodes.clear()
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding:
			spatial_unit_positions.append(u.global_position)
			spatial_unit_nodes.append(u)
	spatial_unit_grid = UnitVisual.build_spatial_grid(spatial_unit_positions)

## Units within `radius` of `center`, using the shared spatial grid. Combat,
## repair and turret callers ask for nodes; `_units_near` keeps the index API
## used by headless tests.
func units_near(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for i in UnitVisual.query_spatial_radius(spatial_unit_grid, spatial_unit_positions, center, radius):
		if i >= 0 and i < spatial_unit_nodes.size():
			out.append(spatial_unit_nodes[i])
	return out

func _units_near(center: Vector2, radius: float) -> Array[int]:
	var out: Array[int] = []
	for i in UnitVisual.query_spatial_radius(spatial_unit_grid, spatial_unit_positions, center, radius):
		out.append(i)
	return out

func _get_team_building_ids(team: int) -> Array:
	var out: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats:
			out.append(str(b.stats.id))
	return out

func _update_hud() -> void:
	if is_instance_valid(building_inspector):
		if GameManager.is_spectator or selected_building == null or not is_instance_valid(selected_building):
			building_inspector.inspect(null)
		else:
			building_inspector.inspect(selected_building, get_team_power_efficiency(int(selected_building.team)))
	if GameManager.is_spectator:
		if is_instance_valid(hud_label):
			hud_label.text = "SPECTATOR | Team 0 %s: %d units | Team 1 %s: %d units" % [
				Faction.name_of(GameManager.faction_for_team(0)), _get_team_units(0).size(),
				Faction.name_of(GameManager.faction_for_team(1)), _get_team_units(1).size(),
			]
		if is_instance_valid(ai_status_label):
			var s0 := _ai_state(0)
			var s1 := _ai_state(1)
			ai_status_label.text = "AI vs AI (%s) | VIEW ONLY | Posture: %s / %s | Tech: T%d / T%d" % [
				AI.difficulty_name(GameManager.ai_difficulty),
				str(s0["tactical_state"]).to_upper(), str(s1["tactical_state"]).to_upper(),
				int(s0["tech_tier"]), int(s1["tech_tier"]),
			]
		return
	if is_instance_valid(hud_label):
		var view_team := maxi(0, GameManager.local_team)
		var w := ResourceManager.get_wallet(view_team)
		var r: Dictionary = ResourceManager.rates.get(view_team, {})
		var p_units := _get_team_units(view_team).size()
		var p_cap := int(ResourceManager.caps.get(view_team, 20))
		var pwr := get_team_power_summary(view_team)
		var pwr_pct := int(round(float(pwr["efficiency"]) * 100.0))
		var view_tech := player_tech_tier if view_team == 0 else int(_ai_state(view_team)["tech_tier"])
		hud_label.text = "Corp: %s | Tech: T%d | Pwr: %+d (%d%%) | Oil: %d (+%d/s) | Iron: %d (+%d/s) | Geo: %d (+%d/s) | Food: %d | Units: %d/%d" % [
			Faction.name_of(GameManager.faction_for_team(view_team)),
			view_tech,
			int(round(float(pwr["balance"]))), pwr_pct,
			int(w.get(Economy.Res.OIL, 0)), int(r.get(Economy.Res.OIL, 0)),
			int(w.get(Economy.Res.IRON, 0)), int(r.get(Economy.Res.IRON, 0)),
			int(w.get(Economy.Res.GEOTHERMAL, 0)), int(r.get(Economy.Res.GEOTHERMAL, 0)),
			int(w.get(Economy.Res.FOOD, 0)),
			p_units, p_cap
		]
	if is_instance_valid(ai_status_label):
		var ai_units := _get_team_units(1).size()
		var mode_str := "Single Player vs %s AI (%s)" % [
			AI.difficulty_name(GameManager.ai_difficulty),
			Faction.name_of(GameManager.ai_faction),
		] if GameManager.match_mode == GameManager.Mode.SINGLE_PLAYER else (
			"Co-op vs %s AI (%s)" % [
				AI.difficulty_name(GameManager.difficulty_for_team(1)),
				Faction.name_of(GameManager.faction_for_team(1)),
			] if GameManager.ai_enabled else "Multiplayer P2P"
		)
		ai_status_label.text = "%s | AI Posture: %s | AI Units: %d | AI Tech: T%d" % [
			mode_str, ai_tactical_state.to_upper(), ai_units, ai_tech_tier
		]

func _alliance_side_key(team: int) -> String:
	var ids: Array[int] = [team]
	for other in GameManager.teams:
		var value := int(other)
		if GameManager.is_allied(team, value) and not ids.has(value):
			ids.append(value)
	ids.sort()
	var parts: Array[String] = []
	for value in ids:
		parts.append(str(value))
	return ",".join(parts)

func _side_members(key: String) -> Array[int]:
	var out: Array[int] = []
	for part in key.split(","):
		if not part.is_empty():
			out.append(int(part))
	return out

func _show_match_end(title: String, detail: String) -> void:
	match_duration = elapsed_time
	if victory_panel != null and is_instance_valid(victory_panel):
		var result := victory_panel.get_node_or_null("VBoxContainer/ResultLabel")
		var score := victory_panel.get_node_or_null("VBoxContainer/ScoreLabel")
		if result is Label:
			(result as Label).text = title
		if score is Label:
			(score as Label).text = detail
		victory_panel.visible = true
	if is_instance_valid(status_label):
		status_label.text = "%s | %s" % [title, detail]

func _check_win():
	if match_over:
		return
	# Production capacity decides the match; unit-only armies cannot rebuild.
	var production_ids := [
		# An HQ-only opening still counts as live production capacity. HQs
		# train engineers and are the primary victory target in a skirmish.
		"hq", "barracks", "factory", "airfield", "shipyard",
		"docks", "mech_factory_1", "mech_factory_2", "mech_factory_3",
		"advanced_shipyard", "aeries_1", "aeries_2",
	]
	var alive_sides: Dictionary = {}
	var all_sides: Dictionary = {}
	for team in GameManager.teams:
		all_sides[_alliance_side_key(int(team))] = true
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.stats and production_ids.has(b.stats.id):
			alive_sides[_alliance_side_key(int(b.team))] = true
	if alive_sides.size() == 1 and all_sides.size() > 1:
		var winning_side: String = alive_sides.keys()[0]
		var members := _side_members(winning_side)
		var winner := members[0] if not members.is_empty() else 0
		var s := _team_score(winner)
		var local_won := _alliance_side_key(GameManager.local_team) == winning_side
		var title := "Team %s" % winning_side
		if GameManager.is_spectator:
			title = "SPECTATOR — " + title
		else:
			title = ("VICTORY — " if local_won else "DEFEAT — ") + title
		var detail := "Score %d (Military %d + Economy %d) | Units %d | Buildings %d | Duration %.1fs" % [
			int(s["total"]), int(s["military"]), int(s["economic"]),
			_get_team_units(winner).size(), _team_building_total(winner), elapsed_time,
		]
		_show_match_end(title, detail)
		if not GameManager.is_spectator:
			AudioManager.play_bark(
				"victory" if local_won else "defeat",
				GameManager.faction_for_team(GameManager.local_team),
			)
		match_over = true
		GameManager.end_match(winner)
	elif alive_sides.is_empty() and all_sides.size() > 1:
		_show_match_end("DRAW", "All production capacity destroyed | Duration %.1fs" % elapsed_time)
		match_over = true
		GameManager.end_match(-1)

func _draw():
	# Minimal forest tree canopies and shrubs
	for dec in forest_decorations:
		if String(dec.get("kind", "")) == "tree":
			continue  # tree canopies are batch-rendered by forest_multimesh
		var dpos: Vector2 = dec["pos"]
		var rad := float(dec["radius"])
		var shade := float(dec["shade"])
		draw_circle(dpos + Vector2(2, 2), rad, Color(0.04, 0.08, 0.04, 0.42))
		if dec["kind"] == "tree":
			draw_circle(dpos, rad, Color(0.12 + shade, 0.34 + shade, 0.14 + shade, 0.92))
			draw_circle(dpos - Vector2(1.5, 1.5), rad * 0.58, Color(0.22 + shade, 0.48 + shade, 0.22 + shade, 0.95))
		else:
			draw_circle(dpos, rad, Color(0.18 + shade, 0.40 + shade, 0.17 + shade, 0.88))

	# On-map finite resource deposits
	for rd in resource_deposits:
		var dep: ResourceDeposit = rd["deposit"]
		if dep.is_depleted():
			continue
		var rpos: Vector2 = rd["pos"]
		var rcol := Color(0.15, 0.15, 0.15, 0.9)
		match dep.type:
			Economy.Res.IRON: rcol = Color(0.65, 0.72, 0.85, 0.9)
			Economy.Res.GEOTHERMAL: rcol = Color(1.0, 0.45, 0.15, 0.9)
			Economy.Res.FOOD: rcol = Color(0.35, 0.85, 0.35, 0.9)
		draw_circle(rpos, 8.0, rcol)
		draw_arc(rpos, 10.0, 0, TAU, 16, rcol.lightened(0.3), 1.5)

	# Scorch marks from blown-up units and buildings
	for s in scorch_marks:
		draw_circle(s["pos"], float(s["radius"]), Color(0.1, 0.09, 0.08, float(s["alpha"])))

	# Active sonar buoys: the deploying side sees the sweep; rivals do not.
	for buoy in sonar_buoys:
		var buoy_owner := int(buoy.get("owner_team", -1))
		if not GameManager.is_spectator and not GameManager.is_allied(GameManager.local_team, buoy_owner):
			continue
		var bpos: Vector2 = buoy.get("pos", Vector2.ZERO)
		var life := clampf(
			(float(buoy.get("expires_at", 0.0)) - elapsed_time) / SonarBuoy.LIFETIME_SEC, 0.0, 1.0
		)
		var bcol := Faction.colorblind_color_of(
			GameManager.faction_for_team(buoy_owner), SettingsManager.colorblind_palette()
		)
		draw_arc(bpos, float(buoy.get("radius_px", SonarBuoy.RADIUS_PX)), 0, TAU, 48,
			Color(bcol.r, bcol.g, bcol.b, 0.18 + life * 0.35), 2.0)
		draw_circle(bpos, 5.0, Color(bcol.r, bcol.g, bcol.b, 0.55 + life * 0.45))

	# Ambient non-combatant wildlife (Deer, Dolphins, Squid, Birds)
	for cr in wildlife_herd:
		_draw_wildlife_critter(cr)

	# Weapon projectile tracers & impact sparks
	for tracer in active_tracers:
		var frac := clampf(1.0 - float(tracer["timer"]) / maxf(0.01, float(tracer["duration"])), 0.0, 1.0)
		var head: Vector2 = tracer["from"].lerp(tracer["to"], minf(1.0, frac * 1.35))
		var tail: Vector2 = tracer["from"].lerp(tracer["to"], maxf(0.0, frac - 0.35))
		draw_line(tail, head, tracer["color"], float(tracer["width"]))
		draw_circle(head, float(tracer["width"]) * 1.15, Color(1.0, 0.98, 0.85, 0.95))

	# Explosions, Orbital Laser Beams, and Nuclear Mushrooms
	for v in active_vfx:
		var dur := maxf(0.01, float(v.get("duration", 1.0)))
		var prog := clampf(1.0 - float(v["timer"]) / dur, 0.0, 1.0)
		var pos: Vector2 = v["pos"]
		var rad := float(v["radius"])
		match String(v.get("type", "explosion")):
			"laser":
				draw_line(pos - Vector2(0, 600), pos, Color(0.25, 0.95, 1.0, 1.0 - prog), 12.0 * (1.0 - prog * 0.5))
				draw_circle(pos, rad * sin(prog * PI), v["color"])
			"nuke":
				draw_arc(pos, rad * prog * 1.25, 0, TAU, 36, Color(1.0, 0.85, 0.3, 1.0 - prog), 5.0)
				draw_circle(pos, rad * sin(prog * PI), v["color"])
				draw_circle(pos, rad * 0.55 * sin(prog * PI), Color(1.0, 0.96, 0.75, 1.0 - prog))
			_:
				draw_arc(pos, rad * prog * 1.35, 0, TAU, 24, Color(1.0, 0.8, 0.3, 1.0 - prog), 2.5)
				draw_circle(pos, rad * sin(prog * PI), Color(1.0, 0.45, 0.1, 0.75 * (1.0 - prog)))

	if drag_selecting:
		var r := Rect2(drag_start, drag_current - drag_start).abs()
		draw_rect(r, Color(0.2, 0.9, 0.3, 0.18), true)
		draw_rect(r, Color(0.2, 0.95, 0.3, 0.9), false, 2.0)

	# Drifting cloud formations (affecting only aerial units). Weather in
	# unexplored territory must not reveal the map through the fog overlay.
	var weather_known := not GameManager.fog_enabled or fog == null
	for cl in GameManager.active_clouds:
		var cpos: Vector2 = cl["pos"]
		if not weather_known:
			var cx := int(cpos.x / TILE_SIZE)
			var cy := int(cpos.y / TILE_SIZE)
			if not fog.is_visible(cx, cy) and not fog.is_explored(cx, cy):
				continue
		var rad := float(cl.get("radius", 90.0))
		var calpha := float(cl.get("alpha", 0.32))
		# Soft ground shadow + multi-puff cloud canopy
		draw_circle(cpos + Vector2(14, 18), rad * 0.85, Color(0.03, 0.05, 0.08, calpha * 0.38))
		draw_circle(cpos, rad * 0.78, Color(0.94, 0.97, 1.0, calpha))
		draw_circle(cpos + Vector2(-rad * 0.35, rad * 0.12), rad * 0.56, Color(0.92, 0.96, 1.0, calpha * 0.92))
		draw_circle(cpos + Vector2(rad * 0.36, -rad * 0.10), rad * 0.58, Color(0.96, 0.98, 1.0, calpha * 0.92))
		draw_circle(cpos + Vector2(0, -rad * 0.25), rad * 0.52, Color(1.0, 1.0, 1.0, calpha * 0.95))

	# Interactive placement ghost & tactical cursor/pings
	if not pending_build_id.is_empty() and map_data != null:
		var mpos := _world_mouse_pos(get_viewport().get_mouse_position())
		var origin := Vector2i(int(mpos.x / TILE_SIZE), int(mpos.y / TILE_SIZE))
		var bs := GameManager.registry.get_building(pending_build_id)
		var fp := bs.footprint if bs != null else Vector2i(2, 2)
		var ok := Placement.can_place_building(map_data, pending_build_id, fp, origin, occupied_tiles)
		var gcol := Color(0.2, 1.0, 0.35, 0.45) if ok else Color(1.0, 0.2, 0.2, 0.45)
		draw_rect(Rect2(float(origin.x) * TILE_SIZE, float(origin.y) * TILE_SIZE, float(fp.x) * TILE_SIZE, float(fp.y) * TILE_SIZE), gcol, true)
	if not pending_target_action.is_empty():
		var tpos := _world_mouse_pos(get_viewport().get_mouse_position())
		var r_sz := 95.0 if pending_target_action == "laser" else 180.0
		if pending_target_action == "sonar_buoy":
			r_sz = SonarBuoy.RADIUS_PX
		draw_arc(tpos, r_sz, 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.85), 2.5)
	for ping in tactical_pings:
		var ppos: Vector2 = ping["pos"]
		var pt := float(ping["timer"])
		draw_arc(ppos, 18.0 + (4.0 - pt) * 8.0, 0, TAU, 20, Color(0.2, 0.95, 1.0, clampf(pt * 0.25, 0.0, 1.0)), 2.5)

func _update_fog() -> void:
	if fog == null:
		return
	var team := GameManager.local_team
	if not GameManager.fog_enabled:
		fog_sprite.visible = false
		for u in units_container.get_children():
			if is_instance_valid(u):
				u.visible = true
		for b in get_tree().get_nodes_in_group("buildings"):
			if is_instance_valid(b):
				b.visible = true
		return
	fog_sprite.visible = true
	fog.reset_visibility()
	for u in units_container.get_children():
		if is_instance_valid(u) and GameManager.is_allied(team, u.team):
			var tx := int(u.global_position.x / TILE_SIZE)
			var ty := int(u.global_position.y / TILE_SIZE)
			var sight_tiles := 8
			if u.has_method("effective_sight"):
				sight_tiles = maxi(1, int(float(u.effective_sight()) / TILE_SIZE))
			elif u.stats:
				sight_tiles = maxi(1, int(u.stats.sight / TILE_SIZE))
			fog.mark_visible(tx, ty, sight_tiles)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and GameManager.is_allied(team, b.team):
			var tx := int(b.global_position.x / TILE_SIZE)
			var ty := int(b.global_position.y / TILE_SIZE)
			# Most structures see 5 tiles. Radar buildings (including sapper
			# missile towers) sweep only their powered, limited range.
			var range_px := _building_vision_px(b, team)
			if range_px > 0.0:
				fog.mark_visible(tx, ty, maxi(1, ceili(range_px / TILE_SIZE)))
	for y in range(fog.height):
		for x in range(fog.width):
			# Unexplored tiles must be fully opaque: a translucent veil still
			# lets terrain, clouds and structures bleed through the fog.
			var col := Color(0, 0, 0, 1.0)
			if fog.is_visible(x, y):
				col = Color(0, 0, 0, 0.0)
			elif fog.is_explored(x, y):
				col = Color(0, 0, 0, 0.55)
			fog_image.set_pixel(x, y, col)
	fog_texture.update(fog_image)
	for u in units_container.get_children():
		if is_instance_valid(u):
			u.visible = _node_visible_to_team(team, u, fog)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b):
			b.visible = _node_visible_to_team(team, b, fog)

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
		MapData.Terrain.DESERT: return Color(0.76, 0.65, 0.38)
		MapData.Terrain.HILLS: return Color(0.45, 0.50, 0.28)
	return Color(0.3, 0.3, 0.3)

func _update_terrain_image() -> void:
	if map_data == null:
		return
	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	if terrain_texture:
		terrain_texture = ImageTexture.create_from_image(terrain_image)
		if terrain_sprite:
			terrain_sprite.texture = terrain_texture
	_rebuild_forest_decorations()

func _rebuild_forest_decorations() -> void:
	forest_decorations.clear()
	if map_data == null:
		return
	for ty in range(2, map_data.height - 2):
		for tx in range(2, map_data.width - 2):
			if map_data.get_terrain(tx, ty) == MapData.Terrain.FOREST:
				var h := ((tx * 374761393) ^ (ty * 668265263)) & 255
				if (h % 4) == 0:
					var wpos := Vector2(float(tx * 16 + 4 + (h % 8)), float(ty * 16 + 4 + ((h >> 3) % 8)))
					forest_decorations.append({
						"pos": wpos,
						"kind": "tree" if (h % 2 == 0) else "shrub",
						"radius": 6.2 if (h % 2 == 0) else 3.8,
						"shade": float(h % 10) * 0.015,
					})
	_rebuild_forest_multimesh()

## Batch-render every tree canopy in one draw call instead of hundreds of
## per-frame `_draw()` circles (Step 20).
func _rebuild_forest_multimesh() -> void:
	if forest_multimesh == null:
		forest_multimesh = MultiMeshInstance2D.new()
		forest_multimesh.name = "ForestMultiMesh"
		forest_multimesh.z_index = -4
		add_child(forest_multimesh)
	var trees: Array = []
	for dec in forest_decorations:
		if String(dec.get("kind", "")) == "tree":
			trees.append(dec)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm := MultiMesh.new()
	mm.mesh = quad
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = trees.size()
	for i in range(trees.size()):
		var dec: Dictionary = trees[i]
		var radius := float(dec.get("radius", 6.2))
		var shade := float(dec.get("shade", 0.0))
		var xform := Transform2D().scaled(Vector2(radius, radius))
		xform.origin = dec["pos"]
		mm.set_instance_transform_2d(i, xform)
		mm.set_instance_color(i, Color(0.12 + shade, 0.34 + shade, 0.14 + shade, 0.92))
	forest_multimesh.multimesh = mm

func _update_wildlife(delta: float) -> void:
	var threats: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding:
			threats.append(u.global_position)
	for i in range(wildlife_herd.size() - 1, -1, -1):
		var cr: Dictionary = wildlife_herd[i]
		WildlifeRef.step_critter(cr, map_data, threats, delta, int(elapsed_time * 10.0) + i)
		if not bool(cr.get("alive", true)) and float(cr.get("death_timer", 0.0)) <= 0.0:
			wildlife_herd.remove_at(i)

func _draw_wildlife_critter(cr: Dictionary) -> void:
	var cpos: Vector2 = cr["pos"]
	var tx := clampi(int(cpos.x / TILE_SIZE), 0, 127)
	var ty := clampi(int(cpos.y / TILE_SIZE), 0, 127)
	if fog != null and not fog.is_visible(tx, ty):
		return
	var alive := bool(cr.get("alive", true))
	var kind := int(cr.get("kind", WildlifeRef.Kind.DEER))
	var vel: Vector2 = cr.get("vel", Vector2.RIGHT)
	var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var phase := float(cr.get("anim_phase", 0.0))

	if not alive:
		var alpha := clampf(float(cr.get("death_timer", 0.0)), 0.0, 1.0)
		draw_circle(cpos, 4.2, Color(0.55, 0.14, 0.12, alpha))
		return

	match kind:
		WildlifeRef.Kind.BIRD:
			var flap := sin(phase * 1.8) * 4.5
			draw_circle(cpos + Vector2(6, 10), 2.4, Color(0, 0, 0, 0.24))
			var wing_l := cpos - dir * 2.0 + perp * (6.2 + flap * 0.4)
			var wing_r := cpos - dir * 2.0 - perp * (6.2 + flap * 0.4)
			draw_line(wing_l, cpos + dir * 2.5, Color(0.95, 0.96, 0.98, 0.95), 1.8)
			draw_line(wing_r, cpos + dir * 2.5, Color(0.95, 0.96, 0.98, 0.95), 1.8)
		WildlifeRef.Kind.DOLPHIN:
			var breach := sin(phase) * 2.0
			draw_arc(cpos, 6.0 + absf(breach), 0, TAU, 16, Color(0.75, 0.95, 1.0, 0.45), 1.2)
			draw_line(cpos - dir * 6.0, cpos + dir * 6.0, Color(0.45, 0.78, 0.92, 0.95), 3.2)
			draw_circle(cpos + dir * 2.0, 2.2, Color(0.32, 0.62, 0.80, 1.0))
		WildlifeRef.Kind.SQUID:
			var pulse := sin(phase * 1.3) * 1.8
			draw_circle(cpos + dir * 3.0, 3.8, Color(0.88, 0.42, 0.58, 0.92))
			for t_i in [-1.0, 0.0, 1.0]:
				var t_end: Vector2 = cpos - dir * (6.5 + pulse) + perp * (float(t_i) * 2.5)
				draw_line(cpos, t_end, Color(0.92, 0.55, 0.68, 0.85), 1.3)
		_:
			var stride := sin(phase * 1.5) * 1.5
			draw_circle(cpos + Vector2(1, 2), 3.2, Color(0, 0, 0, 0.28))
			draw_line(cpos - dir * 4.2, cpos + dir * 4.0, Color(0.68, 0.48, 0.28, 0.96), 3.0)
			draw_circle(cpos + dir * (4.8 + stride * 0.3), 2.2, Color(0.78, 0.58, 0.35, 1.0))
			draw_circle(cpos - dir * 4.8, 1.3, Color(0.95, 0.92, 0.85, 0.95))

func _capture_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir_path := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := "%s/screenshot_%d.png" % [dir_path, int(Time.get_unix_time_from_system())]
	var err := img.save_png(path)
	if err == OK and is_instance_valid(status_label):
		status_label.text = "Screenshot saved: %s" % path
