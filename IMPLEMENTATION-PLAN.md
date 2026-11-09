# Bugs & Lizards — Implementation Plan

**For:** an Opus manager directing Sonnet and Haiku agents.
**Design source:** `Bugs-and-Lizards-GDD-v0.3.md` (approved baseline, 2026-11-09). Section numbers below (§) refer to it.
**Written:** 2026-11-09.

## 0. Done beats perfect

The owner's instruction: recent projects have been lost in revision cycles that add more to documentation than to code. These rules outrank everything else in this plan.

1. **The GDD is frozen.** Nobody edits it, reviews it again, or writes a new design, analysis, review or planning document. This plan is not revised either; if it is wrong, do the sensible thing and add one line under "Deviations" in `README.md`.
2. **Every task delivers code that runs**, plus a test or a command that shows it running. A task whose output is prose is not a task.
3. **Only three documents may grow:** `README.md` (feature checklist, deviations, "Later" list), the project `CLAUDE.md` (40 lines at most), and code comments.
4. **When the GDD is silent, pick the simplest option that fits it, write one line under Deviations, and keep going.** Ask the owner only at the two stop points in §6, or if the choice would change a lesson rule (§4 arithmetic, §5 tag-in, §7 mutant).
5. **One review pass per milestone, by the manager.** Fix only blocking defects: a crash, a wrong number, a round that cannot be completed, or a risk to the shared VPS. Everything else goes on the "Later" list unfixed. No second review round unless the fix touched `round_rules.gd`.
6. **Two failures, then simplify.** A task that fails twice returns to the manager, who cuts it down or does it directly. A third failure means cut the feature or ask the owner.
7. **No refactor without a failing test or a blocking defect.** No art beyond primitives and flat colours before stop point 2.
8. **Tests where numbers matter, smoke tests elsewhere.** The rules and the protocol get real tests. Screens get one browser smoke test.

A milestone is done when its "Done when" line is true. It is not done when it is polished.

## 1. Fixed decisions (do not reopen)

| Topic | Decision |
|---|---|
| Engine | Godot **4.7.2**, GDScript, Compatibility renderer, single-threaded web export, **stock** web template with "Export With Debug" off. The 2D lean templates do not apply. |
| Folder | Godot project in `game/` inside this folder. Deployment files in `deploy/`. The existing `.md` files stay where they are; `GDD.md` is a different project and is ignored. |
| One project, two roles | The same Godot project is client and server. `main.gd` starts the server when run with `-- --server`, otherwise the client. The server runs headless on the VPS from the Linux Godot 4.7.2 binary. |
| Networking | **Plain JSON messages over one WebSocket.** Server: `TCPServer` + `WebSocketPeer.accept_stream`. Client: `WebSocketPeer`. No `MultiplayerSpawner`, no RPC. The GDD left this open (§9); it is decided here so nobody spends a week comparing. Revisit only if it fails in practice. |
| TLS | nginx on the VPS terminates TLS and proxies one path to the server's local port. |
| Movement | Client moves its own lizard and reports position about 10 times a second. Server checks speed, capture range, timing and uniqueness. No line-of-sight check. |
| Bugs | Static. Drawn with one `MultiMesh` per colour. No physics body per bug: the client picks the nearest bug along the view ray by arithmetic. |
| Habitat | Built in code from primitives. Spawn points are generated in code on known open surfaces, so "visible and reachable" holds by construction. No hand-authored `.tscn` layout. |
| Names | Teacher-typed roster; students pick a name. No student text entry. |
| Teacher access | Whoever creates a session holds its teacher token. No passwords or PINs in code. Cap the number of live sessions. |
| Scenes | Main scene is `Main.tscn` (capital M). `_ready` prints `bugs-and-lizards: boot ok`. |

## 2. Layout and ownership

```text
game/
	project.godot, Main.tscn, export_presets.cfg      manager only
	scripts/main.gd                                   manager only
	scripts/shared/protocol.gd                        manager only (message names, field names, constants)
	scripts/shared/round_rules.gd                     pure logic, no nodes
	scripts/shared/config.gd                          stage defaults from §4 "Source defaults"
	scripts/server/server_main.gd, session.gd, room.gd
	scripts/client/net_client.gd
	scripts/client/join_screen.gd, summary_screen.gd, teacher_view.gd, graph.gd
	scripts/client/habitat.gd, bug_field.gd, player_controller.gd, hunt_view.gd
	tests/rules_test.gd, protocol_test.gd, bot_client.gd, web/web_check.js
	build/            (contains .gdignore)
deploy/
	bugs-and-lizards.service, nginx-location.conf, deploy.ps1
README.md, CLAUDE.md
```

