# tests/unit/test_unit_visual.gd
extends GutTest

func test_select_state_priority():
	assert_eq(UnitVisual.select_state(true, 0.2, 0.1, 100.0), UnitVisual.AnimState.EXPLODE)
	assert_eq(UnitVisual.select_state(false, 0.2, 0.1, 100.0), UnitVisual.AnimState.FIRE)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.1, 100.0), UnitVisual.AnimState.HIT)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.0, 100.0), UnitVisual.AnimState.MOVE)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.0, 0.0), UnitVisual.AnimState.IDLE)

func test_state_names_and_frames():
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.MOVE), "move")
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.FIRE), "fire")
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.EXPLODE), "explode")
	assert_eq(UnitVisual.frame_count(UnitVisual.AnimState.MOVE), 6)
	assert_eq(UnitVisual.frame_count(UnitVisual.AnimState.EXPLODE), 8)
	assert_true(UnitVisual.frame_index(UnitVisual.AnimState.MOVE, 0.35, true) >= 0)
	assert_eq(UnitVisual.frame_index(UnitVisual.AnimState.EXPLODE, 10.0, false), 7)

func test_kinematics_and_debris():
	var k_move := UnitVisual.compute_kinematics(UnitVisual.AnimState.MOVE, 0.2, 0)
	assert_true(float(k_move["bob"]) >= 0.0)
	var k_fire := UnitVisual.compute_kinematics(UnitVisual.AnimState.FIRE, 0.02, 1)
	assert_true(float(k_fire["recoil"]) > 0.0)
	assert_true(float(k_fire["muzzle_alpha"]) > 0.0)
	var k_exp := UnitVisual.compute_kinematics(UnitVisual.AnimState.EXPLODE, UnitVisual.explosion_duration() * 0.5, 1)
	assert_almost_eq(float(k_exp["explosion_progress"]), 0.5, 0.05)

	var debris := UnitVisual.generate_Explosion_debris(42, 10)
	assert_eq(debris.size(), 10)
	assert_true(float(debris[0]["speed"]) >= 28.0)

func test_build_unit_frame_image_all_domains():
	for uclass in range(4):
		var img_move := UnitVisual.build_unit_frame_image(uclass, UnitVisual.AnimState.MOVE, 1, Color.BLUE, 32)
		assert_eq(img_move.get_width(), 32)
		assert_eq(img_move.get_height(), 32)
		var img_fire := UnitVisual.build_unit_frame_image(uclass, UnitVisual.AnimState.FIRE, 0, Color.RED, 32)
		assert_eq(img_fire.get_width(), 32)
	var img_exp := UnitVisual.build_unit_frame_image(1, UnitVisual.AnimState.EXPLODE, 3, Color.RED, 32)
	assert_eq(img_exp.get_width(), 32)
