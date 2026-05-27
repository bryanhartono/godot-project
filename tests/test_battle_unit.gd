@tool
extends McpTestSuite

func suite_name() -> String:
	return "battle_unit"

func _knight() -> MonsterData:
	return MonsterData.create(&"knight", "Knight", 3, 8, 3, 3, 1)

func test_init_sets_hp_from_data() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i(1, 2))
	assert_eq(u.current_hp, 8)
	assert_eq(u.team, 0)
	assert_eq(u.grid_pos, Vector2i(1, 2))
	assert_true(u.is_alive())

func test_take_damage_reduces_hp() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i.ZERO)
	u.take_damage(3)
	assert_eq(u.current_hp, 5)

func test_take_damage_clamps_at_zero_and_dies() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i.ZERO)
	u.take_damage(100)
	assert_eq(u.current_hp, 0)
	assert_false(u.is_alive())

func test_reset_turn_clears_flags() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i.ZERO)
	u.has_moved = true
	u.has_acted = true
	u.reset_turn()
	assert_false(u.has_moved)
	assert_false(u.has_acted)

func test_poison_stacks_persists_across_reset_turn() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i.ZERO)
	u.poison_stacks = 2
	u.reset_turn()
	assert_eq(u.poison_stacks, 2)  # poison does NOT reset on turn reset
