# tests/unit/test_settings_store.gd
extends GutTest

func test_set_get():
	var s = SettingsStore.new()
	s.set_value("vol", 0.8)
	assert_eq(s.get_value("vol"), 0.8)

func test_default():
	var s = SettingsStore.new()
	assert_eq(s.get_value("missing", 5), 5)

func test_roundtrip():
	var s = SettingsStore.new()
	s.set_value("a", 1)
	var s2 = SettingsStore.from_dict(s.to_dict())
	assert_eq(s2.get_value("a"), 1)
