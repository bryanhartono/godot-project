# Game Design Plan — Tech Dungeon Pixel Shooter

## Context

The project has a rich set of purchased assets from the "Tech Dungeon Roguelite" pack (itch.io) plus supplementary Kenney fonts and SFX. The goal is to design a 2D pixel-art game for both desktop (PC/browser) and mobile that has genuine market appeal and a sustainable revenue model. No GDScript or scenes exist yet — this is greenfield development on top of a curated asset library.

---

## Asset Inventory Summary

### Visuals
| Sheet | What's in it | Animations |
|---|---|---|
| Players (4 colors: Blue, Red, Green, Grey) | Controllable characters, 32×32 | Idle, Talk, Reload, Run, Shoot, Death |
| Enemies (5 types) | AI opponents, 32×32 | Idle×2, Activate, Run, Shoot, Death, Spawn Idle, Spawn Death |
| Boss (1 type) | Large boss, 64×64 | Idle, Talk, Run, Shoot×3, Death |
| NPC | Shop/quest giver, 32×32 | Idle×2, Talk |
| Projectiles | 8 bullet/shot types, 32×32 | Animated flight + collision |
| Props & Items | Loot, crates, barrels, pickups (24×22 sheet) | Static/animated |
| UI | HUD bars, panels, icons, buttons (20×11 sheet) | Static |
| Tileset | Tech dungeon floor/wall/detail tiles | N/A |

### Audio
- **Ambience/Creature**: alien, phantom, shadow, stalker, presence — perfect for dungeon atmosphere
- **Impact SFX**: footsteps (4 surfaces), glass/metal/wood impacts, punches — combat feedback
- **UI SFX**: clicks, confirms, errors, scrolls, toggles — complete UI feedback loop
- **Jingles (85 OGG)**: 8-bit NES jingles (17) → menu/win/lose music; Hit jingles → level-up fanfares
- **Fonts**: Kenney Pixel, Kenney Future, Kenney Mini — full retro + sci-fi font coverage

---

## Market Analysis (2025–2026)

### What's performing well right now
1. **Auto-survivor / bullet-heaven** (Vampire Survivors clones) — massive on mobile, strong on PC
2. **Roguelite top-down shooters** (Archero, Soul Knight) — #1 genre on mobile mid-core
3. **Idle roguelites** — good retention but need more art variety than we have
4. **Tower defense** — steady but crowded, doesn't fit these assets naturally

### Why roguelite shooter fits these assets perfectly
- Every animation in the pack maps directly to shooter mechanics (Run, Shoot, Reload, Death)
- 5 enemy types + 1 boss = natural run progression (floors 1–5 + boss fight)
- NPC sprite → in-run shop (roguelite staple mechanic)
- 8 projectile types → weapon variety per run
- Props & Items sheet → loot drops, chests, hazards
- Tileset → procedurally assembled dungeon rooms
- The pack is literally named "Tech Dungeon **Roguelite**"

---

## Recommended Game Concept

### "GRID RUN" — Auto-Shooter Dungeon Roguelite

**Elevator pitch**: A fast, 5–10 minute roguelite run where the player's character auto-fires at the nearest enemy. The player's only job is to *move* and *choose upgrades*. Inspired by Vampire Survivors + Archero, optimized for one-thumb mobile play and equally satisfying on PC with WASD.

**Core Loop (one run)**
1. **Floor start** — Spawn in a tech dungeon room; NPC shop offers 3 upgrade cards to choose from
2. **Wave combat** — Enemies spawn in waves; player moves to dodge, character auto-shoots
3. **Room clear** — Props drop loot (health, currency, upgrade shards)
4. **Boss floor** — Every 5 floors a boss fight; boss has 3 attack patterns (uses all 3 Shoot animations)
5. **Run end** — Death or win unlocks meta-currency for permanent upgrades between runs

