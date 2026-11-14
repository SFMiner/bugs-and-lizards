class_name TeacherView
extends Control
## Teacher screen. Setup panel creates a game (CREATE_SESSION). Once a session exists it shows the
## game code, session-wide hunt controls, settings (CONFIGURE), one card per ecosystem and the roster.
## Every TEACHER_STATE rebuilds the view from that state alone. Designed for about 1180x640 and scrolls
## when smaller. Messages arrive through handle(), routed by main.gd. The manager stores the token.

signal session_ready(code: String, token: String)

const COL_BG: Color = Color(0.93, 0.95, 0.9, 1)
const COL_INK: Color = Color(0.1, 0.12, 0.1, 1)
const COL_CARD: Color = Color(1, 1, 1, 1)
const COL_RULE: Color = Color(0.55, 0.6, 0.55, 1)
const COL_ALERT: Color = Color(0.62, 0.1, 0.08, 1)

var _net: NetClient = null
var _built: bool = false
var _code: String = ""
var _token: String = ""
var _resuming: bool = false
var _config_filled: bool = false
var _stage: int = 1
var _lizards_start: int = 1 # config.lizards_start from the latest TEACHER_STATE; feeds the room graphs
var _roster_sig: String = ""
var _room_cards: Dictionary = {} # int room -> rec Dictionary (see _ensure_room_card)
var _last_rooms: Array = [] # rooms from the latest TEACHER_STATE, to redraw the cards when the stage picker changes
var _stage_btns: Array[Button] = []
var _stage_group: ButtonGroup = null
var _scroll: ScrollContainer = null
var _status: Label = null
var _setup_box: VBoxContainer = null
var _session_box: VBoxContainer = null
var _names_edit: TextEdit = null
var _key_edit: LineEdit = null # teacher key, only needed when the server asks for one; never stored
var _back_btn: Button = null
var _prev_code: String = "" # game left with New game; Back returns to it
var _prev_token: String = ""
var _roster_names: Array[String] = []
var _code_label: Label = null
var _spin_rooms: SpinBox = null
var _spin_bugs: SpinBox = null
var _spin_lizards: SpinBox = null
var _spin_hunt: SpinBox = null
var _spin_budget: SpinBox = null
var _spin_handicap: SpinBox = null
var _handicap_label: Label = null
var _rooms_grid: GridContainer = null
var _roster_grid: GridContainer = null
var _advance_note: Label = null


func _ready() -> void:
	_ensure_built()


func setup(net: NetClient) -> void:
	_net = net
	_ensure_built()


## Manager calls this with a stored token: reopen the game and wait for TEACHER_STATE.
func resume(code: String, token: String) -> void:
	_ensure_built()
	_code = code
	_token = token
	_resuming = true
	_config_filled = false
	_roster_sig = ""
	_show_session(true)
	_code_label.text = "Game code: %s" % code
	_set_status("Reconnecting to game %s..." % code)
	_net_send(Protocol.TEACHER_REJOIN, {Protocol.F_CODE: code, Protocol.F_TOKEN: token})


func graph_slot(room: int) -> Control:
	_ensure_built()
	var rec: Dictionary = _ensure_room_card(room)
	return rec["graph"] as Control


func handle(msg: Dictionary) -> void:
	_ensure_built()
	var t: String = str(msg.get(Protocol.F_TYPE, ""))
	if t == Protocol.SESSION_CREATED:
		_on_session_created(msg)
	elif t == Protocol.TEACHER_STATE:
		_on_state(msg)
	elif t == Protocol.ERROR:
		_on_error(msg)


# === BUILD ===
func _ensure_built() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th: Theme = Theme.new()
	th.default_font_size = 20
	theme = th

	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var margin: MarginContainer = _margin(20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(_text_label("Teacher", 36))
	_status = _text_label("", 22)
	_status.add_theme_color_override("font_color", COL_ALERT)
	column.add_child(_status)

	_setup_box = VBoxContainer.new()
	_setup_box.add_theme_constant_override("separation", 10)
	column.add_child(_setup_box)
	_build_setup(_setup_box)

	_session_box = VBoxContainer.new()
	_session_box.add_theme_constant_override("separation", 14)
	_session_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_box.visible = false
	column.add_child(_session_box)
	_build_session(_session_box)

	_fill_from_config(StageConfig.defaults(1))


func _build_setup(box: VBoxContainer) -> void:
	box.add_child(_text_label("Start a new game", 30))
	box.add_child(_text_label("Class names, one per line", 22))
	_names_edit = TextEdit.new()
	_names_edit.custom_minimum_size = Vector2(0, 260)
	_names_edit.gui_input.connect(_on_names_input)
	box.add_child(_names_edit)
	_key_edit = LineEdit.new()
	_key_edit.secret = true
	_key_edit.placeholder_text = "Teacher key (if this server needs one)"
	_key_edit.custom_minimum_size = Vector2(420, 48)
	_key_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_key_edit)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_button("Create game", Vector2(320, 72), 28, _on_create))
	_back_btn = _button("Back to game", Vector2(320, 72), 28, _on_back_to_game)
	_back_btn.visible = false
	row.add_child(_back_btn)


