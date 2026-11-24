# BroWarz — Remaining Roadmap Items

Completed roadmap items have been removed. The items below are the verified gaps remaining to reach a fully featured release.

## Part 3 — Multiplayer P2P Integration
- [x] Lobby state, network security, rate limiting, and host/join P2P scene (`scenes/lobby.tscn`, `LobbyState`, `NetSecurity`).
- [x] Handle peer disconnects, reconnect grace period, and host migration (`LobbyState`, `NetworkManager`).
- [x] Add networked match settings (map, teams, fog of war, ENet/WebRTC transport).
- [ ] Full end-to-end multi-peer lockstep soak testing over WAN/WebRTC.

## Part 4 — Map Rendering & Terrain Visuals
- [x] Hex-grid movement and pathfinding (`HexGrid`).
- [x] High-resolution 4× sub-tile terrain rendering with forest trees, shrubs, water ripples, and mountain ridges (`UnitVisual.build_terrain_map_image`).
- [x] Ambient non-combatant wildlife (Deer, Dolphins, Squid, Birds) that wander, flee when chased or shot at, and die when hit (`Wildlife`).
- [x] Sapper fortifications (barrier walls, barbed wire, missile towers) blocking ground pathfinding (`Fortification`).

## Part 10 — Naval Expansion
- [x] Register ballistic-missile submarine, landing craft, cruiser, battleship, aircraft carrier, hovercraft, and stealth frogman in `UnitRegistry` with 48×48 detailed uniform sprites.
- [ ] Add dedicated amphibious unit embark/disembark UI commands.

## Part 19 — Audio, Visuals & Polish
- [x] Large 48×48 high-detail, strictly uniform unit sprites across all 31 units and 4 corporations (`UnitVisual`, `docs/units.md`).
- [x] Animated combat states (`IDLE`, `MOVE`, `FIRE`, `HIT`, `EXPLODE`), weapon tracers, recoil, and persistent scorch craters.
- [x] Styled `BroWarz` main logo (urban-camouflage letters + 4 faction tanks) and minimalist corporation banner logos (`assets/banners/*.png`).
- [ ] Performance profiling pass (MultiMesh, LOD, batching) for 500+ simultaneous units.

## Part 20 — Release
- [ ] Export and smoke-test all platform release bundles.
- [ ] Publish final release notes and collect post-release feedback.

## Dependency Notes
- Multiplayer integration builds on the lockstep, lobby state, and network security cores.
- Map editor builds on `MapSerializer` (implemented).
