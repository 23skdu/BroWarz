class_name ReplayViewer
extends AcceptDialog

## Lightweight command-stream replay viewer. It loads the deterministic
## Replay log produced by a match and scrubs/ plays back recorded orders so
## the match narrative can be reviewed without a second simulation runtime.

const REPLAY_PATH := "user://replays/match.json"
const TYPE_NAMES: Array[String] = [
	"MOVE", "ATTACK", "ATTACK_MOVE", "BUILD", "STOP", "PATROL", "HOLD",
	"TRAIN", "FORTIFY", "EMBARK", "DISEMBARK", "TECH", "ORBITAL", "NUKE",
]

var replay: Replay = null
var current_tick: float = 0.0
var command_index: int = 0
var playing: bool = false
var speed: float = 60.0  # recorded ticks per real second

var info_label: Label
var now_label: Label
var stream_label: RichTextLabel
var play_button: Button

func _ready() -> void:
	title = "Replay Viewer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_ok_button().text = "Close"
	var vbox := VBoxContainer.new()
	vbox.name = "ReplayVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -56.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	info_label = Label.new()
	info_label.name = "ReplayInfo"
	vbox.add_child(info_label)
	now_label = Label.new()
	now_label.name = "ReplayNow"
	vbox.add_child(now_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)
	play_button = Button.new()
	play_button.name = "PlayButton"
	play_button.text = "Play"
	play_button.pressed.connect(toggle_play)
	buttons.add_child(play_button)
	var step_button := Button.new()
	step_button.text = "Step"
	step_button.pressed.connect(step_one)
	buttons.add_child(step_button)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(reset_playback)
	buttons.add_child(reset_button)
	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(func(): load_replay(REPLAY_PATH))
	buttons.add_child(reload_button)

	stream_label = RichTextLabel.new()
	stream_label.name = "CommandStream"
	stream_label.custom_minimum_size = Vector2(560, 260)
	stream_label.scroll_active = true
	stream_label.bbcode_enabled = true
	vbox.add_child(stream_label)
	load_replay(REPLAY_PATH)

func _process(delta: float) -> void:
	if not playing or replay == null:
		return
	current_tick += delta * speed
	_advance_to_tick()

func toggle_play() -> void:
	if replay == null or command_index >= replay.command_count():
		return
	playing = not playing
	play_button.text = "Pause" if playing else "Play"

func step_one() -> void:
	playing = false
	play_button.text = "Play"
	if replay == null or command_index >= replay.command_count():
		return
	var cmd := Command.from_dict(replay.commands[command_index])
	current_tick = maxf(current_tick, float(cmd.tick) + 1.0)
	_advance_to_tick()
	if command_index >= replay.command_count():
		current_tick = float(replay.ticks) + 1.0

func reset_playback() -> void:
	playing = false
	play_button.text = "Play"
	current_tick = 0.0
	command_index = 0
	_update_now()

func load_replay(path: String = REPLAY_PATH) -> bool:
	reset_playback()
	if not FileAccess.file_exists(path):
		info_label.text = "No replay found at %s. Save one from a match first." % path
		stream_label.text = ""
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		info_label.text = "Cannot open replay: %s" % error_string(FileAccess.get_open_error())
		stream_label.text = ""
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		info_label.text = "Replay is corrupt (invalid JSON)."
		stream_label.text = ""
		return false
	replay = Replay.from_dict(parsed as Dictionary)
	info_label.text = "Map: %s | Seed: %d | Commands: %d | Ticks: %d" % [
		replay.map_name, replay.seed, replay.command_count(), replay.ticks,
	]
	_render_stream()
	_update_now()
	return true

func _advance_to_tick() -> void:
	while command_index < replay.command_count():
		var cmd := Command.from_dict(replay.commands[command_index])
		if float(cmd.tick) > current_tick:
			break
		command_index += 1
	_update_now()
	if command_index >= replay.command_count():
		playing = false
		play_button.text = "Play"

func _update_now() -> void:
	if replay == null:
		now_label.text = "No replay loaded"
		return
	if command_index >= replay.command_count():
		now_label.text = "End of replay (tick %d)" % replay.ticks
		return
	var cmd := Command.from_dict(replay.commands[command_index])
	now_label.text = "Next @ tick %d: %s" % [cmd.tick, _describe(cmd)]

func _render_stream() -> void:
	if replay == null:
		stream_label.text = ""
		return
	var lines: Array[String] = []
	for i in range(replay.command_count()):
		var cmd := Command.from_dict(replay.commands[i])
		var colour := "#7fe9a0" if cmd.player_id == 0 else "#ff9a7a"
		lines.append("[color=%s]%02d. tick %d | P%d | %s[/color]" % [
			colour, i + 1, cmd.tick, cmd.player_id, _describe(cmd),
		])
	stream_label.text = "\n".join(lines)

func _describe(cmd: Command) -> String:
	var type_idx := clampi(int(cmd.type), 0, TYPE_NAMES.size() - 1)
	var detail := TYPE_NAMES[type_idx]
	if not cmd.build_type.is_empty():
		detail += " %s" % cmd.build_type
	if cmd.target_pos != Vector2.ZERO:
		detail += " @ (%.0f, %.0f)" % [cmd.target_pos.x, cmd.target_pos.y]
	if not cmd.unit_ids.is_empty():
		detail += " [%d units]" % cmd.unit_ids.size()
	return detail
