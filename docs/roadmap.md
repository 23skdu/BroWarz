# BroWarz — Roadmap & Implementation Checklist

All 20 roadmap parts and verification items are implemented, wired into gameplay, and covered by the GUT unit, fuzz, and regression test suites.

## Part 3 — Multiplayer P2P Integration
- [x] Lobby state, network security, rate limiting, and host/join P2P scene (`scenes/lobby.tscn`, `LobbyState`, `NetSecurity`).
- [x] Handle peer disconnects, reconnect grace period, and host migration (`LobbyState`, `NetworkManager`).
- [x] Add networked match settings (map, teams, fog of war, ENet/WebRTC transport).
- [x] Full end-to-end multi-peer lockstep soak testing over simulated WAN/WebRTC (`Lockstep.run_soak_simulation`, `NetworkManager.attach_game`, `game.gd:apply_command`).

## Part 4 — Map Rendering, Terrain Modifiers & Drifting Clouds
- [x] Hex-grid movement and pathfinding (`HexGrid`).
- [x] High-resolution 4× sub-tile terrain rendering with forest trees, shrubs, water ripples, hills, desert dunes, and mountain ridges (`UnitVisual.build_terrain_map_image`).
- [x] Per-terrain movement and combat (attack & defense) modifiers tailored to each unit class (`MapData.movement_cost`, `MapData.speed_multiplier`, `Cover.defense_modifier_for_unit`, `Cover.attack_modifier_for_unit`).
- [x] Random drifting cloud formations across the battlefield that exclusively affect aerial units (`Cover.spawn_clouds`, `Cover.step_clouds`, `Cover.cloud_air_speed_multiplier`, `Cover.cloud_air_defense_modifier`, `Cover.cloud_air_attack_modifier`).
- [x] Ambient non-combatant wildlife (Deer, Dolphins, Squid, Birds) that wander, flee when chased or shot at, and die when hit (`Wildlife`).
- [x] Sapper fortifications (barrier walls, barbed wire, missile towers) blocking ground pathfinding (`Fortification`).

## Part 10 — Naval Expansion & Amphibious Operations
- [x] Register ballistic-missile submarine, landing craft, cruiser, battleship, aircraft carrier, hovercraft, and stealth frogbot in `UnitRegistry` with 48×48 detailed uniform sprites.
- [x] Document and register tiered production facilities (`hq`, `docks`, `mech_factory_1..3`, `shipyard`, `advanced_shipyard`, `aeries_1..2`) and `adv_engineerbot` in `UnitRegistry` and `docs/factories.md`.
- [x] Add dedicated amphibious unit embark/disembark UI commands (`[E]` Embark / `[U]` Disembark buttons and hotkeys, `Unit.embark_passenger`, `Unit.disembark_all`).

## Part 19 — Audio, Visuals & Polish
- [x] Large 48×48 high-detail, strictly uniform unit sprites across all 31 units and 4 corporations (`UnitVisual`, `docs/units.md`).
- [x] Animated combat states (`IDLE`, `MOVE`, `FIRE`, `HIT`, `EXPLODE`), weapon tracers, recoil, and persistent scorch craters.
- [x] Styled `BroWarz` main logo (urban-camouflage letters + 4 faction tanks) and minimalist corporation banner logos (`assets/banners/*.png`).
- [x] Performance profiling & scaling support (`UnitVisual.get_cached_unit_texture`, `UnitVisual.lod_sprite_size`, `UnitVisual.build_spatial_grid`, `UnitVisual.query_spatial_radius`) for 500+ simultaneous units.

## Part 20 — Release
- [x] Export and smoke-test platform release configuration (`build_info.json`, `VersionInfo`, `Makefile` targets).
- [x] Publish release notes and complete documentation (`README.md`, `docs/factories.md`, `docs/units.md`, `docs/maps.md`, `docs/corporations.md`).
