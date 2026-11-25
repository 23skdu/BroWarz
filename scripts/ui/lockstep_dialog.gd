# scripts/ui/lockstep_dialog.gd
class_name LockstepDialog
extends AcceptDialog

## Live runtime hook for the deterministic multi-peer lockstep soak harness
## (`Lockstep.run_soak_simulation`) and live P2P match checksum readout.

const PEER_CHOICES: Array[int] = [2, 4, 6, 8]
const TICK_CHOICES: Array[int] = [120, 240, 480]

var peer_option: OptionButton
var tick_option: OptionButton
var seed_edit: LineEdit
var run_button: Button
var result_label: Label
var live_label: Label
var last_result: Dictionary = {}

func _ready() -> void:
	title = "Lockstep Determinism & Soak Verification"
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_ok_button().text = "Close"

	var vbox := VBoxContainer.new()
	vbox.name = "LockstepVBox"
	vbox.custom_minimum_size = Vector2(540, 0)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = (
		"Run the multi-peer deterministic lockstep soak harness live inside the runtime. "
		+ "Every simulated peer executes replicated commands and compares per-tick GameState checksums."
	)
	vbox.add_child(intro)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	vbox.add_child(controls)

	var peer_lbl := Label.new()
	peer_lbl.text = "Peers:"
	controls.add_child(peer_lbl)
	peer_option = OptionButton.new()
	peer_option.name = "PeerOption"
	for p in PEER_CHOICES:
		peer_option.add_item("%d peers" % p)
	peer_option.selected = 1  # 4 peers
	controls.add_child(peer_option)

	var tick_lbl := Label.new()
	tick_lbl.text = "Ticks:"
	controls.add_child(tick_lbl)
	tick_option = OptionButton.new()
	tick_option.name = "TickOption"
	for t in TICK_CHOICES:
		tick_option.add_item("%d ticks" % t)
	tick_option.selected = 1  # 240 ticks
	controls.add_child(tick_option)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:"
	controls.add_child(seed_lbl)
	seed_edit = LineEdit.new()
	seed_edit.name = "SeedEdit"
	seed_edit.text = "2030"
	seed_edit.custom_minimum_size = Vector2(88, 0)
	controls.add_child(seed_edit)

	run_button = Button.new()
	run_button.name = "RunSoakButton"
	run_button.text = "Run Lockstep Soak"
	run_button.pressed.connect(func(): run_soak())
	vbox.add_child(run_button)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.text = "Ready. Press 'Run Lockstep Soak' to verify determinism."
	vbox.add_child(result_label)

	live_label = Label.new()
	live_label.name = "LiveStatusLabel"
	live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(live_label)
	refresh_live_status()

func refresh_live_status(live_checksum: int = -1, desync_count: int = 0) -> void:
	if live_label == null:
		return
	var net_mode := "Active P2P Match" if NetworkManager.is_network_match() else "Offline / Local"
	if live_checksum >= 0:
		live_label.text = "Live session: %s | State checksum: 0x%X | Desync alerts: %d" % [
			net_mode, live_checksum, desync_count,
		]
	else:
		live_label.text = "Live session: %s | Desync alerts: %d" % [net_mode, desync_count]

func run_soak(num_peers: int = -1, num_ticks: int = -1, rng_seed: int = -1) -> Dictionary:
	var peers := num_peers if num_peers >= 2 else PEER_CHOICES[clampi(peer_option.selected, 0, PEER_CHOICES.size() - 1)]
	var ticks := num_ticks if num_ticks >= 1 else TICK_CHOICES[clampi(tick_option.selected, 0, TICK_CHOICES.size() - 1)]
	var chosen_seed := rng_seed
	if chosen_seed < 0:
		chosen_seed = int(seed_edit.text) if (seed_edit != null and seed_edit.text.strip_edges().is_valid_int()) else 2030
	var t0 := Time.get_ticks_usec()
	var res := Lockstep.run_soak_simulation(peers, ticks, chosen_seed)
	var elapsed_ms := float(Time.get_ticks_usec() - t0) * 0.001
	res["elapsed_ms"] = elapsed_ms
	res["seed"] = chosen_seed
	last_result = res
	var status_tag := "PASS (deterministic)" if bool(res["ok"]) else "FAIL (DESYNC DETECTED)"
	if result_label != null:
		result_label.text = "%s\nPeers: %d | Ticks: %d | Commands: %d | Desyncs: %d | Checksum: 0x%X | %.2f ms" % [
			status_tag, int(res["peers"]), int(res["ticks"]), int(res["commands"]),
			int(res["desyncs"]), int(res["final_checksum"]), elapsed_ms,
		]
	return res
