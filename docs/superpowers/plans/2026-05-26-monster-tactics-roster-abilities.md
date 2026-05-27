# Monster Tactics — Phase 2: Roster + Abilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Phase 1's hardcoded 6-unit prototype with all 11 roster monsters defined as data, each with correct sprites and a working passive or active ability, and wire the view to load squads from the new `MonsterDB` autoload.

**Architecture:** A new `AbilityData` resource encodes each ability's type + a single integer parameter. `MonsterData` gains `ability` and `sprite_row` fields. A new `MonsterDB` Node autoload (registered in `project.godot`) holds all 11 monsters in code — no `.tres` files yet; that comes when the editor needs to author them. `MatchState` gains team enforcement (the Phase 1 TODOs) plus passive-ability hooks in `attack()` / `end_turn()` and new `legal_ability_targets()` / `use_ability()` methods. `match_view.gd` is updated surgically to load from `MonsterDB`, use `data.sprite_row` for sprites, highlight ability targets in yellow, and show a brief selected-unit info line.

**Tech Stack:** Godot 4.6.2 GDScript, `class_name`-registered classes, `McpTestSuite` in `res://tests/`, `test_run` MCP tool.

**Scope:** Phase 2 of 6. AI opponents, interactive deploy, `AnimatedSprite2D` walk/attack frames, and the meta-loop are out of scope — those are Phases 3–4. This phase ends with a hot-seat match where all 11 monsters are available and their abilities fire correctly.

**Sprite sheet layout:** `assets/Sprites/Outlined_Entities.png` is 64 × 561 pixels = 4 columns × 35 rows of 16 × 16 cells. Column 0 = idle frame used for all sprites in Phase 2. Confirmed idle rows from Phase 1: knight=0, goblin=9, spider=17, archer=24, crab=26, bat=30. Estimated rows for new monsters below — Task 4 includes a visual-verification step.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `game/core/ability_data.gd` | AbilityData resource: type enum + factory statics |
| Modify | `game/core/monster_data.gd` | Add `ability: AbilityData` and `sprite_row: int` optional params |
| Modify | `game/core/battle_unit.gd` | Add `poison_stacks: int` field |
| Create | `game/core/monster_db.gd` | Node autoload: all 11 monster definitions in code |
| Modify | `game/core/match_state.gd` | Team enforcement + passive/active ability hooks (4 methods changed/added) |
| Modify | `game/match_view.gd` | Load squad from MonsterDB, ability targeting UI, info label |
| Modify | `project.godot` | Register `MonsterDB` autoload |
| Create | `tests/test_ability_data.gd` | AbilityData construction tests |
| Create | `tests/test_monster_db.gd` | MonsterDB lookup + coverage tests |
| Create | `tests/test_match_abilities.gd` | Team enforcement + all ability mechanics tests |

---

## Task 1: AbilityData resource

New file. Five ability types with factory statics. The integer `param` carries the ability-specific value (poison damage, tough reduction, blink range, AoE bonus damage).

**Files:**
- Create: `game/core/ability_data.gd`
- Create: `tests/test_ability_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_ability_data.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "ability_data"

func test_passive_poison_factory() -> void:
	var a := AbilityData.passive_poison(2)
	assert_eq(a.type, AbilityData.Type.PASSIVE_POISON)
	assert_eq(a.param, 2)

func test_passive_tough_factory() -> void:
	var a := AbilityData.passive_tough(1)
	assert_eq(a.type, AbilityData.Type.PASSIVE_TOUGH)
	assert_eq(a.param, 1)

func test_active_blink_factory() -> void:
	var a := AbilityData.active_blink(4)
	assert_eq(a.type, AbilityData.Type.ACTIVE_BLINK)
	assert_eq(a.param, 4)

func test_active_aoe_strike_factory() -> void:
	var a := AbilityData.active_aoe_strike(1)
	assert_eq(a.type, AbilityData.Type.ACTIVE_AOE_STRIKE)
	assert_eq(a.param, 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run` MCP tool with `{"suite": "ability_data", "verbose": true}`.
Expected: `test_ability_data.gd` under `load_errors` — `AbilityData` not yet declared.

- [ ] **Step 3: Write the implementation**

