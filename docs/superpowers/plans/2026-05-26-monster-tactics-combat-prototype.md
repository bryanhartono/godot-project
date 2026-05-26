# Monster Tactics — Phase 1: Combat Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully-tested, pure-GDScript turn-based tactics engine (grid, units, movement, attacks, turns, win condition) and a minimal playable hot-seat isometric match scene to validate that the core combat loop is fun.

**Architecture:** Combat rules live in pure `RefCounted`/`Resource` classes under `res://game/core/` with **no dependency on the scene tree** — this makes them unit-testable via the bundled `McpTestSuite` framework. A thin `Node2D` view (`res://game/match_view.gd`) renders the grid as isometric diamonds, draws unit sprites from the existing sheet, and translates touch/click input into calls on the engine. The view holds no rules.

**Tech Stack:** Godot 4.6.2 (GDScript), `class_name`-registered classes, MCP `test_run` tool for tests (suites in `res://tests/`), iso projection done in code (no TileMap needed for the prototype).

**Scope:** This is **Phase 1 of 6** from the design spec (`docs/superpowers/specs/2026-05-26-monster-tactics-design.md`). Abilities, AI opponents, collection/meta-loop, monetization, and polish are explicitly OUT of scope here and get their own plans. The prototype is **hot-seat** (one human plays both teams) — that is enough to judge whether the moment-to-moment tactics feel good.

**Conventions used throughout:**
- Grid coordinates are `Vector2i(col, row)` with `(0,0)` at the top. The engine is a plain 2D grid; isometric look is purely a rendering concern in the view.
- Movement is 4-directional (orthogonal); attack range uses Manhattan distance.
- Teams: `0` = player (blue), `1` = enemy (red).
- Damage is deterministic: `damage = attacker.atk` (no defense stat in Phase 1).
- After each code change, run tests via the **`test_run` MCP tool**. Passing `{"suite": "<name>", "verbose": true}` runs one suite; passing `{}` runs all.

---

## Task 0: Create directory structure

**Files:**
- Create dir: `game/core/`
- Create dir: `tests/`

- [ ] **Step 1: Make the directories**

Run:
```bash
cd "/Users/bryanhartono/Documents/Game Dev/Godot/Projects/Personal/godot-project" && mkdir -p game/core tests && ls -d game/core tests
```
Expected: prints `game/core` and `tests`.

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "chore: scaffold game/core and tests directories"
```
(If git reports "nothing to commit" because empty dirs aren't tracked, that's fine — proceed; the dirs get content in Task 1.)

---

## Task 1: MonsterData resource

A monster's static stat block. A `Resource` so real units can later be authored as `.tres` files; for now we build them in code via a `create()` factory.

**Files:**
- Create: `game/core/monster_data.gd`
- Test: `tests/test_monster_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_monster_data.gd`:
```gdscript
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "monster_data", "verbose": true}`.
Expected: the file appears under `load_errors` (e.g. `test_monster_data.gd (load failed ...)`) because `MonsterData` is not declared yet. This is the failing state.

- [ ] **Step 3: Write the implementation**

Create `game/core/monster_data.gd`:
```gdscript
class_name MonsterData
extends Resource

## Static stat block for one monster type. Runtime state lives in BattleUnit.

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 1
@export var max_hp: int = 1
@export var atk: int = 1
@export var move_range: int = 1
@export var atk_range: int = 1

static func create(p_id: StringName, p_name: String, p_cost: int, p_hp: int, p_atk: int, p_move: int, p_range: int) -> MonsterData:
	var d := MonsterData.new()
	d.id = p_id
	d.display_name = p_name
	d.cost = p_cost
	d.max_hp = p_hp
	d.atk = p_atk
	d.move_range = p_move
	d.atk_range = p_range
	return d
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "monster_data", "verbose": true}`.
Expected: 2 tests pass, 0 failures, no load errors.

- [ ] **Step 5: Commit**

```bash
git add game/core/monster_data.gd tests/test_monster_data.gd
git commit -m "feat: add MonsterData stat block resource"
```

---

## Task 2: BattleUnit runtime instance

A unit on the board during a match: a reference to its `MonsterData`, plus mutable state (HP, position, team, per-turn action flags).

**Files:**
- Create: `game/core/battle_unit.gd`
- Test: `tests/test_battle_unit.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_battle_unit.gd`:
```gdscript
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "battle_unit", "verbose": true}`.
Expected: `test_battle_unit.gd` under `load_errors` (`BattleUnit` not declared). Failing state.

- [ ] **Step 3: Write the implementation**

Create `game/core/battle_unit.gd`:
```gdscript
class_name BattleUnit
extends RefCounted

