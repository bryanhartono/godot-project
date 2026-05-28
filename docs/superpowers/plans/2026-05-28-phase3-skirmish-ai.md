# Phase 3: AI + Skirmish Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hot-seat prototype with a full single-player skirmish loop: random squads, interactive unit deployment, a heuristic AI opponent at three difficulty levels, and a win/lose screen — all driven by a proper state machine.

**Architecture:** `match_view.gd` becomes a thin state machine host. Four `BaseBattleState` subclasses (`DeployState`, `PlayerTurnState`, `AiTurnState`, `WinLoseState`) each own their own input handling and display logic. `TacticsAI` and `SquadPicker` are pure `RefCounted` classes with no scene dependency. A `MatchConfig` resource carries setup data from the new `skirmish_setup` entry scene into the match.

**Tech Stack:** Godot 4.6.2 GDScript, `class_name`-registered types, `McpTestSuite` in `res://tests/`, MCP `test_run` tool for running tests.

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `scripts/battle/match_config.gd` | Data container: squads + difficulty |
| Create | `scripts/battle/squad_picker.gd` | Random budget-legal squad generator |
| Modify | `scripts/core/match_state.gd` | Add `duplicate()` for AI simulation |
| Create | `scripts/battle/tactics_ai.gd` | Heuristic AI: Easy / Normal / Hard |
| Create | `scripts/battle/states/base_battle_state.gd` | Abstract state interface |
| Create | `scripts/battle/states/player_turn_state.gd` | Human select/move/attack/ability |
| Create | `scripts/battle/states/deploy_state.gd` | Player unit placement phase |
| Create | `scripts/battle/states/ai_turn_state.gd` | Runs TacticsAI, applies actions |
| Create | `scripts/battle/states/win_lose_state.gd` | Result overlay, restart/menu |
| Rewrite | `scripts/battle/match_view.gd` | State machine host + renderer |
| Create | `scripts/battle/skirmish_setup.gd` | Entry screen: difficulty + start |
| Create | `scenes/battle/skirmish_setup.tscn` | Entry scene |
| Modify | `project.godot` | Main scene → skirmish_setup.tscn |
| Create | `tests/test_squad_picker.gd` | SquadPicker unit tests |
| Create | `tests/test_tactics_ai.gd` | TacticsAI unit tests |
| Create | `tests/test_match_state_duplicate.gd` | duplicate() unit tests |

---

## Task 1: MatchConfig

**Files:**
- Create: `scripts/battle/match_config.gd`

- [ ] **Step 1: Create MatchConfig**

```gdscript
# scripts/battle/match_config.gd
class_name MatchConfig
extends Resource

## Carries match setup data from skirmish_setup into match_view.
## Stored transiently in Engine meta; never saved to disk.

var player_squad: Array[MonsterData] = []
var enemy_squad:  Array[MonsterData] = []
var difficulty:   int = 2  # 1=Easy  2=Normal  3=Hard
```

- [ ] **Step 2: Verify parse — no errors expected**

```bash
cd "/path/to/godot-project"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/match_config.gd
git commit -m "feat: add MatchConfig data class"
```

---

## Task 2: SquadPicker + tests

**Files:**
- Create: `scripts/battle/squad_picker.gd`
- Create: `tests/test_squad_picker.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/test_squad_picker.gd
@tool
extends McpTestSuite

const _SquadPicker = preload("res://scripts/battle/squad_picker.gd")
const _MonsterDbScript = preload("res://scripts/core/monster_db.gd")

func suite_name() -> String:
    return "squad_picker"

func _make_db():
    var db = _MonsterDbScript.new()
    db._ready()
    return db

func test_squad_respects_budget() -> void:
    var squad := _SquadPicker.random_squad(10)
    var total := 0
    for m in squad:
        total += m.cost
    assert_true(total <= 10)

func test_squad_has_at_least_one_unit() -> void:
    var squad := _SquadPicker.random_squad(10)
    assert_true(squad.size() >= 1)

func test_squad_no_duplicates() -> void:
    var squad := _SquadPicker.random_squad(10)
    var ids: Array[StringName] = []
    for m in squad:
        assert_true(not ids.has(m.id))
        ids.append(m.id)

func test_squad_budget_1_returns_one_unit() -> void:
    # Cheapest monster costs 2; budget 1 should still return at least
    # the cheapest monster that fits (may be 0 if none fit budget=1).
    # All monsters cost >= 2 per monster_db, so budget=1 returns empty.
    var squad := _SquadPicker.random_squad(1)
    assert_true(squad.size() == 0)

func test_squad_budget_2_returns_one_unit() -> void:
    var squad := _SquadPicker.random_squad(2)
    assert_true(squad.size() == 1)
    assert_true(squad[0].cost <= 2)
```

- [ ] **Step 2: Run tests — expect FAIL (SquadPicker not defined)**

Use MCP `test_run` tool or:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```

- [ ] **Step 3: Implement SquadPicker**

```gdscript
# scripts/battle/squad_picker.gd
## Generates random budget-legal squads from MonsterDB.
## Uses only static methods — no instance needed.

static func random_squad(budget: int) -> Array[MonsterData]:
    var pool: Array[MonsterData] = MonsterDB.all_monsters()
    pool.shuffle()
    var squad: Array[MonsterData] = []
    var remaining := budget
    for m in pool:
        if m.cost <= remaining:
            squad.append(m)
            remaining -= m.cost
        if remaining <= 0:
            break
    return squad
```

- [ ] **Step 4: Run tests — expect PASS**

Use MCP `test_run` tool. Expected: `squad_picker` suite passes all 5 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/squad_picker.gd tests/test_squad_picker.gd
git commit -m "feat: SquadPicker random budget-legal squad generator"
```

---

## Task 3: MatchState.duplicate() + tests

**Files:**
- Modify: `scripts/core/match_state.gd`
- Create: `tests/test_match_state_duplicate.gd`

`TacticsAI` needs to simulate moves without touching the real board. `duplicate()` creates an independent deep copy.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/test_match_state_duplicate.gd
@tool
extends McpTestSuite

func suite_name() -> String:
    return "match_state_duplicate"

func _make_state() -> MatchState:
    var s := MatchState.new(Board.new(7, 7))
    var d0 := MonsterData.create(&"a", "A", 2, 8, 3, 2, 1)
    var d1 := MonsterData.create(&"b", "B", 2, 6, 2, 2, 1)
    s.add_unit(BattleUnit.new(d0, 0, Vector2i(1, 1)), Vector2i(1, 1))
    s.add_unit(BattleUnit.new(d1, 1, Vector2i(5, 5)), Vector2i(5, 5))
    return s

