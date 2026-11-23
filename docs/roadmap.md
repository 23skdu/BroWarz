# BroWarz — 20-Part Roadmap to a Playable Version

This roadmap breaks delivery into 20 parts. Each part has an objective, deliverables, and subtasks. A "playable version" is reached at the end of **Part 16** (multiplayer and single-player skirmish playable end-to-end); Parts 17–20 polish, add AI/editor depth, and prepare release.

Legend: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Part 1 — Project Bootstrap & Tooling

**Objective:** Establish the Godot 4.7.2 project skeleton, repo conventions, and CI so all later work is testable.

**Deliverables:** `project.godot`, folder layout, GUT addon, Makefile wired to BroWarz, pre-commit hooks.

**Subtasks:**
- [x] Create `project.godot` (Godot 4.7.2) with project name "BroWarz", main scene placeholder, viewport 1920×1080, stretch mode canvas_items.
- [x] Establish folder layout: `scenes/`, `scripts/`, `resources/`, `assets/`, `tests/` (unit/integration/fuzz/regression), `addons/`.
- [x] Install GUT v9.7.1 into `addons/gut/` via `make deps`.
- [x] Configure `.gitignore` (already present) and add `.gdignore` for build/venv.
- [x] Wire `Makefile` project name/version (`config/version`) and verify `make check-godot`, `make import`.
- [x] Add export presets for Web, Linux, Windows, macOS (Android/iOS optional).
- [x] Install pre-commit hooks (`make install-hooks`).
- [x] Add `README.md` quickstart (Part 20 refines).
- [x] CI smoke: `make ci` runs without error.

---

## Part 2 — Core Architecture & Scene Structure

**Objective:** Define autoloads, scene tree, and data-driven resource patterns.

**Deliverables:** Autoload singletons, base classes, resource definitions.

**Subtasks:**
- [x] Create autoloads: `GameManager`, `NetworkManager`, `ResourceManager`, `SettingsManager`, `AudioManager`, `SceneManager`.
- [x] Define base `Unit` (`CharacterBody2D` top-down tactical view for high readability across 128×128 tiles).
- [x] Decide coordinate system and tile size; create `MapData` grid abstraction.
- [x] Create resource classes (`Resource` subclasses) for `UnitStats`, `BuildingStats`, `MapData`.
- [x] Implement unit and building catalog registration in `UnitRegistry`.
- [x] Add status/HUD overlay (resources, rates, AI posture, version info).
- [x] Unit tests for resource parsing and stat modifiers.

---

## Part 3 — Networking Foundation (P2P Lobby & Match)

**Objective:** Players can host/join a match over LAN/internet via Godot high-level multiplayer.

**Deliverables:** Lobby UI, host/join, peer management, chat, match start sync.

**Subtasks:**
- [x] Implement `NetworkManager` with ENet host/join.
- [x] Main menu scene: host/join by IP, single-player skirmish mode, difficulty & corporation selection.
- [x] Peer connect/disconnect handling.
- [x] RPCs for chat and match coordination.
- [x] Sync random seed and map data to peers before start.
- [x] Graceful disconnect UI + return to menu.
- [x] Unit tests for command & lockstep replication.

---

## Part 4 — Map System & Terrain

**Objective:** Render and query a 128×128 terrain map with movement modifiers.

**Deliverables:** Tilemap/grid, terrain types, pathfinding integration, map loading.

**Subtasks:**
- [x] Implement `MapData` resource (size, tiles, terrain types).
- [x] Generate terrain tiles (Plains, Forest, Urban, Mountain, Road, Swamp, River, Sea, Wasteland).
- [x] Movement cost per terrain per unit class (infantry/vehicle/naval/air).
- [x] A* grid pathfinding (`Pathfinding.find_path`) respecting terrain passability and movement cost.
- [x] Cover and line-of-sight terrain modifiers (`Cover`).
- [x] Fog-of-war state modeling (`Vision`).
- [x] Validate map dimensions and serialization (`MapSerializer`).
- [x] Unit and fuzz tests for movement cost, bounds, and pathfinding.

