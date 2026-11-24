# tests/unit/test_fortifications.gd
extends GutTest

func test_ids_listed():
	for id in Fortification.IDS:
		assert_true(Fortification.is_fortification(id))

func test_wall_blocks_ground_and_infantry():
	assert_true(Fortification.blocks_unit("wall", 0))
	assert_true(Fortification.blocks_unit("wall", 1))
	assert_false(Fortification.blocks_unit("wall", 3))  # air
	assert_false(Fortification.blocks_unit("wall", 2))  # naval

func test_wire_blocks_infantry_only():
	assert_true(Fortification.blocks_unit("barbed_wire", 0))
	assert_false(Fortification.blocks_unit("barbed_wire", 1))

func test_missile_tower_anti_air():
	assert_true(Fortification.is_anti_air("missile_tower"))
	assert_false(Fortification.is_anti_air("wall"))

func test_missile_tower_does_not_block_movement():
	assert_false(Fortification.blocks_movement("missile_tower"))

func test_mask_blocks_unit():
	var mask := Fortification.BLOCK_INFANTRY | Fortification.BLOCK_GROUND
	assert_true(Fortification.mask_blocks_unit(mask, 0))
	assert_true(Fortification.mask_blocks_unit(mask, 1))
	assert_false(Fortification.mask_blocks_unit(mask, 3))