# BroWarz — Roadmap

## Status

Every previously tracked milestone and gap-analysis step has been verified against the live code and UI and removed from the checklist. **v0.1.3 is pending publication**; no tag has been moved or created, and the older tags remain where they are.

Verification gates are `make check` (GUT suite, post-run orphan guard, layout/deadcode checks, and workflow lint via `actionlint` when installed), headless Godot import, and CI. Web export is a separate `make build-web` gate, not part of `make check`. All checks will be run before release.

## Verified milestones (checklist retired)

- **v0.1.0 foundation:** secure P2P/lobby/lockstep with a deterministic 4-peer soak harness, 128×128 hex maps with per-terrain modifiers and drifting clouds, the combined-arms roster and tiered factories, plus ambient wildlife, sapper fortifications, texture caching and spatial-hash LOD.
- **v0.1.1 co-op, spectator and diplomacy:** host-pinned two-player co-op vs AI, view-only AI-vs-AI spectator mode, per-team AI/faction context, save/load parity with corrupt-context rejection, host-authoritative diplomacy documentation, and a secure host pipeline for all human gameplay commands (not just AI and diplomacy).
- **v0.1.2 menu and map polish:** grouped two-column main menu, full-viewport camo with readability scrim, and a single camera clamp path shared by spawning, panning, zooming, minimap jumps and viewport resizes.
- **Post-v0.1.2 gap analysis (20 steps, all wired):** interactive placement ghosts, on-map finite deposits, live power/brownouts, research UI, minimap with viewport and pings, control groups and zoom, targeted strike reticle, production palettes, engineer capture and demolition, sonar target acquisition, carrier drone decks, procedural WAV audio with four selectable faction soundtracks, in-match save/load, replay recording/playback, multiplayer diplomacy, map-editor validation tools, persistent settings/accessibility, and spatial-hash/MultiMesh rendering.

Audit corrections applied while retiring the checklist: the registry contains **29 base unit roles / 32 IDs including worker aliases** (not “31 units”); sapper fortifications use footprint ghosts while `L`/`N` use the strike reticle; the victory panel now includes match duration; multiplayer diplomacy is documented as multiplayer-only, not skirmish; stale test counts were removed in favor of the `make check` gate.

## v0.1.3 (pending publication)

Work in the pending release:

- HQ-only opening: each player starts with one HQ and a small escort including a scout drone; all other buildings must be built or captured.
- Previously deferred sonar-aware fog/minimap concealment is now implemented: corvette sonar buoys reveal submarines to their owner and allies on a cooldown, and submerged contacts stay hidden until sonar or sight finds them.
- Powered radar: `radar` and `missile_tower` sweep 480 px/320 px, revealing terrain and cloaked contacts with range scaled by power efficiency.
- The minimap sits top-center, clear of the bottom-right unit corner, with fog, blips, buoys, camera viewport and pings.
- AI uses its own fog knowledge, sweeps scouts ahead, remembers the last visible contact briefly (45 s), and attacks sooner in AI-vs-AI spectator mode.
- Building thumbnails for every registered building ID are generated into `docs/thumbnails/buildings/` alongside unit thumbnails.
- Four AI-only NPC factions (IDs 4–7 — Vesper Ascendancy, Thalassa Dominion, Gravebound Legion, Lumen Cabal): AI-only selection for skirmish enemies, co-op AI and both spectator sides (human seats stay IDs 0–3), dedicated banners/colors/theme tracks, 12 unique units with faction-native thumbnails and sprites, per-faction combat modifiers, and updated docs and tests documented in [`npc.md`](npc.md).
- Dedicated **Building Inspector Panel** (`scripts/ui/building_inspector.gd`): selecting any friendly structure opens a bottom-left panel showing icon, HP, power delta, powered radar sweep, rally coordinates, live queue progress bar, one-click unit training buttons, queue cancellation (`X`), rally reset, and 25% refund demolition.
- Live runtime **Lockstep Soak & Checksum Sync** (`scripts/ui/lockstep_dialog.gd` + `game.gd`): exposes the multi-peer deterministic soak harness from both the main menu and pause menu, and broadcasts/compares periodic `GameState` checksums over `NetworkManager` during active P2P matches with live desync alerts.
- Expanded **Per-Weapon SFX & Robotic Voice Barks** (`scripts/core/voice_bark.gd`, 24 synthesized WAVs in `assets/sfx/`): distinct procedural SFX for all 6 weapon damage types, unit/building explosions, orders, sonar pings, captures, tech completion, and throttled robotic voice barks with an accessible HUD subtitle toast toggled in Settings.

## Deferred / future ideas

- Campaign, mods and dedicated server authority (deferred beyond v1).
