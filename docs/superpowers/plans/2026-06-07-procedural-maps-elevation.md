# Procedural Maps & FFT-Style Elevation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static flat 7×7 grid with a procedurally generated, elevation-aware isometric map rendered from real tile sprites, adding terrain variety and tactical height differences each match.

**Architecture:** Pure data classes (`MapTile`, `MapData`, `TileRegistry`, `MapGenerator`) feed a modified `Board` (passability by terrain + movement type) and a rewritten `match_view._build_board` that draws `Sprite2D` tiles instead of `Polygon2D` diamonds. `grid_to_screen` gains a height parameter so units, bars, and highlights all shift vertically with elevation.

**Tech Stack:** Godot 4.6 GDScript, `FastNoiseLite` (built-in), `Sprite2D` + `region_rect` for atlas tile rendering, `McpTestSuite` for tests.

**Tile sheet facts:** `assets/Sprites/Tiles.png` is 176×160 px — an 11-column × 10-row grid of 16×16 px cells. Rows 0–1 hold elevated cube blocks (each block is a 16×32 two-row sprite: row 0 = diamond top, row 1 = wall face). Rows 2–3 hold flat diamond tiles by biome. Rows 4–7 hold earth-colored wall/fill tiles. Rows 8–9 hold decorations. All sprite rendering uses scale `Vector2(TILE_W/16.0, TILE_H/16.0)` = `Vector2(4, 2)`.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `scripts/core/map_tile.gd` | **Create** | Per-tile data: height, terrain, decoration |
| `scripts/core/map_data.gd` | **Create** | Full board data: tiles dict + biome + dimensions |
| `scripts/core/tile_registry.gd` | **Create** | Atlas region catalog: (biome, height) → Rect2i |
| `scripts/core/map_generator.gd` | **Create** | Noise-based procedural map generation |
| `scripts/core/board.gd` | **Modify** | Add elevation/terrain/decoration dicts + load_map + is_passable |
| `scripts/core/match_state.gd` | **Modify** | Replace BFS legal_moves with Dijkstra cost-BFS |
| `scripts/core/monster_data.gd` | **Modify** | Add `movement_type: StringName` field |
| `scripts/battle/match_view.gd` | **Modify** | Sprite rendering, height-aware grid_to_screen, dynamic board size |
| `scripts/battle/states/deploy_state.gd` | **Modify** | Dynamic deploy rows based on board dimensions |
| `tests/test_map_data.gd` | **Create** | Tests for MapTile + MapData |
| `tests/test_board_passability.gd` | **Create** | Tests for is_passable across terrain/movement type combos |
| `tests/test_legal_moves_elevation.gd` | **Create** | Tests for cost-BFS movement rules |
| `tests/test_map_generator.gd` | **Create** | Tests for connectivity, deploy zones, size range |

---

## Task 0: MapTile + MapData data classes

**Files:**
- Create: `scripts/core/map_tile.gd`
- Create: `scripts/core/map_data.gd`
- Create: `tests/test_map_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_map_data.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
    return "map_data"

func test_map_tile_defaults() -> void:
    var t := MapTile.new()
    assert_eq(t.height, 0)
    assert_eq(t.terrain, &"grass")
    assert_eq(t.decoration, &"none")

func test_map_data_get_tile_returns_tile() -> void:
    var md := MapData.new()
    md.map_width = 7
    md.map_rows  = 7
    md.biome     = &"grass"
    var t := MapTile.new()
    t.height    = 2
    t.terrain   = &"stone"
    t.decoration = &"rock"
    md.tiles[Vector2i(3, 3)] = t
    assert_eq(md.height_at(Vector2i(3, 3)), 2)
    assert_eq(md.terrain_at(Vector2i(3, 3)), &"stone")
    assert_eq(md.decoration_at(Vector2i(3, 3)), &"rock")

func test_map_data_missing_tile_returns_defaults() -> void:
    var md := MapData.new()
    assert_eq(md.height_at(Vector2i(0, 0)), 0)
    assert_eq(md.terrain_at(Vector2i(0, 0)), &"grass")
    assert_eq(md.decoration_at(Vector2i(0, 0)), &"none")
```

- [ ] **Step 2: Run test to verify it fails**

Use the `test_run` MCP tool: `{"suite": "map_data", "verbose": true}`
Expected: load errors because `MapTile` and `MapData` don't exist yet.

- [ ] **Step 3: Create MapTile**

Create `scripts/core/map_tile.gd`:
```gdscript
class_name MapTile

var height: int = 0
# 0 = ground, 1 = raised, 2 = cliff

var terrain: StringName = &"grass"
# &"grass" | &"stone" | &"snow" | &"desert" | &"water" | &"lava"

var decoration: StringName = &"none"
# &"none" | &"rock" | &"tree" | &"fence" | &"flower"
```

- [ ] **Step 4: Create MapData**

Create `scripts/core/map_data.gd`:
```gdscript
class_name MapData
extends Resource

var map_width: int = 7
var map_rows: int  = 7
var biome: StringName = &"grass"
var tiles: Dictionary = {}  # Vector2i → MapTile

func get_tile(pos: Vector2i) -> MapTile:
    return tiles.get(pos, MapTile.new())

func height_at(pos: Vector2i) -> int:
    return get_tile(pos).height

func terrain_at(pos: Vector2i) -> StringName:
    return get_tile(pos).terrain

func decoration_at(pos: Vector2i) -> StringName:
    return get_tile(pos).decoration
```

- [ ] **Step 5: Run test to verify it passes**

