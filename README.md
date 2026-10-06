# Soccer War

A 2D top-down soccer game built with **Godot 4.7**, targeting **HTML5 / web** export.
Play offline, or online with friends: 3v3 up to 4v4, joined by room code, 5-minute matches.

## Requirements

- [Godot 4.7.2](https://godotengine.org/download) (standard build, not .NET), on your `PATH` as `godot`
- Web export templates — in the editor: **Editor → Manage Export Templates → Download and Install**
- Python 3 (only for the local web server script)

## Running in the editor

1. Open Godot, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** to run. `scenes/boot.tscn` opens the menu.

## Controls

| Action | Keys |
|--------|------|
| Move   | `WASD` or arrow keys |
| Sprint | `Shift` |
| Kick   | `Space` |
| Menu   | `Esc` |

## Exporting for web

The `Web` preset is already configured in `export_presets.cfg` and outputs to `export/index.html`.

From the editor: **Project → Export → Web → Export Project**, or from the CLI:

```bash
godot --headless --export-release "Web" export/index.html
```

## Testing the web build locally

You cannot just open `export/index.html` from the filesystem — browsers block it, and
Godot's threaded web build also requires the page to be *cross-origin isolated*
(`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`). `serve.py` sets those
headers, which a plain `python3 -m http.server` does not:

```bash
python3 serve.py          # serves ./export at http://127.0.0.1:8060
python3 serve.py 9000     # custom port
```

If you deploy elsewhere, that host must send the same two headers, or disable
`variant/thread_support` in the export preset.

## Online multiplayer

The server is the same Godot project run headless. It owns the whole simulation
(players, ball, goals, clock); browsers only send key presses and draw what the
server sends back.

```
Browser (Vercel) ──wss──▶ Game server (Render, headless Godot)
```

### Play online locally

```bash
godot --headless -- --server   # game server on ws://127.0.0.1:9080 (or $PORT)
tools/build-web.sh             # export the web build
python3 serve.py               # http://127.0.0.1:8060
```

Open several tabs: one clicks **Create room** and shares the 4-letter code, the
others **Join** with it, pick a team, and the host presses **Start match**.

A page can target another server with `?server=wss://host.example.com`.

### Latency

- The local player is predicted: it moves the moment a key is pressed and is
  corrected smoothly when the server disagrees.
- Other players and the ball are drawn ~66 ms behind the newest server snapshot,
  interpolated, so they move smoothly.
- The server simulates at 60 Hz and sends 30 binary snapshots per second.

### Deploy

**Game server → Render** (Docker, free plan, Singapore):
1. Push the repo to GitHub and create a Render *Blueprint* from it (`render.yaml`),
   or a Web Service with runtime *Docker*.
2. Copy the service URL, e.g. `soccer-war-server.onrender.com`, and set
   `PRODUCTION_URL` in `scripts/net/protocol.gd` to `wss://soccer-war-server.onrender.com`.

The free plan sleeps after 15 idle minutes; the first player then waits about a minute.

**Web client → Vercel:** the web build in `export/` is committed. Connect the
repo to a Vercel project; on every push to `main` Vercel serves `export/` as-is
(`vercel.json`: no build step, COOP/COEP headers for the threaded web build).
Run `tools/build-web.sh` before each commit that changes the game (see `CLAUDE.md`).

## Testing

```bash
tools/test.sh          # unit + in-process WebSocket server tests (headless)
tools/test.sh roster   # only suites whose file name contains "roster"
tools/e2e.sh           # real server + two bots through menu, lobby and a match
```

## Project structure

```
soccer-war/
├── project.godot          # gl_compatibility renderer, input map, autoload Net
├── export_presets.cfg     # Web export preset → export/index.html
├── serve.py               # local static server with COOP/COEP headers
├── Dockerfile, render.yaml  # game server image for Render
├── vercel.json            # Vercel: serve export/ with COOP/COEP headers
├── CLAUDE.md              # project rules (rebuild export/ before committing)
├── scenes/
│   ├── boot.tscn          # --server → server.tscn, else menu.tscn
│   ├── menu.tscn, lobby.tscn
│   ├── main.tscn          # match: field, pitch, players, ball, HUD
│   ├── pitch.tscn         # walls and goal nets (collision only)
│   ├── server.tscn        # dedicated server root
│   ├── player.tscn, ball.tscn
├── scripts/
│   ├── main.gd            # match scene: offline play, online prediction/interpolation
│   ├── player.gd, ball.gd
│   ├── game/              # roster (teams, host), match_rules (goals, kickoff, clock)
│   ├── net/               # Net autoload, protocol, snapshot buffer, input queue, predictor
│   ├── server/            # game_server (rooms by code), room (one match world)
│   └── ui/                # menu, lobby
├── tests/                 # headless test suites + runner
└── tools/                 # test.sh, e2e.sh, build-web.sh
```

## Implementation notes

- **Renderer is `gl_compatibility`.** Forward+ and Mobile do not work in browsers; this is
  required for web export.
- **Gravity is `0`.** The pitch is viewed top-down, so nothing should fall.
- **The ball is a `CharacterBody2D`, not a `RigidBody2D`,** so motion stays deterministic
  and easy to tune for arcade feel. Drag and bounce are hand-rolled in `ball.gd`.
- **Collision layers:** `1` = walls, `2` = player, `4` = ball.
- Each server room is a `SubViewport` with its own `World2D`, so rooms never share physics.

## Not yet implemented

Bots, matchmaking, accounts, chat, ball prediction, and sound.
