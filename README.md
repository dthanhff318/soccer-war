# Soccer War

A 2D top-down soccer game built with **Godot 4.3**, targeting **HTML5 / web** export.

## Requirements

- [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET)
- Web export templates — in the editor: **Editor → Manage Export Templates → Download and Install**
- Python 3 (only for the local web server script)

## Running in the editor

1. Open Godot, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** to run. `scenes/main.tscn` is the main scene.

## Controls

| Action | Keys |
|--------|------|
| Move   | `WASD` or arrow keys |
| Kick   | `Space` |

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

## Project structure

```
soccer-war/
├── project.godot          # engine config: gl_compatibility renderer, input map, zero gravity
├── export_presets.cfg     # Web export preset → export/index.html
├── serve.py               # local server with COOP/COEP headers
├── icon.svg
├── scenes/
│   ├── main.tscn          # pitch, walls, goals, score UI
│   ├── player.tscn
│   └── ball.tscn
├── scripts/
│   ├── main.gd            # score tracking, goal detection, ball reset
│   ├── player.gd          # top-down movement + kicking
│   └── ball.gd            # linear drag, wall bounce
├── assets/                # sprites, audio (empty for now)
└── export/                # build output (gitignored)
```

## Implementation notes

- **Renderer is `gl_compatibility`.** Forward+ and Mobile do not work in browsers; this is
  required for web export.
- **Gravity is `0`.** The pitch is viewed top-down, so nothing should fall.
- **The ball is a `CharacterBody2D`, not a `RigidBody2D`,** so motion stays deterministic
  and easy to tune for arcade feel. Drag and bounce are hand-rolled in `ball.gd`.
- **Collision layers:** `1` = walls, `2` = player, `4` = ball.
- Placeholder art is `Polygon2D` rectangles, so the project runs with no image assets.

## Not yet implemented

Opponent AI, a second player, match timer, kickoff/reset flow, sound, and real art.
