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

	# 2b. Stage 3 open tag-in: Ada is a surviving parent with a free slot, Hana was picked, Kai is a hand-up watcher.
	for who: String in ["Ada", "Hana", "Kai"]:
		var s3: SummaryScreen = SummaryScreen.new()
		s3.set_identity(who, 0)
		get_root().add_child(s3)
		await _frames(2)
		s3.handle(_room_state_msg("study", 3, 0.0, _tagin_extra()))
		s3.handle(_tagin_summary_msg())
		await _frames(3)
		await _snap("m5_student_" + who.to_lower())
		if who == "Ada":
			s3.handle_error(Protocol.R_PICK_TAKEN)
			await _frames(3)
			await _snap("m5_student_ada_taken")
		await _discard(s3)

	# 3. Teacher: setup panel, then a live session with two rooms and a 25-name roster.
	var teacher: TeacherView = TeacherView.new()
	teacher.setup(net)
	get_root().add_child(teacher)
	await _frames(3)
	await _snap("teacher_setup")
	teacher.handle({Protocol.F_TYPE: Protocol.SESSION_CREATED, Protocol.F_CODE: "4821", Protocol.F_TOKEN: "preview"})
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
	var st3: Dictionary = _teacher_state()
	var rooms3: Array = st3["rooms"]
	var r0: Dictionary = rooms3[0]
	r0.merge(_tagin_extra(), true)
	r0["stage"] = 3
	r0["phase"] = "study"
	var h3: Array = r0["history"]
	for rec: Variant in h3:
		var rd: Dictionary = rec
		rd["slots_earned"] = 2
		rd["slots_filled"] = 1
		rd["slots_unfilled"] = 1
	var roster3: Array = st3["roster"]
	for i3: int in range(roster3.size()):
		var re: Dictionary = roster3[i3]
		re["hand"] = i3 in [7, 10]
		re["been_lizard"] = i3 < 5
	teacher.handle({Protocol.F_TYPE: Protocol.TEACHER_STATE, Protocol.F_CODE: "4821", Protocol.F_STATE: st3})
	await _frames(3)
	var sc3: Array = teacher.find_children("*", "ScrollContainer", true, false)
	(sc3[0] as ScrollContainer).scroll_vertical = 1000
	await _frames(3)
	await _snap("m5_teacher_rooms")
	(sc3[0] as ScrollContainer).scroll_vertical = 1450
	await _frames(3)
	await _snap("m5_teacher_rooms2")
	(sc3[0] as ScrollContainer).scroll_vertical = 100000
	await _frames(3)
	await _snap("m5_teacher_roster")
	(sc3[0] as ScrollContainer).scroll_vertical = 0
	await _frames(3)
	await _snap("m5_teacher_top")
	await _discard(teacher)

	await _stage4_scenes(net)

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


func _tagin_extra() -> Dictionary:
	return {
		"hands": ["Hana", "Kai", "Nia"],
		"tagin": [
			{"slot": "S0", "parent": "Ada", "student": "Hana", "by_teacher": false},
			{"slot": "S1", "parent": "Ada", "student": "", "by_teacher": false},
			{"slot": "S2", "parent": "Ben", "student": "", "by_teacher": false},
		],
		"can_pick": ["Kai", "Nia"],
	}


func _tagin_summary_msg() -> Dictionary:
	var m: Dictionary = _summary_msg(false, "")
	var sm: Dictionary = m[Protocol.F_SUMMARY]
	sm["stage"] = 3
	sm["tagin_open"] = true
	sm["survived"] = ["Ada", "Ben", "Cleo"]
	sm["starved"] = ["Dev"]
	var hist: Array = sm["history"]
	for rec: Variant in hist:
		var rd: Dictionary = rec
		rd["slots_earned"] = 2
		rd["slots_filled"] = 1
		rd["slots_unfilled"] = 1
	return m


func _room_state_msg(phase: String, round_n: int, secs: float, extra: Dictionary = {}) -> Dictionary:
	var msg: Dictionary = _room_state_base(phase, round_n, secs)
	if not extra.is_empty():
		var st: Dictionary = msg[Protocol.F_STATE]
		st.merge(extra, true)
		st["stage"] = 3
	return msg


func _room_state_base(phase: String, round_n: int, secs: float) -> Dictionary:
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


