class_name ClientApp
extends Node
## Client flow (manager-owned). Routes every server message to the screen that needs it.
## Student: JoinScreen -> SummaryScreen between hunts, HuntView during hunts. Teacher (`?teacher`): TeacherView.
## Tokens are kept in the browser so a refreshed tab rejoins (see _store_for).

const KEY_SEAT: String = "bl_seat"
const KEY_TEACHER: String = "bl_teacher"
const RECONNECT_S: float = 2.0

var teacher_mode: bool = false
var _net: NetClient
var _ui: CanvasLayer
var _join: JoinScreen
var _summary: SummaryScreen
var _teacher: TeacherView
var _hunt: HuntView
var _seat: Dictionary = {} # {code, token, name, room}
var _reconnect_timer: float = -1.0
var _hunting: bool = false
var _histories: Dictionary = {} # room -> history (teacher graphs)


func _ready() -> void:
	_net = NetClient.new()
	_net.name = "Net"
	add_child(_net)
	_net.message_received.connect(_on_message)
	_net.connected.connect(_on_connected)
	_net.disconnected.connect(_on_disconnected)
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	if teacher_mode:
		_teacher = TeacherView.new()
		_ui.add_child(_teacher)
		_teacher.setup(_net)
		_teacher.session_ready.connect(_on_teacher_session)
	else:
		_join = JoinScreen.new()
		_ui.add_child(_join)
		_join.setup(_net)
		_join.joined.connect(_on_joined)
		_summary = SummaryScreen.new()
		_summary.visible = false
		_summary.leave_requested.connect(_on_leave_game)
		_ui.add_child(_summary)
		_hunt = HuntView.new()
		add_child(_hunt)
		_hunt.setup(_net)
		_join.visible = false
	_net.connect_to()


func _process(delta: float) -> void:
	if _reconnect_timer >= 0.0:
		_reconnect_timer -= delta
		if _reconnect_timer < 0.0:
			_net.connect_to()


func _on_connected() -> void:
	if teacher_mode:
		var saved: Dictionary = _load(KEY_TEACHER)
		if not saved.is_empty():
			_teacher.resume(str(saved.get("code", "")), str(saved.get("token", "")))
		return
	var seat: Dictionary = _load(KEY_SEAT)
	if not seat.is_empty():
		_seat = seat
		_net.send(Protocol.REJOIN, {Protocol.F_CODE: seat.get("code", ""), Protocol.F_TOKEN: seat.get("token", "")})
	else:
		_show_join()


func _on_disconnected() -> void:
	_reconnect_timer = RECONNECT_S


func _on_teacher_session(code: String, token: String) -> void:
	_save(KEY_TEACHER, {"code": code, "token": token})


func _on_joined(student_name: String, token: String, room: int, code: String) -> void:
	print("client: joined room %d" % room)
	_seat = {"code": code, "token": token, "name": student_name, "room": room}
	_save(KEY_SEAT, _seat)
	_show_summary()


## Student leaves their game: forget the seat in this tab and show the code pad. The seat stays taken on the
## server until the teacher releases it; joining another game moves this connection there.
func _on_leave_game() -> void:
	_save(KEY_SEAT, {})
	_seat = {}
	_end_hunt_view()
	_join.reset()
	_show_join()


func _on_message(msg: Dictionary) -> void:
	var t: String = str(msg.get(Protocol.F_TYPE, ""))
	if teacher_mode:
		if t == Protocol.ERROR and str(msg.get(Protocol.F_REASON, "")) == Protocol.R_NOT_TEACHER:
			_save(KEY_TEACHER, {})
		_teacher.handle(msg)
		return
	match t:
		Protocol.JOINED:
			var code: String = str(_seat.get("code", ""))
			if code == "":
				_join.handle(msg) # first join: JoinScreen knows the code and emits joined
			else:
				_on_joined(str(msg.get(Protocol.F_NAME, "")), str(msg.get(Protocol.F_TOKEN, "")), int(msg.get(Protocol.F_ROOM, 0)), code)
		Protocol.HUNT_START:
			print("client: hunt_start round %d bugs %d" % [int(msg.get(Protocol.F_ROUND, 0)), (msg.get(Protocol.F_BUGS, []) as Array).size()])
			_hunting = true
			_join.visible = false
			_summary.visible = false
			_hunt.begin_hunt(msg)
		Protocol.BUG_GONE:
			_hunt.on_bug_gone(int(msg.get(Protocol.F_BUG_ID, -1)))
		Protocol.CAPTURE_OK:
			_hunt.on_capture_ok(int(msg.get(Protocol.F_BUG_ID, -1)), int(msg.get(Protocol.F_COUNT, 0)))
		Protocol.CAPTURE_REJECTED:
			_hunt.on_capture_rejected(int(msg.get(Protocol.F_BUG_ID, -1)), str(msg.get(Protocol.F_REASON, "")))
		Protocol.HUNT_END:
			_end_hunt_view()
			_summary.handle(msg)
		Protocol.SUMMARY, Protocol.ROOM_STATE:
			if t == Protocol.SUMMARY:
				var sm: Dictionary = msg.get(Protocol.F_SUMMARY, {})
				print("client: summary round %d BUGS %d next %d LIZARDS %d" % [int(sm.get("round", 0)), int(sm.get("BUGS", 0)), int(sm.get("bugs_next_start", 0)), int(sm.get("LIZARDS", 0))])
			if msg.has(Protocol.F_ROOM):
				_seat["room"] = int(msg[Protocol.F_ROOM])
			_summary.handle(msg)
			if t == Protocol.ROOM_STATE and _hunting:
				var st: Dictionary = msg.get(Protocol.F_STATE, {})
				if str(st.get("phase", "")) != Protocol.PH_HUNT:
					_end_hunt_view()
		Protocol.ERROR:
			var reason: String = str(msg.get(Protocol.F_REASON, ""))
			if (reason == Protocol.R_BAD_TOKEN or reason == Protocol.R_BAD_CODE) and not _seat.is_empty():
				_save(KEY_SEAT, {})
				_seat = {}
				_end_hunt_view()
				_show_join()
			_join.handle(msg)
		_:
			_join.handle(msg)


func _end_hunt_view() -> void:
	if _hunting:
		_hunting = false
		_hunt.end_hunt()
	if not _seat.is_empty():
		_show_summary()


func _show_join() -> void:
	_join.visible = true
	_summary.visible = false


func _show_summary() -> void:
	_join.visible = false
	_summary.visible = not _hunting
	_summary.set_identity(str(_seat.get("name", "")), int(_seat.get("room", 0)))


# === BROWSER STORAGE (web only; desktop keeps nothing, so each desktop window is a fresh player) ===
## Seat token in sessionStorage (per tab, survives a refresh, so two student tabs never share a seat);
## teacher token in localStorage (a closed and reopened teacher tab resumes).
static func _store_for(key: String) -> String:
	return "localStorage" if key == KEY_TEACHER else "sessionStorage"


static func _save(key: String, value: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var js: String = "try{%s.setItem(%s,%s)}catch(e){}" % [_store_for(key), JSON.stringify(key), JSON.stringify(JSON.stringify(value))]
	JavaScriptBridge.eval(js, true)


static func _load(key: String) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var js: String = "(function(){try{return %s.getItem(%s)||''}catch(e){return ''}})()" % [_store_for(key), JSON.stringify(key)]
	var raw: String = str(JavaScriptBridge.eval(js, true))
	if raw == "" or raw == "<null>":
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
