# BroWarz — Roadmap

## Status

**v0.1.4** is the latest published release. All post-v0.1.3 gap-analysis items — including the graphics performance & quality overhaul, Map Editor UX Phases 2–4, combined-arms formations, patrol/guard orders, nuclear early-warning window, in-match chat/surrender, dropped-peer AI takeover, WebRTC ICE configuration, live in-scene replays & victory telemetry, and full command/build hotkey remapping — are shipped and verified in **v0.1.4**.

Verification gates are `make check` / `make ci` (GUT suite, post-run orphan guard, layout/deadcode checks, 100% Python coverage, asset checks, `markdownlint`, and workflow lint via `actionlint` when installed), headless Godot LSP audit (`0 errors, 0 warnings`), and headless Godot import. Web export is a separate `make build-web` gate.

## Verified milestones (checklist retired)

- **v0.1.0 foundation:** secure P2P/lobby/lockstep with a deterministic 4-peer soak harness, 128×128 hex maps with per-terrain modifiers and drifting clouds, the combined-arms roster and tiered factories, plus ambient wildlife, sapper fortifications, texture caching and spatial-hash LOD.
- **v0.1.1 co-op, spectator and diplomacy:** host-pinned two-player co-op vs AI, view-only AI-vs-AI spectator mode, per-team AI/faction context, save/load parity with corrupt-context rejection, host-authoritative diplomacy documentation, and a secure host pipeline for all human gameplay commands (not just AI and diplomacy).
- **v0.1.2 menu and map polish:** grouped two-column main menu, full-viewport camo with readability scrim, and a single camera clamp path shared by spawning, panning, zooming, minimap jumps and viewport resizes.
- **v0.1.3 NPC factions, tactics, inspector, lockstep & audio:** HQ-only opening with scout escort, corvette sonar buoys and powered radar sweeps, top-center minimap, four AI-only NPC factions (Vesper Ascendancy, Thalassa Dominion, Gravebound Legion, Lumen Cabal) with 12 native units/banners/themes, overhauled combined-arms AI tactics, dedicated Building Inspector panel, live Lockstep Soak & P2P checksum sync, and 24 procedural per-weapon SFX & robotic voice-bark clips with toggleable subtitles.

## Post-v0.1.3 Gap Analysis & v0.1.4 Shipped Improvements

### Graphics & Rendering

- [x] **High-resolution `PackedByteArray` terrain synthesis (`UnitVisual.build_terrain_map_image`):** Upgraded battlefield terrain rendering to `8×8` sub-tile detail (`1024×1024` on High quality) written directly via `PackedByteArray` with shoreline foam/depth gradients, directional NW-lit mountain/hill shading, connected road lane markings, bridge girders, urban rooftops/windows, swamp bog pools, desert dune ripples, and cracked wasteland fissures.
- [x] **Batched GPU canopy `MultiMeshInstance2D` foliage (`game.gd` + `UnitVisual.get_canopy_texture`):** Replaced flat untextured tree quads and hundreds of per-frame `_draw()` shrub circles with a single textured GPU `MultiMeshInstance2D` rendering lush, shaded circular tree and shrub canopies.
- [x] **Fast throttled linear Fog of War & minimap (`game.gd`, `minimap.gd`, `UnitVisual.fog_rgba_bytes`):** Replaced per-frame 16,384-pixel GDScript `set_pixel()` loops with reusable `PackedByteArray` uploads throttled to 10 Hz, enabled smooth linear GPU filtering (`TEXTURE_FILTER_LINEAR`) for atmospheric fog transitions, throttled minimap redraws to 15 Hz, and fixed undetected cloaked/submerged unit blip leaks on the minimap.
- [x] **Camera viewport frustum culling & VFX caps (`game.gd`, `UnitVisual.camera_world_rect`):** Culled off-screen deposits, blast craters, sonar buoys, wildlife, tracers, VFX, and clouds in `_draw()`, and enforced per-quality caps on live tracers and VFX.
- [x] **Dirty-tracked unit & building rendering (`unit.gd`, `building.gd`):** Eliminated redundant per-tick texture lookups, string allocations, and idle `queue_redraw()` calls for stationary units and idle structures.
- [x] **Battlefield visual polish & graphics settings (`unit.gd`, `building.gd`, `game.gd`, `SettingsManager`, `SettingsDialog`):** Added altitude-offset drop shadows for aerial craft and grounded contact shadows for ground/naval units and buildings, dual-core glowing tracers, layered blast craters, distinct iconic resource node visuals, dynamic green/amber/red health bars, and persisted **Graphics Quality** (`Low` / `Medium` / `High`) and **Reduced Motion** controls in Settings.
- [x] **GPU-instanced unit batching at far zoom (`game.gd:unit_lod_multimesh`, `unit.gd`, `UnitVisual.get_unit_lod_texture`):** Zoomed-out (`zoom < 0.65`) or massive (`300+` unit) battles automatically switch unit rendering to a single textured `MultiMeshInstance2D` of directional faction-tinted tactical badges while preserving fog visibility and selection rings.
- [x] **Subtle animated water & weather shaders (`game.gd:terrain_shader_mat`, `UnitVisual.water_shimmer_shader_code`):** Attached a lightweight Compatibility/WebGL2-safe `CanvasItem` terrain shader with animated water shimmer and subtle atmospheric weather tinting gated by `graphics_quality` and `reduced_motion`.
- [x] **Pooled hit-spark & smoke particle layer (`game.gd:particle_pool`):** Added a fixed 160-slot preallocated particle ring buffer with zero per-frame allocations for weapon impact sparks, explosion embers, and rising smoke on damaged vehicles and buildings (`< 50%` HP).
- [x] **Automated 500-unit performance benchmark test (`tests/unit/test_unit_visual.gd`):** Added a headless GUT timing/budget regression test exercising 500-unit spatial-hash queries, 128×128 `FogOfWar` buffer updates, and 64×64 terrain image synthesis.