Create `game/core/ability_data.gd`:
```gdscript
class_name AbilityData
extends Resource

## Encodes one monster ability: type + a single integer parameter.
## Monsters with no ability have ability = null in their MonsterData.

enum Type {
	NONE,
	PASSIVE_POISON,      # On attack: target gains poison_stacks = param; ticks at start of its turn
	PASSIVE_TOUGH,       # On receive damage: reduce incoming damage by param (min 0)
	ACTIVE_BLINK,        # Instead of moving: teleport to any empty tile within Manhattan param
	ACTIVE_AOE_STRIKE,   # Instead of attacking: deal atk+param to primary target, param splash to adjacent enemies
}

@export var type: Type = Type.NONE
@export var param: int = 0

static func passive_poison(dmg: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.PASSIVE_POISON
	a.param = dmg
	return a

static func passive_tough(reduction: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.PASSIVE_TOUGH
	a.param = reduction
	return a

static func active_blink(range_val: int = 4) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.ACTIVE_BLINK
	a.param = range_val
	return a

static func active_aoe_strike(bonus_dmg: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.ACTIVE_AOE_STRIKE
	a.param = bonus_dmg
	return a
```

- [ ] **Step 4: Run test to verify it passes**

Run `test_run` MCP tool with `{"suite": "ability_data", "verbose": true}`.
Expected: 4 tests pass, 0 failures, 0 load errors.

- [ ] **Step 5: Commit**

```bash
cd "/Users/bryanhartono/Documents/Game Dev/Godot/Projects/Personal/godot-project" && \
git add game/core/ability_data.gd tests/test_ability_data.gd && \
git commit -m "feat: add AbilityData resource with type enum and factory statics"
```

---

## Task 2: MonsterData upgrade

Add two optional parameters to `MonsterData.create()`: `p_ability: AbilityData = null` and `p_row: int = 0`. All existing test code still compiles because both params have defaults.

**Files:**
- Modify: `game/core/monster_data.gd`
- Modify: `tests/test_monster_data.gd` (add two new tests; do NOT touch existing tests)

- [ ] **Step 1: Write the failing tests**

Read `tests/test_monster_data.gd` first, then append these two test methods inside the class (after the last existing test):
```gdscript
func test_create_with_ability_and_row() -> void:
	var a := AbilityData.passive_poison(1)
	var d := MonsterData.create(&"spider", "Spider", 2, 5, 2, 4, 1, a, 17)
	assert_eq(d.ability, a)
	assert_eq(d.sprite_row, 17)

func test_create_defaults_ability_null_row_zero() -> void:
	var d := MonsterData.create(&"x", "X", 1, 1, 1, 1, 1)
	assert_true(d.ability == null)
	assert_eq(d.sprite_row, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run` MCP tool with `{"suite": "monster_data", "verbose": true}`.
Expected: 2 failures (the new tests) — field `ability` / `sprite_row` not yet declared.

- [ ] **Step 3: Write the implementation**

Read `game/core/monster_data.gd`, then apply these changes:

After `@export var atk_range: int = 1` add:
```gdscript
@export var ability: AbilityData = null
@export var sprite_row: int = 0
```

Replace the `static func create(...)` body with:
```gdscript
static func create(p_id: StringName, p_name: String, p_cost: int, p_hp: int, p_atk: int, p_move: int, p_range: int, p_ability: AbilityData = null, p_row: int = 0) -> MonsterData:
	var d := MonsterData.new()
	d.id = p_id
	d.display_name = p_name
	d.cost = p_cost
	d.max_hp = p_hp
	d.atk = p_atk
	d.move_range = p_move
	d.atk_range = p_range
	d.ability = p_ability
	d.sprite_row = p_row
	return d
```

- [ ] **Step 4: Run test to verify it passes**

Run `test_run` MCP tool with `{"suite": "monster_data", "verbose": true}`.
Expected: 4 tests pass (2 existing + 2 new), 0 failures.

- [ ] **Step 5: Run full suite to confirm no regressions**

Run `test_run` with `{}`.
Expected: all existing suites still pass, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add game/core/monster_data.gd tests/test_monster_data.gd && \
git commit -m "feat: add ability and sprite_row fields to MonsterData"
```

---

## Task 3: BattleUnit poison_stacks

Add `poison_stacks: int = 0` to track active poison on a unit. Poison does NOT reset on `reset_turn()` — it persists until the unit dies.

**Files:**
- Modify: `game/core/battle_unit.gd`
- Modify: `tests/test_battle_unit.gd` (append one test)

- [ ] **Step 1: Write the failing test**

Read `tests/test_battle_unit.gd`, then append:
```gdscript
func test_poison_stacks_persists_across_reset_turn() -> void:
	var u := BattleUnit.new(_knight(), 0, Vector2i.ZERO)
	u.poison_stacks = 2
	u.reset_turn()
	assert_eq(u.poison_stacks, 2)  # poison does NOT reset on turn reset
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run` MCP tool with `{"suite": "battle_unit", "verbose": true}`.
Expected: 1 failure — `poison_stacks` not yet declared.

- [ ] **Step 3: Write the implementation**

Read `game/core/battle_unit.gd`. Add after `var has_acted: bool = false`:
```gdscript
var poison_stacks: int = 0  # damage dealt at start of this unit's team turn; does not reset
```

`reset_turn()` needs no change — it correctly omits `poison_stacks`.

- [ ] **Step 4: Run test to verify it passes**

Run `test_run` MCP tool with `{"suite": "battle_unit", "verbose": true}`.
Expected: 5 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add game/core/battle_unit.gd tests/test_battle_unit.gd && \
git commit -m "feat: add poison_stacks to BattleUnit"
```

