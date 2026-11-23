# BroWarz — 20-Part Roadmap to a Playable Version

This roadmap breaks delivery into 20 parts. Each part has an objective, deliverables, and subtasks. A "playable version" is reached at the end of **Part 16** (multiplayer skirmish playable end-to-end); Parts 17–20 polish, add AI/editor depth, and prepare release.

Legend: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Part 1 — Project Bootstrap & Tooling

**Objective:** Establish the Godot 4.7.2 project skeleton, repo conventions, and CI so all later work is testable.

**Deliverables:** `project.godot`, folder layout, GUT addon, Makefile wired to BroWarz, pre-commit hooks.

**Subtasks:**
- [ ] Create `project.godot` (Godot 4.7.2) with project name "BroWarz", main scene placeholder, viewport 1920×1080, stretch mode canvas_items.
- [ ] Establish folder layout: `scenes/`, `scripts/`, `resources/`, `assets/`, `tests/` (unit/integration/fuzz/regression), `addons/`.
- [ ] Install GUT v9.7.1 into `addons/gut/` via `make deps`.
- [ ] Configure `.gitignore` (already present) and add `.gdignore` for build/venv.
- [ ] Wire `Makefile` project name/version (`config/version`) and verify `make check-godot`, `make import`.
- [ ] Add export presets for Web, Linux, Windows, macOS (Android/iOS optional).
- [ ] Install pre-commit hooks (`make install-hooks`).
- [ ] Add `README.md` quickstart (Part 20 refines).
- [ ] CI smoke: `make ci` runs (may be empty tests) without error.

---

## Part 2 — Core Architecture & Scene Structure

**Objective:** Define autoloads, scene tree, and data-driven resource patterns.

**Deliverables:** Autoload singletons, base classes, resource definitions.

**Subtasks:**
- [ ] Create autoloads: `GameManager`, `NetworkManager`, `ResourceManager`, `SettingsManager`, `AudioManager`, `SceneManager`.
- [ ] Define base `Unit` (CharacterBody3D/2D? decide 3D vs 2.5D). Decision: 3D with orthographic-ish camera? Or 2D? Recommend **3D with top-down camera** for mechs/terrain. Document decision.
- [ ] Decide coordinate system and tile size; create `GridMap`/`TileMap` abstraction.
- [ ] Create resource classes (`Resource` subclasses) for `UnitStats`, `BuildingStats`, `TerrainType`, `MapData`.
- [ ] Implement data loading from `res://data/*.tres` / JSON.
- [ ] Add logging/debug overlay (FPS, tick, peer count).
- [ ] Unit tests for resource parsing and stat modifiers.

---

## Part 3 — Networking Foundation (P2P Lobby & Match)

**Objective:** Players can host/join a match over LAN/internet via Godot high-level multiplayer.

**Deliverables:** Lobby UI, host/join, peer management, chat, match start sync.

**Subtasks:**
- [ ] Implement `NetworkManager` with ENet host/join (desktop) and WebRTC (web).
- [ ] Lobby scene: create/join by IP, player list, ready state, map selection, team assignment.
- [ ] Peer connect/disconnect handling; host migration plan (document; v1: host disconnect ends match).
- [ ] RPCs for chat, ping, ready, start match.
- [ ] Sync random seed and map data to all peers before start.
- [ ] Graceful disconnect UI + return to menu.
- [ ] Integration tests for connect/disconnect in headless mode.

---

## Part 4 — Map System & Terrain

**Objective:** Render and query a 128×128 terrain map with movement modifiers.

**Deliverables:** Tilemap/grid, terrain types, pathfinding integration, map loading.

**Subtasks:**
- [ ] Implement `MapData` resource (size, tiles, resources, start positions).
- [ ] Render terrain tiles (MultiMesh or TileMap3D) with materials per terrain type.
- [ ] Movement cost per terrain per unit class (infantry/vehicle/naval/air).
- [ ] Navigation: bake NavigationRegion per map; handle dynamic obstacles (buildings).
- [ ] Line-of-sight raycasts with terrain blockers.
- [ ] Fog-of-war texture (explored/visible) — basic in Part 13.
- [ ] Load built-in maps; validate dimensions.
- [ ] Unit tests for movement cost and LOS.

---

## Part 5 — Resource & Economy System

**Objective:** Harvesting, income, storage, population cap.

**Deliverables:** Resource nodes, extractors, income tick, UI rates.

**Subtasks:**
- [ ] Resource deposit entities with type/amount.
- [ ] Extractor buildings harvest deposits; rate modifiers.
- [ ] `ResourceManager` tracks per-player resources, income, storage caps.
- [ ] Farms increase population cap; HQ base cap.
- [ ] Income tick (1s) replicated via lockstep commands (not direct state) — coordinate with Part 6.
- [ ] Refinery conversion (if applicable) — decide direct-use vs conversion; document.
- [ ] UI: resource bar with current/limit and rate.
- [ ] Unit tests for income, caps, spend/refund.

