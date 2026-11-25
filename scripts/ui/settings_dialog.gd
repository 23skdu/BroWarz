# scripts/ui/settings_dialog.gd
class_name SettingsDialog
extends AcceptDialog

## In-game settings dialog backed by SettingsManager / SettingsStore
## (user://settings.cfg). Changes apply live and persist on close.

const KEY_CHOICES := [
	["W", KEY_W], ["A", KEY_A], ["S", KEY_S], ["D", KEY_D],
	["Arrow Up", KEY_UP], ["Arrow Down", KEY_DOWN],
	["Arrow Left", KEY_LEFT], ["Arrow Right", KEY_RIGHT],
	["Space", KEY_SPACE], ["Shift", KEY_SHIFT], ["Ctrl", KEY_CTRL],
]
const PALETTE_LABELS := ["None", "Deuteranopia", "Protanopia", "Tritanopia"]

var _status: Label

func _ready() -> void:
	title = "Settings — Audio, Accessibility & Controls"
	get_ok_button().text = "Save & Close"
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(580, 0)
	add_child(vbox)

	_add_section_title(vbox, "Audio")
	_add_slider(vbox, "master_volume", "Master volume", 0.0, 1.0, 0.05, 2)
	_add_slider(vbox, "music_volume", "Music volume", 0.0, 1.0, 0.05, 2)
	_add_slider(vbox, "sfx_volume", "SFX volume", 0.0, 1.0, 0.05, 2)
	var mute := CheckButton.new()
	mute.text = "Mute all audio"
	mute.button_pressed = bool(SettingsManager.get_setting("muted", false))
	mute.toggled.connect(func(pressed: bool): SettingsManager.set_setting("muted", pressed))
	vbox.add_child(mute)

	var soundtrack := OptionButton.new()
	var soundtrack_ids: Array = AudioManager.SOUNDTRACK_ORDER
	for id in soundtrack_ids:
		soundtrack.add_item(AudioManager.soundtrack_label(String(id)))
	var current_track := String(SettingsManager.get_setting("soundtrack", AudioManager.DEFAULT_SOUNDTRACK))
	soundtrack.selected = maxi(0, soundtrack_ids.find(current_track))
	soundtrack.item_selected.connect(func(idx: int):
		SettingsManager.set_setting("soundtrack", String(soundtrack_ids[idx]))
	)
	var soundtrack_row := _labeled_row(vbox, "Soundtrack")
	soundtrack_row.add_child(soundtrack)

	_add_section_title(vbox, "Accessibility & Interface")
	_add_slider(vbox, "camera_speed", "Camera pan speed", 100.0, 1200.0, 20.0, 0)
	_add_slider(vbox, "ui_scale", "UI scale", 0.5, 2.0, 0.05, 2)
	var palette := OptionButton.new()
	for label in PALETTE_LABELS:
		palette.add_item(str(label))
	palette.selected = maxi(0, SettingsManager.COLORBLIND_PALETTES.find(SettingsManager.colorblind_palette()))
	palette.item_selected.connect(func(idx: int): SettingsManager.set_setting("colorblind", SettingsManager.COLORBLIND_PALETTES[idx]))
	var palette_row := _labeled_row(vbox, "Colorblind palette")
	palette_row.add_child(palette)

	_add_section_title(vbox, "Hotkey Bindings — Camera")
	for action in SettingsManager.HOTKEY_ACTIONS:
		var select := OptionButton.new()
		var current := SettingsManager.hotkey(action)
		for choice in KEY_CHOICES:
			select.add_item(str(choice[0]))
			if int(choice[1]) == current:
				select.selected = select.item_count - 1
		var act: String = action
		select.item_selected.connect(func(idx: int): SettingsManager.bind_hotkey(act, int(KEY_CHOICES[idx][1])))
		var row := _labeled_row(vbox, act.capitalize().replace("_", " "))
		row.add_child(select)

	_status = Label.new()
	_status.text = "Changes apply immediately; saved to user://settings.cfg on close."
	vbox.add_child(_status)

	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.pressed.connect(_on_reset_defaults)
	vbox.add_child(reset)

	confirmed.connect(_save_and_close)
	close_requested.connect(_save_and_close)

func _add_section_title(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _labeled_row(parent: Node, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	parent.add_child(row)
	return row

func _add_slider(parent: Node, key: String, text: String, minimum: float, maximum: float, step: float, decimals: int) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(190, 0)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(SettingsManager.get_setting(key, minimum))
	slider.custom_minimum_size = Vector2(280, 0)
	var value_label := Label.new()
	value_label.text = _format_value(float(slider.value), decimals)
	slider.value_changed.connect(func(value: float):
		value_label.text = _format_value(value, decimals)
		SettingsManager.set_setting(key, value)
	)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	parent.add_child(row)

func _format_value(value: float, decimals: int) -> String:
	if decimals == 0:
		return "%d" % int(round(value))
	return "%0.2f" % value

func _on_reset_defaults() -> void:
	SettingsManager.reset_defaults()
	if is_instance_valid(_status):
		_status.text = "Defaults restored. Close the dialog to save."

func _save_and_close() -> void:
	SettingsManager.save_settings()
	SettingsManager.apply_to_scene()
	hide()
	queue_free()
