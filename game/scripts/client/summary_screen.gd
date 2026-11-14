class_name SummaryScreen
extends Control
## What a student sees whenever they are not hunting: the room's phase, their own role this round,
## the latest round summary and a history table for the organizer. Messages arrive through handle(),
## routed by main.gd. Only messages for this student's room are shown.

signal leave_requested
signal send_requested(type: String, fields: Dictionary) # RAISE_HAND / PICK_OFFSPRING; client_app forwards to the net

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
var _rule4_box: VBoxContainer = null # Stage 4 rule lines, inside _rule_box
var _mutants: Array = [] # students whose current lizard is a mutant (ROOM_STATE.mutants)
var _start_lizards: int = -1 # remembered from the round-1 SUMMARY; -1 = not seen yet
var _stage: int = 1
var _hunters: Array = []
var _hands: Array = []
var _tagin: Array = [] # state.tagin: [{slot, parent, student, by_teacher}]
var _can_pick: Array = []
var _tagin_open: bool = false # a summary said tagin_open, or the state shows slots
var _survived: Array = [] # last summary's survivors
var _survived_known: bool = false
var _tagin_sig: String = ""
var _rule_box: VBoxContainer = null
var _hand_box: VBoxContainer = null
var _hand_btn: Button = null
var _tagin_box: VBoxContainer = null
var _tagin_msg: Label = null


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

	_rule_box = VBoxContainer.new()
	_rule_box.visible = false
	column.add_child(_rule_box)
	_rule_box.add_child(_text_label("Babies: every 5 bugs past the 5 you need earns one baby lizard. A baby is a classmate you pick; they hunt next round.", 22))
	_rule_box.add_child(_text_label("(This is a model: real lizards need two parents.)", 20))
	_rule4_box = VBoxContainer.new()
	_rule4_box.visible = false
	_rule_box.add_child(_rule4_box)
	_rule4_box.add_child(_text_label("Stage 4: wild-type lizards wear sunglasses. A mutant sees clearly, and only a mutant's babies are mutants.", 22))
	_rule4_box.add_child(_text_label("(A model: real mutations don't appear because they are needed.)", 20))

	_hand_box = VBoxContainer.new()
	_hand_box.visible = false
	_hand_box.add_theme_constant_override("separation", 6)
	column.add_child(_hand_box)
	_hand_btn = Button.new()
	_hand_btn.toggle_mode = true
	_hand_btn.text = "Raise my hand"
	_hand_btn.add_theme_font_size_override("font_size", 26)
	_hand_btn.custom_minimum_size = Vector2(420, 64)
	_hand_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hand_btn.toggled.connect(_on_hand_toggled)
	_hand_box.add_child(_hand_btn)
	_hand_box.add_child(_text_label("Raise your hand if you want to be picked as a baby lizard.", 22))

	_tagin_box = VBoxContainer.new()
	_tagin_box.add_theme_constant_override("separation", 8)
	column.add_child(_tagin_box)
	_tagin_msg = _text_label("", 24)
	_tagin_msg.add_theme_color_override("font_color", Color(0.62, 0.1, 0.08, 1))
	_tagin_msg.visible = false
	column.add_child(_tagin_msg)
	# Tag-in controls sit right under the phase line so a parent sees them without scrolling.
	var after: int = _phase.get_index()
	for node: Control in [_hand_box, _tagin_box, _tagin_msg, _rule_box]:
		after += 1
		column.move_child(node, after)

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
	_stage = int(st.get("stage", _stage))
	_hunters = hunters
	_mutants = _as_array(st.get("mutants", []))
	if _player_name != "" and _player_name in _mutants and phase != Protocol.PH_HUNT:
		_role.text = "You are a mutant."
	_hands = _as_array(st.get("hands", []))
	_tagin = _as_array(st.get("tagin", []))
	_can_pick = _as_array(st.get("can_pick", []))
	if not _tagin.is_empty():
		_tagin_open = true
	elif phase != Protocol.PH_STUDY:
		_tagin_open = false
	_refresh_tagin()


