# BroWarz — Game Design Document

**Engine:** Godot 4.7.2 (GDScript, forward+/mobile renderer targets)
**Genre:** Real-time strategy (RTS), peer-to-peer multiplayer
**Setting:** Year 2030 — rival corporate armies fighting for resource control
**Map size:** 128 × 128 tiles (configurable, player-created)
**Status:** Playable v0.1.2 — live multiplayer diplomacy, co-op and spectator options, grouped menu and full-screen map framing; v0.1.3 pending publication
**License:** Unlicense (public domain)

---

## 1. Vision & Design Pillars

BroWarz is a large-scale, real-time, peer-to-peer strategy game in which players command combined-arms corporate armies across a 128×128 battlefield. The fantasy is **industrialized warfare at scale**: oil, iron, geothermal power, and food feed factories that churn out infantry robots, drones, tanks, submarines, mechs, and ultimately orbital lasers and nuclear missiles.

Design pillars:

1. **Combined arms, not single-unit spam.** Every domain (infantry, armor, naval, air, orbital, strategic) has a hard counter; winning requires mixing.
2. **Economy first.** Resources are finite and contested; starving an enemy's factories is as valid as destroying their army.
3. **Readable scale.** Hundreds of units on a 128×128 map must remain legible through silhouettes, color coding, and a clean UI.
4. **Player authorship.** Maps, skirmish setups, and (later) mods are first-class; the map editor ships with the game.
5. **Fair peer-to-peer play.** Deterministic simulation, input replication, and desync detection keep matches honest without a central server.
6. **Modular, testable code.** Gameplay logic lives in small, pure, unit-tested systems (GUT) so balance and regressions are caught early.

## 2. Setting & Narrative

In 2030, nation-states have ceded ground to vertically integrated megacorporations. "BroWarz" are sanctioned corporate conflicts fought over resource claims: oil fields, iron ranges, geothermal vents, and arable land (food). Armies are overwhelmingly robotic — cheap, expendable, and standardized — so a corporation's edge comes from logistics, technology, and map control rather than hero units.

Each match is one engagement over a resource-rich sector. There is no persistent campaign in v1; narrative is delivered through map briefings, corporation flavor, and unit barks. A future campaign mode is out of scope for the playable version.

## 3. Core Gameplay Loop

```
Scout map → Claim resource nodes → Build extractors/refineries →
Spend resources on factories & units → Tech up → Contest territory →
Destroy enemy HQ / force surrender → Match end
```

Secondary loops:

- **Base building:** HQ → production buildings → defenses → research.
- **Tech:** research labs unlock tiers and unit upgrades.
- **Strategic escalation:** orbital laser and nuclear missile are late-game, high-cost, map-altering tools that can end a stalled match.

## 4. Match Structure

- **Players:** 2–8 (1v1, 2v2, 3v3, 4v4, free-for-all). P2P host + peers.
- **Map:** 128×128 tiles, chosen from built-in set or player-created.
- **Duration target:** 15–45 minutes.
- **Starting conditions:** Each player begins with **only an HQ** and a small unit escort (including a scout drone); every other building must be built or captured.
- **Fog of war:** On by default; the lobby can switch it off for a revealed map. Unexplored terrain stays hidden until a unit or building reveals it.
- **Win conditions:**
  1. Destroy/capture all enemy production buildings (Barracks, Factories, Airfields, Shipyards) — primary victory.
  2. Destroy all enemy HQs.
  3. Enemy surrender.
  4. (Optional) Score/time limit: highest military + economic score.
- **Defeat:** HQ destroyed or all production + workers lost.
- **Nuclear victory:** A successful nuclear strike on an enemy HQ counts as destruction.

## 5. Factions (Corporations and AI-Only NPC Factions)

**Lore:** The four playable corporations are the four weapons divisions of a single planetary megacorp that rules the planet. The RTS match itself is the medium by which these divisions settle their dividing of the planet's resources: match results draw up new trade borders.

v1 ships **four playable corporations** (IDs 0–3), symmetric in economy but asymmetric in unit flavor and one signature ability each. v0.1.3 adds **four AI-only NPC factions** (IDs 4–7) for AI sides — skirmish enemies, the co-op AI and either spectator side. Human seats, including map-editor test play, remain the four corporations; the NPC factions cannot be picked by a player. Asymmetry is light to keep balance tractable.