**Player progression**
- 4 selectable characters (Blue/Red/Green/Grey player sprites) each with a passive stat difference
- Per-run weapon upgrades using the 8 projectile types (spread shot, laser, bouncing, etc.)
- Meta progression: unlock characters, permanent stat boosts (the NPC can serve as the hub)

**Why this wins on mobile**
- One-thumb / one-stick control — no virtual fire button needed (auto-fire)
- Sessions are 5–10 min — perfect for commute play
- Runs are distinct every time — roguelite = high replay value
- Instant appeal of watching bullets fill the screen (inherently satisfying)

**Platform strategy**
- **Mobile (Android/iOS)**: primary audience, portrait or landscape, touch joystick
- **PC (itch.io + Steam later)**: keyboard WASD, same build via Godot export
- Godot 4 handles both with a single codebase

---

## Revenue Model

### Recommendation: Free-to-Play with soft monetization (no pay-to-win)

**Why not premium?**
- Roguelites under $5 rarely chart on mobile. Free games get 10–50× more downloads.
- PC players accept premium ($3–6) but mobile discovery depends on free installs.
- Our assets support a cosmetic/skin system naturally (4 player colors already exist).

**Monetization pillars**
| Pillar | Mechanic | Notes |
|---|---|---|
| **Rewarded ads** | Watch ad to revive once per run, or double end-run coins | Opt-in, non-intrusive |
| **Remove Ads IAP** ($2–4 one-time) | Removes banner/interstitial; keeps rewarded opt-in | Industry standard |
| **Character unlock IAP** | 3 characters free, 4th (Grey) unlockable via coins or $1.99 | No power difference |
| **Cosmetic skin bundles** | Color-shifted palette versions of existing sprites | Low dev cost, high perceived value |
| **Season/challenge pass** (optional Phase 2) | Weekly challenge runs with exclusive jingles/UI themes | Retention tool |

**No pay-to-win**: all upgrades earnable through play. Paying only unlocks cosmetics or saves time.

**Revenue target**: Rewarded ads + Remove Ads IAP covers operating costs. Character packs scale revenue with playerbase.

---

## Procedural Generation Systems

This is what separates a replayable roguelite from a forgettable one. Every run should feel distinct.

### 1. Procedural Dungeon Layout (Room + Corridor Graph)

**Approach: BSP (Binary Space Partitioning) room generation**
- Split a grid (e.g. 60×40 tiles) recursively into sub-regions
- Carve a room rect inside each region (random size within bounds)
- Connect adjacent rooms with L-shaped corridors
- Result: no two runs share the same floor map
- Each room is tagged: `combat`, `treasure`, `shop`, `trap`, `boss_entry`
- Tag distribution is seeded by floor number so boss rooms only appear on floor 5

