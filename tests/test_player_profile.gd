@tool
extends McpTestSuite

const _MonsterDbScript = preload("res://scripts/core/monster_db.gd")

func suite_name() -> String:
	return "player_profile"

func test_placeholder() -> void:
	assert_true(true)

func test_starter_ids_valid() -> void:
	var db = _MonsterDbScript.new()
	db._ready()
	assert_true(db.get_monster(&"soldier") != null)
	assert_true(db.get_monster(&"orc") != null)
	assert_true(db.get_monster(&"bat") != null)
	assert_true(db.get_monster(&"ghost") != null)

func test_starter_squad_cost_within_budget() -> void:
	var db = _MonsterDbScript.new()
	db._ready()
	var total := 0
	total += db.get_monster(&"soldier").cost
	total += db.get_monster(&"orc").cost
	total += db.get_monster(&"bat").cost
	total += db.get_monster(&"ghost").cost
	assert_true(total <= 10)
