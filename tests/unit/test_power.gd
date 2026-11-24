# tests/unit/test_power.gd
extends GutTest

func test_balance():
	assert_eq(Power.balance(10.0, 4.0), 6.0)
	assert_eq(Power.balance(3.0, 7.0), -4.0)

func test_is_powered():
	assert_true(Power.is_powered(0.0))
	assert_true(Power.is_powered(5.0))
	assert_false(Power.is_powered(-1.0))

func test_efficiency():
	assert_eq(Power.efficiency(5.0), 1.0)
	var e := Power.efficiency(-40.0)
	assert_true(e > 0.0 and e <= 1.0)

func test_building_power_delta():
	assert_eq(Power.building_power_delta("power_plant"), 40.0)
	assert_eq(Power.building_power_delta("radar"), -12.0)
	assert_eq(Power.building_power_delta("nothing"), 0.0)

func test_team_power_summary():
	var s := Power.team_power_summary(["power_plant", "radar", "turret"])
	assert_true(s.has("balance"))
	assert_true(s.has("efficiency"))
	assert_true(s.has("powered"))

func test_resource_manager_power_efficiency():
	ResourceManager.init_player(99, {})
	assert_has(ResourceManager.power_efficiency, 99)
	ResourceManager.power_efficiency.erase(99)