# scripts/core/command.gd
class_name Command
extends RefCounted

enum Type {
	MOVE, ATTACK, ATTACK_MOVE, BUILD, STOP, PATROL, HOLD,
	TRAIN, FORTIFY, EMBARK, DISEMBARK, TECH, ORBITAL, NUKE,
	CAPTURE, DEMOLISH, DIPLOMACY, SONAR_BUOY,
	GUARD, CHAT, SURRENDER,
}

var type: Type = Type.MOVE
var tick: int = 0
var player_id: int = 0
var unit_ids: PackedInt32Array = PackedInt32Array()
var target_pos: Vector2 = Vector2.ZERO
var target_id: int = -1
var build_type: String = ""

func to_dict() -> Dictionary:
	return {
		"type": type,
		"tick": tick,
		"player_id": player_id,
		"unit_ids": Array(unit_ids),
		"target_pos": {"x": target_pos.x, "y": target_pos.y},
		"target_id": target_id,
		"build_type": build_type,
	}

static func from_dict(d: Dictionary) -> Command:
	var c := Command.new()
	c.type = int(d.get("type", 0)) as Type
	c.tick = int(d.get("tick", 0))
	c.player_id = int(d.get("player_id", 0))
	var arr: Array = d.get("unit_ids", [])
	var pa := PackedInt32Array()
	for v in arr:
		pa.append(int(v))
	c.unit_ids = pa
	var tp: Dictionary = d.get("target_pos", {})
	c.target_pos = Vector2(float(tp.get("x", 0)), float(tp.get("y", 0)))
	c.target_id = int(d.get("target_id", -1))
	c.build_type = String(d.get("build_type", ""))
	return c

func equals(other: Command) -> bool:
	return to_dict() == other.to_dict()
