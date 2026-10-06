# Soccer War — project rules

## Web build is committed (Vercel serves `export/` straight from git)

- **MUST run `tools/build-web.sh` before every commit** that changes anything the
  game ships: `scripts/`, `scenes/`, `assets/`, `project.godot`, `export_presets.cfg`.
- **MUST stage the rebuilt `export/` in the same commit** as the code change
  (`git add export/`), so the deployed site always matches the code.
- Never commit `export/.vercel/`, `export/.env*` or `export/*.import`; `.gitignore`
  excludes them — do not force-add them.
- Pushing `main` deploys both sides: Vercel serves `export/` (see `vercel.json`),
  Render rebuilds the game server from `Dockerfile`.

## Before committing

1. `tools/test.sh` — must report 0 failures.
2. `tools/e2e.sh` — when networking, lobby or match code changed.
3. `tools/build-web.sh`, then `git add export/` along with the change.

## Server URL

`Protocol.PRODUCTION_URL` (`scripts/net/protocol.gd`) is the Render server,
`wss://soccer-war.onrender.com`. Changing it requires a rebuild like any other
code change.
