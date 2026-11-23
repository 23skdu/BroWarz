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
