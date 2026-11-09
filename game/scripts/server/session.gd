class_name GameSession
extends RefCounted
## One classroom session: roster, seats, tokens, rooms, config, teacher checks. Pure (no sockets, no real clock):
## feed it messages with handle(conn, msg, now_s) and tick(now_s), then drain take_out() for what to send.
## An outgoing entry is {"to": int connection id, "t": message type, "f": fields Dictionary}.

const MAX_ROOMS: int = 8
const MAX_NAMES: int = 40
const MAX_NAME_LEN: int = 40
const IDLE_DROP_S: float = 3.0 * 3600.0
const TEACHER_BC_S: float = 0.5
const ROOM_BC_S: float = 1.0
const TEACHER_CMDS: Array[String] = [Protocol.CONFIGURE, Protocol.SET_LIZARDS, Protocol.START_HUNT, Protocol.STOP_HUNT,
	Protocol.ADVANCE, Protocol.PAUSE_ROOM, Protocol.RESET_ROOM, Protocol.RELEASE_SEAT, Protocol.SET_DEBUG_BUGS]

var code: String = ""
var teacher_token: String = ""
var roster: Array[String] = []
var config: Dictionary = {}
var assign: Dictionary = {} # name -> room index
var rooms: Array[GameRoom] = []
var seats: Dictionary = {} # name -> {token: String, conn: int (0 = disconnected)}
var teacher_conns: Array[int] = []
var student_conns: Dictionary = {} # conn -> name
var log_dir: String = "" # "" = no catch log
var debug_bugs: int = -1
var idle_since: float = 0.0
var out: Array = []
var _dirty: bool = false
var _last_teacher_bc: float = -100.0
var _last_room_bc: float = -100.0


func _init(p_code: String, names: Variant, now_s: float) -> void:
	code = p_code
	teacher_token = make_token()
	roster = clean_names(names)
	config = StageConfig.defaults(1)
	idle_since = now_s
	_apply_config({}, {})


static func make_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func clean_names(v: Variant) -> Array[String]:
	var res: Array[String] = []
	if typeof(v) != TYPE_ARRAY:
		return res
	for x: Variant in (v as Array):
		if typeof(x) != TYPE_STRING:
			continue
		var s: String = (x as String).strip_edges().substr(0, MAX_NAME_LEN).strip_edges()
		if s != "" and not res.has(s) and res.size() < MAX_NAMES:
			res.append(s)
	return res


# === PUBLIC ENTRY POINTS ===
func take_out() -> Array:
	var o: Array = out
	out = []
	return o


func has_conn(conn: int) -> bool:
	return teacher_conns.has(conn) or student_conns.has(conn)


func is_expired(now_s: float) -> bool:
	return _connected_count() == 0 and now_s - idle_since >= IDLE_DROP_S


## The creating connection becomes a teacher.
func attach_creator(conn: int, now_s: float) -> void:
	_unbind(conn)
	teacher_conns.append(conn)
	_send(conn, Protocol.SESSION_CREATED, {Protocol.F_CODE: code, Protocol.F_TOKEN: teacher_token})
	_send(conn, Protocol.TEACHER_STATE, {Protocol.F_CODE: code, Protocol.F_STATE: teacher_state(now_s)})


func on_disconnect(conn: int, now_s: float) -> void:
	if teacher_conns.has(conn):
		teacher_conns.erase(conn)
	if student_conns.has(conn):
		var n: String = student_conns[conn]
		student_conns.erase(conn)
		var seat: Dictionary = seats.get(n, {})
		if not seat.is_empty() and int(seat["conn"]) == conn:
			seat["conn"] = 0
		_dirty = true
	if _connected_count() == 0:
		idle_since = now_s
	_flush(now_s)


