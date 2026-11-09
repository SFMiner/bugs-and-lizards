extends SceneTree
## End-to-end protocol test: starts the server in this process and plays it with clients and bots.
## Run: Godot --headless --path game --script res://tests/protocol_test.gd

const EXPECTED_TOTAL: int = 157
const WATCHDOG_SECONDS: float = 175.0
const PORTS: Array[int] = [3390, 3391, 3392, 3393, 3394, 3395, 3396, 3397, 3398]
const SPEED: float = 5.0 # bot walking speed in this test (the server allows 9 m/s)

var passed: int = 0
var failed: int = 0
var url: String = ""
var server: Node = null


## A raw protocol client: one NetClient plus every message it has received.
class Peer extends RefCounted:
	var net: NetClient = null
	var tree: SceneTree = null
	var inbox: Array[Dictionary] = []
	var all: Array[Dictionary] = []
	var state: Dictionary = {} # latest TEACHER_STATE.state
	var code: String = ""
	var token: String = ""

	func open(t: SceneTree, url: String) -> bool:
		tree = t
		net = NetClient.new()
		t.root.add_child(net)
		net.message_received.connect(_on_msg)
		net.connect_to(url)
		var end: int = Time.get_ticks_msec() + 5000
		while not net.is_open() and Time.get_ticks_msec() < end:
			await t.process_frame
		return net.is_open()

	func _on_msg(msg: Dictionary) -> void:
		all.append(msg)
		inbox.append(msg)
		if msg[Protocol.F_TYPE] == Protocol.TEACHER_STATE:
			state = msg.get(Protocol.F_STATE, {})
			code = str(msg.get(Protocol.F_CODE, code))

	func send(type: String, fields: Dictionary = {}) -> void:
		net.send(type, fields)

	## Teacher command: adds the token.
	func cmd(type: String, fields: Dictionary = {}) -> void:
		var f: Dictionary = fields.duplicate()
		f[Protocol.F_TOKEN] = token
		net.send(type, f)

	func take(type: String) -> Dictionary:
		for i: int in range(inbox.size()):
			if inbox[i][Protocol.F_TYPE] == type:
				var m: Dictionary = inbox[i]
				inbox.remove_at(i)
				return m
		return {}

	func wait_msg(type: String, timeout: float = 5.0) -> Dictionary:
		var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
		while Time.get_ticks_msec() < end:
			var m: Dictionary = take(type)
			if not m.is_empty():
				return m
			await tree.process_frame
		return take(type)

	func wait_state(pred: Callable, timeout: float = 6.0) -> bool:
		var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
		while Time.get_ticks_msec() < end:
			if bool(pred.call(state)):
				return true
			await tree.process_frame
		return bool(pred.call(state))

	func count_of(type: String) -> int:
		var n: int = 0
		for m: Dictionary in all:
			if m[Protocol.F_TYPE] == type:
				n += 1
		return n

	func room(i: int) -> Dictionary:
		var rs: Array = state.get("rooms", [])
		if i < rs.size():
			return rs[i]
		return {}


func _init() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(_watchdog)
	_run()


func _watchdog() -> void:
	print("protocol_test: FAIL watchdog after %d s (%d passed, %d failed)" % [int(WATCHDOG_SECONDS), passed, failed])
	quit(1)


