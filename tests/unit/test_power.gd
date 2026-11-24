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

func test_power_efficiency_does_not_compound_rates():
	ResourceManager.init_player(98, {})
	ResourceManager.set_rate(98, Economy.Res.IRON, 32)
	ResourceManager.set_power_efficiency(98, 0.9)
	assert_eq(ResourceManager.rates[98][Economy.Res.IRON], 29)
	assert_eq(ResourceManager.get_base_rate(98, Economy.Res.IRON), 32)
	# Re-applying the same brownout must not shrink the rate again.
	ResourceManager.set_power_efficiency(98, 0.9)
	assert_eq(ResourceManager.rates[98][Economy.Res.IRON], 29)
	ResourceManager.set_power_efficiency(98, 1.0)
	assert_eq(ResourceManager.rates[98][Economy.Res.IRON], 32)
	# New extractor output compounds on the base rate, not the scaled rate.
	ResourceManager.set_rate(98, Economy.Res.IRON, 44)
	ResourceManager.set_power_efficiency(98, 0.9)
	assert_eq(ResourceManager.rates[98][Economy.Res.IRON], 40)
	ResourceManager.wallets.erase(98)
	ResourceManager.base_rates.erase(98)
	ResourceManager.rates.erase(98)
	ResourceManager.power_efficiency.erase(98)