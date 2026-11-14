# Bugs & Lizards

A 3D multiplayer classroom ecology game for school Chromebooks (Godot 4.7.2, web export, headless server on the VPS).
Design: `Bugs-and-Lizards-GDD-v0.3.md` (frozen). Build plan: `IMPLEMENTATION-PLAN.md`.

## Run

- Editor scan: `Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --quit-after 250`
- Server (local): `Godot_v4.7.2-stable_win64_console.exe --headless --path game -- --server` (port 3311, loopback)
- Web export: `--headless --path game --export-release "Web" build/web/index.html`, then serve `game/build/web`
- Pages: `index.html` student, `index.html?teacher` teacher, `index.html?campus` campus check
- Tests (headless, `--script res://tests/<name>.gd`): `rules_test` (308), `server_smoke_test` (72), `pick_test` (8), `protocol_test` (167), `graph_test` (21)
- Bots: `BL_CODE=<code> BL_BOTS=2 BL_MODE=hunter|sweeper|idle ... --script res://tests/bots.gd` (`BL_TEACHER=1` runs a whole session)
- Browser smoke test: `$env:PW_PATH = "<game-sim-server>\node_modules\playwright"; node game/tests/web/web_check.js <url>`
- Re-rig the lizard after editing `lizard.blend`: `& "C:\Program Files\Blender Foundation\Blender 5.3lender.exe" -b <GameAssets>d-models\lizard.blend --python toolsig_lizard.py`
- Desktop screenshot: set `BL_SHOT=<png>` and run windowed (`-- --teacher` for the teacher view)

## Milestones

- [x] **M0** Headless editor scan clean; web export loads in Chrome and prints the boot line.
- [ ] **M1** Page loads from the VPS in desktop Chrome, moves, and shows a live round-trip time. (Then stop point 1.) Server side live on the VPS since 2026-11-14 (unit `bugs-and-lizards.service`, 127.0.0.1:3311, loopback handshake 101); the page waits for the nginx snippet + include, which goes into game-sim-server `deploy/nginx.conf.template` with the owner's yes.
- [x] **M2** `tests/rules_test.gd` runs headless with 100+ cases, zero failures, pass count equals expected total. (308/308)
- [x] **M3** One machine: teacher tab + two student tabs play four rounds of Stage 1 and Stage 2; summary matches `round_rules.gd`; two bots racing for one bug give exactly one capture in 20 tries; blind sweeping does no better than looking. (Browser run with 2 hunter bots: Stage 1 four rounds 50/36/24/15/12; Stage 2 reached the overrun endpoint in round 3, 912 > 600. Race 20/20 in protocol_test. Sweeper 1 capture per 360 presses vs hunter 25.)
- [x] **M4** Two rooms run Stage 2 to an endpoint with bots + one human tab; resetting one room leaves the other untouched; a refreshed student tab rejoins with captures intact; 25 bots hunt ten minutes without the server falling over. (Then stop point 2.) (Browser: room 1 reached overrun 915 in round 3; resetting room 2 left room 1 at round 2 / 114; refreshed tab rejoined. Rejoin keeps captures: protocol_test. 25 bots, 4 rooms, 300 bugs, 10 min: 54 round records all match RoundRules, server 97 MB. graph_test 21/21, web_check 6/6 and 3/3.)

## Deviations