---

## Task 4: MonsterDB autoload

A `Node` that owns all 11 monster definitions. No `.tres` files yet — everything is in code via `MonsterData.create()`. Registered as an autoload so any scene can call `MonsterDB.get_monster(&"knight")`.

**Sprite row assignments** (column 0 = idle frame; verify visually after Task 6 run):

| ID | Creature | Row | Archetype |
|----|----------|-----|-----------|
| `knight` | Knight (blue armored) | 0 | Bruiser |
| `soldier` | Soldier (brown recolor) | 4 | Bruiser |
| `goblin` | Goblin (green) | 9 | Bruiser |
| `orc` | Orc/Ranger (green, bow) | 12 | Ranged |
| `spider` | Spider (black) | 17 | Assassin |
| `wraith` | Wraith (dark, scythe) | 19 | Caster |
| `imp` | Imp/Demon (red, horned) | 21 | Caster |
| `archer` | Archer (purple hood) | 24 | Ranged |
| `crab` | Crab/Beetle (red) | 26 | Tank |
| `bat` | Bat (purple) | 30 | Assassin |
| `ghost` | Ghost (blue, banner) | 32 | Support |

If a row renders the wrong creature during manual play-test, adjust `sprite_row` in `monster_db.gd` — it is purely visual.

**Squad budget sanity:** Total cost per demo squad ≤ 10.
- Player squad: knight(3) + archer(2) + spider(2) = 7 ✓
- Enemy squad: goblin(2) + crab(3) + bat(2) = 7 ✓

**Files:**
- Create: `game/core/monster_db.gd`
- Modify: `project.godot`
- Create: `tests/test_monster_db.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_monster_db.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "monster_db"

var _db: MonsterDB

func before_each() -> void:
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
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run` MCP tool with `{"suite": "monster_db", "verbose": true}`.
Expected: `test_monster_db.gd` under `load_errors` — `MonsterDB` not yet declared.

- [ ] **Step 3: Write the implementation**

Create `game/core/monster_db.gd`:
```gdscript
class_name MonsterDB
extends Node

## Autoload: all monster definitions. Call get_monster(&"id") from anywhere.

var _all: Dictionary = {}  # StringName -> MonsterData

func _ready() -> void:
	_register_all()

func get_monster(id: StringName) -> MonsterData:
	return _all.get(id, null)

func all_monsters() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for m in _all.values():
		out.append(m as MonsterData)
	return out

func _register(data: MonsterData) -> void:
	_all[data.id] = data

func _register_all() -> void:
	# cost, max_hp, atk, move_range, atk_range, ability, sprite_row
	# ── Bruisers ──────────────────────────────────────────────────────
	_register(MonsterData.create(&"knight",  "Knight",  3,  8, 3, 3, 1, null,                           0))
	_register(MonsterData.create(&"soldier", "Soldier", 2,  6, 2, 2, 1, null,                           4))
	_register(MonsterData.create(&"goblin",  "Goblin",  2,  7, 3, 2, 1, null,                           9))
	# ── Ranged ────────────────────────────────────────────────────────
	_register(MonsterData.create(&"orc",     "Orc",     2,  6, 2, 2, 2, null,                          12))
	_register(MonsterData.create(&"archer",  "Archer",  2,  4, 2, 1, 3, null,                          24))
	# ── Assassins ─────────────────────────────────────────────────────
	_register(MonsterData.create(&"spider",  "Spider",  2,  5, 2, 4, 1, AbilityData.passive_poison(1), 17))
	_register(MonsterData.create(&"bat",     "Bat",     2,  4, 3, 4, 1, null,                          30))
	# ── Casters ───────────────────────────────────────────────────────
	_register(MonsterData.create(&"wraith",  "Wraith",  3,  5, 3, 2, 2, AbilityData.active_blink(4),   19))
	_register(MonsterData.create(&"imp",     "Imp",     3,  5, 3, 2, 1, AbilityData.active_aoe_strike(1), 21))
	# ── Tank ──────────────────────────────────────────────────────────
	_register(MonsterData.create(&"crab",    "Crab",    3, 10, 1, 2, 1, AbilityData.passive_tough(1),  26))
	# ── Support ───────────────────────────────────────────────────────
	_register(MonsterData.create(&"ghost",   "Ghost",   2,  5, 1, 3, 2, AbilityData.passive_tough(1),  32))
```

