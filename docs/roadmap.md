# BroWarz — Remaining Roadmap Items

Completed roadmap items have been removed. The items below are the verified gaps remaining to reach a fully featured release.

## Part 3 — Multiplayer P2P Integration
- [ ] Wire lobby host/join flow into the game scene.
- [ ] Replicate commands and game state over ENet/WebRTC.
- [ ] Handle peer disconnects, reconnect grace period, and host migration.
- [ ] Add networked match settings (map, teams, fog of war).

## Part 4 — Map Rendering & Terrain Visuals
- [ ] Bake navigation regions per map and update for dynamic buildings.
- [ ] Add terrain-based movement and line-of-sight visuals.

## Part 10 — Naval Expansion
- [ ] Implement ballistic-missile submarine (strategic nuke platform).
- [ ] Implement landing craft and amphibious transport.
- [ ] Add naval counterplay (depth charges, torpedoes, anti-sub).

## Part 17 — Map Editor UI
- [ ] Build tile painting tools (brush, rectangle, fill).
- [ ] Place resources, start positions, neutral structures.
- [ ] Validate maps and save/load `.bwm`.
- [ ] In-game map browser with metadata/preview.

## Part 19 — Audio & Polish
- [ ] Add weapon, UI, and alert sound effects.
- [ ] Add adaptive music tracks.
- [ ] Add voice barks (robotic).
- [ ] Performance profiling pass (MultiMesh, LOD, batching).

## Part 20 — Release
- [ ] Export and smoke-test all platforms.
- [ ] Publish release notes and known limitations.
- [ ] Collect feedback and plan next iteration.

## Dependency Notes
- Multiplayer integration depends on the existing lockstep and game-state cores.
- Map editor depends on `MapSerializer` (implemented).
