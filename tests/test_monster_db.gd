@tool
extends McpTestSuite

## MonsterDB has no class_name (autoload singleton). Instantiate via preload.
const _MonsterDbScript = preload("res://game/core/monster_db.gd")
## Preload AbilityData explicitly so Type.* enum values resolve at parse time.
const _AbilityData = preload("res://game/core/ability_data.gd")

func suite_name() -> String:
	return "monster_db"

func _make_db():
	var db = _MonsterDbScript.new()
	db._ready()
	return db

func test_all_eleven_monsters_registered() -> void:
	var db = _make_db()
	var ids: Array[StringName] = [
		&"knight", &"soldier", &"goblin", &"orc", &"spider",
		&"wraith", &"imp", &"archer", &"crab", &"bat", &"ghost"
	]
	for id in ids:
		var m = db.get_monster(id)
		assert_true(m != null)

func test_all_monsters_have_valid_stats() -> void:
	var db = _make_db()
	for m in db.all_monsters():
		assert_true(m.max_hp > 0)
		assert_true(m.atk > 0)
		assert_true(m.move_range > 0)
		assert_true(m.atk_range > 0)
		assert_true(m.cost > 0)

func test_spider_has_passive_poison() -> void:
	var db = _make_db()
	var spider = db.get_monster(&"spider")
	assert_true(spider.ability != null)
	assert_eq(spider.ability.type, _AbilityData.Type.PASSIVE_POISON)

func test_wraith_has_active_blink() -> void:
	var db = _make_db()
	var wraith = db.get_monster(&"wraith")
	assert_true(wraith.ability != null)
	assert_eq(wraith.ability.type, _AbilityData.Type.ACTIVE_BLINK)

func test_imp_has_active_aoe_strike() -> void:
	var db = _make_db()
	var imp = db.get_monster(&"imp")
	assert_true(imp.ability != null)
	assert_eq(imp.ability.type, _AbilityData.Type.ACTIVE_AOE_STRIKE)

func test_crab_has_passive_tough() -> void:
	var db = _make_db()
	var crab = db.get_monster(&"crab")
	assert_true(crab.ability != null)
	assert_eq(crab.ability.type, _AbilityData.Type.PASSIVE_TOUGH)

func test_unknown_id_returns_null() -> void:
	var db = _make_db()
	assert_true(db.get_monster(&"no_such_monster") == null)

func test_squad_budget_player_leq_10() -> void:
	var db = _make_db()
	var ids: Array[StringName] = [&"knight", &"archer", &"spider"]
	var total := 0
	for id in ids:
		total += db.get_monster(id).cost
	assert_true(total <= 10)

func test_squad_budget_enemy_leq_10() -> void:
	var db = _make_db()
	var ids: Array[StringName] = [&"goblin", &"crab", &"bat"]
	var total := 0
	for id in ids:
		total += db.get_monster(id).cost
	assert_true(total <= 10)