---

## Part 6 — Deterministic Simulation & Lockstep

**Objective:** All peers advance gameplay in sync from replicated inputs.

**Deliverables:** Fixed tick, command buffer, checksum desync detection.

**Subtasks:**
- [ ] Fixed simulation tick (20 Hz) decoupled from render.
- [ ] Command system: `MoveCommand`, `AttackCommand`, `BuildCommand`, etc., serializable.
- [ ] Clients send commands with tick; host/peers buffer and release at target tick.
- [ ] Input delay (e.g., 3–6 ticks) to absorb latency.
- [ ] Deterministic RNG seeded from match seed.
- [ ] Periodic state checksum (units/buildings/resources) broadcast; desync logging + pause.
- [ ] Reconnect handling: late join as spectator (v1).
- [ ] Unit tests for command serialization and checksum determinism.

---

## Part 7 — Unit Framework & Movement

**Objective:** Spawn, select, move units with formation/pathfinding.

**Deliverables:** Unit base class, selection, pathfinding, rally.

**Subtasks:**
- [ ] `Unit` base: stats (HP, speed, armor, sight), team, state machine (idle/move/attack).
- [ ] Health, death, cleanup, orphan guard compliance.
- [ ] Click-to-move with pathfinding; group move with formation.
- [ ] Selection: box select, shift, control groups 0–9.
- [ ] Rally points for buildings.
- [ ] Unit tests for state transitions and selection logic.

---

## Part 8 — Infantry & Robot Units

**Objective:** Implement all infantry robots and mechanized infantry.

**Deliverables:** Riflebot, Heavybot, Sapperbot, Stealthbot, Sniperbot, Rocketbot, Medicbot, Engineerbot, APC/IFV, light mech.

**Subtasks:**
- [ ] Create `UnitStats` resources for each infantry unit.
- [ ] Implement sapper demolition vs fortifications/walls/mines.
- [ ] Stealth cloak + detection interaction (placeholder until Part 13).
- [ ] Medic repair radius; Engineer build/repair/capture.
- [ ] Mechanized infantry transport load/unload.
- [ ] Balance pass (numbers TBD).
- [ ] Unit tests for sapper damage, cloak break, repair.

---

## Part 9 — Vehicles & Heavy Units

**Objective:** Tanks, artillery, AA, mechs.

**Deliverables:** Light/MBT/heavy tank, SPG, AA vehicle, recovery, heavy/siege/AA mechs.

**Subtasks:**
- [ ] Vehicle movement with terrain restrictions (no swamp for heavy).
- [ ] Turret aiming and projectile travel.
- [ ] Artillery indirect fire with min range and splash.
- [ ] AA targeting vs air units.
- [ ] Mechs: large collision, multi-weapon, high cost.
- [ ] Unit tests for damage vs armor classes.

---

## Part 10 — Naval & Submarine Units

**Objective:** Sea drones, submarines, transports.

**Deliverables:** Patrol/missile boats, corvettes, attack subs, ballistic subs, landing craft.

**Subtasks:**
- [ ] Naval movement on sea tiles; depth handling.
- [ ] Submarine cloaking/sonar detection.
- [ ] Torpedoes vs surface; anti-sub weapons.
- [ ] Ballistic sub as strategic nuke platform (links to Part 12).
- [ ] Amphibious loading/unloading.
- [ ] Unit tests for sub detection and damage.

---

## Part 11 — Air & Orbital Units

**Objective:** Aerial drones and orbital systems.

**Deliverables:** Scout/fighter/bomber/gunship/transport drones, AWACS, orbital laser uplink.

**Subtasks:**
- [ ] Flight movement (ignore terrain, height layer).
- [ ] Air-to-air and air-to-ground combat.
- [ ] Transport drop.
- [ ] AWACS vision/radar boost.
- [ ] Orbital laser targeting + beam VFX + cooldown.
- [ ] Unit tests for air targeting priorities.

---

## Part 12 — Strategic Weapons (Nuclear)

**Objective:** Nuclear missile silo, launch, fallout.

**Deliverables:** Silo building, missile entity, fallout terrain, match-ending rule.

**Subtasks:**
- [ ] Silo build + T4 requirement + huge resource cost.
- [ ] Launch sequence with warning, travel time, interception hook (future).
- [ ] Explosion AoE damage + terrain conversion to Wasteland/fallout.
- [ ] Fallout DoT and impassable for ground.
- [ ] HQ hit → match end (win).
- [ ] Radar early warning + UI alert.
- [ ] Unit/integration tests for fallout creation and damage.

---

## Part 13 — Combat Resolution & Damage

**Objective:** Finalize damage model, projectiles, cover, EMP, repair.

**Deliverables:** Damage calculator, projectile system, status effects.

