# tests/unit/test_damage.gd
extends GutTest

func test_multiplier_known():
	var m = Damage.multiplier(Damage.DamageType.KINETIC, Damage.ArmorClass.UNARMORED)
	assert_eq(m, 1.2)

func test_compute_basic():
	var d = Damage.compute(10.0, Damage.DamageType.KINETIC, Damage.ArmorClass.UNARMORED, 0.0, 1.0)
	assert_almost_eq(d, 12.0, 0.001)

func test_compute_armor_reduction():
	var d = Damage.compute(10.0, Damage.DamageType.KINETIC, Damage.ArmorClass.UNARMORED, 0.5, 1.0)
	assert_almost_eq(d, 6.0, 0.001)

func test_compute_cover():
	var d = Damage.compute(10.0, Damage.DamageType.KINETIC, Damage.ArmorClass.UNARMORED, 0.0, 0.5)
	assert_almost_eq(d, 6.0, 0.001)

func test_compute_nonnegative():
	var d = Damage.compute(1.0, Damage.DamageType.KINETIC, Damage.ArmorClass.HEAVY, 0.95, 1.0)
	assert_true(d >= 0.0)

func test_is_effective():
	assert_true(Damage.is_effective(Damage.DamageType.EXPLOSIVE, Damage.ArmorClass.UNARMORED))
	assert_false(Damage.is_effective(Damage.DamageType.KINETIC, Damage.ArmorClass.AIR))

func test_submerged_kinetic_zero():
	var m = Damage.multiplier(Damage.DamageType.KINETIC, Damage.ArmorClass.SUBMERGED)
	assert_eq(m, 0.0)