---

## Part 5 — Resource & Economy System

**Objective:** Harvesting, income, storage, population cap.

**Deliverables:** Resource nodes, extractors, income tick, UI rates.

**Subtasks:**
- [x] Four core resources (`Economy.Res`: Oil, Iron, Geothermal, Food).
- [x] Extractor buildings boost per-second resource harvesting rates.
- [x] `ResourceManager` tracks per-player resources, income rates, and population caps.
- [x] Farms increase population cap; HQ provides base cap.
- [x] Income tick (1s) applied consistently across players.
- [x] Direct-use extractor economy model documented and implemented.
- [x] UI: HUD resource bar with current amounts, per-second income rates, and population usage/cap.
- [x] Unit and fuzz tests for income, caps, spend/affordability.

---

## Part 6 — Deterministic Simulation & Lockstep

**Objective:** All peers advance gameplay in sync from replicated inputs.

**Deliverables:** Fixed tick, command buffer, checksum desync detection.

**Subtasks:**
- [x] Lockstep tick and command buffer manager (`Lockstep`).
- [x] Serializable command system (`Command`: Move, Attack, Attack-Move, Build, Stop, Patrol, Hold).
- [x] Input delay buffering (`target_tick_for_input`) to absorb latency.
- [x] Peer readiness tracking (`peer_ready`, `all_peers_ready`).
- [x] Deterministic state snapshot and checksum (`GameState.snapshot`, `GameState.checksum`).
- [x] Replay command stream recording (`Replay`).
- [x] Unit tests for command serialization, lockstep buffer, replay, and checksum determinism.

---

## Part 7 — Unit Framework & Movement

**Objective:** Spawn, select, move units with formation/pathfinding.

**Deliverables:** Unit base class, selection, pathfinding, rally.

**Subtasks:**
- [x] `Unit` base: stats (HP, speed, armor, sight), team, combat/movement state machine.
- [x] Health bar, death cleanup, and zero-orphan compliance.
- [x] Click and right-click move/attack-move with grid formation offsets (`Formation.grid_offsets`).
- [x] Selection: click select, drag-box select, shift-additive selection.
- [x] Rally points for production buildings.
- [x] Unit tests for formation and unit stats.

---

## Part 8 — Infantry & Robot Units

**Objective:** Implement all infantry robots and mechanized infantry.

**Deliverables:** Riflebot, Heavybot, Sapperbot, Stealthbot, Sniperbot, Rocketbot, Medicbot, Engineerbot, APC/IFV, light mech.

**Subtasks:**
- [x] Register `UnitStats` in `UnitRegistry` for all infantry and mechanized units.
- [x] Implement sapper demolition bonus against structures/fortifications.
- [x] Stealth cloak + detection interaction (`Stealth` and `Vision.stealth_detected`).
- [x] Medicbot auto-repair radius (`Repair`); Engineerbot structure support.
- [x] Unit tests for sapper/damage multipliers, cloak break, and repair math.

---

## Part 9 — Vehicles & Heavy Units

**Objective:** Tanks, artillery, AA, mechs.

**Deliverables:** Light/MBT/heavy tank, SPG, AA vehicle, heavy/siege mechs.

**Subtasks:**
- [x] Vehicle movement with terrain speed modifiers and swamp/mountain restrictions.
- [x] Register Light Tank, MBT, Heavy Tank, Self-Propelled Artillery, AA Vehicle, Heavy Mech, Siege Mech.
- [x] Armor class damage matrix (`Damage.ArmorClass` vs `Damage.DamageType`).
- [x] Unit and fuzz tests for damage vs armor classes.

---

## Part 10 — Naval & Submarine Units

**Objective:** Sea drones, submarines, transports.

**Deliverables:** Patrol boats, corvettes, attack subs.