func handle(conn: int, msg: Dictionary, now_s: float) -> void:
	var t: String = str(msg.get(Protocol.F_TYPE, ""))
	if TEACHER_CMDS.has(t):
		var own_seat: bool = t == Protocol.RELEASE_SEAT and student_conns.get(conn, "") == _str(msg, Protocol.F_NAME)
		if not own_seat and not _is_teacher(msg):
			_error(conn, Protocol.R_NOT_TEACHER)
			return
	match t:
		Protocol.TEACHER_REJOIN:
			_on_teacher_rejoin(conn, msg, now_s)
		Protocol.LOOKUP:
			_send(conn, Protocol.ROSTER, {Protocol.F_CODE: code, Protocol.F_NAMES: _roster_wire()})
		Protocol.PICK_NAME:
			_on_pick(conn, msg, now_s)
		Protocol.REJOIN:
			_on_rejoin(conn, msg, now_s)
		Protocol.POSITION:
			_on_position(conn, msg, now_s)
		Protocol.CAPTURE:
			_on_capture(conn, msg, now_s)
		Protocol.CONFIGURE:
			_on_configure(msg)
		Protocol.SET_LIZARDS:
			var r: int = _room_index(msg)
			if r >= 0 and typeof(msg.get(Protocol.F_LIZARDS)) == TYPE_ARRAY:
				if rooms[r].set_lizards(msg[Protocol.F_LIZARDS]):
					_dirty = true
		Protocol.START_HUNT:
			_on_start_hunt(now_s)
		Protocol.STOP_HUNT:
			for room: GameRoom in rooms:
				if room.phase == Protocol.PH_HUNT:
					_finish_hunt(room, now_s, true)
		Protocol.ADVANCE:
			for room: GameRoom in rooms:
				if room.advance():
					_dirty = true
		Protocol.PAUSE_ROOM:
			var r2: int = _room_index(msg)
			if r2 >= 0:
				rooms[r2].paused = bool(msg.get(Protocol.F_VALUE, false))
				_dirty = true
		Protocol.RESET_ROOM:
			var r3: int = _room_index(msg)
			if r3 >= 0:
				_reset_room(r3)
		Protocol.RELEASE_SEAT:
			_on_release(msg)
		Protocol.SET_DEBUG_BUGS:
			debug_bugs = clampi(_num(msg, Protocol.F_VALUE, -1), -1, GameRoom.spawn_points().size())
			_dirty = true
	_flush(now_s)


## Server clock: ends expired hunts and sends the periodic broadcasts.
func tick(now_s: float) -> void:
	var hunting: bool = false
	for room: GameRoom in rooms:
		if room.phase == Protocol.PH_HUNT:
			if now_s >= room.hunt_end_s:
				_finish_hunt(room, now_s, false)
			else:
				hunting = true
	if hunting:
		if now_s - _last_teacher_bc >= TEACHER_BC_S:
			_broadcast_teacher(now_s)
		if now_s - _last_room_bc >= ROOM_BC_S:
			_broadcast_rooms(now_s)
	_flush(now_s)


# === STATE ===
func room_of(student: String) -> int:
	for i: int in range(rooms.size()):
		if rooms[i].members.has(student):
			return i
	return -1


func teacher_state(now_s: float) -> Dictionary:
	var rs: Array = []
	for room: GameRoom in rooms:
		rs.append(room.state(now_s))
	var ro: Array = []
	for n: String in roster:
		var seat: Dictionary = seats.get(n, {})
		ro.append({"name": n, "room": room_of(n), "taken": not seat.is_empty(),
			"connected": (not seat.is_empty()) and int(seat["conn"]) != 0})
	return {"code": code, "config": config.duplicate(), "roster": ro, "rooms": rs}


# === CONFIG ===
func _on_configure(msg: Dictionary) -> void:
	var cfg: Variant = msg.get(Protocol.F_CONFIG)
	var asg: Variant = msg.get(Protocol.F_ASSIGN)
	_apply_config(cfg if typeof(cfg) == TYPE_DICTIONARY else {}, asg if typeof(asg) == TYPE_DICTIONARY else {})
	_dirty = true


