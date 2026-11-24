# BroWarz

![BroWarz Logo](assets/logo.png)

**Retro-future corporate dystopia RTS — Godot 4.7.2**
*Megacorp warfare, 2030.*

BroWarz is a combined-arms RTS set in 2030 where four rival megacorporations (**AeroDyne Industries**, **FerroCore Heavy**, **Pelagic Systems**, and **Vanguard Robotics**) fight for control of **Oil**, **Iron**, **Geothermal**, and **Food**. Command infantry robots, sappers, stealth units, advanced construction bots, tanks, mechanized walkers, sea drones, submarines, frogbot commandos, aerial drones, orbital lasers, and strategic nuclear missiles across a 128×128 hex-pathfound battlefield. Play solo against a tactical Skirmish AI (Easy, Normal, Hard), design custom maps in the built-in Hex Map Editor with portable share codes, or battle over peer-to-peer multiplayer.

## Status

Playable v0.1.0 build with Single Player vs AI Skirmish mode, Hex Map Editor (`BWM1:` share codes & `.bwm` files), and P2P Multiplayer. See [`docs/design.md`](docs/design.md) for the game design document, [`docs/units.md`](docs/units.md) for unit visual rosters, [`docs/factories.md`](docs/factories.md) for tiered production buildings, [`docs/corporations.md`](docs/corporations.md) for faction lore, [`docs/maps.md`](docs/maps.md) for terrain/map editor details, and [`docs/roadmap.md`](docs/roadmap.md) for the 20-part roadmap.

---

## Unit & Combat Mechanics

Every unit mechanic in BroWarz is backed by deterministic core modules in `scripts/core/` and live scene logic in `scripts/game/unit.gd`, `scripts/game/building.gd`, and `scripts/game/game.gd`.

### 1. Damage Types vs. Armor Classes (`Damage`)

Combat damage combines base weapon damage, a **6 × 8 Damage-to-Armor multiplier matrix**, terrain cover reduction, and specialized unit role multipliers:

$$\text{Final Damage} = \text{Base Damage} \times M(\text{DamageType}, \text{ArmorClass}) \times (1 - \text{ArmorReduction}) \times \text{CoverMod} \times \text{RoleMod}$$

| Damage Type | Unarmored | Light | Medium | Heavy | Structure | Naval | Air | Submerged |
|---|---|---|---|---|---|---|---|---|
| **Kinetic** | `1.2×` | `1.0×` | `0.8×` | `0.5×` | `0.6×` | `0.7×` | `0.3×` | `0.0×` |
| **Explosive** | `1.5×` | `1.2×` | `1.0×` | `0.8×` | `1.3×` | `1.1×` | `0.6×` | `0.2×` |
| **Energy** | `1.0×` | `1.0×` | `1.0×` | `1.0×` | `1.2×` | `1.0×` | `1.0×` | `0.5×` |
| **EMP** | `1.5×` | `1.2×` | `0.9×` | `0.5×` | `0.3×` | `0.8×` | `1.0×` | `0.6×` |
| **Thermal** | `1.3×` | `1.1×` | `0.9×` | `0.7×` | `1.0×` | `1.0×` | `0.8×` | `0.4×` |
| **Toxic** | `1.4×` | `1.0×` | `0.6×` | `0.3×` | `0.2×` | `0.5×` | `0.9×` | `0.7×` |

- **Submerged Immunity:** Submerged submarines (`attack_sub`, `ballistic_sub`) take `0.0×` damage from standard **Kinetic** weapons; use **Explosive** depth charges/torpedoes, **Energy**, **EMP**, or **Frogbots** to destroy them.

### 2. Specialized Unit Role Mechanics

- **Sapperbot (`sapperbot`):** Deals **`2.5×` demolition bonus damage** against `STRUCTURE` armor and constructs defensive fortifications:
  - **Barrier Wall (`wall`):** 900 HP; blocks movement of all ground units (infantry, vehicles, mechs).
  - **Barbed Wire (`barbed_wire`):** 150 HP; blocks infantry (`0`) and heavy infantry (`6`) while allowing armored vehicles to crush/pass.
  - **Missile Tower (`missile_tower`):** 600 HP dedicated anti-air static defense (`320 px` range, `42` Explosive damage against `AIR` units).