**Subtasks:**
- [x] Naval movement restricted to Sea and River tiles (`MapData.movement_cost`).
- [x] Submarine `SUBMERGED` armor class (immune to kinetic, stealth cloaked).
- [x] Register Patrol Sea Drone, Missile Corvette, Attack Submarine in `UnitRegistry`.
- [x] Unit tests for naval passability and submerged damage immunity.

---

## Part 11 — Air & Orbital Units

**Objective:** Aerial drones and orbital systems.

**Deliverables:** Scout/fighter/bomber drones, AWACS, orbital laser uplink.

**Subtasks:**
- [x] Flight movement (passes over all terrain types with cost 1.0).
- [x] Register Scout Drone, Fighter Drone, Bomber Drone, AWACS Radar Drone.
- [x] AWACS and Scout Drone radar detection of cloaked/stealth units.
- [x] Orbital laser strike targeting, geothermal scaling damage, and beam VFX.
- [x] Unit tests for air movement and orbital laser damage scaling.

---

## Part 12 — Strategic Weapons (Nuclear)

**Objective:** Nuclear missile silo, launch, fallout.

**Deliverables:** Silo building, nuke strike, fallout terrain, match-ending rule.

**Subtasks:**
- [x] Register Nuclear Missile Silo and Orbital Laser Uplink in `UnitRegistry`.
- [x] Nuclear strike AoE devastation and cooldown management.
- [x] Terrain conversion to `WASTELAND` fallout zone within `Strategic.nuke_fallout_radius`.
- [x] HQ destruction triggers match victory.
- [x] Unit tests for fallout radius, fallout creation, and strategic damage.

---

## Part 13 — Combat Resolution & Damage

**Objective:** Finalize damage model, cover, EMP, repair.

**Deliverables:** Damage calculator, status effects, repair helpers.

**Subtasks:**
- [x] Implement 6×8 damage types and armor class matrix (`Damage`).
- [x] Cover modifiers for urban/forest (`Cover`).
- [x] EMP disable duration and tick (`EMP`).
- [x] Stealth cloak break and detection (`Stealth`, `Vision`).
- [x] Repair rate and cost calculation (`Repair`).
- [x] Unit and fuzz tests for damage math edge cases.

---

## Part 14 — Fog of War & Vision

**Objective:** Explored/visible fog, shared team vision, radar.

**Deliverables:** Vision calculations, stealth detection, team vision sharing.

**Subtasks:**
- [x] Sight range per unit (`UnitStats.sight`, `Vision.in_sight`).
- [x] Fog-of-war state machine (`UNEXPLORED`, `EXPLORED`, `VISIBLE`).
- [x] Shared team vision (`Vision.shared_vision` and `Alliance`).
- [x] Radar/AWACS reveal stealth (`Vision.stealth_detected`).
- [x] Unit and fuzz tests for vision radius and stealth reveal.

---

## Part 15 — Base Building & Production

**Objective:** Place buildings, queues, rally, repairs.

**Deliverables:** Building placement, production queue, cancellation, power grid.

**Subtasks:**
- [x] Grid placement with footprint and terrain validation (`Placement`).
- [x] Building health, turret defense auto-fire, and destruction.
- [x] Production queue per building (`Production`) with sequential ticking and progress.
- [x] Rally point setting on buildings.
- [x] Queue cancellation (`Production.cancel`).
- [x] Power grid balance and brownout efficiency (`Power`).
- [x] Unit and fuzz tests for placement validity, power grid, and production queue.

---

## Part 16 — Command & Control UI (Playable Milestone)

**Objective:** Complete UI enabling a full single-player or multiplayer match.

**Deliverables:** HUD, command bar, hotkeys, tech tier progression, win/loss detection.

