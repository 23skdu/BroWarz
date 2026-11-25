class_name DiplomacyDialog
extends AcceptDialog

## In-match diplomacy panel. Every button sends a command through
## NetworkManager, so the host resolves the sender's team, validates the
## transition and relays the result instead of trusting a client-side edit.

const REFRESH_INTERVAL: float = 0.5

var status_label: Label = null
var teams_container: VBoxContainer = null
var _refresh_timer: float = 0.0
var _state_signature: String = ""

func _ready() -> void:
	title = "Diplomacy"
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_ok_button().text = "Close"
	var root := VBoxContainer.new()
	root.name = "DiplomacyRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18.0
	root.offset_top = 18.0
	root.offset_right = -18.0
	root.offset_bottom = -58.0
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "TeamScroll"
	scroll.custom_minimum_size = Vector2(520, 320)
	root.add_child(scroll)
	teams_container = VBoxContainer.new()
	teams_container.name = "TeamRows"
	teams_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(teams_container)
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	var signature := _build_signature()
	if signature != _state_signature:
		refresh()

func _build_signature() -> String:
	var parts: Array[String] = [
		str(GameManager.local_team), str(GameManager.teams), str(GameManager.alliances),
	]
	for key in GameManager.alliance_proposals.keys():
		parts.append(String(key))
	parts.sort()
	return "|".join(parts)

func refresh() -> void:
	_state_signature = _build_signature()
	if teams_container == null or status_label == null:
		return
	for child in teams_container.get_children():
		teams_container.remove_child(child)
		child.free()
	var local := GameManager.local_team
	var teams: Array[int] = []
	for value in GameManager.teams:
		var team := Alliance.team_id(value)
		if team >= 0 and not teams.has(team):
			teams.append(team)
	teams.sort()
	if (
		GameManager.match_mode != GameManager.Mode.MULTIPLAYER
		or teams.size() < 3 or not teams.has(local)
	):
		status_label.text = "In-match diplomacy needs a multiplayer match with 3 or more teams."
		return
	status_label.text = "Team %d | Proposals need the other team's approval. " % local + \
		"Host-authoritative: the server validates and relays every action."
	for team in teams:
		if team == local:
			continue
		_add_team_row(local, team)

func _add_team_row(local: int, team: int) -> void:
	var row := VBoxContainer.new()
	row.name = "Team_%d" % team
	row.add_theme_constant_override("separation", 4)
	teams_container.add_child(row)

	var heading := Label.new()
	heading.name = "Heading"
	row.add_child(heading)
	if GameManager.is_allied(local, team):
		heading.text = "Team %d — ALLIED (shared vision, no friendly fire)" % team
		_add_row_button(row, "Break", "Break_%d" % team, "break", team)
		return
	if Alliance.has_proposal(GameManager.alliance_proposals, local, team):
		heading.text = "Team %d — request sent, waiting for acceptance" % team
		_add_row_button(row, "Cancel Request", "Cancel_%d" % team, "cancel", team)
		return
	if Alliance.has_proposal(GameManager.alliance_proposals, team, local):
		heading.text = "Team %d — wants to ally with you" % team
		_add_row_button(row, "Accept", "Accept_%d" % team, "accept", team)
		_add_row_button(row, "Decline", "Decline_%d" % team, "decline", team)
		return
	heading.text = "Team %d — neutral" % team
	_add_row_button(row, "Propose Alliance", "Propose_%d" % team, "propose", team)

func _add_row_button(row: Node, label: String, button_name: String, action: String, target: int) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.pressed.connect(_send.bind(action, target))
	row.add_child(button)

func _send(action: String, target_team: int) -> void:
	NetworkManager.send_command({
		"type": "diplomacy", "team": GameManager.local_team,
		"action": action, "target_team": target_team,
	})
	# The relayed host verdict arrives asynchronously; _process refreshes the
	# rows when the authoritative alliance/proposal state actually changes.
