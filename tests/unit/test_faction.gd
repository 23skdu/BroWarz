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
