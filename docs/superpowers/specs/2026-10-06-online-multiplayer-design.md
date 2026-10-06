# Online Multiplayer — Design

Date: 2026-10-06
Status: approved in chat

## Goal

Friends play Soccer War together in the browser: 3v3 up to 4v4, joined by room
code, 5-minute timed matches, with the lowest practical input latency.

## Decisions

| Topic | Decision |
|---|---|
| Players | Up to 4 per team, 8 per room. Uneven teams allowed, no bots. |
| Joining | Host creates a room → 4-char code → others join → pick team → host presses Start. |
| Match | 5:00 clock on the scoreboard. Most goals wins, draws allowed. Result shown ~5 s, then back to lobby. |
| Authority | Dedicated server owns all simulation (players, ball, goals, clock). Clients send inputs only. |
| Transport | Godot high-level multiplayer over `WebSocketMultiplayerPeer`. Render terminates TLS, so clients use `wss://`. |
| Hosting | Web client on Vercel (static `export/`). Game server on Render (free tier first) via Docker. |
| Codebase | One Godot project. `godot --headless -- --server` runs the server. |
| Out of scope | Bots, matchmaking, accounts, chat, ball prediction, WebRTC. |

## Architecture

```
Browser (Vercel) ──wss──▶ Game server (Render, headless Godot)
  Menu → Lobby → Match                GameServer
  Net autoload (client role)          ├─ Net autoload (server role)
  local player: predicted             └─ Room (SubViewport, own World2D) × N
  others + ball: interpolated              ├─ Pitch (walls, nets)
                                           ├─ Players
                                           └─ Ball
```

Each room is a `SubViewport` with its own `World2D`, so rooms never share
physics. Rendering is disabled on the server; it never loads the field
texture (`pitch.tscn` holds only collision geometry).

## Units

| File | Responsibility |
|---|---|
| `scripts/boot.gd` | Entry scene. `--server` → server scene; `--smoke-client` → headless smoke test; else menu. |
| `scripts/net/net.gd` (autoload `Net`) | Connect/listen, every RPC endpoint, emits signals. No game logic. |
| `scripts/net/protocol.gd` | Constants, input bit packing, snapshot encode/decode (binary). Pure, tested. |
| `scripts/net/snapshot_buffer.gd` | Stores snapshots by tick, samples interpolated state at a render tick. Pure, tested. |
| `scripts/net/input_queue.gd` | Server-side per-player input queue with catch-up policy. Pure, tested. |
| `scripts/game/roster.gd` | Room membership: names, teams, host, capacity rules. Pure, tested. |
| `scripts/game/match_rules.gd` | Goal detection, kickoff positions, clock formatting. Pure, tested. |
| `scripts/server/game_server.gd` | Room codes, routes Net requests to rooms, cleans up empty rooms. |
| `scripts/server/room.gd` | Lobby/match state machine, fixed-step simulation, snapshot broadcast. |
| `scripts/main.gd` (match scene) | Client view for offline and online play: spawns players, applies snapshots, prediction. |
| `scripts/net/predictor.gd` | Client prediction + reconciliation for the local player. |
| `scripts/ui/menu.gd`, `scripts/ui/lobby.gd` | Menu and lobby screens. |

`player.gd` stops reading `Input` itself; it exposes
`simulate(input_bits, delta)` and `get_state()/set_state()`. `ball.gd` gains a
`simulated` flag so clients can drive it from snapshots.

## Netcode

- **Tick rate:** physics 60 Hz on server and client.
- **Input (client → server):** every physics frame, `c_input(seq, bits)`.
  `bits` = left/right/up/down/sprint/kick in one byte; the movement vector is
  rebuilt identically on both sides. Kick is set only on the press frame.
- **Server input queue:** one input consumed per player per tick. If the queue
  is empty, the last movement repeats (without kick). If it holds more than 3,
  two are consumed that tick to catch up.
- **Snapshots (server → room peers):** 30 Hz, binary `PackedByteArray`:
  tick, phase, scores, time left, ball (pos, vel), and per player
  (id, pos, vel, stamina, exhausted, last processed input seq).
- **Remote players + ball:** rendered ~2 snapshot intervals (~66 ms) in the
  past, interpolated between bracketing snapshots. Render tick follows the
  newest server tick smoothly.
- **Local player:** predicted. Each frame the input is applied locally and kept
  in a history. On snapshot: reset to the server state at `last_seq`, replay
  newer inputs. Small corrections are hidden by decaying the sprite offset;
  large ones (>48 px) snap.
- **Reliable events:** room state, match start, goal, match end, errors,
  ping/pong (ping shown in the HUD).

## Room lifecycle

`LOBBY → PLAYING → ENDED (5 s) → LOBBY`

- Join is refused when the code is unknown, the room is full, or a match is
  running — the client shows the reason.
- New joiners go to the smaller team. Team switch is refused if that team has 4.
- Start requires the host and at least one player on each team.
- Kickoff: players placed by team formation (1–4 slots), ball at centre.
  After a goal: 2.5 s celebration, then kickoff reset. The clock keeps running.
- Disconnect: the player is removed; host passes to the oldest remaining
  member; an empty room is deleted.
- Client loses connection → back to menu with a message.

## Configuration

- Server port: `$PORT` env, default `9080`.
- Client server URL: `?server=` query param, else `Protocol.PRODUCTION_URL`
  on a non-localhost page, else `ws://127.0.0.1:9080`.

## Deployment

- **Vercel:** `web/vercel.json` (COOP/COEP headers) is copied into `export/`
  by `tools/build-web.sh`; `export/` is deployed as a static site.
- **Render:** `Dockerfile` installs Godot 4.7.2 Linux, imports the project,
  runs `godot --headless -- --server`. The field texture is excluded from the
  image.

## Testing

- `godot --headless -s tests/run_tests.gd` runs unit tests for protocol,
  snapshot buffer, input queue, roster and match rules (no external libs).
- Smoke test: start the server, then `godot --headless -- --smoke-client`
  creates a room, starts a match, and exits 0 once snapshots arrive.
- Manual: server on the Mac, 4–8 browser tabs.