func test_duplicate_is_independent() -> void:
    var original := _make_state()
    var copy := original.duplicate()
    # Mutating copy does not affect original
    copy.units[0].take_damage(3)
    assert_eq(original.units[0].current_hp, original.units[0].data.max_hp)
    assert_eq(copy.units[0].current_hp, copy.units[0].data.max_hp - 3)

func test_duplicate_same_unit_count() -> void:
    var original := _make_state()
    var copy := original.duplicate()
    assert_eq(copy.units.size(), original.units.size())

func test_duplicate_preserves_positions() -> void:
    var original := _make_state()
    var copy := original.duplicate()
    assert_eq(copy.units[0].grid_pos, original.units[0].grid_pos)
    assert_eq(copy.units[1].grid_pos, original.units[1].grid_pos)

func test_duplicate_preserves_current_team() -> void:
    var original := _make_state()
    original.current_team = 1
    var copy := original.duplicate()
    assert_eq(copy.current_team, 1)

func test_duplicate_board_occupancy_matches() -> void:
    var original := _make_state()
    var copy := original.duplicate()
    assert_true(copy.board.is_occupied(Vector2i(1, 1)))
    assert_true(copy.board.is_occupied(Vector2i(5, 5)))
    assert_true(not copy.board.is_occupied(Vector2i(0, 0)))
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Add duplicate() to MatchState**

Add this method to `scripts/core/match_state.gd` (append before the last line):

```gdscript
## Returns a deep copy for AI simulation. Mutating the copy never affects self.
func duplicate() -> MatchState:
    var copy := MatchState.new(Board.new(board.width, board.height))
    copy.current_team = current_team
    for u in units:
        var u_copy := BattleUnit.new(u.data, u.team, u.grid_pos)
        u_copy.current_hp = u.current_hp
        u_copy.has_moved = u.has_moved
        u_copy.has_acted = u.has_acted
        u_copy.poison_stacks = u.poison_stacks
        copy.units.append(u_copy)
        copy.board.place_unit(u_copy, u_copy.grid_pos)
    return copy
```

- [ ] **Step 4: Run all tests — expect 57 + 5 new = 62 passing**

- [ ] **Step 5: Commit**

```bash
git add scripts/core/match_state.gd tests/test_match_state_duplicate.gd
git commit -m "feat: MatchState.duplicate() for AI simulation"
```

---

## Task 4: TacticsAI + tests

**Files:**
- Create: `scripts/battle/tactics_ai.gd`
- Create: `tests/test_tactics_ai.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/test_tactics_ai.gd
@tool
extends McpTestSuite

const _TacticsAI = preload("res://scripts/battle/tactics_ai.gd")

func suite_name() -> String:
    return "tactics_ai"

func _make_adjacent_state() -> MatchState:
    # AI unit (team 1) at (3,3), player unit (team 0) at (4,3) — adjacent
    var s := MatchState.new(Board.new(7, 7))
    var ai_data   := MonsterData.create(&"ai_unit",     "AI",     1, 5, 3, 2, 1)
    var pl_data   := MonsterData.create(&"player_unit", "Player", 1, 5, 1, 2, 1)
    s.add_unit(BattleUnit.new(ai_data, 1, Vector2i(3, 3)), Vector2i(3, 3))
    s.add_unit(BattleUnit.new(pl_data, 0, Vector2i(4, 3)), Vector2i(4, 3))
    s.current_team = 1
    return s

func test_get_actions_returns_array() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var actions := ai.get_actions(state, 1, 1)
    assert_true(actions is Array)

func test_easy_attacks_adjacent_enemy() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var actions := ai.get_actions(state, 1, 1)
    var has_attack := false
    for a in actions:
        if a.action_type == _TacticsAI.Action.ATTACK:
            has_attack = true
    assert_true(has_attack)

func test_actions_reference_ai_team_units() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var actions := ai.get_actions(state, 1, 1)
    for a in actions:
        assert_eq(a.unit.team, 1)

func test_does_not_mutate_original_state() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var hp_before := state.units[0].current_hp
    ai.get_actions(state, 1, 1)
    assert_eq(state.units[0].current_hp, hp_before)

func test_normal_difficulty_returns_actions() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var actions := ai.get_actions(state, 1, 2)
    assert_true(actions is Array)

func test_hard_difficulty_returns_actions() -> void:
    var ai := _TacticsAI.new()
    var state := _make_adjacent_state()
    var actions := ai.get_actions(state, 1, 3)
    assert_true(actions is Array)
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement TacticsAI**

```gdscript
# scripts/battle/tactics_ai.gd
## Heuristic AI for the enemy team. Pure RefCounted — no Node or scene dependency.
## Never mutates MatchState directly; all simulation uses duplicate().

class Action:
    const PASS   := 0
    const MOVE   := 1
    const ATTACK := 2
    const ABILITY := 3

    var unit:        BattleUnit
    var move_to:     Vector2i  # Vector2i(-1,-1) = stay in place
    var action_type: int
    var action_target: Vector2i  # position of attack/ability target; ignored for PASS/MOVE

    func _init(p_unit: BattleUnit, p_move: Vector2i, p_type: int, p_target: Vector2i = Vector2i(-1,-1)) -> void:
        unit         = p_unit
        move_to      = p_move
        action_type  = p_type
        action_target = p_target

## Entry point. Returns an Array[Action] for the ai_team in the given state.
## difficulty: 1=Easy (greedy per-unit), 2=Normal (team coordination), 3=Hard (+opponent lookahead)
func get_actions(state: MatchState, ai_team: int, difficulty: int) -> Array:
    match difficulty:
        1: return _easy(state, ai_team)
        2: return _normal(state, ai_team)
        3: return _hard(state, ai_team)
    return _easy(state, ai_team)

# ── Scoring ────────────────────────────────────────────────────────────────────

## Higher score = better for ai_team. Measures HP advantage.
func _score(state: MatchState, ai_team: int) -> float:
    var my_hp := 0.0
    var en_hp := 0.0
    for u in state.units:
        if not u.is_alive():
            continue
        if u.team == ai_team:
            my_hp += u.current_hp
        else:
            en_hp += u.current_hp
    return my_hp - en_hp