| Corporation (human, IDs 0–3) | Theme | Signature |
|---|---|---|
| **AeroDyne Industries** | Air superiority, precision | Cheaper aerial drones; orbital laser cooldown −15% |
| **FerroCore Heavy** | Armor & siege | Heavier tanks; sappers destroy fortifications faster |
| **Pelagic Systems** | Naval & subsurface | Submarines start cloaked; cheaper sea drones |
| **Vanguard Robotics** | Infantry & stealth | Stealth units cloak longer; mechanized infantry cheaper |

All share the same tech tree and resource model; human signatures are numeric modifiers, not unique units.

| NPC faction (AI-only) | ID / key | Identity & color | Theme music | Unique units | Modifiers |
|---|---|---|---|---|---|
| **Vesper Ascendancy** | 4 / `vesper` | Alien saucers; magenta `#FF4FD8`, lime accent `#C7FF4F` | `vesper.wav` | `ufo_wisp`, `ufo_talon`, `ufo_nova` | Air damage ×1.20, air speed ×1.30; vehicle/ground HP ×0.80 |
| **Thalassa Dominion** | 5 / `thalassa` | Atlantean navy; blue `#2F7BFF`, cyan accent `#64FFE0` | `thalassa.wav` | `abyssal_trireme`, `leviathan_carrier`, `nereid_raider` | Naval HP ×1.25, naval damage ×1.15, sea cost ×0.90; land/air damage ×0.85 |
| **Gravebound Legion** | 6 / `gravebound` | Undead attrition; olive `#8FBF3F`, bone accent `#D8C9A3` | `gravebound.wav` | `bone_legionary`, `ghoul_stalker`, `lichen_colossus` | Infantry HP ×1.20, infantry cost ×0.85, sight ×0.85; vehicle/air HP ×0.80 |
| **Lumen Cabal** | 7 / `lumen` | Illuminati foresight/stealth; gold `#F2D65B`, violet accent `#9B7BFF` | `lumen.wav` | `lumen_operative`, `lumen_oracle`, `lumen_enforcer` | Sight ×1.25, stealth duration ×1.30; all cost ×1.10, all HP ×0.90 |

NPC factions use the same buildings and shared roster plus those three unique units each; their modifiers apply only to their own units. Banners, mottos, strategy and full numbers are in [`npc.md`](npc.md), with art in [`units.md`](units.md).

## 6. Units

Units are grouped by domain. Each has a role, hard counters, and a cost in resources + build time. Exact stats are tuned in Part 19 (balancing).

### 6.1 Infantry Robots

| Unit | Role | Notes |
|---|---|---|
| Riflebot | Line infantry | Cheap, numerous, anti-infantry |
| Heavybot | Suppression | Slow, high HP, anti-light armor |
| Sapperbot | Demolition | Destroys fortifications/walls, mines, repairs structures |
| Stealthbot | Recon/ambush | Cloak, low HP, high burst, detected by radar/scout |
| Sniperbot | Long-range | Very long range, low rate of fire |
| Rocketbot | Anti-armor | Infantry-carried anti-tank |
| Medicbot | Support | Repairs friendly robots in radius |
| Engineerbot | Economy | Builds/repairs structures, captures points |

### 6.2 Mechanized Infantry

- **APC/IFV:** Transports infantry, light cannon, amphibious (some).
- **Mech Walker (light):** Fast skirmisher, anti-infantry.

### 6.3 Armor

- Light tank, main battle tank, heavy tank, self-propelled artillery, anti-air vehicle, recovery vehicle.

### 6.4 Naval

- Patrol boat, missile boat, corvette, submarine (attack), ballistic-missile submarine (strategic), landing craft, hovercraft (amphibious), frogbots (stealth), cruiser, battleship, aircraft carrier.

### 6.5 Air

- Scout drone, fighter drone, bomber drone, gunship, transport drone, AWACS (vision/radar).

### 6.6 Strategic / Orbital

- **Orbital Laser Satellite:** Targeted beam, long cooldown, high energy cost, damages structures/units in a line.
- **Nuclear Missile:** Silo-launched, massive AoE, creates fallout zone (impassable + damage), ends matches if HQ hit.