# === CHECK HELPERS ===
func ck(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", label)


func eq(actual: Variant, expected: Variant, label: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		passed += 1
	else:
		failed += 1
		print("  FAIL: %s: expected %s, got %s" % [label, str(expected), str(actual)])


func wait_until(pred: Callable, timeout: float = 6.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())


func frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func make_teacher(names: Array) -> Peer:
	var t: Peer = Peer.new()
	var ok: bool = await t.open(self, url)
	if not ok:
		return t
	t.send(Protocol.CREATE_SESSION, {Protocol.F_NAMES: names})
	var m: Dictionary = await t.wait_msg(Protocol.SESSION_CREATED)
	t.code = str(m.get(Protocol.F_CODE, ""))
	t.token = str(m.get(Protocol.F_TOKEN, ""))
	await t.wait_msg(Protocol.TEACHER_STATE, 3.0)
	return t


func make_bot(code: String, player: String, mode: String, opts: Dictionary = {}) -> BotClient:
	var b: BotClient = BotClient.new()
	root.add_child(b)
	var o: Dictionary = opts.duplicate()
	if not o.has("speed"):
		o["speed"] = SPEED
	if not o.has("reaction_s"):
		o["reaction_s"] = 0.05
	o["record"] = true
	b.start(url, code, player, mode, o)
	await wait_until(func() -> bool: return b.token != "", 5.0)
	return b


func configure(t: Peer, stage: int, rooms: int, bugs: int, lizards: int, assign: Dictionary = {}) -> void:
	var cfg: Dictionary = StageConfig.defaults(stage)
	cfg["rooms"] = rooms
	cfg["bugs_start"] = bugs
	cfg["lizards_start"] = lizards
	cfg["hunt_seconds"] = 15
	t.cmd(Protocol.CONFIGURE, {Protocol.F_CONFIG: cfg, Protocol.F_ASSIGN: assign})


func find_port() -> int:
	for p: int in PORTS:
		var probe: TCPServer = TCPServer.new()
		if probe.listen(p, "127.0.0.1") == OK:
			probe.stop()
			return p
	return -1


# === MAIN ===
func _run() -> void:
	await process_frame
	var port: int = find_port()
	if port < 0:
		print("protocol_test: FAIL no free port in 3390..3398")
		quit(1)
		return
	server = load("res://scripts/server/server_main.gd").new()
	root.add_child(server)
	server.call("start", port)
	url = "ws://127.0.0.1:%d" % port
	await frames(5)
	var t0: int = Time.get_ticks_msec()
	await test_a_stage1()
	await test_b_stage2()
	await test_c_race()
	await test_d_rooms()
	await test_e_rejoin()
	await test_f_bad_inputs()
	print("protocol_test: %d s" % ((Time.get_ticks_msec() - t0) / 1000))
	if failed == 0 and passed == EXPECTED_TOTAL:
		print("protocol_test: PASS %d/%d" % [passed, EXPECTED_TOTAL])
		quit(0)
	else:
		print("protocol_test: FAIL %d failures, %d/%d passed" % [failed, passed, EXPECTED_TOTAL])
		quit(1)


# === PLAYING ROUNDS (shared by a and b) ===
func names_of(lizards: Array) -> Array:
	var out: Array = []
	for liz: Dictionary in lizards:
		out.append(str(liz["student"]))
	out.sort()
	return out


## Plays `rounds` rounds against a session. targets: {student: captures wanted per hunt}. Checks each
## SUMMARY against RoundRules for the captures the bots actually made. Returns one dictionary per round:
## {start_bugs, captured_ids, summary, expected}.
func play_rounds(t: Peer, bots: Dictionary, stage: int, bugs_start: int, lizard_names: Array,
		rounds: int, label: String, observer: BotClient = null) -> Array:
	var infos: Array = []
	var lizards: Array = RoundRules.starting_lizards(lizard_names)
	var bugs_now: int = bugs_start
	for r: int in range(1, rounds + 1):
		var hunters: Array = []
		for liz: Dictionary in lizards:
			hunters.append(str(liz["student"]))
		var lead: BotClient = bots[hunters[0]]
		t.cmd(Protocol.START_HUNT)
		var ok: bool = await wait_until(func() -> bool:
			for h: String in hunters:
				if (bots[h] as BotClient).hunts_started != r:
					return false
			return true, 6.0)
		ck(ok, "%s r%d: every lizard got HUNT_START" % [label, r])
		var start_bugs: Dictionary = lead.start_bugs.duplicate()
		var ids: Array = []
		var reached: bool = await wait_until(func() -> bool:
			for h: String in hunters:
				var b: BotClient = bots[h]
				if b.captures_now < int(b.opts.get("max_captures", 0)):
					return false
			return true, 40.0)
		ck(reached, "%s r%d: bots reached their capture targets" % [label, r])
		var caps: Dictionary = {}
		for h: String in hunters:
			var b: BotClient = bots[h]
			caps[h] = b.captures_now
			ids.append_array(b.hunt_captured_ids)
			eq(b.ok_counts, _seq(b.captures_now), "%s r%d: %s CAPTURE_OK counts" % [label, r, h])
		t.cmd(Protocol.STOP_HUNT)
		var got: bool = await wait_until(func() -> bool:
			for h: String in hunters:
				if (bots[h] as BotClient).summaries.size() < r:
					return false
			return true, 6.0)
		ck(got, "%s r%d: SUMMARY reached every lizard" % [label, r])
		var sm: Dictionary = {}
		if (lead.summaries.size() >= r):
			sm = lead.summaries[r - 1].get(Protocol.F_SUMMARY, {})
		var exp: Dictionary = BotClient.expected_round(stage, r, bugs_now, lizards, caps, 600)
		var rec: Dictionary = (exp["finish"] as Dictionary)["record"]
		var hunt: Dictionary = exp["hunt"]
		eq(int(sm.get("round", -1)), r, "%s r%d: summary round" % [label, r])
		eq(int(sm.get("bugs_start", -1)), bugs_now, "%s r%d: summary bugs_start" % [label, r])
		eq(int(sm.get("BUGS", -1)), int(rec["BUGS"]), "%s r%d: BUGS" % [label, r])
		eq(int(sm.get("bugs_next_start", -1)), int(rec["bugs_next_start"]), "%s r%d: bugs_next_start" % [label, r])
		eq(int(sm.get("LIZARDS", -1)), int(rec["LIZARDS"]), "%s r%d: LIZARDS" % [label, r])
		eq(_sorted(sm.get("starved", [])), names_of(hunt["starved"]), "%s r%d: starved" % [label, r])
		eq(_sorted(sm.get("survived", [])), names_of(hunt["survivors"]), "%s r%d: survived" % [label, r])
		eq(bool(sm.get("ended", false)), bool((exp["finish"] as Dictionary)["ended"]), "%s r%d: ended" % [label, r])
		eq(str(sm.get("end_reason", "?")), str(rec["end_reason"]), "%s r%d: end_reason" % [label, r])
		var sc: Dictionary = sm.get("captures", {})
		var caps_ok: bool = true
		for h: String in hunters:
			if int(sc.get(h, -1)) != int(caps[h]):
				caps_ok = false
		ck(caps_ok, "%s r%d: summary captures match the CAPTURE_OKs" % [label, r])
		eq((sm.get("history", []) as Array).size(), r, "%s r%d: history length" % [label, r])
		if observer != null:
			ck(observer.summaries.size() >= r and observer.summaries[r - 1] == lead.summaries[r - 1],
				"%s r%d: observer got the same SUMMARY" % [label, r])
		infos.append({"start_bugs": start_bugs, "captured_ids": ids, "summary": sm, "expected": exp})
		lizards = (exp["finish"] as Dictionary)["next_lizards"]
		bugs_now = int((exp["finish"] as Dictionary)["next_bugs_start"])
		if bool((exp["finish"] as Dictionary)["ended"]) or r == rounds:
			break
		t.cmd(Protocol.ADVANCE)
		await wait_until(func() -> bool: return t.room(0).get("phase", "") != Protocol.PH_STUDY, 4.0)
	return infos


func _seq(n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(1, n + 1):
		out.append(i)
	return out


func _sorted(a: Variant) -> Array:
	var out: Array = (a as Array).duplicate()
	out.sort()
	return out


# === a) STAGE 1 ===
func test_a_stage1() -> void:
	print("-- a) stage 1")
	var t: Peer = await make_teacher(["Ann", "Ben", "Cy", "Di", "Ed", "Flo"])
	ck(t.code.length() == 4 and t.token != "", "a: session created with a 4-digit code and a token")
	configure(t, 1, 1, 50, 2)
	var bots: Dictionary = {}
	bots["Ann"] = await make_bot(t.code, "Ann", "hunter", {"max_captures": 5})
	bots["Ben"] = await make_bot(t.code, "Ben", "hunter", {"max_captures": 2})
	var cy: BotClient = await make_bot(t.code, "Cy", "idle")
	eq((bots["Ann"] as BotClient).room, 0, "a: Ann joined room 0")
	eq(cy.room, 0, "a: Cy joined room 0")
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["Ann", "Ben"]})
	t.cmd(Protocol.START_HUNT)
	var ann: BotClient = bots["Ann"]
	var ben: BotClient = bots["Ben"]
	await wait_until(func() -> bool: return ann.hunting and ben.hunting, 6.0)
	ck(ann.hunting and ben.hunting, "a: both hunters got HUNT_START")
	eq((ann.start_msg.get(Protocol.F_BUGS, []) as Array).size(), 50, "a: HUNT_START carries 50 bugs")
	await frames(30)
	eq(cy.hunts_started, 0, "a: observer got no HUNT_START")
	ck(_count_type(cy.log, Protocol.ROOM_STATE) > 0, "a: observer received ROOM_STATE")
	ck(not _leaks_bugs(cy.log), "a: observer saw no bug positions during the hunt")
	# out-of-range capture
	await wait_until(func() -> bool: return ann.captures_now >= 5 and ben.captures_now >= 2, 30.0)
	var far_id: int = -1
	var far_d: float = 0.0
	for id: int in ann.bugs:
		var d: float = ann.pos.distance_to(ann.bugs[id])
		if d > far_d:
			far_d = d
			far_id = id
	ck(far_d > 4.0, "a: a bug far from Ann exists")
	var before: int = ann.responses
	ann.raw(Protocol.CAPTURE, {Protocol.F_BUG_ID: far_id})
	await wait_until(func() -> bool: return ann.responses > before, 3.0)
	eq(str(ann.last_response.get("reason", "?")), Protocol.R_RANGE, "a: out-of-range CAPTURE is rejected as range")
	eq(ann.captures_now, 5, "a: the rejected capture did not count")
	# stop, then play the whole stage
	t.cmd(Protocol.STOP_HUNT)
	await wait_until(func() -> bool: return ann.summaries.size() >= 1 and ben.summaries.size() >= 1 and cy.summaries.size() >= 1, 6.0)
	# round 1 summary is checked by play_rounds' logic below; replay it here by hand for round 1
	var exp1: Dictionary = BotClient.expected_round(1, 1, 50, RoundRules.starting_lizards(["Ann", "Ben"]), {"Ann": 5, "Ben": 2}, 600)
	var sm1: Dictionary = {}
	if not ann.summaries.is_empty():
		sm1 = ann.summaries[0].get(Protocol.F_SUMMARY, {})
	var rec1: Dictionary = (exp1["finish"] as Dictionary)["record"]
	eq(int(sm1.get("BUGS", -1)), 43, "a r1: BUGS = 50 - 7")
	eq(int(sm1.get("BUGS", -1)), int(rec1["BUGS"]), "a r1: BUGS matches RoundRules")
	eq(int(sm1.get("bugs_next_start", -1)), int(rec1["bugs_next_start"]), "a r1: bugs_next_start matches RoundRules")
	eq(int(sm1.get("LIZARDS", -1)), int(rec1["LIZARDS"]), "a r1: LIZARDS matches RoundRules")
	eq(_sorted(sm1.get("starved", [])), ["Ben"], "a r1: Ben starved")
	eq(_sorted(sm1.get("survived", [])), ["Ann"], "a r1: Ann survived")
	eq(bool(sm1.get("ended", true)), false, "a r1: not ended")
	ck(cy.summaries.size() >= 1 and cy.summaries[0] == ann.summaries[0], "a r1: observer got the same SUMMARY")
	ck(not _leaks_bugs(cy.log), "a: observer saw no bug positions in the whole round")
	# rounds 2..4: Ann alone
	t.cmd(Protocol.ADVANCE)
	await wait_until(func() -> bool: return t.room(0).get("phase", "") == Protocol.PH_SETUP and int(t.room(0).get("round", 0)) == 2, 4.0)
	eq(int(t.room(0).get("round", 0)), 2, "a: ADVANCE moved the room to round 2")
	var lizards2: Array = (exp1["finish"] as Dictionary)["next_lizards"]
	var lz_names: Array = []
	for liz: Dictionary in lizards2:
		lz_names.append(str(liz["student"]))
	# play_rounds works from round 1, so drive rounds 2-4 inline with the same checks
	var lizards: Array = lizards2
	var bugs_now: int = int((exp1["finish"] as Dictionary)["next_bugs_start"])
	var last_ended: bool = false
	var last_reason: String = ""
	for r: int in range(2, 5):
		t.cmd(Protocol.START_HUNT)
		await wait_until(func() -> bool: return ann.hunts_started == r, 6.0)
		eq(ann.hunts_started, r, "a r%d: Ann got HUNT_START" % r)
		eq(ben.hunts_started, 1, "a r%d: starved Ben got none" % r)
		eq((ann.start_msg.get(Protocol.F_BUGS, []) as Array).size(), bugs_now, "a r%d: bug count at start" % r)
		await wait_until(func() -> bool: return ann.captures_now >= 5, 30.0)
		t.cmd(Protocol.STOP_HUNT)
		await wait_until(func() -> bool: return ann.summaries.size() >= r, 6.0)
		var sm: Dictionary = {}
		if ann.summaries.size() >= r:
			sm = ann.summaries[r - 1].get(Protocol.F_SUMMARY, {})
		var ex: Dictionary = BotClient.expected_round(1, r, bugs_now, lizards, {"Ann": ann.captures_now}, 600)
		var rc: Dictionary = (ex["finish"] as Dictionary)["record"]
		eq(int(sm.get("BUGS", -1)), int(rc["BUGS"]), "a r%d: BUGS" % r)
		eq(int(sm.get("bugs_next_start", -1)), int(rc["bugs_next_start"]), "a r%d: bugs_next_start" % r)
		eq(int(sm.get("LIZARDS", -1)), int(rc["LIZARDS"]), "a r%d: LIZARDS" % r)
		eq(_sorted(sm.get("survived", [])), ["Ann"], "a r%d: survived" % r)
		eq(_sorted(sm.get("starved", [])), [], "a r%d: starved" % r)
		eq(bool(sm.get("ended", false)), bool((ex["finish"] as Dictionary)["ended"]), "a r%d: ended" % r)
		eq(str(sm.get("end_reason", "?")), str(rc["end_reason"]), "a r%d: end_reason" % r)
		eq((sm.get("history", []) as Array).size(), r, "a r%d: history length" % r)
		last_ended = bool(sm.get("ended", false))
		last_reason = str(sm.get("end_reason", "?"))
		lizards = (ex["finish"] as Dictionary)["next_lizards"]
		bugs_now = int((ex["finish"] as Dictionary)["next_bugs_start"])
		if r < 4:
			t.cmd(Protocol.ADVANCE)
			await wait_until(func() -> bool: return t.room(0).get("phase", "") == Protocol.PH_SETUP and int(t.room(0).get("round", 0)) == r + 1, 4.0)
	ck(last_ended, "a: stage 1 ended after round 4")
	eq(last_reason, RoundRules.END_ROUNDS, "a: end_reason is rounds")
	await wait_until(func() -> bool: return t.room(0).get("phase", "") == Protocol.PH_ENDED, 4.0)
	eq(str(t.room(0).get("phase", "?")), Protocol.PH_ENDED, "a: teacher state shows the room ended")
	_free_all([ann, ben, cy])


func _free_all(bs: Array) -> void:
	for b: BotClient in bs:
		b.disconnect_now()


func _count_type(log: Array, type: String) -> int:
	var n: int = 0
	for m: Dictionary in log:
		if m[Protocol.F_TYPE] == type:
			n += 1
	return n


## True if any message to a non-hunter carries bug positions (a "bugs" key or HUNT_START).
func _leaks_bugs(log: Array) -> bool:
	for m: Dictionary in log:
		if m[Protocol.F_TYPE] == Protocol.HUNT_START or JSON.stringify(m).contains("\"bugs\":"):
			return true
	return false


# === b) STAGE 2 ===
func test_b_stage2() -> void:
	print("-- b) stage 2")
	var t: Peer = await make_teacher(["Ann", "Ben", "Cy"])
	configure(t, 2, 1, 50, 2)
	var bots: Dictionary = {}
	bots["Ann"] = await make_bot(t.code, "Ann", "hunter", {"max_captures": 5})
	bots["Ben"] = await make_bot(t.code, "Ben", "hunter", {"max_captures": 2})
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["Ann", "Ben"]})
	var infos: Array = await play_rounds(t, bots, 2, 50, ["Ann", "Ben"], 2, "b")
	eq(infos.size(), 2, "b: two rounds were played")
	if infos.size() == 2:
		var s1: Dictionary = infos[0]["summary"]
		var s2_start: Dictionary = infos[1]["start_bugs"]
		eq(int(s1.get("BUGS", -1)), 43, "b r1: uncaught bugs = 43")
		eq(int(s1.get("bugs_next_start", -1)), 129, "b r1: bugs_next_start = uncaught * 3")
		eq(s2_start.size(), 129, "b r2: HUNT_START has exactly bugs_next_start bugs")
		var seen: Dictionary = {}
		for id: int in s2_start:
			seen[_pos_key(s2_start[id])] = true
		var captured: Array = infos[0]["captured_ids"]
		var kept: bool = true
		var kept_n: int = 0
		for id: int in (infos[0]["start_bugs"] as Dictionary):
			if captured.has(id):
				continue
			kept_n += 1
			if not seen.has(_pos_key((infos[0]["start_bugs"] as Dictionary)[id])):
				kept = false
		eq(kept_n, 43, "b: 43 uncaught bugs were tracked")
		ck(kept, "b r2: every uncaught bug is still at its old position")
	for b: Variant in bots.values():
		(b as BotClient).disconnect_now()


