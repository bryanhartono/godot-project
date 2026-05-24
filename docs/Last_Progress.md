# Grid Run (Godot 4.6)

## Project Overview
**Grid Run** is a 2D pixel-art auto-shooter dungeon roguelite. The player moves with WASD; their character auto-fires at the nearest enemy. Inspired by Vampire Survivors + Archero. Supports solo and 2–4 player online co-op.

- **Engine**: Godot 4.6, GDScript, mobile renderer, Jolt Physics
- **Repo**: `bryanhartono/godot-project`, branch `claude/setup-godot-assets-P0DvC`
- **Assets**: "Tech Dungeon Roguelite" pack — 32×32 sprites, 64×64 boss, 32×32 tileset tiles (37×23 grid)

---

## Implementation Status

| Phase | Status |
|---|---|
| Phase 0 — Scaffold (scenes, project.godot, input map) | ✅ Complete |
| Phase 1 — Core combat (player, enemy, projectile, room) | ✅ Complete |
| Phase 2 — Roguelite systems (BSP dungeon, waves, upgrades, shop, loot, boss) | ✅ Complete |
| Phase 3 — Multiplayer (NetworkManager, sync, revive, combo, lobby) | ✅ Complete |
| TileMap — DungeonPainter with wall collision | ✅ Complete |
| Phase 4 — Meta progression UI, run summary, main menu polish | ⬜ Not started |
| Phase 5 — AdMob, IAP, Android/iOS export | ⬜ Not started |

---

## File Inventory

### Scripts (`scripts/`)
| File | Purpose |
|---|---|
| `player.gd` | Movement, auto-fire, ghost/revive, 4-character passives |
| `enemy.gd` | State machine (Spawn→Idle→Move→Shoot→Dead), elite modifiers |
| `boss_ai.gd` | Pattern deck (3 phases), rage mode at 40% HP |
| `projectile.gd` | Area2D bullet, vampiric healing, pierce |
| `room.gd` | Combat room: calls DungeonPainter.paint(), wave spawning |
| `trap_room.gd` | Cellular automata hazard placement, calls DungeonPainter |
| `dungeon_painter.gd` | Builds TileSet at runtime, paints rooms from BSP rects, wall collision |
| `dungeon_generator.gd` | BSP layout: rooms Array[Rect2i], corridors Array[Rect2i] |
| `wave_composer.gd` | Budget-based enemy selection, elite modifier rolls |
| `upgrade_card.gd` | 8 cards, contextual draw pool, synergy weights, cursed cards |
| `loot_drop.gd` | 4-rarity system (Common/Uncommon/Rare/Epic) |
| `shop_npc.gd` | Coin-based shop, 3 stock items |
| `game_world.gd` | Floor orchestrator: room sequencing, card draft, player spawning |
| `run_manager.gd` | Autoload: seeded RNG, floor progression, combo meter |
| `network_manager.gd` | Autoload: ENet/WebSocket, room codes, character selection sync |
| `lobby.gd` | Host/join/solo UI, character row selection |
| `hud.gd` | HP bars (ghost-tinted), combo label, coin display |
| `meta_manager.gd` | Autoload: ConfigFile save/load (coins, unlocked chars) |

### Scenes (`scenes/`)
`main.tscn` → `lobby.tscn` → `game_world.tscn`. Game entities: `player.tscn`, `enemy.tscn`, `boss.tscn`, `room.tscn`, `trap_room.tscn`, `shop_npc.tscn`, `loot_drop.tscn`, `projectile.tscn`, `upgrade_card.tscn`, `hud.tscn`.

### Resources (`resources/`)
12 SpriteFrames .tres files: `player_blue/red/green/grey_frames.tres`, `enemy_grunt/shooter/runner/turret/flying_frames.tres`, `boss_frames.tres`, `npc_frames.tres`, `projectile_frames.tres`.

---

## Architecture Notes

### DungeonPainter
`scripts/dungeon_painter.gd` — `class_name DungeonPainter extends RefCounted`

Builds a TileSet programmatically at runtime from `res://assets/Tech Dungeon Roguelite - Asset Pack (v7)/tileset x1.png` (37×23 grid of 32×32 tiles). No .tres TileSet file needed.

