# BroWarz — Diplomacy

BroWarz treats alliances as **temporary, in-match sides**, not permanent faction relationships. The four corporations remain weapons divisions of the same megacorp; a match is the negotiation that redraws their resource borders. See [`corporations.md`](corporations.md) for the lore and [`design.md`](design.md) for the simulation rules.

Alliance state is a graph of team ids. Two teams on the same connected component form one **side** for fog of war, targeting, AI, strategic weapons and victory scoring. Resources, factories, tech and unit control always stay with the original team.

## Availability

| Match type | Diplomacy |
|---|---|
| Single player vs AI | Off; the human and AI sides are fixed at match start. |
| Co-op vs AI (two humans, one AI) | Off; both humans are permanently on team 0 and the AI is team 1. |
| AI vs AI spectator | Off; two host-driven AI sides are fixed at match start and the player has no command authority. |
| Multiplayer, 2 teams | Off; there is no third side to negotiate with. |
| Multiplayer, 3–4 teams | On; the **Diplomacy** HUD button opens the panel. |

Lobby setting `alliance_mode` selects the opening arrangement:

- `0` (default) — free-for-all; no allied links.
- `1` — paired sides for four teams: `{0: [0, 2], 1: [1, 3]}`.

The lobby graph is normalized into symmetric adjacency before the match starts, so both peers on a side see identical combat and fog behavior.

## States

For any pair of teams, the panel shows one of four states:

1. **Neutral** — no alliance and no pending request. The only available action is **Propose Alliance**.
2. **Request sent** — your team has offered an alliance to the target. You may **Cancel Request**.
3. **Request received** — the target team has offered an alliance to you. You may **Accept** or **Decline**.
4. **Allied** — the teams belong to the same side. You may **Break** the alliance.

A team cannot propose to itself or to a team it is already allied with. Duplicate proposals are ignored.

## Actions

| Action | Authorized sender | Effect |
|---|---|---|
| `propose` | Any team in a neutral pair | Creates a one-way `"from>to"` proposal. It takes no effect until the target team accepts. |
| `cancel` | Original proposing team | Removes that team's outbound proposal. |
| `decline` | Target of a proposal | Removes the inbound proposal. |
| `accept` | Target of a proposal | Merges both connected sides into one symmetric alliance side, then clears stale proposals between the merged teams. |
| `break` | Any team on one of the two sides | Removes every link between the two sides. If both teams were already on the same side, the entire side dissolves. |

Accepting is transitive: if team 0 is allied with team 2 and team 2 accepts team 3, teams 0, 2 and 3 all become one side. Breaking is also side-wide: a break between any two teams on that side removes the side's links. Break changes only the alliance graph; it does not create or remove proposals. Use **Cancel Request** or **Decline** for those.

## Effects on the match

`GameManager.is_allied(a, b)` is the single query used by live systems:

- **Fog of war:** allied teams share explored and currently visible tiles. The explored overlay uses `alpha 0.55`; unexplored tiles stay fully opaque.
- **Targeting:** units, buildings and the AI skip allied units and structures. Capture and demolish commands reject allied buildings.
- **Weapons:** orbital lasers and nuclear strikes exclude allied units and buildings from their damage area.
- **Repairs:** Sapperbots and other repair-capable workers repair allied units and buildings.
- **Deposits:** a depleted resource deposit reports its status to allied teams.
- **Victory:** side membership is computed from the connected alliance graph, so a newly accepted alliance immediately changes which teams count as enemies.

Alliances never transfer resources, tech, production queues, unit selection or command authority. There is no trade, no shared treasury, no team chat and no corporation-specific diplomacy bonus.

## Host-authoritative command path

The panel never edits alliance state locally. Every button calls `NetworkManager.send_command()` with:

```json
{
  "type": "diplomacy",
  "team": 0,
  "action": "propose",
  "target_team": 2
}
```

The host then:

1. Applies `NetSecurity` whitelisting and command sanitization (`action` must be one of `propose`, `cancel`, `decline`, `accept`, `break`; `target_team` must be `0..7`).
2. Applies the token-bucket rate limiter and per-peer monotonic sequence guard.
3. Overwrites `team` from the host's lobby seat record for the sending peer, so a forged payload cannot propose or accept on another team's behalf.
4. Calls `GameManager.apply_diplomacy(team, action, target_team)`, which checks team existence and the transition rules above.
5. Relays the validated command to every peer. Clients only apply relayed commands from the host.

In single-player mode commands are applied immediately, but the diplomacy panel is not exposed there.

## Persistence and replays

Match saves store `teams`, `alliances` and `alliance_proposals` in the save settings. JSON turns integer keys into strings and floats; `Alliance.normalize()` and `Alliance.clean_proposals()` restore integer team ids, symmetric sides and well-formed proposal keys on load.

Replays record the action as `Command.Type.DIPLOMACY`, with the action string in `build_type` and the target team in `target_id`. The replay viewer renders it as `DIPLOMACY <action> team <id>`.

## Functions

### Core (`scripts/core/alliance.gd`)

| Function | Purpose |
|---|---|
| `Alliance.team_id(raw)` | Parse an integer or JSON team id; reject anything outside `0..7`. |
| `Alliance.neighbors(graph, team)` | Direct adjacent teams, following both keys and values. |
| `Alliance.members(graph, team)` | Every team connected to `team`, including `team`, sorted. |
| `Alliance.are_allied_teams(graph, a, b)` | True for same side, including transitivity. |
| `Alliance.normalize(raw)` | Convert lobby/save data into symmetric alliance sides. |
| `Alliance.proposal_key(from, to)` | Stable `"from>to"` proposal key. |
| `Alliance.set_proposal`, `has_proposal`, `cancel_proposal` | Proposal lifecycle helpers. |
| `Alliance.clear_proposals_between` | Drop stale offers after two sides merge. |
| `Alliance.clean_proposals(raw, teams)` | Reject malformed or out-of-match loaded keys. |
| `Alliance.form(graph, a, b)` | Merge two sides. |
| `Alliance.split(graph, a, b)` | Break links between two sides, or dissolve one side. |

### Match state (`scripts/autoload/game_manager.gd`)

| Function | Purpose |
|---|---|
| `GameManager.set_diplomacy_state(graph, proposals, teams)` | Install normalized graph/proposals for lobby staging, quickload and tests. |
| `GameManager.apply_diplomacy(team, action, target_team)` | Host-side transition validator and mutator. |
| `GameManager.is_allied(a, b)` | Live query used by gameplay and UI. |
| `GameManager.clear_match_state()` | Clears both graph and proposals between matches. |

### UI (`scripts/ui/diplomacy_dialog.gd`)

`DiplomacyDialog.refresh()` rebuilds one row per other team from the authoritative state, and `DiplomacyDialog._send(action, target)` routes the button press through `NetworkManager`. The panel polls for state changes only while visible; no row mutates `GameManager.alliances` directly.

## Known limitations

- No negotiation chat: offers are binary accept/decline with no counter-offers or treaties.
- No per-team diplomatic reputation, treachery penalty or cooldown beyond normal command rate limits.
- A modified client can still send legal actions for its own seat; full server-side authority is out of scope for P2P (see [`design.md`](design.md) §21).
