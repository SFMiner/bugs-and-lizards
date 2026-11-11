class_name SummaryScreen
extends Control
## What a student sees whenever they are not hunting: the room's phase, their own role this round,
## the latest round summary and a history table for the organizer. Messages arrive through handle(),
## routed by main.gd. Only messages for this student's room are shown.

signal leave_requested

const COL_BG: Color = Color(0.93, 0.95, 0.9, 1)
const COL_INK: Color = Color(0.1, 0.12, 0.1, 1)

var _built: bool = false
var _player_name: String = ""
var _room: int = -1
var _header: Label = null
var _phase: Label = null
var _round: Label = null
var _caught: Label = null
var _remaining: Label = null
var _role: Label = null
var _summary_box: VBoxContainer = null
var _history_grid: GridContainer = null
var _graph_slot: VBoxContainer = null
var _graph: PopulationGraph = null
var _start_lizards: int = -1 # remembered from the round-1 SUMMARY; -1 = not seen yet


func _ready() -> void:
	_ensure_built()


func set_identity(player_name: String, room: int) -> void:
	_ensure_built()
	_player_name = player_name
	_room = room
	_header.text = "You are %s — Ecosystem %d" % [player_name, room + 1]


func graph_slot() -> Control:
	_ensure_built()
	return _graph_slot


func handle(msg: Dictionary) -> void:
	_ensure_built()
	var t: String = str(msg.get(Protocol.F_TYPE, ""))
	if t == Protocol.ROOM_STATE:
		_on_room_state(msg)
	elif t == Protocol.SUMMARY:
		_on_summary(msg)


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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin: MarginContainer = _margin(24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_header = _text_label("You are watching this round", 34)
	column.add_child(_header)
	var leave: Button = Button.new()
	leave.text = "Wrong game or name? Leave this game"
	leave.add_theme_font_size_override("font_size", 22)
	leave.custom_minimum_size = Vector2(420, 52)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	leave.pressed.connect(func() -> void: leave_requested.emit())
	column.add_child(leave)
	_phase = _text_label("", 30)
	column.add_child(_phase)
	_round = _text_label("", 24)
	column.add_child(_round)
	_caught = _text_label("", 24)
	column.add_child(_caught)
	_remaining = _text_label("", 24)
	column.add_child(_remaining)
	_role = _text_label("", 26)
	column.add_child(_role)

	column.add_child(HSeparator.new())
	column.add_child(_text_label("Latest round results", 28))
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 6)
	column.add_child(_summary_box)
	_summary_box.add_child(_text_label("Round results appear here after each hunt.", 22))

	column.add_child(HSeparator.new())
	column.add_child(_text_label("For your organizer (bugs after the hunt, lizards after births)", 22))
	_history_grid = GridContainer.new()
	_history_grid.columns = 3
	_history_grid.add_theme_constant_override("h_separation", 28)
	_history_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(_history_grid)

	_graph_slot = VBoxContainer.new()
	_graph_slot.name = "GraphSlot"
	_graph_slot.add_theme_constant_override("separation", 8)
	column.add_child(_graph_slot)