## A monster instance during a match. Holds mutable state; rules live in MatchState.

var data: MonsterData
var team: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 0
var has_moved: bool = false
var has_acted: bool = false

func _init(p_data: MonsterData = null, p_team: int = 0, p_pos: Vector2i = Vector2i.ZERO) -> void:
	data = p_data
	team = p_team
	grid_pos = p_pos
	if p_data != null:
		current_hp = p_data.max_hp

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func reset_turn() -> void:
	has_moved = false
	has_acted = false
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "battle_unit", "verbose": true}`.
Expected: 4 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add game/core/battle_unit.gd tests/test_battle_unit.gd
git commit -m "feat: add BattleUnit runtime instance"
```

---

## Task 3: Board grid & occupancy

Tracks board dimensions and which `BattleUnit` occupies which tile. Pure bookkeeping — no rules.

**Files:**
- Create: `game/core/board.gd`
- Test: `tests/test_board.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_board.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "board"

func _unit() -> BattleUnit:
	return BattleUnit.new(MonsterData.create(&"x", "X", 1, 5, 1, 1, 1), 0, Vector2i.ZERO)

func test_bounds() -> void:
	var b := Board.new(7, 7)
	assert_true(b.is_in_bounds(Vector2i(0, 0)))
	assert_true(b.is_in_bounds(Vector2i(6, 6)))
	assert_false(b.is_in_bounds(Vector2i(7, 0)))
	assert_false(b.is_in_bounds(Vector2i(-1, 3)))

func test_place_and_query() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(2, 3))
	assert_true(b.is_occupied(Vector2i(2, 3)))
	assert_eq(b.get_unit_at(Vector2i(2, 3)), u)
	assert_eq(u.grid_pos, Vector2i(2, 3))

func test_relocate_moves_occupancy() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(2, 3))
	b.relocate_unit(u, Vector2i(4, 4))
	assert_false(b.is_occupied(Vector2i(2, 3)))
	assert_true(b.is_occupied(Vector2i(4, 4)))
	assert_eq(u.grid_pos, Vector2i(4, 4))

func test_remove_clears_occupancy() -> void:
	var b := Board.new(7, 7)
	var u := _unit()
	b.place_unit(u, Vector2i(1, 1))
	b.remove_unit(u)
	assert_false(b.is_occupied(Vector2i(1, 1)))
	assert_eq(b.get_unit_at(Vector2i(1, 1)), null)
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "board", "verbose": true}`.
Expected: `test_board.gd` under `load_errors` (`Board` not declared). Failing state.

- [ ] **Step 3: Write the implementation**

Create `game/core/board.gd`:
```gdscript
class_name Board
extends RefCounted

## The grid and unit occupancy. Vector2i positions are keys into _occupancy.

var width: int = 7
var height: int = 7
var _occupancy: Dictionary = {}  # Vector2i -> BattleUnit

func _init(p_width: int = 7, p_height: int = 7) -> void:
	width = p_width
	height = p_height

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_occupied(pos: Vector2i) -> bool:
	return _occupancy.has(pos)

func get_unit_at(pos: Vector2i) -> BattleUnit:
	return _occupancy.get(pos, null)

func place_unit(unit: BattleUnit, pos: Vector2i) -> void:
	_occupancy[pos] = unit
	unit.grid_pos = pos

func relocate_unit(unit: BattleUnit, pos: Vector2i) -> void:
	_occupancy.erase(unit.grid_pos)
	_occupancy[pos] = unit
	unit.grid_pos = pos

func remove_unit(unit: BattleUnit) -> void:
	_occupancy.erase(unit.grid_pos)
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "board", "verbose": true}`.
Expected: 4 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add game/core/board.gd tests/test_board.gd
git commit -m "feat: add Board grid and occupancy tracking"
```

---

## Task 4: MatchState — movement rules

The rules engine. This task creates `MatchState` with unit registration and **movement** (BFS over 4-directional steps within `move_range`, blocked by occupied tiles and bounds). Attacks and turn flow are added in Tasks 5 and 6 to the same file.

**Files:**
- Create: `game/core/match_state.gd`
- Test: `tests/test_match_movement.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_match_movement.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_movement"

