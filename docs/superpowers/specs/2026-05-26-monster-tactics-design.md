# Monster Tactics — Design Spec

**Working title:** Monster Tactics (final name TBD)
**Date:** 2026-05-26
**Engine:** Godot 4.6.2-stable
**Platforms:** Android (Google Play) + iOS (App Store)
**Goal:** A small, addictive, replayable mobile tactics game built from the existing
`assets/Sprites` pack, monetized for passive income (rewarded-ad-heavy hybrid).

---

## 1. Concept

A **turn-based tactical RPG** ("monster chess") where players build a squad of
monsters and fight on a compact isometric grid. Two modes:

- **Ranked (async):** face stored squad *snapshots* played by AI, scaled to your
  trophy level. Feels like PvP, requires no live server.
- **Chill Skirmish (offline):** pick any unlocked squad, fight AI at a chosen
  difficulty, low stakes.

Inspiration: the deckbuilding/collection chase of Clash Royale, expressed through
deliberate turn-based tactics rather than real-time action.

### Why this fits
- The asset pack is purpose-built for grid tactics: isometric terrain tiles, diamond
  tile-highlight indicators (legal move/attack markers), hearts (HP), gems (currency).
- Replayability comes from **squad combinations and counters**, not from new art —
  so a modest roster sustains a deep meta.
- Turn-based + async/bot opponents = **no real-time netcode, no servers** → stays
  cheap and low-maintenance, which serves the passive-income goal.

---

## 2. Core Match Design

### Combat model — Tactics-RPG
Each monster has stats: `{ cost, hp, atk, move_range, atk_range, ability }`.
- **Move** up to `move_range` tiles, then **attack** once if a valid target is within
  `atk_range` (melee = adjacent; ranged = at distance).
- **Deterministic damage:** `damage = atk - defense` (no random rolls). Fairer for
  async play, rewards planning, and makes the AI feel smart. All RNG lives in the
  draft/collection, never in combat resolution.
- **One signature ability per monster** — a passive (e.g., Spider: attacks poison for
  1 dmg/turn) or a short-cooldown active (e.g., Wraith: blink to an empty tile; Imp:
  small AoE). Kept simple and readable.

### Board & deployment
- **Isometric grid ~7×7**, centered for portrait orientation.
- All tiles walkable in MVP (terrain effects deferred to avoid balance complexity).
- **Squad budget:** each monster has a **deploy cost 1–5** by power; build a squad
  under a **~10 budget** (≈ 3 strong / 5 weak / a mix). This is the deckbuilding
  decision and the primary fairness lever.
- At match start, the player **places** units on their back two rows (chess-style)
  using the tile-highlight indicators.

### Turn structure — I-go-you-go
- The active player moves/acts with **all** their units, then the opponent does the
  same. Repeat until one squad is wiped.

### Win condition
- **Wipe the entire enemy squad.**

### Match length
- ~**5–8 minutes**, roughly 6–10 turns. A clean scene-break at match end is the only
  interstitial-ad slot.

---

## 3. Roster

The sheet `Outlined_Entities.png` (4×35 = 140 cells) is **animation frames**, not 140
units. The 4 columns are frames; most creatures span multiple rows (idle/walk/attack);
a few are recolors. Verified distinct creatures:

| # | Creature | Archetype |
|---|---|---|
| 1 | Knight/soldier (blue) + brown recolor | Bruiser (+ recolor variant) |
| 2 | Blue mage/caster *(tentative — verify vs knight variant)* | Caster |
| 3 | Goblin/Orc (green), sword & bow poses | Bruiser / Ranged |
| 4 | Spider (black) | Assassin (poison) |
| 5 | Wraith/Reaper (purple, scythe) | Caster |
| 6 | Demon/Imp (red, horned) | Caster/Bruiser |
| 7 | Archer (purple hood, bow) | Ranged |
| 8 | Crab/Beetle (red) | Tank |
| 9 | Slime (orange) | Support |
| 10 | Bat (purple) | Assassin (fast) |
| 11 | Ghost/Spirit (blue, banner) | Support |

Plus two non-creature props (last row): a **gravestone** and a **"?" mystery block** —
used as *mechanics* (summon/revive tile, mystery-unit reward), not units.

**Archetypes** give rock-paper-scissors depth: Bruiser, Tank, Ranged, Assassin,
Caster, Support — each filled by 1–2 creatures.

### Expansion plan (honest)
- **v1 launches with the ~11 base monsters.** This is a strong tactics roster (chess
  thrives on 6 piece types); the match design does not depend on more.