**Subtasks:**
- [ ] Implement damage types and armor class matrix.
- [ ] Projectiles: hitscan vs travel-time; splash.
- [ ] Cover modifiers for urban/forest.
- [ ] EMP disable status.
- [ ] Stealth detection radii.
- [ ] Repair systems and costs.
- [ ] Fuzz tests for damage math edge cases.

---

## Part 14 — Fog of War & Vision

**Objective:** Explored/visible fog, shared team vision, radar.

**Deliverables:** Fog texture, vision sources, radar reveal.

**Subtasks:**
- [ ] Vision component per unit/structure with radius.
- [ ] Fog-of-war render layer (black/grey/clear).
- [ ] Shared team vision.
- [ ] Radar/AWACS reveal stealth.
- [ ] Minimap integration.
- [ ] Performance: update fog on tick, not per frame where possible.
- [ ] Tests for vision radius and stealth reveal.

---

## Part 15 — Base Building & Production

**Objective:** Place buildings, queues, rally, repairs.

**Deliverables:** Building placement, production UI, cancellation refunds.

**Subtasks:**
- [ ] Grid placement with footprint validation.
- [ ] Building health and destruction.
- [ ] Production queue UI per building.
- [ ] Rally point setting.
- [ ] Cancel refund.
- [ ] Power requirement (optional simplified).
- [ ] Repair via engineer/depot.
- [ ] Tests for placement validity and queue.

---

## Part 16 — Command & Control UI (Playable Milestone)

**Objective:** Complete UI enabling a full multiplayer match.

**Deliverables:** HUD, minimap, command card, build menu, tech UI, chat, surrender.

**Subtasks:**
- [ ] Top bar: resources, rates, pop, power.
- [ ] Minimap with pings and camera jump.
- [ ] Selection panel and command card.
- [ ] Build menu (contextual to selected builder/HQ).
- [ ] Tech tree UI with research progress.
- [ ] Chat and ping markers.
- [ ] Surrender vote and match end screen.
- [ ] Settings (keys, audio, UI scale).
- [ ] **Milestone:** two players can play a full match to completion.

---

## Part 17 — Map Editor & Custom Maps

**Objective:** Players create and share maps.

**Deliverables:** Editor tool, validation, save/load, in-game browser.

**Subtasks:**
- [ ] Tile paint tools (brush/rect/fill).
- [ ] Resource/start-position placement.
- [ ] Neutral structures placement.
- [ ] Validation (resources, start areas, HQ reachability).
- [ ] Save/load `.bwm` with version + migration.
- [ ] Map browser with metadata/preview.
- [ ] Import/export files.
- [ ] Tests for serialization round-trip.

---

## Part 18 — AI Opponent (Skirmish)

**Objective:** Solo play vs AI.

**Deliverables:** AI controller with difficulty levels.

**Subtasks:**
- [ ] AI economy: expand, build extractors.
- [ ] AI production: mixed army composition.
- [ ] AI scouting and threat response.
- [ ] AI attacks: timing, targeting weakest.
- [ ] Difficulty modifiers (Easy/Normal/Hard).
- [ ] Replace dropped players with AI (optional).
- [ ] Tests for AI decision helpers.

---

## Part 19 — Audio, VFX & Polish

**Objective:** Readable, satisfying presentation.

**Deliverables:** VFX set, SFX, music, team colors, accessibility.

**Subtasks:**
- [ ] Unit/building models and silhouettes; team color application.
- [ ] Muzzle flashes, explosions, nuke mushroom, laser beam, cloak shimmer.
- [ ] SFX for weapons, UI, alerts, barks.
- [ ] Adaptive music.
- [ ] Colorblind palettes, UI scale, remappable keys, subtitles, reduced motion.
- [ ] Performance profiling pass (MultiMesh, LOD, batching).
- [ ] Balance tuning pass with telemetry hooks.

---

## Part 20 — Testing, Release & Documentation

**Objective:** Ship a stable, documented playable build.

**Deliverables:** Full test suite green, docs, release builds, changelog.

**Subtasks:**
- [ ] Achieve GUT unit/integration/fuzz/regression coverage gates.
- [ ] Run `make ci` clean.
- [ ] Complete README (install, run, controls, map sharing, troubleshooting).
- [ ] Write changelog and version bump.
- [ ] Export Web/Linux/Windows/macOS builds; smoke test.
- [ ] Publish release notes and known limitations (P2P trust, NAT).
- [ ] Post-release: collect feedback, plan Part 21+.

---

## Dependency Notes

- Part 6 (lockstep) should be introduced before heavy gameplay (Parts 8–12) but can start after Part 4.
- Part 13 (combat) refines damage used by unit parts; unit parts may use placeholder damage until then.
- Part 16 is the playable milestone; Parts 17–20 are polish/release.

## Definition of "Playable Version"

A build where 2+ players can host/join, choose a map, play a full match with economy, production, combat across domains, fog of war, and a win/loss outcome over the network without desync.