func _mover(move_range: int) -> MonsterData:
	return MonsterData.create(&"m", "M", 1, 5, 2, move_range, 1)

func test_legal_moves_within_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	var moves := ms.legal_moves(u)
	assert_eq(moves.size(), 4)
	assert_contains(moves, Vector2i(4, 3))
	assert_contains(moves, Vector2i(2, 3))
	assert_contains(moves, Vector2i(3, 4))
	assert_contains(moves, Vector2i(3, 2))

func test_legal_moves_excludes_occupied_and_oob() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(0, 0))
	ms.add_unit(u, Vector2i(0, 0))
	var blocker := BattleUnit.new(_mover(1), 1, Vector2i(1, 0))
	ms.add_unit(blocker, Vector2i(1, 0))
	var moves := ms.legal_moves(u)
	assert_eq(moves.size(), 1)
	assert_contains(moves, Vector2i(0, 1))

func test_move_unit_updates_state_and_flag() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(2), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	var ok := ms.move_unit(u, Vector2i(3, 5))
	assert_true(ok)
	assert_eq(u.grid_pos, Vector2i(3, 5))
	assert_true(u.has_moved)

func test_move_unit_rejects_illegal_and_when_already_moved() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var u := BattleUnit.new(_mover(1), 0, Vector2i(3, 3))
	ms.add_unit(u, Vector2i(3, 3))
	assert_false(ms.move_unit(u, Vector2i(6, 6)))
	assert_true(ms.move_unit(u, Vector2i(3, 4)))
	assert_false(ms.move_unit(u, Vector2i(3, 5)))
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "match_movement", "verbose": true}`.
Expected: `test_match_movement.gd` under `load_errors` (`MatchState` not declared). Failing state.

- [ ] **Step 3: Write the implementation**

Create `game/core/match_state.gd`:
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
	if unit.has_moved:
		return false
	if not pos in legal_moves(unit):
		return false
	board.relocate_unit(unit, pos)
	unit.has_moved = true
	return true
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "match_movement", "verbose": true}`.
Expected: 4 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add game/core/match_state.gd tests/test_match_movement.gd
git commit -m "feat: add MatchState with movement rules"
```

---

## Task 5: MatchState — attack rules & damage

Adds target selection (enemy units within Manhattan `atk_range`) and attacking (deterministic damage; dead units leave the board).

**Files:**
- Modify: `game/core/match_state.gd` (append two methods)
- Test: `tests/test_match_combat.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_match_combat.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_combat"

func _melee() -> MonsterData:
	return MonsterData.create(&"melee", "Melee", 1, 6, 3, 1, 1)

func _ranged() -> MonsterData:
	return MonsterData.create(&"ranged", "Ranged", 1, 4, 2, 1, 3)

func test_legal_targets_only_adjacent_enemies_for_melee() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var adj_enemy := BattleUnit.new(_melee(), 1, Vector2i(3, 4))
	ms.add_unit(adj_enemy, Vector2i(3, 4))
	var far_enemy := BattleUnit.new(_melee(), 1, Vector2i(3, 6))
	ms.add_unit(far_enemy, Vector2i(3, 6))
	var ally := BattleUnit.new(_melee(), 0, Vector2i(2, 3))
	ms.add_unit(ally, Vector2i(2, 3))
	var targets := ms.legal_targets(a)
	assert_eq(targets.size(), 1)
	assert_contains(targets, adj_enemy)

func test_ranged_hits_within_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_ranged(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_melee(), 1, Vector2i(3, 6))  # manhattan dist 3
	ms.add_unit(e, Vector2i(3, 6))
	assert_contains(ms.legal_targets(a), e)

func test_attack_applies_damage_and_sets_flag() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_melee(), 1, Vector2i(3, 4))  # hp 6
	ms.add_unit(e, Vector2i(3, 4))
	var ok := ms.attack(a, e)
	assert_true(ok)
	assert_eq(e.current_hp, 3)  # 6 - 3 atk
	assert_true(a.has_acted)

