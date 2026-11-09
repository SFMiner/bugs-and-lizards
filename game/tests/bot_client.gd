class_name BotClient
extends Node
## A headless scripted player. Owns one NetClient, joins a session by code and name (or REJOINs with a
## token) and plays every hunt it is sent. Modes: "hunter" (looks, walks to the nearest bug, captures),
## "sweeper" (never looks: spins the view and mashes capture, sending only what pick() returns),
## "racer" (walks to opts.bug_id and sends CAPTURE at opts.at_msec), "idle" (joins, does nothing).
##
## opts: token (REJOIN instead of PICK_NAME), speed (default 3.0 m/s), reaction_s (hunter, default 0.6),
## max_captures (per hunt; -1 = unlimited, 0 = none), miss_cooldown (sweeper, default 0.0),
## bug_id / at_msec (racer; may be set after start, between hunts).

signal joined(token: String)
signal hunt_started(msg: Dictionary)
signal summary(msg: Dictionary)
signal hunt_ended

const REACH: float = 1.5 # hunter stops this close to its bug (metres)
const ARRIVE: float = 1.0 # racer stops this close
const SWEEP_YAW_RATE: float = 3.0 # rad/s
const SWEEP_PRESS_HZ: float = 8.0
const BUG_FIELD_PATH: String = "res://scripts/client/bug_field.gd"

var net: NetClient = null
var code: String = ""
var player_name: String = ""
var mode: String = "hunter"
var opts: Dictionary = {}
var token: String = ""
var room: int = -1
var joined_name: String = ""

var hunting: bool = false
var hunts_started: int = 0
var pos: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var bugs: Dictionary = {} # id -> Vector3, what this player currently believes is left
var start_bugs: Dictionary = {} # the bugs of the latest HUNT_START
var start_msg: Dictionary = {}
var captures_now: int = 0 # accepted captures in the current hunt (as the server counts them)
var hunt_captures: Array[int] = [] # finished hunts
var hunt_captured_ids: Array[int] = [] # ids accepted in the current/latest hunt
var ok_counts: Array[int] = [] # CAPTURE_OK.count values of the current/latest hunt
var presses: int = 0
var blocked_presses: int = 0 # sweeper presses swallowed by the miss cooldown
var rejections: int = 0
var rejection_reasons: Dictionary = {}
var responses: int = 0 # capture responses (ok or rejected) in the current hunt
var last_response: Dictionary = {} # {ok: bool, id: int, reason: String}
var summaries: Array[Dictionary] = []
var errors: Array[Dictionary] = []
var log: Array[Dictionary] = [] # every message, only when opts.record is true

var _skip: Dictionary = {}
var _pending_id: int = -1
var _target: int = -1
var _pending_since: int = 0
var _cooldown: float = 0.0
var _pos_timer: float = 0.0
var _t: float = 0.0
var _press_acc: float = 0.0
var _miss_cd: float = 0.0
var _waypoint: Vector3 = Vector3.INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _race_id: int = -1
var _race_pos: Vector3 = Vector3.INF
var _race_fired: bool = false
var _bug_field: Script = null
var _bug_field_checked: bool = false


func start(url: String, session_code: String, player: String, play_mode: String, options: Dictionary = {}) -> void:
	code = session_code
	player_name = player
	mode = play_mode
	opts = options
	_rng.seed = hash(player)
	net = NetClient.new()
	add_child(net)
	net.message_received.connect(_on_msg)
	net.connected.connect(_on_connected)
	net.connect_to(url)


## Closes the socket the way a crashed tab would (no further messages are sent or read).
func disconnect_now() -> void:
	if net != null:
		net._ws.close()
		hunting = false


## Sends any message (tests use this for out-of-range captures and so on).
func raw(type: String, fields: Dictionary = {}) -> void:
	if net != null:
		net.send(type, fields)


func stats() -> Dictionary:
	var per_hunt: Array[int] = hunt_captures.duplicate()
	if hunting:
		per_hunt.append(captures_now)
	return {"captures_per_hunt": per_hunt, "presses": presses, "rejected": rejections,
		"reasons": rejection_reasons.duplicate(), "blocked": blocked_presses}


## Recomputes one round with RoundRules from the captures a room's students actually made.
## lizards: RoundRules lizard dictionaries; caps_by_student: {name: int}.
## Returns {hunt, finish} (the resolve_hunt and finish_round results).
static func expected_round(stage: int, round_number: int, bugs_start: int, lizards: Array,
		caps_by_student: Dictionary, bug_budget: int) -> Dictionary:
	var caps: Dictionary = {}
	for liz: Dictionary in lizards:
		caps[liz["id"]] = int(caps_by_student.get(liz["student"], 0))
	var hunt: Dictionary = RoundRules.resolve_hunt(stage, round_number, bugs_start, lizards, caps)
	var fin: Dictionary = RoundRules.finish_round(hunt, RoundRules.new_tagin(hunt), {"bug_budget": bug_budget})
	return {"hunt": hunt, "finish": fin}


