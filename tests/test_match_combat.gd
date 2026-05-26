@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_combat"

func _melee() -> MonsterData:
	return MonsterData.create(&"melee", "Melee", 1, 6, 3, 1, 1)

func _ranged() -> MonsterData:
	return MonsterData.create(&"ranged", "Ranged", 1, 4, 2, 1, 3)

func test_legal_targets_only_adjacent_enemies_for_melee() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var adj_enemy := BattleUnit.new(_melee(), 1, Vector2i(3, 4))
	ms.add_unit(adj_enemy, Vector2i(3, 4))
	var far_enemy := BattleUnit.new(_melee(), 1, Vector2i(3, 6))
	ms.add_unit(far_enemy, Vector2i(3, 6))
	var ally := BattleUnit.new(_melee(), 0, Vector2i(2, 3))
	ms.add_unit(ally, Vector2i(2, 3))
	var targets := ms.legal_targets(a)
	assert_eq(targets.size(), 1)
	assert_contains(targets, adj_enemy)

func test_ranged_hits_within_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_ranged(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_melee(), 1, Vector2i(3, 6))  # manhattan dist 3
	ms.add_unit(e, Vector2i(3, 6))
	assert_contains(ms.legal_targets(a), e)

func test_attack_applies_damage_and_sets_flag() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_melee(), 1, Vector2i(3, 4))  # hp 6
	ms.add_unit(e, Vector2i(3, 4))
	var ok := ms.attack(a, e)
	assert_true(ok)
	assert_eq(e.current_hp, 3)  # 6 - 3 atk
	assert_true(a.has_acted)

func test_attack_kills_and_removes_from_board() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))   # atk 3
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_ranged(), 1, Vector2i(3, 4))  # hp 4
	ms.add_unit(e, Vector2i(3, 4))
	ms.attack(a, e)        # 4 - 3 = 1 left
	a.has_acted = false    # allow a second hit for this test only
	ms.attack(a, e)        # dead
	assert_false(e.is_alive())
	assert_false(ms.board.is_occupied(Vector2i(3, 4)))

func test_attack_rejected_when_out_of_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(0, 0))
	ms.add_unit(a, Vector2i(0, 0))
	var e := BattleUnit.new(_melee(), 1, Vector2i(5, 5))
	ms.add_unit(e, Vector2i(5, 5))
	assert_false(ms.attack(a, e))

func test_attack_rejected_when_already_acted() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e1 := BattleUnit.new(_melee(), 1, Vector2i(3, 4))
	ms.add_unit(e1, Vector2i(3, 4))
	var e2 := BattleUnit.new(_melee(), 1, Vector2i(2, 3))
	ms.add_unit(e2, Vector2i(2, 3))
	assert_true(ms.attack(a, e1))
	assert_false(ms.attack(a, e2))  # already acted this turn
