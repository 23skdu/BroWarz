# BroWarz — Roadmap

## Status

Every previously tracked milestone and gap-analysis step has been verified against the live code and UI and removed from the checklist. Verification gates are `make check` (GUT suite plus post-run orphan guard), headless Godot import, `actionlint`, CI, and web export. No new release is pending.

## Verified milestones (checklist retired)

- **v0.1.0 foundation:** secure P2P/lobby/lockstep with a deterministic 4-peer soak harness, 128×128 hex maps with per-terrain modifiers and drifting clouds, the combined-arms roster and tiered factories, plus ambient wildlife, sapper fortifications, texture caching and spatial-hash LOD.
- **v0.1.1 co-op, spectator and diplomacy:** host-pinned two-player co-op vs AI, view-only AI-vs-AI spectator mode, per-team AI/faction context, save/load parity with corrupt-context rejection, and host-authoritative diplomacy documentation.
- **v0.1.2 menu and map polish:** grouped two-column main menu, full-viewport camo with readability scrim, and a single camera clamp path shared by spawning, panning, zooming, minimap jumps and viewport resizes.
- **Post-v0.1.2 gap analysis (20 steps, all wired):** interactive placement ghosts, on-map finite deposits, live power/brownouts, research UI, minimap with viewport and pings, control groups and zoom, targeted strike reticle, production palettes, engineer capture and demolition, sonar target acquisition, carrier drone decks, procedural WAV audio with four selectable faction soundtracks, in-match save/load, replay recording/playback, multiplayer diplomacy, map-editor validation tools, persistent settings/accessibility, and spatial-hash/MultiMesh rendering.

Audit corrections applied while retiring the checklist: the registry contains **29 base unit roles / 32 IDs including worker aliases** (not “31 units”); sapper fortifications use footprint ghosts while `L`/`N` use the strike reticle; the victory panel now includes match duration; multiplayer diplomacy is documented as multiplayer-only, not skirmish; stale test counts were removed in favor of the `make check` gate.

## Deferred / future ideas

- A live runtime hook for the lockstep soak harness; the soak currently runs as a deterministic test rather than an in-game verification path.
- A dedicated building-inspector panel; the live building HUD already shows queue progress, rally flags and hotkey cancellation.
- Sonar-aware fog/minimap concealment for submerged units; sonar currently governs target acquisition.
- A fuller voice-bark/SFX set beyond the current alias table.
- Campaign, mods and dedicated server authority (deferred beyond v1).
