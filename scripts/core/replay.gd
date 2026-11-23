# scripts/core/replay.gd
class_name Replay
extends RefCounted

var seed: int = 0
var map_name: String = ""
var commands: Array = []  # Array of Command.to_dict()
var ticks: int = 0

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

static func from_dict(d: Dictionary) -> Replay:
	var r = Replay.new()
	r.seed = int(d.get("seed", 0))
	r.map_name = String(d.get("map_name", ""))
	r.ticks = int(d.get("ticks", 0))
	r.commands = d.get("commands", []).duplicate(true)
	return r

func command_count() -> int:
	return commands.size()