Use `test_run` MCP: `{"suite": "map_data", "verbose": true}`
Expected: 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/map_tile.gd scripts/core/map_data.gd tests/test_map_data.gd
git commit -m "feat: add MapTile + MapData data classes"
```

---

## Task 1: TileRegistry (catalog + code)

**Files:**
- Create: `scripts/core/tile_registry.gd`

The tile sheet (`assets/Sprites/Tiles.png`) is 176×160 px — 11 columns × 10 rows at 16×16 per cell. Use the HTML grid tool below to visually identify each tile's coordinates before writing code.

- [ ] **Step 1: Generate the visual tile catalog**

Run this in a terminal to regenerate the labeled HTML grid (it was saved to `/tmp/tile_grid.html` during planning, but `/tmp` may have been cleared):

```bash
python3 - <<'EOF'
import struct, zlib, base64
def read_png(path):
    with open(path,'rb') as f: data=f.read()
    w=struct.unpack('>I',data[16:20])[0]; h=struct.unpack('>I',data[20:24])[0]
    raw=b''; i=8
    while i<len(data):
        l=struct.unpack('>I',data[i:i+4])[0]; t=data[i+4:i+8]; d=data[i+8:i+8+l]
        if t==b'IDAT': raw+=d
        i+=12+l
    dec=zlib.decompress(raw); stride=w*4+1; pixels=[]; prev=[0]*(w*4)
    for ri in range(h):
        rs=ri*stride; ft=dec[rs]; row=list(dec[rs+1:rs+1+w*4])
        if ft==1:
            for j in range(4,len(row)): row[j]=(row[j]+row[j-4])%256
        elif ft==2:
            for j in range(len(row)): row[j]=(row[j]+prev[j])%256
        elif ft==3:
            for j in range(len(row)):
                a=row[j-4] if j>=4 else 0; row[j]=(row[j]+(a+prev[j])//2)%256
        elif ft==4:
            for j in range(len(row)):
                a=row[j-4] if j>=4 else 0; b=prev[j]; c=prev[j-4] if j>=4 else 0
                pa=abs(b-c); pb=abs(a-c); pc=abs(a+b-2*c)
                pr=a if pa<=pb and pa<=pc else (b if pb<=pc else c)
                row[j]=(row[j]+pr)%256
        pixels.append(row); prev=row
    return w,h,pixels
path='/Users/bryanhartono/Documents/Game Dev/Godot/Projects/Personal/godot-project/assets/Sprites/Tiles.png'
W,H,pixels=read_png(path)
with open(path,'rb') as f: b64=base64.b64encode(f.read()).decode()
TW=TH=16; cols=W//TW; rows=H//TH; sc=4
html=f'<html><body style="background:#1a1008;font-family:monospace;padding:20px;"><h3 style="color:#eee">Tiles.png {W}x{H} = {cols}x{rows} grid (16x16, {sc}x zoom)</h3><div style="position:relative;display:inline-block;"><img src="data:image/png;base64,{b64}" style="image-rendering:pixelated;width:{W*sc}px;height:{H*sc}px;"/><svg style="position:absolute;top:0;left:0;" width="{W*sc}" height="{H*sc}">'
for r in range(rows+1): html+=f'<line x1="0" y1="{r*TH*sc}" x2="{W*sc}" y2="{r*TH*sc}" stroke="#ff0" stroke-width="0.5" opacity="0.7"/>'
for c in range(cols+1): html+=f'<line x1="{c*TW*sc}" y1="0" x2="{c*TW*sc}" y2="{H*sc}" stroke="#ff0" stroke-width="0.5" opacity="0.7"/>'
for r in range(rows):
    for c in range(cols): html+=f'<text x="{c*TW*sc+2}" y="{r*TH*sc+9}" fill="#ff0" font-size="7">r{r}c{c}</text><text x="{c*TW*sc+1}" y="{r*TH*sc+TH*sc-2}" fill="#0ff" font-size="6">({c*16},{r*16})</text>'
html+=f'</svg></div><p style="color:#888">Yellow=index, Cyan=(x,y) for Rect2i(x,y,16,16)</p></body></html>'
open('/tmp/tile_grid.html','w').write(html); print('Saved: /tmp/tile_grid.html')
EOF
open /tmp/tile_grid.html
```

- [ ] **Step 2: Identify all tile coordinates**

Using the labeled HTML grid (yellow = row/col index, cyan = pixel origin), identify the `Rect2i` for each tile type. Mark each on paper or in a text file. Look for:

- Each biome's flat diamond (height 0): bright top-face-only diamond shapes
- Each biome's elevated cube (rows 0–1 span = 16×32): 3D blocks with visible wall face
- Water flat tile, lava flat tile
- Rock, tree, fence, flower decorations (likely in rows 8–9)
- A generic dirt wall extender (a plain earth-colored rectangle, likely in rows 4–7)

- [ ] **Step 3: Create TileRegistry with identified coordinates**

Create `scripts/core/tile_registry.gd`. Fill in the `Rect2i` values from your catalog. The values below are **best-effort starting points based on color analysis — verify every one in-game**:

```gdscript
class_name TileRegistry

const TEXTURE_PATH := "res://assets/Sprites/Tiles.png"

# Flat ground tile (height 0) — 16×16 region, rendered at TILE_W×TILE_H.
# Keys: biome StringName
static var FLAT: Dictionary = {
    &"grass":  Rect2i( 64, 32, 16, 16),  # R2 C4 — verify
    &"stone":  Rect2i(  0, 32, 16, 16),  # R2 C0 — verify
    &"snow":   Rect2i( 16, 32, 16, 16),  # R2 C1 — verify
    &"desert": Rect2i( 48, 48, 16, 16),  # R3 C3 — verify
    &"water":  Rect2i(160, 32, 16, 16),  # R2 C10 — verify
    &"lava":   Rect2i( 32, 32, 16, 16),  # R2 C2 — verify
}

# Elevated cube tile (height 1) — 16×32 region spanning rows 0-1.
# Includes diamond top face (row 0) + one wall segment (row 1).
# Rendered at TILE_W × (TILE_H*2) on screen.
# Water and lava are always height 0 — no elevated variants.
static var CUBE: Dictionary = {
    &"grass":  Rect2i( 16, 0, 16, 32),  # R0-R1 C1 — verify
    &"stone":  Rect2i( 32, 0, 16, 32),  # R0-R1 C2 — verify
    &"snow":   Rect2i( 80, 0, 16, 32),  # R0-R1 C5 — verify
    &"desert": Rect2i( 48, 0, 16, 32),  # R0-R1 C3 — verify
}

# Wall extender — 16×16, used BELOW the cube sprite when height == 2
# to fill the visual gap to the ground. One generic earth-colored tile.
static var WALL_EXTENDER: Rect2i = Rect2i(0, 64, 16, 16)  # R4 C0 — verify

# Decoration sprites — 16×16, drawn above the ground tile.
# IMPORTANT: These coordinates are rough guesses from rows 8–9.
# You MUST verify them using the HTML grid — the colors in rows 8–9
# are ambiguous and the tile content cannot be determined from color alone.
static var DECORATION: Dictionary = {
    &"rock":   Rect2i( 16, 128, 16, 16),  # R8 C1 — MUST VERIFY
    &"tree":   Rect2i(  0, 128, 16, 16),  # R8 C0 — MUST VERIFY
    &"fence":  Rect2i( 96, 144, 16, 16),  # R9 C6 — MUST VERIFY
    &"flower": Rect2i( 64, 128, 16, 16),  # R8 C4 — MUST VERIFY
}

static func flat_region(biome: StringName) -> Rect2i:
    return FLAT.get(biome, FLAT[&"grass"])

static func cube_region(biome: StringName) -> Rect2i:
    return CUBE.get(biome, CUBE[&"grass"])

static func decoration_region(dec: StringName) -> Rect2i:
    return DECORATION.get(dec, Rect2i())
```

- [ ] **Step 4: Commit**

```bash
git add scripts/core/tile_registry.gd
git commit -m "feat: add TileRegistry with tile sheet region catalog"
```

---

## Task 2: Board passability

**Files:**
- Modify: `scripts/core/board.gd`
- Create: `tests/test_board_passability.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_board_passability.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
    return "board_passability"

func _make_board() -> Board:
    var b := Board.new(5, 5)
    for y in 5:
        for x in 5:
            b._terrain[Vector2i(x, y)] = &"grass"
            b._decoration[Vector2i(x, y)] = &"none"
            b._elevation[Vector2i(x, y)] = 0
    return b

func test_ground_on_grass_passable() -> void:
    var b := _make_board()
    assert_true(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_water_unit_passes_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_true(b.is_passable(Vector2i(2, 2), &"water"))

func test_water_unit_blocked_by_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_false(b.is_passable(Vector2i(2, 2), &"water"))

func test_ground_blocked_by_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_ground_blocked_by_rock() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"rock"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_tree() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"tree"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_fence() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"fence"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_rock() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"rock"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_flower_does_not_block() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"flower"
    assert_true(b.is_passable(Vector2i(2, 2), &"ground"))

func test_elevation_at_returns_height() -> void:
    var b := _make_board()
    b._elevation[Vector2i(1, 1)] = 2
    assert_eq(b.elevation_at(Vector2i(1, 1)), 2)
    assert_eq(b.elevation_at(Vector2i(0, 0)), 0)

func test_out_of_bounds_not_passable() -> void:
    var b := _make_board()
    assert_false(b.is_passable(Vector2i(-1, 0), &"ground"))
    assert_false(b.is_passable(Vector2i(5, 5), &"flying"))

func test_load_map_sets_dimensions() -> void:
    var md := MapData.new()
    md.map_width = 9
    md.map_rows  = 8
    md.biome     = &"stone"
    for y in 8:
        for x in 9:
            var t := MapTile.new()
            t.height = 0
            t.terrain = &"stone"
            t.decoration = &"none"
            md.tiles[Vector2i(x, y)] = t
    var b := Board.new()
    b.load_map(md)
    assert_eq(b.width, 9)
    assert_eq(b.height, 8)

func test_load_map_copies_terrain() -> void:
    var md := MapData.new()
    md.map_width = 3
    md.map_rows  = 3
    md.biome     = &"grass"
    for y in 3:
        for x in 3:
            var t := MapTile.new()
            md.tiles[Vector2i(x, y)] = t
    md.tiles[Vector2i(1, 1)].terrain = &"water"
    md.tiles[Vector2i(2, 2)].decoration = &"rock"
    md.tiles[Vector2i(0, 0)].height = 2
    var b := Board.new()
    b.load_map(md)
    assert_false(b.is_passable(Vector2i(1, 1), &"ground"))
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))
    assert_eq(b.elevation_at(Vector2i(0, 0)), 2)
