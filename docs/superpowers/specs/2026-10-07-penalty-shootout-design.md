# Penalty Shootout (Practice) — Design

Date: 2026-10-07 · Status: approved in chat

## Flow
Start menu → PRACTICE → FREE PLAY | PENALTY (+ BACK) → PICK YOUR PLAYER → `penalty.tscn`.

## Match
- One goal: the right one. Ball on the penalty spot (`GOAL_LINE_RIGHT - PENALTY_SPOT_DISTANCE`).
- You are BLUE, the AI is RED. Blue kicks first; teams alternate.
- On your kick you shoot (your character's stats) and the AI keeps. On the AI's
  kick you keep: keeper characters use their keeper stats, others the defaults.

## One kick
1. Setup: ball on the spot, shooter 40 px behind it, keeper centred on the goal
   line. Round label: `ROUND n` / `SUDDEN DEATH`.
2. Countdown 3-2-1: nobody moves.
3. Live: the shooter moves freely and may touch the ball once (any touch —
   kick, pass or dribble push — ends their control). No touch within 6 s = miss.
   The keeper is locked on the goal line: up/down only, inside the posts.
4. Result: ball wholly over the line inside the mouth = GOAL. Otherwise, once
   the ball is (nearly) still or 4 s after the touch: SAVED if the keeper
   touched it, else MISSED. Banner for 1.5 s, then the next kick.

## Winning
Five kicks each, most goals wins; stop early once one side cannot catch up.
Level after five: sudden death, decided after any round where one scores and
the other misses. End screen: YOU WIN / YOU LOSE with the score, PLAY AGAIN and MENU.

## AI
- Shooter: starts straight behind the ball (no tell). After the countdown it
  waits briefly, picks a random point in the goal, steps onto that line,
  charges 0.3–1 s and releases. Placement is imperfect, so it sometimes misses.
- Keeper: when the ball is struck it guesses a side (right ~60 % of the time),
  reacts after ~0.15 s and moves along the line towards its guess.

## Units
| File | Responsibility |
|---|---|
| `scripts/game/penalty_rules.gd` | Kick record, whose turn, round, early finish, sudden death, winner; spot/keeper geometry. Pure. |
| `scripts/game/penalty_ai.gd` | Shooter and keeper brains producing input bits. |
| `scripts/penalty.gd` + `scenes/penalty.tscn` | Phases (setup, countdown, live, kicked, result, finished), keeper lock, one-touch rule, HUD. |
| `scripts/ui/menu.gd`, `scripts/ui/characters_screen.gd` | Practice mode choice, pick screen routes to the chosen mode. |

## Tests
Rules (regular, early finish, sudden death, turn order); keeper line lock;
countdown freeze; one touch; goal / saved / missed / timeout; AI shooter on
target; AI keeper moves to its guess; menu → practice → penalty → pick → scene.
