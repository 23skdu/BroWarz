# tests/unit/test_formation.gd
extends GutTest

func test_count():
	var offs = Formation.grid_offsets(4, 10.0)
	assert_eq(offs.size(), 4)

func test_centered():
	var offs = Formation.grid_offsets(4, 10.0)
	var sum = Vector2.ZERO
	for o in offs:
		sum += o
	assert_true(sum.length() < 0.001)

func test_empty():
	var offs = Formation.grid_offsets(0, 10.0)
	assert_eq(offs.size(), 0)

func test_tactical_formations_place_vanguard_ahead_of_standoff():
	var roles: Array[String] = ["standoff", "vanguard", "anti_air", "worker", "vanguard"]
	for style in [Formation.Style.GRID, Formation.Style.WEDGE, Formation.Style.LINE, Formation.Style.ECHELON]:
		var offs := Formation.tactical_offsets(roles, Vector2.RIGHT, style, 30.0)
		assert_eq(offs.size(), roles.size())
		var sum := Vector2.ZERO
		for o in offs:
			sum += o
		assert_true(sum.length() < 0.01, "Formation %s must be centered" % Formation.style_name(style))
		var vanguard_x := (offs[1].x + offs[4].x) * 0.5
		var rear_x := (offs[0].x + offs[3].x) * 0.5
		assert_gt(vanguard_x, rear_x, "Vanguard should lead standoff/worker in %s" % Formation.style_name(style))
	# Heading rotation works along -Y / +Y as well.
	var down_offs := Formation.tactical_offsets(["standoff", "vanguard"], Vector2.DOWN, Formation.Style.WEDGE, 30.0)
	assert_gt(down_offs[1].y, down_offs[0].y)