```

- [ ] **Step 2: Run tests to verify they fail**

Use `test_run` MCP: `{"suite": "board_passability", "verbose": true}`
Expected: load errors or failures because Board lacks `_elevation`, `_terrain`, `_decoration`, `is_passable`, `elevation_at`, `load_map`.

- [ ] **Step 3: Modify Board**

Replace `scripts/core/board.gd` with:
```gdscript
class_name Board
extends RefCounted

var width: int = 7
var height: int = 7
var _occupancy:  Dictionary = {}  # Vector2i → BattleUnit
var _elevation:  Dictionary = {}  # Vector2i → int
var _terrain:    Dictionary = {}  # Vector2i → StringName
var _decoration: Dictionary = {}  # Vector2i → StringName

func _init(p_width: int = 7, p_height: int = 7) -> void:
    width  = p_width
    height = p_height

func load_map(map: MapData) -> void:
    width  = map.map_width
    height = map.map_rows
    _elevation.clear()
    _terrain.clear()
    _decoration.clear()
    for pos: Vector2i in map.tiles:
        var t: MapTile = map.tiles[pos]
        _elevation[pos]  = t.height
        _terrain[pos]    = t.terrain
        _decoration[pos] = t.decoration

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

func elevation_at(pos: Vector2i) -> int:
    return _elevation.get(pos, 0)

func is_passable(pos: Vector2i, movement_type: StringName = &"ground") -> bool:
    if not is_in_bounds(pos):
        return false
    var t: StringName = _terrain.get(pos, &"grass")
    var d: StringName = _decoration.get(pos, &"none")
    match t:
        &"water":
            if movement_type not in [&"flying", &"water"]:
                return false
        &"lava":
            if movement_type not in [&"flying", &"lava"]:
                return false
    if d in [&"rock", &"tree", &"fence"]:
        if movement_type != &"flying":
            return false
    return true
```

- [ ] **Step 4: Run tests to verify they pass**

Use `test_run` MCP: `{"suite": "board_passability", "verbose": true}`
Expected: all 16 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/board.gd tests/test_board_passability.gd
git commit -m "feat: add Board passability — terrain, decoration, elevation, load_map"
```

---

## Task 3: MonsterData.movement_type

**Files:**
- Modify: `scripts/core/monster_data.gd`

- [ ] **Step 1: Add the field to MonsterData**