- [ ] **Step 4: Run test to verify it passes**

Run `test_run` MCP tool with `{"suite": "monster_db", "verbose": true}`.
Expected: 9 tests pass, 0 failures.

- [ ] **Step 5: Register MonsterDB as autoload in project.godot**

Read `project.godot` and locate the `[autoload]` section. If it doesn't exist, add it. Add this line:
```
MonsterDB="*res://game/core/monster_db.gd"
```

Full `[autoload]` section should look like:
```
[autoload]

MonsterDB="*res://game/core/monster_db.gd"
```

Use `mcp__godot-ai__autoload_manage` with `op="add"`, `params={"name": "MonsterDB", "path": "res://game/core/monster_db.gd"}` to register it through the editor, or edit `project.godot` directly.

- [ ] **Step 6: Commit**

```bash
git add game/core/monster_db.gd tests/test_monster_db.gd project.godot && \
git commit -m "feat: add MonsterDB autoload with all 11 monster definitions"
```

---

## Task 5: MatchState Phase 2 — team enforcement + abilities

Four changes to `game/core/match_state.gd`:
1. `move_unit()` — enforce `unit.team == current_team`
2. `attack()` — enforce team, apply PASSIVE_TOUGH damage reduction, apply PASSIVE_POISON on attacker hit
3. `end_turn()` — tick poison damage on newly-active team's units before resetting flags
4. New methods: `legal_ability_targets()` + `use_ability()`

**Files:**
- Modify: `game/core/match_state.gd`
- Create: `tests/test_match_abilities.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_match_abilities.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_abilities"

# ── Helpers ───────────────────────────────────────────────────────────────────

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

# ── Team enforcement ──────────────────────────────────────────────────────────

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
	assert_true(ms.attack(u0, u1))    # u0 is team 0 ✓

# ── PASSIVE_POISON ────────────────────────────────────────────────────────────

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
	# target took 1 poison damage → hp should be 4
	assert_eq(target.current_hp, 4)

func test_poison_kills_and_removes_from_board() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var spider := _spider(0, Vector2i(3, 3))
	ms.add_unit(spider, Vector2i(3, 3))
	var target := _plain(1, Vector2i(3, 4), 3, 1)  # hp 3
	ms.add_unit(target, Vector2i(3, 4))
	ms.attack(spider, target)   # target hp = 3-2=1, poison=1
	ms.end_turn()               # poison tick → hp 0 → removed from board
	assert_false(target.is_alive())
	assert_false(ms.board.is_occupied(Vector2i(3, 4)))

# ── PASSIVE_TOUGH ─────────────────────────────────────────────────────────────

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
	# attacker with atk 1; crab tough -1 → effective damage 0
	var attacker := _plain(0, Vector2i(3, 3), 6, 1)
	ms.add_unit(attacker, Vector2i(3, 3))
	var crab := _crab(1, Vector2i(3, 4))
	ms.add_unit(crab, Vector2i(3, 4))
	ms.attack(attacker, crab)
	assert_eq(crab.current_hp, 10)  # no damage

# ── ACTIVE_BLINK ──────────────────────────────────────────────────────────────

func test_blink_moves_unit_beyond_move_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var wraith := _wraith(0, Vector2i(3, 3))  # move_range 2, blink range 4
	ms.add_unit(wraith, Vector2i(3, 3))
	var enemy := _plain(1, Vector2i(6, 6))
	ms.add_unit(enemy, Vector2i(6, 6))
	# Blink to (3, 0) — Manhattan dist 3, within blink range 4, beyond move_range 2
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

# ── ACTIVE_AOE_STRIKE ─────────────────────────────────────────────────────────

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
```

- [ ] **Step 2: Run test to verify it fails**

Run `test_run` MCP tool with `{"suite": "match_abilities", "verbose": true}`.
Expected: 2 failures for team enforcement (tests exist but logic not enforced yet) + load errors or failures for `legal_ability_targets` / `use_ability` not yet declared.