Key atlas coordinates (column, row):
- `FLOOR   = Vector2i(32, 1)`  — dark navy solid floor tile
- `W_TOP   = Vector2i(5,  0)`  — north-facing wall face
- `W_BOT   = Vector2i(5,  10)` — south-facing wall face
- `W_LEFT  = Vector2i(1,  5)`  — west wall
- `W_RIGHT = Vector2i(9,  5)`  — east wall
- `W_FILL  = Vector2i(4,  1)`  — solid interior wall fill
- `C_NW    = Vector2i(2,  0)`  — corner top-left
- `C_NE    = Vector2i(8,  0)`  — corner top-right
- `C_SW    = Vector2i(2,  10)` — corner bottom-left
- `C_SE    = Vector2i(8,  10)` — corner bottom-right

Wall tiles have full-tile physics collision polygons (physics layer 0, collision layer 1). Floor tile has none.

`paint_room(tilemap, rect)` centers the BSP Rect2i at world origin via `offset = -(rect.position + rect.size/2)` in tile units.

`get_spawn_positions(rect)` returns 8 enemy spawn positions relative to origin, inset 1.5 tiles from each wall.

### Room Centering
All rooms are centered at `Vector2.ZERO` in the game world. Constants in `game_world.gd`:
- `PLAYER_START = Vector2(-48, 0)` — always inside minimum 6×5 room floor area
- `ROOM_SPAWN_POS = Vector2(0, 0)`
- Multiplayer player spread: `PLAYER_START + Vector2(i * 32.0, 0)` (fits up to 4 players in minimum room)

### Dungeon Generator
BSP on 60×40 tile grid. `MIN_ROOM = Vector2i(6, 5)`, `MAX_ROOM = Vector2i(14, 10)`.  
`tag_rooms(floor_number)` returns `Array[Dictionary]` each with `{"rect": Rect2i, "type": String}`.  
Room types: `"combat"`, `"shop"`, `"trap"`, `"treasure"`, `"boss_entry"`.

### Multiplayer Architecture
- `NetworkManager` (autoload): ENet for LAN, WebSocket stub (`RELAY_URL = ""`) for online relay
- `MultiplayerSynchronizer` on Player: syncs `position` (always), `modulate`/`hp`/`is_ghost` (on_change)
- `MultiplayerSynchronizer` on Enemy: syncs `position` (always), `hp` (on_change)
- `MultiplayerSpawner` in Room scene (`spawner.spawn_path = "."`) and GameWorld Entities node
- Character selection stored in `_pending_char_selection` at `join_game()` time, sent in `_on_connected_to_server()`

### Combo System (RunManager)
`combo_count` increments on enemy kill (server-only), resets on player hit, expires after 3 seconds.  
`get_combo_multiplier() = 1.0 + min(count, 20) * 0.05` — max 2× at 20 kills.

### Revive Mechanic
Dead player enters ghost mode: 40% move speed, no shooting, `modulate.a = 0.4`. Any living teammate within 40px walking range triggers `_revive.rpc_id()` → restores HP to `max_hp / 4`.

### Upgrade Cards (8 total)
| ID | Effect |
|---|---|
| `scatter_shot` | Fires 3 projectiles in spread cone (via `set_meta`) |
| `ricochet` | **TODO**: wall bounce physics — currently `pass` |
| `chain_lightning` | Every 5th shot chains to nearby enemy |
| `overdrive` | `fire_rate_mult *= 0.5` (shoots 2× faster) |
| `vampiric_round` | Sets meta `"vampiric"` — projectile heals 15% of damage dealt |
| `phantom_ammo` | `pierce_remaining = 1` per projectile |
| `glass_cannon` | Cursed: `damage_mult *= 1.8`, `max_hp *= 0.7` |
| `berserker` | Cursed: `fire_rate_mult *= 0.5`, `max_hp *= 0.8` |

### Character Passives (player.gd `_apply_character_passive`)
- Index 0 (Blue): `fire_rate_mult = 0.7` — fastest fire rate
- Index 1 (Red): `aoe_mult = 1.5`
- Index 2 (Green): `heal_on_kill = 5` (HP restored per kill)
- Index 3 (Grey): `max_hp += 50`

