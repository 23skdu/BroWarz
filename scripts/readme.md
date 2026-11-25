# BroWarz Script Inventory

This directory contains every runtime, tool, and verification script in the project. GDScript files are grouped by role; Python files support CI checks and local web serving. The authoritative test suite is GUT under `tests/` (run with `make check`), not the two legacy no-op smoke scripts noted below.

## Autoloads (`scripts/autoload/`)

- `audio_manager.gd` — Plays looping music and SFX, maps logical `menu`/`battle` cues to the selected faction soundtrack, resolves SFX aliases, and applies persisted volume/mute settings.
- `game_manager.gd` — Holds global match state (mode, map, teams, factions, AI, alliances, clouds) and allocates network IDs and fortification movement blocks.
- `network_manager.gd` — Secure P2P session manager: lobby handshake, host-authoritative command validation and relay, rate limiting, anti-replay, disconnect grace, host migration, WebRTC transport, and checksums.
- `resource_manager.gd` — Tracks per-player wallets, base/effective resource rates, population caps, and power efficiency; runs economy ticks.
- `scene_manager.gd` — Thin wrapper that delegates scene changes to `SceneTree.change_scene_to_file()`.
- `settings_manager.gd` — Loads/saves `user://settings.cfg` and applies audio, soundtrack, UI scale, colorblind palette, and camera hotkey settings live.

## Core systems (`scripts/core/`)

- `ai.gd` — Difficulty tables and heuristics for income, targeting, army composition, production, and tactical decisions.
- `alliance.gd` — Normalizes team adjacency graphs and handles alliance proposal states, connected sides, merging, and splitting.
- `building_stats.gd` — Resource defining building identity, HP, costs, footprint, produced unit, build time, and HQ flag.
- `command.gd` — Serialized lockstep command data (type, tick, player, unit IDs, target, build type) with equality support.
- `cover.gd` — Terrain/unit-class attack and defense modifiers plus drifting cloud spawning, stepping, and containment checks.
- `damage.gd` — Damage-type/armor multiplier matrix and helpers for computed, role-adjusted, and effective damage.
- `economy.gd` — Resource keys and wallet helpers for affordability, spending, grants, income accrual, and population caps.
- `emp.gd` — Armor-adjusted EMP disable duration and active-timer state.
- `faction.gd` — Corporation identities, colors, colorblind/mirror variants, modifiers, and effective unit stats.
- `fog_of_war.gd` — Per-tile explored/visible arrays with radius visibility marking and line-of-sight checks.
- `formation.gd` — Grid offset positions for arranging a group of units.
- `fortification.gd` — Sapper-built structure IDs and pure movement-block/anti-air rules.
- `game_state.gd` — Tick/resource/unit/building snapshots with checksum generation and restoration.
- `hex_grid.gd` — World-to-axial hex conversion, neighbors, distance, and passability-aware hex paths.
- `lobby_state.gd` — Host-authoritative, socket-free lobby membership, settings, ready/start gating, disconnect grace, host migration, and snapshots.
- `lockstep.gd` — Fixed-tick command buffering, input delay, peer readiness, and a deterministic multi-peer soak helper.
- `map_data.gd` — Map resource storing tiles, terrain metadata, HQ spawns, deposits, movement rules, hex connectivity, and validation.
- `map_serializer.gd` — Map conversion to/from dictionaries, JSON files, and `BWM1:` share codes with detailed validation.
- `net_security.gd` — Fail-closed sanitizers/validators for names, addresses, lobby settings, hello payloads, and gameplay commands, plus tokens and log masking.
- `pathfinding.gd` — A* over map tiles with class-aware passability and a tile-distance heuristic.
- `placement.gd` — Building footprint validation for bounds, terrain, occupancy, and naval requirements, plus occupy/free helpers.
- `power.gd` — Production/consumption balance, brownout efficiency, building power deltas, and team summaries.
- `production.gd` — Timed build queue with enqueue, tick, cancel, size, and progress helpers.
- `rate_limiter.gd` — Per-peer token buckets with escalating violation strikes and bans.
- `repair.gd` — Pure repair amount, cost, and eligibility calculations.
- `replay.gd` — Validated command log recording and serialization for later playback.
- `resource_deposit.gd` — Finite harvestable resource node with rate, remaining amount, harvest, and depletion checks.
- `save_game.gd` — Versioned game-state/settings dictionary serialization to and from storage form.
- `score.gd` — Military, economic, and total score formulas.
- `seq_guard.gd` — Per-peer monotonic sequence numbers that reject replayed or reordered commands.
- `settings_store.gd` — Small in-memory key/value settings dictionary with `has`, `remove`, and dict round-trip.
- `stealth.gd` — Cloak-break conditions, cloak duration, and active cloak state.
- `strategic.gd` — Nuke fallout radius, orbital laser damage, and fallout-creation checks.
- `tech.gd` — Research tree with prerequisites, unlock state, affordability, and available-node queries.
- `terrain_generator.gd` — Seeded desert, island, and forest `MapData` generator.
- `unit_registry.gd` — Default unit/building stats and queries for transport, worker, builder, and producer capabilities.
- `unit_stats.gd` — Resource defining unit identity, HP, speed, armor/damage, range, sight, costs, class, stealth, and build ability.
- `unit_visual.gd` — Procedural faction-styled sprite frames, terrain images, texture caching, LOD, and spatial-grid helpers.
- `version_info.gd` — Thin accessor for application version and commit SHA from `ProjectSettings`/`build_info.json`.
- `vision.gd` — Sight, stealth detection, sonar, fog-state, and shared allied-vision checks.
- `wildlife.gd` — Ambient deer/dolphin/squid/bird spawning, wandering, fleeing, damage, and per-step movement.

