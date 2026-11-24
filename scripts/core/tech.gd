# scripts/core/tech.gd
class_name Tech
extends RefCounted

# Tech nodes: Dictionary id -> { "requires": Array of ids, "cost": Dictionary }

static func can_research(unlocked: Array, node_requires: Array) -> bool:
	for req in node_requires:
		if not unlocked.has(req):
			return false
	return true

static func unlock(unlocked: Array, node_id: String) -> bool:
	if unlocked.has(node_id):
		return false
	unlocked.append(node_id)
	return true

static func research_cost_affordable(wallet: Dictionary, cost: Dictionary) -> bool:
	# reuse Economy logic inline
	for k in cost.keys():
		if int(wallet.get(k, 0)) < int(cost.get(k, 0)):
			return false
	return true

const TREE := {
	"reactive_armor": {
		"name": "Reactive Armor (+15% Armor HP)",
		"requires": [],
		"cost": {1: 120, 0: 60},
	},
	"railgun_cal": {
		"name": "Railgun Calibration (+15% Weapon Dmg)",
		"requires": [],
		"cost": {1: 140, 2: 50},
	},
	"cloak_caps": {
		"name": "Cloak Capacitors (+25% Stealth Duration)",
		"requires": ["railgun_cal"],
		"cost": {0: 100, 2: 90},
	},
	"super_heavy": {
		"name": "Super-Heavy Chassis (T3 Factories)",
		"requires": ["reactive_armor"],
		"cost": {1: 220, 0: 140, 2: 80},
	},
	"strategic_uplinks": {
		"name": "Strategic Uplinks (Orbital & Nuke)",
		"requires": ["super_heavy", "railgun_cal"],
		"cost": {1: 300, 0: 200, 2: 180},
	},
}

static func node_info(node_id: String) -> Dictionary:
	return TREE.get(node_id, {})

static func available_nodes(unlocked: Array) -> Array[String]:
	var out: Array[String] = []
	for nid in TREE.keys():
		if unlocked.has(nid):
			continue
		var info: Dictionary = TREE[nid]
		if can_research(unlocked, info.get("requires", [])):
			out.append(str(nid))
	return out