- [ ] **Step 3: Write the implementation — replace match_state.gd**

Read `game/core/match_state.gd` first. The full updated file is:
```gdscript
class_name MatchState
extends RefCounted

## The rules engine: holds the board and all units, and enforces movement,
## attacks, turn order, and win conditions.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var board: Board
var units: Array[BattleUnit] = []
var current_team: int = 0

func _init(p_board: Board = null) -> void:
	board = p_board if p_board != null else Board.new()

func add_unit(unit: BattleUnit, pos: Vector2i) -> void:
	board.place_unit(unit, pos)
	units.append(unit)

func units_for_team(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.team == team and u.is_alive():
			out.append(u)
	return out

## All empty, in-bounds tiles reachable within move_range via 4-directional steps.
func legal_moves(unit: BattleUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited := {unit.grid_pos: 0}
	var frontier: Array[Vector2i] = [unit.grid_pos]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var dist: int = visited[cur]
		if dist >= unit.data.move_range:
			continue
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if visited.has(nxt):
				continue
			if not board.is_in_bounds(nxt):
				continue
			if board.is_occupied(nxt):
				continue
			visited[nxt] = dist + 1
			result.append(nxt)
			frontier.append(nxt)
	return result

func move_unit(unit: BattleUnit, pos: Vector2i) -> bool:
	if unit.team != current_team:
		return false
	if unit.has_moved:
		return false
	if not pos in legal_moves(unit):
		return false
	board.relocate_unit(unit, pos)
	unit.has_moved = true
	return true

## Living enemy units within Manhattan attack range.
func legal_targets(unit: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for other in units:
		if other.team == unit.team or not other.is_alive():
			continue
		var dist: int = abs(other.grid_pos.x - unit.grid_pos.x) + abs(other.grid_pos.y - unit.grid_pos.y)
		if dist <= unit.data.atk_range:
			out.append(other)
	return out

func attack(attacker: BattleUnit, target: BattleUnit) -> bool:
	if attacker.team != current_team:
		return false
	if attacker.has_acted:
		return false
	if not target in legal_targets(attacker):
		return false
	# Compute damage, reduced by PASSIVE_TOUGH on defender
	var dmg: int = attacker.data.atk
	if target.data.ability != null and target.data.ability.type == AbilityData.Type.PASSIVE_TOUGH:
		dmg = max(0, dmg - target.data.ability.param)
	target.take_damage(dmg)
	# Apply PASSIVE_POISON from attacker
	if attacker.data.ability != null and attacker.data.ability.type == AbilityData.Type.PASSIVE_POISON:
		target.poison_stacks = max(target.poison_stacks, attacker.data.ability.param)
	attacker.has_acted = true
	if not target.is_alive():
		board.remove_unit(target)  # removes from board; units[] keeps dead entries, filtered by is_alive()
	return true

func end_turn() -> void:
	current_team = 1 - current_team
	# Tick poison on the newly-active team's units before they act
	for u in units_for_team(current_team):
		if u.poison_stacks > 0:
			u.take_damage(u.poison_stacks)
			if not u.is_alive():
				board.remove_unit(u)
	# Reset turn flags for surviving units
	for u in units_for_team(current_team):
		u.reset_turn()

## Returns the winning team (0 or 1), or -1 if the match is ongoing.
func winner() -> int:
	var alive0 := units_for_team(0).size()
	var alive1 := units_for_team(1).size()
	if alive0 == 0:
		return 1
	if alive1 == 0:
		return 0
	return -1

## Valid target positions for a unit's active ability (empty if passive or already used).
func legal_ability_targets(unit: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit.data.ability == null:
		return out
	match unit.data.ability.type:
		AbilityData.Type.ACTIVE_BLINK:
			if unit.has_moved:
				return out
			for x in board.width:
				for y in board.height:
					var pos := Vector2i(x, y)
					if board.is_occupied(pos):
						continue
					var dist := abs(pos.x - unit.grid_pos.x) + abs(pos.y - unit.grid_pos.y)
					if dist > 0 and dist <= unit.data.ability.param:
						out.append(pos)
		AbilityData.Type.ACTIVE_AOE_STRIKE:
			if unit.has_acted:
				return out
			for t in legal_targets(unit):
				out.append(t.grid_pos)
	return out

## Execute a unit's active ability targeting target_pos. Returns false if invalid.
func use_ability(unit: BattleUnit, target_pos: Vector2i) -> bool:
	if unit.team != current_team:
		return false
	if unit.data.ability == null:
		return false
	if not target_pos in legal_ability_targets(unit):
		return false
	match unit.data.ability.type:
		AbilityData.Type.ACTIVE_BLINK:
			board.relocate_unit(unit, target_pos)
			unit.has_moved = true
		AbilityData.Type.ACTIVE_AOE_STRIKE:
			var primary := board.get_unit_at(target_pos)
			primary.take_damage(unit.data.atk + unit.data.ability.param)
			if not primary.is_alive():
				board.remove_unit(primary)
			for d in DIRS:
				var adj := target_pos + d
				var splash := board.get_unit_at(adj)
				if splash != null and splash.team != unit.team and splash.is_alive():
					splash.take_damage(unit.data.ability.param)
					if not splash.is_alive():
						board.remove_unit(splash)
			unit.has_acted = true
	return true
```

