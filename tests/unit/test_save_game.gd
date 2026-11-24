# tests/unit/test_save_game.gd
extends GutTest

func test_roundtrip():
	var s = SaveGame.new()
	s.version = 2
	s.game_state = {"tick": 5}
	s.settings = {"vol": 0.5}
	var d = s.to_dict()
	var s2 = SaveGame.from_dict(d)
	assert_eq(s2.version, 2)
	assert_eq(s2.game_state["tick"], 5)
	assert_eq(s2.settings["vol"], 0.5)
