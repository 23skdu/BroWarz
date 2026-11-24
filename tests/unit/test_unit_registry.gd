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
	assert_true(reg.has_unit("adv_engineerbot"))
	assert_true(reg.has_unit("heavy_mech"))
	assert_true(reg.has_unit("attack_sub"))
	assert_true(reg.has_unit("frogbot"))
	assert_true(reg.has_unit("fighter_drone"))
	assert_true(reg.has_building("hq"))
	assert_true(reg.has_building("docks"))
	assert_true(reg.has_building("mech_factory_1"))
	assert_true(reg.has_building("mech_factory_2"))
	assert_true(reg.has_building("mech_factory_3"))
	assert_true(reg.has_building("shipyard"))
	assert_true(reg.has_building("advanced_shipyard"))
	assert_true(reg.has_building("aeries_1"))
	assert_true(reg.has_building("aeries_2"))
	assert_true(reg.has_building("silo"))
	assert_true(reg.has_building("orbital_uplink"))

func test_builder_requirements_and_producers():
	assert_true(UnitRegistry.requires_advanced_builder("mech_factory_3"))
	assert_true(UnitRegistry.requires_advanced_builder("advanced_shipyard"))
	assert_true(UnitRegistry.requires_advanced_builder("aeries_2"))
	assert_false(UnitRegistry.requires_advanced_builder("mech_factory_1"))
	assert_false(UnitRegistry.can_unit_construct("engineerbot", "mech_factory_3"))
	assert_true(UnitRegistry.can_unit_construct("adv_engineerbot", "mech_factory_3"))
	assert_true(UnitRegistry.can_unit_construct("engineerbot", "mech_factory_2"))
	assert_true(UnitRegistry.can_unit_construct("sapperbot", "wall"))
	assert_true(UnitRegistry.can_unit_construct("sapperbot", "barbed_wire"))
	assert_true(UnitRegistry.can_unit_construct("sapperbot", "missile_tower"))
	assert_false(UnitRegistry.can_unit_construct("sapperbot", "mech_factory_1"))
	assert_true("mech_factory_2" in UnitRegistry.producer_ids_for_unit("adv_engineerbot", 0))
	assert_true("mech_factory_3" in UnitRegistry.producer_ids_for_unit("heavy_mech", 7))
	assert_true("docks" in UnitRegistry.producer_ids_for_unit("frogbot", 5))
	assert_true("advanced_shipyard" in UnitRegistry.producer_ids_for_unit("battleship", 2))
	assert_true("aeries_2" in UnitRegistry.producer_ids_for_unit("bomber_drone", 3))

func test_transport_capacity_and_embark_rules():
	assert_eq(UnitRegistry.transport_capacity("landing_craft"), 4)
	assert_eq(UnitRegistry.transport_capacity("apc"), 3)
	assert_eq(UnitRegistry.transport_capacity("hovercraft"), 2)
	assert_eq(UnitRegistry.transport_capacity("aircraft_carrier"), 4)
	assert_eq(UnitRegistry.transport_capacity("riflebot"), 0)
	assert_true(UnitRegistry.can_embark("landing_craft", "riflebot", 0))
	assert_true(UnitRegistry.can_embark("landing_craft", "frogbot", 5))
	assert_true(UnitRegistry.can_embark("apc", "heavybot", 6))
	assert_false(UnitRegistry.can_embark("landing_craft", "mbt", 1))
	assert_true(UnitRegistry.can_embark("aircraft_carrier", "fighter_drone", 3))
	assert_false(UnitRegistry.can_embark("aircraft_carrier", "riflebot", 0))
