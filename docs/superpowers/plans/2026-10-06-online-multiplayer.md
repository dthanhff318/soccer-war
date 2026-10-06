# Online Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Room-code online play for 3v3–4v4 with a server-authoritative Godot server, client prediction for the local player and interpolation for everything else.

**Architecture:** One Godot project. `godot --headless -- --server` runs `GameServer`, which hosts rooms as `SubViewport`s with their own `World2D`. Browsers connect over WebSocket through the `Net` autoload, send input bits at 60 Hz and receive 30 Hz binary snapshots.

**Tech Stack:** Godot 4.7.2 (GDScript), `WebSocketMultiplayerPeer`, `SceneMultiplayer` RPCs, Vercel (static web), Render (Docker).

**Spec:** `docs/superpowers/specs/2026-10-06-online-multiplayer-design.md`

## Global Constraints

- Godot 4.7.2, GL Compatibility renderer, web export preset `Web` → `export/index.html`.
- No new third-party dependencies (tests use a ~60-line in-repo runner).
- Server port `$PORT`, default `9080`. Physics/tick rate 60 Hz, snapshots 30 Hz.
- Max 4 players per team, 8 per room; room code 4 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- Match 300 s, celebration 2.5 s, result screen 5 s.
- The server must never load `assets/field/field.png` (10000×7499).
- Commit messages: `type(scope): description`, no tool/assistant references, no co-author lines.

## Review Focus

1. Player disconnects mid-match → their body disappears for others, the match continues, host passes on. (Task 5 integration test: guest leaves.)
2. Joining with a lowercase/padded code or a padded name → accepted and normalized. (Task 5 test.)
3. Joining a room that is mid-match or unknown → clear error, client stays on menu. (Task 5 test.)
4. Kickoff teleport after a goal → local player snaps instead of sliding across the pitch. (Task 3 predictor test: large correction snaps.)
5. Packets arriving late or in bursts → server consumes backlog two per tick and repeats last movement when empty. (Task 3 input queue tests.)

---

### Task 1: Test runner + Protocol

**Files:**
- Create: `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_protocol.gd`, `scripts/net/protocol.gd`, `export/.gdignore`
- Modify: `.gitignore` (keep `export/.gdignore`)

**Interfaces — Produces:**
- `TestCase` (Node): `check(cond, msg)`, `check_eq(actual, expected, msg)`, `check_near(a, b, tol, msg)`, static `failures`.
- `Protocol`: consts `DEFAULT_PORT`, `LOCAL_URL`, `PRODUCTION_URL`, `TICK_RATE`, `SNAPSHOT_RATE`, `enum Phase {LOBBY, PLAYING, CELEBRATING, ENDED}`, `IN_LEFT/RIGHT/UP/DOWN/SPRINT/KICK`, `INPUT_MASK`, `CODE_ALPHABET`, `CODE_LENGTH`;
  `static input_vector(bits) -> Vector2`, `static keyboard_bits(kick: bool) -> int`,
  `static make_code(rng, taken: Dictionary) -> String`,
  `static encode_snapshot(snap: Dictionary) -> PackedByteArray`, `static decode_snapshot(bytes) -> Dictionary`.
- Snapshot dict: `{tick, phase, score_left, score_right, time_left, ball_pos, ball_vel, players: {id: {pos, vel, stamina, regen, exhausted, last_seq}}}`.

- [ ] Write `tests/test_case.gd`, `tests/run_tests.gd` (runs `tests/test_*.gd`, optional name filter arg, exit 1 on failure).
- [ ] Write `tests/test_protocol.gd`: input_vector (each direction, diagonal length 1, opposites cancel), make_code (length, alphabet, skips taken), snapshot round-trip with two players.
- [ ] Run `godot --headless -s tests/run_tests.gd` → FAIL (Protocol missing).
- [ ] Implement `scripts/net/protocol.gd`.
- [ ] Run → PASS. Add `export/.gdignore` so Godot stops importing exported files.
- [ ] Commit `test(net): add headless test runner and wire protocol`.

### Task 2: Roster + MatchRules

**Files:** Create `scripts/game/roster.gd`, `scripts/game/match_rules.gd`, `tests/test_roster.gd`, `tests/test_match_rules.gd`.

**Interfaces — Produces:**
- `Roster`: `enum Team {LEFT, RIGHT}`, `MAX_PER_TEAM=4`, `MAX_NAME_LENGTH=12`, `host_id`; `static clean_name(raw)`, `add(id, name) -> String` (error or ""), `remove(id)`, `set_team(id, team) -> String`, `can_start(requester) -> String`, `has`, `size`, `is_empty`, `count(team)`, `team_of(id)`, `ids() -> Array[int]`, `ids_in_team(team) -> Array[int]`, `to_dict() -> {host_id, players:[{id,name,team}]}`.
- `MatchRules`: `GOAL_LINE_LEFT/RIGHT`, `GOAL_MOUTH_TOP/BOTTOM`, `CENTER`, `MATCH_SECONDS`, `CELEBRATION_SECONDS`, `RESULT_SECONDS`, `TEAM_COLORS`, `TEAM_NAMES`; `static scoring_team(ball_pos, radius) -> int` (-1 none), `static kickoff_positions(team, count) -> Array[Vector2]`, `static format_clock(seconds) -> String`, `static result_text(left, right) -> String`.

- [ ] Tests: roster balancing, full room (9th refused), team full, host transfer on remove, start rules, name cleaning; goal detection (inside/outside mouth, partially over line), mirrored kickoff, clock `4:59`/`0:00`/`5:00`, result text.
- [ ] Run → FAIL; implement; run → PASS.
- [ ] Commit `feat(game): add room roster and match rules`.