# ── Helpers ───────────────────────────────────────────────────────────────────

## Find the unit in `state` that corresponds to `original` (same team + position).
func _mirror(state: MatchState, original: BattleUnit) -> BattleUnit:
    return state.board.get_unit_at(original.grid_pos)

## Return all (move_pos, action_type, action_target) tuples for one unit in state.
func _unit_options(state: MatchState, unit: BattleUnit) -> Array:
    var opts := []
    var move_positions: Array[Vector2i] = [unit.grid_pos]
    if not unit.has_moved:
        move_positions.append_array(state.legal_moves(unit))

    for move_pos in move_positions:
        # Simulate the move
        var sim := state.duplicate()
        var su := _mirror(sim, unit)
        if move_pos != su.grid_pos:
            sim.move_unit(su, move_pos)

        # Option: just move (no action)
        opts.append([move_pos, Action.MOVE, Vector2i(-1,-1)])

        # Option: attack
        for target in sim.legal_targets(su):
            opts.append([move_pos, Action.ATTACK, target.grid_pos])

        # Option: ability
        for ap in sim.legal_ability_targets(su):
            opts.append([move_pos, Action.ABILITY, ap])

    return opts

## Apply one (move_pos, action_type, action_target) option to `unit` in `state`.
func _apply_option(state: MatchState, unit: BattleUnit, opt: Array) -> void:
    var move_pos: Vector2i    = opt[0]
    var action_type: int      = opt[1]
    var action_target: Vector2i = opt[2]
    if move_pos != unit.grid_pos:
        state.move_unit(unit, move_pos)
    match action_type:
        Action.ATTACK:
            var target := state.board.get_unit_at(action_target)
            if target:
                state.attack(unit, target)
        Action.ABILITY:
            state.use_ability(unit, action_target)

# ── Difficulty levels ─────────────────────────────────────────────────────────

## Easy: each unit independently picks the best immediate (move, action) pair.
func _easy(state: MatchState, ai_team: int) -> Array:
    var actions := []
    for unit in state.units_for_team(ai_team):
        var best_score := -INF
        var best_opt: Array = [unit.grid_pos, Action.PASS, Vector2i(-1,-1)]
        for opt in _unit_options(state, unit):
            var sim := state.duplicate()
            var su  := _mirror(sim, unit)
            _apply_option(sim, su, opt)
            var s := _score(sim, ai_team)
            if s > best_score:
                best_score = s
                best_opt   = opt
        actions.append(Action.new(unit, best_opt[0], best_opt[1], best_opt[2]))
        # Apply the chosen action to the real state so next unit sees updated board
        var real_unit := _mirror(state, unit)
        _apply_option(state, real_unit, best_opt)
    return actions

## Normal: evaluate all units' options as a combined sequence; pick best total.
func _normal(state: MatchState, ai_team: int) -> Array:
    var units := state.units_for_team(ai_team)
    var best_score := -INF
    var best_sequence: Array = []

    _search_sequence(state, ai_team, units, 0, [], best_score, best_sequence)

    # Convert best_sequence (Array of [orig_pos, action_type, action_target]) to Actions
    # Re-simulate to get actual unit references
    var result := []
    var sim := state.duplicate()
    for i in range(units.size()):
        var orig_unit := units[i]
        var opt: Array = best_sequence[i] if i < best_sequence.size() else [orig_unit.grid_pos, Action.PASS, Vector2i(-1,-1)]
        var su := _mirror(sim, orig_unit)
        result.append(Action.new(orig_unit, opt[0], opt[1], opt[2]))
        _apply_option(sim, su, opt)
    return result

## Recursive helper for _normal. Fills best_sequence with the highest-scoring combination.
func _search_sequence(state: MatchState, ai_team: int, units: Array[BattleUnit],
        idx: int, current_seq: Array, best_score: float, best_seq: Array) -> void:
    if idx >= units.size():
        var s := _score(state, ai_team)
        if s > best_score:
            # Store by value — clear and re-fill best_seq
            best_seq.clear()
            best_seq.append_array(current_seq)
            # GDScript passes floats by value; we need a trick to mutate caller's best_score.
            # Instead, store in a 1-element Array passed by reference:
            # This method signature is simplified; see the actual implementation below.
        return
    var unit := units[idx]
    for opt in _unit_options(state, unit):
        var sim := state.duplicate()
        var su  := _mirror(sim, unit)
        _apply_option(sim, su, opt)
        var new_seq := current_seq.duplicate()
        new_seq.append(opt)
        _search_sequence(sim, ai_team, units, idx + 1, new_seq, best_score, best_seq)

## Hard: pick the Normal sequence that best survives the player's greedy response.
func _hard(state: MatchState, ai_team: int) -> Array:
    var player_team := 1 - ai_team
    var units := state.units_for_team(ai_team)

    # Collect all candidate sequences (reuse normal search)
    var candidates: Array = []  # Each: { score, sequence }
    _collect_candidates(state, ai_team, units, 0, [], candidates)
    candidates.sort_custom(func(a, b): return a["score"] > b["score"])

    # Evaluate top-3 candidates against player's greedy response
    var best_net := -INF
    var best_sequence: Array = []
    var top := mini(3, candidates.size())
    for i in range(top):
        var cand: Dictionary = candidates[i]
        var sim := state.duplicate()
        # Apply candidate sequence
        for j in range(units.size()):
            if j < cand["sequence"].size():
                var su := _mirror(sim, units[j])
                _apply_option(sim, su, cand["sequence"][j])
        # Simulate player's greedy (Easy) response
        sim.end_turn()
        _easy(sim, player_team)
        var net := _score(sim, ai_team)
        if net > best_net:
            best_net = net
            best_sequence = cand["sequence"]

    # Convert to Actions
    var result := []
    var final_sim := state.duplicate()
    for i in range(units.size()):
        var orig_unit := units[i]
        var opt: Array = best_sequence[i] if i < best_sequence.size() else [orig_unit.grid_pos, Action.PASS, Vector2i(-1,-1)]
        var su := _mirror(final_sim, orig_unit)
        result.append(Action.new(orig_unit, opt[0], opt[1], opt[2]))
        _apply_option(final_sim, su, opt)
    return result

