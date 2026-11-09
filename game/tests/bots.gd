extends SceneTree
## Bot runner for manual and pressure tests. Run:
##   Godot --headless --path game --script res://tests/bots.gd
## Env: BL_SERVER_URL (ws://127.0.0.1:3311), BL_CODE, BL_TEACHER=1 (create and drive a session),
## BL_STAGE (2), BL_ROOMS (1), BL_BUGS (stage default), BL_HUNT (45), BL_ROUNDS (4), BL_BOTS (3),
## BL_MODE (hunter|sweeper|idle, hunter), BL_MINUTES (0 = until rounds are done), BL_LIZARDS
## (lizards per room; stage default), BL_MISS_COOLDOWN (sweeper, 0.0).

var url: String = "ws://127.0.0.1:3311"
var code: String = ""
var teacher_on: bool = false
var stage: int = 2
var rooms: int = 1
var bugs_start: int = 0
var hunt_seconds: int = 45
var rounds: int = 4
var bot_count: int = 3
var mode: String = "hunter"
var minutes: float = 0.0
var lizards_per_room: int = 0
var miss_cooldown: float = 0.0

var net: NetClient = null
var teacher_token: String = ""
var tstate: Dictionary = {}
var bots: Array[BotClient] = []
var room_members: Array = [] # per room: [names]
var room_lizards: Array = [] # per room: [names]


func _init() -> void:
	_run()


func _env(key: String, fallback: String) -> String:
	var v: String = OS.get_environment(key)
	return v if v != "" else fallback


func _wait(pred: Callable, timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())


func _rooms_state() -> Array:
	return tstate.get("rooms", [])


func _all_rooms(pred: Callable) -> bool:
	var rs: Array = _rooms_state()
	if rs.is_empty():
		return false
	for r: Dictionary in rs:
		if not bool(pred.call(r)):
			return false
	return true


func _on_teacher_msg(msg: Dictionary) -> void:
	if msg[Protocol.F_TYPE] == Protocol.SESSION_CREATED:
		code = str(msg.get(Protocol.F_CODE, ""))
		teacher_token = str(msg.get(Protocol.F_TOKEN, ""))
	elif msg[Protocol.F_TYPE] == Protocol.TEACHER_STATE:
		tstate = msg.get(Protocol.F_STATE, {})
	elif msg[Protocol.F_TYPE] == Protocol.ERROR:
		print("teacher error: ", msg)


func _cmd(type: String, fields: Dictionary = {}) -> void:
	var f: Dictionary = fields.duplicate()
	f[Protocol.F_TOKEN] = teacher_token
	net.send(type, f)


func _run() -> void:
	await process_frame
	url = _env("BL_SERVER_URL", url)
	code = _env("BL_CODE", "")
	teacher_on = _env("BL_TEACHER", "0") == "1"
	stage = int(_env("BL_STAGE", "2"))
	rooms = maxi(int(_env("BL_ROOMS", "1")), 1)
	bugs_start = int(_env("BL_BUGS", "0"))
	hunt_seconds = int(_env("BL_HUNT", "45"))
	rounds = int(_env("BL_ROUNDS", "4"))
	bot_count = int(_env("BL_BOTS", "3"))
	mode = _env("BL_MODE", "hunter")
	minutes = float(_env("BL_MINUTES", "0"))
	lizards_per_room = int(_env("BL_LIZARDS", "0"))
	miss_cooldown = float(_env("BL_MISS_COOLDOWN", "0"))
	var names: Array = []
	for i: int in range(bot_count):
		names.append("Bot%02d" % (i + 1))
	var cfg: Dictionary = StageConfig.defaults(stage)
	if teacher_on and code == "":
		net = NetClient.new()
		root.add_child(net)
		net.message_received.connect(_on_teacher_msg)
		net.connect_to(url)
		if not await _wait(func() -> bool: return net.is_open(), 5.0):
			print("bots: cannot connect to ", url)
			quit(1)
			return
		net.send(Protocol.CREATE_SESSION, {Protocol.F_NAMES: names})
		var got: bool = await _wait(func() -> bool: return teacher_token != "", 5.0)
		if not got:
			print("bots: no SESSION_CREATED after CREATE_SESSION")
			quit(1)
			return
	var assign: Dictionary = {}
	for i: int in range(bot_count):
		assign[names[i]] = i % rooms
	for r: int in range(rooms):
		room_members.append([])
		room_lizards.append([])
	for i: int in range(bot_count):
		(room_members[i % rooms] as Array).append(names[i])
	if lizards_per_room <= 0:
		lizards_per_room = int(cfg["lizards_start"])
	for r: int in range(rooms):
		var members: Array = room_members[r]
		for k: int in range(mini(lizards_per_room, members.size())):
			(room_lizards[r] as Array).append(members[k])
	print("bots: code %s, %d bots, mode %s" % [code, bot_count, mode])
	for i: int in range(bot_count):
		var b: BotClient = BotClient.new()
		root.add_child(b)
		var o: Dictionary = {"miss_cooldown": miss_cooldown, "record": false}
		b.start(url, code, names[i], mode, o)
		bots.append(b)
	if not await _wait(func() -> bool: return _all_joined(), 15.0):
		print("bots: not all bots joined")
	if teacher_on:
		await _drive(cfg, assign)
	else:
		await _passive()
	_report()
	quit(0)


func _all_joined() -> bool:
	for b: BotClient in bots:
		if b.token == "":
			return false
	return true


