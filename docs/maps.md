# BroWarz — Maps

## Map Size
- Grid: 128 × 128 tiles.
- Tile size: 16 world units (2048 × 2048 world).
- Movement: units move on a hex grid overlaid on the tile map.

## Built-in Maps

### Desert
- No water (no rivers or seas).
- Plains, roads, occasional mountains.
- Land units move freely; naval units cannot operate.

### Island Chain
- Sea base with random islands.
- Naval units dominate; land units only on islands.
- Mountains on larger islands.

### Forest
- Mix of plains, forest, swamp, mountains, and a winding river.
- Rivers block most land units (except hovercraft and frogmen).
- Swamps slow infantry and block vehicles.

## Terrain & Passability

| Terrain | Infantry | Vehicle/Mech | Naval | Air | Hovercraft | Frogman |
|---|---|---|---|---|---|---|
| Plains | Yes | Yes | No | Yes | Yes | Yes |
| Forest | Yes (slow) | Slow | No | Yes | Yes (slow) | Yes (slow) |
| Swamp | Yes (slow) | No | No | Yes | Yes (slow) | Yes (slow) |
| River | No | No | Yes | Yes | Yes | Yes |
| Sea | No | No | Yes | Yes | Yes | Yes |
| Mountain | Heavy only | Heavy mech only | No | Yes | No | No |
| Urban | Yes | Yes | No | Yes | Yes | Yes |
| Road | Yes | Yes | No | Yes | Yes | Yes |
| Wasteland | Slow | No | No | Yes | No | No |

## Map Generation Methodology
- `TerrainGenerator` uses seeded `RandomNumberGenerator` for determinism.
- Desert: mostly plains with sparse mountains and roads.
- Islands: sea base with randomly placed circular islands and mountains.
- Forest: mixed biomes plus a meandering river.

## Custom Maps
- Map editor allows painting terrain and saving to `user://custom_map.bwm`.
- `MapSerializer` validates dimensions and tile counts.
- Shared via file export/import.

## Movement
- All units move on a hex grid (pointy-topped, size 16).
- Hex pathfinding respects terrain passability and unit class.
