# tests/unit/test_command.gd
extends GutTest

func test_roundtrip():
	var c = Command.new()
	c.type = Command.Type.ATTACK
	c.tick = 42
	c.player_id = 3
	c.unit_ids = PackedInt32Array([1,2,3])
	c.target_pos = Vector2(10, 20)
	c.target_id = 7
	c.build_type = "barracks"
	var d = c.to_dict()
	var c2 = Command.from_dict(d)
	assert_true(c.equals(c2))

func test_unit_ids_packed():
	var c = Command.new()
	c.unit_ids = PackedInt32Array([5,6])
	var c2 = Command.from_dict(c.to_dict())
	assert_eq(c2.unit_ids.size(), 2)
	assert_eq(c2.unit_ids[1], 6)
