# Procedural Maps & FFT-Style Elevation — Design Spec

**Date:** 2026-06-07  
**Status:** Approved  
**Relates to:** Phase 1 combat prototype (extends `match_view.gd`, `Board`, `MatchState`)

---

## 1. Goal

Replace the static flat 7×7 colored-diamond grid with a procedurally generated isometric board using real tile sprites from `assets/Sprites/Tiles.png`. Each match gets a unique map with 3 height levels, impassable terrain, and scattered decorations — adding tactical routing decisions without changing the core CT-initiative turn system.

---

## 2. Scope

**In scope:**
- MapData / MapTile data model
- TileRegistry (sprite sheet region catalog)
- MapGenerator (noise-based procedural generation)
- Board passability (terrain + decoration + unit movement_type)
- Dijkstra-style movement cost BFS (uphill costs extra)
- match_view.gd rendering with Sprite2D tiles + elevation Y-offset
- MonsterData.movement_type field

**Explicitly out of scope (future spec):**
- Per-unit-type elevation rules (e.g. bats fly, water/lava unit types)
- Fall damage for dropping heights
- Fence height-jump mechanics (fence is simply blocked for now)
- Map editor or hand-authored templates
- Animated water/lava tiles

---

## 3. Data Model

### 3.1 MapTile (`scripts/core/map_tile.gd`)

```gdscript
class_name MapTile

var height: int = 0
# 0 = ground, 1 = raised, 2 = cliff

var terrain: StringName = &"grass"
# &"grass" | &"stone" | &"snow" | &"desert" | &"water" | &"lava"

var decoration: StringName = &"none"
# &"none" | &"rock" | &"tree" | &"fence" | &"flower"
```

### 3.2 MapData (`scripts/core/map_data.gd`)

```gdscript
class_name MapData
extends Resource

var map_width: int = 7
var map_rows: int  = 7
var biome: StringName = &"grass"
# &"grass" | &"stone" | &"snow" | &"desert"

var tiles: Dictionary = {}
# Vector2i → MapTile
# Every in-bounds position has an entry.

func get_tile(pos: Vector2i) -> MapTile:
    return tiles.get(pos, MapTile.new())

func height_at(pos: Vector2i) -> int:
    return get_tile(pos).height

func terrain_at(pos: Vector2i) -> StringName:
    return get_tile(pos).terrain

func decoration_at(pos: Vector2i) -> StringName:
    return get_tile(pos).decoration
```

### 3.3 TileRegistry (`scripts/core/tile_registry.gd`)

Static lookup table: maps `(biome, height)` and `(decoration)` to a `Rect2i` region in `Tiles.png` (16×16 px per cell). Exact pixel coordinates are measured from the sprite sheet during implementation using an image editor or the Aseprite MCP.

```gdscript
class_name TileRegistry

# Ground tile regions — (biome, height) → Rect2i in Tiles.png
# NOTE: Rect2i values are measured from assets/Sprites/Tiles.png during
# implementation (open in Aseprite or any image editor; each cell is 16×16 px).
# This is the one manual cataloguing step before the rest can be tested.
static var GROUND: Dictionary = {
    [&"grass",   0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER — measure from sheet
    [&"grass",   1]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"grass",   2]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"stone",   0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"stone",   1]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"stone",   2]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"snow",    0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"snow",    1]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"snow",    2]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"desert",  0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"desert",  1]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"desert",  2]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER
    [&"water",   0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER — water is always height 0
    [&"lava",    0]: Rect2i(0,  0, 16, 16),  # PLACEHOLDER — lava is always height 0
}

# Decoration regions — decoration → Rect2i in Tiles.png (PLACEHOLDERS — measure from sheet)
static var DECORATION: Dictionary = {
    &"rock":   Rect2i(0, 0, 16, 16),  # PLACEHOLDER
    &"tree":   Rect2i(0, 0, 16, 16),  # PLACEHOLDER
    &"fence":  Rect2i(0, 0, 16, 16),  # PLACEHOLDER
    &"flower": Rect2i(0, 0, 16, 16),  # PLACEHOLDER
}

static func get_ground_region(biome: StringName, height: int) -> Rect2i:
    return GROUND.get([biome, height], GROUND[[&"grass", 0]])

static func get_decoration_region(dec: StringName) -> Rect2i:
    return DECORATION.get(dec, Rect2i())
```

### 3.4 MonsterData — new field

```gdscript
@export var movement_type: StringName = &"ground"
# &"ground" | &"flying" | &"water" | &"lava"
```

All existing `.tres` unit resource files default to `&"ground"` — no changes required until new unit types are added.