In `scripts/core/monster_data.gd`, add one line after `@export var sprite_file`:
```gdscript
@export var movement_type: StringName = &"ground"
# &"ground" | &"flying" | &"water" | &"lava"
```

Also add `p_movement_type: StringName = &"ground"` to the `create()` factory, and `d.movement_type = p_movement_type` inside it:
```gdscript
static func create(p_id: StringName, p_name: String, p_cost: int, p_hp: int, p_atk: int, p_move: int, p_range: int, p_ability: AbilityData = null, p_row: int = 0, p_sprite_file: StringName = &"", p_speed: int = 3, p_movement_type: StringName = &"ground") -> MonsterData:
    var d := MonsterData.new()
    d.id            = p_id
    d.display_name  = p_name
    d.cost          = p_cost
    d.max_hp        = p_hp
    d.atk           = p_atk
    d.move_range    = p_move
    d.atk_range     = p_range
    d.ability       = p_ability
    d.sprite_row    = p_row
    d.sprite_file   = p_sprite_file
    d.speed         = p_speed
    d.movement_type = p_movement_type
    return d
```

No `.tres` file changes needed — Godot uses the `@export` default `&"ground"` for existing resources automatically.

- [ ] **Step 2: Verify the bat unit uses flying**

The `bat.tres` file is a `SpriteFrames` resource, not a `MonsterData` resource directly. MonsterData for bat is built in `MonsterDB` or `SquadPicker`. Find where bat's MonsterData is created and set `movement_type = &"flying"`. If bat uses `MonsterData.create(...)`, add `&"flying"` as the last argument. Search with:
```bash
cd "/Users/bryanhartono/Documents/Game Dev/Godot/Projects/Personal/godot-project"
grep -rn "bat\|flying" scripts/core/monster_db.gd scripts/battle/squad_picker.gd 2>/dev/null | head -20
```

If bat's MonsterData is hardcoded somewhere, set its `movement_type` to `&"flying"` there. If it's not defined yet, skip this step.

- [ ] **Step 3: Commit**

```bash
git add scripts/core/monster_data.gd
git commit -m "feat: add MonsterData.movement_type for terrain passability"
```

---

## Task 4: MatchState.legal_moves — Dijkstra cost-BFS

**Files:**
- Modify: `scripts/core/match_state.gd` (lines 132–152)
- Create: `tests/test_legal_moves_elevation.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_legal_moves_elevation.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
    return "legal_moves_elevation"

func _make_state(w: int, h: int) -> MatchState:
    var b := Board.new(w, h)
    for y in h:
        for x in w:
            b._terrain[Vector2i(x, y)]    = &"grass"
            b._decoration[Vector2i(x, y)] = &"none"
            b._elevation[Vector2i(x, y)]  = 0
    return MatchState.new(b)

func _make_unit(ms: MatchState, pos: Vector2i, move_range: int, mtype: StringName = &"ground") -> BattleUnit:
    var d := MonsterData.create(&"test", "Test", 1, 5, 1, move_range, 1)
    d.movement_type = mtype
    var u := BattleUnit.new(d, 0, pos)
    ms.board.place_unit(u, pos)
    ms.units.append(u)
    ms.active_unit = u
    return u

func test_flat_moves_budget_respected() -> void:
    var ms := _make_state(5, 1)
    var u  := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)
    assert_false(Vector2i(3, 0) in moves)

func test_uphill_one_costs_two() -> void:
    # Row: h0 at x=0, h1 at x=1, h0 at x=2
    # Unit at x=0 with move_range=2: can reach x=1 (cost 2) but not x=2 (cost 3)
    var ms := _make_state(4, 1)
    ms.board._elevation[Vector2i(1, 0)] = 1
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_false(Vector2i(2, 0) in moves)

func test_uphill_two_blocked_for_ground() -> void:
    # h0 at x=0, h2 at x=1: ground unit cannot jump 2 levels
    var ms := _make_state(3, 1)
    ms.board._elevation[Vector2i(1, 0)] = 2
    var u := _make_unit(ms, Vector2i(0, 0), 3)
    var moves := ms.legal_moves(u)
    assert_false(Vector2i(1, 0) in moves)

func test_downhill_costs_one() -> void:
    # h1 at x=0, h0 at x=1 and x=2: downhill costs 1 each
    var ms := _make_state(4, 1)
    ms.board._elevation[Vector2i(0, 0)] = 1
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)
    assert_false(Vector2i(3, 0) in moves)

func test_flying_ignores_elevation_cost() -> void:
    # h0 at x=0, h2 at x=1, h0 at x=2: flying with move_range=2 reaches all
    var ms := _make_state(5, 1)
    ms.board._elevation[Vector2i(1, 0)] = 2
    var u := _make_unit(ms, Vector2i(0, 0), 2, &"flying")
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)

func test_water_blocked_for_ground() -> void:
    var ms := _make_state(3, 1)
    ms.board._terrain[Vector2i(1, 0)] = &"water"
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_false(Vector2i(1, 0) in moves)

func test_water_passable_for_water_unit() -> void:
    var ms := _make_state(3, 1)
    ms.board._terrain[Vector2i(1, 0)] = &"water"
    var u := _make_unit(ms, Vector2i(0, 0), 2, &"water")
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)

func test_has_moved_returns_empty() -> void:
    var ms := _make_state(3, 1)
    var u  := _make_unit(ms, Vector2i(0, 0), 2)
    u.has_moved = true
    var moves := ms.legal_moves(u)
    assert_eq(moves.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Use `test_run` MCP: `{"suite": "legal_moves_elevation", "verbose": true}`
Expected: most tests fail because existing `legal_moves` ignores terrain and elevation cost.

- [ ] **Step 3: Replace legal_moves in MatchState**

In `scripts/core/match_state.gd`, replace the `legal_moves` function (currently lines 132–152) with:
```gdscript
func legal_moves(unit: BattleUnit) -> Array[Vector2i]:
    if unit.has_moved:
        return []
    var mtype:  StringName      = unit.data.movement_type
    var budget: int             = unit.data.move_range
    var start:  Vector2i        = unit.grid_pos
    var cost_map: Dictionary    = { start: 0 }
    var queue: Array[Vector2i]  = [start]
    var result: Array[Vector2i] = []

    while queue.size() > 0:
        queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
            return cost_map[a] < cost_map[b]
        )
        var cur: Vector2i = queue.pop_front()
        for d: Vector2i in DIRS:
            var nb: Vector2i = cur + d
            if not board.is_in_bounds(nb):
                continue
            if not board.is_passable(nb, mtype):
                continue
            if board.get_unit_at(nb) != null:
                continue
            var dh: int = board.elevation_at(nb) - board.elevation_at(cur)
            var step_cost: int = 1
            if mtype != &"flying":
                if dh >= 2:
                    continue
                if dh == 1:
                    step_cost = 2
            var new_cost: int = cost_map[cur] + step_cost
            if new_cost > budget:
                continue
            if cost_map.has(nb) and cost_map[nb] <= new_cost:
                continue
            cost_map[nb] = new_cost
            queue.append(nb)
            if nb not in result:
                result.append(nb)

    return result
