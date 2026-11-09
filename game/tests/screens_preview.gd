extends SceneTree
## Renders the client screens with realistic fake messages. Headless: checks the screens build and
## take messages, prints "screens_preview: ok", exits 0. Windowed with BL_SHOT_DIR set: also saves one
## PNG per view into that folder. Run: godot --script res://tests/screens_preview.gd (windowed for PNGs).

const NAMES_25: Array = [
	"Ada", "Ben", "Cleo", "Dev", "Eli", "Fay", "Gus", "Hana", "Ivan", "Jo", "Kai", "Lena", "Mo",
	"Nia", "Omar", "Pia", "Quinn", "Rosa", "Sam", "Tara", "Uma", "Vic", "Wren", "Xan", "Yara",
]

var _shot_dir: String = ""
var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_shot_dir = OS.get_environment("BL_SHOT_DIR")
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	var net: NetClient = NetClient.new()

	# 1. Join: code entry, then the roster.
	var join: JoinScreen = JoinScreen.new()
	join.setup(net)
	get_root().add_child(join)
	await _frames(3)
	await _snap("join_code")
	join.handle(_roster_msg())
	await _frames(3)
	await _snap("join_roster")
	await _discard(join)

	# 2. Summary: hunting, then study with a 3-round history, then ended.
	var summary: SummaryScreen = SummaryScreen.new()
	summary.set_identity("Ada", 0)
	get_root().add_child(summary)
	await _frames(2)
	summary.handle(_room_state_msg("hunt", 3, 17.6))
	await _frames(3)
	await _snap("summary_hunt")
	summary.handle(_room_state_msg("study", 3, 0.0))
	summary.handle(_summary_msg(false, ""))
	await _frames(3)
	await _snap("summary_study")
	summary.handle(_room_state_msg("ended", 3, 0.0))
	summary.handle(_summary_msg(true, RoundRules.END_OVERRUN))
	await _frames(3)
	await _snap("summary_ended")
	_check(summary.graph_slot() != null and summary.graph_slot().name == "GraphSlot", "summary graph slot")
	_check(summary.graph_slot().get_child_count() == 1, "summary graph added once")
	var summary_scrolls: Array = summary.find_children("*", "ScrollContainer", true, false)
	if not summary_scrolls.is_empty():
		(summary_scrolls[0] as ScrollContainer).scroll_vertical = 100000
	await _frames(3)
	await _snap("summary_graph")
	await _discard(summary)

	# 3. Teacher: setup panel, then a live session with two rooms and a 25-name roster.
	var teacher: TeacherView = TeacherView.new()
	teacher.setup(net)
	get_root().add_child(teacher)
	await _frames(3)
	await _snap("teacher_setup")
	teacher.handle({Protocol.F_TYPE: Protocol.TEACHER_STATE, Protocol.F_CODE: "4821", Protocol.F_STATE: _teacher_state()})
	await _frames(3)
	await _snap("teacher_session")
	var scrolls: Array = teacher.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		var sc: ScrollContainer = scrolls[0] as ScrollContainer
		sc.scroll_vertical = 100000
	await _frames(3)
	await _snap("teacher_session_bottom")
	if not scrolls.is_empty():
		var sc_mid: ScrollContainer = scrolls[0] as ScrollContainer
		sc_mid.scroll_vertical = 760
	await _frames(3)
	await _snap("teacher_session_rooms")
	if not scrolls.is_empty():
		var sc_graph: ScrollContainer = scrolls[0] as ScrollContainer
		sc_graph.scroll_vertical = 1000
	await _frames(3)
	await _snap("teacher_session_graphs")
	_check(teacher.graph_slot(0) != null and teacher.graph_slot(1) != null, "teacher graph slots")
	await _discard(teacher)

	net.free()
	if _failures > 0:
		print("screens_preview: FAILED %d checks" % _failures)
		quit(1)
		return
	print("screens_preview: ok")
	quit(0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("screens_preview: check failed: " + what)


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _snap(file_name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	var img: Image = get_root().get_texture().get_image()
	img.save_png(_shot_dir.path_join(file_name + ".png"))
	print("screens_preview: saved %s.png" % file_name)


func _discard(node: Node) -> void:
	get_root().remove_child(node)
	node.queue_free()
	await _frames(2)


func _roster_msg() -> Dictionary:
	var names: Array = []
	for i: int in range(NAMES_25.size()):
		names.append({"name": NAMES_25[i], "taken": i % 4 == 1})
	return {Protocol.F_TYPE: Protocol.ROSTER, Protocol.F_CODE: "4821", Protocol.F_NAMES: names}


func _room_state_msg(phase: String, round_n: int, secs: float) -> Dictionary:
	return {
		Protocol.F_TYPE: Protocol.ROOM_STATE,
		Protocol.F_ROOM: 0,
		Protocol.F_STATE: {
			"room": 0, "phase": phase, "round": round_n, "stage": 2, "paused": false,
			"bugs_start": 45, "caught": 33, "remaining": 12, "seconds_left": secs,
			"hunters": ["Ada", "Ben", "Cleo", "Dev"], "members": NAMES_25.slice(0, 13),
		},
	}


func _summary_msg(ended: bool, reason: String) -> Dictionary:
	var history: Array = _stage2_history(reason)
	return {
		Protocol.F_TYPE: Protocol.SUMMARY,
		Protocol.F_ROOM: 0,
		Protocol.F_SUMMARY: {
			"round": 4, "stage": 2, "bugs_start": 912, "BUGS": 620, "bugs_next_start": 1860,
			"LIZARDS": 2, "MUTANTS": 0, "starved": ["Dev"], "survived": ["Ada", "Ben", "Cleo"],
			"captures": {"Ada": 7, "Ben": 6, "Cleo": 9, "Dev": 2}, "hunt_seconds": 45,
			"ended": ended, "end_reason": reason, "history": history,
		},
	}


func _teacher_state() -> Dictionary:
	var roster: Array = []
	for i: int in range(NAMES_25.size()):
		roster.append({
			"name": NAMES_25[i], "room": 0 if i < 13 else 1,
			"taken": i < 20, "connected": i % 5 != 0,
		})
	var cfg: Dictionary = StageConfig.defaults(2)
	cfg["rooms"] = 2
	var hist: Array = _stage2_history("")
	var rooms: Array = [
		{
			"room": 0, "phase": "study", "round": 4, "stage": 2, "paused": false, "bugs_start": 912,
			"caught": 292, "remaining": 620, "seconds_left": 0.0,
			"hunters": ["Ada", "Ben", "Cleo"], "members": NAMES_25.slice(0, 13), "history": hist,
		},
		{
			"room": 1, "phase": "setup", "round": 1, "stage": 2, "paused": true, "bugs_start": 75,
			"caught": 0, "remaining": 75, "seconds_left": 0.0,
			"hunters": [], "members": NAMES_25.slice(13, 25), "history": [],
		},
	]
	return {"code": "4821", "config": cfg, "roster": roster, "rooms": rooms}


## Four Stage 2 rounds: next start = BUGS x 3, so the last round's next start (1860) overruns the habitat.
## BUGS values run past 999 on purpose, to check the graph plots them without capping.
func _stage2_history(last_reason: String) -> Array:
	return [
		{"round": 1, "stage": 2, "bugs_start": 75, "BUGS": 48, "bugs_next_start": 144, "LIZARDS": 3, "MUTANTS": 0, "end_reason": ""},
		{"round": 2, "stage": 2, "bugs_start": 144, "BUGS": 114, "bugs_next_start": 342, "LIZARDS": 3, "MUTANTS": 0, "end_reason": ""},
		{"round": 3, "stage": 2, "bugs_start": 342, "BUGS": 304, "bugs_next_start": 912, "LIZARDS": 2, "MUTANTS": 0, "end_reason": ""},
		{"round": 4, "stage": 2, "bugs_start": 912, "BUGS": 620, "bugs_next_start": 1860, "LIZARDS": 2, "MUTANTS": 0, "end_reason": last_reason},
	]
