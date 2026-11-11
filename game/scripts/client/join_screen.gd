class_name JoinScreen
extends Control
## Student join. Step 1: the 4-digit session code, typed on the on-screen pad or the physical keys
## (no text field). Step 2: pick a free name from the roster. Messages arrive through handle(), routed
## by main.gd. Emits joined() once the server accepts the seat.

signal joined(player_name: String, token: String, room: int, code: String)

const CODE_LENGTH: int = 4
const COL_BG: Color = Color(0.93, 0.95, 0.9, 1)
const COL_INK: Color = Color(0.1, 0.12, 0.1, 1)
const COL_ALERT: Color = Color(0.62, 0.1, 0.08, 1)

var _net: NetClient = null
var _built: bool = false
var _step: int = 1
var _digits: String = ""
var _code: String = ""
var _keep_message: bool = false
var _step1: VBoxContainer = null
var _step2: VBoxContainer = null
var _code_label: Label = null
var _join_btn: Button = null
var _name_scroll: ScrollContainer = null
var _name_grid: GridContainer = null
var _message: Label = null


func _ready() -> void:
	_ensure_built()


func setup(net: NetClient) -> void:
	_net = net
	_ensure_built()


func handle(msg: Dictionary) -> void:
	_ensure_built()
	var t: String = str(msg.get(Protocol.F_TYPE, ""))
	if t == Protocol.ROSTER:
		_on_roster(msg)
	elif t == Protocol.JOINED:
		_on_joined(msg)
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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin: MarginContainer = _margin(24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# Step 1: code entry.
	_step1 = VBoxContainer.new()
	_step1.add_theme_constant_override("separation", 10)
	column.add_child(_step1)
	_step1.add_child(_text_label("Join the game", 36))
	_step1.add_child(_text_label("Type the 4-digit code from the board, on the pad or on the keyboard.", 22))
	_code_label = _text_label("", 56)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step1.add_child(_code_label)

	var pad: GridContainer = GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 12)
	pad.add_theme_constant_override("v_separation", 10)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_step1.add_child(pad)
	for d: int in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		pad.add_child(_button(str(d), Vector2(150, 64), 32, _on_digit.bind(d)))
	pad.add_child(_button("Clear", Vector2(150, 64), 26, _on_clear))
	pad.add_child(_button("0", Vector2(150, 64), 32, _on_digit.bind(0)))
	pad.add_child(_button("Back", Vector2(150, 64), 26, _on_backspace))

	_join_btn = _button("Join", Vector2(340, 72), 30, _on_join)
	_join_btn.disabled = true
	_join_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_step1.add_child(_join_btn)

	# Step 2: name picking.
	_step2 = VBoxContainer.new()
	_step2.add_theme_constant_override("separation", 10)
	_step2.visible = false
	column.add_child(_step2)
	_step2.add_child(_text_label("Pick your name", 36))
	_step2.add_child(_text_label("Tap your name. Names marked (taken) are already used.", 22))
	_name_scroll = ScrollContainer.new()
	_name_scroll.custom_minimum_size = Vector2(0, 320)
	_name_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_step2.add_child(_name_scroll)
	_name_grid = GridContainer.new()
	_name_grid.columns = 3
	_name_grid.add_theme_constant_override("h_separation", 12)
	_name_grid.add_theme_constant_override("v_separation", 10)
	_name_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_scroll.add_child(_name_grid)
	_step2.add_child(_button("Back", Vector2(220, 60), 26, _on_back_to_code))

	_message = _text_label("", 22)
	column.add_child(_message)
	_refresh_code()


