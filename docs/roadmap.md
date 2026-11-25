# BroWarz — Roadmap & Next-Phase 20-Step Improvement Plan

## Phase 1 — Completed v0.1.0 Foundation (Parts 1–20)

All core foundation milestones are implemented, wired into gameplay, and verified by `make check` (255 GUT tests across 50 test scripts with 0 orphans):

- [x] **Multiplayer P2P & Lockstep Soak:** Host-authoritative lobby (`LobbyState`), fail-closed payload validation (`NetSecurity`), rate limiting (`RateLimiter`), anti-replay sequence guards (`SeqGuard`), disconnect grace & host migration (`NetworkManager`), and 4-peer deterministic lockstep soak testing (`Lockstep.run_soak_simulation`).
- [x] **Map Rendering, Per-Terrain Combat/Move Modifiers & Drifting Clouds:** 128×128 hex-pathfound maps (`HexGrid`), 4× sub-tile high-resolution terrain (`UnitVisual.build_terrain_map_image`), per-terrain movement and incoming/outgoing combat modifiers across all 12 terrain types (`MapData.movement_cost`, `MapData.speed_multiplier`, `Cover.defense_modifier_for_unit`, `Cover.attack_modifier_for_unit`), and drifting cloud formations that exclusively affect aerial units (`Cover.spawn_clouds`, `Cover.step_clouds`, `Cover.cloud_air_*`).
- [x] **Combined-Arms Roster & Tiered Factories:** 31 units with 48×48 strictly uniform corporate sprites (`UnitVisual`, `docs/units.md`), tiered factories (`hq`, `docks`, `mech_factory_1..3`, `shipyard`, `advanced_shipyard`, `aeries_1..2`, `adv_engineerbot` builder enforcement in `docs/factories.md`), and amphibious embark/disembark transport commands (`[E]` / `[U]`).
- [x] **Ambient Wildlife, Fortifications & Performance Scaling:** Roaming/fleeing wildlife (`Wildlife`), sapper fortifications (`Fortification`), shared texture caching & 500-unit LOD/spatial hashing (`UnitVisual.get_cached_unit_texture`, `UnitVisual.build_spatial_grid`).

---

## Phase 2 — Gap Analysis & 20 New Roadmap Steps for v0.2.0 Improvements

A full gap analysis between the design vision ([`docs/design.md`](design.md)), existing core systems (`scripts/core/*.gd`), and live match scenes (`scripts/game/*.gd`, `scripts/ui/*.gd`) identified several standalone core modules (`ResourceDeposit`, `Power`, `Tech`, `Placement`, `Replay`, `SaveGame`, `Score`, `Alliance`, `SettingsStore`, `AudioManager`) that are unit-tested in isolation but not yet surfaced in the live match HUD or gameplay loop, alongside tactical UX, audio, and multiplayer improvements.

Below are the **20 new roadmap steps** to bridge every remaining gap:

### Step 1 — Interactive Building Placement Ghost & Footprint Grid (`Placement` → `game.gd`)
- [x] Interactive mouse placement via `pending_build_id` ghost, validated footprints, shore-adjacency checks.

### Step 2 — On-Map Finite Resource Deposits & Depletion Visuals (`ResourceDeposit` → `game.gd`, `map_editor.gd`)
- [x] On-map oil/iron/geothermal/farm nodes (`ResourceDeposit`) with depletion over time; `resource_deposits` rendered in `game.gd`.

### Step 3 — Live Power Grid & Brownout Efficiency (`Power` → `game.gd`, `building.gd`)
- [x] Wired `Power.balance()`/`is_powered()`/`efficiency()` into the economy tick; `_tick_power()` applies per-team efficiency to resource rates, `ResourceManager.power_efficiency` stores it, and `power_plant`/`radar`/`turret`/`missile_tower`/`silo` deltas are defined in `Power`.

### Step 4 — Branching Research Lab Tech Tree UI (`Tech` → `game.gd`)
- [x] `Tech.can_research()`/`Tech.unlock()` wired into `game.gd` with a Research Lab gate; the dialog shows every node with prerequisites, researched state, cost and disabled reasons, and refreshes after purchases.

### Step 5 — Interactive Minimap with Camera Viewport & Tactical Pings (`game.gd`)
- [x] 164×164 corner minimap with terrain/fog, unit/building/deposit blips, camera viewport box, camera jump, move orders (hold `A` for attack-move), and `Alt + Left Click` tactical pings (`tactical_pings`).

