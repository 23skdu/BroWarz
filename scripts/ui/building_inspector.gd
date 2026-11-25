# scripts/ui/building_inspector.gd
class_name BuildingInspector
extends PanelContainer

## Dedicated in-match building inspector panel. Shows the selected friendly
## structure's icon, HP, power balance, radar sweep, rally point, live
## production queue/progress, one-click unit training buttons, queue
## cancellation, and demolition.

signal train_requested(unit_id: String)
signal cancel_queue_requested
signal reset_rally_requested
signal demolish_requested

var icon_rect: TextureRect
var name_label: Label
var hp_label: Label
var stats_label: Label
var queue_label: Label
var queue_bar: ProgressBar
var cancel_btn: Button
var reset_rally_btn: Button
var demolish_btn: Button
var train_grid: GridContainer

var _current_building: Node2D = null
var _last_building_id: String = ""
var _last_color_hex: String = ""

func _ready() -> void:
	name = "BuildingInspector"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 20.0
	offset_top = -236.0
	offset_right = 410.0
	offset_bottom = -16.0
	custom_minimum_size = Vector2(390.0, 220.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.28, 0.78, 0.95, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(icon_rect)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Building"
	title_box.add_child(name_label)

	hp_label = Label.new()
	hp_label.name = "HpLabel"
	hp_label.text = "HP: 0 / 0"
	title_box.add_child(hp_label)

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = ""
	vbox.add_child(stats_label)

	queue_label = Label.new()
	queue_label.name = "QueueLabel"
	queue_label.text = "Queue: idle"
	vbox.add_child(queue_label)

	queue_bar = ProgressBar.new()
	queue_bar.name = "QueueBar"
	queue_bar.min_value = 0.0
	queue_bar.max_value = 100.0
	queue_bar.value = 0.0
	queue_bar.custom_minimum_size = Vector2(0, 14)
	queue_bar.show_percentage = false
	vbox.add_child(queue_bar)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	vbox.add_child(actions)

	cancel_btn = Button.new()
	cancel_btn.name = "CancelQueueButton"
	cancel_btn.text = "Cancel Last [X]"
	cancel_btn.pressed.connect(func(): cancel_queue_requested.emit())
	actions.add_child(cancel_btn)

	reset_rally_btn = Button.new()
	reset_rally_btn.name = "ResetRallyButton"
	reset_rally_btn.text = "Reset Rally"
	reset_rally_btn.pressed.connect(func(): reset_rally_requested.emit())
	actions.add_child(reset_rally_btn)

	demolish_btn = Button.new()
	demolish_btn.name = "DemolishButton"
	demolish_btn.text = "Demolish (25%)"
	demolish_btn.pressed.connect(func(): demolish_requested.emit())
	actions.add_child(demolish_btn)

	train_grid = GridContainer.new()
	train_grid.name = "TrainGrid"
	train_grid.columns = 3
	train_grid.add_theme_constant_override("h_separation", 4)
	train_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(train_grid)

func _exit_tree() -> void:
	_current_building = null

func inspected_building() -> Node2D:
	return _current_building if is_instance_valid(_current_building) else null

func inspect(building: Node2D, power_eff: float = 1.0) -> void:
	if building == null or not is_instance_valid(building) or ("is_exploding" in building and building.is_exploding):
		_current_building = null
		visible = false
		return
	var bs: BuildingStats = building.get("stats") as BuildingStats
	if bs == null:
		_current_building = null
		visible = false
		return
	_current_building = building
	visible = true

	var b_team := int(building.get("team"))
	var fac_id := GameManager.faction_for_team(b_team)
	var col := Faction.colorblind_color_of(fac_id, SettingsManager.colorblind_palette(), 0)
	var col_hex := col.to_html(false)
	if bs.id != _last_building_id or col_hex != _last_color_hex:
		icon_rect.texture = BuildingVisual.get_cached_building_texture(bs.id, col, 48)
		_last_color_hex = col_hex

	name_label.text = bs.display_name
	var cur_hp := int(building.get("hp"))
	hp_label.text = "HP: %d / %d" % [cur_hp, bs.hp]

	var pwr_delta := Power.building_power_delta(bs.id)
	var pwr_str := "%+d Pwr" % int(round(pwr_delta))
	var radar_str := ""
	if bs.radar_range > 0.0:
		radar_str = " | Radar: %.0f px" % (bs.radar_range * clampf(power_eff, 0.0, 1.0))
	var has_r := bool(building.get("has_rally"))
	var r_pos: Vector2 = building.get("rally_point")
	var rally_str := " | Rally: (%.0f, %.0f)" % [r_pos.x, r_pos.y] if has_r else " | Rally: default"
	stats_label.text = "%s%s%s" % [pwr_str, radar_str, rally_str]

	var queue: Array = building.get("production_queue")
	if queue.is_empty():
		queue_label.text = "Queue: idle"
		queue_bar.value = 0.0
		cancel_btn.disabled = true
	else:
		var names: Array[String] = []
		for item in queue:
			if item is Dictionary:
				names.append(String(item.get("id", "?")))
			else:
				names.append(str(item))
		var prog := Production.current_progress(queue) * 100.0
		queue_label.text = "Queue (%d): %s (%.0f%%)" % [queue.size(), ", ".join(names), prog]
		queue_bar.value = prog
		cancel_btn.disabled = false

	demolish_btn.disabled = bs.is_hq

	if bs.id != _last_building_id:
		_last_building_id = bs.id
		_rebuild_train_buttons(bs.id)

func _rebuild_train_buttons(building_id: String) -> void:
	for child in train_grid.get_children():
		train_grid.remove_child(child)
		child.free()
	var producible: Array[String] = []
	for uid in GameManager.registry.units.keys():
		var s: UnitStats = GameManager.registry.get_unit(String(uid))
		if s == null or s.ai_only:
			continue
		if building_id in UnitRegistry.producer_ids_for_unit(s.id, s.unit_class):
			producible.append(s.id)
	producible.sort()
	# Cap visible buttons cleanly so the inspector never overflows the screen.
	var limit := mini(producible.size(), 9)
	for i in range(limit):
		var uid := producible[i]
		var s: UnitStats = GameManager.registry.get_unit(uid)
		var btn := Button.new()
		btn.name = "InspectTrain_%s" % uid
		btn.text = s.display_name if s != null else uid
		var chosen := uid
		btn.pressed.connect(func(): train_requested.emit(chosen))
		train_grid.add_child(btn)