```

- [ ] **Step 4: Run tests to verify they pass**

Use `test_run` MCP: `{"suite": "legal_moves_elevation", "verbose": true}`
Expected: all 8 tests PASS.

- [ ] **Step 5: Run all existing tests to check for regressions**

Use `test_run` MCP: `{}` (runs all suites)
Expected: all previously-passing suites still PASS. If `attack_tiles` or similar movement-related tests fail, investigate and fix.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/match_state.gd tests/test_legal_moves_elevation.gd
git commit -m "feat: Dijkstra cost-BFS legal_moves with elevation and terrain passability"
```

---

## Task 5: MapGenerator

**Files:**
- Create: `scripts/core/map_generator.gd`
- Create: `tests/test_map_generator.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_map_generator.gd`:
```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
    return "map_generator"

func test_dimensions_in_range() -> void:
    for i in 10:
        var md := MapGenerator.generate(i)
        assert_true(md.map_width  >= 7 and md.map_width  <= 10)
        assert_true(md.map_rows   >= 7 and md.map_rows   <= 10)

func test_biome_is_valid() -> void:
    var valid := [&"grass", &"stone", &"snow", &"desert"]
    for i in 10:
        var md := MapGenerator.generate(i)
        assert_true(md.biome in valid)

func test_all_positions_have_tiles() -> void:
    var md := MapGenerator.generate(0)
    for y in md.map_rows:
        for x in md.map_width:
            assert_true(md.tiles.has(Vector2i(x, y)))

func test_deploy_zones_are_walkable() -> void:
    for i in 5:
        var md := MapGenerator.generate(i)
        for y in [0, 1, md.map_rows - 2, md.map_rows - 1]:
            for x in md.map_width:
                var t: MapTile = md.tiles[Vector2i(x, y)]
                assert_eq(t.height, 0)
                assert_true(t.terrain in [&"grass", &"stone", &"snow", &"desert"])
                assert_eq(t.decoration, &"none")

func test_height_values_in_range() -> void:
    var md := MapGenerator.generate(0)
    for pos: Vector2i in md.tiles:
        var h: int = md.tiles[pos].height
        assert_true(h >= 0 and h <= 2)

func test_connectivity_at_least_60_percent() -> void:
    for i in 5:
        var md := MapGenerator.generate(i)
        var walkable: Array[Vector2i] = []
        for pos: Vector2i in md.tiles:
            var t: MapTile = md.tiles[pos]
            if t.terrain not in [&"water", &"lava"] and t.decoration not in [&"rock", &"tree", &"fence"]:
                walkable.append(pos)
        if walkable.is_empty():
            continue
        # BFS from first walkable tile
        var visited: Dictionary = {}
        var queue: Array[Vector2i] = [walkable[0]]
        visited[walkable[0]] = true
        var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
        while queue.size() > 0:
            var cur: Vector2i = queue.pop_front()
            for d in dirs:
                var nb: Vector2i = cur + d
                if visited.has(nb): continue
                if not md.tiles.has(nb): continue
                var t2: MapTile = md.tiles[nb]
                if t2.terrain in [&"water", &"lava"]: continue
                if t2.decoration in [&"rock", &"tree", &"fence"]: continue
                visited[nb] = true
                queue.append(nb)
        var ratio: float = float(visited.size()) / float(walkable.size())
        assert_true(ratio >= 0.60)
```

- [ ] **Step 2: Run tests to verify they fail**

Use `test_run` MCP: `{"suite": "map_generator", "verbose": true}`
Expected: load error because `MapGenerator` doesn't exist.

- [ ] **Step 3: Create MapGenerator**

