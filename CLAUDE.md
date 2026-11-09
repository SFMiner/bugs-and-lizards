# Bugs & Lizards — project rules (40 lines max)

Read `IMPLEMENTATION-PLAN.md` §0 first. `Bugs-and-Lizards-GDD-v0.3.md` is frozen. Ignore the other .md files here
(old GDD versions, reviews; `GDD.md` is a different project).

## Done beats perfect
- Every task delivers running code plus a test or command showing it. No design/analysis/review/planning docs.
- Only `README.md` (checklist, Deviations, Later), this file and code comments may grow.
- GDD silent → simplest option, one line under README "Deviations", keep going. Ask the owner only if a lesson rule
  (round arithmetic, tag-in, the mutant) would change.
- One manager review per milestone; fix only blockers (crash, wrong number, uncompletable round, VPS risk). Rest → "Later".
- Two failures → simplify; third → cut or ask. No refactor without a failing test. Primitives and flat colours only.

## Fixed decisions
- Godot **4.7.2** (`Gamedev\Godot_v4.7.2-stable_win64_console.exe`), Compatibility renderer, single-threaded web export,
  **stock** template, Export With Debug off. The 2D lean templates do not apply.
- Godot project in `game/`; deployment in `deploy/`. Main scene `Main.tscn`; `_ready` prints `bugs-and-lizards: boot ok`.
- Same project is client and server: `-- --server` starts the headless server (loopback port 3311).
- Networking: plain JSON over one WebSocket (`TCPServer` + `WebSocketPeer.accept_stream`). No RPC/MultiplayerSpawner.
  nginx terminates TLS and proxies `/bugs-and-lizards/ws`.
- Client moves its own lizard and reports position ~10/s; server checks speed, range, timing, uniqueness. No line of sight.
- Bugs static, one MultiMesh per colour, picked by arithmetic along the view ray. Habitat built in code from primitives.
- Teacher-typed roster; students pick a name, type nothing. Session creator holds the teacher token. No passwords/PINs/keys
  anywhere in code or .md files.

## Contract files (manager only)
- `scripts/shared/protocol.gd` (message and field names) and `scripts/shared/round_rules.gd` public signatures.
  Agents never change them; they ask the manager.

## Checks
- After any agent: `--headless --path game --editor --quit-after 250` → no SCRIPT ERROR / Parse Error / not found.
- Rules/server change: run `tests/rules_test.gd` and `tests/protocol_test.gd`; pass count must equal the expected total.
- Before `git add`: `find . \( -name "*Name clash*" -o -name "*Edit conflict*" \)` and `git diff --stat`.
- One commit + push per milestone (remote `origin` = github.com/SFMiner/bugs-and-lizards).
