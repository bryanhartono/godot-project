# Phase 4a: Meta-Loop Foundation Design

## Goal

Add persistent player state — a fixed starter collection, a squad builder, and a home hub screen — so the game has a real identity between matches. Phase 4b will layer chests, ranked, and daily rewards on top of this foundation.

## Scope

- `PlayerProfile` autoload: owns all mutable player state and save/load
- `OwnedMonster`: data class pairing a MonsterData with a duplicate count
- Hub screen: new main scene, two buttons (Squad Builder + Play)
- Squad builder screen: pick from owned collection within the cost budget
- Small updates to `match_view.gd` to route back to the hub
- Delete `skirmish_setup.tscn` / `skirmish_setup.gd` (fully replaced)

**Out of scope for 4a:** earning gems, earning new monsters, chests, ranked, daily reward (all Phase 4b).

---

## Architecture

### PlayerProfile (autoload)

**File:** `scripts/core/player_profile.gd`  
**Registered as:** `PlayerProfile` in Project → Autoloads

Holds all runtime player state. Saves immediately after any mutation to `user://player_profile.json`.

```
PlayerProfile
  gems: int                      # static 100 for now; mutated in 4b
  owned: Array[OwnedMonster]     # all monsters the player possesses
  squad: Array[MonsterData]      # active squad; cost sum ≤ BUDGET (10)
```

On `_ready()`:
- If `user://player_profile.json` exists → load it, reconstruct `MonsterData` refs via `MonsterDB`
- Otherwise → create fresh profile with starter set, save immediately

**Starter set:** `soldier`, `orc`, `bat`, `ghost` (costs 2+2+2+2 = 8; all four are in the default squad).

**JSON format:**
```json
{
  "gems": 100,
  "owned": [
    { "id": "soldier",  "duplicates": 0 },
    { "id": "orc",      "duplicates": 0 },
    { "id": "bat",      "duplicates": 0 },
    { "id": "ghost",    "duplicates": 0 }
  ],
  "squad": ["soldier", "orc", "bat", "ghost"]
}
```

Public API:
```gdscript
func set_squad(new_squad: Array[MonsterData]) -> void   # validates budget, saves
func add_owned(id: StringName) -> void                  # adds or increments duplicates, saves
func squad_cost() -> int                                # sum of squad member costs
```

**Save invariant:** `squad_cost() ≤ 10` is enforced inside `set_squad()`; method is a no-op if violated.

---

### OwnedMonster

**File:** `scripts/core/owned_monster.gd`  
`class_name OwnedMonster extends RefCounted`

```gdscript
var data: MonsterData
var duplicate_count: int = 0
```

Pure data holder — no logic. `duplicate_count` is unused in 4a but stored so 4b can read it for level bonuses without a data migration.

---

### Hub Screen

**Scene:** `scenes/hub/hub.tscn`  
**Script:** `scripts/hub/hub.gd`  
**Becomes:** project main scene (replaces `skirmish_setup.tscn` in `project.godot`)

Layout (CanvasLayer → VBoxContainer, centered):
- Title label: "Monster Tactics"
- Gem counter label: "Gems: {n}" (reads `PlayerProfile.gems`)
- "My Squad" button → `get_tree().change_scene_to_file("res://scenes/hub/squad_builder.tscn")`
- "Play" button → builds `MatchConfig` from `PlayerProfile.squad` + `SquadPicker.random_squad(10)` at difficulty Normal, sets Engine meta, changes scene to `match_view.tscn`. Disabled (greyed out) if `PlayerProfile.squad.is_empty()`.

---

### Squad Builder Screen

**Scene:** `scenes/hub/squad_builder.tscn`  
**Script:** `scripts/hub/squad_builder.gd`

Three regions:

1. **Top bar** — "Budget: {used}/{max}" label + "Back" button
2. **Collection grid** (ScrollContainer → GridContainer) — one card per owned monster showing: sprite icon, display name, cost. Tapping toggles in/out of the working squad. Card is greyed and non-interactive if adding it would exceed the budget, unless it's already selected (can always deselect).
3. **Squad strip** (HBoxContainer at bottom) — shows currently selected monsters in order; tap to deselect.

On "Back": calls `PlayerProfile.set_squad(working_squad)` then returns to hub.

No separate "Confirm" button — Back always saves. The working squad is a local `Array[MonsterData]` initialized from `PlayerProfile.squad` on enter.

---

### match_view.gd changes

Two one-line changes only:

- `_on_go_to_menu()`: change target from `skirmish_setup.tscn` → `hub.tscn`
- `_on_play_again()`: build `MatchConfig` using `PlayerProfile.squad` instead of `SquadPicker.random_squad(10)` for the player squad; keep random AI squad

---

## File Map

| Action | Path |
|--------|------|
| Create | `scripts/core/player_profile.gd` |
| Create | `scripts/core/owned_monster.gd` |
| Create | `scripts/hub/hub.gd` |
| Create | `scripts/hub/squad_builder.gd` |
| Create | `scenes/hub/hub.tscn` |
| Create | `scenes/hub/squad_builder.tscn` |
| Modify | `scripts/battle/match_view.gd` |
| Modify | `project.godot` (main scene + autoload) |
| Delete | `scripts/battle/skirmish_setup.gd` |
| Delete | `scenes/battle/skirmish_setup.tscn` |
| Create | `tests/test_player_profile.gd` |
| Create | `tests/test_squad_builder_logic.gd` |

---

## Testing

**`tests/test_player_profile.gd`**
- Fresh profile has the 4 starter monsters in `owned`
- Fresh profile has all 4 starters in `squad`
- `set_squad()` accepts a valid squad (cost ≤ 10)
- `set_squad()` rejects a squad that exceeds the budget (no-op)
- Save/load round-trip: mutate squad, reload profile, squad matches

**`tests/test_squad_builder_logic.gd`**
- Can't select a monster that would exceed the budget
- Can always deselect a currently selected monster
- Selecting and deselecting updates `squad_cost()` correctly