Create `scripts/core/map_generator.gd`:
```gdscript
class_name MapGenerator

const BIOMES:  Array[StringName] = [&"grass", &"stone", &"snow", &"desert"]
const MIN_SIZE := 7
const MAX_SIZE := 10
const WATER_LAVA_DENSITY := 0.15
const DECORATION_DENSITIES := {
    &"rock":   0.10,
    &"tree":   0.12,
    &"fence":  0.05,
    &"flower": 0.15,
}
const TREE_BIOMES:   Array[StringName] = [&"grass", &"snow"]
const FLOWER_BIOMES: Array[StringName] = [&"grass", &"snow"]
const MAX_RETRIES := 10

static func generate(seed: int = -1) -> MapData:
    if seed < 0:
        seed = randi()
    for attempt in MAX_RETRIES:
        var md := _attempt(seed + attempt)
        if _validate(md):
            return md
    return _flat_fallback(seed)

static func _attempt(seed: int) -> MapData:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed

    var md         := MapData.new()
    md.biome       = BIOMES[rng.randi() % BIOMES.size()]
    md.map_width   = MIN_SIZE + rng.randi() % (MAX_SIZE - MIN_SIZE + 1)
    md.map_rows    = MIN_SIZE + rng.randi() % (MAX_SIZE - MIN_SIZE + 1)

    # Height noise
    var hn := FastNoiseLite.new()
    hn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    hn.frequency  = 0.35
    hn.seed       = seed

    # Water/lava placement noise
    var wn := FastNoiseLite.new()
    wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    wn.frequency  = 0.5
    wn.seed       = seed + 1000

    var water_terrain: StringName = &"water" if md.biome in [&"grass", &"snow"] else &"lava"

    # Build tiles
    for y in md.map_rows:
        for x in md.map_width:
            var pos   := Vector2i(x, y)
            var t     := MapTile.new()
            t.terrain  = md.biome

            var raw: float = (hn.get_noise_2d(x, y) + 1.0) * 0.5  # normalise [0,1]
            if   raw < 0.35: t.height = 0
            elif raw < 0.70: t.height = 1
            else:            t.height = 2

            # Water/lava on height-0 tiles only
            if t.height == 0:
                var wraw: float = (wn.get_noise_2d(x, y) + 1.0) * 0.5
                if wraw < WATER_LAVA_DENSITY:
                    t.terrain = water_terrain

            md.tiles[pos] = t

    # Protect deploy zones
    for y in [0, 1, md.map_rows - 2, md.map_rows - 1]:
        for x in md.map_width:
            var t: MapTile = md.tiles[Vector2i(x, y)]
            t.height      = 0
            t.terrain     = md.biome
            t.decoration  = &"none"

    # Scatter decorations on walkable tiles (skip deploy zones)
    var protected_ys: Array[int] = [0, 1, md.map_rows - 2, md.map_rows - 1]
    for y in md.map_rows:
        if y in protected_ys:
            continue
        for x in md.map_width:
            var pos := Vector2i(x, y)
            var t: MapTile = md.tiles[pos]
            if t.terrain in [&"water", &"lava"]:
                continue
            t.decoration = _pick_decoration(rng, t, md.biome)

    return md

static func _pick_decoration(rng: RandomNumberGenerator, t: MapTile, biome: StringName) -> StringName:
    if t.height in [1, 2] and rng.randf() < DECORATION_DENSITIES[&"rock"]:
        return &"rock"
    if t.height in [0, 1] and biome in TREE_BIOMES and rng.randf() < DECORATION_DENSITIES[&"tree"]:
        return &"tree"
    if t.height in [0, 1] and rng.randf() < DECORATION_DENSITIES[&"fence"]:
        return &"fence"
    if t.height == 0 and biome in FLOWER_BIOMES and rng.randf() < DECORATION_DENSITIES[&"flower"]:
        return &"flower"
    return &"none"

static func _validate(md: MapData) -> bool:
    var walkable: Array[Vector2i] = []
    for pos: Vector2i in md.tiles:
        var t: MapTile = md.tiles[pos]
        if t.terrain not in [&"water", &"lava"] and t.decoration not in [&"rock", &"tree", &"fence"]:
            walkable.append(pos)
    if walkable.is_empty():
        return false
    var visited: Dictionary = {}
    var queue: Array[Vector2i] = [walkable[0]]
    visited[walkable[0]] = true
    var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
    while queue.size() > 0:
        var cur: Vector2i = queue.pop_front()
        for d in dirs:
            var nb: Vector2i = cur + d
            if visited.has(nb): continue
            if not md.tiles.has(nb): continue
            var t2: MapTile = md.tiles[nb]
            if t2.terrain in [&"water", &"lava"]: continue
            if t2.decoration in [&"rock", &"tree", &"fence"]: continue
            visited[nb] = true
            queue.append(nb)
    return float(visited.size()) / float(walkable.size()) >= 0.60

static func _flat_fallback(seed: int) -> MapData:
    var rng  := RandomNumberGenerator.new()
    rng.seed  = seed
    var md   := MapData.new()
    md.biome  = BIOMES[rng.randi() % BIOMES.size()]
    md.map_width = 7
    md.map_rows  = 7
    for y in 7:
        for x in 7:
            var t     := MapTile.new()
            t.terrain  = md.biome
            md.tiles[Vector2i(x, y)] = t
    return md
```

- [ ] **Step 4: Run tests to verify they pass**

Use `test_run` MCP: `{"suite": "map_generator", "verbose": true}`
Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/map_generator.gd tests/test_map_generator.gd
git commit -m "feat: MapGenerator — noise-based procedural map generation"
```

---

## Task 6: match_view.gd — sprite rendering + elevation

**Files:**
- Modify: `scripts/battle/match_view.gd`

This task replaces the `Polygon2D` tile rendering with `Sprite2D` tiles from `Tiles.png`, adds the `h` parameter to `grid_to_screen`, and builds decoration sprites. The highlight `Polygon2D` overlays remain as the tinting layer above each sprite.

- [ ] **Step 1: Add ELEV_LIFT constant and update grid_to_screen**

In `match_view.gd`, add the constant after the existing constants block:
```gdscript
const ELEV_LIFT   := TILE_H      # screen pixels raised per height level (32px)
```

Replace the `grid_to_screen` function:
```gdscript
func grid_to_screen(g: Vector2i, h: int = 0) -> Vector2:
    return Vector2(
        (g.x - g.y) * TILE_W * 0.5,
        (g.x + g.y) * TILE_H * 0.5 - h * ELEV_LIFT
    )
