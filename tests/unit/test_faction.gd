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

func test_colorblind_and_mirror_colors():
	var base := Faction.color_of(Faction.Id.AERODYNE)
	assert_eq(Faction.colorblind_color_of(Faction.Id.AERODYNE, "none"), base)
	assert_ne(Faction.colorblind_color_of(Faction.Id.AERODYNE, "deuteranopia"), base)
	assert_ne(Faction.colorblind_color_of(Faction.Id.FERROCORE, "tritanopia"), Faction.color_of(Faction.Id.FERROCORE))
	# Mirror matches keep chess black/white even with a colorblind palette.
	assert_eq(Faction.colorblind_color_of(Faction.Id.AERODYNE, "deuteranopia", 1), Faction.color_of(Faction.Id.AERODYNE, 1))
	assert_eq(Faction.colorblind_color_of(Faction.Id.AERODYNE, "tritanopia", 2), Faction.color_of(Faction.Id.AERODYNE, 2))
	assert_eq(Faction.color_for_team(Faction.Id.AERODYNE, 0), 0)
	assert_eq(Faction.color_for_team(Faction.Id.AERODYNE, 1), 2)

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

func test_npc_factions_identity_banners_and_sets():
	assert_eq(Faction.human_ids(), [0, 1, 2, 3])
	assert_eq(Faction.npc_ids(), [4, 5, 6, 7])
	assert_eq(Faction.ai_ids(), [0, 1, 2, 3, 4, 5, 6, 7])
	for id in Faction.human_ids():
		assert_false(Faction.is_npc(id))
		assert_true(ResourceLoader.exists(Faction.banner_path(id)))
	var expected_names := {
		Faction.Id.VESPER: "Vesper Ascendancy",
		Faction.Id.THALASSA: "Thalassa Dominion",
		Faction.Id.GRAVEBOUND: "Gravebound Legion",
		Faction.Id.LUMEN: "Lumen Cabal",
	}
	for id in Faction.npc_ids():
		assert_true(Faction.is_npc(id))
		assert_eq(Faction.name_of(id), expected_names[id])
		assert_ne(Faction.motto_of(id), "")
		assert_ne(Faction.background_of(id), "")
		assert_ne(Faction.theme_key(id), "")
		assert_true(ResourceLoader.exists(Faction.banner_path(id)))
		assert_eq(Faction.logo_path(id), Faction.banner_path(id))
		var pc := Faction.pros_cons(id)
		assert_gt((pc["pros"] as Array).size(), 0)
		assert_gt((pc["cons"] as Array).size(), 0)
		assert_ne(Faction.colorblind_color_of(id, "deuteranopia"), Faction.color_of(id))
		assert_ne(Faction.colorblind_color_of(id, "tritanopia"), Faction.color_of(id))

func test_npc_faction_combat_and_cost_modifiers():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	# Vesper: +20% air damage, +30% air speed, -20% non-air HP
	var talon := reg.get_unit("ufo_talon")
	var mbt := reg.get_unit("mbt")
	assert_almost_eq(Faction.damage_multiplier(Faction.Id.VESPER, talon.id, talon.unit_class), 1.2, 0.001)
	assert_almost_eq(Faction.speed_multiplier(Faction.Id.VESPER, talon.id, talon.unit_class), 1.3, 0.001)
	assert_eq(Faction.effective_max_hp(Faction.Id.VESPER, mbt.id, mbt.hp, mbt.unit_class), int(round(mbt.hp * 0.8)))
	assert_eq(Faction.effective_max_hp(Faction.Id.VESPER, talon.id, talon.hp, talon.unit_class), talon.hp)
	# Thalassa: +25% naval HP, +15% naval dmg, -10% sea cost, -15% land/air dmg
	var trireme := reg.get_unit("abyssal_trireme")
	assert_eq(Faction.effective_max_hp(Faction.Id.THALASSA, trireme.id, trireme.hp, trireme.unit_class), int(round(trireme.hp * 1.25)))
	assert_almost_eq(Faction.damage_multiplier(Faction.Id.THALASSA, trireme.id, trireme.unit_class), 1.15, 0.001)
	assert_almost_eq(Faction.damage_multiplier(Faction.Id.THALASSA, "riflebot", 0), 0.85, 0.001)
	var tri_cost := Faction.effective_unit_cost(Faction.Id.THALASSA, trireme)
	assert_eq(int(tri_cost["iron"]), int(round(trireme.cost_iron * 0.9)))
	# Gravebound: +20% infantry HP, -15% infantry cost, -15% sight, -20% vehicle/air HP
	var bone := reg.get_unit("bone_legionary")
	assert_eq(Faction.effective_max_hp(Faction.Id.GRAVEBOUND, bone.id, bone.hp, bone.unit_class), int(round(bone.hp * 1.2)))
	assert_almost_eq(Faction.sight_multiplier(Faction.Id.GRAVEBOUND, bone.id, bone.unit_class), 0.85, 0.001)
	var bone_cost := Faction.effective_unit_cost(Faction.Id.GRAVEBOUND, bone)
	assert_eq(int(bone_cost["iron"]), int(round(bone.cost_iron * 0.85)))
	assert_eq(Faction.effective_max_hp(Faction.Id.GRAVEBOUND, mbt.id, mbt.hp, mbt.unit_class), int(round(mbt.hp * 0.8)))
	# Lumen: +25% sight, +30% stealth duration, +10% all cost, -10% all HP
	var op := reg.get_unit("lumen_operative")
	assert_almost_eq(Faction.sight_multiplier(Faction.Id.LUMEN, op.id, op.unit_class), 1.25, 0.001)
	assert_almost_eq(Faction.effective_cloak_duration(Faction.Id.LUMEN, 10.0), 13.0, 0.001)
	assert_eq(Faction.effective_max_hp(Faction.Id.LUMEN, op.id, op.hp, op.unit_class), int(round(op.hp * 0.9)))
	var op_cost := Faction.effective_unit_cost(Faction.Id.LUMEN, op)
	assert_eq(int(op_cost["iron"]), int(round(op.cost_iron * 1.1)))
