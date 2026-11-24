# BroWarz — Game Design Document

**Engine:** Godot 4.7.2 (GDScript, forward+/mobile renderer targets)
**Genre:** Real-time strategy (RTS), peer-to-peer multiplayer
**Setting:** Year 2030 — rival corporate armies fighting for resource control
**Map size:** 128 × 128 tiles (configurable, player-created)
**Status:** Pre-production / design phase
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
- **Starting conditions:** Each player begins with an HQ, a small worker/robot complement, and a nearby resource cluster.
- **Fog of war:** On (default); "revealed map" option for casual play.
- **Win conditions:**
  1. Destroy/capture all enemy production buildings (Barracks, Factories, Airfields, Shipyards) — primary victory.
  2. Destroy all enemy HQs.
  3. Enemy surrender.
  4. (Optional) Score/time limit: highest military + economic score.
- **Defeat:** HQ destroyed or all production + workers lost.
- **Nuclear victory:** A successful nuclear strike on an enemy HQ counts as destruction.

## 5. Factions (Corporations)

v1 ships **four playable corporations**, symmetric in economy but asymmetric in unit flavor and one signature ability each. Asymmetry is light to keep balance tractable.

| Corporation | Theme | Signature |
|---|---|---|
| **AeroDyne Industries** | Air superiority, precision | Cheaper aerial drones; orbital laser cooldown −15% |
| **FerroCore Heavy** | Armor & siege | Heavier tanks; sappers destroy fortifications faster |
| **Pelagic Systems** | Naval & subsurface | Submarines start cloaked; cheaper sea drones |
| **Vanguard Robotics** | Infantry & stealth | Stealth units cloak longer; mechanized infantry cheaper |

All share the same tech tree and resource model; signature abilities are numeric modifiers, not unique units, in v1.

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

- Patrol boat, missile boat, corvette, submarine (attack), ballistic-missile submarine (strategic), landing craft.

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

- **Grid:** 128×128 tiles, each tile 2 world units (256×256 m battlefield). Tile size configurable for editor preview.
- **Terrain types:** Plains, Forest, Swamp, River, Sea, Mountain, Urban Ruins, Road, Bridge, Wasteland (fallout).
- **Effects:**
  - Swamp: −movement speed for ground units, no vehicles except mechs; infantry unaffected-ish.
  - River: impassable to ground except at bridges/fords; naval passable if deep enough.
  - Sea: naval only; ground blocked.
  - Mountain: impassable, blocks line of sight.
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
- **Range & accuracy:** Projectiles with travel time for artillery/missiles; hitscan for lasers/small arms. Accuracy modified by movement, range, terrain.
- **Cover:** Urban ruins/forest reduce incoming damage for infantry.
- **Stealth:** Cloaked units invisible unless within detection radius of radar/scout/AWACS or attacking.
- **EMP:** Disables unit for N seconds (no movement/attack); robots more vulnerable.
- **Repair:** Engineer/Medic/depot repair; cost resources.
- **No morale** (robots), but command disruption via EMP/comms jamming (future).

## 10. Vision & Fog of War

- Each unit has a sight range; terrain/elevation modifies.
- Fog of war: unexplored (black), explored (grey, last known), visible (full).
- Radar structures/AWACS reveal stealth in radius.
- Shared vision within team.

## 11. Base Building & Production

- **Placement:** Grid-aligned, with footprint and collision; cannot overlap resources/terrain impassable.
- **Buildings:** HQ, Barracks (infantry), Factory (vehicles/mechs), Shipyard (naval), Airfield (air), Refinery, Power Plant, Research Lab, Radar, Turret, Wall, Mine/Extractor, Farm, Silo (nukes), Orbital Uplink.
- **Production chain:** Every player starts with an HQ and a Barracks. Barracks produce infantry (including Sappers). Sappers construct additional Barracks and Factories. Factories produce tanks and construction vehicles. Construction vehicles construct Airfields (air units) and Shipyards/Docks on shorelines (naval units). Extractors are built on resource deposits.
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

