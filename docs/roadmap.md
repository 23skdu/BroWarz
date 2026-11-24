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
- [ ] Replace auto-offset base building spawning with an interactive mouse placement ghost showing green/red tile footprints validated by `Placement.can_place(map_data, footprint, origin, occupied)` and shore-adjacency checks for `docks`, `shipyard`, and `advanced_shipyard`.

### Step 2 — On-Map Finite Resource Deposits & Depletion Visuals (`ResourceDeposit` → `game.gd`, `map_editor.gd`)
- [ ] Spawn visible **Oil Wells**, **Iron Veins**, **Geothermal Vents**, and **Arable Farmland** nodes on the map using `ResourceDeposit`, require `extractor`, `power_plant`, and `farm` structures to be placed on or adjacent to matching deposits, and deplete deposits over time (`ResourceDeposit.harvest`).

### Step 3 — Live Power Grid & Brownout Efficiency (`Power` → `game.gd`, `building.gd`)
- [ ] Wire `Power.balance()`, `Power.is_powered()`, and `Power.efficiency()` into the live economy tick so `power_plant` structures generate megawatts while factories, `radar`, `turret`, `missile_tower`, `orbital_uplink`, and `silo` consume power, slowing production queue ticks and radar sweeps during brownouts.

### Step 4 — Branching Research Lab Tech Tree UI (`Tech` → `game.gd`)
- [ ] Replace linear `T1 → T4` instant upgrades with a branching Research Lab tech panel driven by `Tech.can_research()` and `Tech.unlock()`, requiring a constructed `research_lab` and researching specific upgrades (Reactive Armor, Railgun Calibration, Cloak Field Capacitors, Super-Heavy Chassis, Strategic Uplinks).

### Step 5 — Interactive Minimap with Camera Viewport & Tactical Pings (`game.gd`)
- [ ] Add a 160×160 corner minimap rendering live terrain, fog of war, friendly/enemy unit dots, building icons, and drifting clouds, supporting left-click camera jump, right-click unit move orders, and `Alt + Left Click` allied tactical ping markers.

### Step 6 — Control Groups (`0–9`), Double-Click Type Select & Camera Zoom (`game.gd`)
- [ ] Wire `Ctrl + 0..9` to assign `control_groups`, `0..9` (or `Alt + 1..9`) to recall and double-tap to center camera, double-click on a unit to select all visible friendly units of the same `stats.id`, and mouse-wheel zoom (`0.4×` to `2.0×`) linked to `UnitVisual.lod_sprite_size()`.

### Step 7 — Targeted Cursor Mode for Orbital Laser, Nuclear Strike & Sapper Fortifications (`game.gd`)
- [ ] Add a targeting reticle state when pressing `L` (Orbital Laser), `N` (Nuclear Strike), or building `wall` / `barbed_wire` / `missile_tower` with a selected `sapperbot`, allowing players to click the exact world coordinates for strikes and fortification lines instead of auto-targeting the enemy HQ.

### Step 8 — Building Selection Inspector, Production Queue Cancellation & Rally Flags (`building.gd`, `game.gd`)
- [ ] Allow left-clicking friendly production buildings (`hq`, `docks`, `mech_factory_1..3`, `shipyard`, `advanced_shipyard`, `aeries_1..2`) to inspect their active `production_queue`, right-click to set a visual `rally_point` flag (`Building.set_rally`), and cancel queued units via `Production.cancel()` with resource refunds.

### Step 9 — Expanded Factory-Specific Unit Production Palettes (`game.gd`, `building.gd`)
- [ ] Display context-sensitive unit training buttons when a specific factory is selected so all 31 registered units (including `heavybot`, `sapperbot`, `sniperbot`, `medicbot`, `adv_engineerbot`, `apc`, `light_mech`, `light_tank`, `heavy_tank`, `artillery`, `heavy_mech`, `siege_mech`, `patrol_boat`, `corvette`, `attack_sub`, `ballistic_sub`, `landing_craft`, `cruiser`, `battleship`, `aircraft_carrier`, `frogbot`, `scout_drone`, `bomber_drone`, `awacs`) can be trained directly from the UI.

### Step 10 — Engineer Building Capture & Structure Demolition (`unit.gd`, `building.gd`)
- [ ] Allow `engineerbot` and `adv_engineerbot` units ordered onto damaged enemy production buildings (`hp < 50%`) to capture and convert building ownership (`building.team = unit.team`), freeing captured factories to produce for the capturing corporation.

### Step 11 — Subsurface Naval Warfare & Sonar Detection Rules (`unit.gd`, `damage.gd`, `vision.gd`)
- [ ] Enforce dedicated subsurface detection and targeting rules for `attack_sub` and `ballistic_sub`: submerged submarines remain hidden unless detected by naval sonar (`corvette`, `cruiser`, `attack_sub`, `docks`, `shipyard`) or airborne radar (`awacs`), and allow `ballistic_sub` to launch tactical cruise/nuclear missiles from sea tiles.

### Step 12 — Aircraft Carrier Mobile Drone Deck Operations (`unit.gd`, `building.gd`)
- [ ] Allow `aircraft_carrier` capital ships to act as mobile naval `aeries_1` flight decks that auto-repair embarked aerial drones (`scout_drone`, `fighter_drone`, `bomber_drone`) at sea and launch them directly toward designated strike targets.

### Step 13 — Procedural Retro-Synth WAV Audio & SFX Generator (`AudioManager`, `scripts/tools/`)
- [ ] Add a deterministic procedural WAV generator tool (`scripts/tools/generate_audio.gd` or runtime `AudioStreamGenerator` / PCM WAV synthesis) to populate `assets/sfx/*.wav` (`weapon_fire`, `unit_explode`, `building_explode`, `order_move`, `tech_up`, `orbital_laser`, `nuclear_launch`, `eel_hazard`) and `assets/music/*.wav` (`menu`, `battle`) so audio cues play out-of-the-box.

### Step 14 — In-Match Save / Load Game Serialization (`SaveGame`, `GameState` → `game.gd`)
- [ ] Wire `SaveGame` and `GameState` into an in-match Pause/System Menu (`Esc`) allowing single-player skirmish matches (map tiles, unit positions/HP/cargo, building queues, wallets, tech tiers, and active clouds) to be saved to `user://saves/<slot>.bws` and resumed from the Main Menu.

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
