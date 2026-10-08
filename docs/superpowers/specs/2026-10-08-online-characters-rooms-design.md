# Online: Characters, Match Length, Room List — Design

Date: 2026-10-08 · Status: approved in chat

## Play Online screen
- Opening it connects and shows the server's rooms, updated live: host name,
  players x/8, match length, WAITING (JOIN) or IN MATCH (dimmed). Full or
  running rooms can't be joined. No more typing codes (codes stay internal).
- YOUR NAME is required before JOIN or CREATE ROOM; it shows under your player.
- At most 5 rooms per server; when full, CREATE ROOM is disabled with a note.

## Lobby
- Each member shows name + character (chip + name).
- CHARACTER button opens a picker of all 10; unavailable ones are dimmed with
  the reason: taken by a teammate (other team may share), or the team already
  has a goalkeeper (max one keeper per team).
- Joining assigns the first free outfield character; switching team re-assigns
  if the character is taken there.
- Host picks match length 5 / 7 / 10 minutes; others see it.
- START needs: host, a player on each team, and exactly one keeper in every
  team of two or more. The reason is shown otherwise.

## Match
- The server applies each character's stats; the client applies the same to
  its own predicted player. Keepers roam the whole pitch with keeper save
  rules, green shirt and gloves. The clock uses the chosen length.

## Protocol (Net RPCs)
- New client→server: `request_room_list()`, `request_character(id)`,
  `request_duration(minutes)`.
- New server→client: `send_room_list(rooms)`; room state gains
  `minutes` and each member a `character`.
- Room list is pushed to every connected peer that is not in a room whenever
  any room changes.

## Tests
Roster character rules and start rule; duration (host only, 5/7/10); room cap;
room list updates; server applies stats and uses the chosen length; online
screen (name required, dimmed rooms); lobby picker; e2e via the room list.
