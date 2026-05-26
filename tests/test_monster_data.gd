@tool
extends McpTestSuite

func suite_name() -> String:
	return "monster_data"

func test_create_sets_all_fields() -> void:
	var d := MonsterData.create(&"knight", "Knight", 3, 8, 3, 3, 1)
	assert_eq(d.id, &"knight")
	assert_eq(d.display_name, "Knight")
	assert_eq(d.cost, 3)
	assert_eq(d.max_hp, 8)
	assert_eq(d.atk, 3)
	assert_eq(d.move_range, 3)
	assert_eq(d.atk_range, 1)

func test_defaults_are_sane() -> void:
	var d := MonsterData.new()
	assert_eq(d.cost, 1)
	assert_eq(d.max_hp, 1)
	assert_eq(d.atk, 1)