func _passive() -> void:
	var limit: float = minutes * 60.0 if minutes > 0.0 else 1800.0
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		var all_done: bool = true
		for b: BotClient in bots:
			if b.summaries.is_empty() or not bool((b.summaries.back()["summary"] as Dictionary).get("ended", false)):
				all_done = false
		if all_done and minutes <= 0.0:
			return
		await process_frame


func _drive(cfg: Dictionary, assign: Dictionary) -> void:
	cfg["rooms"] = rooms
	cfg["hunt_seconds"] = hunt_seconds
	cfg["lizards_start"] = lizards_per_room
	if bugs_start > 0:
		cfg["bugs_start"] = bugs_start
	_cmd(Protocol.CONFIGURE, {Protocol.F_CONFIG: cfg, Protocol.F_ASSIGN: assign})
	for r: int in range(rooms):
		_cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: r, Protocol.F_LIZARDS: room_lizards[r]})
	await _wait(func() -> bool: return false, 0.5)
	var deadline: int = Time.get_ticks_msec() + int(minutes * 60000.0) if minutes > 0.0 else 0
	var round_no: int = 0
	var per_room_lizards: Array = []
	for r: int in range(rooms):
		per_room_lizards.append(RoundRules.starting_lizards(room_lizards[r]))
	var room_bugs: Array = []
	for r: int in range(rooms):
		room_bugs.append(int(cfg["bugs_start"]))
	var room_done: Array = []
	for r: int in range(rooms):
		room_done.append(false)
	while round_no < rounds or (deadline > 0 and Time.get_ticks_msec() < deadline):
		if deadline > 0 and Time.get_ticks_msec() >= deadline:
			break
		round_no += 1
		var seen: Array = []
		for b: BotClient in bots:
			seen.append(b.summaries.size())
		_cmd(Protocol.START_HUNT)
		var started: bool = await _wait(func() -> bool: return _all_rooms(func(r: Dictionary) -> bool:
			return r["phase"] != Protocol.PH_SETUP), 10.0)
		if not started:
			print("bots: hunt did not start")
		var finished: bool = await _wait(func() -> bool: return _all_rooms(func(r: Dictionary) -> bool:
			return r["phase"] == Protocol.PH_STUDY or r["phase"] == Protocol.PH_ENDED), float(hunt_seconds) + 20.0)
		if not finished:
			print("bots: hunt did not finish in time")
			break
		await _wait(func() -> bool: return false, 0.5) # let the summaries arrive
		# print and recompute each room's record
		for r: int in range(rooms):
			if room_done[r]:
				continue
			var sm: Dictionary = _summary_for_room(r, round_no)
			if sm.is_empty():
				print("round %d room %d: no summary received" % [round_no, r])
				continue
			var expect: Dictionary = BotClient.expected_round(stage, round_no, room_bugs[r], per_room_lizards[r],
				sm.get("captures", {}), int(cfg["bug_budget"]))
			var rec: Dictionary = sm["history"].back()
			var want: Dictionary = (expect["finish"] as Dictionary)["record"]
			var same: bool = true
			for key: String in ["BUGS", "bugs_next_start", "LIZARDS", "end_reason"]:
				if rec.get(key) != want.get(key):
					same = false
			print("round %d room %d: record %s" % [round_no, r, JSON.stringify(rec)])
			print("round %d room %d: RoundRules %s -> %s" % [round_no, r, JSON.stringify(want), "match" if same else "MISMATCH"])
			per_room_lizards[r] = (expect["finish"] as Dictionary)["next_lizards"]
			room_bugs[r] = int((expect["finish"] as Dictionary)["next_bugs_start"])
			room_done[r] = bool(sm.get("ended", false))
		var all_ended: bool = true
		for r: int in range(rooms):
			if not room_done[r]:
				all_ended = false
		if all_ended and deadline > 0 and Time.get_ticks_msec() < deadline:
			# Pressure test: keep hunting until the deadline by resetting every room to round 1.
			for r: int in range(rooms):
				_cmd(Protocol.RESET_ROOM, {Protocol.F_ROOM: r})
				_cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: r, Protocol.F_LIZARDS: room_lizards[r]})
				per_room_lizards[r] = RoundRules.starting_lizards(room_lizards[r])
				room_bugs[r] = int(cfg["bugs_start"])
				room_done[r] = false
			for b: BotClient in bots:
				b.summaries.clear()
			round_no = 0
			print("bots: all rooms ended; reset for another run")
			await _wait(func() -> bool: return false, 1.0)
			continue
		if all_ended:
			break
		if round_no >= rounds and deadline == 0:
			break
		_cmd(Protocol.ADVANCE)
		await _wait(func() -> bool: return _all_rooms(func(r: Dictionary) -> bool:
			return r["phase"] != Protocol.PH_STUDY), 10.0)


func _summary_for_room(r: int, round_no: int) -> Dictionary:
	for b: BotClient in bots:
		if b.room != r:
			continue
		for s: Dictionary in b.summaries:
			var sm: Dictionary = s.get(Protocol.F_SUMMARY, {})
			if int(sm.get("round", 0)) == round_no:
				return sm
	return {}


func _report() -> void:
	for b: BotClient in bots:
		var st: Dictionary = b.stats()
		print("bot %s: captures per hunt %s presses %d rejected %d" % [b.player_name,
			str(st["captures_per_hunt"]), st["presses"], st["rejected"]])
	for r: int in range(rooms):
		var last: Dictionary = {}
		for b: BotClient in bots:
			if b.room == r and not b.summaries.is_empty():
				last = (b.summaries.back() as Dictionary).get(Protocol.F_SUMMARY, {})
		print("room %d history: %s" % [r, JSON.stringify(last.get("history", []))])
	print("bots: done")