---

## Autoloads (project.godot)
```
NetworkManager = res://scripts/network_manager.gd
MetaManager    = res://scripts/meta_manager.gd
RunManager     = res://scripts/run_manager.gd
```

---

## Godot 4 Syntax Rules (CRITICAL)
- `const X: Type = value` — **NOT** `const X := value` (`:=` is only valid for `var`)
- Typed arrays everywhere: `Array[int]`, `Array[String]`, `Array[Dictionary]`, `Array[Rect2i]`
- `ConfigFile.get_value()` returns untyped — coerce with `.assign()`: `typed_arr.assign(raw_val)`
- `@rpc("authority", "call_local", "reliable")` for server→all broadcasts
- `@rpc("any_peer", "reliable")` for peer→authority calls (e.g. revive request)
- `@rpc("call_local")` for client-predicted actions (shooting)
- `Array[Vector2i]` cannot be initialized with `[Vector2i(...)] + another_typed_array` — build the list and iterate separately to avoid type mix issues

---

## What's Next: Phase 4

### Priority Tasks
1. **Run summary screen** — `_on_run_ended(won: bool)` in `game_world.gd:229` currently just prints. Create a `RunSummaryLayer` CanvasLayer showing: floors cleared, enemies killed, coins earned, win/loss banner, "Play Again" / "Main Menu" buttons. Use Kenney Pixel font.
2. **Main menu scene** — `main.tscn` likely goes directly to lobby. Add a proper title screen with Play, Credits, Quit. Wire up a menu jingle from `assets/Jingles/`.
3. **Permanent upgrades UI** — `MetaManager` has `permanent_upgrades: Dictionary` and `spend_coins()` but no UI. Add a pre-run upgrade shop screen (accessible from main menu or between runs).
4. **Character unlock screen** — `MetaManager.unlocked_characters: Array[int] = [0,1,2]`. Grey (index 3) costs coins to unlock. Show padlock in lobby `CharacterRow` for locked characters; clicking opens unlock prompt.
5. **Audio hookup** — Wire SFX from `assets/SFX/Impact*/` for combat, `assets/SFX/UI*/` for menus, jingles from `assets/Jingles/` for win/lose/floor transitions.

### Phase 5 (after Phase 4)
- Mobile virtual touch joystick (input action `move_left/right/up/down` already mapped)
- AdMob via GodotAds plugin (rewarded ad on revive, interstitial on run end)
- IAP: character unlocks, "Remove Ads" one-time purchase, cosmetic bundles
- Android / iOS / Web (HTML5) export presets
- Deploy WebSocket relay and set `RELAY_URL` in `network_manager.gd`

---

## Known Gaps / TODOs
| Location | Issue |
|---|---|
| `upgrade_card.gd` — `ricochet` branch | `pass` placeholder — needs bullet to check wall normals and reflect velocity |
| `network_manager.gd:RELAY_URL` | Empty string — online co-op only works on LAN until relay deployed |
| Room decoration | No prop/decor placement (barrels, crates) — Poisson disk sampling planned |
| Daily challenge UI | Seeded RNG infrastructure exists, no frontend |
| `game_world.gd:229` | `# TODO Phase 4: run summary screen` |
| `lobby.gd` | Character unlock lock-icon display not implemented |

---

## Asset Paths Reference
```
assets/Tech Dungeon Roguelite - Asset Pack (v7)/
  tileset x1.png          ← 32×32 tiles, 37 cols × 23 rows
  Players/Blue Player/    ← Idle, Run, Shoot, Reload, Death (32×32)
  Players/Red Player/
  Players/Green Player/
  Players/Grey Player/
  Enemies/                ← 5 types, same animation set
  Boss/                   ← 64×64, Shoot1/Shoot2/Shoot3
  NPC/                    ← Idle, Talk (32×32)
  Projectiles/            ← 8 types (32×32)
  Props & Items/          ← loot, crates, barrels (24×22 sheet)
  UI/                     ← HUD bars, panels, icons (20×11 sheet)
assets/SFX/
assets/Jingles/
assets/Fonts/             ← Kenney Pixel, Kenney Future, Kenney Mini
```