func test_attack_kills_and_removes_from_board() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))   # atk 3
	ms.add_unit(a, Vector2i(3, 3))
	var e := BattleUnit.new(_ranged(), 1, Vector2i(3, 4))  # hp 4
	ms.add_unit(e, Vector2i(3, 4))
	ms.attack(a, e)        # 4 - 3 = 1 left
	a.has_acted = false    # allow a second hit for this test only
	ms.attack(a, e)        # dead
	assert_false(e.is_alive())
	assert_false(ms.board.is_occupied(Vector2i(3, 4)))

func test_attack_rejected_when_out_of_range() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(0, 0))
	ms.add_unit(a, Vector2i(0, 0))
	var e := BattleUnit.new(_melee(), 1, Vector2i(5, 5))
	ms.add_unit(e, Vector2i(5, 5))
	assert_false(ms.attack(a, e))

func test_attack_rejected_when_already_acted() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var a := BattleUnit.new(_melee(), 0, Vector2i(3, 3))
	ms.add_unit(a, Vector2i(3, 3))
	var e1 := BattleUnit.new(_melee(), 1, Vector2i(3, 4))
	ms.add_unit(e1, Vector2i(3, 4))
	var e2 := BattleUnit.new(_melee(), 1, Vector2i(2, 3))
	ms.add_unit(e2, Vector2i(2, 3))
	assert_true(ms.attack(a, e1))
	assert_false(ms.attack(a, e2))  # already acted this turn
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "match_combat", "verbose": true}`.
Expected: `test_match_combat.gd` under `load_errors` (`legal_targets` / `attack` not defined). Failing state.

- [ ] **Step 3: Write the implementation**

Append these two methods to the end of `game/core/match_state.gd`:
```gdscript

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
	if attacker.has_acted:
		return false
	if not target in legal_targets(attacker):
		return false
	target.take_damage(attacker.data.atk)
	attacker.has_acted = true
	if not target.is_alive():
		board.remove_unit(target)
	return true
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "match_combat", "verbose": true}`.
Expected: 6 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add game/core/match_state.gd tests/test_match_combat.gd
git commit -m "feat: add attack targeting and deterministic damage"
```

---

## Task 6: MatchState — turn flow & win condition

