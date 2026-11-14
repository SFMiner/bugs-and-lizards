extends Node
## Headless WebSocket server: TCPServer + WebSocketPeer.accept_stream, plain JSON messages (protocol.gd).
## Owns connections and routing; all game logic lives in GameSession / GameRoom (session.gd, room.gd).

const POLL_FPS: int = 60
const CODE_TRIES: int = 200

var _tcp: TCPServer = TCPServer.new()
var _peers: Dictionary = {} # int id -> WebSocketPeer
var _next_id: int = 1
var _sessions: Dictionary = {} # code -> GameSession
var _conn_session: Dictionary = {} # conn id -> code
var _log_dir: String = "" # catch log (names + counts) only when BL_CATCH_LOG=1; off on the VPS
var _teacher_key: String = "" # BL_TEACHER_KEY from the unit's environment; "" = anyone may create a game (local)
var _max_peers: int = Protocol.MAX_PEERS # a var so the test can lower it
var _conn: Dictionary = {} # conn id -> {t0, tokens, last, bad}: abuse limits (protocol.gd)


func start(port: int) -> void:
	Engine.max_fps = POLL_FPS
	if OS.get_environment("BL_CATCH_LOG") == "1":
		var env_dir: String = OS.get_environment("BL_LOG_DIR")
		_log_dir = env_dir if env_dir != "" else "user://logs"
	_teacher_key = OS.get_environment("BL_TEACHER_KEY").strip_edges()
	var err: Error = _tcp.listen(port, "127.0.0.1")
	if err != OK:
		push_error("server: cannot listen on %d (%s)" % [port, error_string(err)])
		get_tree().quit(1)
		return
	GameRoom.spawn_points() # warm the cache so the first session is not slow
	print("server: listening on 127.0.0.1:%d (catch log %s, teacher key %s)" % [port, "on" if _log_dir != "" else "off", "required" if _teacher_key != "" else "not required"])


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	var now: float = _now()
	while _tcp.is_connection_available():
		var conn: StreamPeerTCP = _tcp.take_connection()
		if _peers.size() >= _max_peers:
			conn.disconnect_from_host()
			continue
		var ws: WebSocketPeer = WebSocketPeer.new()
		ws.inbound_buffer_size = Protocol.MAX_MESSAGE_BYTES * 2
		if ws.accept_stream(conn) == OK:
			_peers[_next_id] = ws
			_conn[_next_id] = {"t0": now, "tokens": Protocol.MSG_BURST, "last": now, "bad": 0}
			_next_id += 1
	var closed: Array[int] = []
	for id: int in _peers:
		var ws: WebSocketPeer = _peers[id]
		ws.poll()
		var state: WebSocketPeer.State = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt: PackedByteArray = ws.get_packet()
				if not _spend(id, now):
					ws.close(1008, "too many messages")
					break
				if not ws.was_string_packet():
					continue
				var msg: Dictionary = Protocol.decode(pkt.get_string_from_utf8())
				if not msg.is_empty():
					_on_message(id, msg)
			if ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not _conn_session.has(id) \
					and now - float(_conn[id]["t0"]) > Protocol.JOIN_TIMEOUT_S:
				ws.close(1000, "idle")
		elif state == WebSocketPeer.STATE_CLOSED:
			closed.append(id)
	for id: int in closed:
		_peers.erase(id)
		_conn.erase(id)
		_on_disconnect(id)
	var dead: Array[String] = []
	for code: String in _sessions:
		var s: GameSession = _sessions[code]
		s.tick(now)
		_flush(s)
		if s.is_expired(now):
			dead.append(code)
	for code: String in dead:
		_sessions.erase(code)


## Token bucket per connection: MSG_RATE a second, MSG_BURST at once. False = over the limit.
func _spend(id: int, now: float) -> bool:
	var c: Dictionary = _conn[id]
	var tokens: float = minf(Protocol.MSG_BURST, float(c["tokens"]) + (now - float(c["last"])) * Protocol.MSG_RATE)
	c["last"] = now
	if tokens < 1.0:
		c["tokens"] = tokens
		return false
	c["tokens"] = tokens - 1.0
	return true