**Tile placement rules** (using the dungeon tileset):
- Walls auto-tile based on neighbor bitmask (Godot's built-in `TileMap` terrain system)
- Floor tiles randomly sample from the tileset's floor variants to break repetition
- Decor props (barrels, crates, terminals) placed pseudo-randomly using Poisson disk sampling so they never overlap

### 2. Procedural Enemy Spawning (Wave Composer)

**Budget system** — each room has a "threat budget" that scales with floor number:
```
floor_budget = base_budget + (floor_number * difficulty_scalar)
```
- Each enemy type costs a different amount of budget (weaker = cheap, stronger = expensive)
- A `WaveComposer` randomly fills the budget by sampling enemy types, favoring newly unlocked types on deeper floors
- Spawn positions use pre-placed spawn-point nodes at room edges, staggered with small delays so the player isn't immediately surrounded

**Enemy type unlocking by floor**:
| Floor | New enemy type unlocked |
|---|---|
| 1 | Basic grunt (cheapest) |
| 2 | Ranged shooter |
| 3 | Fast charger |
| 4 | Tank (high HP) |
| 5+ | Elite variants + Boss |

**Elite modifier system**: On floors 3+, any enemy can randomly roll an elite modifier:
- **Shielded** — takes half damage from front
- **Speedy** — 1.5× movement speed
- **Exploder** — spawns 2 small enemies on death
- **Armored** — damage cap per hit (forces burst fire)

Elites are visually distinguished by a color tint shift applied at runtime to the sprite.

### 3. Procedural Trap Rooms

The Props & Items sheet contains hazards that can be animated/triggered:
- **Laser grids** — toggle on/off on a timer; player must time movement through gaps
- **Turret props** — stationary shooters placed at room corners, removed by player fire
- **Spike floors** — tile-based damage zones, placed in random clusters using cellular automata fill
- **EMP pulse zones** — periodically disable projectile weapons, forcing melee proximity play (adds tension)

Trap rooms are generated by: picking a room tagged `trap`, running a cellular automata pass on its floor tiles to determine hazard placement, then instantiating the appropriate prop scenes.

### 4. Procedural Upgrade Card Pool (Draft System)

Each floor-end card draft draws 3 cards from a weighted pool. The pool is *contextual*:
- Cards already taken this run are de-weighted (prevents redundant stacking early)
- Synergistic cards are up-weighted if the player already has a related card (emergent builds)
- "Cursed" upgrade cards appear on floors 3+ — powerful bonus + a drawback (e.g. +50% fire rate, -20% max HP)

**Example upgrade card types** using existing projectile sprites:
| Card | Effect |
|---|---|
| Scatter Shot | Fires 3 projectiles in a spread cone |
| Ricochet | Bullets bounce off walls once |
| Chain Lightning | Every 5th shot chains to a nearby enemy |
| Overdrive | +100% fire rate for 5s after room clear |
| Vampiric Round | 10% of damage dealt restores HP |
| Phantom Ammo | Projectiles pass through one enemy |

### 5. Procedural Loot Drops (Item Rarity System)

Props and items dropped from crates/enemies use a rarity tier system:
```
Common (grey) → Uncommon (green) → Rare (blue) → Epic (purple)
```
Rarity is determined at drop time using a weighted random roll modified by a hidden `luck` stat that upgrades can improve. Higher rarity = stronger base effect + an additional bonus modifier randomly selected from a pool.

### 6. Procedural Boss Pattern Sequencing

The Boss sprite has 3 distinct Shoot animations (Shoot1, Shoot2, Shoot3). These map to attack phases that are sequenced *semi-randomly*:
- Boss has a pattern deck (e.g. [Phase1, Phase1, Phase2, Phase3, Phase2])
- Each run the deck is shuffled with constraints (Phase1 always first, Phase3 never twice in a row)
- Boss HP thresholds trigger rage mode: deck is reshuffled more aggressively
- This means no two boss fights feel identical even though art is the same

### 7. Run Seed & Daily Challenge

Every run is assigned a numeric seed. Sharing or re-entering a seed reproduces the exact dungeon layout, enemy placements, and card pool — enabling daily challenge seeds (a specific seed broadcast to all players, leaderboard by fastest completion time). This is a free feature that dramatically increases replayability and community engagement.

---

## Multiplayer Design

### Mode: Online Co-op (2–4 players)

**Why co-op, not PvP?**
- Co-op has 3–5× higher session length on mobile vs solo
- "Play with friends" is the #1 organic install channel — every invite is a free acquisition
- The 4 player-color variants (Blue, Red, Green, Grey) already give each player a distinct identity with zero extra art
- PvP in a roguelite is much harder to balance and design for; co-op just scales the existing content

**How it integrates with existing design**
- Each player controls one of the 4 colored characters simultaneously
- Shared procedurally generated dungeon — all players in the same room on the same seed
- Enemy wave budget scales with player count: `floor_budget × player_count × 0.75` (so it's harder but not overwhelming)
- Boss HP scales the same way
- Each player drafts their own 3 upgrade cards independently between floors — no card conflicts
- Individual HP pools with a revive mechanic: downed player becomes a ghost with limited movement, any teammate can walk over them to revive

### Technical Architecture (Godot 4 High-Level Multiplayer)

**Host/join flow**
1. Host taps "Create Room" → `NetworkManager` generates a 6-character room code, opens an `ENetMultiplayerPeer` server
2. Friends enter the room code → client connects to relay → lobby screen shows connected players
3. Host taps "Start" → run seed is broadcast to all peers → `DungeonGenerator` runs identically on all machines using the shared seed (deterministic, no sync needed for map layout)

**Godot 4 networking nodes used**
- `MultiplayerSynchronizer` on each `Player` node — syncs position, animation state, HP
- `MultiplayerSpawner` on the `Room` node — host spawns enemies authoritatively, clients receive replicated nodes
- RPCs (`@rpc`) for: shooting (client calls → host validates → broadcasts), loot pickup, death/revive events, upgrade card selections

**NAT traversal (mobile-safe)**
- Pure peer-to-peer fails behind mobile carrier NAT
- Solution: deploy a lightweight relay server (a simple Godot headless server or a UDP relay) on a cheap VPS (Fly.io/Railway free tier)
- Clients connect to the relay via `WebSocketMultiplayerPeer` (works through all mobile NAT and firewalls, and works in browser export too)
- Relay simply forwards packets between peers — no game logic, very low CPU/bandwidth

**Latency handling**
- Projectiles use client-side prediction: the shooting player sees their own bullets immediately, others see them with ~1 frame delay (imperceptible at 60fps)
- Enemy movement is host-authoritative with interpolation on clients
- Input delay tolerance is fine for a top-down shooter — this genre is forgiving on 50–150ms latency

### Multiplayer-specific design additions
- **Ghost spectator view** — downed player floats around as a ghost, can still see the run; teammate revive creates a tense "rescue" moment
- **Shared combo meter** — team collectively builds a combo multiplier on kill streaks, creates group coordination incentive
- **Role differentiation** — each character color has a minor passive that makes co-op composition feel meaningful (e.g. Blue has fastest fire rate, Red has biggest AoE, Green heals on kill, Grey has highest HP)
- **No friendly fire** by default (toggle for experienced players)
- **Solo mode** is unchanged — the multiplayer layer is opt-in, single-player always works offline

### Revenue impact of multiplayer
- Multiplayer invites = free user acquisition loop (biggest mobile growth lever)
- Add "Party Bundle" cosmetic IAP: matching color-tinted outfit sets for friend groups ($2.99 for a 2-player set, $4.99 for 4-player)
- Daily challenge seeds become competitive co-op runs with co-op leaderboard (friend group vs friend group)
- Relay server cost is negligible at launch scale: a $5/month VPS handles thousands of concurrent small rooms

---

## Implementation Plan (Godot 4)

### Phase 0 — Project scaffolding (unchanged)
- Set up scene structure: `Main`, `GameWorld`, `Player`, `Enemy`, `Boss`, `Room`, `UI`, `HUD`
- Import sprites as `SpriteFrames` resources, slice animation frames per the pack's cell grid docs
- Configure input map for keyboard (WASD/arrows) and touch joystick (mobile)

### Phase 1 — Core combat loop (unchanged)
- `Player.gd`: movement, auto-fire targeting nearest enemy, health
- `Enemy.gd`: state machine (Spawn → Idle → Move → Shoot → Die)
- `Projectile.gd`: pool-based bullet system, use all 8 projectile sprites
- `Room.gd`: tilemap-based room with spawn points

### Phase 2 — Roguelite structure + procedural systems
- `RunManager.gd`: floor progression, seeded RNG, boss trigger
- `DungeonGenerator.gd`: BSP room splitting, corridor carving, room tagging, TileMap autotile fill
- `WaveComposer.gd`: budget-based enemy selection, elite modifier roll, staggered spawning
- `TrapRoom.gd`: cellular automata hazard placement, laser/spike/turret instantiation
- `UpgradeCard.gd`: contextual weighted card pool, synergy detection, cursed card logic
- `LootDrop.gd`: rarity tier roll, modifier selection, props sprite sheet → drop scene
- `BossAI.gd`: pattern deck builder, shuffle with constraints, rage mode re-sequence
- `ShopNPC.gd`: NPC dialogue + coin-based shop using NPC sprite + Talk animation

### Phase 3 — Multiplayer
- `NetworkManager.gd` (autoload singleton): room creation, room code generation, peer connect/disconnect events
- Deploy headless Godot relay server to Fly.io; `WebSocketMultiplayerPeer` on clients
- Add `MultiplayerSynchronizer` to `Player` scene; add `MultiplayerSpawner` to `Room` scene
- Lobby scene: show connected players (with colored character previews), ready-up, host starts run
- RPC calls for shooting, loot pickup, death, revive, upgrade card selection
- Scale enemy budget and boss HP based on `multiplayer.get_peers().size()`
- Test: 2-player local loopback first, then cross-device on LAN, then via relay

### Phase 4 — Meta progression & UI
- `MetaManager.gd`: persistent save (coins, unlocks) via `ConfigFile`
- HUD: health bar per player, wave counter, coin display using UI sprite sheet
- Main menu, character select, room code lobby, run summary screen using Kenney fonts + jingles

### Phase 5 — Monetization & platform
- Integrate AdMob (Android/iOS) via GodotAds plugin
- IAP via Godot's in-app purchase plugin (character unlocks, Party Bundle cosmetics, Remove Ads)
- Export configurations: Android, iOS, Windows, Web (HTML5)

---

## Verification / Milestones

1. **Playable prototype**: Player moves, auto-fires, one enemy type dies — run it in Godot editor
2. **One full floor**: spawn → combat → room clear → loot drop → next floor entry
3. **Boss fight**: all 3 shoot patterns, rage mode, death animation triggers run-end screen
4. **Full run loop**: 5 floors + boss, upgrade card drafts, meta coin persist
5. **2-player local co-op**: loopback test on same machine, both players visible, enemies scale
6. **Online co-op**: 2 devices over relay server, room code works, both players synced
7. **Mobile build**: Android device test — touch joystick, 60 FPS, co-op via mobile hotspot
8. **Soft-launch**: publish free on itch.io (PC/browser), gather feedback before mobile store submission

---

## Critical Files to Create

```
project.godot              (already exists)
scenes/
  main.tscn
  lobby.tscn               ← room code entry, player list, ready-up
  game_world.tscn
  player.tscn              ← includes MultiplayerSynchronizer
  enemy.tscn
  boss.tscn
  room.tscn                ← includes MultiplayerSpawner
  trap_room.tscn
  hud.tscn
  upgrade_card.tscn
  shop_npc.tscn
scripts/
  player.gd
  enemy.gd
  boss_ai.gd
  projectile.gd
  room.gd
  dungeon_generator.gd     ← BSP layout, corridor carve, tile autofill
  wave_composer.gd         ← budget system, elite modifier rolls (scales with player count)
  trap_room.gd             ← cellular automata hazard placement
  run_manager.gd           ← seeded RNG, floor progression
  upgrade_card.gd          ← contextual pool, synergy weights, cursed cards
  loot_drop.gd             ← rarity roll, modifier attach
  shop_npc.gd
  network_manager.gd       ← autoload: room creation, relay connect, peer events
  lobby.gd                 ← room code UI, player list, ready/start
  meta_manager.gd
  hud.gd
resources/
  player_frames.tres       (SpriteFrames for each player color)
  enemy_frames.tres
  boss_frames.tres
  npc_frames.tres
  projectile_frames.tres
  upgrade_pool.tres        (Resource list of all upgrade card definitions)
  enemy_catalog.tres       (Resource list of enemy types with budget costs)
```