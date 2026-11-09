# Bugs & Lizards

A 3D multiplayer classroom ecology game for school Chromebooks (Godot 4.7.2, web export, headless server on the VPS).
Design: `Bugs-and-Lizards-GDD-v0.3.md` (frozen). Build plan: `IMPLEMENTATION-PLAN.md`.

## Run

- Editor scan: `Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --quit-after 250`
- Server (local): `Godot_v4.7.2-stable_win64_console.exe --headless --path game -- --server` (port 3311, loopback)
- Web export: `--headless --path game --export-release "Web" build/web/index.html`, then serve `game/build/web`
- Browser smoke test: `$env:PW_PATH = "<game-sim-server>\node_modules\playwright"; node game/tests/web/web_check.js <url>`

## Milestones

- [x] **M0** Headless editor scan clean; web export loads in Chrome and prints the boot line.
- [ ] **M1** Page loads from the VPS in desktop Chrome, moves, and shows a live round-trip time. (Then stop point 1.)
- [ ] **M2** `tests/rules_test.gd` runs headless with 100+ cases, zero failures, pass count equals expected total.
- [ ] **M3** One machine: teacher tab + two student tabs play four rounds of Stage 1 and Stage 2; summary matches `round_rules.gd`; two bots racing for one bug give exactly one capture in 20 tries; blind sweeping does no better than looking.
- [ ] **M4** Two rooms run Stage 2 to an endpoint with bots + one human tab; resetting one room leaves the other untouched; a refreshed student tab rejoins with captures intact; 25 bots hunt ten minutes without the server falling over. (Then stop point 2.)

## Deviations

## Later