func _apply_config(provided: Dictionary, prov_assign: Dictionary) -> void:
	var cfg: Dictionary = config.duplicate()
	var old_rooms: int = int(config.get("rooms", 1))
	if provided.has("stage") and _is_num(provided["stage"]):
		var d: Dictionary = StageConfig.defaults(int(provided["stage"]))
		d["rooms"] = cfg.get("rooms", 1)
		d["hunt_seconds"] = cfg.get("hunt_seconds", StageConfig.HUNT_SECONDS_DEFAULT)
		d["bug_budget"] = cfg.get("bug_budget", StageConfig.BUG_BUDGET_DEFAULT)
		cfg = d
	for key: String in ["rooms", "bugs_start", "lizards_start", "hunt_seconds", "bug_budget"]:
		if provided.has(key) and _is_num(provided[key]):
			cfg[key] = int(provided[key])
	cfg["stage"] = clampi(int(cfg["stage"]), 1, 4)
	cfg["rooms"] = clampi(int(cfg["rooms"]), 1, MAX_ROOMS)
	cfg["bugs_start"] = clampi(int(cfg["bugs_start"]), 0, GameRoom.spawn_points().size())
	cfg["lizards_start"] = clampi(int(cfg["lizards_start"]), 0, MAX_NAMES)
	cfg["hunt_seconds"] = clampi(int(cfg["hunt_seconds"]), StageConfig.HUNT_SECONDS_MIN, StageConfig.HUNT_SECONDS_MAX)
	cfg["bug_budget"] = clampi(int(cfg["bug_budget"]), 1, 100000)
	config = cfg
	var n: int = int(cfg["rooms"])
	var new_assign: Dictionary = {}
	var rr: int = 0
	for name: String in roster:
		# A changed room count re-deals everyone not named in prov_assign round-robin (the teacher view sends no assign).
		var v: Variant = prov_assign.get(name, assign.get(name) if n == old_rooms else null)
		if _is_num(v) and int(v) >= 0 and int(v) < n:
			new_assign[name] = int(v)
		else:
			new_assign[name] = rr % n
			rr += 1
	assign = new_assign
	# Rooms in PH_SETUP of round 1 (and brand-new ones) take the new config; the rest keep theirs until reset.
	var i: int = rooms.size() - 1
	while i >= n and rooms[i].is_fresh():
		rooms.remove_at(i)
		i -= 1
	while rooms.size() < n:
		rooms.append(GameRoom.new(rooms.size()))
	var applicable: Array[int] = []
	for k: int in range(rooms.size()):
		if rooms[k].is_fresh():
			applicable.append(k)
			rooms[k].members.clear()
	for name: String in roster:
		var r: int = int(assign[name])
		if applicable.has(r) and room_of(name) == -1:
			rooms[r].members.append(name)
	_fix_orphans()
	for k: int in applicable:
		rooms[k].setup(config, debug_bugs)


## A student left in no room (their room was rebuilt around them) goes to the room they are assigned to.
func _fix_orphans() -> void:
	for name: String in roster:
		if room_of(name) == -1:
			var r: int = int(assign.get(name, 0))
			rooms[r if r < rooms.size() else 0].members.append(name)


func _reset_room(i: int) -> void:
	rooms[i].members.clear()
	for name: String in roster:
		if int(assign.get(name, 0)) == i and room_of(name) == -1:
			rooms[i].members.append(name)
	_fix_orphans()
	rooms[i].setup(config, debug_bugs)
	_dirty = true


# === STUDENTS ===
func _roster_wire() -> Array:
	var a: Array = []
	for n: String in roster:
		a.append({"name": n, "taken": seats.has(n)})
	return a


func _on_pick(conn: int, msg: Dictionary, now_s: float) -> void:
	var name: String = _str(msg, Protocol.F_NAME)
	if not roster.has(name) or seats.has(name):
		_error(conn, Protocol.R_NAME_TAKEN)
		return
	seats[name] = {"token": make_token(), "conn": 0}
	_bind_student(conn, name)
	_welcome(conn, name, now_s, false)
	_dirty = true


func _on_rejoin(conn: int, msg: Dictionary, now_s: float) -> void:
	var token: String = _str(msg, Protocol.F_TOKEN)
	var name: String = ""
	if token != "":
		for n: String in seats:
			if str((seats[n] as Dictionary)["token"]) == token:
				name = n
	if name == "":
		_error(conn, Protocol.R_BAD_TOKEN)
		return
	var seat: Dictionary = seats[name]
	var old: int = int(seat["conn"])
	if old != 0 and old != conn:
		student_conns.erase(old)
	_bind_student(conn, name)
	_welcome(conn, name, now_s, true)
	_dirty = true


func _bind_student(conn: int, name: String) -> void:
	_unbind(conn)
	student_conns[conn] = name
	(seats[name] as Dictionary)["conn"] = conn