### Task 3: InputQueue, SnapshotBuffer, Predictor + Player/Ball refactor

**Files:**
- Create: `scripts/net/input_queue.gd`, `scripts/net/snapshot_buffer.gd`, `scripts/net/predictor.gd`, `scenes/pitch.tscn`, tests `test_input_queue.gd`, `test_snapshot_buffer.gd`, `test_predictor.gd`.
- Modify: `scripts/player.gd` (input bits, `simulate`, `get_state/set_state`, team ring, name, `visual_offset`), `scripts/ball.gd` (`simulated`, `step`, `show_at`, `reset`), `scenes/main.tscn` (walls/nets → `pitch.tscn`), `scripts/main.gd` (offline path uses `MatchRules`), `scripts/scoreboard.gd` (`set_clock`).

**Interfaces — Produces:**
- `InputQueue`: `last_seq`, `push(seq, bits)`, `take() -> Array[int]` (1 per tick, 2 when > 3 queued, repeat last movement without kick when empty).
- `SnapshotBuffer`: `INTERP_TICKS=4`, `render_tick`, `push(snap)`, `latest()`, `advance(delta)`, `sample() -> {ball_pos, players:{id: pos}}` (teleports > 200 px snap).
- `Predictor.new(player)`: `apply(bits, delta) -> int seq`, `reconcile(state_with_last_seq, delta)`; `SNAP_DISTANCE=48`.
- `Player`: `keyboard_control`, `team`, `display_name`, `is_local`, `visual_offset`, `simulate(bits, delta)`, `get_state() -> {pos, vel, stamina, regen, exhausted}`, `set_state(state)`.
- `Ball`: `simulated`, `step(delta)`, `show_at(pos)`, `reset(pos)`.
- `Scoreboard.set_clock(text)`.

- [ ] Tests: queue ordering/duplicates/catch-up/repeat-without-kick; buffer interpolation midpoint, clamp before/after, teleport, render clock resync; predictor replay is identity, small correction smoothed, large correction snaps.
- [ ] Run → FAIL; implement; run → PASS.
- [ ] Re-export web build and check offline play still works (move, sprint, kick, goal).
- [ ] Commit `refactor(game): drive players by input bits and extract pitch scene`.

### Task 4: Net autoload, GameServer, Room, boot

**Files:**
- Create: `scripts/net/net.gd` (autoload `Net`), `scripts/server/game_server.gd`, `scripts/server/room.gd`, `scenes/server.tscn`, `scripts/boot.gd`, `scenes/boot.tscn`, `tests/test_server_flow.gd`.
- Modify: `project.godot` (main scene → boot, autoload Net).

**Interfaces — Produces:**
- `Net` signals: `connected`, `connection_failed`, `disconnected`, `room_state_received(state)`, `error_received(msg)`, `match_started`, `snapshot_received(snap)`, `goal_scored(team)`, `match_ended(l, r)`. Vars: `server`, `current_room`, `last_error`, `player_name`, `ping_ms`. Funcs: `host(port)`, `join(url)`, `leave()`, `is_online()`, `my_id()`, `server_url()`.
- Client→server RPCs: `request_create(name)`, `request_join(code, name)`, `request_team(team)`, `request_start()`, `request_leave()`, `send_input(seq, bits)`, `ping(msec)`.
- Server→client RPCs: `send_room_state(state)`, `send_error(msg)`, `send_match_start()`, `send_snapshot(bytes)`, `send_goal(team)`, `send_match_end(l, r)`, `pong(msec)`.
- `GameServer`: `port` export, `room_count()`, `handle_create/join/team/start/input/leave`.
- `Room` (SubViewport): `code`, `roster`, `phase`, `score`, `time_left`, `add_player`, `remove_player`, `set_team`, `start`, `push_input`, `is_empty`, `is_in_match`.

- [ ] Write `tests/test_server_flow.gd`: in one process, server on `/root/Net` and two clients on their own `SceneMultiplayer` branches over a real WebSocket. Covers unknown code, create, join (lowercase code, padded name), team balance, non-host start refused, snapshots, movement acked, goal, join during match refused, match end → lobby, disconnect removal, empty room deletion.
- [ ] Run → FAIL; implement; run → PASS.
- [ ] Commit `feat(net): add authoritative game server with rooms`.

### Task 5: Client menu, lobby, online match

**Files:** Create `scripts/ui/menu.gd`, `scenes/menu.tscn`, `scripts/ui/lobby.gd`, `scenes/lobby.tscn`. Modify `scripts/main.gd`, `scenes/main.tscn` (Status + Result labels).

- [ ] Menu: name, Create room, code + Join, Play offline, status line.
- [ ] Lobby: code, two team columns, Join Blue/Red, Start (host), Leave.
- [ ] Match online: spawn roster players, predict local, interpolate others, scoreboard clock, ping, goal banner, result, back to lobby, Esc to menu.
- [ ] Manual test: server + 4 browser tabs (2v2), play a goal, let the clock run out (temporarily via short match for the test), leave mid-match.
- [ ] Commit `feat(ui): add menu, lobby and online match client`.

### Task 6: Deployment

**Files:** Create `web/vercel.json`, `tools/build-web.sh`, `Dockerfile`, `.dockerignore`, `render.yaml`. Modify `README.md`.

- [ ] `tools/build-web.sh` exports and copies `web/vercel.json` into `export/`.
- [ ] Dockerfile installs Godot 4.7.2 Linux, imports, runs server; build locally with `docker build --platform linux/amd64`.
- [ ] README: multiplayer run/test/deploy instructions.
- [ ] Commit `chore(deploy): add Vercel and Render deployment config`.
