# tests/unit/test_economy.gd
extends GutTest

func test_empty_wallet():
	var w = Economy.empty_wallet()
	assert_eq(w[Economy.Res.OIL], 0)

func test_can_afford_true():
	var w = Economy.empty_wallet()
	w[Economy.Res.OIL] = 10
	assert_true(Economy.can_afford(w, {Economy.Res.OIL: 5}))

func test_can_afford_false():
	var w = Economy.empty_wallet()
	assert_false(Economy.can_afford(w, {Economy.Res.OIL: 5}))

func test_spend_success():
	var w = Economy.empty_wallet()
	w[Economy.Res.OIL] = 10
	assert_true(Economy.spend(w, {Economy.Res.OIL: 5}))
	assert_eq(w[Economy.Res.OIL], 5)

func test_spend_fail_no_change():
	var w = Economy.empty_wallet()
	w[Economy.Res.OIL] = 3
	assert_false(Economy.spend(w, {Economy.Res.OIL: 5}))
	assert_eq(w[Economy.Res.OIL], 3)

func test_grant():
	var w = Economy.empty_wallet()
	Economy.grant(w, {Economy.Res.IRON: 7})
	assert_eq(w[Economy.Res.IRON], 7)

func test_apply_income():
	var w = Economy.empty_wallet()
	var added = Economy.apply_income(w, {Economy.Res.OIL: 60}, 1.0)
	assert_eq(added[Economy.Res.OIL], 60)
	assert_eq(w[Economy.Res.OIL], 60)

func test_population_cap():
	assert_eq(Economy.population_cap(10, 2, 5), 20)

func test_within_pop_cap():
	assert_true(Economy.within_pop_cap(5, 10))
	assert_false(Economy.within_pop_cap(11, 10))