## A connection holds one role at a time.
func _unbind(conn: int) -> void:
	teacher_conns.erase(conn)
	if student_conns.has(conn):
		var prev: String = student_conns[conn]
		student_conns.erase(conn)
		var seat: Dictionary = seats.get(prev, {})
		if not seat.is_empty() and int(seat["conn"]) == conn:
			seat["conn"] = 0


func _welcome(conn: int, name: String, now_s: float, rejoin: bool) -> void:
	var ri: int = room_of(name)
	var seat: Dictionary = seats[name]
	_send(conn, Protocol.JOINED, {Protocol.F_NAME: name, Protocol.F_TOKEN: seat["token"], Protocol.F_ROOM: maxi(ri, 0)})
	if ri < 0 or not rejoin:
		return
	var room: GameRoom = rooms[ri]
	_send(conn, Protocol.ROOM_STATE, {Protocol.F_ROOM: ri, Protocol.F_STATE: room.state(now_s)})
	if room.phase == Protocol.PH_HUNT and room.lizard_id_of(name) != "":
		room.reset_hunter_pos(name, now_s)
		_send(conn, Protocol.HUNT_START, _hunt_start_fields(room, name, now_s))
	elif (room.phase == Protocol.PH_STUDY or room.phase == Protocol.PH_ENDED) and not room.last_summary.is_empty():
		_send(conn, Protocol.SUMMARY, {Protocol.F_ROOM: ri, Protocol.F_SUMMARY: room.last_summary})


func _hunt_start_fields(room: GameRoom, name: String, now_s: float) -> Dictionary:
	return {Protocol.F_ROOM: room.index, Protocol.F_ROUND: room.round_number,
		Protocol.F_SECONDS: snappedf(room.seconds_left(now_s), 0.1), Protocol.F_BUGS: room.wire_bugs(),
		Protocol.F_POS: Protocol.vec_to_wire(HabitatLayout.START_POS), Protocol.F_COUNT: room.count_of(name)}


func _on_position(conn: int, msg: Dictionary, now_s: float) -> void:
	var name: String = str(student_conns.get(conn, ""))
	var ri: int = room_of(name)
	if name == "" or ri < 0:
		return
	var p: Vector3 = Protocol.wire_to_vec(msg.get(Protocol.F_POS))
	if p == Vector3.INF:
		return
	rooms[ri].submit_position(name, p, now_s)


func _on_capture(conn: int, msg: Dictionary, now_s: float) -> void:
	var id: int = _num(msg, Protocol.F_BUG_ID, -1)
	var name: String = str(student_conns.get(conn, ""))
	var ri: int = room_of(name)
	if name == "" or ri < 0:
		_send(conn, Protocol.CAPTURE_REJECTED, {Protocol.F_BUG_ID: id, Protocol.F_REASON: Protocol.R_NOT_HUNTING})
		return
	var res: Dictionary = rooms[ri].capture(name, id, now_s)
	if bool(res["ok"]):
		_send(conn, Protocol.CAPTURE_OK, {Protocol.F_BUG_ID: id, Protocol.F_COUNT: res["count"]})
		for h: String in rooms[ri].hunter_names():
			if h != name:
				_send_to_student(h, Protocol.BUG_GONE, {Protocol.F_BUG_ID: id})
	else:
		_send(conn, Protocol.CAPTURE_REJECTED, {Protocol.F_BUG_ID: id, Protocol.F_REASON: res["reason"]})


func _on_release(msg: Dictionary) -> void:
	var name: String = _str(msg, Protocol.F_NAME)
	if not seats.has(name):
		return
	var conn: int = int((seats[name] as Dictionary)["conn"])
	seats.erase(name)
	if conn != 0:
		student_conns.erase(conn)
		_error(conn, Protocol.R_BAD_TOKEN)
	_dirty = true


# === TEACHER ===
func _is_teacher(msg: Dictionary) -> bool:
	var t: String = _str(msg, Protocol.F_TOKEN)
	return t != "" and t == teacher_token


func _on_teacher_rejoin(conn: int, msg: Dictionary, now_s: float) -> void:
	if not _is_teacher(msg):
		_error(conn, Protocol.R_NOT_TEACHER)
		return
	_unbind(conn)
	teacher_conns.append(conn)
	_send(conn, Protocol.TEACHER_STATE, {Protocol.F_CODE: code, Protocol.F_STATE: teacher_state(now_s)})