Use `mcp__godot-ai__filesystem_manage` with `op="write_text"` to write the file so the editor picks up the changes.

- [ ] **Step 4: Run match_abilities tests to verify they pass**

Run `test_run` MCP tool with `{"suite": "match_abilities", "verbose": true}`.
Expected: 14 tests pass, 0 failures.

- [ ] **Step 5: Run full suite to confirm no regressions**

Run `test_run` with `{}`.
Expected: all 7 suites pass (ability_data, battle_unit, board, match_abilities, match_combat, match_flow, match_movement, monster_data, monster_db), 0 failures.

Note: The old Phase 1 test suites still pass because:
- `MonsterData.create()` new params have defaults — old 7-param calls compile fine.
- All Phase 1 test units are team 0; `current_team` starts at 0 → team enforcement passes.

- [ ] **Step 6: Commit**

```bash
git add game/core/match_state.gd tests/test_match_abilities.gd && \
git commit -m "feat: team enforcement + passive and active abilities in MatchState"
```

---

## Task 6: match_view Phase 2

Surgical update to `game/match_view.gd`: load squads from `MonsterDB`, use `data.sprite_row` for sprites, add ability targeting highlight (yellow), and show a brief info line for the selected unit. This task is verified by running the game and playing through at least one ability activation.

**Files:**
- Modify: `game/match_view.gd`

- [ ] **Step 1: Write the updated match_view.gd**

