# BroWarz

![BroWarz Logo](assets/logo.png)

**Real-time networked peer-to-peer strategy game — Godot 4.7.2**

BroWarz is a combined-arms RTS set in 2030 where rival corporations fight for control of oil, iron, geothermal, and food. Command infantry robots, sappers, stealth units, tanks, mechanized infantry, sea drones, submarines, aerial drones, orbital lasers, nuclear missiles, and large killer robots across a 128×128 battlefield. Play solo against a tactical Skirmish AI (Easy, Normal, Hard) or over peer-to-peer multiplayer.

## Status

Playable v0.1.0 build with Single Player vs AI Skirmish mode and P2P Multiplayer. See [`docs/design.md`](docs/design.md) for the game design document and [`docs/roadmap.md`](docs/roadmap.md) for the 20-part roadmap.

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
- **1–6**: Train units (`1` Riflebot, `2` Rocketbot, `3` Stealthbot, `4` MBT, `5` AA Vehicle, `6` Fighter Drone)
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

- `docs/` — design document, roadmap, corporations, and units
- `scenes/`, `scripts/`, `resources/`, `assets/` — game scenes, core logic, autoloads, and assets
- `tests/` — GUT unit/integration/fuzz/regression tests
- `addons/` — Godot addons (GUT)

## Networking

Peer-to-peer via Godot's HighLevelMultiplayerAPI (ENet on desktop, WebRTC on web) with deterministic lockstep command buffering and state checksums. See design doc §16.

## License

Public domain (Unlicense). See [LICENSE](LICENSE).