- **Camera:** Pan/zoom, edge scroll, minimap click.
- **Selection:** Box select, shift-add, control groups (0–9).
- **Commands:** Move, attack, attack-move, patrol, guard, stop, hold, build, repair, unload, cloak toggle.
- **Overlays:** Resource rates, power, population, tech, minimap pings.
- **Comms:** Team chat, ping markers, surrender vote.
- **Accessibility:** Remappable keys, colorblind palettes, UI scale, subtitles for barks.

## 15. Map Editor

- Tile painting (brush/rectangle/fill), terrain height? (flat tiles v1).
- Place resources, start positions, neutral structures.
- Validate: enough resources, valid start areas, no blocked HQ.
- Save/load custom maps (`.bwm` or Godot resource) to user dir; share via file.
- In-game map browser with metadata and preview.

## 16. Multiplayer & Networking (P2P)

- **Transport:** Godot `HighLevelMultiplayerAPI` with `ENetMultiplayerPeer` (desktop) and `WebRTCMultiplayerPeer` (web builds) for true P2P.
- **Topology:** Host-authoritative lobby; gameplay uses **deterministic lockstep**:
  - Fixed simulation tick (e.g., 20 Hz).
  - Clients send input commands with tick numbers.
  - All peers advance only when all inputs for a tick are received (with a small command buffer / delay).
  - Host coordinates start and handles late join (spectator only in v1).
- **State sync:** Periodic checksums of simulation state for desync detection; on desync, log and optionally pause.
- **Reconnect:** Peer may reconnect within grace period; otherwise AI/takeover or defeat.
- **NAT:** STUN/TURN fallback documented; web uses signaling server (minimal, out of scope for v1 dedicated infra; LAN/direct IP first).
- **Security:** P2P is trust-based; v1 targets friendly play. Anti-cheat is best-effort (checksums, command validation). Documented limitation.

## 17. AI (Skirmish)

- Optional AI opponent for solo/skirmish and to replace dropped players.
- Difficulty levels (Easy/Normal/Hard) via economy/scouting/micro bonuses.
- Behavior: expand, build army, attack weakest, respond to threats. Not required for "playable" multiplayer but included in roadmap.

## 18. Audio & Visual

- **Style:** Stylized low-poly / clean silhouettes, team colors, readable at zoom-out.
- **VFX:** Muzzle flashes, explosions, nuke mushroom, laser beam, cloak shimmer.
- **Audio:** Per-weapon SFX, ambient map audio, UI clicks, alerts, voice barks (robotic).
- **Music:** Menu + in-match (adaptive intensity).

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

P2P cannot fully prevent cheating. v1 mitigations: deterministic lockstep + checksums, command validation, host can kick. Documented as known limitation; ranked play deferred.

## 22. Data & Save Formats

- **Maps:** `.bwm` (Godot Resource or JSON) with version field and migration.
- **Replays:** recorded command streams + initial map seed; deterministic playback.
- **Settings:** `user://settings.cfg`.
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

The repository now contains a playable single-player skirmish vertical slice plus extensive core systems. Implemented:

- Project bootstrap, autoloads, 4 corporations with colors/modifiers.
- Core systems: damage, economy, map data, command serialization, unit/building stats, production queues, placement, vision/stealth/EMP/cover/repair, tech, fog of war, lockstep helpers, game state/replay/save settings, pathfinding, AI heuristics, strategic weapons, formation, alliances, scoring, power, resource deposits.
- Gameplay: 128×128 map, units across infantry/armor/naval/air, buildings (HQ, barracks, factory, airfield, shipyard, extractor, farm, power, lab, radar, turret, silo, orbital uplink), combat with VFX/tracers, economy, tech progression, orbital laser and nuclear strikes, fog of war rendering, skirmish AI, audio stubs.
- Verification: GUT unit/fuzz/regression suites and `make ci` gate.

Outstanding gaps (see `docs/roadmap.md`):

- Multiplayer P2P match integration (lobby → game).
- Terrain rendering and map editor UI.
- Full naval roster (ballistic missile submarine, landing craft).
- Audio content (music/SFX) beyond stubs.
- Additional polish/performance passes.

---
*End of design document.*
