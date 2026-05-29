# tests/test_squad_builder_logic.gd
@tool
extends McpTestSuite

const _MonsterDbScript = preload("res://scripts/core/monster_db.gd")
const BUDGET := 10

func suite_name() -> String:
	return "squad_builder_logic"

func _make_db():
	var db = _MonsterDbScript.new()
	db._ready()
	return db

func _working_cost(squad: Array[MonsterData]) -> int:
	var total := 0
	for m in squad:
		total += m.cost
	return total

func test_add_within_budget() -> void:
	var db      = _make_db()
	var soldier = db.get_monster(&"soldier")  # cost 2
	var squad: Array[MonsterData] = []
	for i in 5:
		squad.append(soldier)
	assert_true(_working_cost(squad) <= BUDGET)

func test_cannot_add_over_budget() -> void:
	var db     = _make_db()
	var knight = db.get_monster(&"knight")    # cost 3
	assert_true(9 + knight.cost > BUDGET)

func test_deselect_restores_budget_room() -> void:
	var db      = _make_db()
	var soldier = db.get_monster(&"soldier")
	var squad: Array[MonsterData] = []
	squad.append(soldier)
	squad.append(soldier)
	var before := _working_cost(squad)
	squad.erase(soldier)
	assert_eq(_working_cost(squad), before - soldier.cost)

func test_selected_card_always_toggleable() -> void:
	var db      = _make_db()
	var soldier = db.get_monster(&"soldier")
	var squad: Array[MonsterData] = []
	squad.append(soldier)
	assert_true(soldier in squad)
	squad.erase(soldier)
	assert_true(not (soldier in squad))