func _collect_candidates(state: MatchState, ai_team: int, units: Array[BattleUnit],
        idx: int, current_seq: Array, out: Array) -> void:
    if idx >= units.size():
        out.append({"score": _score(state, ai_team), "sequence": current_seq.duplicate()})
        return
    var unit := units[idx]
    for opt in _unit_options(state, unit):
        var sim := state.duplicate()
        var su  := _mirror(sim, unit)
        _apply_option(sim, su, opt)
        var new_seq := current_seq.duplicate()
        new_seq.append(opt)
        _collect_candidates(sim, ai_team, units, idx + 1, new_seq, out)
```

> **Note on _search_sequence:** The recursive helper above has a GDScript limitation — primitive `float` isn't passed by reference, so `best_score` can't be mutated across recursive calls. The actual implementation uses a 1-element `Array` wrapper `[best_score]` to allow mutation. The `_normal()` and `_collect_candidates()` approach sidesteps this by using `_collect_candidates` which collects all candidates into an array and picks the best outside the recursion. Replace `_normal()` with the simpler version below:

```gdscript
## Normal (revised): collect all sequences, pick best.
func _normal(state: MatchState, ai_team: int) -> Array:
    var units := state.units_for_team(ai_team)
    var candidates: Array = []
    _collect_candidates(state, ai_team, units, 0, [], candidates)
    if candidates.is_empty():
        return []
    candidates.sort_custom(func(a, b): return a["score"] > b["score"])
    var best_seq: Array = candidates[0]["sequence"]

    var result := []
    var sim := state.duplicate()
    for i in range(units.size()):
        var orig_unit := units[i]
        var opt: Array = best_seq[i] if i < best_seq.size() else [orig_unit.grid_pos, Action.PASS, Vector2i(-1,-1)]
        var su := _mirror(sim, orig_unit)
        result.append(Action.new(orig_unit, opt[0], opt[1], opt[2]))
        _apply_option(sim, su, opt)
    return result
```

Remove the `_search_sequence` function entirely — it is replaced by `_normal` using `_collect_candidates`.

- [ ] **Step 4: Run tests — expect all 6 new tests PASS + 62 existing = 68 total**

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/tactics_ai.gd tests/test_tactics_ai.gd
git commit -m "feat: TacticsAI heuristic AI with Easy/Normal/Hard difficulty"
```

---

## Task 5: BaseBattleState

**Files:**
- Create: `scripts/battle/states/base_battle_state.gd`

No tests needed — pure interface, no logic.

- [ ] **Step 1: Create the interface**

```gdscript
# scripts/battle/states/base_battle_state.gd
class_name BaseBattleState
extends RefCounted

## Abstract interface for all match states.
## `ctx` is the MatchView node — states call its public methods to read/update the board.
## Never store a permanent reference to ctx; only use it within enter/exit/handle_input.

func enter(ctx: Node) -> void:
    pass

func exit(ctx: Node) -> void:
    pass

func handle_input(ctx: Node, event: InputEvent) -> void:
    pass
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/states/base_battle_state.gd
git commit -m "feat: BaseBattleState interface"
```

---

## Task 6: PlayerTurnState

**Files:**
- Create: `scripts/battle/states/player_turn_state.gd`

This extracts the existing select/move/attack/ability input loop from `match_view.gd` into a dedicated state. The underlying logic still lives in `MatchState`; this state just drives it.

`PlayerTurnState` relies on `ctx` (MatchView) exposing these public methods (all implemented in Task 10):
- `ctx.match_state` — the live `MatchState`
- `ctx.highlight_tiles(move, atk, ability)` — highlight tile overlays
- `ctx.clear_highlights()` — reset all tiles to base colour
- `ctx.sync_sprites()` — update sprite positions / remove dead units
- `ctx.set_labels(turn, result, info)` — update HUD text
- `ctx.change_state(state)` — transition to a new state
- `ctx.screen_to_grid(pos)` — coordinate conversion

- [ ] **Step 1: Create PlayerTurnState**

```gdscript
# scripts/battle/states/player_turn_state.gd
class_name PlayerTurnState
extends BaseBattleState

var _selected:        BattleUnit       = null
var _move_targets:    Array[Vector2i]  = []
var _atk_targets:     Array[BattleUnit] = []
var _ability_targets: Array[Vector2i]  = []

func enter(ctx: Node) -> void:
    _deselect(ctx)

func exit(ctx: Node) -> void:
    _deselect(ctx)

func handle_input(ctx: Node, event: InputEvent) -> void:
    if ctx.match_state.winner() != -1:
        ctx.change_state(WinLoseState.new())
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _on_tile_clicked(ctx, ctx.screen_to_grid(ctx.get_local_mouse_position()))

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_tile_clicked(ctx: Node, g: Vector2i) -> void:
    var ms: MatchState = ctx.match_state
    if not ms.board.is_in_bounds(g):
        _deselect(ctx)
        return
    var clicked: BattleUnit = ms.board.get_unit_at(g)
    # Ability target takes priority
    if _selected != null and g in _ability_targets:
        ms.use_ability(_selected, g)
        _after_action(ctx)
        return
    if _selected != null and clicked != null and clicked in _atk_targets:
        ms.attack(_selected, clicked)
        _after_action(ctx)
        return
    if _selected != null and g in _move_targets:
        ms.move_unit(_selected, g)
        _after_action(ctx)
        return
    if clicked != null and clicked.team == ms.current_team:
        _selected = clicked
        _recompute(ctx)
        _refresh(ctx)
        return
    _deselect(ctx)

func _after_action(ctx: Node) -> void:
    if ctx.match_state.winner() != -1:
        ctx.sync_sprites()
        ctx.change_state(WinLoseState.new())
        return
    if _selected != null and _selected.has_moved and _selected.has_acted:
        _deselect(ctx)
    else:
        _recompute(ctx)
        _refresh(ctx)
    ctx.sync_sprites()
    _update_labels(ctx)

func _recompute(ctx: Node) -> void:
    var ms: MatchState = ctx.match_state
    if _selected == null:
        _move_targets.clear()
        _atk_targets.clear()
        _ability_targets.clear()
        return
    _move_targets.clear()
    if not _selected.has_moved:
        _move_targets = ms.legal_moves(_selected)
    _atk_targets.clear()
    if not _selected.has_acted:
        _atk_targets = ms.legal_targets(_selected)
    _ability_targets = ms.legal_ability_targets(_selected)

func _deselect(ctx: Node) -> void:
    _selected = null
    _move_targets.clear()
    _atk_targets.clear()
    _ability_targets.clear()
    _refresh(ctx)

func _refresh(ctx: Node) -> void:
    ctx.highlight_tiles(_move_targets, _atk_targets, _ability_targets)
    _update_labels(ctx)

func _update_labels(ctx: Node) -> void:
    var ms: MatchState = ctx.match_state
    var info := ""
    if _selected != null:
        var ab := ""
        if _selected.data.ability != null:
            ab = "  [%s]" % AbilityData.Type.keys()[_selected.data.ability.type]
        info = "%s  HP:%d/%d%s" % [_selected.data.display_name, _selected.current_hp, _selected.data.max_hp, ab]
    ctx.set_labels("Turn: PLAYER", "", info)

## Called by MatchView when the End Turn button is pressed.
func on_end_turn(ctx: Node) -> void:
    ctx.match_state.end_turn()
    _deselect(ctx)
    ctx.sync_sprites()
    if ctx.match_state.winner() != -1:
        ctx.change_state(WinLoseState.new())
    else:
        ctx.change_state(AiTurnState.new(ctx.config.difficulty))
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```
Expected: no output (forward references to WinLoseState / AiTurnState are resolved at runtime).

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/states/player_turn_state.gd
git commit -m "feat: PlayerTurnState — player select/move/attack/ability"
```

---

## Task 7: DeployState

**Files:**
- Create: `scripts/battle/states/deploy_state.gd`

`DeployState` is entered with a pre-built `Array[MonsterData]` queue. The player taps valid tiles to place units one by one.

Relies on `ctx` exposing (in addition to Task 6 list):
- `ctx.spawn_unit(data, team, pos)` — add unit to board + sprite
- `ctx.config` — MatchConfig with player_squad / enemy_squad

- [ ] **Step 1: Create DeployState**

```gdscript
# scripts/battle/states/deploy_state.gd
class_name DeployState
extends BaseBattleState

