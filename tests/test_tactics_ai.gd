@tool
extends McpTestSuite

const _TacticsAI = preload("res://scripts/battle/tactics_ai.gd")

func suite_name() -> String:
	return "tactics_ai"

func _make_adjacent_state() -> MatchState:
	# AI unit (team 1) at (3,3), player unit (team 0) at (4,3) — adjacent
	var s := MatchState.new(Board.new(7, 7))
	var ai_data   := MonsterData.create(&"ai_unit",     "AI",     1, 5, 3, 2, 1)
	var pl_data   := MonsterData.create(&"player_unit", "Player", 1, 5, 1, 2, 1)
	s.add_unit(BattleUnit.new(ai_data, 1, Vector2i(3, 3)), Vector2i(3, 3))
	s.add_unit(BattleUnit.new(pl_data, 0, Vector2i(4, 3)), Vector2i(4, 3))
	s.current_team = 1
	return s

func test_get_actions_returns_array() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var actions := ai.get_actions(state, 1, 1)
	assert_true(actions is Array)

func test_easy_attacks_adjacent_enemy() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var actions := ai.get_actions(state, 1, 1)
	var has_attack := false
	for a in actions:
		if a.action_type == _TacticsAI.Action.ATTACK:
			has_attack = true
	assert_true(has_attack)

func test_actions_reference_ai_team_units() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var actions := ai.get_actions(state, 1, 1)
	for a in actions:
		assert_eq(a.unit.team, 1)

func test_does_not_mutate_original_state() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var hp_before := state.units[0].current_hp
	ai.get_actions(state, 1, 1)
	assert_eq(state.units[0].current_hp, hp_before)

func test_normal_difficulty_returns_actions() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var actions := ai.get_actions(state, 1, 2)
	assert_true(actions is Array)

func test_hard_difficulty_returns_actions() -> void:
	var ai := _TacticsAI.new()
	var state := _make_adjacent_state()
	var actions := ai.get_actions(state, 1, 3)
	assert_true(actions is Array)
