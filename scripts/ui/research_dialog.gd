class_name ResearchDialog
extends AcceptDialog

## Full research tree picker. Every node is shown with its prerequisites,
## researched state and live affordability so players can plan a branch
## instead of guessing what the next available node will be.

signal research_selected(node_id: String)

var _tech_tree: VBoxContainer = null

func populate(unlocked: Array, wallet: Dictionary, has_lab: bool = false) -> void:
	title = "Research Tree"
	get_ok_button().text = "Close"
	if _tech_tree != null and is_instance_valid(_tech_tree):
		remove_child(_tech_tree)
		_tech_tree.free()
		_tech_tree = null
	var vbox := VBoxContainer.new()
	vbox.name = "TechTree"
	vbox.custom_minimum_size = Vector2(560, 0)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	_tech_tree = vbox

	var header := Label.new()
	header.text = "Research Lab: %s" % ("ONLINE" if has_lab else "REQUIRED — build one to unlock research")
	vbox.add_child(header)

	for nid in Tech.TREE.keys():
		var node_id := str(nid)
		var info: Dictionary = Tech.node_info(node_id)
		var requires: Array = info.get("requires", [])
		var cost: Dictionary = info.get("cost", {})
		var researched := unlocked.has(node_id)
		var prereq_ok := Tech.can_research(unlocked, requires)
		var affordable := Tech.research_cost_affordable(wallet, cost)
		var status := "READY"
		if researched:
			status = "RESEARCHED"
		elif not has_lab:
			status = "NEEDS LAB"
		elif not prereq_ok:
			status = "REQUIRES %s" % ", ".join(PackedStringArray(_names_of(requires)))
		elif not affordable:
			status = "INSUFFICIENT RESOURCES"
		var b := Button.new()
		b.name = "Tech_%s" % node_id
		b.text = "%s — %s | %s" % [String(info.get("name", node_id)), _cost_label(cost), status]
		b.disabled = researched or not has_lab or not prereq_ok or not affordable
		var chosen := node_id
		b.pressed.connect(func(): research_selected.emit(chosen))
		vbox.add_child(b)

func _names_of(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		var info: Dictionary = Tech.node_info(str(id))
		out.append(String(info.get("name", str(id))))
	return out

func _cost_label(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		var amt := int(cost.get(res, 0))
		if amt > 0:
			var label: String = ["Oil", "Iron", "Geo", "Food"][res]
			parts.append("%d %s" % [amt, label])
	return ", ".join(parts) if not parts.is_empty() else "free"