### 6.7 Large Killer Robots (Mechs)

- Heavy mech: slow, multi-weapon, anti-everything, very expensive.
- Siege mech: long-range bombardment.
- Anti-air mech.

**Counters (rock-paper-scissors):** infantry ↔ armor (rockets), armor ↔ air (AA), air ↔ infantry, naval ↔ naval, subs ↔ surface (torpedoes), stealth ↔ radar, fortifications ↔ sappers.

**Amphibious hazard:** Hovercraft traverse both land and sea, but occasionally suffer a unique hazard — "My Hovercraft is full of eels!" — temporarily disabling the unit.

## 7. Terrain & Maps

Inspired by grid-based tactics games such as *Tiny Attack*: terrain types impose movement costs and passability, and capturing production buildings is central to victory.

- **Grid:** 128×128 tiles, each tile 2 world units (256×256 m battlefield). Tile size configurable for editor preview.
- **Terrain types:** Plains, Forest, Swamp, River, Sea, Mountain, Urban Ruins, Road, Bridge, Wasteland (fallout).
- **Effects:**
  - Swamp: −movement speed for ground units, no vehicles except mechs; infantry unaffected-ish.
  - River: impassable to ground except at bridges/fords; naval passable if deep enough.
  - Sea: naval only; ground blocked.
  - Mountain: impassable except for heavy infantry, large mechs, and air units; blocks line of sight.
  - Forest: concealment (stealth bonus), slows vehicles.
  - Road: +movement.
  - Urban ruins: cover, vision blockers.
  - Fallout: damage over time, impassable after nuke.
- **Resources:** Deposits placed on tiles (oil, iron, geothermal, food). Geothermal only on vents.
- **Map metadata:** name, author, description, player slots, resource multiplier, fog of war default, allowed units.

## 8. Resources & Economy

Four resources:

| Resource | Primary use | Source |
|---|---|---|
| Oil | Fuel, power, vehicle/air production | Oil wells |
| Iron | Construction, armor, structures | Mines |
| Geothermal | High energy: lasers, nukes, heavy industry | Geothermal plants on vents |
| Food | Infantry upkeep, population cap | Farms |

Economy rules:

- Extractors harvest deposits at a base rate; rate modified by terrain and upgrades.
- Refineries convert raw to usable (or direct-use model; decide in implementation; v1 uses direct usable with extractor output).
- **Population cap** (food-based) limits total units; HQ + farms raise cap.
- **Power grid:** structures require power; underpower slows production. (Optional v1; can be simplified to geothermal-only for heavy units.)
- **Income tick:** every 1s; displayed as rate/min.
- **No market/trade in v1.**

## 9. Combat System

- **Damage model:** `damage = base * type_multiplier[attacker_type][target_armor] * (1 - armor_reduction) * terrain_cover_modifier`.
- **Damage types:** Kinetic, Explosive, Energy, EMP, Thermal, Toxic (fallout).
- **Armor classes:** Unarmored, Light, Medium, Heavy, Structure, Naval, Air, Submerged.
- **NPC faction modifiers:** AI-only factions alter their own units' damage, HP, speed, sight, stealth duration and cost on top of the armor/damage-type matrix, terrain/cloud cover, cloak and tech upgrades. The modifiers never apply to human corporations (IDs 0–3); exact values are in [`npc.md`](npc.md).
- **Range & accuracy:** Projectiles with travel time for artillery/missiles; hitscan for lasers/small arms. Accuracy modified by movement, range, terrain.
- **Cover:** Urban ruins/forest reduce incoming damage for infantry.
- **Stealth:** Cloaked units invisible unless within detection radius of radar/scout/AWACS or attacking.
- **Sonar early warning:** Corvettes deploy sonar buoys (`K` / HUD button) on a 30 s cooldown; each 320 px sweep reveals enemy submarines to the deploying team and its allies for 75 s.
- **EMP:** Disables unit for N seconds (no movement/attack); robots more vulnerable.
- **Repair:** Engineer/Medic/depot repair; cost resources.
- **No morale** (robots), but command disruption via EMP/comms jamming (future).

## 10. Vision & Fog of War