## Gameplay scenes (`scripts/game/`)

- `building.gd` — StaticBody2D building with HP, production queue and rally flags, turret targeting/firing, damage, destruction, and queue drawing.
- `game.gd` — Main match scene orchestrating map/camera/HUD/input, units/buildings, economy, research, AI, networking, fog, replay, save/load, and victory.
- `map_editor.gd` — Node2D editor for painting terrain, HQ spawns, and deposits, with validation, save/load/share-code, and test-play workflows.
- `unit.gd` — CharacterBody2D unit handling hex movement/orders, combat, animation, transports, cloaking, EMP, repair, and building capture.

## UI (`scripts/ui/`)

- `diplomacy_dialog.gd` — Views alliance state and sends host-authorized propose/cancel/accept/decline/break commands.
- `lobby.gd` — P2P lobby UI showing players/settings and routing ready, start, settings, and leave actions through `NetworkManager`.
- `main_menu.gd` — Skirmish/spectator/host/join/editor entry plus map, difficulty, faction, soundtrack, and tool selection.
- `minimap.gd` — Corner tactical minimap rendering terrain and fog-aware blips while emitting camera-jump, move-order, and ping signals.
- `replay_viewer.gd` — Loads a saved replay and scrubs/plays its validated command stream with readable command descriptions.
- `research_dialog.gd` — Research-tree picker showing prerequisites, unlock state, and affordability; emits `research_selected`.
- `settings_dialog.gd` — In-game settings dialog applying volume, soundtrack, mute, camera, UI-scale, and colorblind changes live.

## Tooling (`scripts/tools/`, `scripts/testing/`, and root scripts)

- `tools/generate_audio.gd` — Deterministic headless generator for the six music loops (menu, battle, and four faction soundtracks) and five SFX WAVs.
- `tools/generate_map_thumbnails.gd` — Headless renderer for desert, islands, and forest terrain thumbnails.
- `tools/generate_thumbnails.gd` — Headless renderer for four faction thumbnails per registered unit into `docs/thumbnails`.
- `run_tests.gd` — Legacy no-op SceneTree smoke script; GUT is the real test runner.
- `run_tests.sh` — Legacy no-op shell smoke script kept for the `test-scripts` target.
- `testing/gut_orphan_guard.gd` — GUT post-run hook that fails the test command when orphaned nodes remain.
- `bw_util.py` — Minimal `clamp(v, lo, hi)` helper used by the Python unit suite.
- `check_bg.py` — CI helper verifying faction banner PNGs keep an anti-aliased alpha background.
- `check_coverage.py` — CI helper failing when a `scripts/core` module lacks a GUT unit-test reference.
- `check_deadcode.py` — CI helper scanning for duplicate `class_name`s and unreferenced GDScript files.
- `check_fuzz_coverage.py` — CI helper verifying high-risk core modules are referenced by fuzz tests.
- `serve_web.py` — Local HTTP-server wrapper for `build/web` with COOP/COEP headers for WebAssembly threading.