func _build_session(box: VBoxContainer) -> void:
	_code_label = _text_label("", 56)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_code_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_button("Start hunt", Vector2(280, 80), 28, _on_start_hunt))
	row.add_child(_button("Stop hunt", Vector2(280, 80), 28, _on_stop_hunt))
	row.add_child(_button("Next round", Vector2(280, 80), 28, _on_advance))
	row.add_child(_button("New game", Vector2(200, 80), 24, _on_new_game))
	_advance_note = _text_label("Next round closes the baby picking; empty slots stay unfilled.", 22)
	_advance_note.add_theme_color_override("font_color", COL_ALERT)
	_advance_note.visible = false
	box.add_child(_advance_note)

	box.add_child(_text_label("Game settings (apply to every ecosystem)", 28))
	_stage_group = ButtonGroup.new()
	var stage_row: HBoxContainer = HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 10)
	box.add_child(stage_row)
	_stage_btns.clear()
	for s: int in [1, 2, 3, 4]:
		var b: Button = Button.new()
		b.text = "%d. %s" % [s, StageConfig.NAMES[s]]
		b.toggle_mode = true
		b.button_group = _stage_group
		b.custom_minimum_size = Vector2(260, 60)
		b.add_theme_font_size_override("font_size", 22)
		b.toggled.connect(_on_stage_toggled.bind(s))
		stage_row.add_child(b)
		_stage_btns.append(b)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	_spin_rooms = _spin(1, 8, 1)
	grid.add_child(_cell_label("Ecosystems (rooms)", 22))
	grid.add_child(_spin_rooms)
	_spin_bugs = _spin(0, 600, 5)
	grid.add_child(_cell_label("Starting bugs per ecosystem", 22))
	grid.add_child(_spin_bugs)
	_spin_lizards = _spin(1, 10, 1)
	grid.add_child(_cell_label("Starting lizards per ecosystem", 22))
	grid.add_child(_spin_lizards)
	_spin_hunt = _spin(15, 120, 1)
	grid.add_child(_cell_label("Hunt length (seconds)", 22))
	grid.add_child(_spin_hunt)
	_spin_budget = _spin(50, 2000, 10)
	grid.add_child(_cell_label("Bug budget", 22))
	grid.add_child(_spin_budget)
	_spin_handicap = _spin(StageConfig.HANDICAP_MIN, StageConfig.HANDICAP_MAX, 5)
	_spin_handicap.value = float(StageConfig.HANDICAP_DEFAULT)
	_handicap_label = _cell_label("Sunglasses strength % (Stage 4)", 22)
	grid.add_child(_handicap_label)
	grid.add_child(_spin_handicap)
	_set_stage_pressed(_stage)
	box.add_child(_button("Apply settings", Vector2(280, 64), 26, _on_apply))

	box.add_child(_text_label("Ecosystems", 28))
	_rooms_grid = GridContainer.new()
	_rooms_grid.columns = 2
	_rooms_grid.add_theme_constant_override("h_separation", 16)
	_rooms_grid.add_theme_constant_override("v_separation", 16)
	_rooms_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_rooms_grid)

	box.add_child(_text_label("Roster", 28))
	_roster_grid = GridContainer.new()
	_roster_grid.columns = 5
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_grid.add_theme_constant_override("h_separation", 18)
	_roster_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_roster_grid)