# === NETWORK ===
func _on_connected() -> void:
	if str(opts.get("token", "")) != "":
		net.send(Protocol.REJOIN, {Protocol.F_CODE: code, Protocol.F_TOKEN: str(opts["token"])})
	else:
		net.send(Protocol.LOOKUP, {Protocol.F_CODE: code})


func _on_msg(msg: Dictionary) -> void:
	if bool(opts.get("record", false)):
		log.append(msg)
	var mt: String = str(msg[Protocol.F_TYPE])
	if (mt == Protocol.ROOM_STATE or mt == Protocol.SUMMARY or mt == Protocol.HUNT_START) and msg.has(Protocol.F_ROOM):
		room = int(msg[Protocol.F_ROOM]) # the teacher may move us after we join (CONFIGURE with more rooms)
	match mt:
		Protocol.ROSTER:
			net.send(Protocol.PICK_NAME, {Protocol.F_CODE: code, Protocol.F_NAME: player_name})
		Protocol.JOINED:
			token = str(msg.get(Protocol.F_TOKEN, ""))
			room = int(msg.get(Protocol.F_ROOM, -1))
			joined_name = str(msg.get(Protocol.F_NAME, ""))
			joined.emit(token)
		Protocol.ERROR:
			errors.append(msg)
		Protocol.HUNT_START:
			_begin_hunt(msg)
		Protocol.BUG_GONE:
			bugs.erase(int(msg.get(Protocol.F_BUG_ID, -1)))
		Protocol.CAPTURE_OK:
			var id: int = int(msg.get(Protocol.F_BUG_ID, -1))
			captures_now = int(msg.get(Protocol.F_COUNT, captures_now))
			ok_counts.append(captures_now)
			hunt_captured_ids.append(id)
			bugs.erase(id)
			responses += 1
			last_response = {"ok": true, "id": id, "reason": ""}
			if id == _pending_id:
				_pending_id = -1
		Protocol.CAPTURE_REJECTED:
			var rid: int = int(msg.get(Protocol.F_BUG_ID, -1))
			var reason: String = str(msg.get(Protocol.F_REASON, ""))
			rejections += 1
			rejection_reasons[reason] = int(rejection_reasons.get(reason, 0)) + 1
			responses += 1
			last_response = {"ok": false, "id": rid, "reason": reason}
			_skip[rid] = true
			if reason == Protocol.R_GONE:
				bugs.erase(rid)
			if rid == _pending_id:
				_pending_id = -1
		Protocol.HUNT_END:
			if hunting:
				hunting = false
				hunt_captures.append(captures_now)
				hunt_ended.emit()
		Protocol.SUMMARY:
			summaries.append(msg)
			summary.emit(msg)


func _begin_hunt(msg: Dictionary) -> void:
	if hunting:
		hunt_captures.append(captures_now)
	hunting = true
	hunts_started += 1
	start_msg = msg
	bugs.clear()
	for b: Variant in msg.get(Protocol.F_BUGS, []):
		var arr: Array = b
		if arr.size() >= 4:
			bugs[int(arr[0])] = Vector3(float(arr[1]), float(arr[2]), float(arr[3]))
	start_bugs = bugs.duplicate()
	var p: Vector3 = Protocol.wire_to_vec(msg.get(Protocol.F_POS))
	pos = p if p.is_finite() else HabitatLayout.START_POS
	yaw = 0.0
	pitch = 0.0
	captures_now = int(msg.get(Protocol.F_COUNT, 0))
	hunt_captured_ids = []
	ok_counts = []
	responses = 0
	last_response = {}
	_skip.clear()
	_pending_id = -1
	_target = -1
	_cooldown = 0.0
	_pos_timer = 0.0
	_miss_cd = 0.0
	_waypoint = Vector3.INF
	_race_id = -1
	_race_pos = Vector3.INF
	_race_fired = false
	if mode == "racer":
		opts.erase("bug_id")
	hunt_started.emit(msg)


# === PLAY ===
func _process(delta: float) -> void:
	if not hunting or net == null or not net.is_open():
		return
	_t += delta
	match mode:
		"hunter":
			_tick_hunter(delta)
		"sweeper":
			_tick_sweeper(delta)
		"racer":
			_tick_racer(delta)
		_:
			return
	_pos_timer += delta
	if _pos_timer >= 1.0 / Protocol.POS_HZ:
		_pos_timer = 0.0
		_send_pos()


func _send_pos() -> void:
	net.send(Protocol.POSITION, {Protocol.F_POS: Protocol.vec_to_wire(pos), Protocol.F_YAW: yaw})


func _speed() -> float:
	return float(opts.get("speed", 3.0))