func _pos_key(v: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]


# === c) RACE ===
func test_c_race() -> void:
	print("-- c) race (20 tries)")
	var t: Peer = await make_teacher(["R1", "R2"])
	configure(t, 1, 1, 50, 2)
	var r1: BotClient = await make_bot(t.code, "R1", "racer")
	var r2: BotClient = await make_bot(t.code, "R2", "racer")
	var wins: int = 0
	for i: int in range(20):
		t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["R1", "R2"]})
		t.cmd(Protocol.START_HUNT)
		var up: bool = await wait_until(func() -> bool: return r1.hunts_started == i + 1 and r2.hunts_started == i + 1, 6.0)
		if not up:
			ck(false, "c try %d: both racers got HUNT_START" % i)
			break
		var best: int = -1
		var best_d: float = INF
		for id: int in r1.bugs:
			var d: float = r1.pos.distance_to(r1.bugs[id])
			if d < best_d:
				best_d = d
				best = id
		var walk: float = maxf(maxf(Vector2(r1.bugs[best].x - r1.pos.x, r1.bugs[best].z - r1.pos.z).length(),
			Vector2(r1.bugs[best].x - r2.pos.x, r1.bugs[best].z - r2.pos.z).length()) - BotClient.ARRIVE, 0.0) / SPEED
		var at: int = Time.get_ticks_msec() + int(walk * 1000.0) + 400
		r1.opts["bug_id"] = best
		r2.opts["bug_id"] = best
		r1.opts["at_msec"] = at
		r2.opts["at_msec"] = at
		await wait_until(func() -> bool: return r1.responses >= 1 and r2.responses >= 1, 8.0)
		var oks: int = 0
		var gone: int = 0
		for b: BotClient in [r1, r2]:
			if bool(b.last_response.get("ok", false)):
				oks += 1
			elif b.last_response.get("reason", "") == Protocol.R_GONE:
				gone += 1
		var win: bool = oks == 1 and gone == 1
		if win:
			wins += 1
		ck(win, "c try %d: one CAPTURE_OK and one gone (ok %d, gone %d)" % [i, oks, gone])
		t.cmd(Protocol.STOP_HUNT)
		await wait_until(func() -> bool: return r1.summaries.size() >= i + 1 and r2.summaries.size() >= i + 1, 5.0)
		t.cmd(Protocol.RESET_ROOM, {Protocol.F_ROOM: 0})
		await t.wait_state(func(s: Dictionary) -> bool:
			var rs: Array = s.get("rooms", [])
			return not rs.is_empty() and rs[0].get("phase", "") == Protocol.PH_SETUP and int(rs[0].get("round", 0)) == 1, 4.0)
	eq(wins, 20, "c: 20 of 20 races produced exactly one winner")
	r1.disconnect_now()
	r2.disconnect_now()


