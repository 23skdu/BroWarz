# scripts/ui/settings_dialog.gd
class_name SettingsDialog
extends AcceptDialog

## In-game settings dialog backed by SettingsManager / SettingsStore
## (user://settings.cfg). Changes apply live and persist on close.

const KEY_CHOICES := [
	["A", KEY_A], ["B", KEY_B], ["C", KEY_C], ["D", KEY_D], ["E", KEY_E],
	["F", KEY_F], ["G", KEY_G], ["H", KEY_H], ["I", KEY_I], ["J", KEY_J],
	["K", KEY_K], ["L", KEY_L], ["M", KEY_M], ["N", KEY_N], ["O", KEY_O],
	["P", KEY_P], ["Q", KEY_Q], ["R", KEY_R], ["S", KEY_S], ["T", KEY_T],
	["U", KEY_U], ["V", KEY_V], ["W", KEY_W], ["X", KEY_X], ["Y", KEY_Y], ["Z", KEY_Z],
	["Arrow Up", KEY_UP], ["Arrow Down", KEY_DOWN],
	["Arrow Left", KEY_LEFT], ["Arrow Right", KEY_RIGHT],
	["Space", KEY_SPACE], ["Shift", KEY_SHIFT], ["Ctrl", KEY_CTRL],
]
const CAMERA_HOTKEYS := ["camera_up", "camera_down", "camera_left", "camera_right"]
const PALETTE_LABELS := ["None", "Deuteranopia", "Protanopia", "Tritanopia"]
const QUALITY_LABELS := ["Low (Max FPS)", "Medium", "High (Best Visuals)"]

var _status: Label

func _ready() -> void:
	title = "Settings — Audio, Accessibility & Controls"
	get_ok_button().text = "Save & Close"
	var outer_scroll := ScrollContainer.new()
	outer_scroll.name = "SettingsScroll"
	outer_scroll.custom_minimum_size = Vector2(600, 520)
	add_child(outer_scroll)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(568, 0)
	outer_scroll.add_child(vbox)

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

	var subs := CheckButton.new()
	subs.name = "SubtitlesToggle"
	subs.text = "Show voice-bark subtitles"
	subs.button_pressed = SettingsManager.subtitles_enabled()
	subs.toggled.connect(func(pressed: bool): SettingsManager.set_setting("subtitles", pressed))
	vbox.add_child(subs)

	var quality := OptionButton.new()
	quality.name = "GraphicsQualityOption"
	for qlabel in QUALITY_LABELS:
		quality.add_item(str(qlabel))
	quality.selected = maxi(0, SettingsManager.GRAPHICS_QUALITIES.find(String(SettingsManager.graphics_quality())))
	quality.item_selected.connect(func(idx: int):
		SettingsManager.set_setting("graphics_quality", SettingsManager.GRAPHICS_QUALITIES[idx])
	)
	var quality_row := _labeled_row(vbox, "Graphics quality")
	quality_row.add_child(quality)

	var motion := CheckButton.new()
	motion.name = "ReducedMotionToggle"
	motion.text = "Reduced motion (calm pulses & rotors)"
	motion.button_pressed = bool(SettingsManager.reduced_motion())
	motion.toggled.connect(func(pressed: bool): SettingsManager.set_setting("reduced_motion", pressed))
	vbox.add_child(motion)

	_add_section_title(vbox, "Hotkey Bindings — Camera")
	for action in CAMERA_HOTKEYS:
		_add_hotkey_row(vbox, action)

	_add_section_title(vbox, "Hotkey Bindings — Commands & Build")
	var cmd_grid := GridContainer.new()
	cmd_grid.name = "CommandHotkeyGrid"
	cmd_grid.columns = 2
	vbox.add_child(cmd_grid)
	for action in SettingsManager.HOTKEY_ACTIONS:
		if action in CAMERA_HOTKEYS:
			continue
		_add_hotkey_row(cmd_grid, action)

	_add_section_title(vbox, "Multiplayer — WebRTC ICE Servers")
	var stun_row := _labeled_row(vbox, "STUN server URL")
	var stun_edit := LineEdit.new()
	stun_edit.name = "SettingsStunEdit"
	stun_edit.custom_minimum_size = Vector2(320, 0)
	stun_edit.text = String(SettingsManager.webrtc_stun_url())
	stun_edit.text_submitted.connect(func(v: String):
		if NetSecurity.is_valid_ice_url(v):
			SettingsManager.set_setting("webrtc_stun_url", v.strip_edges())
	)
	stun_edit.focus_exited.connect(func():
		var v := stun_edit.text.strip_edges()
		if NetSecurity.is_valid_ice_url(v):
			SettingsManager.set_setting("webrtc_stun_url", v)
	)
	stun_row.add_child(stun_edit)

	var turn_row := _labeled_row(vbox, "TURN relay URL")
	var turn_edit := LineEdit.new()
	turn_edit.name = "SettingsTurnEdit"
	turn_edit.placeholder_text = "Optional turn:host:3478"
	turn_edit.custom_minimum_size = Vector2(320, 0)
	turn_edit.text = String(SettingsManager.webrtc_turn_url())
	turn_edit.focus_exited.connect(func():
		var v := turn_edit.text.strip_edges()
		if v.is_empty() or NetSecurity.is_valid_ice_url(v):
			SettingsManager.set_setting("webrtc_turn_url", v)
	)
	turn_row.add_child(turn_edit)

	_status = Label.new()
	_status.text = "Changes apply immediately; saved to user://settings.cfg on close."
	vbox.add_child(_status)

	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.pressed.connect(_on_reset_defaults)
	vbox.add_child(reset)

	confirmed.connect(_save_and_close)
	close_requested.connect(_save_and_close)

func _add_hotkey_row(parent: Node, action: String) -> void:
	var select := OptionButton.new()
	select.name = "Hotkey_" + action
	var current: int = int(SettingsManager.hotkey(action))
	for choice in KEY_CHOICES:
		select.add_item(str(choice[0]))
		if int(choice[1]) == current:
			select.selected = select.item_count - 1
	var act: String = action
	select.item_selected.connect(func(idx: int): SettingsManager.bind_hotkey(act, int(KEY_CHOICES[idx][1])))
	var label_text := act.replace("cmd_", "").replace("build_", "Build ").capitalize().replace("_", " ")
	var row := _labeled_row(parent, label_text)
	row.add_child(select)

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
