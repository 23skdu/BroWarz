# tests/unit/test_gut_orphan_guard.gd
extends GutTest

class FakeCounter extends RefCounted:
	var count: int = 0
	var recorded: Array[String] = []

	func record_orphans(group, _subgroup = null) -> Array:
		recorded.append(str(group))
		return []

	func orphan_count() -> int:
		return count

class FakeLogger extends RefCounted:
	var errors: Array[String] = []
	var infos: Array[String] = []

	func error(text) -> void:
		errors.append(str(text))

	func info(text) -> void:
		infos.append(str(text))

class FakeGut extends RefCounted:
	var counter := FakeCounter.new()
	var logger := FakeLogger.new()

	func get_orphan_counter() -> Object:
		return counter

func _run_guard(count: int) -> Dictionary:
	var guard = load("res://scripts/testing/gut_orphan_guard.gd").new()
	var fake := FakeGut.new()
	fake.counter.count = count
	guard.gut = fake
	guard.run()
	return {"guard": guard, "fake": fake}

func test_guard_fails_when_orphans_are_present():
	var result := _run_guard(1)
	var guard = result["guard"]
	var fake = result["fake"]
	assert_eq(guard.get_exit_code(), 1)
	assert_eq(fake.counter.recorded, ["post_run"])
	assert_eq(fake.logger.errors.size(), 1)

func test_guard_passes_when_tree_is_clean():
	var result := _run_guard(0)
	var guard = result["guard"]
	var fake = result["fake"]
	assert_null(guard.get_exit_code())
	assert_eq(fake.logger.infos.size(), 1)
	assert_eq(fake.logger.errors.size(), 0)
