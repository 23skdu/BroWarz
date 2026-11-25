# tests/unit/test_sonar_buoy.gd
extends GutTest

func test_buoy_lifetime_and_radius():
	var buoy := SonarBuoy.make(0, 42, Vector2(100, 200), 10.0)
	assert_eq(buoy["owner_team"], 0)
	assert_eq(buoy["owner_id"], 42)
	assert_almost_eq(float(buoy["radius_px"]), SonarBuoy.RADIUS_PX, 0.001)
	assert_true(SonarBuoy.is_active(buoy, 10.0))
	assert_true(SonarBuoy.is_active(buoy, 84.9))
	assert_false(SonarBuoy.is_active(buoy, 85.1))

func test_buoy_reveals_only_allied_submerged_contacts_in_range():
	var buoy := SonarBuoy.make(0, 42, Vector2(100, 200), 0.0)
	assert_true(SonarBuoy.reveals_sub(buoy, 0, Vector2(300, 200), true))
	assert_true(SonarBuoy.reveals_sub(buoy, 0, Vector2(410, 200), true))
	assert_false(SonarBuoy.reveals_sub(buoy, 0, Vector2(430, 200), true))
	assert_false(SonarBuoy.reveals_sub(buoy, 0, Vector2(100, 200), false))
	assert_false(SonarBuoy.reveals_sub(buoy, 1, Vector2(100, 200), true))
	var saved: Dictionary = GameManager.alliances.duplicate(true)
	GameManager.alliances = {0: [1], 1: [0]}
	assert_true(SonarBuoy.reveals_sub(buoy, 1, Vector2(100, 200), true))
	GameManager.alliances = saved

func test_deploy_contract_constants_are_sane():
	assert_gt(SonarBuoy.RADIUS_PX, SonarBuoy.DEPLOY_RANGE_PX)
	assert_gt(SonarBuoy.LIFETIME_SEC, SonarBuoy.COOLDOWN_SEC)
