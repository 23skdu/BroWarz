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
	assert_eq(UnitRegistry.transport_capacity("leviathan_carrier"), 4)
	assert_true(UnitRegistry.can_embark("leviathan_carrier", "fighter_drone", 3))
	assert_false(UnitRegistry.can_embark("leviathan_carrier", "riflebot", 0))

func test_npc_unique_units_metadata_and_producers():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	var total_npc := 0
	for fac_id in Faction.npc_ids():
		var roster := reg.units_for_faction(fac_id)
		assert_eq(roster.size(), 3)
		for uid in roster:
			total_npc += 1
			assert_true(UnitRegistry.is_ai_only(str(uid)))
			assert_eq(UnitRegistry.npc_faction_for_unit(str(uid)), fac_id)
			var s := reg.get_unit(str(uid))
			assert_not_null(s)
			assert_true(s.ai_only)
			assert_eq(s.native_faction, fac_id)
			assert_gt(UnitRegistry.producer_ids_for_unit(str(uid), s.unit_class).size(), 0)
	assert_eq(total_npc, 12)
	var human_roster := reg.units_for_faction(Faction.Id.AERODYNE)
	assert_false(human_roster.has("ufo_wisp"))
	assert_false(UnitRegistry.is_ai_only("riflebot"))
	assert_true(UnitRegistry.is_scout_unit("ufo_wisp"))
	assert_true(UnitRegistry.is_scout_unit("lumen_oracle"))