## Moves along the floor toward target by up to speed*delta; returns the remaining flat distance.
func _walk_toward(target: Vector3, delta: float) -> float:
	var d: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist: float = d.length()
	if dist > 0.001:
		yaw = atan2(-d.x, -d.z)
		var step: float = minf(_speed() * delta, dist)
		pos += d / dist * step
		dist -= step
	return dist


func _send_capture(id: int) -> void:
	_send_pos()
	_pos_timer = 0.0
	presses += 1
	_pending_id = id
	_pending_since = Time.get_ticks_msec()
	net.send(Protocol.CAPTURE, {Protocol.F_BUG_ID: id})


func _pending_blocks() -> bool:
	if _pending_id < 0:
		return false
	if Time.get_ticks_msec() - _pending_since > 1500:
		_pending_id = -1
		return false
	return true


func _tick_hunter(delta: float) -> void:
	var max_c: int = int(opts.get("max_captures", -1))
	if max_c >= 0 and captures_now >= max_c:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	if _pending_blocks():
		return
	if not bugs.has(_target) or _skip.has(_target):
		_target = _choose_target()
	var best: int = _target
	if best < 0:
		return
	var tp: Vector3 = bugs[best]
	if pos.distance_to(tp) > REACH:
		if _walk_toward(tp, delta) <= 0.001 and pos.distance_to(tp) > REACH:
			_skip[best] = true # directly above or below and still out of reach; give up on it
		return
	var d3: Vector3 = tp - pos
	yaw = atan2(-d3.x, -d3.z)
	_send_capture(best)
	_cooldown = float(opts.get("reaction_s", 0.6))


## Picks one of the three nearest bugs at random, so bots sharing a start point do not all chase one bug.
func _choose_target() -> int:
	var cands: Array = []
	for id: int in bugs:
		if not _skip.has(id):
			cands.append([pos.distance_squared_to(bugs[id]), id])
	if cands.is_empty():
		return -1
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var k: int = mini(3, cands.size())
	var pick_row: Array = cands[_rng.randi() % k]
	return int(pick_row[1])


func _tick_sweeper(delta: float) -> void:
	if not _waypoint.is_finite() or _walk_toward(_waypoint, delta) <= 0.05:
		var lim: float = HabitatLayout.HALF - 1.5
		_waypoint = Vector3(_rng.randf_range(-lim, lim), 0.0, _rng.randf_range(-lim, lim))
	yaw += SWEEP_YAW_RATE * delta
	pitch = 0.5 * sin(_t * 1.3) - 0.2
	if _miss_cd > 0.0:
		_miss_cd -= delta
	_press_acc += delta
	var interval: float = 1.0 / SWEEP_PRESS_HZ
	while _press_acc >= interval:
		_press_acc -= interval
		if _miss_cd > 0.0:
			blocked_presses += 1
			continue
		if _pending_blocks():
			continue
		var eye: Vector3 = pos + Vector3(0.0, HabitatLayout.EYE_HEIGHT, 0.0)
		var dir: Vector3 = Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
		var id: int = _pick(eye, dir)
		if id >= 0:
			_send_capture(id)
		else:
			presses += 1
			_miss_cd = float(opts.get("miss_cooldown", 0.0))


func _tick_racer(delta: float) -> void:
	if _race_id < 0:
		var want: int = int(opts.get("bug_id", -1))
		if want < 0 or not bugs.has(want):
			return
		_race_id = want
		_race_pos = bugs[want]
	var flat: Vector3 = Vector3(_race_pos.x - pos.x, 0.0, _race_pos.z - pos.z)
	if flat.length() > ARRIVE:
		_walk_toward(_race_pos, delta)
		return
	if not _race_fired and Time.get_ticks_msec() >= int(opts.get("at_msec", 0)):
		_race_fired = true
		_send_capture(_race_id)


# === BUG PICKING ===
## Uses BugField.pick when agent B's file exists, otherwise a private copy of the same idea:
## the nearest bug along the view ray within max_range whose perpendicular miss distance is small.
func _pick(origin: Vector3, dir: Vector3) -> int:
	if not _bug_field_checked:
		_bug_field_checked = true
		if ResourceLoader.exists(BUG_FIELD_PATH):
			_bug_field = load(BUG_FIELD_PATH)
	if _bug_field != null:
		return int(_bug_field.call("pick", origin, dir, bugs, Protocol.CAPTURE_RANGE))
	return _private_pick(origin, dir, bugs, Protocol.CAPTURE_RANGE)


static func _private_pick(origin: Vector3, dir: Vector3, field: Dictionary, max_range: float) -> int:
	var best: int = -1
	var best_t: float = INF
	var d: Vector3 = dir.normalized()
	for id: int in field:
		var v: Vector3 = (field[id] as Vector3) - origin
		var t: float = v.dot(d)
		if t < 0.0 or t > max_range:
			continue
		var miss: float = (v - d * t).length()
		if miss <= 0.15 + t * 0.03 and t < best_t:
			best_t = t
			best = id
	return best