**Subtasks:**
- [x] Top HUD bar: corporation, tech tier, resources, per-second income rates, population usage/cap, AI posture.
- [x] Command bar buttons & hotkeys (`1–6` unit training, `B/V` building placement, `T` tech upgrade, `L` orbital laser, `N` nuclear strike).
- [x] Drag-box selection and formation right-click movement.
- [x] Return to Main Menu and match end victory/defeat announcement.
- [x] Settings store and manager (`SettingsStore`, `SettingsManager`).
- [x] **Milestone:** Players can play a full match to completion in Single Player vs AI or Multiplayer.

---

## Part 17 — Map Editor & Custom Maps

**Objective:** Players serialize, validate, and share custom maps.

**Deliverables:** Map serializer, validator, custom map dictionary format.

**Subtasks:**
- [x] Map serialization to/from dictionary (`MapSerializer.to_dict`, `MapSerializer.from_dict`).
- [x] Map dimension and tile count validation (`MapSerializer.validate`).
- [x] Terrain modification API (`MapData.set_terrain`, `MapData.get_terrain`).
- [x] Unit tests for serialization round-trip and validation error cases.

---

## Part 18 — AI Opponent (Skirmish)

**Objective:** Solo play vs a capable tactical AI across Easy, Normal, and Hard difficulties.

**Deliverables:** AI controller with difficulty levels, economic expansion, counter-production, and squad tactics.

**Subtasks:**
- [x] Single Player vs AI mode on Main Menu with selectable AI Difficulty (Easy/Normal/Hard) and Corporation.
- [x] AI economy & base expansion (`AI.should_expand`, `AI.select_next_building`: builds farms, extractors, barracks, factories, airfields, turrets).
- [x] AI counter-production (`AI.choose_production_unit`: scouts enemy composition and builds AA vs air, bombers/rockets vs armor, tanks vs infantry, and heavy mechs at T3).
- [x] AI tactical posture state machine (`AI.choose_tactical_state`: `defend` base against intruders, `harass`, `attack` in coordinated formation waves, `rally`, and retreat damaged units).
- [x] Difficulty modifiers (`AI.income_multiplier`, `AI.decision_interval`, `AI.attack_wave_threshold`).
- [x] Unit tests for all AI decision, counter-production, building priority, and tactical state helpers.

---

## Part 19 — Audio, VFX & Polish

**Objective:** Readable, satisfying presentation.

**Deliverables:** VFX rendering, animated unit sprites, audio manager hooks, team/class color silhouettes, score system.

**Subtasks:**
- [x] Procedural multi-frame animated pixel-art sprites for every unit domain (`UnitVisual.build_unit_frame_image`: infantry robots, tracked tanks/mechs with rotating turrets, naval hulls with wakes, and aerial drones with spinning rotors).
- [x] Realistic combat state animations (`UnitVisual.AnimState`: `IDLE`, `MOVE` with stride/dust/wake puffs, `FIRE` with barrel recoil, muzzle flashes, and projectile tracers, `HIT` damage flash, and multi-stage `EXPLODE` fireball, shockwave, flying shrapnel debris, and persistent scorch craters).
- [x] Visual feedback for selection rings, drag-selection box, EMP disable arcs, orbital laser beams, and nuclear explosions.
- [x] `AudioManager` SFX and adaptive music state hooks.
- [x] Military and economic score calculation (`Score`).
- [x] Unit tests for sprite animation state machine, frame generation, kinematics, and explosion debris (`test_unit_visual.gd`).

---

## Part 20 — Testing, Release & Documentation

**Objective:** Ship a stable, documented playable build.

**Deliverables:** Full test suite green, docs, export presets, version info.

**Subtasks:**
- [x] Achieve GUT unit and fuzz test suite pass with zero orphans (`gut_orphan_guard.gd`).
- [x] Run `make ci` clean.
- [x] Complete `README.md` (install, run, controls, project layout, networking).
- [x] Wire `VersionInfo` (`0.1.0` + commit SHA) and `export_presets.cfg` for Web/Linux/Windows/macOS.
