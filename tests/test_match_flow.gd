@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_flow"

func _u(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(MonsterData.create(&"u", "U", 1, 5, 3, 2, 1), team, pos)

func test_winner_is_negative_one_while_both_alive() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	ms.add_unit(_u(0, Vector2i(0, 0)), Vector2i(0, 0))
	ms.add_unit(_u(1, Vector2i(6, 6)), Vector2i(6, 6))
	assert_eq(ms.winner(), -1)

func test_winner_when_enemy_wiped() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	ms.add_unit(_u(0, Vector2i(0, 0)), Vector2i(0, 0))
	var enemy := _u(1, Vector2i(0, 1))
	ms.add_unit(enemy, Vector2i(0, 1))
	enemy.take_damage(100)
	ms.board.remove_unit(enemy)
	assert_eq(ms.winner(), 0)

func test_winner_when_player_wiped() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var p := _u(0, Vector2i(0, 0))
	ms.add_unit(p, Vector2i(0, 0))
	ms.add_unit(_u(1, Vector2i(6, 6)), Vector2i(6, 6))
	p.take_damage(100)
	ms.board.remove_unit(p)
	assert_eq(ms.winner(), 1)

func test_end_turn_switches_team_and_resets_flags() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var p := _u(0, Vector2i(0, 0))
	ms.add_unit(p, Vector2i(0, 0))
	var e := _u(1, Vector2i(6, 6))
	ms.add_unit(e, Vector2i(6, 6))
	assert_eq(ms.current_team, 0)
	p.has_moved = true
	ms.end_turn()
	assert_eq(ms.current_team, 1)
	e.has_moved = true
	ms.end_turn()
	assert_eq(ms.current_team, 0)
	assert_false(p.has_moved)  # reset when team 0 became active again
