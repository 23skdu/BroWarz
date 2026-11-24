# BroWarz — Roadmap & Next-Phase 20-Step Improvement Plan

## Phase 1 — Completed v0.1.0 Foundation (Parts 1–20)

All core foundation milestones are implemented, wired into gameplay, and verified by `make ci` (157 GUT tests across 40 test scripts with 0 orphans):

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
- [ ] Branching Research Lab panel driven by `Tech.can_research()`/`Tech.unlock()`.

### Step 5 — Interactive Minimap with Camera Viewport & Tactical Pings (`game.gd`)
- [x] 160×160 corner minimap with camera jump, unit move orders, and `Alt + Left Click` tactical pings (`tactical_pings`).

### Step 6 — Control Groups (`0–9`), Double-Click Type Select & Camera Zoom (`game.gd`)
- [ ] Ctrl+0..9 assign `control_groups`, Alt+0..9 recall; double-tap centers camera; double-click selects same-type; mouse-wheel zoom.

### Step 7 — Targeted Cursor Mode for Orbital Laser, Nuclear Strike & Sapper Fortifications (`game.gd`)
- [x] Targeting reticle via `pending_target_action` for `L`, `N`, and sappering `wall`/`barbed_wire`/`missile_tower`; click-to-place coordinates.

### Step 8 — Building Selection Inspector, Production Queue Cancellation & Rally Flags (`building.gd`, `game.gd`)
- [x] `cancel_last_queued`, rally points, and production queue inspection in `building.gd`.

### Step 9 — Expanded Factory-Specific Unit Production Palettes (`game.gd`, `building.gd`)
- [x] All 31 registered units listed in `game.gd` command bar / build palettes.

### Step 10 — Engineer Building Capture & Structure Demolition (`unit.gd`, `building.gd`)
- [x]Engineers (`engineerbot`/`adv_engineerbot`) capture damaged production buildings (`building.gd`).

### Step 11 — Subsurface Naval Warfare & Sonar Detection Rules (`unit.gd`, `damage.gd`, `vision.gd`)
- [ ] Submarine sonar rules: submerged hiding, narrow detection by naval/radar ships.

### Step 12 — Aircraft Carrier Mobile Drone Deck Operations (`unit.gd`, `building.gd`)
- [x]Aircraft carrier drone-deck operations (`unit_registry`, `unit_visual`, `unit.gd`).

### Step 13 — Procedural Retro-Synth WAV Audio & SFX Generator (`AudioManager`, `scripts/tools/`)
- [x]Out-of-the-box procedural WAV audio (`assets/sfx/*.wav`, `assets/music/*.wav`, `AudioManager` aliases).

### Step 14 — In-Match Save / Load Game Serialization (`SaveGame`, `GameState` → `game.gd`)
- [x] In-match save/load via `SaveGame` + in-match Pause/System Menu.

### Step 15 — Deterministic Match Replay Recorder & Playback Viewer (`Replay` → `game.gd`, `main_menu.gd`)
- [ ] Record all issued match commands into a `Replay` instance (`Replay.record`) during single-player and P2P matches, save completed match logs to `user://replays/`, and add a Replay Viewer mode with `1× / 2× / 4×` playback speed and free camera scrubbing.

### Step 16 — Post-Match Victory / Defeat Summary Screen & Score Breakdown (`Score` → `game.gd`)
- [ ] Display a dedicated end-of-match overlay when `match_over` triggers, computing and charting each corporation's `Score.military_score()`, `Score.economic_score()`, and `Score.total()` alongside units trained/lost, buildings captured/destroyed, and match duration.

### Step 17 — Multi-Team Diplomacy, Shared Allied Vision & 2v2 / FFA Skirmish (`Alliance`, `Vision` → `game.gd`, `lobby.gd`)
- [ ] Wire `Alliance.is_allied()` and `Vision.shared_vision()` into targeting, fog-of-war rendering (`_update_fog`), and win-condition checks (`_check_win`) so 2v2 allied teams share line-of-sight and victory conditions, and support 3–4 AI corporations in Free-For-All skirmish matches.

### Step 18 — Map Editor Resource Node, Starting Base & Validation Tools (`map_editor.gd`)
- [ ] Upgrade the Hex Map Editor to place player HQ spawn points (`Team 0..3`) and `ResourceDeposit` nodes (Oil, Iron, Geothermal, Food), and add a **Validate Map** button that verifies hex path connectivity and balanced starting resources before saving or exporting a `BWM1:` share code.

### Step 19 — Persistent Settings Menu & Accessibility Options (`SettingsStore`, `SettingsManager` → `main_menu.gd`)
- [ ] Add an in-game Settings dialog backed by `SettingsStore` (`user://settings.cfg`) to configure master/SFX/music volume, `AudioManager.muted`, camera pan speed, UI scale, colorblind faction palettes, and custom hotkey bindings.

### Step 20 — Spatial-Hash Combat Queries & MultiMesh Batch Rendering in Live Scene (`UnitVisual` → `game.gd`, `unit.gd`)
- [ ] Wire `UnitVisual.build_spatial_grid()` and `UnitVisual.query_spatial_radius()` directly into `game.gd` per-tick combat/repair lookups (replacing $O(N^2)$ `get_nodes_in_group("units")` scans in `unit.gd`) and batch forest decorations, projectiles, and 500+ LOD unit icons via `MultiMeshInstance2D`.