---

## 4. Procedural Generation

### 4.1 MapGenerator (`scripts/core/map_generator.gd`)

`RefCounted` — no scene tree dependency. Entry point:

```gdscript
static func generate(seed: int = -1) -> MapData
```

**Algorithm (retries up to 10× with a new seed on validation failure):**

**Step 1 — Biome & size**
- `biome` chosen randomly from `[&"grass", &"stone", &"snow", &"desert"]`
- `map_width` random int in `[7, 10]`
- `map_rows` random int in `[7, 10]`

**Step 2 — Height map**
- Create `FastNoiseLite` with `noise_type = SimplexSmooth`, `frequency = 0.35`
- Sample `noise.get_noise_2d(x, y)` for each cell, normalize to `[0.0, 1.0]`
- Discretize: `< 0.35 → 0`, `< 0.70 → 1`, `≥ 0.70 → 2`

**Step 3 — Terrain assignment**
- Default terrain is the map biome for all tiles
- Water/lava spawn on height-0 tiles only, at ~15% density:
  - `grass` biome → `&"water"` patches
  - `stone` biome → `&"lava"` patches
  - `snow` biome → `&"water"` patches (frozen ponds)
  - `desert` biome → `&"lava"` patches
- Use a second noise pass (different seed offset) to decide which height-0 tiles get water/lava

**Step 4 — Deploy zone protection**
- Player zone: rows `y = 0` and `y = 1`
- AI zone: rows `y = map_rows-2` and `y = map_rows-1`
- All tiles in these zones are forced to: `height = 0`, `terrain = biome` (walkable), `decoration = &"none"`

**Step 5 — Decorations**
Scattered randomly on walkable (non-water, non-lava) tiles using `randf()`:

| Decoration | Eligible heights | Eligible biomes | Density |
|------------|-----------------|-----------------|---------|
| `rock`     | 1, 2            | all             | 10%     |
| `tree`     | 0, 1            | grass, snow     | 12%     |
| `fence`    | 0, 1            | all             | 5%      |
| `flower`   | 0               | grass, snow     | 15%     |

Deploy zones are skipped (already cleared in Step 4).

**Step 6 — Connectivity validation**
- BFS from any walkable tile (not water/lava, not rock/tree decoration)
- Count reachable walkable tiles vs. total walkable tiles
- If reachable < 60% of total: validation fails → increment seed, retry from Step 1
- Max 10 retries; if all fail, fall back to a guaranteed-passable all-flat map

---

## 5. Engine Changes

### 5.1 Board (`scripts/core/board.gd`)

New method `load_map(map: MapData)` — copies elevation/terrain/decoration into the Board so the rules engine can query them without holding a reference to MapData.

```gdscript
var _elevation:   Dictionary = {}  # Vector2i → int
var _terrain:     Dictionary = {}  # Vector2i → StringName
var _decoration:  Dictionary = {}  # Vector2i → StringName

func load_map(map: MapData) -> void:
    width  = map.map_width
    height = map.map_rows
    for pos: Vector2i in map.tiles:
        var t: MapTile = map.tiles[pos]
        _elevation[pos]  = t.height
        _terrain[pos]    = t.terrain
        _decoration[pos] = t.decoration

func elevation_at(pos: Vector2i) -> int:
    return _elevation.get(pos, 0)

func is_passable(pos: Vector2i, movement_type: StringName = &"ground") -> bool:
    if not is_in_bounds(pos): return false
    var t := _terrain.get(pos, &"grass")
    var d := _decoration.get(pos, &"none")

    match t:
        &"water":
            if movement_type not in [&"flying", &"water"]: return false
        &"lava":
            if movement_type not in [&"flying", &"lava"]: return false

    if d in [&"rock", &"tree", &"fence"]:
        if movement_type != &"flying": return false

    return true
```

### 5.2 MatchState — legal_moves (`scripts/core/match_state.gd`)

Replace the simple BFS with a Dijkstra-style cost BFS. Movement budget = `unit.data.move_range`.

