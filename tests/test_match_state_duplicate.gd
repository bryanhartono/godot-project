@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_state_duplicate"

func _make_state() -> MatchState:
	var s := MatchState.new(Board.new(7, 7))
	var d0 := MonsterData.create(&"a", "A", 2, 8, 3, 2, 1)
	var d1 := MonsterData.create(&"b", "B", 2, 6, 2, 2, 1)
	s.add_unit(BattleUnit.new(d0, 0, Vector2i(1, 1)), Vector2i(1, 1))
	s.add_unit(BattleUnit.new(d1, 1, Vector2i(5, 5)), Vector2i(5, 5))
	return s

func test_duplicate_is_independent() -> void:
	var original := _make_state()
	var copy := original.duplicate()
	# Mutating copy does not affect original
	copy.units[0].take_damage(3)
	assert_eq(original.units[0].current_hp, original.units[0].data.max_hp)
	assert_eq(copy.units[0].current_hp, copy.units[0].data.max_hp - 3)

func test_duplicate_same_unit_count() -> void:
	var original := _make_state()
	var copy := original.duplicate()
	assert_eq(copy.units.size(), original.units.size())

func test_duplicate_preserves_positions() -> void:
	var original := _make_state()
	var copy := original.duplicate()
	assert_eq(copy.units[0].grid_pos, original.units[0].grid_pos)
	assert_eq(copy.units[1].grid_pos, original.units[1].grid_pos)

func test_duplicate_preserves_current_team() -> void:
	var original := _make_state()
	original.current_team = 1
	var copy := original.duplicate()
	assert_eq(copy.current_team, 1)

func test_duplicate_board_occupancy_matches() -> void:
	var original := _make_state()
	var copy := original.duplicate()
	assert_true(copy.board.is_occupied(Vector2i(1, 1)))
	assert_true(copy.board.is_occupied(Vector2i(5, 5)))
	assert_true(not copy.board.is_occupied(Vector2i(0, 0)))