- Bug colours: four flat colours matching the four floor colours, drawn equally (GDD gives no mix).
- Bug budget default 600 (provisional until the Gate 2 ladder); the room ends with the exact count above it.
- Changing the number of ecosystems deals the roster round-robin into them; there is no per-student room picker yet.
- Graph: bugs and lizards share one y axis, as on the paper organizer, so small lizard counts sit near zero.
- Starting lizards not picked by the teacher are picked at random from the room, connected students first.
- Seat token kept per browser tab (sessionStorage), so two tabs on one machine are two students; teacher token in localStorage.
- PICK_NAME with a name not on the roster answers `name_taken` (no separate reason code).
- No miss delay after a capture press that hits nothing: the sweep test showed it is not needed.
- Teacher New game returns to the setup panel with the old names filled in; the old game keeps running until it expires, and Back to game reopens it.
- When all 8 game slots are used, creating a game drops the game that has had nobody connected for longest (games with anyone connected are kept).
- Apply settings changes only ecosystems still waiting to start round 1; a played one keeps its stage until Reset, and its card says so in red while the picked stage differs.
- Decor: 200 items by weight 75 plant : 30 fungi : 10 rock : 1 log (owner), each model of a group equally, 1-2x base size (plants 1-3x), placed by a fixed seed on open floor. Bugs may sit under leaves and caps (only stems kept 12 cm clear); rocks and logs are solid (box collision from the model bounds) and bugs stay off them. leaves and caps may overlap by half their spread; 1036 spawn points left. Base sizes and colours picked by the manager.
- Hunters see the other hunters in their ecosystem (owner, 2026-11-11): the server sends each hunter the others' last accepted positions and facing 10 times a second (LIZARDS_SEEN); no name labels, no collision between lizards.
- Server limits for hosting on sims (game-sim-reviewer, 2026-11-14): at most 360 connections; a connection is closed after more than 60 messages at once or 30 a second on average, after 5 wrong codes or teacher keys, or when it has not joined a game within 10 minutes. Creating a game needs the teacher key when the server sets `BL_TEACHER_KEY` (kept in `/etc/bugs-and-lizards.env` on the VPS, typed by the teacher, never stored). The names-and-counts catch log is off unless `BL_CATCH_LOG=1`. Code stays 4 digits (GDD).
- Students can leave their game from the waiting screen ("Wrong game or name?"); the seat stays taken until the teacher releases it.

## Later

- Release seat has no confirm step.
- Keys once died in old browser tabs (letters never reached the page; cause not found); fresh tabs with Ctrl+Shift+R work in Chrome and Vivaldi. Hunt HUD shows a temporary key/focus readout; a window-level key listener feeds the movement keys when they miss the canvas. Remove the readout once settled.
- Keyboard-only play, digit keys on the join pad and Tab order not yet tried by a human.
- Bots out-catch humans by far; the §4 calibration target needs real players.
- Bugs are the beetle and spider models in `game/assets/models/` (picked per bug from its id, recoloured in code to one flat floor colour, random facing, longest side 16 cm); the code-built beetle is the fallback. Spiders' long legs make their bodies smaller than beetles'; tune sizes with the calibration test.
- Decor (owner, 2026-11-11): good for breaking line of sight; when more plant models exist, raise to 3-4x the count (600-800) at about 2/3 plants, 1/3 fungi. Recheck the spawn-point count against the bug budget then.
- Other lizards use the owner's model (`game/assets/models/lizard.glb`, 1.6 m long, standing about 33 cm tall in a low sprawl copied from the owner's hind-leg pose). It is rigged and animated (walk, idle) by `tools/rig_lizard.py`, run in background Blender on `GameAssets\3d-models\lizard.blend`; it writes `lizard_animated.blend` beside it (never `lizard_rigged.blend`, which holds the owner's hand pose) and the glb here. The code-built placeholder in `lizard_avatar.gd` is the fallback. The player's eye height (0.5 m) is a little above the model's eyes (about 30 cm).
- Teacher graph's Start lizard count comes from the settings, not from who was ticked in round 1.
- Teacher starting-bugs box stops at 600; the server's SET_DEBUG_BUGS goes to 1036 (the spawn-point count) but has no button yet.

## Credits

- Bug models (`game/assets/models/beetle.glb`, `spider.glb`): made by Sean Miner for this game, 2026-11-11.
- Lizard model (`game/assets/models/lizard.glb`): made by Sean Miner for this game, 2026-11-11; rig and animations by `tools/rig_lizard.py`.
- Plant, mushroom, log and rock models (`game/assets/models/`): made by Sean Miner for this game, 2026-11-11.
