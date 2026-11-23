# tests/unit/test_unit_registry.gd
extends GutTest

func test_register_unit():
	var reg = UnitRegistry.new()
	var s = UnitStats.new()
	s.id = "riflebot"
	reg.register_unit(s)
	assert_true(reg.has_unit("riflebot"))
	assert_eq(reg.get_unit("riflebot"), s)

func test_missing():
	var reg = UnitRegistry.new()
	assert_false(reg.has_unit("x"))
	assert_null(reg.get_unit("x"))

func test_populate_defaults():
	var reg = UnitRegistry.new()
	reg.populate_defaults()
	assert_true(reg.has_unit("riflebot"))
	assert_true(reg.has_unit("heavy_mech"))
	assert_true(reg.has_unit("attack_sub"))
	assert_true(reg.has_unit("fighter_drone"))
	assert_true(reg.has_building("hq"))
	assert_true(reg.has_building("silo"))
	assert_true(reg.has_building("orbital_uplink"))