Full replacement of `game/match_view.gd`:
```gdscript
extends Node2D

## Thin presentation layer over MatchState. Renders an isometric board with
## Polygon2D diamonds and unit Sprite2Ds, and turns clicks into engine calls.
## Hot-seat: one human controls both teams.

const TILE_W := 64
const TILE_H := 32
const BOARD_W := 7
const BOARD_H := 7
const UNIT_SCALE := 3.0
const SPRITE_LIFT := 24.0
const ENTITY_SHEET := "res://assets/Sprites/Outlined_Entities.png"

const COLOR_LIGHT   := Color(0.30, 0.42, 0.30)
const COLOR_DARK    := Color(0.24, 0.34, 0.24)
const COLOR_MOVE    := Color(0.30, 0.55, 0.95, 0.85)
const COLOR_ATTACK  := Color(0.90, 0.30, 0.30, 0.85)
const COLOR_ABILITY := Color(0.95, 0.85, 0.20, 0.85)

var _state: MatchState
var _tiles: Dictionary = {}          # Vector2i -> Polygon2D
var _sprites: Dictionary = {}        # BattleUnit -> Sprite2D
var _selected: BattleUnit = null
var _move_targets: Array[Vector2i] = []
var _atk_targets: Array[BattleUnit] = []
var _ability_targets: Array[Vector2i] = []
var _turn_label: Label
var _result_label: Label
var _info_label: Label

func _ready() -> void:
	_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_board()
	_load_squads()
	_build_ui()
	_setup_camera()
	_refresh()

func grid_to_screen(g: Vector2i) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)

func screen_to_grid(s: Vector2) -> Vector2i:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var gx := (s.x / hw + s.y / hh) * 0.5
	var gy := (s.y / hh - s.x / hw) * 0.5
	return Vector2i(roundi(gx), roundi(gy))

func _build_board() -> void:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var diamond := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])
	for y in BOARD_H:
		for x in BOARD_W:
			var g := Vector2i(x, y)
			var poly := Polygon2D.new()
			poly.polygon = diamond
			poly.position = grid_to_screen(g)
			poly.color = _base_color(g)
			add_child(poly)
			_tiles[g] = poly

func _base_color(g: Vector2i) -> Color:
	return COLOR_LIGHT if (g.x + g.y) % 2 == 0 else COLOR_DARK

func _load_squads() -> void:
	# Player squad (team 0) — bottom rows
	var player_squad: Array = [
		[&"knight", Vector2i(2, 5)],
		[&"archer", Vector2i(3, 6)],
		[&"spider", Vector2i(4, 5)],
	]
	for entry in player_squad:
		_spawn_unit(MonsterDB.get_monster(entry[0]), 0, entry[1])
	# Enemy squad (team 1) — top rows, red-tinted
	var enemy_squad: Array = [
		[&"goblin", Vector2i(2, 1)],
		[&"crab",   Vector2i(3, 0)],
		[&"bat",    Vector2i(4, 1)],
	]
	for entry in enemy_squad:
		_spawn_unit(MonsterDB.get_monster(entry[0]), 1, entry[1])

func _spawn_unit(data: MonsterData, team: int, pos: Vector2i) -> void:
	var unit := BattleUnit.new(data, team, pos)
	_state.add_unit(unit, pos)
	var spr := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ENTITY_SHEET)
	atlas.region = Rect2(0, data.sprite_row * 16, 16, 16)
	spr.texture = atlas
	spr.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
	if team == 1:
		spr.modulate = Color(1.0, 0.65, 0.65)
	add_child(spr)
	_sprites[unit] = spr

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_turn_label = Label.new()
	_turn_label.position = Vector2(16, 16)
	layer.add_child(_turn_label)
	_result_label = Label.new()
	_result_label.position = Vector2(16, 44)
	layer.add_child(_result_label)
	var btn := Button.new()
	btn.text = "End Turn"
	btn.position = Vector2(16, 80)
	btn.pressed.connect(_on_end_turn)
	layer.add_child(btn)
	_info_label = Label.new()
	_info_label.position = Vector2(16, 120)
	layer.add_child(_info_label)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(BOARD_W / 2, BOARD_H / 2))
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)
	cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if _state.winner() != -1:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tile_clicked(screen_to_grid(get_local_mouse_position()))

func _on_tile_clicked(g: Vector2i) -> void:
	if not _state.board.is_in_bounds(g):
		_deselect()
		return
	var clicked: BattleUnit = _state.board.get_unit_at(g)
	# Ability target takes priority over normal attack target
	if _selected != null and g in _ability_targets:
		_state.use_ability(_selected, g)
		_after_action()
		return
	if _selected != null and clicked != null and clicked in _atk_targets:
		_state.attack(_selected, clicked)
		_after_action()
		return
	if _selected != null and g in _move_targets:
		_state.move_unit(_selected, g)
		_after_action()
		return
	if clicked != null and clicked.team == _state.current_team:
		_selected = clicked
		_recompute_targets()
		_refresh()
		return
	_deselect()

func _after_action() -> void:
	if _selected != null and _selected.has_moved and _selected.has_acted:
		_selected = null
		_move_targets = []
		_atk_targets = []
		_ability_targets = []
	else:
		_recompute_targets()
	_sync_sprites()
	_refresh()

func _recompute_targets() -> void:
	if _selected == null:
		_move_targets = []
		_atk_targets = []
		_ability_targets = []
		return
	_move_targets = [] if _selected.has_moved else _state.legal_moves(_selected)
	_atk_targets = [] if _selected.has_acted else _state.legal_targets(_selected)
	_ability_targets = _state.legal_ability_targets(_selected)

func _deselect() -> void:
	_selected = null
	_move_targets = []
	_atk_targets = []
	_ability_targets = []
	_refresh()

func _on_end_turn() -> void:
	_state.end_turn()
	_deselect()

func _refresh() -> void:
	for g in _tiles:
		_tiles[g].color = _base_color(g)
	for g in _move_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_MOVE
	for u in _atk_targets:
		if _tiles.has(u.grid_pos):
			_tiles[u.grid_pos].color = COLOR_ATTACK
	for g in _ability_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_ABILITY
	_update_labels()

func _sync_sprites() -> void:
	for u in _sprites.keys():
		var spr: Sprite2D = _sprites[u]
		if not u.is_alive():
			spr.queue_free()
			_sprites.erase(u)
		else:
			spr.position = grid_to_screen(u.grid_pos) - Vector2(0, SPRITE_LIFT)

func _update_labels() -> void:
	var w := _state.winner()
	if w == -1:
		_turn_label.text = "Turn: %s" % ("PLAYER" if _state.current_team == 0 else "ENEMY (red tint)")
		_result_label.text = ""
	else:
		_turn_label.text = ""
		_result_label.text = "%s WINS" % ("PLAYER" if w == 0 else "ENEMY")
	if _selected != null:
		var ab_text := ""
		if _selected.data.ability != null:
			ab_text = "  [%s]" % AbilityData.Type.keys()[_selected.data.ability.type]
		_info_label.text = "%s  HP:%d/%d%s" % [
			_selected.data.display_name,
			_selected.current_hp,
			_selected.data.max_hp,
			ab_text
		]
	else:
		_info_label.text = ""
```

