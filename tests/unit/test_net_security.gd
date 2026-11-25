# tests/unit/test_net_security.gd
extends GutTest

func test_sanitize_name_valid():
	assert_eq(NetSecurity.sanitize_name("Alice-01"), "Alice-01")

func test_sanitize_name_strips_bad_chars():
	assert_eq(NetSecurity.sanitize_name("A!l#i%c^e"), "Alice")

func test_sanitize_name_too_short():
	assert_eq(NetSecurity.sanitize_name("A"), "")

func test_is_valid_address_ipv4():
	assert_true(NetSecurity.is_valid_address("192.168.1.10"))

func test_is_valid_address_rejects_slash():
	assert_false(NetSecurity.is_valid_address("1.2.3.4/evil"))

func test_mask_address_ipv4():
	assert_eq(NetSecurity.mask_address("192.168.1.10"), "192.168.1.*")

func test_constant_time_equal():
	assert_true(NetSecurity.constant_time_equal("secret", "secret"))
	assert_false(NetSecurity.constant_time_equal("secret", "Secret"))

func test_sanitize_settings_clamps():
	var out := NetSecurity.sanitize_settings({"map_type": 99, "num_teams": 1, "fog_of_war": true, "transport": "webrtc", "evil": 1})
	assert_eq(out["map_type"], 2)
	assert_eq(out["num_teams"], 2)
	assert_true(out["fog_of_war"])
	assert_eq(out["transport"], "webrtc")
	assert_false(out.has("evil"))

func test_sanitize_command_move():
	var c := NetSecurity.sanitize_command({"type": "move", "seq": 5, "unit_ids": [1, 2], "target_x": 10.0, "target_y": 20.0, "attack_move": true})
	assert_false(c.is_empty())
	assert_eq(c["type"], "move")
	assert_eq(c["seq"], 5)

func test_sanitize_command_rejects_unknown_type():
	assert_true(NetSecurity.sanitize_command({"type": "hack", "seq": 1}).is_empty())

func test_new_token_length():
	assert_eq(NetSecurity.new_token(8).length(), 16)

func test_validate_hello_protocol_mismatch():
	var v := NetSecurity.validate_hello(999, "x", "Alice", "1.2.3.4", "")
	assert_false(v["ok"])
func test_sanitize_capture_and_demolish_commands():
	var cap := NetSecurity.sanitize_command({
		"type": "capture", "seq": 6, "unit_ids": [1, 2], "target_x": 32.0, "target_y": 48.0,
	})
	assert_false(cap.is_empty())
	assert_eq(cap["unit_ids"].size(), 2)
	assert_eq(cap["x"], 32.0)
	assert_eq(cap["y"], 48.0)
	assert_true(NetSecurity.sanitize_command({
		"type": "capture", "seq": 7, "unit_ids": [], "target_x": 32.0, "target_y": 48.0,
	}).is_empty())
	var demo := NetSecurity.sanitize_command({"type": "demolish", "seq": 8, "x": 20.0, "y": 30.0})
	assert_false(demo.is_empty())
	assert_eq(demo["x"], 20.0)
	assert_eq(demo["y"], 30.0)

func test_sanitize_diplomacy_command():
	var cmd := NetSecurity.sanitize_command({
		"type": "diplomacy", "seq": 9, "action": "propose", "target_team": 2,
	})
	assert_false(cmd.is_empty())
	assert_eq(cmd["action"], "propose")
	assert_eq(cmd["target_team"], 2)
	assert_true(NetSecurity.sanitize_command({
		"type": "diplomacy", "seq": 10, "action": "hack", "target_team": 2,
	}).is_empty())
	assert_true(NetSecurity.sanitize_command({
		"type": "diplomacy", "seq": 11, "action": "accept", "target_team": -1,
	}).is_empty())
	assert_true(NetSecurity.sanitize_command({
		"type": "diplomacy", "seq": 12, "action": "accept", "target_team": 0,
	}).has("target_team"))