Adds `end_turn` (switch active team, reset the newly-active team's per-turn flags) and `winner` (returns the winning team, or `-1` while both sides have living units).

**Files:**
- Modify: `game/core/match_state.gd` (append two methods)
- Test: `tests/test_match_flow.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_match_flow.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "match_flow"

func _u(team: int, pos: Vector2i) -> BattleUnit:
	return BattleUnit.new(MonsterData.create(&"u", "U", 1, 5, 3, 2, 1), team, pos)

func test_winner_is_negative_one_while_both_alive() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	ms.add_unit(_u(0, Vector2i(0, 0)), Vector2i(0, 0))
	ms.add_unit(_u(1, Vector2i(6, 6)), Vector2i(6, 6))
	assert_eq(ms.winner(), -1)

func test_winner_when_enemy_wiped() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	ms.add_unit(_u(0, Vector2i(0, 0)), Vector2i(0, 0))
	var enemy := _u(1, Vector2i(0, 1))
	ms.add_unit(enemy, Vector2i(0, 1))
	enemy.take_damage(100)
	ms.board.remove_unit(enemy)
	assert_eq(ms.winner(), 0)

func test_winner_when_player_wiped() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var p := _u(0, Vector2i(0, 0))
	ms.add_unit(p, Vector2i(0, 0))
	ms.add_unit(_u(1, Vector2i(6, 6)), Vector2i(6, 6))
	p.take_damage(100)
	ms.board.remove_unit(p)
	assert_eq(ms.winner(), 1)

func test_end_turn_switches_team_and_resets_flags() -> void:
	var ms := MatchState.new(Board.new(7, 7))
	var p := _u(0, Vector2i(0, 0))
	ms.add_unit(p, Vector2i(0, 0))
	var e := _u(1, Vector2i(6, 6))
	ms.add_unit(e, Vector2i(6, 6))
	assert_eq(ms.current_team, 0)
	p.has_moved = true
	ms.end_turn()
	assert_eq(ms.current_team, 1)
	e.has_moved = true
	ms.end_turn()
	assert_eq(ms.current_team, 0)
	assert_false(p.has_moved)  # reset when team 0 became active again
```

- [ ] **Step 2: Run the test to verify it fails**

Run the `test_run` MCP tool with `{"suite": "match_flow", "verbose": true}`.
Expected: `test_match_flow.gd` under `load_errors` (`end_turn` / `winner` not defined). Failing state.

- [ ] **Step 3: Write the implementation**

Append these two methods to the end of `game/core/match_state.gd`:
```gdscript

func end_turn() -> void:
	current_team = 1 - current_team
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run the `test_run` MCP tool with `{"suite": "match_flow", "verbose": true}`.
Expected: 4 tests pass, 0 failures.

- [ ] **Step 5: Run the FULL suite to confirm no regressions**

Run the `test_run` MCP tool with `{}` (all suites).
Expected: suites `battle_unit`, `board`, `match_combat`, `match_flow`, `match_movement`, `monster_data` all pass; 0 failures; 0 load errors.

- [ ] **Step 6: Commit**

```bash
git add game/core/match_state.gd tests/test_match_flow.gd
git commit -m "feat: add turn flow and win condition"
```

---

## Task 7: Playable hot-seat isometric match scene (manual verification)

A thin `Node2D` view that renders the engine: isometric diamond tiles drawn in code, unit sprites pulled from `Outlined_Entities.png`, click-to-select/move/attack, an End Turn button, and a turn/result label. This task is verified by **running the game and playing it** — there are no unit tests for the view (it needs the running scene tree).

> The sprite `frame_row` values below are first-guess 16px rows from the sheet analysis. They will render *a* creature regardless; if a chosen row looks wrong, nudge the number — that's visual tuning, not a logic change.

**Files:**
- Create: `game/match_view.gd`
- Create: `game/match_view.tscn` (root `Node2D` named `MatchView`, script attached)
- Modify: `project.godot` (set `run/main_scene`)

- [ ] **Step 1: Create the view script**

Create `game/match_view.gd`:
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
const SPRITE_LIFT := 24.0  # lifts a 16*scale sprite so it sits on the diamond
const ENTITY_SHEET := "res://assets/Sprites/Outlined_Entities.png"

const COLOR_LIGHT := Color(0.30, 0.42, 0.30)
const COLOR_DARK := Color(0.24, 0.34, 0.24)
const COLOR_MOVE := Color(0.30, 0.55, 0.95, 0.85)
const COLOR_ATTACK := Color(0.90, 0.30, 0.30, 0.85)

var _state: MatchState
var _tiles: Dictionary = {}    # Vector2i -> Polygon2D
var _sprites: Dictionary = {}  # BattleUnit -> Sprite2D
var _selected: BattleUnit = null
var _move_targets: Array[Vector2i] = []
var _atk_targets: Array[BattleUnit] = []
var _turn_label: Label
var _result_label: Label

func _ready() -> void:
	_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_board()
	_setup_units()
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

func _setup_units() -> void:
	# Player team (0) — bottom of the board.
	_spawn(0, 8, 3, 3, 1, 0, Vector2i(2, 5))    # row 0: knight (bruiser)
	_spawn(24, 4, 2, 1, 3, 0, Vector2i(3, 6))   # row 24: archer (ranged)
	_spawn(17, 5, 2, 4, 1, 0, Vector2i(4, 5))   # row 17: spider (fast)
	# Enemy team (1) — top of the board.
	_spawn(9, 7, 3, 2, 1, 1, Vector2i(2, 1))    # row 9: goblin
	_spawn(26, 10, 1, 2, 1, 1, Vector2i(3, 0))  # row 26: crab (tank)
	_spawn(30, 4, 3, 4, 1, 1, Vector2i(4, 1))   # row 30: bat (fast)

func _spawn(frame_row: int, hp: int, atk: int, mv: int, rng: int, team: int, pos: Vector2i) -> void:
	var data := MonsterData.create(StringName("u%d" % frame_row), "U%d" % frame_row, 1, hp, atk, mv, rng)
	var unit := BattleUnit.new(data, team, pos)
	_state.add_unit(unit, pos)
	var spr := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ENTITY_SHEET)
	atlas.region = Rect2(0, frame_row * 16, 16, 16)
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
	else:
		_recompute_targets()
	_sync_sprites()
	_refresh()

func _recompute_targets() -> void:
	if _selected == null:
		_move_targets = []
		_atk_targets = []
		return
	_move_targets = [] if _selected.has_moved else _state.legal_moves(_selected)
	_atk_targets = [] if _selected.has_acted else _state.legal_targets(_selected)

func _deselect() -> void:
	_selected = null
	_move_targets = []
	_atk_targets = []
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
		_turn_label.text = "Turn: %s" % ("PLAYER (blue)" if _state.current_team == 0 else "ENEMY (red)")
		_result_label.text = ""
	else:
		_result_label.text = "%s WINS" % ("PLAYER" if w == 0 else "ENEMY")
```

- [ ] **Step 2: Create the scene**

Use the MCP tools to build and save the scene:
1. `scene_manage` with `op="create"` and `params` `{"root_type": "Node2D", "root_name": "MatchView", "path": "res://game/match_view.tscn"}`.
2. `script_attach` to attach `res://game/match_view.gd` to the `MatchView` root node.
3. `scene_save`.

(If the MCP scene tools are unavailable, create the scene in the Godot editor: New Scene → Other Node → `Node2D`, rename to `MatchView`, attach `res://game/match_view.gd`, save as `res://game/match_view.tscn`.)

- [ ] **Step 3: Set the main scene**

Edit `project.godot` so the project launches the match scene. In the `[application]` section set:
```
run/main_scene="res://game/match_view.tscn"
config/run/main_scene="res://game/match_view.tscn"
```

- [ ] **Step 4: Run and screenshot to confirm rendering**

Run the `project_run` MCP tool. Then call `editor_screenshot` (or capture the running game).
Expected: a 7×7 isometric green checkerboard with **3 blue-ish units near the bottom** and **3 red-tinted units near the top**, an "End Turn" button top-left, and a "Turn: PLAYER (blue)" label.
If nothing renders or the scene errors, check `logs_read` for script errors and fix before proceeding.

- [ ] **Step 5: Manual play-test checklist (the "is it fun?" gate)**

Play a full match (hot-seat) and confirm each:
- [ ] Clicking a player unit highlights its reachable tiles in blue and any in-range enemies in red.
- [ ] Clicking a blue tile moves the unit there; the sprite follows.
- [ ] Clicking a red-highlighted enemy deals damage; a lethal hit removes the enemy sprite.
- [ ] A unit can both move and attack in one turn, but not move twice or attack twice.
- [ ] "End Turn" switches the active team (label updates) and refreshes which units can act.
- [ ] Wiping one side shows "PLAYER WINS" / "ENEMY WINS" and input stops.

- [ ] **Step 6: Commit**

```bash
git add game/match_view.gd game/match_view.tscn project.godot
git commit -m "feat: playable hot-seat isometric match prototype"
```

---

## Definition of Done (Phase 1)

- All six logic suites pass via `test_run` `{}` with zero failures and zero load errors.
- The match scene runs, renders the iso board + 6 units, and a full hot-seat match is playable end to end (move, attack, kill, end turn, win/lose).
- Everything is committed.
- **Decision gate:** with the prototype in hand, judge whether the core tactics loop is fun. If yes → write the Phase 2 plan (data-driven roster + abilities + real sprite animations). If it needs changes, iterate on the engine/feel before expanding scope.

---

## Self-Review (completed during authoring)

**Spec coverage (Phase 1 scope only):** combat model (HP/atk/move_range/atk_range, deterministic damage) → Tasks 1,2,5; ~7×7 board → Task 3 + view; I-go-you-go turns → Task 6; wipe-squad win → Task 6; isometric rendering with tile highlights → Task 7. Out-of-scope-by-design for Phase 1: abilities, AI, collection/meta, monetization, audio — deferred to later phase plans (noted in Scope).

**Placeholder scan:** no TBD/TODO; every code step contains complete, runnable code; the sprite `frame_row` note is a tuning allowance, not missing logic.

**Type consistency:** verified names across tasks — `MonsterData.create(...)`, `BattleUnit(data, team, pos)` with `current_hp/has_moved/has_acted/is_alive/take_damage/reset_turn`; `Board.place_unit/relocate_unit/remove_unit/get_unit_at/is_occupied/is_in_bounds`; `MatchState.add_unit/units_for_team/legal_moves/move_unit/legal_targets/attack/end_turn/winner`. The view calls only these signatures. `relocate_unit` (Board) is intentionally distinct from `move_unit` (MatchState, rules-checked).