- **Fog:** unexplored terrain is black, explored-but-unseen terrain is dimmed, and currently visible terrain renders in full. Terrain and obstacles modify sight.
- **Units:** see by their own sight range; scouts and AWACS extend what a team can observe.
- **Faction sight:** NPC sight is modified per faction (Lumen ×1.25, Gravebound ×0.85) before the radar and sonar fog rules below apply; spectator AI sides still act on their own fog knowledge, not on the view-only revealed map.
- **Buildings:** ordinary structures see only a short perimeter (80 px). `radar` and `missile_tower` have limited, powered sweeps of **480 px** and **320 px** respectively; each sweep reveals terrain and cloaked contacts in its area and shrinks with power efficiency.
- **Sonar:** corvette-deployed buoys reveal enemy submarines to their owner and allies for a limited time; they do not reveal terrain or surface targets. Sonar-aware fog and the minimap hide submerged contacts until a buoy, sonar unit, or sight detection finds them.
- **Minimap:** top-center of the HUD, clear of the bottom-right unit corner; shows fog, blips, buoys and the camera viewport, and supports camera jumps, move orders and pings.
- **Sharing:** vision is shared within a team and across allied sides; `GameManager.is_allied()` is the single source of truth. See [`diplomacy.md`](diplomacy.md).

## 11. Base Building & Production