# === d) ROOMS ===
func test_d_rooms() -> void:
	print("-- d) isolation and reset")
	var t: Peer = await make_teacher(["A0", "A1", "B0", "B1"])
	configure(t, 1, 2, 50, 2, {"A0": 0, "A1": 0, "B0": 1, "B1": 1})
	var a0: BotClient = await make_bot(t.code, "A0", "hunter", {"max_captures": 5})
	var a1: BotClient = await make_bot(t.code, "A1", "idle")
	var b0: BotClient = await make_bot(t.code, "B0", "hunter", {"max_captures": 0})
	var b1: BotClient = await make_bot(t.code, "B1", "idle")
	eq([a0.room, a1.room, b0.room, b1.room], [0, 0, 1, 1], "d: students joined their assigned rooms")
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["A0", "A1"]})
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 1, Protocol.F_LIZARDS: ["B0", "B1"]})
	t.cmd(Protocol.START_HUNT)
	await wait_until(func() -> bool: return a0.hunting and b0.hunting, 6.0)
	await wait_until(func() -> bool: return a0.captures_now >= 5, 30.0)
	await t.wait_state(func(s: Dictionary) -> bool:
		var rs: Array = s.get("rooms", [])
		return rs.size() == 2 and int(rs[0].get("caught", -1)) == 5, 4.0)
	eq(int(t.room(0).get("caught", -1)), 5, "d r1: room 0 caught 5")
	eq(int(t.room(1).get("caught", -1)), 0, "d r1: room 1 caught 0 while room 0 captured")
	eq(int(t.room(1).get("remaining", -1)), 50, "d r1: room 1 still has 50 bugs")
	eq(b0.captures_now, 0, "d r1: room 1 hunter has no captures")
	b0.opts["max_captures"] = 5
	await wait_until(func() -> bool: return b0.captures_now >= 5, 30.0)
	await t.wait_state(func(s: Dictionary) -> bool: return int(((s.get("rooms", []) as Array)[1] as Dictionary).get("caught", -1)) == 5, 4.0)
	eq(int(t.room(1).get("caught", -1)), 5, "d r1: room 1 caught 5")
	eq(int(t.room(0).get("caught", -1)), 5, "d r1: room 0 still caught 5")
	t.cmd(Protocol.STOP_HUNT)
	await wait_until(func() -> bool: return a0.summaries.size() >= 1 and b0.summaries.size() >= 1, 6.0)
	t.cmd(Protocol.ADVANCE)
	await t.wait_state(func(s: Dictionary) -> bool:
		var rs: Array = s.get("rooms", [])
		return rs.size() == 2 and int(rs[0].get("round", 0)) == 2 and int(rs[1].get("round", 0)) == 2 and rs[0].get("phase", "") == Protocol.PH_SETUP, 4.0)
	b0.opts["max_captures"] = 2
	t.cmd(Protocol.START_HUNT)
	await wait_until(func() -> bool: return a0.hunts_started == 2 and b0.hunts_started == 2, 6.0)
	await wait_until(func() -> bool: return a0.captures_now >= 5 and b0.captures_now >= 2, 30.0)
	await t.wait_state(func(s: Dictionary) -> bool:
		var rs: Array = s.get("rooms", [])
		return rs.size() == 2 and int(rs[0].get("caught", -1)) == 5 and int(rs[1].get("caught", -1)) == 2, 4.0)
	eq(int(t.room(0).get("remaining", -1)), 40, "d r2: room 0 has 40 bugs left")
	eq(int(t.room(1).get("remaining", -1)), 43, "d r2: room 1 has 43 bugs left")
	var snap: Dictionary = (t.room(1)).duplicate(true)
	t.cmd(Protocol.RESET_ROOM, {Protocol.F_ROOM: 0})
	await t.wait_state(func(s: Dictionary) -> bool:
		var rs: Array = s.get("rooms", [])
		return rs.size() == 2 and int(rs[0].get("round", 0)) == 1, 4.0)
	await frames(20)
	eq(int(t.room(0).get("round", 0)), 1, "d reset: room 0 is back to round 1")
	eq((t.room(0).get("history", []) as Array).size(), 0, "d reset: room 0 history cleared")
	eq(int(t.room(1).get("round", 0)), int(snap.get("round", -1)), "d reset: room 1 round unchanged")
	eq((t.room(1).get("history", []) as Array).size(), (snap.get("history", []) as Array).size(), "d reset: room 1 history unchanged")
	eq(int(t.room(1).get("remaining", -1)), int(snap.get("remaining", -2)), "d reset: room 1 bug count unchanged")
	eq(int(t.room(1).get("caught", -1)), int(snap.get("caught", -2)), "d reset: room 1 caught unchanged")
	eq(str(t.room(1).get("phase", "?")), str(snap.get("phase", "!")), "d reset: room 1 phase unchanged")
	eq((snap.get("history", []) as Array).size(), 1, "d reset: room 1 had one history record")
	for b: BotClient in [a0, a1, b0, b1]:
		b.disconnect_now()


