@tool
extends McpTestSuite

const _SquadPicker = preload("res://scripts/battle/squad_picker.gd")
const _MonsterDbScript = preload("res://scripts/core/monster_db.gd")

func suite_name() -> String:
	return "squad_picker"

func _make_pool() -> Array[MonsterData]:
	var db = _MonsterDbScript.new()
	db._ready()
	return db.all_monsters()

func test_squad_respects_budget() -> void:
	var squad := _SquadPicker.random_squad(10, _make_pool())
	var total := 0
	for m in squad:
		total += m.cost
	assert_true(total <= 10)

func test_squad_has_at_least_one_unit() -> void:
	var squad := _SquadPicker.random_squad(10, _make_pool())
	assert_true(squad.size() >= 1)

func test_squad_no_duplicates() -> void:
	var squad := _SquadPicker.random_squad(10, _make_pool())
	var ids: Array[StringName] = []
	for m in squad:
		assert_true(not ids.has(m.id))
		ids.append(m.id)

func test_squad_budget_1_returns_empty() -> void:
	var squad := _SquadPicker.random_squad(1, _make_pool())
	assert_true(squad.size() == 0)

func test_squad_budget_2_returns_one_unit() -> void:
	var squad := _SquadPicker.random_squad(2, _make_pool())
	assert_true(squad.size() == 1)
	assert_true(squad[0].cost <= 2)
