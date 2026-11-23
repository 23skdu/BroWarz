# tests/fuzz/test_economy_fuzz.gd
extends GutTest

func test_spend_never_negative_fuzz():
	for i in range(200):
		var w = Economy.empty_wallet()
		w[Economy.Res.OIL] = randi() % 50
		var cost = randi() % 60
		var ok = Economy.spend(w, {Economy.Res.OIL: cost})
		if ok:
			assert_true(w[Economy.Res.OIL] >= 0)
		else:
			assert_true(w[Economy.Res.OIL] >= 0)

func test_can_afford_consistency_fuzz():
	for i in range(200):
		var w = Economy.empty_wallet()
		w[Economy.Res.IRON] = randi() % 50
		var cost = randi() % 60
		var c = {Economy.Res.IRON: cost}
		var affordable = Economy.can_afford(w, c)
		# spending should succeed iff affordable
		var w2 = w.duplicate()
		var spent = Economy.spend(w2, c)
		assert_eq(affordable, spent)