- **Placement:** Grid-aligned, with footprint and collision; cannot overlap resources/terrain impassable.
- **Sapper fortifications:** Sapperbots (and the commander's build orders) construct three defensive structures that register a movement block on the 16 px tile grid: **Wall** (blocks all ground unit classes), **Barbed Wire** (impedes infantry only, class 0/6), **Missile Tower** (anti-air battery — 320 px range, explosive damage, powered 320 px radar sweep; does not block movement). Air (class 3) and naval (class 2) units are never stopped by land fortifications; walls and wire are removed from the block registry when destroyed. The `Fortification` core class is pure and unit-tested.
- **Buildings:** HQ, Docks, Mech Factory 1 (smaller bots/light mechs), Mech Factory 2 (medium armor & advanced construction bots), Mech Factory 3 (heavy tanks/killer mechs, built only by advanced construction bots), Shipyard, Advanced Shipyard, Aeries Level 1 (scout/fighter drones), Aeries Level 2 (bomber/AWACS drones), Refinery/Extractor, Power Plant, Research Lab, Radar, Turret, Missile Tower, Wall, Barbed Wire, Farm, Silo (nukes), Orbital Uplink. See [`docs/factories.md`](factories.md).
- **Production chain:** Every player starts with an HQ and a small unit escort (including a scout drone), with no other buildings. Players build or capture a Barracks/Mech Factory 1 for infantry and Sappers, then Factories for armor and construction vehicles, Airfields/Aeries for air units, and Shipyards/Docks on shorelines for naval units. Extractors are built on resource deposits.
- **Queue:** Production queue per building; rally points.
- **Cancellation:** Refunds partial cost.
- **Repairs:** Engineerbots or auto-repair near depot.

## 12. Technology & Upgrades

- **Tiers:** T1 (start), T2 (research lab), T3 (advanced lab), T4 (strategic).
- **Research:** Global per-player tech tree; costs resources + time.
- **Upgrades:** Unit HP/damage/speed, armor, sight, stealth duration, resource yield.
- **Strategic unlocks:** Orbital laser, nuclear missile, heavy mechs require T4 + special buildings.

## 13. Strategic Weapons

- **Orbital Laser:** Requires Orbital Uplink + T4 + geothermal. Targeted line beam, long cooldown (e.g., 120s), high damage to structures/units. Can be shot down? No (orbital). Counter: spread units, shields (future).
- **Nuclear Missile:** Requires Silo + T4 + massive resources. Long build time. Creates fallout zone. Triggers match-ending if HQ hit; otherwise massive damage + terrain change. Early-warning via radar; can be intercepted by (future) missile defense.

## 14. Command, Control & UI

- **Camera:** Pan/zoom, edge scroll, top-center minimap click.
- **Selection:** Box select, shift-add, control groups (0–9).
- **Commands:** Move, attack, attack-move, patrol, guard, stop, hold, build, repair, unload, cloak toggle, sonar buoy.
- **Overlays:** Resource rates, power, population, tech, minimap pings; the minimap stays clear of the bottom-right unit corner.
- **Comms:** Team chat, ping markers, surrender vote, and the in-match **Diplomacy** panel for 3+ team multiplayer matches.
- **Accessibility:** Remappable keys, colorblind palettes, UI scale, subtitles for barks.

## 15. Map Editor

- Tile painting (brush/rectangle/fill), terrain height? (flat tiles v1).
- Place resources, start positions, neutral structures. Implemented: Team 0..3 HQ spawn markers and Oil/Iron/Geothermal/Food deposit markers, drawn in-editor and serialized into `.bwm` files and `BWM1:` share codes.
- Validate: enough resources, valid start areas, no blocked HQ. Implemented: **Validate Map** confirms passable infantry hex paths between all HQs and balanced resource deposits near each spawn.
- Save/load custom maps (`.bwm` or Godot resource) to user dir; share via file.
- In-game map browser with metadata and preview.

## 16. Multiplayer & Networking (P2P)

- **Transport:** Godot `HighLevelMultiplayerAPI` with `ENetMultiplayerPeer` (desktop) and `WebRTCMultiplayerPeer` (web builds) for true P2P. A lobby scene (`scenes/lobby.tscn`) drives host/join: the host pins map, teams, fog of war and transport from `LobbyState` settings; clients adopt a host snapshot and only send ready/start requests.
- **Topology:** Host-authoritative lobby and gameplay:
  - The host is peer id 1. Every client command is sent to the host, which re-validates it (whitelist, ownership, cost) before applying it and relaying the sanitized copy back to all peers. A client never applies a command that the host rejected.
  - Commands carry only intent (move/train/build/fortify/tech/laser/nuke/capture/demolish/diplomacy/hold/stop); the host overwrites `team` from its own lobby record, so a forged payload cannot claim another player's economy or accept an alliance for another side.
  - Teams are assigned round-robin from the lobby's `num_teams` setting (2–4) and reused after host migration.
- **State sync:** Periodic simulation checksums (`NetworkManager.broadcast_hash`) are throttled (≥ 3 s apart) and relayed to the host for desync detection. On mismatch the host's state is authoritative (resync via the next lobby snapshot).
- **Reconnect & host migration:** A dropped peer keeps its seat for a 30 s grace window (`LobbyState.sweep`); rejoining proves ownership with a crypto-random resume token issued at admission (token is sent only in the targeted welcome, never in broadcast snapshots). If the host vanishes mid-match, the lowest connected peer is elected successor (`next_host_id`) and re-hosts on the same port, marking the other seats disconnected so they can rejoin with their tokens. WebRTC transport degrades gracefully to ENet if signaling fails.
- **Match settings (networked):** map type (0–2), number of teams (2–4), fog of war, transport (enet/webrtc), seed, and the co-op settings (`coop_vs_ai`, `human_faction`, `ai_difficulty`, `ai_faction`) are pinned by the host in `LobbyState.settings` and staged into `GameManager` before scene load; every peer applies the same map, seed, team layout and AI configuration. New keys are added to `NetSecurity.sanitize_settings()`/`default_settings()` so hostile clients cannot inject unknown match state.
- **Security (see §21):** fail-closed whitelisting (`NetSecurity`), constant-time passcode compare, crypto-random resume tokens, token-bucket rate limiting with strikes→kick, per-peer monotonic sequence anti-replay (`SeqGuard`), protocol-version handshake, masked addresses in logs, and session bans for kicked peers.
- **NAT:** STUN/TURN fallback documented; web uses signaling server (minimal, out of scope for v1 dedicated infra; LAN/direct IP first).

### Match Modes

| Mode | Entry point | Teams | Command authority |
|---|---|---|---|
| Single player vs AI | Main menu **Skirmish** | Human team 0 vs AI team 1 | Local human + local AI |
| Co-op vs AI | Host lobby, **Co-op: On (2 humans vs AI)** | Both humans share team 0 vs one AI on team 1 | Host validates human and AI commands; both humans may issue orders for the shared side |
| AI vs AI spectator | Main menu **Watch AI vs AI (View Only)** | Two AI teams, factions selected before launch | No local command authority; camera and pause only |
| P2P skirmish | Host/join lobby | 2–4 human teams | Host-authoritative command relay |

- **Co-op vs AI** requires exactly two connected players. The host pins the human corporation, AI corporation and AI difficulty in the lobby; both seats are assigned team 0 by `LobbyState._reassign_teams()`, while team 1 is a synthetic AI seat added by `_net_teams()` so victory scoring sees both sides.
- AI decisions are generated only by the match host. `_issue_ai_command()` sanitizes each build/research/train/move decision and passes it through `NetworkManager.apply_host_command()`, so the co-op partner receives the same validated command stream as the host. Clients can never inject AI orders.
- **Spectator mode** is a local view-only match driven by the same per-team AI controller for both sides. The main menu's **Spectator AI Side A** and **AI Opponent / Side B** selectors both cycle IDs 0–7, so either AI can use an NPC faction (while the human **Your Corp** selector stays at IDs 0–3 for Skirmish). Both sides share the chosen difficulty. The spectator fog overlay is disabled so both sides are visible in the view, but each AI still acts on its own fog knowledge and scouts. Mouse selection/hotkeys/build commands are ignored, attack waves are smaller and the rally grace shorter so contact arrives sooner. The HUD shows both sides and labels the result `SPECTATOR`.
- Co-op and spectator use fixed sides, so in-match diplomacy is intentionally unavailable there (see [`diplomacy.md`](diplomacy.md)).

### In-Match Diplomacy

- Matches with three or more teams expose a **Diplomacy** panel. Proposals are directional; only the target team can accept or decline, and only the proposer can cancel.
- Accepting merges connected alliance sides transitively; breaking removes every link between two sides. `Alliance.normalize()` keeps the graph symmetric so combat, fog and victory agree on both peers.
- All actions travel through the same host-authoritative command pipeline as unit orders. See [`diplomacy.md`](diplomacy.md) for rules, functions, persistence and replay details.

## 17. AI (Skirmish)

- Optional AI opponent for solo, co-op and spectator matches; dropped-player replacement remains a future extension.
- Difficulty levels (Easy/Normal/Hard) via economy/scouting/micro bonuses, stored per team in `GameManager.team_difficulties`.
- Behavior: expand, counter enemy composition, rally, defend, harass and attack visible enemies. `_run_ai_turn_for_team()` drives each AI side independently, while the legacy team-1 fields stay synchronized for saves and tests.
- Knowledge is fog-aware: each AI sees through its own visibility, sends scout drones and other scouts sweeping ahead, and briefly remembers the last visible contact (45 s) without gaining live hidden positions. AI-vs-AI spectator matches attack sooner with smaller waves and a shorter rally grace.
- Faction identity is resolved per team through `GameManager.faction_for_team()`, so mirrored corporations and both spectator sides get readable chess black/white variants.
- AI faction selectors cover IDs 0–7: NPC factions 4–7 are available only to AI sides (skirmish enemy, co-op AI, spectator); human seats stay 0–3. AI-vs-AI spectator keeps shorter rallies and smaller attack waves regardless of the chosen factions.

## 18. Audio & Visual

- **Style:** Stylized low-poly / clean silhouettes, team colors, readable at zoom-out.
- **VFX:** Muzzle flashes, explosions, nuke mushroom, laser beam, cloak shimmer.
- **Audio:** Per-weapon SFX, ambient map audio, UI clicks, alerts, voice barks (robotic).
- **Music:** Menu + in-match (adaptive intensity). The menu/settings soundtrack picker supplies the logical `menu`/`battle` cues; each NPC faction also has a theme WAV available to that system, and NPC battle music follows the selected soundtrack unless a dedicated theme is chosen ([`npc.md`](npc.md)).

## 19. Performance & Scalability

- Target: 60 FPS with 500+ units on 128×128 map on mid-range hardware.
- Techniques: MultiMesh for identical units, navigation region baking, spatial hashing for queries, LOD for models, occlusion culling, batching, avoid per-frame allocations, pool projectiles.
- Network: command-only replication keeps bandwidth low.

## 20. Testing & Quality

- **Unit tests (GUT):** pure logic systems (damage, economy, pathfinding helpers, serialization).
- **Integration tests:** scene-level (spawn, build, destroy).
- **Fuzz tests:** property-based for math/serialization.
- **Regression tests:** fixed scenarios for reported bugs.
- **Python tooling:** asset checks, coverage gates, deadcode scans (per Makefile).
- **CI:** `make ci` gate; markdown lint.

## 21. Security & Anti-Cheat (Limitations)

P2P cannot fully prevent cheating, but BroWarz ships a **defense-in-depth** lobby and command pipeline (`NetSecurity`, `RateLimiter`, `SeqGuard`, `LobbyState`) designed for hostile peers on untrusted networks:

- **Fail closed:** every inbound payload is whitelisted and coerced; unknown keys, types and out-of-range values are dropped (`sanitize_name`, `sanitize_settings`, `sanitize_command`, `is_valid_address`). An empty result always means "reject".
- **Host authority:** the host overwrites `team` from its own lobby record; clients only accept command relays that originate from peer id 1 (`_from_server`). A forged client payload can never touch another player's economy, units or alliance side.
- **Access control:** optional lobby passcode compared in constant time; resume tokens are 32-byte crypto-random hex and are issued per seat, sent only in the targeted welcome RPC (never in broadcast snapshots); kicked peers are session-banned by token and address (5 min TTL).
- **Anti-flood:** per-peer token buckets (handshake, lobby, command, hash, WebRTC signaling) with escalating strikes that kick the offending peer.
- **Anti-replay:** per-sender monotonic sequence guard (`SeqGuard`); out-of-order or duplicate sequences are dropped and counted as violations.
- **Handshake:** protocol-version check on connect; hello timeout (5 s) disconnects silent peers; handshake deadline (10 s).
- **Privacy:** addresses are masked in all logs (`mask_address`).
- **Limits:** ranked play and server-side authority are deferred; a modified client can still lie about its own inputs within the validated command grammar (e.g., move targets). Documented as a known limitation.

## 22. Data & Save Formats

- **Maps:** `.bwm` (Godot Resource or JSON) with version field and migration.
- **Replays:** recorded command streams + initial map seed; deterministic playback, including `DIPLOMACY` commands.
- **Diplomacy:** save settings carry `teams`, `alliances` and `alliance_proposals`; map/reload paths normalize integer team ids after JSON round-trips.
- **Match context:** saves also persist `match_mode`, `ai_enabled`, `ai_teams`, `team_factions`, `team_difficulties`, `is_spectator` and `local_team`, so quickload restores co-op vs AI and view-only AI-vs-AI matches without leaking stale AI difficulty into a later multiplayer game.
- **Settings:** `user://settings.cfg`, persisted by the in-game Settings dialog (audio volumes/mute, camera speed, UI scale, colorblind palettes, camera hotkeys) through `SettingsManager`/`SettingsStore`.
- **Versioning:** semantic versioning; save/map migration on load.

## 23. Accessibility

- Colorblind modes, UI scale, remappable input, subtitles, reduced motion option, pause in single-player/skirmish.

## 24. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| P2P desyncs | Lockstep + checksums + deterministic RNG |
| Performance with 500+ units | MultiMesh, spatial hashing, profiling gates |
| Balance complexity | Data-driven stats in resources, telemetry, iterative playtests |
| Map editor scope creep | Ship paint + place + validate first; height/advanced later |
| Solo play lacking | Include skirmish AI in roadmap |

## 25. Glossary

- **HQ:** Headquarters structure; losing it loses the match.
- **Tick:** Fixed simulation step (20 Hz).
- **Lockstep:** All peers advance simulation in sync from replicated inputs.
- **Extractor:** Structure harvesting a resource deposit.
- **Cloak:** Stealth state; breaks on attack/movement (unit-dependent).

---
## 26. Current Implementation Status

The repository now contains a playable single-player skirmish vertical slice and P2P multiplayer lobby/match foundation plus extensive core systems. Implemented:

- Project bootstrap, autoloads (`GameManager`, `NetworkManager`, `ResourceManager`, `SettingsManager`, `AudioManager`, `SceneManager`), 4 human corporations with signature colors, emblems and gameplay modifiers, and 4 AI-only NPC factions with banners, colors, modifiers and unique units.
- Core systems: damage, economy, map data, command serialization, unit/building stats, production queues, placement, fortifications, vision/stealth/EMP/cover/repair, tech, fog of war, lockstep helpers, network security/rate-limiting/sequence guards, lobby state, game state/replay/save settings, hex grid & A* pathfinding, AI heuristics, strategic weapons, formation, transitive alliances with host-authoritative diplomacy, scoring, power, resource deposits, and ambient wildlife (`Wildlife`).
- Visuals & Audio:
  - Large 48×48 high-detail procedural unit sprites (`UnitVisual`) across all 29 base unit roles (32 registry IDs including worker aliases) with 100% uniform geometry across factions, 5 animation states (`IDLE`, `MOVE`, `FIRE`, `HIT`, `EXPLODE`), articulated turret rotation, barrel recoil, muzzle flashes, projectile tracers, and shrapnel/scorch-mark explosions.
  - High-resolution 512×512 terrain rendering (4× sub-tile detail) with forest tree canopies and shrubs, water wave highlights, and mountain ridges.
  - Large 48×48 sprites for the 12 AI-only unique units, each with its own faction-native art instead of a corporation recolor.
  - Ambient non-combatant wildlife (Birds on all maps, Dolphins and Squid in sea/river water, and Deer in forests/plains) that wander, flee when chased or shot at, and die when hit.
  - Custom retro-future corporate dystopia main logo (`assets/logo.png`), minimalist corporation banners and AI-only NPC banners (`assets/banners/*.png`).
  - Faction-styled building thumbnails for every registered building ID in `docs/thumbnails/buildings/`, alongside the unit thumbnails in `docs/thumbnails/`.
- Gameplay: 128×128 maps (Desert, Island Chain, Forest), 29 base unit roles across infantry/armor/naval/air, 20 buildings & fortifications (23 registry IDs including aliases), economy, tech progression, orbital laser and nuclear strikes, fog of war with powered radar sweeps and corvette sonar buoys, a top-center minimap, tactical fog-aware skirmish AI (Easy/Normal/Hard) for solo/co-op/spectator matches, multiplayer diplomacy, and map editor.
- Audio: procedural looping menu/battle beds plus four selectable corporation soundtracks (AeroDyne, FerroCore, Pelagic, Vanguard) with main-menu and settings switchers, four AI-only NPC theme WAVs available to the soundtrack system, and an aliased SFX set.
- Verification: GUT unit/integration/fuzz/regression suites, the post-run orphan guard, and the `make check`/`make ci` gates; web export is a separate `make build-web` gate.

Outstanding gaps (see `docs/roadmap.md`):

- A fuller voice-bark/SFX set beyond the current alias table.
- Campaign/mods and dedicated server authority (deferred beyond v1).
- Additional polish/performance passes.

## 27. High-Resolution Graphics Plan

### Unit Graphics
- Source art at 128×128 (4× current 32×32) with 2×/4× export variants.
- Use nearest-neighbor scaling for pixel-art, or bilinear for high-res 3D sprites.
- AnimatedSprite2D frame sets: idle, move, fire, hit, explode (8 frames each).
- Per-corporation color palettes applied via shader uniforms.
- LOD: switch to 32×32 icon sprites when zoomed out beyond threshold.
- Normal maps for lighting on high-res sprites.

### Terrain Graphics
- Tile size 16 world units; source tiles at 64×64 (4×).
- Terrain atlas with 8 variants per biome for variety.
- Animated tiles for water (waves), lava, etc.
- Height/parallax for mountains and cliffs.
- Decals for scorch marks, roads, and resource nodes.
- Dynamic weather overlays (rain, snow) as full-screen shaders.

### Pipeline
- Blender/MagicaVoxel for 3D unit renders → sprite sheets.
- Aseprite for 2D pixel-art and animation.
- Automated export via CI to generate mipmaps and atlases.

## 28. Hex Grid & Screenshots

- Units move on a pointy-topped hex grid (size 16) overlaid on the 128×128 tile map.
- Hex pathfinding respects terrain passability per unit class.
- Screenshot capture: press F12 in-game to save a PNG to `user://screenshots/`.

---
*End of design document.*