```

- [ ] **Step 2: Update all grid_to_screen callers to pass height**

Every call to `grid_to_screen(pos)` that positions a unit, bar, ghost, or overlay needs to pass the tile's height. Find all callers with:
```bash
grep -n "grid_to_screen" scripts/battle/match_view.gd
```

For each caller that positions game objects (not tile construction itself), change:
```gdscript
grid_to_screen(some_pos)
# to:
grid_to_screen(some_pos, match_state.board.elevation_at(some_pos))
```

Callers that set up the board geometry (inside `_build_board`) should NOT add height — the tile sprite renderer handles that internally.

- [ ] **Step 3: Rewrite _build_board to accept MapData and draw sprites**

Replace the `_build_board()` function signature and body:
```gdscript
func _build_board(map: MapData) -> void:
    var tile_tex: Texture2D = load(TileRegistry.TEXTURE_PATH)
    var hw := TILE_W * 0.5
    var hh := TILE_H * 0.5
    # Diamond shape for highlight overlays (same as before)
    var diamond := PackedVector2Array([
        Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
    ])
    var scale_flat := Vector2(float(TILE_W) / 16.0, float(TILE_H) / 16.0)  # 4×2

    for y in map.map_rows:
        for x in map.map_width:
            var g    := Vector2i(x, y)
            var tile := map.get_tile(g)
            var h    := tile.height
            var z_base: int = (x + y) * 3 + h

            # ── Ground sprite ────────────────────────────────────────
            var spr := Sprite2D.new()
            spr.texture         = tile_tex
            spr.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
            spr.centered        = false
            spr.region_enabled  = true
            if h == 0 or tile.terrain in [&"water", &"lava"]:
                spr.region_rect = TileRegistry.flat_region(tile.terrain)
                spr.scale       = scale_flat
            else:
                # Elevated cube: 16×32 region → 64×64 on screen
                spr.region_rect = TileRegistry.cube_region(map.biome)
                spr.scale       = scale_flat  # scale_flat applied to 32-tall region → 64px tall
            # Position sprite so diamond center aligns with grid_to_screen(g, h)
            spr.position = grid_to_screen(g, h) - Vector2(hw, hh)
            spr.z_index  = z_base
            add_child(spr)

            # Wall extender for height 2 — fills the gap below the cube sprite
            if h == 2:
                var ext := Sprite2D.new()
                ext.texture        = tile_tex
                ext.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                ext.centered       = false
                ext.region_enabled = true
                ext.region_rect    = TileRegistry.WALL_EXTENDER
                ext.scale          = scale_flat
                # Position at height-1 level (one ELEV_LIFT below the cube top)
                ext.position = grid_to_screen(g, 1) - Vector2(hw, hh)
                ext.z_index  = (x + y) * 3 + 1
                add_child(ext)

            # ── Highlight overlay (Polygon2D, same as before) ────────
            var poly := Polygon2D.new()
            poly.polygon  = diamond
            poly.color    = Color(0, 0, 0, 0)   # transparent until highlighted
            poly.position = grid_to_screen(g, h)
            poly.z_index  = z_base + 1
            add_child(poly)
            _tiles[g] = poly

            # ── Decoration sprite ────────────────────────────────────
            if tile.decoration != &"none" and tile.decoration != &"flower":
                var dec := Sprite2D.new()
                dec.texture        = tile_tex
                dec.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                dec.centered       = false
                dec.region_enabled = true
                dec.region_rect    = TileRegistry.decoration_region(tile.decoration)
                dec.scale          = scale_flat
                # Sit on top of the tile diamond
                dec.position = grid_to_screen(g, h) - Vector2(hw, hh + TILE_H * 0.5)
                dec.z_index  = z_base + 2
                add_child(dec)
            elif tile.decoration == &"flower":
                var dec := Sprite2D.new()
                dec.texture        = tile_tex
                dec.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                dec.centered       = false
                dec.region_enabled = true
                dec.region_rect    = TileRegistry.decoration_region(&"flower")
                dec.scale          = scale_flat
                dec.position = grid_to_screen(g, h) - Vector2(hw, hh + TILE_H * 0.25)
                dec.z_index  = z_base + 2
                add_child(dec)

    # Active unit gold highlight
    _active_highlight          = Polygon2D.new()
    _active_highlight.polygon  = diamond
    _active_highlight.color    = Color(1.0, 0.90, 0.20, 0.60)
    _active_highlight.z_index  = 2
    _active_highlight.visible  = false
    add_child(_active_highlight)

    # Hover overlay
    _hover_poly         = Polygon2D.new()
    _hover_poly.polygon = diamond
    _hover_poly.color   = Color(1.0, 1.0, 1.0, 0.22)
    _hover_poly.visible = false
    _hover_poly.z_index = 999
    add_child(_hover_poly)
```

- [ ] **Step 4: Update highlight_tiles to use Color with alpha instead of lerp**

The existing `highlight_tiles` sets `poly.color = _base_color(g).lerp(...)`. Since sprites now show the ground texture, highlights should be a semi-transparent tint overlay. Replace the highlight color logic:
```gdscript
func highlight_tiles(move_targets: Array[Vector2i],
                     atk_targets:  Array[BattleUnit],
                     ability_targets: Array[Vector2i]) -> void:
    for g in _tiles:
        _tiles[g].color = Color(0, 0, 0, 0)
    for g in move_targets:
        if _tiles.has(g):
            _tiles[g].color = Color(0.30, 0.55, 0.95, 0.45)
    for u in atk_targets:
        if _tiles.has(u.grid_pos):
            _tiles[u.grid_pos].color = Color(0.90, 0.20, 0.20, 0.55)
    for g in ability_targets:
        if _tiles.has(g):
            _tiles[g].color = Color(0.95, 0.85, 0.20, 0.55)

func clear_highlights() -> void:
    for g in _tiles:
        _tiles[g].color = Color(0, 0, 0, 0)
```

Also remove the `_base_color` function (it's no longer needed — tiles are now sprites).

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/match_view.gd
git commit -m "feat: match_view sprite tile rendering with elevation and decoration support"
```

---

## Task 7: match_view.gd integration + DeployState dynamic dimensions

**Files:**
- Modify: `scripts/battle/match_view.gd` (the `_ready` function and related)
- Modify: `scripts/battle/states/deploy_state.gd`

- [ ] **Step 1: Add _map_data variable and update _ready**

In `match_view.gd`, add a variable near the top of the private variables block:
```gdscript
var _map_data: MapData = null
```

Replace the `_ready` body with:
```gdscript
func _ready() -> void:
    if Engine.has_meta("match_config"):
        config = Engine.get_meta("match_config") as MatchConfig
        Engine.remove_meta("match_config")
    else:
        config = MatchConfig.new()
        config.player_squad = SquadPicker.random_squad(10)
        config.enemy_squad  = SquadPicker.random_squad(10)
        config.difficulty   = 2

    _map_data  = MapGenerator.generate()
    var board  := Board.new()
    board.load_map(_map_data)
    match_state = MatchState.new(board)

    _build_background()
    _build_board(_map_data)
    _build_ui()
    _setup_camera()
    change_state(DeployState.new())
```

- [ ] **Step 2: Replace BOARD_W / BOARD_H usages with dynamic reads**

Find all remaining uses of the `BOARD_W` and `BOARD_H` constants in `match_view.gd`:
```bash
grep -n "BOARD_W\|BOARD_H" scripts/battle/match_view.gd
```

Replace each:
- `BOARD_W` → `match_state.board.width`
- `BOARD_H` → `match_state.board.height`