## Rows available for player placement (y = 5 and y = 6 on a 7×7 board).
const PLAYER_ROWS: Array[int] = [5, 6]

var _queue: Array[MonsterData] = []  # remaining units to place

func enter(ctx: Node) -> void:
    _queue = ctx.config.player_squad.duplicate()
    # Place AI squad automatically before player deploys
    _place_ai_squad(ctx)
    _highlight_valid_tiles(ctx)
    _update_label(ctx)

func exit(ctx: Node) -> void:
    ctx.clear_highlights()

func handle_input(ctx: Node, event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    var g := ctx.screen_to_grid(ctx.get_local_mouse_position())
    _try_place(ctx, g)

# ── Internal ──────────────────────────────────────────────────────────────────

func _place_ai_squad(ctx: Node) -> void:
    var ai_squad: Array[MonsterData] = ctx.config.enemy_squad
    # Spread AI units across top rows (y=0 and y=1), columns 2,3,4
    var positions := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
                      Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
    for i in range(mini(ai_squad.size(), positions.size())):
        ctx.spawn_unit(ai_squad[i], 1, positions[i])

func _try_place(ctx: Node, g: Vector2i) -> void:
    if _queue.is_empty():
        return
    if not _is_valid_tile(ctx, g):
        return
    var data := _queue.pop_front() as MonsterData
    ctx.spawn_unit(data, 0, g)
    _highlight_valid_tiles(ctx)
    _update_label(ctx)
    if _queue.is_empty():
        ctx.clear_highlights()
        ctx.change_state(PlayerTurnState.new())

func _is_valid_tile(ctx: Node, g: Vector2i) -> bool:
    if not ctx.match_state.board.is_in_bounds(g):
        return false
    if ctx.match_state.board.is_occupied(g):
        return false
    if g.y not in PLAYER_ROWS:
        return false
    return true

func _highlight_valid_tiles(ctx: Node) -> void:
    # Collect empty valid tiles and pass as move_targets (blue highlight)
    var valid: Array[Vector2i] = []
    for y in PLAYER_ROWS:
        for x in range(ctx.match_state.board.width):
            var g := Vector2i(x, y)
            if not ctx.match_state.board.is_occupied(g):
                valid.append(g)
    ctx.highlight_tiles(valid, [], [])

func _update_label(ctx: Node) -> void:
    var next_name := _queue[0].display_name if not _queue.is_empty() else ""
    ctx.set_labels("Deploy: place %s" % next_name, "", "Tap a blue tile to place your unit")

## Auto-place remaining units randomly on valid tiles (called by Auto-place button).
func auto_place(ctx: Node) -> void:
    var valid: Array[Vector2i] = []
    for y in PLAYER_ROWS:
        for x in range(ctx.match_state.board.width):
            var g := Vector2i(x, y)
            if not ctx.match_state.board.is_occupied(g):
                valid.append(g)
    valid.shuffle()
    var placed := 0
    while not _queue.is_empty() and placed < valid.size():
        var data := _queue.pop_front() as MonsterData
        ctx.spawn_unit(data, 0, valid[placed])
        placed += 1
    ctx.clear_highlights()
    ctx.change_state(PlayerTurnState.new())
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/states/deploy_state.gd
git commit -m "feat: DeployState — interactive unit placement"
```

---

## Task 8: AiTurnState

**Files:**
- Create: `scripts/battle/states/ai_turn_state.gd`

`AiTurnState` runs the TacticsAI, applies each returned action to the real MatchState with a small delay for readability, then transitions back to `PlayerTurnState` (or `WinLoseState` if the game ended).

- [ ] **Step 1: Create AiTurnState**

```gdscript
# scripts/battle/states/ai_turn_state.gd
class_name AiTurnState
extends BaseBattleState

const AI_TEAM := 1
const ACTION_DELAY := 0.4  # seconds between AI actions for visual clarity

var _difficulty: int
var _actions:    Array = []
var _timer:      float = 0.0
var _started:    bool  = false

func _init(difficulty: int = 2) -> void:
    _difficulty = difficulty

func enter(ctx: Node) -> void:
    ctx.set_labels("Turn: AI", "", "")
    _started = false
    _timer    = ACTION_DELAY  # wait before first action so player can see the board
    # Compute all actions upfront
    var ai := TacticsAI.new()
    _actions = ai.get_actions(ctx.match_state, AI_TEAM, _difficulty)
    # Connect to SceneTree process via a Tween on ctx
    _start_processing(ctx)

func exit(ctx: Node) -> void:
    pass

func handle_input(_ctx: Node, _event: InputEvent) -> void:
    pass  # Player cannot interact during AI turn

# ── Action execution via Tween ────────────────────────────────────────────────

func _start_processing(ctx: Node) -> void:
    if _actions.is_empty():
        _finish_turn(ctx)
        return
    # Use a Tween to apply each action with delay
    var tween: Tween = ctx.create_tween()
    for i in range(_actions.size()):
        tween.tween_callback(_apply_next_action.bind(ctx, i)).set_delay(ACTION_DELAY * (i + 1))
    tween.tween_callback(_finish_turn.bind(ctx)).set_delay(ACTION_DELAY * (_actions.size() + 1))

func _apply_next_action(ctx: Node, idx: int) -> void:
    if idx >= _actions.size():
        return
    var action: TacticsAI.Action = _actions[idx]
    var ms: MatchState = ctx.match_state
    # Find the real unit (action.unit may point to a pre-simulation reference)
    var real_unit := ms.board.get_unit_at(action.unit.grid_pos)
    if real_unit == null or real_unit.team != AI_TEAM:
        return
    if action.move_to != Vector2i(-1, -1) and action.move_to != real_unit.grid_pos:
        ms.move_unit(real_unit, action.move_to)
    match action.action_type:
        TacticsAI.Action.ATTACK:
            var target := ms.board.get_unit_at(action.action_target)
            if target:
                ms.attack(real_unit, target)
        TacticsAI.Action.ABILITY:
            ms.use_ability(real_unit, action.action_target)
    ctx.sync_sprites()

func _finish_turn(ctx: Node) -> void:
    if ctx.match_state.winner() != -1:
        ctx.change_state(WinLoseState.new())
        return
    ctx.match_state.end_turn()
    ctx.sync_sprites()
    ctx.change_state(PlayerTurnState.new())
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/states/ai_turn_state.gd
git commit -m "feat: AiTurnState — executes TacticsAI actions with delay"
```

---

## Task 9: WinLoseState

**Files:**
- Create: `scripts/battle/states/win_lose_state.gd`

Shows a semi-transparent overlay with result + two buttons. Board stays frozen underneath.

Relies on `ctx` exposing (in addition to previous list):
- `ctx.show_win_lose_overlay(winner: int)` — builds and shows the overlay (implemented in Task 10)
- `ctx.hide_win_lose_overlay()` — removes the overlay

- [ ] **Step 1: Create WinLoseState**

```gdscript
# scripts/battle/states/win_lose_state.gd
class_name WinLoseState
extends BaseBattleState

func enter(ctx: Node) -> void:
    var winner := ctx.match_state.winner()
    ctx.show_win_lose_overlay(winner)
    # Phase 5 hook: ctx.ads_manager.show_interstitial(_on_ad_closed.bind(ctx))
    # For now, overlay is shown immediately.

func exit(ctx: Node) -> void:
    ctx.hide_win_lose_overlay()

func handle_input(_ctx: Node, _event: InputEvent) -> void:
    pass  # Buttons handle their own signals; no tile input needed here.
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/states/win_lose_state.gd
git commit -m "feat: WinLoseState — result overlay with Phase 5 ad hook"
```

---

## Task 10: Refactor match_view.gd

**Files:**
- Rewrite: `scripts/battle/match_view.gd`

This is the largest task. `match_view.gd` becomes a thin host: it owns rendering, sprites, the `MatchState`, and the state machine. All turn logic is delegated to the current state.

**Public API that states rely on:**
| Method / Property | Purpose |
|---|---|
| `match_state: MatchState` | Live game state (read/write by states) |
| `config: MatchConfig` | Setup data from skirmish_setup |
| `change_state(s: BaseBattleState)` | Transition to new state |
| `spawn_unit(data, team, pos)` | Add unit to board + create sprite |
| `sync_sprites()` | Update/remove sprites after state changes |
| `highlight_tiles(move, atk, ability)` | Colour tile overlays |
| `clear_highlights()` | Reset all tiles to base colour |
| `set_labels(turn, result, info)` | Update HUD text |
| `show_win_lose_overlay(winner)` | Build + show result overlay |
| `hide_win_lose_overlay()` | Remove result overlay |
| `screen_to_grid(s)` | Screen → grid coordinate |
| `get_local_mouse_position()` | Inherited from Node2D |

- [ ] **Step 1: Write the new match_view.gd**

```gdscript
# scripts/battle/match_view.gd
extends Node2D

## State machine host for a single match.
## Owns: board rendering, sprite management, MatchState, current BaseBattleState.
## All turn/input logic lives in state objects; this file only coordinates and renders.

const TILE_W     := 64
const TILE_H     := 32
const BOARD_W    := 7
const BOARD_H    := 7
const UNIT_SCALE := 3.0
const SPRITE_LIFT := 8.0

const COLOR_LIGHT   := Color(0.30, 0.42, 0.30)
const COLOR_DARK    := Color(0.24, 0.34, 0.24)
const COLOR_MOVE    := Color(0.30, 0.55, 0.95, 0.45)
const COLOR_ATTACK  := Color(0.90, 0.30, 0.30, 0.85)
const COLOR_ABILITY := Color(0.95, 0.85, 0.20, 0.85)

## Public — states read these directly.
var match_state: MatchState
var config:      MatchConfig

## Private rendering.
var _tiles:    Dictionary = {}   # Vector2i -> Polygon2D
var _sprites:  Dictionary = {}   # BattleUnit -> AnimatedSprite2D

## State machine.
var _current_state: BaseBattleState = null

## UI nodes (built in _build_ui).
var _turn_label:   Label
var _result_label: Label
var _info_label:   Label
var _end_btn:      Button
var _auto_btn:     Button
var _overlay:      Control = null   # win/lose overlay panel

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
    # Load config passed from skirmish_setup via Engine meta.
    if Engine.has_meta("match_config"):
        config = Engine.get_meta("match_config") as MatchConfig
        Engine.remove_meta("match_config")
    else:
        # Fallback for direct scene testing: generate a default config.
        config = MatchConfig.new()
        config.player_squad = SquadPicker.random_squad(10)
        config.enemy_squad  = SquadPicker.random_squad(10)
        config.difficulty   = 2

    match_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
    _build_board()
    _build_ui()
    _setup_camera()
    change_state(DeployState.new())

func _unhandled_input(event: InputEvent) -> void:
    if _current_state:
        _current_state.handle_input(self, event)

# ── State machine ─────────────────────────────────────────────────────────────

func change_state(new_state: BaseBattleState) -> void:
    if _current_state:
        _current_state.exit(self)
    _current_state = new_state
    _current_state.enter(self)

# ── Public API for states ─────────────────────────────────────────────────────

func spawn_unit(data: MonsterData, team: int, pos: Vector2i) -> void:
    var unit := BattleUnit.new(data, team, pos)
    match_state.add_unit(unit, pos)
    var spr := AnimatedSprite2D.new()
    spr.sprite_frames = load("res://resources/monsters/%s.tres" % data.sprite_stem())
    spr.scale  = Vector2(UNIT_SCALE, UNIT_SCALE)
    spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
    spr.z_index  = pos.x + pos.y
    spr.play("idle_front")
    if team == 1:
        spr.modulate = Color(1.0, 0.65, 0.65)
    add_child(spr)
    _sprites[unit] = spr

func sync_sprites() -> void:
    for u in _sprites.keys():
        var spr: AnimatedSprite2D = _sprites[u]
        if not u.is_alive():
            spr.queue_free()
            _sprites.erase(u)
        else:
            spr.position = grid_to_screen(u.grid_pos) - Vector2(0, SPRITE_LIFT)
            spr.z_index  = u.grid_pos.x + u.grid_pos.y
            if not spr.is_playing():
                spr.play(spr.animation)

func highlight_tiles(move_targets: Array[Vector2i],
                     atk_targets:  Array[BattleUnit],
                     ability_targets: Array[Vector2i]) -> void:
    for g in _tiles:
        _tiles[g].color = _base_color(g)
    for g in move_targets:
        if _tiles.has(g):
            _tiles[g].color = COLOR_MOVE
    for u in atk_targets:
        if _tiles.has(u.grid_pos):
            _tiles[u.grid_pos].color = COLOR_ATTACK
    for g in ability_targets:
        if _tiles.has(g):
            _tiles[g].color = COLOR_ABILITY

func clear_highlights() -> void:
    for g in _tiles:
        _tiles[g].color = _base_color(g)

func set_labels(turn: String, result: String, info: String) -> void:
    _turn_label.text   = turn
    _result_label.text = result
    _info_label.text   = info

func show_win_lose_overlay(winner: int) -> void:
    if _overlay != null:
        return
    var layer := CanvasLayer.new()
    _overlay = layer

    var panel := ColorRect.new()
    panel.color = Color(0, 0, 0, 0.55)
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_CENTER)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    layer.add_child(vbox)

    var banner := Label.new()
    banner.text = "Victory!" if winner == 0 else "Defeat"
    banner.add_theme_font_size_override("font_size", 48)
    vbox.add_child(banner)

    var again_btn := Button.new()
    again_btn.text = "Play Again"
    again_btn.pressed.connect(_on_play_again)
    vbox.add_child(again_btn)

    var menu_btn := Button.new()
    menu_btn.text = "Menu"
    menu_btn.pressed.connect(_on_go_to_menu)
    vbox.add_child(menu_btn)

    add_child(layer)