```gdscript
func legal_moves(unit: BattleUnit) -> Array[Vector2i]:
    if unit.has_moved: return []
    var mtype  := unit.data.movement_type
    var budget := unit.data.move_range
    var start  := unit.grid_pos
    # cost_map: Vector2i → int (cheapest cost to reach)
    var cost_map: Dictionary = { start: 0 }
    var queue: Array[Vector2i] = [start]
    var result: Array[Vector2i] = []
    var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

    while queue.size() > 0:
        queue.sort_custom(func(a, b): return cost_map[a] < cost_map[b])
        var cur: Vector2i = queue.pop_front()
        for d in dirs:
            var nb: Vector2i = cur + d
            if not board.is_in_bounds(nb): continue
            if not board.is_passable(nb, mtype): continue
            if board.get_unit_at(nb) != null: continue  # can't enter occupied tile

            var dh := board.elevation_at(nb) - board.elevation_at(cur)
            var step_cost: int = 1
            if mtype != &"flying":
                if dh >= 2: continue          # can't climb 2+ levels
                if dh == 1: step_cost = 2     # uphill costs 2

            var new_cost := cost_map[cur] + step_cost
            if new_cost > budget: continue
            if cost_map.has(nb) and cost_map[nb] <= new_cost: continue
            cost_map[nb] = new_cost
            queue.append(nb)
            if nb != start and not result.has(nb):
                result.append(nb)

    return result
```

---

## 6. Rendering Changes (`scripts/battle/match_view.gd`)

### 6.1 New constant

```gdscript
const ELEV_LIFT := TILE_H   # pixels per height level (32px)
```

### 6.2 Height-aware grid_to_screen

```gdscript
func grid_to_screen(g: Vector2i, h: int = 0) -> Vector2:
    return Vector2(
        (g.x - g.y) * TILE_W * 0.5,
        (g.x + g.y) * TILE_H * 0.5 - h * ELEV_LIFT
    )
```

All existing callers that position units, HP bars, highlights, or the ghost sprite pass the tile's height: `grid_to_screen(pos, match_state.board.elevation_at(pos))`.

### 6.3 _build_board(map: MapData)

Replaces the current `_build_board()` signature. For each tile:

1. **Ground sprite** — `Sprite2D` with `texture = Tiles.png`, `region_enabled = true`, `region_rect = TileRegistry.get_ground_region(map.biome, tile.height)`, `texture_filter = TEXTURE_FILTER_NEAREST`. Positioned at `grid_to_screen(g, tile.height)`. Z-index = `(g.x + g.y) * 3 + tile.height`.

2. **Highlight overlay** — `Polygon2D` diamond (same shape as today), transparent by default, sits at same position. This is what `highlight_tiles()` tints. Z-index = ground sprite z + 1.

3. **Decoration sprite** — if `tile.decoration != &"none"`, a second `Sprite2D` above the ground sprite using `TileRegistry.get_decoration_region(tile.decoration)`. Positioned at `grid_to_screen(g, tile.height)` minus a small lift so it sits on top of the tile. Z-index = ground sprite z + 2.

The `_tiles` dictionary (`Vector2i → Polygon2D`) continues to hold the highlight overlays — all existing highlight/clear methods work unchanged.

### 6.4 match_view._ready() change

```gdscript
var _map_data: MapData = null

func _ready() -> void:
    # ... existing config setup ...
    _map_data = MapGenerator.generate()
    match_state = MatchState.new(Board.new())
    match_state.board.load_map(_map_data)
    _build_background()
    _build_board(_map_data)   # ← now takes MapData
    _build_ui()
    _setup_camera()
    change_state(DeployState.new())
```

### 6.5 BOARD_W / BOARD_H

`BOARD_W` and `BOARD_H` constants are replaced by reading `match_state.board.width` and `match_state.board.height` at runtime (since the map is now variable-size). Any code that uses these constants for rendering loops or camera positioning is updated accordingly.

> **Naming note:** `Board.height` is the row count (the board dimension), not tile elevation. Tile elevation is accessed via `Board.elevation_at(pos)`. This matches the existing naming in `board.gd`.

---

## 7. Integration Points

| Existing system | Change |
|----------------|--------|
| `DeployState` deploy zones | Must read `board.width`/`board.height` instead of `BOARD_W`/`BOARD_H` |
| `AiTurnState._find_path` | BFS already respects `board.is_in_bounds`; add `board.is_passable(nb, unit.data.movement_type)` check |
| `PlayerTurnState._find_path` | Same — add passability check |
| Camera setup | Read board size from `board.width`/`board.height` for center calculation |
| Initiative strip | No change |

---

## 8. Testing

- `test_map_generator.gd` — generates 20 maps, asserts: connectivity ≥ 60%, deploy zones walkable, width/rows in range 7–10, all tiles have a valid terrain + decoration
- `test_board_passability.gd` — unit tests for `is_passable` with each movement_type × terrain × decoration combination
- `test_legal_moves_elevation.gd` — asserts uphill costs 2, uphill 2+ is blocked, flying ignores costs, budget is respected
- Manual playtest: walk a unit uphill, confirm they can only reach 1-cost-2 elevated tiles within budget; confirm water tiles are not selectable for ground units