`protocol.gd` and `round_rules.gd`'s public function names are the **interface contract**. The manager writes both before any parallel work starts and pastes them into every agent's brief. Agents do not change them; they ask the manager.

## 3. Agent assignment

- **Opus manager:** writes the contract files, `main.gd`, project settings; briefs agents; does the one review pass; runs the checks in §5; makes the calls under rule 4. Does not delegate integration.
- **Sonnet:** `round_rules.gd`, server scripts, `net_client.gd`, `player_controller.gd`, `bug_field.gd`, tag-in, the Stage 4 view handicap, protocol tests, debugging across files.
- **Haiku:** `config.gd`, screens built from a stated layout (`join_screen`, `summary_screen`), `graph.gd`, export preset, deploy files, README checklist upkeep.
- At most four agents at once. Each agent owns named files and touches no others. Use worktrees only if two agents must create files in the same folder at the same time.
- Every brief uses the task format in the `godot-game-pipeline` skill (`references/orchestration.md`) and tells the agent: tabs, type hints, read the Gamedev `CLAUDE.md` gotchas, no new documents.

## 4. Milestones

Work M1 and M2 at the same time. Do not wait for the campus result before starting M3.

### M0 — Setup (manager, sequential)

- Download Godot 4.7.2 (Windows editor, Linux binary for the VPS, web export templates). Put the editor beside the other Godot binaries in `Gamedev\`.
- Create `game/`, `project.godot` (Compatibility, `allow_hidpi` on, stretch `expand`), `Main.tscn`, `main.gd` with the boot line and the `--server` switch.
- Write `protocol.gd` and the `round_rules.gd` function signatures.
- `README.md` with a checklist copied from the "Done when" lines below. `CLAUDE.md` with the fixed decisions and rule 0 in short form.
- `git init` (local only).

**Done when:** `Godot --headless --path game --editor --quit-after 250` shows no errors and a web export loads in Chrome and prints the boot line.

### M1 — Campus check (GDD Gate 0)

The smallest thing that answers the school questions.

- Client: a floor, a few boxes, first-person movement with keys-only turning **and** pointer lock, an on-screen frame rate, and a line showing WebSocket state and round-trip time. A second line shows whether a key press and trackpad movement registered in the same half second.
- Server: accepts a connection and echoes.
- Deploy: server unit and site folder on the VPS; nginx location for the WebSocket path.
- Print the export's download size and time-to-boot on screen so the owner can read them off a Chromebook.

**VPS rule:** the site's own folder and service unit need no permission. The nginx location and reload are shared-layer changes: message **MainCircleAgent** with exactly what will change and wait for its reply; if it is not running, ask the owner.

**Done when:** the page loads from the VPS in desktop Chrome, moves, and shows a live round-trip time. Then **stop point 1** (§6). Carry on with M2 and M3 while waiting.

### M2 — Rules engine (parallel with M1; one Sonnet agent)

`round_rules.gd`: pure functions, no nodes, no networking.

- Survival and offspring arithmetic for Stages 1–4 (§4 "Essential arithmetic").
- Round resolution in the §4 order, producing both the paper-organizer values (BUGS after hunt and before bug births; LIZARDS and MUTANTS after tag-in) and the next-round starting counts.
- Endpoints: Stage 1 at five or fewer bugs or four rounds; Stages 2–3 four rounds; Stage 4 five; zero bugs; zero lizards; bug-budget overflow with the exact count kept.
- Tag-in resolution: earned, filled and unfilled slots; first pick wins.
- Stage 4: one mutant among the first *filled* offspring cohort; an offspring is counted by its own trait; the teacher fallback is flagged in the record.

**Done when:** `tests/rules_test.gd` runs headless with at least 100 cases, zero failures, and the pass count equals the expected total. Cases include 4, 5, 10 and 15 captures, no prey, two picks of one student, and overflow.

### M3 — One-room hunt (GDD Gate 1)

Sequential first (manager): fill in `protocol.gd` messages for join, hunt start, position, capture, bug gone, hunt end, summary, teacher commands.

Then in parallel:

- **A (Sonnet):** `server_main.gd`, `session.gd`, `room.gd`. One session, one room. Roster, join, hunt timer owned by the server, capture validation, calls `round_rules.gd`, sends the summary. Logs each player's captures per hunt with the bug count, to a file.
- **B (Sonnet):** `habitat.gd`, `bug_field.gd`, `player_controller.gd`, `hunt_view.gd`. Capture is an aimed key press on one bug at close range. No hover highlight, no walk-over pickup. Own capture count on screen. Habitat hidden between hunts; shared start area.
- **C (Haiku):** `join_screen.gd` (code, then pick a name), `summary_screen.gd` (shows "Bugs remaining after hunt" and "bugs at next round start" as separate labeled lines), `teacher_view.gd` (roster entry, pick starting lizards, start, stop, advance, live caught and remaining).
- **D (Sonnet):** `net_client.gd`, `tests/bot_client.gd` (a headless scripted player), `tests/protocol_test.gd`.

Join (manager): wire A–D, run Stage 1 and Stage 2 end to end.

**Done when:** on one machine, a teacher tab and two student tabs play four rounds of Stage 1 and of Stage 2; the summary matches `round_rules.gd`; two bots racing for one bug produce exactly one capture in 20 tries; a player sweeping the view while mashing the capture key does no better than one who is not looking (if they do, add a short delay after a miss).

### M4 — Rooms, rejoin, graph

- Several rooms in one session, isolated state, **one shared pace**: teacher start, stop and advance apply to every room (§5). Per-room pause and reset only.
- Bug positions go only to hunters, and only at hunt start.
- Rejoin with a token kept in the browser; captures already accepted stand; teacher can release a seat.
- Teacher view rebuilds from server state when its tab returns; a hunt ends on the server's clock regardless.
- `graph.gd`: one simple line graph per room in the paper convention, each line with a colour, a dash pattern and a label.
- A debug setting for bug count, and `bot_client.gd` able to run 25 bots across rooms, for the pressure test.
- Browser smoke test (`tests/web/web_check.js`, Playwright with the installed Chrome): boot line present, no console `SCRIPT ERROR`, join and one hunt complete. Check the port is free and serve with `--directory`.

**Done when:** two rooms run Stage 2 to an endpoint with bots plus one human tab; resetting one room leaves the other untouched; a refreshed student tab rejoins with its captures intact; 25 bots hunt for ten minutes without the server falling over. Then **stop point 2**.

### M5–M7 — outlined, **not authorised yet**

The GDD holds the full build until the gates pass (§10). After stop point 2, and only on the owner's word:

- **M5, Stage 3:** raise-hand toggle, parent pick is final, slot accounting on the teacher view. A small script (not a document) replays the catch counts logged in M3–M4 through `round_rules.gd` at room sizes 6, 12 and 25 and prints the resulting series, so the owner can choose a Stage 3–4 room size.
- **M6, Stage 4:** the view handicap for normal lizards (loses contrast, not just brightness), mutant designation and inheritance, teacher fallback, MUTANTS series, five rounds.
- **M7, pilot readiness:** observer view, text-size option, high-contrast demonstration view, final export and deploy.

## 5. Checks the manager runs

- After every agent returns: `Godot --headless --path game --editor --quit-after 250`; expect no `SCRIPT ERROR`, `Parse Error` or `not found`.
- After any change to rules or server: both headless test suites, checking pass counts against expected totals.
- Before each "Done when": a real web export opened in Chrome, console read.
- Before any `git add`: `find . \( -name "*Name clash*" -o -name "*Edit conflict*" \)` and `git diff --stat`.
- Commit locally at the end of each milestone with a one-line message. Do not push or add a remote unless the owner asks.

## 6. Stop points for the owner

Only these. Anything else, decide and move on.

1. **After M1 is deployed — campus check.** The owner opens the page on a school Chromebook, on school Wi-Fi, on a day the firewall allows the site, and reads off: did it load, load time, frame rate, WebSocket state and round-trip time, did keys plus trackpad work together, did pointer lock work. Ask first which browser will be used and record it. Whether the firewall allows the site on a given day is outside this project.
2. **After M4 — play it.** The owner plays Stages 1–2 with whatever devices and students are to hand, runs the bug-count ladder (50 to about 600) and many-lizards-in-one-room test on a Chromebook, and says whether to go on to M5–M7.

If stop point 1 fails on something this project controls (frame rate, download size, WebSocket through the proxy), fix that before building further on M3. If it fails on the firewall, keep building.
