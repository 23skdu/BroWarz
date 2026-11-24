# tests/unit/test_resource_deposit.gd
extends GutTest

func test_harvest():
	var d = ResourceDeposit.new()
	d.amount = 100
	d.harvest_rate = 10.0
	var got = d.harvest(2.0)
	assert_eq(got, 20)
	assert_eq(d.amount, 80)

func test_deplete():
	var d = ResourceDeposit.new()
	d.amount = 5
	d.harvest_rate = 10.0
	var got = d.harvest(1.0)
	assert_eq(got, 5)
	assert_true(d.is_depleted())