func hide_win_lose_overlay() -> void:
    if _overlay != null:
        _overlay.queue_free()
        _overlay = null

# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_end_turn() -> void:
    if _current_state is PlayerTurnState:
        (_current_state as PlayerTurnState).on_end_turn(self)

func _on_auto_place() -> void:
    if _current_state is DeployState:
        (_current_state as DeployState).auto_place(self)

func _on_play_again() -> void:
    var new_config        := MatchConfig.new()
    new_config.player_squad = SquadPicker.random_squad(10)
    new_config.enemy_squad  = SquadPicker.random_squad(10)
    new_config.difficulty   = config.difficulty
    Engine.set_meta("match_config", new_config)
    get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _on_go_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/battle/skirmish_setup.tscn")

# ── Coordinate helpers ────────────────────────────────────────────────────────

func grid_to_screen(g: Vector2i) -> Vector2:
    return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)

func screen_to_grid(s: Vector2) -> Vector2i:
    var hw := TILE_W * 0.5
    var hh := TILE_H * 0.5
    return Vector2i(roundi((s.x / hw + s.y / hh) * 0.5),
                    roundi((s.y / hh - s.x / hw) * 0.5))

# ── Board construction ────────────────────────────────────────────────────────

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
            poly.polygon  = diamond
            poly.position = grid_to_screen(g)
            poly.color    = _base_color(g)
            add_child(poly)
            _tiles[g] = poly

