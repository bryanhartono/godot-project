@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_abilities"

# --- Helpers ----------------------------------------------------------------

func _plain(team: int, pos: Vector2i, hp: int = 6, atk: int = 3, mv: int = 2, rng: int = 1) -> BattleUnit:
	return BattleUnit.new(MonsterData.create(&"x", "X", 1, hp, atk, mv, rng), team, pos)

func _spider(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(
		MonsterData.create(&"spider", "Spider", 2, 5, 2, 4, 1, AbilityData.passive_poison(1), 17),
		team, pos)

func _crab(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(
		MonsterData.create(&"crab", "Crab", 3, 10, 1, 2, 1, AbilityData.passive_tough(1), 26),
		team, pos)

func _wraith(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(
		MonsterData.create(&"wraith", "Wraith", 3, 5, 3, 2, 2, AbilityData.active_blink(4), 19),
		team, pos)

func _imp(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(
		MonsterData.create(&"imp", "Imp", 3, 5, 3, 2, 1, AbilityData.active_aoe_strike(1), 21),
		team, pos)

# --- Team enforcement -------------------------------------------------------

func test_move_blocked_for_wrong_team() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u0 := _plain(0, Vector2i(0, 0))
	ms.add_unit(u0, Vector2i(0, 0))
	var u1 := _plain(1, Vector2i(6, 6))
	ms.add_unit(u1, Vector2i(6, 6))
	# current_team = 0; u1 (team 1) must be blocked
	assert_false(ms.move_unit(u1, Vector2i(6, 5)))
	assert_true(ms.move_unit(u0, Vector2i(0, 1)))

func test_attack_blocked_for_wrong_team() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u0 := _plain(0, Vector2i(3, 3))
	ms.add_unit(u0, Vector2i(3, 3))
	var u1 := _plain(1, Vector2i(3, 4))
	ms.add_unit(u1, Vector2i(3, 4))
	assert_false(ms.attack(u1, u0))   # u1 is team 1; current_team = 0
	assert_true(ms.attack(u0, u1))    # u0 is team 0

# --- PASSIVE_POISON ---------------------------------------------------------

func test_poison_applied_when_spider_attacks() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var spider := _spider(0, Vector2i(3, 3))
	ms.add_unit(spider, Vector2i(3, 3))
	var target := _plain(1, Vector2i(3, 4))
	ms.add_unit(target, Vector2i(3, 4))
	ms.attack(spider, target)
	assert_eq(target.poison_stacks, 1)

func test_poison_ticks_at_start_of_poisoned_units_turn() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var spider := _spider(0, Vector2i(3, 3))
	ms.add_unit(spider, Vector2i(3, 3))
	var target := _plain(1, Vector2i(3, 4), 7)  # hp 7
	ms.add_unit(target, Vector2i(3, 4))
	ms.attack(spider, target)   # target hp = 7-2=5, poison_stacks=1
	ms.end_turn()               # switches to team 1; ticks poison on team-1 units
	# target took 1 poison damage -> hp should be 4
	assert_eq(target.current_hp, 4)

func test_poison_kills_and_removes_from_board() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var spider := _spider(0, Vector2i(3, 3))
	ms.add_unit(spider, Vector2i(3, 3))
	var target := _plain(1, Vector2i(3, 4), 3, 1)  # hp 3, atk 1
	ms.add_unit(target, Vector2i(3, 4))
	ms.attack(spider, target)   # target hp = 3-2=1, poison=1
	ms.end_turn()               # poison tick -> hp 0 -> removed from board
	assert_false(target.is_alive())
	assert_false(ms.board.is_occupied(Vector2i(3, 4)))

# --- PASSIVE_TOUGH ----------------------------------------------------------

func test_tough_reduces_incoming_damage() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var attacker := _plain(0, Vector2i(3, 3), 6, 3)  # atk 3
	ms.add_unit(attacker, Vector2i(3, 3))
	var crab := _crab(1, Vector2i(3, 4))              # tough -1; hp 10
	ms.add_unit(crab, Vector2i(3, 4))
	ms.attack(attacker, crab)
	assert_eq(crab.current_hp, 8)  # 10 - (3-1) = 8

func test_tough_never_goes_below_zero_damage() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	# attacker with atk 1; crab tough -1 -> effective damage 0
	var attacker := _plain(0, Vector2i(3, 3), 6, 1)
	ms.add_unit(attacker, Vector2i(3, 3))
	var crab := _crab(1, Vector2i(3, 4))
	ms.add_unit(crab, Vector2i(3, 4))
	ms.attack(attacker, crab)
	assert_eq(crab.current_hp, 10)  # no damage

# --- ACTIVE_BLINK -----------------------------------------------------------

func test_blink_moves_unit_beyond_move_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var wraith := _wraith(0, Vector2i(3, 3))  # move_range 2, blink range 4
	ms.add_unit(wraith, Vector2i(3, 3))
	var enemy := _plain(1, Vector2i(6, 6))
	ms.add_unit(enemy, Vector2i(6, 6))
	# Blink to (3, 0) -- Manhattan dist 3, within blink range 4, beyond move_range 2
	var targets := ms.legal_ability_targets(wraith)
	assert_true(Vector2i(3, 0) in targets)
	var ok := ms.use_ability(wraith, Vector2i(3, 0))
	assert_true(ok)
	assert_eq(wraith.grid_pos, Vector2i(3, 0))
	assert_true(wraith.has_moved)  # blink counts as move

func test_blink_blocked_if_already_moved() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var wraith := _wraith(0, Vector2i(3, 3))
	ms.add_unit(wraith, Vector2i(3, 3))
	var enemy := _plain(1, Vector2i(6, 6))
	ms.add_unit(enemy, Vector2i(6, 6))
	wraith.has_moved = true
	assert_eq(ms.legal_ability_targets(wraith).size(), 0)
	assert_false(ms.use_ability(wraith, Vector2i(3, 0)))

func test_blink_blocked_for_wrong_team() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var wraith := _wraith(1, Vector2i(3, 3))  # team 1; current_team=0
	ms.add_unit(wraith, Vector2i(3, 3))
	var enemy := _plain(0, Vector2i(6, 6))
	ms.add_unit(enemy, Vector2i(6, 6))
	assert_false(ms.use_ability(wraith, Vector2i(3, 0)))

# --- ACTIVE_AOE_STRIKE ------------------------------------------------------

func test_aoe_strike_damages_primary_and_adjacent_enemies() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var imp := _imp(0, Vector2i(3, 3))          # atk 3, aoe bonus 1
	ms.add_unit(imp, Vector2i(3, 3))
	var e1 := _plain(1, Vector2i(3, 4), 8)      # primary (adjacent to imp); hp 8
	ms.add_unit(e1, Vector2i(3, 4))
	var e2 := _plain(1, Vector2i(4, 4), 8)      # adjacent to e1 (splash); hp 8
	ms.add_unit(e2, Vector2i(4, 4))
	var ok := ms.use_ability(imp, Vector2i(3, 4))
	assert_true(ok)
	assert_eq(e1.current_hp, 4)  # 8 - (3+1) = 4
	assert_eq(e2.current_hp, 7)  # 8 - 1 splash = 7
	assert_true(imp.has_acted)   # aoe strike counts as attack action

func test_aoe_strike_blocked_if_already_acted() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var imp := _imp(0, Vector2i(3, 3))
	ms.add_unit(imp, Vector2i(3, 3))
	var enemy := _plain(1, Vector2i(3, 4))
	ms.add_unit(enemy, Vector2i(3, 4))
	imp.has_acted = true
	assert_eq(ms.legal_ability_targets(imp).size(), 0)
	assert_false(ms.use_ability(imp, Vector2i(3, 4)))

func test_unit_with_no_ability_has_empty_legal_ability_targets() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := _plain(0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	assert_eq(ms.legal_ability_targets(u).size(), 0)