## A wrong code or teacher key: answer it, and close the connection after MAX_BAD_TRIES (slows code sweeps).
func _bad_try(id: int, reason: String) -> void:
	send(id, Protocol.ERROR, {Protocol.F_REASON: reason})
	var c: Dictionary = _conn.get(id, {})
	if c.is_empty():
		return
	c["bad"] = int(c["bad"]) + 1
	if int(c["bad"]) >= Protocol.MAX_BAD_TRIES:
		(_peers[id] as WebSocketPeer).close(1008, "too many wrong codes")


func send(id: int, type: String, fields: Dictionary = {}) -> void:
	var ws: WebSocketPeer = _peers.get(id)
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(Protocol.encode(type, fields))


func _flush(s: GameSession) -> void:
	for m: Dictionary in s.take_out():
		send(int(m["to"]), str(m["t"]), m["f"])


func _on_message(id: int, msg: Dictionary) -> void:
	var t: String = str(msg[Protocol.F_TYPE])
	var now: float = _now()
	match t:
		Protocol.PING:
			send(id, Protocol.PONG, {Protocol.F_TIME: msg.get(Protocol.F_TIME, 0)})
		Protocol.CREATE_SESSION:
			_create_session(id, msg, now)
		Protocol.LOOKUP, Protocol.PICK_NAME, Protocol.REJOIN, Protocol.TEACHER_REJOIN:
			var code: String = ""
			var cv: Variant = msg.get(Protocol.F_CODE)
			if typeof(cv) == TYPE_STRING:
				code = cv
			var s: GameSession = _sessions.get(code)
			if s == null:
				_bad_try(id, Protocol.R_BAD_CODE)
				return
			if t != Protocol.LOOKUP:
				_leave_other_session(id, code, now)
			s.handle(id, msg, now)
			if s.has_conn(id):
				_conn_session[id] = code
			_flush(s)
		_:
			var s2: GameSession = _sessions.get(_conn_session.get(id, ""))
			if s2 != null:
				s2.handle(id, msg, now)
				_flush(s2)


func _create_session(id: int, msg: Dictionary, now: float) -> void:
	if _teacher_key != "" and str(msg.get(Protocol.F_TEACHER_KEY, "")).strip_edges() != _teacher_key:
		_bad_try(id, Protocol.R_BAD_TEACHER_KEY)
		return
	var dead: Array[String] = []
	for code: String in _sessions:
		if (_sessions[code] as GameSession).is_expired(now):
			dead.append(code)
	for code: String in dead:
		_sessions.erase(code)
	if _sessions.size() >= Protocol.MAX_SESSIONS:
		_drop_oldest_unattended()
	if _sessions.size() >= Protocol.MAX_SESSIONS:
		send(id, Protocol.ERROR, {Protocol.F_REASON: Protocol.R_TOO_MANY_SESSIONS})
		return
	var code_new: String = ""
	for _i: int in range(CODE_TRIES):
		var c: String = "%04d" % randi_range(0, 9999)
		if not _sessions.has(c):
			code_new = c
			break
	if code_new == "":
		send(id, Protocol.ERROR, {Protocol.F_REASON: Protocol.R_TOO_MANY_SESSIONS})
		return
	_leave_other_session(id, code_new, now)
	var s: GameSession = GameSession.new(code_new, msg.get(Protocol.F_NAMES, []), now)
	s.log_dir = _log_dir
	_sessions[code_new] = s
	s.attach_creator(id, now)
	_conn_session[id] = code_new
	_flush(s)


## A connection that joins another session stops belonging to the previous one.
## Full server: drop the game that has had nobody connected for longest (left by New game or a closed tab), so
## abandoned games never lock out a new class. Games with anyone connected are never dropped.
func _drop_oldest_unattended() -> void:
	var pick: String = ""
	var since: float = INF
	for code: String in _sessions:
		var s: GameSession = _sessions[code]
		if s.connected_count() == 0 and s.idle_since < since:
			since = s.idle_since
			pick = code
	if pick != "":
		_sessions.erase(pick)


func _leave_other_session(id: int, new_code: String, now: float) -> void:
	var old: String = _conn_session.get(id, "")
	if old != "" and old != new_code:
		var s: GameSession = _sessions.get(old)
		if s != null:
			s.on_disconnect(id, now)
			_flush(s)
		_conn_session.erase(id)


func _on_disconnect(id: int) -> void:
	var s: GameSession = _sessions.get(_conn_session.get(id, ""))
	_conn_session.erase(id)
	if s != null:
		s.on_disconnect(id, _now())
		_flush(s)