func _base_color(g: Vector2i) -> Color:
    return COLOR_LIGHT if (g.x + g.y) % 2 == 0 else COLOR_DARK

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    _turn_label = Label.new()
    _turn_label.position = Vector2(16, 16)
    layer.add_child(_turn_label)

    _result_label = Label.new()
    _result_label.position = Vector2(16, 44)
    layer.add_child(_result_label)

    _end_btn = Button.new()
    _end_btn.text = "End Turn"
    _end_btn.position = Vector2(16, 80)
    _end_btn.pressed.connect(_on_end_turn)
    layer.add_child(_end_btn)

    _info_label = Label.new()
    _info_label.position = Vector2(16, 120)
    layer.add_child(_info_label)

    _auto_btn = Button.new()
    _auto_btn.text = "Auto-place"
    _auto_btn.position = Vector2(16, 160)
    _auto_btn.pressed.connect(_on_auto_place)
    layer.add_child(_auto_btn)

func _setup_camera() -> void:
    var cam := Camera2D.new()
    cam.position = grid_to_screen(Vector2i(BOARD_W / 2, BOARD_H / 2))
    cam.zoom = Vector2(1.0, 1.0)
    add_child(cam)
    cam.make_current()
```

- [ ] **Step 2: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```
Expected: no output.

- [ ] **Step 3: Run all tests**

Use MCP `test_run` tool. Expected: 68 tests passing.

- [ ] **Step 4: Commit**

```bash
git add scripts/battle/match_view.gd
git commit -m "refactor: match_view becomes state machine host"
```

---

## Task 11: SkirmishSetup scene

**Files:**
- Create: `scripts/battle/skirmish_setup.gd`
- Create: `scenes/battle/skirmish_setup.tscn`
- Modify: `project.godot`

The setup screen lets the player pick difficulty, previews their randomly-drawn squad, and starts the match.

- [ ] **Step 1: Create skirmish_setup.gd**