func _text_label(text: String, px: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", COL_INK)
	return l


func _button(text: String, min_size: Vector2, px: int, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", px)
	b.pressed.connect(cb)
	return b


func _margin(px: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


# === STEP 1: CODE ENTRY ===
func _unhandled_input(event: InputEvent) -> void:
	if _step != 1 or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	# Physical key first: with an input method (IME) on, keycode can be wrong while physical_keycode is right.
	var k: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var digit: int = -1
	if k >= KEY_0 and k <= KEY_9:
		digit = k - KEY_0
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		digit = k - KEY_KP_0
	if digit >= 0:
		_on_digit(digit)
	elif k == KEY_BACKSPACE:
		_on_backspace()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_digit(d: int) -> void:
	if _digits.length() >= CODE_LENGTH:
		return
	_digits += str(d)
	_show_message("", false)
	_refresh_code()


func _on_backspace() -> void:
	if _digits.length() == 0:
		return
	_digits = _digits.substr(0, _digits.length() - 1)
	_refresh_code()


func _on_clear() -> void:
	_digits = ""
	_refresh_code()


func _refresh_code() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(CODE_LENGTH):
		parts.append(_digits.substr(i, 1) if i < _digits.length() else "_")
	_code_label.text = " ".join(parts)
	var was_full: bool = not _join_btn.disabled
	var full: bool = _digits.length() == CODE_LENGTH
	_join_btn.disabled = not full
	if full and not was_full:
		_join_btn.grab_focus()


func _on_join() -> void:
	if _digits.length() != CODE_LENGTH:
		return
	_code = _digits
	_show_message("Looking up the game...", false)
	_send(Protocol.LOOKUP, {Protocol.F_CODE: _code})


# === STEP 2: NAME PICKING ===
func _on_roster(msg: Dictionary) -> void:
	_code = str(msg.get(Protocol.F_CODE, _code))
	var raw: Variant = msg.get(Protocol.F_NAMES, [])
	var entries: Array = raw if typeof(raw) == TYPE_ARRAY else []
	_clear(_name_grid)
	var first_free: Button = null
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var nm: String = str(e.get("name", ""))
		if nm == "":
			continue
		var taken: bool = bool(e.get("taken", false))
		var label: String = (nm + " (taken)") if taken else nm
		var b: Button = _button(label, Vector2(250, 60), 24, _on_pick.bind(nm))
		b.disabled = taken
		_name_grid.add_child(b)
		if first_free == null and not taken:
			first_free = b
	_set_step(2)
	if not _keep_message:
		_show_message("", false)
	_keep_message = false
	if first_free != null:
		first_free.grab_focus()


func _on_pick(nm: String) -> void:
	_show_message("Joining as %s..." % nm, false)
	_send(Protocol.PICK_NAME, {Protocol.F_CODE: _code, Protocol.F_NAME: nm})


## Back to an empty code pad (the student left their game).
func reset() -> void:
	_on_clear()
	_on_back_to_code()


func _on_back_to_code() -> void:
	_set_step(1)
	_show_message("", false)


func _on_joined(msg: Dictionary) -> void:
	var player_name: String = str(msg.get(Protocol.F_NAME, ""))
	var token: String = str(msg.get(Protocol.F_TOKEN, ""))
	var room: int = int(msg.get(Protocol.F_ROOM, 0))
	_show_message("", false)
	joined.emit(player_name, token, room, _code)


func _on_error(msg: Dictionary) -> void:
	var reason: String = str(msg.get(Protocol.F_REASON, ""))
	if reason == Protocol.R_BAD_CODE:
		_set_step(1)
		_show_message("No game with that code. Check the code on the board.", true)
	elif reason == Protocol.R_NAME_TAKEN:
		_show_message("That name is already taken. Pick your own name, or ask your teacher.", true)
		if _code != "":
			_keep_message = true
			_send(Protocol.LOOKUP, {Protocol.F_CODE: _code})
	else:
		_show_message("Something went wrong (%s)." % reason, true)


# === HELPERS ===
func _set_step(n: int) -> void:
	_step = n
	_step1.visible = n == 1
	_step2.visible = n == 2


func _show_message(text: String, is_error: bool) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", COL_ALERT if is_error else COL_INK)


func _send(type: String, fields: Dictionary) -> void:
	if _net != null:
		_net.send(type, fields)