## START_HUNT is session-wide: every unpaused room in PH_SETUP starts on the same server clock.
func _on_start_hunt(now_s: float) -> void:
	var connected: Array[String] = []
	for n: String in seats:
		if int((seats[n] as Dictionary)["conn"]) != 0:
			connected.append(n)
	for room: GameRoom in rooms:
		if room.start_hunt(now_s, connected):
			_dirty = true
			for h: String in room.hunter_names():
				_send_to_student(h, Protocol.HUNT_START, _hunt_start_fields(room, h, now_s))


func _finish_hunt(room: GameRoom, now_s: float, stopped: bool) -> void:
	var res: Dictionary = room.end_hunt(now_s, stopped)
	if res.is_empty():
		return
	for m: String in room.members:
		_send_to_student(m, Protocol.HUNT_END, {Protocol.F_ROOM: room.index, Protocol.F_ROUND: res["round"]})
		_send_to_student(m, Protocol.SUMMARY, {Protocol.F_ROOM: room.index, Protocol.F_SUMMARY: res["summary"]})
	_log_catches(room, res)
	_dirty = true


# === BROADCASTS ===
func _flush(now_s: float) -> void:
	if _dirty:
		_dirty = false
		_broadcast_teacher(now_s)
		_broadcast_rooms(now_s)


func _broadcast_teacher(now_s: float) -> void:
	_last_teacher_bc = now_s
	if teacher_conns.is_empty():
		return
	var st: Dictionary = teacher_state(now_s)
	for c: int in teacher_conns:
		_send(c, Protocol.TEACHER_STATE, {Protocol.F_CODE: code, Protocol.F_STATE: st})


func _broadcast_rooms(now_s: float) -> void:
	_last_room_bc = now_s
	for room: GameRoom in rooms:
		var st: Dictionary = room.state(now_s)
		for m: String in room.members:
			_send_to_student(m, Protocol.ROOM_STATE, {Protocol.F_ROOM: room.index, Protocol.F_STATE: st})


# === CATCH LOG ===
func _log_catches(room: GameRoom, res: Dictionary) -> void:
	if log_dir == "" or (res["rows"] as Array).is_empty():
		return
	DirAccess.make_dir_recursive_absolute(log_dir)
	var path: String = log_dir.path_join("catches.csv")
	var is_new: bool = not FileAccess.file_exists(path)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if f == null:
		push_error("session: cannot open %s" % path)
		return
	f.seek_end()
	if is_new:
		f.store_line("utc_iso,session_code,room,stage,round,bugs_start,hunt_seconds_actual,hunters_in_room,student_name,captures")
	var stamp: String = Time.get_datetime_string_from_system(true) + "Z"
	for row: Dictionary in res["rows"]:
		f.store_line("%s,%s,%d,%d,%d,%d,%s,%d,%s,%d" % [stamp, code, room.index, int(res["stage"]), int(res["round"]),
			int(res["bugs_start"]), str(res["actual"]), int(res["hunters"]), _csv(str(row["name"])), int(row["captures"])])
	f.close()


static func _csv(s: String) -> String:
	if s.contains(",") or s.contains("\"") or s.contains("\n") or s.contains("\r"):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


# === HELPERS ===
func _connected_count() -> int:
	return teacher_conns.size() + student_conns.size()


func _send(conn: int, type: String, fields: Dictionary = {}) -> void:
	if conn != 0:
		out.append({"to": conn, "t": type, "f": fields})


func _send_to_student(name: String, type: String, fields: Dictionary = {}) -> void:
	var seat: Dictionary = seats.get(name, {})
	if not seat.is_empty():
		_send(int(seat["conn"]), type, fields)


func _error(conn: int, reason: String) -> void:
	_send(conn, Protocol.ERROR, {Protocol.F_REASON: reason})


func _room_index(msg: Dictionary) -> int:
	var r: int = _num(msg, Protocol.F_ROOM, -1)
	return r if r >= 0 and r < rooms.size() else -1


static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT) or (typeof(v) == TYPE_FLOAT and is_finite(v as float))


static func _num(d: Dictionary, k: String, def: int) -> int:
	var v: Variant = d.get(k)
	return int(v) if _is_num(v) else def


static func _str(d: Dictionary, k: String) -> String:
	var v: Variant = d.get(k)
	if typeof(v) == TYPE_STRING:
		var s: String = v
		return s
	return ""
