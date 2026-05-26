@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_movement"

func _mover(move_range: int) -> MonsterData:
	return MonsterData.create(&"m", "M", 1, 5, 2, move_range, 1)

func test_legal_moves_within_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	var moves := ms.legal_moves(u)
	assert_eq(moves.size(), 4)
	assert_contains(moves, Vector2i(4, 3))
	assert_contains(moves, Vector2i(2, 3))
	assert_contains(moves, Vector2i(3, 4))
	assert_contains(moves, Vector2i(3, 2))

func test_legal_moves_excludes_occupied_and_oob() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(0, 0))
	ms.add_unit(u, Vector2i(0, 0))
	var blocker := BattleUnit.new(_mover(1), 1, Vector2i(1, 0))
	ms.add_unit(blocker, Vector2i(1, 0))
	var moves := ms.legal_moves(u)
	assert_eq(moves.size(), 1)
	assert_contains(moves, Vector2i(0, 1))

func test_move_unit_updates_state_and_flag() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(2), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	var ok := ms.move_unit(u, Vector2i(3, 5))
	assert_true(ok)
	assert_eq(u.grid_pos, Vector2i(3, 5))
	assert_true(u.has_moved)

func test_move_unit_rejects_illegal_and_when_already_moved() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	assert_false(ms.move_unit(u, Vector2i(6, 6)))
	assert_true(ms.move_unit(u, Vector2i(3, 4)))
	assert_false(ms.move_unit(u, Vector2i(3, 5)))