### Map Editor UX (Phases 2–4 of [`map_editor_ui_plan.md`](map_editor_ui_plan.md))

- [x] **Three-pane `HSplitContainer` workspace (`scripts/game/map_editor.gd`):** Split the editor into a compact top action bar, left scrollable Tool Rail (Terrain Brush, Flood Fill, HQ/Deposit/Erase markers, Brush 1–4 slider, Mirror-X/Mirror-Y symmetry, Grid Overlay, Zoom controls), transparent click-through center zoomable canvas (`0.45×`–`2.0×`), and right Inspector pane.
- [x] **Safer file workflows (`scripts/game/map_editor.gd`, `SettingsManager`):** Added native `FileDialog` (`Save As…` / `Browse…` filtered to `*.bwm`), unsaved-changes dirty indicator (`*`), `ConfirmationDialog` guards for discarding unsaved edits (`New`) or overwriting files, and a persisted **Recent Maps** picker.
- [x] **Persistent validation checklist & undo/redo (`scripts/game/map_editor.gd`):** Added a live `ValidationPanel` checklist (dimensions, land tiles, spawns, hex path connectivity, deposit balance) and a 30-step `Ctrl+Z` / `Ctrl+Shift+Z` (`Ctrl+Y`) terrain and marker undo/redo history stack.

### Gameplay, Commands & Formations

- [x] **Patrol & guard commands (`unit.gd`, `game.gd`, `command.gd`, `net_security.gd`):** Wired multi-point `patrol` loops (`Y`) and 240 px leashed `guard` stance (`J`) through the host-authoritative command pipeline and HUD.
- [x] **Combined-arms tactical formations (`scripts/core/formation.gd`, `game.gd`):** Extended `Formation` with `tactical_offsets()` supporting **Grid**, **Wedge**, **Line**, and **Echelon** templates (`Q` cycle) that orient along move headings and place vanguard/armor forward, anti-air/infantry on flanks, and standoff artillery/workers in the rear.
- [x] **Nuclear launch early-warning window (`scripts/core/strategic.gd`, `game.gd`, `minimap.gd`):** Added a `5.0 s` launch-to-impact flight timer (`Strategic.NUKE_WARNING_SECONDS`) with HUD warning alert, pulsing battlefield countdown reticle, and flashing minimap warning ring so defenders can scatter forces before impact.

### Multiplayer, Replays & Accessibility

- [x] **In-match team chat & surrender vote (`game.gd`, `net_security.gd`, `command.gd`):** Added a host-relayed toggleable Chat & Comms drawer (`Enter`) with `All` / `Team` scopes and a team surrender-vote command that cleanly concedes matches when teammates agree.
- [x] **Dropped-peer AI takeover (`lobby_state.gd`, `network_manager.gd`, `game_manager.gd`, `game.gd`):** Upgraded `LobbyState.sweep_detailed()` and `NetworkManager._host_watchdog()` so teams left with zero human players after the 30 s disconnect grace window are automatically handed over to the skirmish AI (`peer_ai_takeover` signal + HUD/chat notification).
- [x] **WebRTC ICE/signaling configuration UI (`lobby.gd`, `network_manager.gd`, `net_security.gd`, `settings_dialog.gd`):** Added fail-closed `stun:`/`turn:`/`turns:` URL validation (`NetSecurity.is_valid_ice_url`), wired `iceServers` initialization into `WebRTCPeerConnection`, and exposed host-editable STUN/TURN & signaling diagnostics in the multiplayer lobby and Settings dialog.
- [x] **Live in-scene replay playback & victory telemetry (`replay_viewer.gd`, `game.gd`):** Added playback speed multipliers (`0.5×`–`4×`), timeline scrub slider, and **Play Live in Match** command injection into `game.tscn`, plus per-team telemetry breakdown (units trained/lost, buildings built/lost, damage dealt, resources harvested) on the post-match Victory/Defeat panel.
- [x] **Full command & build hotkey remapping (`settings_manager.gd`, `settings_dialog.gd`, `game.gd`):** Extended key remapping beyond the four camera pan keys to cover 19 unit command, formation, strategic weapon, and build hotkeys persisted in `user://settings.cfg`.

## Deferred / future ideas

- Campaign mode, user mod loader, and dedicated server authority (deferred beyond v1).
