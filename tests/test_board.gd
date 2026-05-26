@tool
extends McpTestSuite

func suite_name() -> String:
	return "board"

func _unit() -> BattleUnit:
	return BattleUnit.new(MonsterData.create(&"x", "X", 1, 5, 1, 1, 1), 0, Vector2i.ZERO)

func test_bounds() -> void:
	var b := Board.new(7, 7)
	assert_true(b.is_in_bounds(Vector2i(0, 0)))
	assert_true(b.is_in_bounds(Vector2i(6, 6)))
	assert_false(b.is_in_bounds(Vector2i(7, 0)))
	assert_false(b.is_in_bounds(Vector2i(-1, 3)))

func test_place_and_query() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(2, 3))
	assert_true(b.is_occupied(Vector2i(2, 3)))
	assert_eq(b.get_unit_at(Vector2i(2, 3)), u)
	assert_eq(u.grid_pos, Vector2i(2, 3))

func test_relocate_moves_occupancy() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(2, 3))
	b.relocate_unit(u, Vector2i(4, 4))
	assert_false(b.is_occupied(Vector2i(2, 3)))
	assert_true(b.is_occupied(Vector2i(4, 4)))
	assert_eq(u.grid_pos, Vector2i(4, 4))

func test_remove_clears_occupancy() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(1, 1))
	b.remove_unit(u)
	assert_false(b.is_occupied(Vector2i(1, 1)))
	assert_eq(b.get_unit_at(Vector2i(1, 1)), null)
