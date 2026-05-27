@tool
extends McpTestSuite

func suite_name() -> String:
	return "monster_db"

var _db: MonsterDB

func setup() -> void:
	_db = MonsterDB.new()
	_db._ready()

func test_all_eleven_monsters_registered() -> void:
	var ids: Array[StringName] = [
		&"knight", &"soldier", &"goblin", &"orc", &"spider",
		&"wraith", &"imp", &"archer", &"crab", &"bat", &"ghost"
	]
	for id in ids:
		var m := _db.get_monster(id)
		assert_true(m != null)

func test_all_monsters_have_valid_stats() -> void:
	for m in _db.all_monsters():
		assert_true(m.max_hp > 0)
		assert_true(m.atk > 0)
		assert_true(m.move_range > 0)
		assert_true(m.atk_range > 0)
		assert_true(m.cost > 0)

func test_spider_has_passive_poison() -> void:
	var spider := _db.get_monster(&"spider")
	assert_true(spider.ability != null)
	assert_eq(spider.ability.type, AbilityData.Type.PASSIVE_POISON)

func test_wraith_has_active_blink() -> void:
	var wraith := _db.get_monster(&"wraith")
	assert_true(wraith.ability != null)
	assert_eq(wraith.ability.type, AbilityData.Type.ACTIVE_BLINK)

func test_imp_has_active_aoe_strike() -> void:
	var imp := _db.get_monster(&"imp")
	assert_true(imp.ability != null)
	assert_eq(imp.ability.type, AbilityData.Type.ACTIVE_AOE_STRIKE)

func test_crab_has_passive_tough() -> void:
	var crab := _db.get_monster(&"crab")
	assert_true(crab.ability != null)
	assert_eq(crab.ability.type, AbilityData.Type.PASSIVE_TOUGH)

func test_unknown_id_returns_null() -> void:
	assert_true(_db.get_monster(&"no_such_monster") == null)

func test_squad_budget_player_leq_10() -> void:
	var ids: Array[StringName] = [&"knight", &"archer", &"spider"]
	var total := 0
	for id in ids:
		total += _db.get_monster(id).cost
	assert_true(total <= 10)

func test_squad_budget_enemy_leq_10() -> void:
	var ids: Array[StringName] = [&"goblin", &"crab", &"bat"]
	var total := 0
	for id in ids:
		total += _db.get_monster(id).cost
	assert_true(total <= 10)