# === e) REJOIN ===
func test_e_rejoin() -> void:
	print("-- e) rejoin")
	var t: Peer = await make_teacher(["H1", "H2", "H3"])
	configure(t, 1, 1, 50, 2)
	var h1: BotClient = await make_bot(t.code, "H1", "hunter", {"max_captures": 3})
	var h2: BotClient = await make_bot(t.code, "H2", "hunter", {"max_captures": 2})
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["H1", "H2"]})
	t.cmd(Protocol.START_HUNT)
	await wait_until(func() -> bool: return h1.captures_now >= 3 and h2.captures_now >= 2, 30.0)
	eq(h1.captures_now, 3, "e: H1 has 3 accepted captures")
	var tok: String = h1.token
	var gone_ids: Array[int] = h1.hunt_captured_ids.duplicate()
	h1.disconnect_now()
	await wait_until(func() -> bool: return not h1.net.is_open(), 3.0)
	await frames(30)
	var h1b: BotClient = await make_bot(t.code, "H1", "hunter", {"token": tok, "max_captures": 5})
	await wait_until(func() -> bool: return h1b.hunts_started >= 1, 5.0)
	eq(h1b.joined_name, "H1", "e: REJOIN answered JOINED with the name")
	eq(h1b.hunts_started, 1, "e: REJOIN mid-hunt sent HUNT_START")
	eq(int(h1b.start_msg.get(Protocol.F_COUNT, -1)), 3, "e: HUNT_START count is 3")
	var leaked: bool = false
	for id: int in gone_ids:
		if h1b.start_bugs.has(id):
			leaked = true
	ck(not leaked, "e: the 3 captured bugs are not in the rejoin HUNT_START")
	eq(h1b.start_bugs.size(), 45, "e: rejoin HUNT_START lists the 45 remaining bugs")
	await wait_until(func() -> bool: return h1b.captures_now >= 5, 30.0)
	eq(h1b.ok_counts, [4, 5] as Array[int], "e: captures after rejoin continue from 3")
	t.cmd(Protocol.STOP_HUNT)
	await wait_until(func() -> bool: return h1b.summaries.size() >= 1 and h2.summaries.size() >= 1, 6.0)
	var sm: Dictionary = {}
	if not h1b.summaries.is_empty():
		sm = h1b.summaries[0].get(Protocol.F_SUMMARY, {})
	var caps: Dictionary = sm.get("captures", {})
	eq(int(caps.get("H1", -1)), 5, "e: SUMMARY credits H1 with 3 + 2 captures")
	eq(int(caps.get("H2", -1)), 2, "e: SUMMARY credits H2 with 2 captures")
	eq(int(sm.get("BUGS", -1)), 43, "e: BUGS is 50 - 7")
	h1b.disconnect_now()
	h2.disconnect_now()