# === TAG-IN (stages 3-4) ===
func handle_error(reason: String) -> void:
	_ensure_built()
	if reason == Protocol.R_PICK_TAKEN:
		_tagin_msg.text = "Someone else picked them first — pick again."
	elif reason == Protocol.R_CANNOT_PICK:
		_tagin_msg.text = "That pick didn't work."
	else:
		return
	_tagin_msg.visible = true


func _is_lizard() -> bool:
	if _tagin_open and _survived_known:
		return _player_name in _survived
	return _player_name in _hunters


func _on_hand_toggled(on: bool) -> void:
	_refresh_hand_text(on)
	send_requested.emit(Protocol.RAISE_HAND, {Protocol.F_VALUE: on})


func _refresh_hand_text(on: bool) -> void:
	_hand_btn.text = "Hand raised — lower it" if on else "Raise my hand"


func _refresh_tagin() -> void:
	var on: bool = _stage >= 3
	_rule_box.visible = on
	_rule4_box.visible = _stage == 4
	var in_slot: bool = false # already picked: the pick is final, so the hand no longer matters
	for raw: Variant in _tagin:
		if str(_as_dict(raw).get("student", "")) == _player_name:
			in_slot = true
	_hand_box.visible = on and not _is_lizard() and not in_slot
	var up: bool = _player_name in _hands
	_hand_btn.set_pressed_no_signal(up) # the server is the truth
	_refresh_hand_text(up)
	if not on:
		_clear(_tagin_box)
		_tagin_sig = ""
		return
	var sig: String = JSON.stringify([_tagin, _can_pick, _player_name])
	if sig == _tagin_sig:
		return
	_tagin_sig = sig
	_tagin_msg.visible = false # the state changed under the message
	_clear(_tagin_box)
	if _tagin.is_empty():
		return
	_tagin_box.add_child(_text_label("Baby lizards", 28))
	var mine_unfilled: int = 0
	var mine_total: int = 0
	var picked_by: String = ""
	for raw: Variant in _tagin:
		var slot: Dictionary = _as_dict(raw)
		var parent: String = str(slot.get("parent", ""))
		var kid: String = str(slot.get("student", ""))
		var line: String = "%s's baby: %s" % [parent, kid if kid != "" else "not picked yet"]
		_tagin_box.add_child(_text_label(line, 24))
		if parent == _player_name:
			mine_total += 1
			if kid == "":
				mine_unfilled += 1
		if kid == _player_name and kid != "":
			picked_by = parent
	if picked_by != "":
		_tagin_box.add_child(_text_label("You were picked by %s! You hunt next round." % picked_by, 26))
	if mine_unfilled > 0:
		_tagin_box.add_child(_text_label("You earned %d baby lizard%s. Pick a classmate with a raised hand. Your pick is final." % [mine_total, "" if mine_total == 1 else "s"], 24))
		if _can_pick.is_empty():
			_tagin_box.add_child(_text_label("Nobody has a raised hand right now. Ask your teacher, or wait for a hand.", 22))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_tagin_box.add_child(flow)
		for nm: Variant in _can_pick:
			var b: Button = Button.new()
			b.text = str(nm)
			b.custom_minimum_size = Vector2(180, 56)
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(_on_pick.bind(str(nm)))
			flow.add_child(b)