Use `mcp__godot-ai__filesystem_manage` with `op="write_text"` to write the file so the editor reloads it.

- [ ] **Step 2: Run the game**

Run `project_run` MCP tool, then take an `editor_screenshot`.
Expected: 7×7 isometric board, 3 player sprites (bottom), 3 enemy sprites (top, red-tinted), info panel with End Turn button and info label area.
If there are script errors, call `logs_read` and fix before continuing.

- [ ] **Step 3: Visual sprite verification**

Check the screenshot to confirm each unit shows a distinct creature sprite:
- Player knight, archer, spider should look visually different from each other.
- Enemy goblin, crab, bat should look visually different from each other.

If a sprite shows the wrong creature (e.g., two identical-looking units), adjust the `sprite_row` value in `monster_db.gd` for that creature and re-run. The correct rows are a best estimate — visual tuning is expected here.

- [ ] **Step 4: Manual ability play-test checklist**

Play a hot-seat match and verify each ability fires:

**Spider (player):**
- [ ] Select spider → move into range of an enemy → attack it → enemy tile should not show poison visually (no visual indicator yet), but at the start of enemy's next turn, that enemy takes 1 automatic damage. Confirm by End Turn-ing and watching enemy HP before they move.

**Wraith (swap spider for wraith in `_load_squads` temporarily to test — change `&"spider"` to `&"wraith"`):**
- [ ] Select wraith → yellow tiles appear beyond its normal move_range → clicking a yellow tile teleports it there → `has_moved` flag prevents normal move after.

**Imp (swap archer for imp to test — change `&"archer"` to `&"imp"`):**
- [ ] Select imp → attack an enemy with adjacent allies → the adjacent enemies also take 1 splash damage.

**Crab (enemy):**
- [ ] Have player attack the crab → crab should take 1 less damage than the attacker's raw ATK.

After verifying, revert `_load_squads` back to the original squads (knight/archer/spider vs goblin/crab/bat).

- [ ] **Step 5: Run full test suite one final time**

Run `test_run` with `{}`.
Expected: all suites pass, 0 failures, 0 load errors.

- [ ] **Step 6: Commit**

```bash
git add game/match_view.gd && \
git commit -m "feat: match_view loads MonsterDB squads with ability targeting UI"
```

---

## Definition of Done (Phase 2)

- All test suites pass with zero failures and zero load errors:
  `ability_data`, `battle_unit`, `board`, `match_abilities`, `match_combat`, `match_flow`, `match_movement`, `monster_data`, `monster_db`
- The game runs: correct sprites per monster, info label shows unit name + HP + ability type.
- All 4 abilities verified in manual play-test: poison tick, tough reduction, blink teleport, AoE strike.
- Everything committed on `master`.
- **Decision gate:** does each monster feel distinct because of its ability? If yes → write the Phase 3 plan (AI + Skirmish mode).

---

## Self-Review

**Spec coverage (Phase 2 scope):**
- All ~11 units as resources → MonsterDB (Task 4) ✓
- Animations → `sprite_row` column-0 idle frame per creature (Task 6); full walk/attack animation deferred to Phase 6 Polish as YAGNI ✓
- Abilities wired → PASSIVE_POISON, PASSIVE_TOUGH, ACTIVE_BLINK, ACTIVE_AOE_STRIKE (Tasks 1, 5, 6) ✓
- Team enforcement TODOs removed → Task 5 ✓
- Deploy phase: not included — using fixed spawn positions; interactive deploy goes in Phase 3 when AI placement is also needed ✓

**Placeholder scan:** no TBDs or vague steps. Every code step shows complete, runnable code. Sprite row estimates are flagged with a visual-verification step.

**Type consistency:** `AbilityData.Type` enum used consistently across `ability_data.gd`, `match_state.gd`, and `match_view.gd`. `MonsterData.create()` 9-param signature (7 original + `p_ability` + `p_row`) used consistently in all tasks. `monster_db.gd` calls match the signature exactly.