### Step 6 — Control Groups (`0–9`), Double-Click Type Select & Camera Zoom (`game.gd`)
- [x] Control groups assigned via Ctrl+0..9 and recalled via Ctrl+Shift+0..9 with camera centering; double-tap centers camera; double-click selects same-type; mouse-wheel zoom implemented.

### Step 7 — Targeted Cursor Mode for Orbital Laser, Nuclear Strike & Sapper Fortifications (`game.gd`)
- [x] Targeting reticle via `pending_target_action` for `L`, `N`, and sappering `wall`/`barbed_wire`/`missile_tower`; click-to-place coordinates.

### Step 8 — Building Selection Inspector, Production Queue Cancellation & Rally Flags (`building.gd`, `game.gd`)
- [x] `cancel_last_queued`, rally points, and production queue inspection in `building.gd`.

### Step 9 — Expanded Factory-Specific Unit Production Palettes (`game.gd`, `building.gd`)
- [x] All 31 registered units listed in `game.gd` command bar / build palettes.

### Step 10 — Engineer Building Capture & Structure Demolition (`unit.gd`, `building.gd`)
- [x] Workers (`sapperbot` and engineer aliases) capture damaged production buildings automatically or via the `C` target command; `Del` demolishes a selected building with a 25% refund.

### Step 11 — Subsurface Naval Warfare & Sonar Detection Rules (`unit.gd`, `damage.gd`, `vision.gd`)
- [x] Sonar rules: submerged units hidden unless detected by naval sonar (`Vision.sub_detected` + `unit.gd` `_nearest_enemy`).

### Step 12 — Aircraft Carrier Mobile Drone Deck Operations (`unit.gd`, `building.gd`)
- [x]Aircraft carrier drone-deck operations (`unit_registry`, `unit_visual`, `unit.gd`).

### Step 13 — Procedural Retro-Synth WAV Audio & SFX Generator (`AudioManager`, `scripts/tools/`)
- [x]Out-of-the-box procedural WAV audio (`assets/sfx/*.wav`, `assets/music/*.wav`, `AudioManager` aliases).

### Step 14 — In-Match Save / Load Game Serialization (`SaveGame`, `GameState` → `game.gd`)
- [x] In-match save/load via `SaveGame` + in-match Pause/System Menu.

### Step 15 — Deterministic Match Replay Recorder & Playback Viewer (`Replay` → `game.gd`, `main_menu.gd`)
- [x] Commands recorded into a `Replay` instance in `apply_command`, validated on load, saved to `user://replays/match.json`, and played/scrubbed tick-by-tick as a command stream in the replay viewer from the menu and pause screen.

### Step 16 — Post-Match Victory / Defeat Summary Screen & Score Breakdown (`Score` → `game.gd`)
- [x] `_check_win` computes and displays `Score.military_score()`, `Score.economic_score()` (including Food), `Score.total()`, true building totals and match duration in the victory panel.

### Step 17 — Multi-Team Diplomacy, Shared Allied Vision & 2v2 / FFA Skirmish (`Alliance`, `Vision` → `game.gd`, `lobby.gd`, `diplomacy_dialog.gd`)
- [x] `GameManager.is_allied()` wired into fog visibility, unit targeting, and win-condition sides; alliances staged via `GameManager.alliances` in `stage_net_match`.
- [x] In-match Diplomacy panel proposes, accepts/declines, cancels and breaks alliances for 3+ teams. Requests pass through the host-authoritative command pipeline (`NetSecurity` allowlist, lobby-derived team ownership, anti-replay, relay) and are saved with the match.

### Step 18 — Map Editor Resource Node, Starting Base & Validation Tools (`map_editor.gd`)
- [x] Tile Map Editor places Team 0..3 HQ spawns and Oil/Iron/Geothermal/Food deposits with a matching tile cursor, saved-map picker, detailed save/load/share-code errors, playability-gated test play, and **Validate Map** checks for connectivity and balance.

### Step 19 — Persistent Settings Menu & Accessibility Options (`SettingsStore`, `SettingsManager` → `main_menu.gd`)
- [x] In-game Settings dialog (`scripts/ui/settings_dialog.gd`) persists master/music/SFX volume, mute, camera speed, UI scale, colorblind faction palettes and camera hotkeys to `user://settings.cfg`; values apply live to audio, viewport scaling, faction colors and camera controls.

### Step 20 — Spatial-Hash Combat Queries & MultiMesh Batch Rendering in Live Scene (`UnitVisual` → `game.gd`, `unit.gd`)
- [x] Spatial grid built per tick in `game.gd`; radius queries feed combat/turrets, and `UnitVisual.lod_sprite_size()` drives live sprite LOD; forests use MultiMesh batching.
