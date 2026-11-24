# tests/unit/test_faction.gd
extends GutTest

func test_names():
	assert_eq(Faction.name_of(Faction.Id.AERODYNE), "AeroDyne Industries")

func test_modifiers():
	var m = Faction.modifiers(Faction.Id.VANGUARD)
	assert_true(m.has("stealth_duration"))
	assert_almost_eq(m["stealth_duration"], 1.2, 0.001)

func test_unknown():
	assert_eq(Faction.name_of(999), "Unknown")
	assert_eq(Faction.modifiers(999), {})

func test_color():
	var c = Faction.color_of(Faction.Id.AERODYNE)
	assert_true(c is Color)
	var a = Faction.accent_of(Faction.Id.VANGUARD)
	assert_true(a is Color)
	assert_ne(c, a)

func test_motto():
	assert_ne(Faction.motto_of(Faction.Id.FERROCORE), "")

func test_background():
	assert_ne(Faction.background_of(Faction.Id.PELAGIC), "")

func test_effective_unit_mechanics():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	# FerroCore: +10% tank HP, +25% sapper/engineer speed
	var mbt := reg.get_unit("mbt")
	assert_eq(Faction.effective_max_hp(Faction.Id.FERROCORE, "mbt", mbt.hp), int(round(mbt.hp * 1.1)))
	assert_eq(Faction.effective_max_hp(Faction.Id.AERODYNE, "mbt", mbt.hp), mbt.hp)
	var sapper := reg.get_unit("sapperbot")
	assert_almost_eq(Faction.effective_speed(Faction.Id.FERROCORE, "sapperbot", sapper.speed), sapper.speed * 1.25, 0.001)
	# Vanguard: +20% stealth cloak duration, -10% infantry/mech cost
	assert_almost_eq(Faction.effective_cloak_duration(Faction.Id.VANGUARD, 10.0), 12.0, 0.001)
	var rifle_cost := Faction.effective_unit_cost(Faction.Id.VANGUARD, reg.get_unit("riflebot"))
	assert_eq(int(rifle_cost["iron"]), 45)
	# AeroDyne: -10% air cost
	var fighter_cost := Faction.effective_unit_cost(Faction.Id.AERODYNE, reg.get_unit("fighter_drone"))
	assert_eq(int(fighter_cost["iron"]), int(round(120 * 0.9)))
	# Pelagic: -10% sea cost
	var sub_cost := Faction.effective_unit_cost(Faction.Id.PELAGIC, reg.get_unit("attack_sub"))
	assert_eq(int(sub_cost["iron"]), int(round(190 * 0.9)))
