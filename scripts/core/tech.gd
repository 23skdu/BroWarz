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
