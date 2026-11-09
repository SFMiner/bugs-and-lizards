extends SceneTree
## Drives GameSession / GameRoom directly (no sockets, no real waiting). Run:
## Godot --headless --path <game> --script res://tests/server_smoke_test.gd

const EXPECTED_TOTAL: int = 69
const LOG_DIR: String = "user://bl_test_logs"

var _pass: int = 0
var _fail: int = 0
var _tok: String = ""


func _init() -> void:
	_scenario_stage2()
	_scenario_two_rooms()
	_scenario_misc()
	print("server_smoke_test: %s %d/%d" % ["PASS" if _fail == 0 and _pass == EXPECTED_TOTAL else "FAIL", _pass, EXPECTED_TOTAL])
	quit(0 if _fail == 0 and _pass == EXPECTED_TOTAL else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAILED: " + label)


func _msg(t: String, f: Dictionary = {}) -> Dictionary:
	var d: Dictionary = f.duplicate()
	d["t"] = t
	return d


func _teacher(t: String, f: Dictionary = {}) -> Dictionary:
	var d: Dictionary = _msg(t, f)
	d["token"] = _tok
	return d


func _of(outs: Array, type: String, to: int = -1) -> Array:
	var r: Array = []
	for m: Dictionary in outs:
		if m["t"] == type and (to < 0 or int(m["to"]) == to):
			r.append(m["f"])
	return r


func _join(s: GameSession, conn: int, name: String, now: float) -> String:
	s.handle(conn, _msg("pick_name", {"code": s.code, "name": name}), now)
	var j: Array = _of(s.take_out(), "joined", conn)
	return str(j[0]["token"]) if j.size() == 1 else ""


func _scenario_stage2() -> void:
	var s: GameSession = GameSession.new("1234", ["Ann", " Bo ", "Cy", "Di", "Ann", ""], 0.0)
	_tok = s.teacher_token
	s.log_dir = LOG_DIR
	DirAccess.remove_absolute(LOG_DIR.path_join("catches.csv"))
	s.attach_creator(1, 0.0)
	var first: Array = s.take_out()
	_check(_of(first, "session_created", 1).size() == 1 and _of(first, "teacher_state", 1).size() == 1, "session_created then teacher_state")
	_check(s.roster.size() == 4 and s.teacher_token.length() == 32, "roster cleaned, token 32 hex")
	s.handle(1, _teacher("configure", {"config": {"stage": 2, "rooms": 1, "bugs_start": 75, "lizards_start": 3}}), 0.0)
	s.take_out()
	var room: GameRoom = s.rooms[0]
	_check(room.bugs.size() == 75 and room.stage == 2 and room.is_fresh(), "stage 2 room with 75 bugs")
	var toks: Dictionary = {}
	var names: Array = ["Ann", "Bo", "Cy", "Di"]
	for i: int in range(4):
		toks[names[i]] = _join(s, 11 + i, names[i], 1.0)
	_check(str(toks["Ann"]).length() == 32 and room.members.size() == 4, "four students seated")
	s.handle(20, _msg("pick_name", {"code": "1234", "name": "Ann"}), 1.0)
	_check(_of(s.take_out(), "error", 20)[0]["reason"] == "name_taken", "taken seat refused")
	s.handle(1, _teacher("set_lizards", {"room": 0, "lizards": ["Ann", "Bo", "Cy"]}), 1.0)
	s.take_out()
	_check(room.hunter_names().size() == 3, "set_lizards makes 3 hunters")
	s.handle(1, {"t": "start_hunt", "token": "nope"}, 2.0)
	_check(_of(s.take_out(), "error", 1)[0]["reason"] == "not_teacher" and room.phase == "setup", "start without token refused")
	s.handle(1, _teacher("start_hunt"), 10.0)
	var o: Array = s.take_out()
	_check(room.phase == "hunt", "hunt started")
	_check(_of(o, "hunt_start", 11).size() == 1 and _of(o, "hunt_start", 12).size() == 1 and _of(o, "hunt_start", 13).size() == 1, "HUNT_START to the 3 hunters")
	_check(_of(o, "hunt_start", 14).is_empty() and _of(o, "hunt_start", 1).is_empty(), "no HUNT_START to non-hunter or teacher")
	_check((_of(o, "hunt_start", 11)[0]["bugs"] as Array).size() == 75, "HUNT_START carries all bugs")
	var rs: Array = _of(o, "room_state", 14)
	_check(rs.size() == 1 and not JSON.stringify(rs[0]).contains("\"bugs\""), "ROOM_STATE has no bug list")
	var ids: Array = room.bugs.keys()
	# teleport is refused, a reachable step is accepted
	s.handle(11, _msg("pos", {"p": [0, 0, -9], "yaw": 0}), 10.1)
	_check(room.hunt_pos["Ann"] == HabitatLayout.START_POS, "teleport rejected")
	s.handle(11, _msg("pos", {"p": [0.3, 0, 10.0], "yaw": 0}), 10.2)
	_check(room.hunt_pos["Ann"] != HabitatLayout.START_POS, "reachable position accepted")
	# Ann 6, Bo 5, Cy 2: stand on each bug (positions set directly; movement checks tested above)
	var plan: Dictionary = {"Ann": 6, "Bo": 5, "Cy": 2}
	var conn_of: Dictionary = {"Ann": 11, "Bo": 12, "Cy": 13}
	var k: int = 0
	var caught_ids: Array = []
	for n: String in plan:
		for _j: int in range(int(plan[n])):
			var id: int = ids[k]
			k += 1
			room.hunt_pos[n] = (room.bugs[id] as Dictionary)["pos"]
			s.handle(int(conn_of[n]), _msg("capture", {"id": id}), 20.0)
			var oo: Array = s.take_out()
			_check(_of(oo, "capture_ok", int(conn_of[n])).size() == 1, "capture_ok " + n)
			caught_ids.append(id)
	_check(room.caught_total() == 13 and room.bugs.size() == 62, "13 captured, 62 left")
	var extra_id: int = ids[k]
	room.hunt_pos["Cy"] = (room.bugs[extra_id] as Dictionary)["pos"]
	room.hunt_pos["Bo"] = (room.bugs[extra_id] as Dictionary)["pos"]
	s.handle(12, _msg("capture", {"id": extra_id}), 21.0)
	s.handle(13, _msg("capture", {"id": extra_id}), 21.0)
	var sim: Array = s.take_out()
	var oks: int = _of(sim, "capture_ok").size()
	var rejected: Array = _of(sim, "capture_rejected", 13)
	_check(oks == 1 and rejected.size() == 1 and rejected[0]["reason"] == "gone", "simultaneous capture: exactly one accepted")
	_check(_of(sim, "bug_gone", 11).size() == 1 and _of(sim, "bug_gone", 13).size() == 1 and _of(sim, "bug_gone", 12).is_empty(), "BUG_GONE to other hunters only")
	# Bo took extra_id: counts are Ann 6, Bo 6, Cy 2 (total 14, 61 left)
	var far_id: int = -1
	for id: int in room.bugs:
		if (room.bugs[id] as Dictionary)["pos"].distance_to(room.hunt_pos["Ann"]) > 5.0:
			far_id = id
			break
	s.handle(11, _msg("capture", {"id": far_id}), 21.5)
	_check(_of(s.take_out(), "capture_rejected", 11)[0]["reason"] == "range", "out of range refused")
	s.handle(14, _msg("capture", {"id": far_id}), 21.5)
	_check(_of(s.take_out(), "capture_rejected", 14)[0]["reason"] == "not_hunting", "non-hunter refused")
	# seat rejoin mid-hunt
	s.handle(31, _msg("rejoin", {"code": "1234", "token": toks["Ann"]}), 30.0)
	var rj: Array = s.take_out()
	var hs: Array = _of(rj, "hunt_start", 31)
	_check(_of(rj, "joined", 31).size() == 1 and hs.size() == 1, "rejoin: JOINED + HUNT_START")
	_check(hs.size() == 1 and int(hs[0]["count"]) == 6 and (hs[0]["bugs"] as Array).size() == 61 and abs(float(hs[0]["seconds"]) - 25.0) < 0.2, "rejoin carries count, remaining bugs, seconds left")
	s.handle(11, _msg("capture", {"id": far_id}), 30.5)
	_check(_of(s.take_out(), "capture_rejected", 11)[0]["reason"] == "not_hunting", "old connection no longer the seat")
	s.handle(1, _msg("capture", {"id": 1}), 31.0)
	s.take_out()
	# the timer ends the hunt on the server clock
	s.tick(54.0)
	_check(room.phase == "hunt", "hunt still running before the deadline")
	s.tick(55.0)
	var eo: Array = s.take_out()
	_check(room.phase == "study", "timer ended the hunt")
	_check(_of(eo, "hunt_end", 31).size() == 1 and _of(eo, "hunt_end", 14).size() == 1, "HUNT_END to the whole room")
	var sm: Array = _of(eo, "summary", 14)
	_check(sm.size() == 1, "SUMMARY sent")
	var summary: Dictionary = sm[0]["summary"]
	# independent expectation from RoundRules for the same captures
	var lz: Array = RoundRules.starting_lizards(["Ann", "Bo", "Cy"])
	var res: Dictionary = RoundRules.resolve_hunt(2, 1, 75, lz, {"L1": 6, "L2": 6, "L3": 2})
	var fin: Dictionary = RoundRules.finish_round(res, RoundRules.new_tagin(res), {"bug_budget": 600})
	var rec: Dictionary = fin["record"]
	_check(summary["BUGS"] == rec["BUGS"] and summary["bugs_next_start"] == rec["bugs_next_start"] and summary["LIZARDS"] == rec["LIZARDS"], "summary numbers match RoundRules")
	_check(summary["BUGS"] == 61 and summary["bugs_next_start"] == 183, "61 uncaught, 183 next")
	_check(summary["captures"] == {"Ann": 6, "Bo": 6, "Cy": 2} and summary["survived"] == ["Ann", "Bo"] and summary["starved"] == ["Cy"], "captures/survived/starved by name")
	_check((summary["history"] as Array).size() == 1 and abs(float(summary["hunt_seconds"]) - 45.0) < 0.01, "history and actual seconds")
	var csv: String = FileAccess.get_file_as_string(LOG_DIR.path_join("catches.csv"))
	var lines: PackedStringArray = csv.strip_edges().split("\n")
	_check(lines.size() == 4 and lines[1].contains(",Ann,6") and not csv.contains(toks["Ann"]), "catch log: header + 3 hunters, no tokens")
	# advance
	var kept: Dictionary = {}
	for id: int in room.bugs:
		kept[id] = (room.bugs[id] as Dictionary)["pos"]
	s.handle(1, _teacher("advance"), 60.0)
	s.take_out()
	_check(room.phase == "setup" and room.round_number == 2 and room.bugs.size() == 183, "advance: round 2, uncaught*3 bugs")
	var same: bool = true
	for id: int in kept:
		same = same and room.bugs.has(id) and (room.bugs[id] as Dictionary)["pos"] == kept[id]
	_check(same, "uncaught bugs kept their positions")
	var fresh_ids: bool = true
	for id: int in room.bugs:
		if not kept.has(id) and (caught_ids.has(id) or id < 76):
			fresh_ids = false
	_check(fresh_ids, "new bug ids never reuse old ones")
	s.handle(1, _teacher("start_hunt"), 61.0)
	var r2: Array = s.take_out()
	_check(_of(r2, "hunt_start", 31).size() == 1 and _of(r2, "hunt_start", 12).size() == 1 and _of(r2, "hunt_start", 13).is_empty() and room.phase == "hunt" and room.lizards.size() == 2, "round 2 hunt with the survivors only")


func _scenario_two_rooms() -> void:
	var s: GameSession = GameSession.new("5678", ["A", "B", "C", "D"], 0.0)
	_tok = s.teacher_token
	s.attach_creator(1, 0.0)
	s.handle(1, _teacher("configure", {"config": {"stage": 1, "rooms": 2, "bugs_start": 50, "lizards_start": 1}, "assign": {"A": 0, "B": 0, "C": 1, "D": 1}}), 0.0)
	_check(s.rooms.size() == 2 and s.rooms[0].members == ["A", "B"] and s.rooms[1].members == ["C", "D"], "two rooms with the assignment")
	var before: Dictionary = {"state": s.rooms[1].state(0.0), "bugs": s.rooms[1].bugs.duplicate(true)}
	var old0: Array = s.rooms[0].bugs.keys()
	s.handle(1, _teacher("reset_room", {"room": 0}), 1.0)
	_check(s.rooms[0].bugs.keys() != old0 and s.rooms[0].is_fresh(), "reset room 0 gives fresh bugs")
	var after: Dictionary = {"state": s.rooms[1].state(0.0), "bugs": s.rooms[1].bugs.duplicate(true)}
	_check(before == after, "reset of room 0 leaves room 1 identical")
	# pause: a paused room ignores START_HUNT, the other runs on the same call
	s.handle(1, _teacher("pause_room", {"room": 1, "value": true}), 2.0)
	s.handle(1, _teacher("start_hunt"), 3.0)
	_check(s.rooms[0].phase == "hunt" and s.rooms[1].phase == "setup", "paused room skipped by START_HUNT")
	_check(s.rooms[0].lizards.size() == 1, "random lizard pick when none set")
	s.handle(1, _teacher("stop_hunt"), 5.0)
	_check(s.rooms[0].phase == "ended" and abs(float(s.rooms[0].history[0]["hunt_seconds"]) - 2.0) < 0.01, "STOP_HUNT ends now with actual seconds")
	s.handle(1, _teacher("set_debug_bugs", {"value": 7}), 6.0)
	s.handle(1, _teacher("reset_room", {"room": 0}), 6.0)
	_check(s.rooms[0].bugs.size() == 7 and s.rooms[1].bugs.size() == 50, "debug bugs override applies to the next fresh setup only")


func _scenario_misc() -> void:
	var s: GameSession = GameSession.new("9999", ["X", "Y"], 0.0)
	_tok = s.teacher_token
	s.attach_creator(1, 0.0)
	s.take_out()
	s.handle(2, _msg("lookup", {"code": "9999"}), 1.0)
	var ro: Array = _of(s.take_out(), "roster", 2)
	_check(ro.size() == 1 and (ro[0]["names"] as Array).size() == 2, "LOOKUP returns the roster")
	var tk: String = _join(s, 3, "X", 1.0)
	s.handle(2, _msg("teacher_rejoin", {"code": "9999", "token": "bad"}), 2.0)
	_check(_of(s.take_out(), "error", 2)[0]["reason"] == "not_teacher", "wrong teacher token refused")
	s.handle(2, _msg("teacher_rejoin", {"code": "9999", "token": _tok}), 2.0)
	var ts: Array = _of(s.take_out(), "teacher_state", 2)
	_check(ts.size() == 1 and (ts[0]["state"]["rooms"] as Array).size() == 1, "teacher rejoin gets full state")
	s.handle(4, _msg("rejoin", {"code": "9999", "token": "zzz"}), 2.0)
	_check(_of(s.take_out(), "error", 4)[0]["reason"] == "bad_token", "bad seat token refused")
	s.handle(1, _teacher("release_seat", {"name": "X"}), 3.0)
	var rel: Array = s.take_out()
	_check(_of(rel, "error", 3).size() == 1 and _of(rel, "error", 3)[0]["reason"] == "bad_token", "released seat's connection told bad_token")
	s.handle(3, _msg("rejoin", {"code": "9999", "token": tk}), 3.0)
	_check(_of(s.take_out(), "error", 3)[0]["reason"] == "bad_token", "old token invalid after release")
	_check(_join(s, 5, "X", 4.0).length() == 32, "released name can be picked again")
	s.on_disconnect(5, 5.0)
	s.take_out()
	_check(s.seats.has("X") and int((s.seats["X"] as Dictionary)["conn"]) == 0, "disconnect keeps the seat")
	s.on_disconnect(1, 6.0)
	s.on_disconnect(2, 6.0)
	_check(not s.is_expired(6.0 + 3.0 * 3600.0 - 1.0) and s.is_expired(6.0 + 3.0 * 3600.0 + 1.0), "session expires 3 hours after the last peer left")
	s.handle(9, {"t": "capture", "id": "oops"}, 7.0)
	s.handle(9, {"t": "configure", "token": s.teacher_token, "config": "bad", "assign": 5}, 7.0)
	_check(s.rooms.size() == 1, "malformed messages ignored")
	_check(GameSession.clean_names(["a", " a ", "b", 5, ""]).size() == 2 and GameSession.clean_names("x").is_empty(), "names trimmed and deduplicated")
	var many: Array = []
	for i: int in range(60):
		many.append("n%d" % i)
	_check(GameSession.clean_names(many).size() == 40, "roster capped at 40")
	s.handle(1, _teacher("configure", {"config": {"hunt_seconds": 5, "rooms": 99}}), 8.0)
	_check(s.config["hunt_seconds"] == StageConfig.HUNT_SECONDS_MIN and s.config["rooms"] == 8 and s.rooms.size() == 8, "config clamped (hunt_seconds, rooms)")
	_check(abs(HabitatLayout.START_POS.distance_to(Vector3(0, 0, 10.0))) < 0.01, "START_POS as assumed by the position test")