# === f) BAD INPUTS ===
func test_f_bad_inputs() -> void:
	print("-- f) bad inputs")
	var t: Peer = await make_teacher(["Ann", "Bob", "Cat"])
	configure(t, 1, 1, 50, 1)
	var bad_code: String = "0000" if t.code != "0000" else "9999"
	var p: Peer = Peer.new()
	await p.open(self, url)
	p.send(Protocol.LOOKUP, {Protocol.F_CODE: bad_code})
	var m: Dictionary = await p.wait_msg(Protocol.ERROR)
	eq(str(m.get(Protocol.F_REASON, "?")), Protocol.R_BAD_CODE, "f: LOOKUP with a bad code")
	p.send(Protocol.PICK_NAME, {Protocol.F_CODE: bad_code, Protocol.F_NAME: "Ann"})
	m = await p.wait_msg(Protocol.ERROR)
	eq(str(m.get(Protocol.F_REASON, "?")), Protocol.R_BAD_CODE, "f: PICK_NAME with a bad code")
	p.send(Protocol.REJOIN, {Protocol.F_CODE: t.code, Protocol.F_TOKEN: "no-such-token"})
	m = await p.wait_msg(Protocol.ERROR)
	eq(str(m.get(Protocol.F_REASON, "?")), Protocol.R_BAD_TOKEN, "f: REJOIN with a bad token")
	# taken name
	var ann: BotClient = await make_bot(t.code, "Ann", "idle")
	ck(ann.token != "", "f: Ann joined")
	p.send(Protocol.LOOKUP, {Protocol.F_CODE: t.code})
	var ros: Dictionary = await p.wait_msg(Protocol.ROSTER)
	ck(not ros.is_empty(), "f: LOOKUP with a good code returns a ROSTER")
	p.send(Protocol.PICK_NAME, {Protocol.F_CODE: t.code, Protocol.F_NAME: "Ann"})
	m = await p.wait_msg(Protocol.ERROR)
	eq(str(m.get(Protocol.F_REASON, "?")), Protocol.R_NAME_TAKEN, "f: PICK_NAME of a taken name")
	# teacher command with the wrong token
	t.send(Protocol.START_HUNT, {Protocol.F_TOKEN: "wrong"})
	m = await t.wait_msg(Protocol.ERROR)
	eq(str(m.get(Protocol.F_REASON, "?")), Protocol.R_NOT_TEACHER, "f: START_HUNT with a wrong token")
	var errs_before: int = ann.errors.size()
	ann.raw(Protocol.CONFIGURE, {Protocol.F_TOKEN: ann.token, Protocol.F_CONFIG: {"stage": 3}})
	await wait_until(func() -> bool: return ann.errors.size() > errs_before, 3.0)
	eq(str(ann.errors.back().get(Protocol.F_REASON, "?")) if not ann.errors.is_empty() else "none", Protocol.R_NOT_TEACHER, "f: a student token is not a teacher token")
	await frames(10)
	ck(ann.hunts_started == 0 and str(t.room(0).get("phase", "")) != Protocol.PH_HUNT, "f: the wrong-token START_HUNT did nothing")
	# garbage frames
	var g: Peer = Peer.new()
	await g.open(self, url)
	var junk: Array[String] = ["not json at all", "{}", "[1,2,3]", "{\"t\": 5}", "{\"t\": \"nonsense_type\"}",
		"null", "{\"t\": \"capture\", \"id\": \"abc\"}", "{\"t\": \"pos\", \"p\": \"x\", \"yaw\": []}",
		"{\"t\": \"pick_name\"}"]
	for j: String in junk:
		g.net._ws.send_text(j)
		await frames(1)
	g.net._ws.put_packet(PackedByteArray([0, 1, 2, 3, 255]))
	await frames(5)
	g.send(Protocol.PING, {Protocol.F_TIME: 123})
	var pong: Dictionary = await g.wait_msg(Protocol.PONG)
	ck(not pong.is_empty() and g.net.is_open(), "f: the server survived garbage frames and still answers PING")
	var q: Peer = Peer.new()
	await q.open(self, url)
	q.send(Protocol.LOOKUP, {Protocol.F_CODE: t.code})
	var ros2: Dictionary = await q.wait_msg(Protocol.ROSTER)
	ck(not ros2.is_empty(), "f: a new client can still LOOKUP after the garbage")
	# a 50 m position jump is ignored
	var hx: BotClient = await make_bot(t.code, "Bob", "idle")
	t.cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: 0, Protocol.F_LIZARDS: ["Bob"]})
	t.cmd(Protocol.START_HUNT)
	await wait_until(func() -> bool: return hx.hunting, 6.0)
	ck(hx.hunting, "f: Bob got HUNT_START")
	var far_id: int = -1
	var far_d: float = 0.0
	for id: int in hx.bugs:
		var d: float = hx.pos.distance_to(hx.bugs[id])
		if d > far_d:
			far_d = d
			far_id = id
	ck(far_d > 8.0, "f: a bug more than 8 m from the start exists")
	hx.raw(Protocol.POSITION, {Protocol.F_POS: [0.0, 0.0, 60.0], Protocol.F_YAW: 0.0})
	var fp: Vector3 = hx.bugs[far_id]
	hx.raw(Protocol.POSITION, {Protocol.F_POS: Protocol.vec_to_wire(fp), Protocol.F_YAW: 0.0})
	hx.raw(Protocol.CAPTURE, {Protocol.F_BUG_ID: far_id})
	await wait_until(func() -> bool: return hx.responses >= 1, 3.0)
	eq(str(hx.last_response.get("reason", "?")), Protocol.R_RANGE, "f: capture after a position jump is rejected as range")
	eq(hx.captures_now, 0, "f: no capture was counted")
	t.cmd(Protocol.STOP_HUNT)
	for b: BotClient in [ann, hx]:
		b.disconnect_now()