# === STAGE 4 (M6) ===
func _stage4_scenes(net: NetClient) -> void:
	# Students: Ada became a mutant this round; Ben sees the news; Cleo is mid tag-in with a mutant already in play.
	for who: String in ["Ada", "Ben"]:
		var s4: SummaryScreen = SummaryScreen.new()
		s4.set_identity(who, 0)
		get_root().add_child(s4)
		await _frames(2)
		var rs: Dictionary = _room_state_base("study", 3, 0.0)
		var st: Dictionary = rs[Protocol.F_STATE]
		st["stage"] = 4
		st["mutants"] = ["Ada"]
		st["mutant_arisen"] = true
		s4.handle(rs)
		s4.handle(_stage4_summary(false))
		await _frames(3)
		await _snap("m6_student_" + who.to_lower())
		var sc: Array = s4.find_children("*", "ScrollContainer", true, false)
		if not sc.is_empty():
			(sc[0] as ScrollContainer).scroll_vertical = 480
			await _frames(3)
			await _snap("m6_student_%s_results" % who.to_lower())
		if who == "Ada" and not sc.is_empty():
			(sc[0] as ScrollContainer).scroll_vertical = 100000
			await _frames(3)
			await _snap("m6_student_ada_bottom")
		await _discard(s4)
	var s4t: SummaryScreen = SummaryScreen.new()
	s4t.set_identity("Ben", 0)
	get_root().add_child(s4t)
	await _frames(2)
	var rt: Dictionary = _room_state_base("study", 3, 0.0)
	var stt: Dictionary = rt[Protocol.F_STATE]
	stt["stage"] = 4
	stt["mutants"] = ["Ada"]
	stt["mutant_arisen"] = true
	stt.merge(_tagin_extra(), true)
	s4t.handle(rt)
	var ts: Dictionary = _stage4_summary(true)
	s4t.handle(ts)
	await _frames(3)
	await _snap("m6_student_tagin")
	await _discard(s4t)

	# Teacher: room 0 tag-in open, no mutant yet (chooser); room 1 between hunts, no mutant (fallback);
	# room 2 mutants exist (names, table).
	var teacher: TeacherView = TeacherView.new()
	teacher.setup(net)
	get_root().add_child(teacher)
	await _frames(3)
	var tst: Dictionary = _teacher_state()
	var cfg: Dictionary = StageConfig.defaults(4)
	cfg["rooms"] = 3
	tst["config"] = cfg
	var base_hist: Array = _stage4_history()
	var rooms: Array = []
	var r0: Dictionary = {"room": 0, "phase": "study", "round": 1, "stage": 4, "paused": false, "bugs_start": 60, "caught": 40,
		"remaining": 20, "seconds_left": 0.0, "hunters": ["Ada", "Ben", "Cleo"], "members": NAMES_25.slice(0, 8),
		"history": [], "mutants": [], "mutant_arisen": false, "mutant_slot": ""}
	r0.merge(_tagin_extra(), true)
	rooms.append(r0)
	var r1: Dictionary = {"room": 1, "phase": "study", "round": 2, "stage": 4, "paused": false, "bugs_start": 80, "caught": 50,
		"remaining": 30, "seconds_left": 0.0, "hunters": ["Ivan", "Jo", "Kai"], "members": NAMES_25.slice(8, 16),
		"history": [(base_hist[0] as Dictionary).duplicate()], "mutants": [], "mutant_arisen": false, "mutant_slot": "", "tagin": []}
	rooms.append(r1)
	var r2: Dictionary = {"room": 2, "phase": "study", "round": 3, "stage": 4, "paused": false, "bugs_start": 90, "caught": 50,
		"remaining": 40, "seconds_left": 0.0, "hunters": ["Pia", "Quinn", "Rosa"], "members": NAMES_25.slice(16, 25),
		"history": base_hist, "mutants": ["Pia"], "mutant_arisen": true, "mutant_slot": "", "tagin": []}
	rooms.append(r2)
	tst["rooms"] = rooms
	teacher.handle({Protocol.F_TYPE: Protocol.SESSION_CREATED, Protocol.F_CODE: "4821", Protocol.F_TOKEN: "preview"})
	teacher.handle({Protocol.F_TYPE: Protocol.TEACHER_STATE, Protocol.F_CODE: "4821", Protocol.F_STATE: tst})
	await _frames(3)
	var scr: Array = teacher.find_children("*", "ScrollContainer", true, false)
	var sc0: ScrollContainer = scr[0] as ScrollContainer
	sc0.scroll_vertical = 0
	await _frames(3)
	await _snap("m6_teacher_top")
	for y: int in [350, 900, 1500, 2100, 2500, 2900]:
		sc0.scroll_vertical = y
		await _frames(3)
		await _snap("m6_teacher_%d" % y)
	sc0.scroll_vertical = 100000
	await _frames(3)
	await _snap("m6_teacher_bottom")
	await _discard(teacher)


func _stage4_history() -> Array:
	return [
		{"round": 1, "stage": 4, "bugs_start": 60, "BUGS": 40, "bugs_next_start": 80, "LIZARDS": 3, "WILD": 3, "MUTANTS": 0, "mutant_arisen": false, "mutant_fallback": false, "end_reason": ""},
		{"round": 2, "stage": 4, "bugs_start": 80, "BUGS": 60, "bugs_next_start": 120, "LIZARDS": 4, "WILD": 3, "MUTANTS": 1, "mutant_arisen": true, "mutant_fallback": true, "end_reason": ""},
		{"round": 3, "stage": 4, "bugs_start": 120, "BUGS": 70, "bugs_next_start": 140, "LIZARDS": 5, "WILD": 3, "MUTANTS": 2, "mutant_arisen": true, "mutant_fallback": false, "end_reason": ""},
	]


func _stage4_summary(tagin_open: bool) -> Dictionary:
	return {
		Protocol.F_TYPE: Protocol.SUMMARY,
		Protocol.F_ROOM: 0,
		Protocol.F_SUMMARY: {
			"round": 3, "stage": 4, "bugs_start": 60, "BUGS": 70, "bugs_next_start": 140, "LIZARDS": 5, "WILD": 3, "MUTANTS": 2,
			"mutant_arisen": true, "new_mutants": ["Ada"] if not tagin_open else [], "tagin_open": tagin_open,
			"starved": ["Dev"], "survived": ["Ada", "Ben", "Cleo"],
			"captures": {"Ada": 7, "Ben": 6, "Cleo": 9, "Dev": 2}, "hunt_seconds": 45,
			"ended": false, "end_reason": "", "history": _stage4_history(),
		},
	}
