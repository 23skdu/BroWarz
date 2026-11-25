# scripts/core/replay.gd
class_name Replay
extends RefCounted

var seed: int = 0
var map_name: String = ""
var commands: Array = []  # Array of validated Command.to_dict()
var ticks: int = 0
var invalid_commands: int = 0

func record(cmd: Command) -> void:
	commands.append(cmd.to_dict())
	if cmd.tick > ticks:
		ticks = cmd.tick

func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"map_name": map_name,
		"ticks": ticks,
		"commands": commands.duplicate(true),
	}

## Reject malformed command records before they reach the viewer/playback UI.
static func is_valid_command(raw: Variant) -> bool:
	if not (raw is Dictionary):
		return false
	var c := raw as Dictionary
	var tv: Variant = c.get("type", -1)
	var tickv: Variant = c.get("tick", -1)
	if not ((tv is int) or (tv is float)) or not ((tickv is int) or (tickv is float)):
		return false
	if int(c["type"]) < 0 or int(c["type"]) > Command.Type.DEMOLISH:
		return false
	if int(c["tick"]) < 0:
		return false
	var ids: Variant = c.get("unit_ids", [])
	if ids != null and not (ids is Array):
		return false
	return true

static func from_dict(d: Dictionary) -> Replay:
	var r = Replay.new()
	r.seed = int(d.get("seed", 0))
	r.map_name = String(d.get("map_name", ""))
	r.ticks = int(d.get("ticks", 0))
	var raw_commands: Variant = d.get("commands", [])
	if raw_commands is Array:
		for entry in (raw_commands as Array):
			if is_valid_command(entry):
				r.commands.append((entry as Dictionary).duplicate(true))
			else:
				r.invalid_commands += 1
	return r

func command_count() -> int:
	return commands.size()
