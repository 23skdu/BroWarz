class_name ResearchDialog
extends AcceptDialog

## Small node picker for the research tree. Buttons show prerequisites and
## live affordability; selection is handed back to the game scene to spend.

signal research_selected(node_id: String)

func populate(unlocked: Array, wallet: Dictionary) -> void:
	title = "Research Tree"
	get_ok_button().text = "Close"
	for child in get_children():
		if child is Control and child != get_ok_button():
			child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	add_child(vbox)
	var avail: Array = Tech.available_nodes(unlocked)
	if avail.is_empty():
		var none := Label.new()
		none.text = "All available nodes researched."
		vbox.add_child(none)
		return
	for nid in avail:
		var info: Dictionary = Tech.node_info(str(nid))
		var cost: Dictionary = info.get("cost", {})
		var affordable := Tech.research_cost_affordable(wallet, cost)
		var b := Button.new()
		b.text = "%s — %s" % [String(info.get("name", str(nid))), _cost_label(cost)]
		b.disabled = not affordable
		var chosen := str(nid)
		b.pressed.connect(func():
			research_selected.emit(chosen)
			hide()
			queue_free()
		)
		vbox.add_child(b)

func _cost_label(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		var amt := int(cost.get(res, 0))
		if amt > 0:
			var label: String = ["Oil", "Iron", "Geo", "Food"][res]
			parts.append("%d %s" % [amt, label])
	return ", ".join(parts) if not parts.is_empty() else "free"