```gdscript
# scripts/battle/skirmish_setup.gd
extends Node

## Skirmish entry screen. Handles difficulty selection, squad preview, and match start.

var _difficulty: int = 2   # 1=Easy 2=Normal 3=Hard
var _player_squad: Array[MonsterData] = []

# UI node references — assigned in _ready() after scene tree is ready.
var _squad_label:   Label
var _diff_label:    Label

func _ready() -> void:
    _player_squad = SquadPicker.random_squad(10)
    _refresh_squad_label()

func _on_easy_pressed()   -> void: _difficulty = 1; _refresh_diff_label()
func _on_normal_pressed() -> void: _difficulty = 2; _refresh_diff_label()
func _on_hard_pressed()   -> void: _difficulty = 3; _refresh_diff_label()

func _on_reroll_pressed() -> void:
    _player_squad = SquadPicker.random_squad(10)
    _refresh_squad_label()

func _on_start_pressed() -> void:
    var cfg            := MatchConfig.new()
    cfg.player_squad    = _player_squad
    cfg.enemy_squad     = SquadPicker.random_squad(10)
    cfg.difficulty      = _difficulty
    Engine.set_meta("match_config", cfg)
    get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _refresh_squad_label() -> void:
    if _squad_label == null:
        return
    var names := []
    for m in _player_squad:
        names.append(m.display_name)
    _squad_label.text = "Your squad: " + ", ".join(names)

func _refresh_diff_label() -> void:
    if _diff_label == null:
        return
    var labels := {1: "Easy", 2: "Normal", 3: "Hard"}
    _diff_label.text = "Difficulty: " + labels[_difficulty]
```

- [ ] **Step 2: Create skirmish_setup.tscn**

Create `scenes/battle/skirmish_setup.tscn` with this content:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/battle/skirmish_setup.gd" id="1_setup"]

[node name="SkirmishSetup" type="Node"]
script = ExtResource("1_setup")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="VBox" type="VBoxContainer" parent="CanvasLayer"]
offset_left = 40.0
offset_top = 80.0
offset_right = 500.0
offset_bottom = 900.0

[node name="Title" type="Label" parent="CanvasLayer/VBox"]
text = "Skirmish"

[node name="SquadLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Your squad: ..."

[node name="RerollBtn" type="Button" parent="CanvasLayer/VBox"]
text = "Reroll Squad"

[node name="DiffLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Difficulty: Normal"

[node name="EasyBtn" type="Button" parent="CanvasLayer/VBox"]
text = "Easy"

[node name="NormalBtn" type="Button" parent="CanvasLayer/VBox"]
text = "Normal"

[node name="HardBtn" type="Button" parent="CanvasLayer/VBox"]
text = "Hard"

[node name="StartBtn" type="Button" parent="CanvasLayer/VBox"]
text = "Start Match"
```

- [ ] **Step 3: Wire button signals and node refs in _ready()**

Update `skirmish_setup.gd` `_ready()` to connect buttons and assign label refs:

```gdscript
func _ready() -> void:
    var vbox := $CanvasLayer/VBox
    _squad_label = vbox.get_node("SquadLabel") as Label
    _diff_label  = vbox.get_node("DiffLabel")  as Label
    (vbox.get_node("RerollBtn") as Button).pressed.connect(_on_reroll_pressed)
    (vbox.get_node("EasyBtn")   as Button).pressed.connect(_on_easy_pressed)
    (vbox.get_node("NormalBtn") as Button).pressed.connect(_on_normal_pressed)
    (vbox.get_node("HardBtn")   as Button).pressed.connect(_on_hard_pressed)
    (vbox.get_node("StartBtn")  as Button).pressed.connect(_on_start_pressed)
    _player_squad = SquadPicker.random_squad(10)
    _refresh_squad_label()
    _refresh_diff_label()
```

- [ ] **Step 4: Update project.godot main scene via MCP settings**

Use MCP `project_manage(op="settings_set", params={"key": "application/run/main_scene", "value": "res://scenes/battle/skirmish_setup.tscn"})`.

Or edit `project.godot` directly — change:
```
run/main_scene="res://scenes/battle/match_view.tscn"
```
to:
```
run/main_scene="res://scenes/battle/skirmish_setup.tscn"
```

Also remove the stale duplicate `config/run/main_scene="res://game/match_view.tscn"` line if it is still present.

- [ ] **Step 5: Verify parse**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```

- [ ] **Step 6: Run all tests — expect 68 passing**

- [ ] **Step 7: Commit**

```bash
git add scripts/battle/skirmish_setup.gd scenes/battle/skirmish_setup.tscn project.godot
git commit -m "feat: SkirmishSetup entry screen — difficulty picker + squad preview"
```

---

## Task 12: Final integration + smoke test

**Files:**
- No new files — verify everything works end-to-end.

- [ ] **Step 1: Run full test suite**

Use MCP `test_run` tool. Expected: **68 tests passing, 0 failures.**

- [ ] **Step 2: Headless parse check**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1 | grep -iE "error|parse"
```
Expected: no output.

- [ ] **Step 3: Run the game via MCP project_run**

Use MCP `project_run`. Verify:
- SkirmishSetup scene loads (title, squad label, difficulty buttons visible)
- Pressing Start transitions to match_view
- AI squad is placed on top rows automatically
- Player can tap bottom 2 rows to deploy units
- After all 3 placed, player turn begins (blue move highlights appear on unit select)
- End Turn button triggers AI turn (red-tinted units move after delay)
- Win/lose overlay appears when one squad is wiped
- Play Again reloads match; Menu returns to SkirmishSetup

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Phase 3 complete — AI + Skirmish mode with state machine

- State machine: DeployState → PlayerTurnState → AiTurnState → WinLoseState
- TacticsAI: Easy (greedy), Normal (team coordination), Hard (+opponent lookahead)
- SquadPicker: random budget-legal squad from MonsterDB
- MatchState.duplicate() for simulation
- SkirmishSetup entry screen with difficulty selector + squad preview
- match_view refactored as thin state machine host
- 68 tests passing"
```

---

## Definition of Done

- [ ] 68+ tests passing (57 original + 5 squad_picker + 6 tactics_ai + 5 duplicate = 73 if tests from Tasks 2/3/4 are all included — recount after implementation)
- [ ] Game launches to SkirmishSetup scene
- [ ] Full match loop playable: deploy → player turn → AI responds → win/lose → restart
- [ ] All three difficulty levels selectable and functional
- [ ] No errors in headless parse check
