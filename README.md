# BroWarz

**Real-time networked peer-to-peer strategy game — Godot 4.7.2**

BroWarz is a combined-arms RTS set in 2030 where rival corporations fight for control of oil, iron, geothermal, and food. Command infantry robots, sappers, stealth units, tanks, mechanized infantry, sea drones, submarines, aerial drones, orbital lasers, nuclear missiles, and large killer robots across a 128×128 battlefield. Maps vary with swamps, rivers, seas, and more — and players can build their own.

## Status

Pre-production / design phase. See [`docs/design.md`](docs/design.md) for the game design document and [`docs/roadmap.md`](docs/roadmap.md) for the 20-part roadmap to a playable version.

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

## Development

Common targets (see `make help`):

- `make test` — run full GUT test suite
- `make lint` — lint Python + GDScript
- `make ci` — full verification gate
- `make build-web` — export web build

## Project Layout

- `docs/` — design document and roadmap
- `scenes/`, `scripts/`, `resources/`, `assets/` — game content (created per roadmap)
- `tests/` — GUT unit/integration/fuzz/regression tests
- `addons/` — Godot addons (GUT)

## Networking

Peer-to-peer via Godot's HighLevelMultiplayerAPI (ENet on desktop, WebRTC on web). See design doc §16.

## License

Public domain (Unlicense). See [LICENSE](LICENSE).