- **First expansion wave = palette-swap "elite" tiers** (the pack already does this:
  blue/brown knight). Cheap, standard for the genre; → ~20–25 roster entries.
- **Genuinely new monsters require new art** (commissioned / AI-generated in matching
  style / follow-up pack). This is the real long-term content lever — there is *no*
  hidden stockpile of unique sprites.

---

## 4. Meta-Loop & Progression

- **Collection + Squad Builder (Clash-style):** persistent collection; unlock monsters
  via play, chests, or spending gems. Build squads under the cost budget.
- **Currency:** one soft currency — **gems** — earned from wins/dailies.
- **Chests:** win → earn a chest → opens to gems + a chance at new/duplicate monsters.
  **Duplicates level a monster up slightly** (small power, mostly progression feel).
- **Fairness:** power stays bounded by the **cost budget + trophy-based matchmaking**,
  so collecting is about variety/options, not stat-stomping.
- **Ranked ladder (async):** win vs snapshot squads near your trophy level → trophies +
  chest → climb tiers → tougher opponents, better rewards. The core retention loop.
- **Retention glue:** **daily login reward** + **daily free chest**.

---

## 5. Monetization

Rewarded-heavy hybrid (maximize revenue, minimize annoyance and ad-lifecycle bugs).

- **Rewarded video (primary, opt-in):**
  - Double chest rewards on open
  - Extra free chest on the daily timer
  - Gem booster (+gems)
  - Scout opponent (preview enemy squad before a ranked match)
- **Interstitial (sparing):** only on **match-end → return to menu**, frequency-capped
  (~once / 3 min), **never mid-match**. Suppressed after a Remove-Ads purchase.
- **IAP:** **"Remove Ads" — $1.99** (removes interstitials; rewarded stays). Optional
  single **gem pack** later. Nothing else in v1.

---

## 6. Technical Architecture (Godot 4.6)

- **Data-driven units:** each monster is a `Resource` (`.tres`) loaded by a
  `MonsterDB` autoload. New unit/recolor = new resource, no code.
- **Board:** isometric `TileMapLayer` for terrain + a logical grid model; iso↔grid
  coordinate conversion. `Unit` nodes render via `AnimatedSprite2D` (idle/walk/attack).
- **MatchManager:** state machine — *deploy → player turn → enemy turn → resolve →
  win/lose*.
- **AI (`TacticsAI`):** heuristic action scorer — prioritize kills, focus low-HP
  targets, value positioning and abilities. Difficulty = heuristic depth / noise.
  Same AI drives both Ranked and Skirmish.
- **"Async PvP" — serverless in MVP:** ranked opponents come from a **local pool of
  squad snapshots that scale with trophies**. No backend, no maintenance. *Post-launch,
  if it grows:* an optional free-tier backend (Firebase/PlayFab) stores real player
  squad snapshots + leaderboard. Not in v1.
- **Save:** local `user://` JSON — collection, gems, trophies, saved squads, daily
  timers.
- **Meta UI:** menu, collection, squad builder, chest opening, shop, daily reward —
  built from `UI.png` panels/buttons.
- **Ads:** community AdMob plugin (Android + iOS). Strict lifecycle handling: pause on
  ad show, resume on close, graceful no-fill/failure handling.
- **Export:** Android (AAB) and iOS (Xcode build on macOS; requires Apple Developer
  account, $99/yr).

---

## 7. Build Phases

Each phase ends with something playable/verifiable.

1. **Combat prototype** — grid, move/attack, IGOUGO turns, win condition, one hardcoded
   match. *Gate: is it fun?*
2. **Roster + abilities** — all ~11 units as resources, animations, abilities wired.
3. **AI + Skirmish mode** — heuristic AI, offline play vs AI at difficulties.
4. **Meta-loop** — collection, squad builder, gems, chests, trophies/ranked vs
   snapshots, save/load, daily reward.
5. **Monetization** — AdMob RV + INT + Remove-Ads IAP, careful lifecycle.
6. **Polish + ship** — menus, juice, SFX, store assets, build & submit both stores.

---

## 8. Open Questions / Risks

- **AI quality is the make-or-break.** Both modes lean on it; budget real iteration time
  in Phases 1 and 3.
- **Economy/balance tuning** (costs, chest odds, trophy curve) needs playtesting.
- **iOS submission overhead** (review, Apple account, provisioning) is the heaviest
  store friction.
- **Final game name** is TBD.
- **Creature #2 (blue caster)** identity unconfirmed — verify against the sprite sheet
  during Phase 2 in case it's a knight variant rather than a distinct unit.