- **Frogbot (`frogbot`):** Amphibious stealth demolition commando (traverses land and water, faster in water at `1.0` move cost vs `1.2` on plains). Cloaked until attacking and deals **`2.2×` bonus damage** against `NAVAL` capital ships, `SUBMERGED` submarines, and coastal `STRUCTURE` targets.
- **Anti-Air Vehicle (`aa_vehicle`):** Quad-flak mobile air defense dealing **`3.0×` bonus damage** against `AIR` targets.
- **Rocketbot (`rocketbot`):** Shaped-charge anti-armor infantry dealing **`1.5×` bonus damage** against `MEDIUM` and `HEAVY` armor.
- **Sniperbot (`sniperbot`):** Long-range precision unit (`340 px` range, `380 px` sight) dealing **`1.5×` bonus damage** against `UNARMORED` and `LIGHT` infantry/bots.
- **Attack Submarine (`attack_sub`):** Stealth-capable subsurface hunter dealing **`1.8×` torpedo bonus damage** against `NAVAL` and `SUBMERGED` hulls.
- **Siege Mech (`siege_mech`) & Artillery (`artillery`):** Long-range bombardment units (`420–450 px` range) dealing **`1.6×` bonus damage** against `STRUCTURE` targets.
- **Medicbot (`medicbot`) & Engineer Bots (`engineerbot`, `adv_engineerbot`):** Automatically repair damaged friendly robots within `100 px` (`12 HP/s` for Medicbot/Engineerbot, `18 HP/s` for Advanced Construction Bot). Engineer bots also auto-repair damaged friendly buildings within `110 px`.
- **Advanced Construction Bot (`adv_engineerbot`):** Produced at **Mech Factory 2 (`mech_factory_2`)**. Required to construct Tier-3 apex production facilities: **Mech Factory 3 (`mech_factory_3`)**, **Advanced Shipyard (`advanced_shipyard`)**, and **Aeries Level 2 (`aeries_2`)**.
- **AWACS Radar Drone (`awacs`) & Scout Drone (`scout_drone`):** Provide long-range radar detection that reveals cloaked enemy units across their entire sight radius (`540 px` and `460 px`). AWACS fires **EMP** bursts that disable enemy units (`3.75s` disable on Unarmored/Light bots, `2.5s` on heavier hulls).
- **Eel-Prone Hovercraft (`hovercraft`):** High-speed amphibious transport/skirmisher (`160 px/s`) that crosses both land and sea (`PLAINS`, `DESERT`, `SWAMP`, `FOREST`, `RIVER`, `SEA`), but suffers a random **Eel Hazard** (`"My Hovercraft is full of eels!"`) that stalls propulsion for `5.0s`.

### 3. Stealth, Vision, Radar & EMP (`Stealth`, `Vision`, `EMP`)

- **Cloaking (`stealthbot`, `attack_sub`, `ballistic_sub`, `frogbot`):** Stealth units render semi-transparent (`42%` alpha) when cloaked. Firing a weapon immediately breaks cloak (`Stealth.break_on_action`); cloak recharges automatically when out of combat.
- **Detection (`Vision.stealth_detected`):** Cloaked units are invisible to standard enemies beyond **`35%` of the observer's sight range**, unless the observer has radar (`awacs`, `scout_drone`), which detects stealth units at **`100%` of sight range**.
- **EMP Disruption (`EMP`):** Units hit by `DamageType.EMP` are immobilized and unable to fire while `emp_timer > 0`. Unarmored and Light robotic units suffer a **`1.5×` longer disable duration**.

### 4. Terrain Movement, Hex Pathfinding & Cover (`MapData`, `Cover`, `HexGrid`)

Units navigate on a 16 px axial hex grid (`HexGrid`) that routes around impassable terrain and sapper fortifications (`GameManager.is_tile_blocked`):

| Unit Class | Plains / Road / Bridge | Desert | Hills (Cover `0.85×`) | Forest (Cover `0.80×`) | Urban (Cover `0.70×`) | Swamp | Mountain | River / Sea |
|---|---|---|---|---|---|---|---|---|
| **Infantry (`0`)** | `1.0` | `1.15` | `1.30` | `1.20` | `0.90` | `1.60` | Impassable | Impassable |
| **Heavy Infantry (`6`, `heavybot`)** | `1.0` | `1.15` | `1.30` | `1.20` | `0.90` | `1.60` | **`2.00` (Passable)** | Impassable |
| **Vehicle (`1`)** | `1.0` | `1.15` | `1.45` | `1.60` | `1.30` | Impassable | Impassable | Impassable |
| **Heavy / Siege Mech (`7`)** | `1.0` | `1.15` | `1.45` | `1.60` | `1.30` | Impassable | **`2.20` (Passable)** | Impassable |
| **Naval (`2`)** | Impassable | Impassable | Impassable | Impassable | Impassable | Impassable | Impassable | **`1.00`** |
| **Air (`3`)** | `1.0` | `1.00` | `1.00` | `1.00` | `1.00` | `1.00` | `1.00` | `1.00` |
| **Hovercraft (`4`)** | `1.0` | `1.00` | `1.40` | `1.30` | `1.00` | `1.30` | Impassable | **`1.10`** |
| **Frogbot (`5`)** | `1.2` | `1.20` | `1.35` | `1.40` | `1.10` | `1.50` | Impassable | **`1.00`** |

- **Defensive Cover (`Cover.modifier`):** Units standing in **Urban** (`0.70×` damage taken, `-30%`), **Forest** (`0.80×` damage taken, `-20%`), or **Hills** (`0.85×` damage taken, `-15%`) receive automatic incoming damage reduction.

### 5. Corporation Asymmetric Modifiers (`Faction`)