func _text_label(text: String, px: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", COL_INK)
	return l


func _cell_label(text: String, px: int) -> Label:
	var l: Label = _text_label(text, px)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, min_size: Vector2, px: int, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", px)
	b.pressed.connect(cb)
	return b


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var s: SpinBox = SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(200, 52)
	return s


func _margin(px: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


func _card_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.border_color = COL_RULE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _as_array(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _join_names(names: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for n: Variant in names:
		parts.append(str(n))
	return ", ".join(parts)


# === SENDING ===
func _net_send(type: String, fields: Dictionary) -> void:
	if _net != null:
		_net.send(type, fields)


func _send_cmd(type: String, fields: Dictionary = {}) -> void:
	if _token == "":
		_set_status("Create or reopen a game first.")
		return
	var body: Dictionary = fields.duplicate()
	body[Protocol.F_TOKEN] = _token
	_net_send(type, body)


func _set_status(text: String) -> void:
	_status.text = text


func _show_session(on: bool) -> void:
	_session_box.visible = on
	_setup_box.visible = not on


# === SETUP ===
func _on_names_input(event: InputEvent) -> void:
	# A TextEdit takes Tab for indentation, so a keyboard user could never leave it.
	# Tab moves focus instead (Shift+Tab backwards).
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	var target: Control = _names_edit.find_prev_valid_focus() if key.shift_pressed else _names_edit.find_next_valid_focus()
	if target != null:
		target.grab_focus()
		get_viewport().set_input_as_handled()


func _on_create() -> void:
	var names: Array = []
	for line: String in _names_edit.text.split("\n"):
		var nm: String = line.strip_edges()
		if nm != "":
			names.append(nm)
	if names.is_empty():
		_set_status("Type at least one name, one per line.")
		return
	if _net == null or not _net.is_open():
		_set_status("Can't reach the game server. Wait a few seconds and press Create game again; if it keeps failing, the server is down.")
		return
	_set_status("Creating the game...")
	_net_send(Protocol.CREATE_SESSION, {Protocol.F_NAMES: names, Protocol.F_TEACHER_KEY: _key_edit.text.strip_edges()})


func _on_session_created(msg: Dictionary) -> void:
	_code = str(msg.get(Protocol.F_CODE, ""))
	_token = str(msg.get(Protocol.F_TOKEN, ""))
	_resuming = false
	_config_filled = false
	_roster_sig = ""
	_back_btn.visible = false
	_show_session(true)
	_code_label.text = "Game code: %s" % _code
	_set_status("Game created. Students type this code on their screens.")
	session_ready.emit(_code, _token)


## Back to the setup panel for a new code. The old game keeps running on the server (its students stay in it,
## and it expires once nobody is connected); Back to game reopens it. The saved token changes only on Create.
func _on_new_game() -> void:
	_prev_code = _code
	_prev_token = _token
	_code = ""
	_token = ""
	_resuming = false
	_roster_sig = ""
	_prune_rooms({})
	_names_edit.text = "
".join(_roster_names)
	_back_btn.text = "Back to game %s" % _prev_code
	_back_btn.visible = true
	_show_session(false)
	_set_status("Edit the names if needed, then press Create game for a new code.")


func _on_back_to_game() -> void:
	_back_btn.visible = false
	resume(_prev_code, _prev_token)


# === SESSION COMMANDS ===
func _on_start_hunt() -> void:
	_send_cmd(Protocol.START_HUNT)


func _on_stop_hunt() -> void:
	_send_cmd(Protocol.STOP_HUNT)


func _on_advance() -> void:
	_send_cmd(Protocol.ADVANCE)


func _on_apply() -> void:
	var cfg: Dictionary = {
		"stage": _stage,
		"rooms": int(_spin_rooms.value),
		"bugs_start": int(_spin_bugs.value),
		"lizards_start": int(_spin_lizards.value),
		"hunt_seconds": int(_spin_hunt.value),
		"bug_budget": int(_spin_budget.value),
	}
	if _stage == 4:
		cfg["handicap"] = int(_spin_handicap.value)
	_send_cmd(Protocol.CONFIGURE, {Protocol.F_CONFIG: cfg, Protocol.F_ASSIGN: {}})
	_set_status("Settings sent.")


func _on_stage_toggled(on: bool, s: int) -> void:
	if not on:
		return
	_fill_from_config(StageConfig.defaults(s))
	for raw: Variant in _last_rooms:
		if typeof(raw) == TYPE_DICTIONARY:
			_update_room(int((raw as Dictionary).get("room", 0)), raw)


func _fill_from_config(cfg: Dictionary) -> void:
	_spin_rooms.value = float(cfg.get("rooms", 1))
	_spin_bugs.value = float(cfg.get("bugs_start", 0))
	_spin_lizards.value = float(cfg.get("lizards_start", 1))
	_spin_hunt.value = float(cfg.get("hunt_seconds", StageConfig.HUNT_SECONDS_DEFAULT))
	_spin_budget.value = float(cfg.get("bug_budget", StageConfig.BUG_BUDGET_DEFAULT))
	_spin_handicap.value = float(cfg.get("handicap", StageConfig.HANDICAP_DEFAULT))
	_set_stage_pressed(clampi(int(cfg.get("stage", 1)), 1, 4))


func _set_stage_pressed(s: int) -> void:
	_stage = s
	if _spin_handicap != null:
		_spin_handicap.visible = s == 4
		_handicap_label.visible = s == 4
	for i: int in range(_stage_btns.size()):
		_stage_btns[i].set_pressed_no_signal(i == s - 1)


# === TEACHER_STATE ===
func _on_state(msg: Dictionary) -> void:
	var st: Dictionary = _as_dict(msg.get(Protocol.F_STATE, {}))
	if st.is_empty() or _token == "":
		return # no game open (after New game the old game still sends its state until we leave it)
	_resuming = false
	_code = str(msg.get(Protocol.F_CODE, st.get("code", _code)))
	_show_session(true)
	_code_label.text = "Game code: %s" % _code
	if not _config_filled:
		var cfg: Dictionary = _as_dict(st.get("config", {}))
		if not cfg.is_empty():
			_fill_from_config(cfg)
			_config_filled = true
	_set_status("")
	var cfg_now: Dictionary = _as_dict(st.get("config", {}))
	if not cfg_now.is_empty():
		_lizards_start = int(cfg_now.get("lizards_start", _lizards_start))

	var seen: Dictionary = {}
	_last_rooms = _as_array(st.get("rooms", []))
	for raw: Variant in _last_rooms:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = raw
		var idx: int = int(room.get("room", 0))
		seen[idx] = true
		_update_room(idx, room)
	_prune_rooms(seen)
	var any_open: bool = false
	for raw2: Variant in _last_rooms:
		if typeof(raw2) == TYPE_DICTIONARY and not _as_array((raw2 as Dictionary).get("tagin", [])).is_empty():
			any_open = true
	_advance_note.visible = any_open
	_update_roster(_as_array(st.get("roster", [])))


func _on_error(msg: Dictionary) -> void:
	var reason: String = str(msg.get(Protocol.F_REASON, ""))
	if _resuming:
		_resuming = false
		_code = ""
		_token = ""
		_show_session(false)
		_set_status("That saved game could not be reopened (%s). Create a new game, or check the code." % reason)
		return
	if reason == Protocol.R_BAD_TEACHER_KEY:
		_set_status("That teacher key is not right. Check it and press Create game again.")
		return
	_set_status("Something went wrong (%s)." % reason)


# === ROOM CARDS ===
## A card is built once per room and kept. Its "inner" box is rebuilt only when the structure changes
## (phase, round, stage, paused, hunters, members); its counts and seconds labels update in place on
## every state. The "graph" box is never rebuilt, so the graph can be added later.
func _ensure_room_card(idx: int) -> Dictionary:
	if _room_cards.has(idx):
		return _room_cards[idx]
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rooms_grid.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	column.add_child(inner)
	var graph: VBoxContainer = VBoxContainer.new()
	graph.name = "GraphSlot%d" % idx
	column.add_child(graph)
	var rec: Dictionary = {
		"card": card, "inner": inner, "graph": graph, "sig": "",
		"counts": null, "seconds": null, "reminder": null, "picks": {},
	}
	_room_cards[idx] = rec
	return rec


func _room_structure(room: Dictionary) -> Dictionary:
	return {
		"phase": str(room.get("phase", "")),
		"round": int(room.get("round", 0)),
		"stage": int(room.get("stage", _stage)),
		"picked_stage": _stage,
		"paused": bool(room.get("paused", false)),
		"hunters": _as_array(room.get("hunters", [])),
		"members": _as_array(room.get("members", [])),
		"tagin": _as_array(room.get("tagin", [])),
		"can_pick": _as_array(room.get("can_pick", [])),
		"hist_n": _as_array(room.get("history", [])).size(),
		"mutants": _as_array(room.get("mutants", [])),
		"arisen": bool(room.get("mutant_arisen", false)),
		"mutant_slot": str(room.get("mutant_slot", "")),
	}


func _update_room(idx: int, room: Dictionary) -> void:
	var rec: Dictionary = _ensure_room_card(idx)
	var sig: String = JSON.stringify(_room_structure(room))
	if sig != str(rec["sig"]):
		rec["sig"] = sig
		_rebuild_room_inner(idx, room, rec)
	_update_room_dynamic(room, rec)
	_update_graph(room, rec)


## One PopulationGraph per room, added once into the card's graph box and updated from the room's history.
func _update_graph(room: Dictionary, rec: Dictionary) -> void:
	var plot: PopulationGraph = rec.get("plot", null) as PopulationGraph
	if plot == null:
		plot = PopulationGraph.new()
		(rec["graph"] as Control).add_child(plot)
		rec["plot"] = plot
	var hist: Array = _as_array(room.get("history", []))
	var start_bugs: int = int(room.get("bugs_start", 0))
	if not hist.is_empty():
		start_bugs = int(_as_dict(hist[0]).get("bugs_start", start_bugs))
	var stage: int = clampi(int(room.get("stage", _stage)), 1, 4)
	plot.set_history(hist, stage, start_bugs, _lizards_start)


func _rebuild_room_inner(idx: int, room: Dictionary, rec: Dictionary) -> void:
	var inner: VBoxContainer = rec["inner"] as VBoxContainer
	_clear(inner)
	var picks: Dictionary = {}
	rec["picks"] = picks
	var phase: String = str(room.get("phase", ""))
	var round_n: int = int(room.get("round", 0))
	var stage: int = clampi(int(room.get("stage", _stage)), 1, 4)
	var paused: bool = bool(room.get("paused", false))
	var hunters: Array = _as_array(room.get("hunters", []))
	var members: Array = _as_array(room.get("members", []))

	inner.add_child(_text_label("Ecosystem %d" % (idx + 1), 30))
	inner.add_child(_text_label("Stage %d: %s" % [stage, StageConfig.NAMES[stage]], 22))
	if stage != _stage:
		# Settings reach only ecosystems still waiting to start round 1; the rest keep their stage until Reset.
		var fresh: bool = phase == Protocol.PH_SETUP and round_n == 1
		var how: String = "press Apply settings." if fresh else "press Apply settings, then Reset (it starts again from round 1)."
		var note: Label = _text_label("The settings panel has Stage %d picked. To play it here, %s" % [_stage, how], 22)
		note.add_theme_color_override("font_color", COL_ALERT)
		inner.add_child(note)
	var phase_line: String = "%s. Round %d" % [_phase_text(phase), round_n]
	if paused:
		phase_line += " (PAUSED)"
	inner.add_child(_text_label(phase_line, 24))
	if phase == Protocol.PH_ENDED:
		var why: Label = _text_label("%s This ecosystem is over: Next round and Start hunt do nothing here. Reset starts it again from round 1." % SummaryScreen.end_text(str(room.get("end_reason", "")), -1), 22)
		why.add_theme_color_override("font_color", COL_ALERT)
		inner.add_child(why)

	var counts: Label = _text_label("", 24)
	inner.add_child(counts)
	var seconds: Label = _text_label("", 22)
	inner.add_child(seconds)
	var reminder: Label = _text_label("Prediction stop: students write their prediction now.", 24)
	reminder.add_theme_color_override("font_color", COL_ALERT)
	inner.add_child(reminder)
	rec["counts"] = counts
	rec["seconds"] = seconds
	rec["reminder"] = reminder

	inner.add_child(_text_label("Hunting: %s" % ("nobody" if hunters.is_empty() else _join_names(hunters)), 22))
	inner.add_child(_text_label("Members (%d): %s" % [members.size(), "none" if members.is_empty() else _join_names(members)], 22))

	if stage >= 3:
		_build_tagin(idx, room, inner)
	if stage == 4:
		_build_mutant(idx, room, inner)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	row.add_child(_button("Resume" if paused else "Pause", Vector2(180, 60), 24, _on_pause_room.bind(idx, not paused)))
	row.add_child(_button("Reset", Vector2(180, 60), 24, _on_reset_room.bind(idx)))

	if phase == Protocol.PH_SETUP and round_n <= 1:
		inner.add_child(_text_label("Round 1 starting lizards: tick the students who start as lizards.", 22))
		for m: Variant in members:
			var nm: String = str(m)
			var cb: CheckBox = CheckBox.new()
			cb.text = nm
			for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				cb.add_theme_color_override(c, COL_INK)
			cb.button_pressed = nm in hunters
			inner.add_child(cb)
			picks[nm] = cb
		inner.add_child(_button("Set lizards", Vector2(240, 60), 24, _on_set_lizards.bind(idx)))


## Stages 3-4: baby-slot accounting for the open tag-in, a per-round table, and an Assign row per unfilled slot.
func _build_tagin(idx: int, room: Dictionary, inner: VBoxContainer) -> void:
	var tagin: Array = _as_array(room.get("tagin", []))
	var can_pick: Array = _as_array(room.get("can_pick", []))
	var hands: Array = _as_array(room.get("hands", []))
	inner.add_child(_text_label("Hands up (%d): %s" % [hands.size(), "nobody" if hands.is_empty() else _join_names(hands)], 22))
	if not tagin.is_empty():
		var filled: int = 0
		for raw: Variant in tagin:
			if str(_as_dict(raw).get("student", "")) != "":
				filled += 1
		inner.add_child(_text_label("Babies earned %d · picked %d · unfilled %d" % [tagin.size(), filled, tagin.size() - filled], 24))
		for raw: Variant in tagin:
			var slot: Dictionary = _as_dict(raw)
			var parent: String = str(slot.get("parent", ""))
			var kid: String = str(slot.get("student", ""))
			if kid != "":
				var how: String = " (teacher assigned)" if bool(slot.get("by_teacher", false)) else ""
				inner.add_child(_text_label("%s's baby: %s%s" % [parent, kid, how], 22))
				continue
			inner.add_child(_text_label("%s's baby: not picked yet" % parent, 22))
			if can_pick.is_empty():
				inner.add_child(_text_label("Nobody with a raised hand to assign.", 20))
				continue
			var srow: HBoxContainer = HBoxContainer.new()
			srow.add_theme_constant_override("separation", 10)
			inner.add_child(srow)
			var opt: OptionButton = OptionButton.new()
			opt.custom_minimum_size = Vector2(200, 52)
			opt.add_theme_font_size_override("font_size", 22)
			for nm: Variant in can_pick:
				opt.add_item(str(nm))
			srow.add_child(opt)
			srow.add_child(_button("Assign", Vector2(140, 52), 22, _on_assign.bind(idx, str(slot.get("slot", "")), opt)))
	var hist: Array = _as_array(room.get("history", []))
	var has_slots: bool = false
	for raw3: Variant in hist:
		if _as_dict(raw3).has("slots_earned"):
			has_slots = true
	if has_slots:
		inner.add_child(_text_label("Babies by round", 22))
		var grid: GridContainer = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 20)
		inner.add_child(grid)
		for h: String in ["Round", "Babies earned", "picked", "unfilled"]:
			grid.add_child(_cell_label(h, 20))
		for raw4: Variant in hist:
			var r: Dictionary = _as_dict(raw4)
			if not r.has("slots_earned"):
				continue
			grid.add_child(_cell_label(str(int(r.get("round", 0))), 20))
			grid.add_child(_cell_label(str(int(r.get("slots_earned", 0))), 20))
			grid.add_child(_cell_label(str(int(r.get("slots_filled", 0))), 20))
			grid.add_child(_cell_label(str(int(r.get("slots_unfilled", 0))), 20))


## Stage 4: mutant names, the first-mutant chooser (open tag-in, no mutant yet), the teacher fallback
## (between hunts, no mutant yet), and a population table with WILD TYPE and MUTANTS once a mutant exists.
func _build_mutant(idx: int, room: Dictionary, inner: VBoxContainer) -> void:
	var mutants: Array = _as_array(room.get("mutants", []))
	var arisen: bool = bool(room.get("mutant_arisen", false))
	var tagin: Array = _as_array(room.get("tagin", []))
	var phase: String = str(room.get("phase", ""))
	inner.add_child(_text_label("Mutants: %s" % ("none yet" if mutants.is_empty() else _join_names(mutants)), 24))
	if not arisen and not tagin.is_empty():
		inner.add_child(_text_label("First mutant:", 22))
		var opt: OptionButton = OptionButton.new()
		opt.custom_minimum_size = Vector2(260, 52)
		opt.add_theme_font_size_override("font_size", 22)
		opt.add_item("Automatic (random)")
		opt.set_item_metadata(0, "")
		var want: String = str(room.get("mutant_slot", ""))
		for raw: Variant in tagin:
			var slot: Dictionary = _as_dict(raw)
			var kid: String = str(slot.get("student", ""))
			if kid == "":
				continue
			opt.add_item(kid)
			opt.set_item_metadata(opt.item_count - 1, str(slot.get("slot", "")))
			if str(slot.get("slot", "")) == want and want != "":
				opt.select(opt.item_count - 1)
		opt.item_selected.connect(_on_choose_mutant.bind(idx, opt))
		inner.add_child(opt)
		inner.add_child(_text_label("Tip: don't give it to a student who is slower at finding bugs.", 20))
	elif not arisen and tagin.is_empty() and (phase == Protocol.PH_STUDY or phase == Protocol.PH_SETUP):
		var lizards: Array = _as_array(room.get("hunters", []))
		if not lizards.is_empty():
			inner.add_child(_text_label("Add a mutant (teacher)", 22))
			var srow: HBoxContainer = HBoxContainer.new()
			srow.add_theme_constant_override("separation", 10)
			inner.add_child(srow)
			var opt2: OptionButton = OptionButton.new()
			opt2.custom_minimum_size = Vector2(200, 52)
			opt2.add_theme_font_size_override("font_size", 22)
			for nm: Variant in lizards:
				opt2.add_item(str(nm))
			srow.add_child(opt2)
			srow.add_child(_button("Add mutant", Vector2(180, 52), 22, _on_add_mutant.bind(idx, opt2)))
			inner.add_child(_text_label("Shown in the data as a teacher intervention. Suggested after round 2 if no baby has been born.", 20))
	var hist: Array = _as_array(room.get("history", []))
	if not hist.is_empty():
		inner.add_child(_text_label("Population by round", 22))
		var with_m: bool = SummaryScreen.history_has_mutants(hist)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 5 if with_m else 3
		grid.add_theme_constant_override("h_separation", 20)
		inner.add_child(grid)
		var heads: Array = ["Round", "BUGS", "LIZARDS"]
		if with_m:
			heads.append("WILD TYPE")
			heads.append("MUTANTS")
		for h: Variant in heads:
			grid.add_child(_cell_label(str(h), 20))
		for raw2: Variant in hist:
			var r: Dictionary = _as_dict(raw2)
			grid.add_child(_cell_label(str(int(r.get("round", 0))), 20))
			grid.add_child(_cell_label(str(int(r.get("BUGS", 0))), 20))
			grid.add_child(_cell_label(str(int(r.get("LIZARDS", 0))), 20))
			if with_m:
				var seen: bool = bool(r.get("mutant_arisen", false))
				grid.add_child(_cell_label(str(int(r.get("WILD", 0))) if seen else "–", 20))
				var mt: String = str(int(r.get("MUTANTS", 0))) if seen else "–"
				if bool(r.get("mutant_fallback", false)):
					mt += " (teacher)"
				grid.add_child(_cell_label(mt, 20))


func _on_choose_mutant(index: int, idx: int, opt: OptionButton) -> void:
	_send_cmd(Protocol.CHOOSE_MUTANT, {Protocol.F_ROOM: idx, Protocol.F_SLOT: str(opt.get_item_metadata(index))})


func _on_add_mutant(idx: int, opt: OptionButton) -> void:
	if opt.item_count == 0 or opt.selected < 0:
		return
	_send_cmd(Protocol.ADD_MUTANT, {Protocol.F_ROOM: idx, Protocol.F_NAME: opt.get_item_text(opt.selected)})
	_set_status("Mutant added for Ecosystem %d (shown in the data as a teacher intervention)." % (idx + 1))


func _on_assign(idx: int, slot_id: String, opt: OptionButton) -> void:
	if opt.item_count == 0 or opt.selected < 0:
		return
	_send_cmd(Protocol.ASSIGN_SLOT, {Protocol.F_ROOM: idx, Protocol.F_SLOT: slot_id, Protocol.F_NAME: opt.get_item_text(opt.selected)})


func _phase_text(phase: String) -> String:
	if phase == Protocol.PH_SETUP:
		return "Setup, waiting for the hunt"
	if phase == Protocol.PH_HUNT:
		return "Hunt in progress"
	if phase == Protocol.PH_STUDY:
		return "Round results, waiting for Next round"
	if phase == Protocol.PH_ENDED:
		return "Ended"
	return phase


func _update_room_dynamic(room: Dictionary, rec: Dictionary) -> void:
	var counts: Label = rec["counts"] as Label
	var seconds: Label = rec["seconds"] as Label
	var reminder: Label = rec["reminder"] as Label
	if counts == null or seconds == null or reminder == null:
		return
	var phase: String = str(room.get("phase", ""))
	counts.text = "Caught: %d    Remaining: %d" % [int(room.get("caught", 0)), int(room.get("remaining", 0))]
	seconds.text = ("Seconds left: %d" % int(room.get("seconds_left", 0))) if phase == Protocol.PH_HUNT else ""

	var show_reminder: bool = false
	var hist: Array = _as_array(room.get("history", []))
	if not hist.is_empty():
		var last: Dictionary = _as_dict(hist[hist.size() - 1])
		var stage: int = clampi(int(room.get("stage", _stage)), 1, 4)
		show_reminder = int(last.get("round", -1)) == StageConfig.PREDICTION_AFTER_ROUND[stage]
	reminder.visible = show_reminder


func _prune_rooms(seen: Dictionary) -> void:
	for key: Variant in _room_cards.keys():
		if seen.has(key):
			continue
		var rec: Dictionary = _room_cards[key]
		var card: Control = rec["card"] as Control
		_rooms_grid.remove_child(card)
		card.queue_free()
		_room_cards.erase(key)


func _on_pause_room(idx: int, value: bool) -> void:
	_send_cmd(Protocol.PAUSE_ROOM, {Protocol.F_ROOM: idx, Protocol.F_VALUE: value})


func _on_reset_room(idx: int) -> void:
	_send_cmd(Protocol.RESET_ROOM, {Protocol.F_ROOM: idx})


func _on_set_lizards(idx: int) -> void:
	var rec: Dictionary = _room_cards.get(idx, {})
	var picks: Dictionary = _as_dict(rec.get("picks", {}))
	var chosen: Array = []
	for nm: Variant in picks.keys():
		var cb: CheckBox = picks[nm] as CheckBox
		if cb != null and cb.button_pressed:
			chosen.append(str(nm))
	_send_cmd(Protocol.SET_LIZARDS, {Protocol.F_ROOM: idx, Protocol.F_LIZARDS: chosen})
	_set_status("Lizards sent for Ecosystem %d." % (idx + 1))


# === ROSTER ===
func _update_roster(roster: Array) -> void:
	var notes_on: bool = false
	for raw5: Variant in _last_rooms:
		if typeof(raw5) == TYPE_DICTIONARY and int((raw5 as Dictionary).get("stage", 1)) >= 3:
			notes_on = true
	var sig: String = JSON.stringify([roster, notes_on])
	if sig == _roster_sig:
		return
	_roster_sig = sig
	_roster_names.clear()
	_clear(_roster_grid)
	_roster_grid.columns = 6 if notes_on else 5
	for h: String in ["Name", "Ecosystem", "Seat", "Connection", "Notes", ""]:
		if h == "Notes" and not notes_on:
			continue
		_roster_grid.add_child(_cell_label(h, 22))
	for raw: Variant in roster:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = raw
		var nm: String = str(e.get("name", ""))
		_roster_names.append(nm)
		var taken: bool = bool(e.get("taken", false))
		var connected: bool = bool(e.get("connected", false))
		_roster_grid.add_child(_cell_label(nm, 22))
		_roster_grid.add_child(_cell_label("Ecosystem %d" % (int(e.get("room", 0)) + 1), 22))
		_roster_grid.add_child(_cell_label("taken" if taken else "free", 22))
		_roster_grid.add_child(_cell_label("connected" if connected else "not connected", 22))
		if notes_on:
			var notes: Array = []
			if bool(e.get("hand", false)):
				notes.append("hand up")
			if not bool(e.get("been_lizard", false)):
				notes.append("not yet a lizard")
			_roster_grid.add_child(_cell_label(", ".join(PackedStringArray(notes)), 22))
		if taken:
			_roster_grid.add_child(_button("Release", Vector2(160, 52), 22, _on_release.bind(nm)))
		else:
			_roster_grid.add_child(_cell_label("", 22))


func _on_release(nm: String) -> void:
	_send_cmd(Protocol.RELEASE_SEAT, {Protocol.F_NAME: nm})