func _on_pick(nm: String) -> void:
	send_requested.emit(Protocol.PICK_OFFSPRING, {Protocol.F_NAME: nm})


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
	var open: bool = bool(s.get("tagin_open", false))
	_stage = stage
	_tagin_open = open
	_survived = _as_array(s.get("survived", []))
	_survived_known = true
	_refresh_tagin()
	_clear(_summary_box)
	_summary_box.add_child(_text_label("Round %d" % int(s.get("round", 0)), 28))
	_summary_box.add_child(_text_label("Bugs remaining after hunt: %d" % int(s.get("BUGS", 0)), 24))
	_summary_box.add_child(_text_label("Bugs at next round start: %d" % int(s.get("bugs_next_start", 0)), 24))
	var arisen: bool = bool(s.get("mutant_arisen", false))
	if open:
		if arisen:
			var wild_n: int = 0
			for sn: Variant in _survived:
				if not (str(sn) in _mutants):
					wild_n += 1
			_summary_box.add_child(_text_label("Lizards: %d survived (%d wild type, %d mutants); babies are being picked" % [_survived.size(), wild_n, _survived.size() - wild_n], 24))
		else:
			_summary_box.add_child(_text_label("Lizards: %d survived; babies are being picked" % _survived.size(), 24))
	else:
		_summary_box.add_child(_text_label("Lizards: %d" % int(s.get("LIZARDS", 0)), 24))
		if stage == 4 and arisen:
			_summary_box.add_child(_text_label("Wild type: %d    Mutants: %d" % [int(s.get("WILD", 0)), int(s.get("MUTANTS", 0))], 24))
	var new_mutants: Array = _as_array(s.get("new_mutants", []))
	if stage == 4 and not new_mutants.is_empty():
		var others: PackedStringArray = PackedStringArray()
		var me_new: bool = false
		for nm0: Variant in new_mutants:
			if str(nm0) == _player_name:
				me_new = true
			else:
				others.append(str(nm0))
		if me_new:
			var big: Label = _text_label("You are a MUTANT lizard! You can see clearly in the dim forest. (Only your babies inherit it.)", 30)
			_summary_box.add_child(big)
		if not others.is_empty():
			_summary_box.add_child(_text_label("New mutant: %s" % ", ".join(others) if others.size() == 1 else "New mutants: %s" % ", ".join(others), 24))

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
	_fill_history(history, stage == 4 and history_has_mutants(history), stage >= 3)
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


## True once any record shows a mutant (tables then add WILD TYPE and MUTANTS). Shared with the teacher card.
static func history_has_mutants(history: Array) -> bool:
	for raw: Variant in history:
		if typeof(raw) == TYPE_DICTIONARY and bool((raw as Dictionary).get("mutant_arisen", false)):
			return true
	return false


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


func _fill_history(history: Array, with_mutants: bool, want_slots: bool = false) -> void:
	_clear(_history_grid)
	var with_slots: bool = false
	if want_slots:
		for raw0: Variant in history:
			if typeof(raw0) == TYPE_DICTIONARY and (raw0 as Dictionary).has("slots_earned"):
				with_slots = true
	_history_grid.columns = (5 if with_mutants else 3) + (3 if with_slots else 0)
	_history_grid.add_child(_cell("Round", 22))
	_history_grid.add_child(_cell("BUGS", 22))
	_history_grid.add_child(_cell("LIZARDS", 22))
	if with_mutants:
		_history_grid.add_child(_cell("WILD TYPE", 22))
		_history_grid.add_child(_cell("MUTANTS", 22))
	if with_slots:
		_history_grid.add_child(_cell("Babies earned", 22))
		_history_grid.add_child(_cell("picked", 22))
		_history_grid.add_child(_cell("unfilled", 22))
	for raw: Variant in history:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = raw
		_history_grid.add_child(_cell(str(int(r.get("round", 0))), 22))
		_history_grid.add_child(_cell(str(int(r.get("BUGS", 0))), 22))
		_history_grid.add_child(_cell(str(int(r.get("LIZARDS", 0))), 22))
		if with_mutants:
			var seen: bool = bool(r.get("mutant_arisen", false))
			_history_grid.add_child(_cell(str(int(r.get("WILD", 0))) if seen else "–", 22))
			_history_grid.add_child(_cell(str(int(r.get("MUTANTS", 0))) if seen else "–", 22))
		if with_slots:
			_history_grid.add_child(_cell(str(int(r.get("slots_earned", 0))), 22))
			_history_grid.add_child(_cell(str(int(r.get("slots_filled", 0))), 22))
			_history_grid.add_child(_cell(str(int(r.get("slots_unfilled", 0))), 22))