| Corporation | Active Gameplay Modifiers |
|---|---|
| **AeroDyne Industries** | `-10%` Air unit resource cost (`air_cost: 0.9`), `-15%` Orbital Laser cooldown (`orbital_cooldown: 0.85`) |
| **FerroCore Heavy** | `+10%` Tank max HP (`light_tank`, `mbt`, `heavy_tank`), `+25%` Sapper & Engineer movement speed |
| **Pelagic Systems** | `-10%` Naval/Amphibious unit resource cost (`sea_cost: 0.9`), Submarine stealth cloaking (`sub_cloak: true`) |
| **Vanguard Robotics** | `+20%` Stealth cloak duration (`12.0s` vs `10.0s`), `-10%` Infantry & Mech unit resource cost (`mech_cost: 0.9`) |

### 6. Tiered Factories & Production (`UnitRegistry`, `Production`)

See [`docs/factories.md`](docs/factories.md) for full details:

- **Headquarters (`hq`):** Command anchor; trains `engineerbot`.
- **Mech Factory 1 (`mech_factory_1`):** Trains small bots & light mechs (`riflebot`, `heavybot`, `sapperbot`, `stealthbot`, `sniperbot`, `rocketbot`, `medicbot`, `engineerbot`, `light_mech`, `light_tank`).
- **Mech Factory 2 (`mech_factory_2`):** Trains medium units (`apc`, `mbt`, `artillery`, `aa_vehicle`) and **Advanced Construction Bots (`adv_engineerbot`)**.
- **Mech Factory 3 (`mech_factory_3`):** **Constructible only by `adv_engineerbot`**; produces apex heavy armor and killer mechs (`heavy_tank`, `heavy_mech`, `siege_mech`).
- **Docks (`docks`), Shipyard (`shipyard`), Advanced Shipyard (`advanced_shipyard`):** Produce littoral craft & `frogbot` commandos (`docks`), warships & attack subs (`shipyard`), and capital ships (`battleship`, `aircraft_carrier`, `ballistic_sub` at `advanced_shipyard`, built by `adv_engineerbot`).
- **Aeries Level 1 (`aeries_1`) & Aeries Level 2 (`aeries_2`):** Aerial drone launchpads producing `scout_drone` & `fighter_drone` (`aeries_1`) and `bomber_drone` & `awacs` (`aeries_2`, built by `adv_engineerbot`).

### 7. Strategic Weapons & Ambient Wildlife (`Strategic`, `Wildlife`)

- **Orbital Laser Strike (`L`):** Deals `180 × (1 + Geothermal / 1000)` AOE energy damage in a `95 px` radius.
- **Strategic Nuclear Missile (`N`):** Deals `650` AOE explosive damage in a `180 px` blast radius and converts a `4`-tile radius of terrain into irradiated **Wasteland** (`MapData.Terrain.WASTELAND`), which is impassable to vehicles and hovercraft.
- **Ambient Wildlife (`Wildlife`):** Non-combatant **Birds**, **Deer**, **Dolphins**, and **Squid** roam their native biomes, flee at `2.35×` speed when chased by units or when weapons fire nearby, and can be killed by direct or AOE fire.

---

## Requirements

- Godot 4.7.2 (`godot --version`)
- (Optional) Python 3 for asset/coverage tooling
- (Optional) `gdtoolkit` for GDScript lint/format

## Getting Started

```sh
git clone git@github.com:23skdu/BroWarz.git
cd BroWarz
make check-godot
make deps          # install GUT test addon
make import        # import resources
make run           # launch the game
```

Open in editor: `make editor`

## Controls (In-Match)

- **WASD / Arrow Keys**: Pan camera
- **Left Click / Drag Box**: Select friendly units (`Shift` to add)
- **Right Click**: Move / Attack-Move in grid formation
- **1–7**: Train units (`1` Riflebot, `2` Rocketbot, `3` Stealthbot, `4` MBT, `5` AA Vehicle, `6` Fighter Drone, `7` Hovercraft)
- **B / V**: Build Resource Extractor (`B`) or Defense Turret (`V`)
- **T**: Upgrade Corporation Tech Tier (T1 → T4)
- **L**: Fire Orbital Laser Strike
- **N**: Launch Strategic Nuclear Missile
- **H**: Hold position

## Development

Common targets (see `make help`):

- `make test` — run full GUT test suite
- `make lint` — lint Python + GDScript
- `make ci` — full verification gate
- `make build-web` — export web build

## Project Layout

- `docs/` — design document, roadmap, corporations, units, factories, and maps
- `scenes/`, `scripts/`, `resources/`, `assets/` — game scenes, core logic, autoloads, and assets
- `tests/` — GUT unit/integration/fuzz/regression tests
- `addons/` — Godot addons (GUT)

## Networking

Peer-to-peer via Godot's HighLevelMultiplayerAPI (ENet on desktop, WebRTC on web) with deterministic lockstep command buffering and state checksums. See design doc §16.

## License

Public domain (Unlicense). See [LICENSE](LICENSE).
