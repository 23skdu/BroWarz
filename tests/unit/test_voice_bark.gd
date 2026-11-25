# tests/unit/test_voice_bark.gd
extends GutTest

const VoiceBarkRef := preload("res://scripts/core/voice_bark.gd")

func test_all_bark_events_have_existing_sfx_and_subtitles():
	var events: Array[String] = VoiceBarkRef.all_events()
	assert_gt(events.size(), 10)
	for ev in events:
		var clip: String = VoiceBarkRef.sfx_for_event(ev)
		assert_ne(clip, "")
		assert_true(ResourceLoader.exists("res://assets/sfx/%s.wav" % clip), "missing WAV for %s (%s)" % [ev, clip])
		var sub: String = VoiceBarkRef.subtitle_for(ev, Faction.Id.AERODYNE, "TestSubject")
		assert_true(sub.begins_with("[AeroDyne]"))
		assert_gt(sub.length(), 12)

func test_per_weapon_damage_types_map_to_distinct_existing_wavs():
	var seen: Dictionary = {}
	for dmg_type in [
		Damage.DamageType.KINETIC, Damage.DamageType.EXPLOSIVE,
		Damage.DamageType.ENERGY, Damage.DamageType.EMP,
		Damage.DamageType.THERMAL, Damage.DamageType.TOXIC,
	]:
		var clip: String = VoiceBarkRef.weapon_sfx_for_damage_type(dmg_type)
		assert_false(seen.has(clip), "duplicate weapon clip: %s" % clip)
		seen[clip] = true
		assert_true(ResourceLoader.exists("res://assets/sfx/%s.wav" % clip), "missing weapon WAV: %s" % clip)
	assert_eq(seen.size(), 6)

func test_faction_flavor_and_cooldown_throttling():
	assert_true(VoiceBarkRef.subtitle_for("select", Faction.Id.FERROCORE).contains("FerroCore"))
	assert_true(VoiceBarkRef.subtitle_for("move", Faction.Id.PELAGIC).contains("Pelagic"))
	assert_true(VoiceBarkRef.subtitle_for("attack", Faction.Id.VANGUARD).contains("Vanguard"))
	assert_true(VoiceBarkRef.subtitle_for("select", Faction.Id.VESPER).contains("Vesper"))
	assert_true(VoiceBarkRef.subtitle_for("build_complete", Faction.Id.AERODYNE, "Riflebot").contains("Riflebot"))
	assert_true(VoiceBarkRef.can_emit(-1.0, 0.0, 1.8))
	assert_false(VoiceBarkRef.can_emit(10.0, 11.0, 1.8))
	assert_true(VoiceBarkRef.can_emit(10.0, 12.0, 1.8))