If they appear before `match_state` is initialised (e.g. in `_setup_camera`), that's fine — camera setup runs after `_ready` creates `match_state`.

You may delete the `const BOARD_W := 7` and `const BOARD_H := 7` lines since they're no longer used.

- [ ] **Step 3: Update DeployState to use dynamic board dimensions**

In `scripts/battle/states/deploy_state.gd`, remove the constant `PLAYER_ROWS` and replace all references with dynamic reads from the board. Replace the entire file:
```gdscript
class_name DeployState
extends BaseBattleState

var _unplaced: Array[MonsterData] = []

func enter(ctx: Node) -> void:
    ctx.set_deploy_mode(true)
    _unplaced = ctx.config.player_squad.duplicate()
    _place_ai_squad(ctx)
    _highlight_valid_tiles(ctx)
    ctx.set_labels("Deploy", "", "Drag a unit card to the board")
    ctx.show_unit_cards(_unplaced)

func exit(ctx: Node) -> void:
    ctx.set_deploy_mode(false)
    ctx.hide_unit_cards()
    ctx.clear_highlights()

func handle_input(_ctx: Node, _event: InputEvent) -> void:
    pass

func on_card_dropped(ctx: Node, data: MonsterData, tile: Vector2i) -> void:
    if not (data in _unplaced):
        return
    if not _is_valid_tile(ctx, tile):
        return
    _unplaced.erase(data)
    ctx.spawn_unit(data, 0, tile)
    ctx.remove_unit_card(data)
    AudioManager.play_sfx(&"place_unit")
    _highlight_valid_tiles(ctx)
    if _unplaced.is_empty():
        ctx.clear_highlights()
        ctx.match_state.initialize_initiative()
        ctx.advance_turn()

func auto_place(ctx: Node) -> void:
    var rows := _player_rows(ctx)
    var valid: Array[Vector2i] = []
    for y in rows:
        for x in range(ctx.match_state.board.width):
            var g := Vector2i(x, y)
            if not ctx.match_state.board.is_occupied(g) and ctx.match_state.board.is_passable(g, &"ground"):
                valid.append(g)
    valid.shuffle()
    var placed := 0
    while not _unplaced.is_empty() and placed < valid.size():
        var data := _unplaced.pop_front() as MonsterData
        ctx.spawn_unit(data, 0, valid[placed])
        placed += 1
    ctx.hide_unit_cards()
    ctx.clear_highlights()
    ctx.match_state.initialize_initiative()
    ctx.advance_turn()

func _player_rows(ctx: Node) -> Array[int]:
    var h: int = ctx.match_state.board.height
    return [h - 2, h - 1]

func _ai_positions(ctx: Node) -> Array[Vector2i]:
    var w: int = ctx.match_state.board.width
    var mid: int = w / 2
    return [
        Vector2i(mid - 1, 0), Vector2i(mid, 0), Vector2i(mid + 1, 0),
        Vector2i(mid - 1, 1), Vector2i(mid, 1), Vector2i(mid + 1, 1),
    ]

func _place_ai_squad(ctx: Node) -> void:
    var ai_squad: Array[MonsterData] = ctx.config.enemy_squad
    var positions := _ai_positions(ctx)
    for i in range(mini(ai_squad.size(), positions.size())):
        ctx.spawn_unit(ai_squad[i], 1, positions[i])

func _is_valid_tile(ctx: Node, g: Vector2i) -> bool:
    if not ctx.match_state.board.is_in_bounds(g):
        return false
    if ctx.match_state.board.is_occupied(g):
        return false
    if not ctx.match_state.board.is_passable(g, &"ground"):
        return false
    if g.y not in _player_rows(ctx):
        return false
    return true

func _highlight_valid_tiles(ctx: Node) -> void:
    var valid: Array[Vector2i] = []
    for y in _player_rows(ctx):
        for x in range(ctx.match_state.board.width):
            var g := Vector2i(x, y)
            if not ctx.match_state.board.is_occupied(g) and ctx.match_state.board.is_passable(g, &"ground"):
                valid.append(g)
    ctx.highlight_tiles(valid, ([] as Array[BattleUnit]), ([] as Array[Vector2i]))
```

- [ ] **Step 4: Run the game and verify**

Use the Godot AI MCP `project_run` tool to launch the game. Check that:
1. A new map generates with sprite tiles visible (not colored polygons)
2. Elevated tiles appear higher on screen with visible walls
3. Water / lava tiles render in their terrain color
4. Units deploy to the correct rows
5. AI units appear in the top center rows
6. Moving a unit respects elevation (uphill costs 2, big cliffs block)
7. Hovering shows the highlight overlay above the sprite

If tile sprites show wrong graphics (wrong biome colors), update `TileRegistry` coordinates based on the HTML grid tool, then re-run.

- [ ] **Step 5: Fix TileRegistry coordinates if needed**

Open `/tmp/tile_grid.html` (or regenerate with the script from Task 1 Step 1) and compare what you see against what renders in-game. Update any incorrect `Rect2i` values in `scripts/core/tile_registry.gd`.

- [ ] **Step 6: Commit**

```bash
git add scripts/battle/match_view.gd scripts/battle/states/deploy_state.gd scripts/core/tile_registry.gd
git commit -m "feat: wire procedural map into match_view + dynamic deploy zones"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ MapTile + MapData → Task 0
- ✅ TileRegistry → Task 1
- ✅ Board passability (load_map, is_passable, elevation_at) → Task 2
- ✅ MonsterData.movement_type → Task 3
- ✅ MatchState cost-BFS → Task 4
- ✅ MapGenerator with connectivity validation → Task 5
- ✅ match_view sprite rendering + ELEV_LIFT + grid_to_screen(h) → Task 6
- ✅ _ready wiring + BOARD_W/H removal + DeployState dynamic rows → Task 7
- ✅ Test suites: map_data, board_passability, legal_moves_elevation, map_generator

**Known limitations (out of scope, future work):**
- `screen_to_grid` still assumes height 0. Click targets on elevated tiles may be slightly offset on mobile. Acceptable for now.
- Height-2 wall extender uses a generic earth-colored tile. Biome-specific height-2 tiles can be added later.
- TileRegistry decoration coordinates require in-game verification — rows 8–9 of the tile sheet could not be identified by color alone.