func _text_label(text: String, px: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", COL_INK)
	return l


func _margin(px: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _as_array(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


# === ROOM_STATE ===
func _is_my_room(msg: Dictionary) -> bool:
	if _room < 0:
		return true
	return int(msg.get(Protocol.F_ROOM, _room)) == _room


func _on_room_state(msg: Dictionary) -> void:
	if not _is_my_room(msg):
		return
	var st: Dictionary = _as_dict(msg.get(Protocol.F_STATE, {}))
	var phase: String = str(st.get("phase", ""))
	var secs: int = int(st.get("seconds_left", 0))
	_phase.text = _phase_words(phase, secs)
	_round.text = "Round %d" % int(st.get("round", 0))
	_caught.text = "Bugs caught so far: %d" % int(st.get("caught", 0))
	_remaining.text = "Bugs remaining: %d" % int(st.get("remaining", 0))
	var hunters: Array = _as_array(st.get("hunters", []))
	if _player_name != "" and _player_name in hunters:
		_role.text = "You are a lizard this round"
	else:
		_role.text = "You are watching this round"


func _phase_words(phase: String, secs: int) -> String:
	if phase == Protocol.PH_SETUP:
		return "Waiting for the teacher to start the hunt"
	if phase == Protocol.PH_HUNT:
		return "Hunt in progress: %d s left" % secs
	if phase == Protocol.PH_STUDY:
		return "Round results"
	if phase == Protocol.PH_ENDED:
		return "This ecosystem has ended"
	return phase


# === SUMMARY ===
func _on_summary(msg: Dictionary) -> void:
	if not _is_my_room(msg):
		return
	var s: Dictionary = _as_dict(msg.get(Protocol.F_SUMMARY, {}))
	if s.is_empty():
		return
	var stage: int = int(s.get("stage", 1))
	_clear(_summary_box)
	_summary_box.add_child(_text_label("Round %d" % int(s.get("round", 0)), 28))
	_summary_box.add_child(_text_label("Bugs remaining after hunt: %d" % int(s.get("BUGS", 0)), 24))
	_summary_box.add_child(_text_label("Bugs at next round start: %d" % int(s.get("bugs_next_start", 0)), 24))
	_summary_box.add_child(_text_label("Lizards: %d" % int(s.get("LIZARDS", 0)), 24))
	if stage == 4:
		_summary_box.add_child(_text_label("Mutant lizards: %d" % int(s.get("MUTANTS", 0)), 24))

	var captures: Dictionary = _as_dict(s.get("captures", {}))
	var survived: Array = _as_array(s.get("survived", []))
	var starved: Array = _as_array(s.get("starved", []))
	for nm: Variant in survived:
		var n: String = str(nm)
		_summary_box.add_child(_text_label("%s: %d bugs — survived" % [n, int(captures.get(n, 0))], 22))
	for nm: Variant in starved:
		var n: String = str(nm)
		_summary_box.add_child(_text_label("%s: %d bugs — starved" % [n, int(captures.get(n, 0))], 22))

	if bool(s.get("ended", false)):
		_summary_box.add_child(_text_label(end_text(str(s.get("end_reason", "")), int(s.get("bugs_next_start", 0))), 26))

	var history: Array = _as_array(s.get("history", []))
	_fill_history(history, stage == 4)
	_update_graph(s, history, stage)


## Starting lizards: the round-1 SUMMARY's survived + starved (every starter hunts in round 1). Later
## summaries reuse that; if this student never saw round 1, the first record's LIZARDS stands in.
func _update_graph(s: Dictionary, history: Array, stage: int) -> void:
	if int(s.get("round", 0)) == 1 and history.size() == 1:
		_start_lizards = _as_array(s.get("survived", [])).size() + _as_array(s.get("starved", [])).size()
	var start_lizards: int = _start_lizards
	var start_bugs: int = int(s.get("bugs_start", 0))
	if not history.is_empty():
		var first: Dictionary = _as_dict(history[0])
		start_bugs = int(first.get("bugs_start", start_bugs))
		if start_lizards < 0:
			start_lizards = int(first.get("LIZARDS", 0))
	if start_lizards < 0:
		start_lizards = 0
	if _graph == null:
		_graph = PopulationGraph.new()
		_graph_slot.add_child(_graph)
	_graph.set_history(history, stage, start_bugs, start_lizards)


## Shared with the teacher card; bugs_next < 0 leaves the overrun count out.
static func end_text(reason: String, bugs_next: int) -> String:
	if reason == RoundRules.END_OVERRUN:
		return "The bugs have overrun the habitat." if bugs_next < 0 else "The bugs have overrun the habitat: %d bugs" % bugs_next
	if reason == RoundRules.END_NO_BUGS:
		return "No bugs are left."
	if reason == RoundRules.END_NO_LIZARDS:
		return "No lizards survived."
	if reason == RoundRules.END_FEW_BUGS:
		return "Five or fewer bugs are left."
	if reason == RoundRules.END_ROUNDS:
		return "That was the last round."
	return "This ecosystem has ended."


## A table cell: no wrapping, or a GridContainer squeezes each column to one character.
func _cell(text: String, px: int) -> Label:
	var l: Label = _text_label(text, px)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _fill_history(history: Array, with_mutants: bool) -> void:
	_clear(_history_grid)
	_history_grid.columns = 4 if with_mutants else 3
	_history_grid.add_child(_cell("Round", 22))
	_history_grid.add_child(_cell("BUGS", 22))
	_history_grid.add_child(_cell("LIZARDS", 22))
	if with_mutants:
		_history_grid.add_child(_cell("MUTANTS", 22))
	for raw: Variant in history:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = raw
		_history_grid.add_child(_cell(str(int(r.get("round", 0))), 22))
		_history_grid.add_child(_cell(str(int(r.get("BUGS", 0))), 22))
		_history_grid.add_child(_cell(str(int(r.get("LIZARDS", 0))), 22))
		if with_mutants:
			_history_grid.add_child(_cell(str(int(r.get("MUTANTS", 0))), 22))
