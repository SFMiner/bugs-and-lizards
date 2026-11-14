class_name HuntView
extends Node3D
## The 3D hunt: habitat, bugs, own lizard, HUD. The manager (main.gd) routes server messages in through
## begin_hunt / on_bug_gone / on_lizards_seen / on_capture_ok / on_capture_rejected / end_hunt. Nothing is shown between hunts.

const HUD_FONT: int = 20
const HINT_TEXT: String = "W/S or Up/Down: walk   A/D: sidestep   Q/E or Left/Right: turn   R/F: look up/down   Space: catch the bug under the crosshair   Click: mouse look (Esc frees it)"

var _net: NetClient
var _habitat: Habitat
var _bugs: BugField
var _player: PlayerController
var _hud: CanvasLayer
var _count_label: Label
var _time_label: Label
var _hint_label: Label
var _flash_label: Label
var _hud_visible: bool = true
var _hunting: bool = false
var _seconds_left: float = 0.0
var _pos_timer: float = 0.0
var _pending: Dictionary = {} # bug ids with a CAPTURE in flight
var _others: Dictionary = {} # other hunter name -> LizardAvatar
var _flash_tween: Tween


func setup(net: NetClient) -> void:
	_net = net


func _ready() -> void:
	_ensure_built()
	_show_all(false)


func begin_hunt(msg: Dictionary) -> void:
	_ensure_built()
	_pending.clear()
	var bug_list: Array = msg.get(Protocol.F_BUGS, [])
	_bugs.set_bugs(bug_list)
	var start: Vector3 = Protocol.wire_to_vec(msg.get(Protocol.F_POS))
	if start == Vector3.INF:
		start = HabitatLayout.START_POS
	_player.place(start)
	_seconds_left = float(msg.get(Protocol.F_SECONDS, 0))
	_set_count(int(msg.get(Protocol.F_COUNT, 0)))
	_update_time_label()
	_flash_label.modulate.a = 0.0
	_hunting = true
	_pos_timer = 0.0
	_focus_canvas()
	_show_all(true)
	_player.set_active(true)


func end_hunt() -> void:
	_hunting = false
	_pending.clear()
	if _player != null:
		_player.set_active(false)
	if _bugs != null:
		_bugs.set_bugs([])
	_clear_others()
	_show_all(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Web: put the browser's keyboard focus on the game canvas, so keys reach Godot without a click first.
func _focus_canvas() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');if(c){c.focus();}})()", true)


func on_bug_gone(id: int) -> void:
	if _bugs != null:
		_bugs.remove_bug(id)
	_pending.erase(id)


## The other hunters in this room: move (or add) each one named, remove any not named.
func on_lizards_seen(list: Variant) -> void:
	if not _hunting or typeof(list) != TYPE_ARRAY:
		return
	var seen: Dictionary = {}
	for e: Variant in list:
		if typeof(e) != TYPE_ARRAY or (e as Array).size() < 5:
			continue
		var a: Array = e
		var n: String = str(a[0])
		var p: Vector3 = Protocol.wire_to_vec([a[1], a[2], a[3]])
		if p == Vector3.INF or not LizardAvatar.is_num(a[4]):
			continue
		seen[n] = true
		var av: LizardAvatar = _others.get(n)
		if av == null:
			av = LizardAvatar.new()
			add_child(av)
			_others[n] = av
			av.snap_to(p, float(a[4]))
		else:
			av.set_target(p, float(a[4]))
	for n: String in _others.keys():
		if not seen.has(n):
			(_others[n] as Node).queue_free()
			_others.erase(n)


func _clear_others() -> void:
	for n: String in _others:
		(_others[n] as Node).queue_free()
	_others.clear()


func on_capture_ok(id: int, count: int) -> void:
	if _bugs != null:
		_bugs.remove_bug(id)
	_pending.erase(id)
	_set_count(count)


func on_capture_rejected(id: int, _reason: String) -> void:
	_pending.erase(id)
	_flash("Missed")


func set_hud_visible(v: bool) -> void:
	_hud_visible = v
	if _hud != null:
		_hud.visible = v and _hunting


func _process(delta: float) -> void:
	if not _hunting:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_update_time_label()
	_pos_timer += delta
	var interval: float = 1.0 / Protocol.POS_HZ
	if _pos_timer >= interval:
		_pos_timer = fmod(_pos_timer, interval)
		if _net != null:
			_net.send(Protocol.POSITION, {Protocol.F_POS: Protocol.vec_to_wire(_player.global_position), Protocol.F_YAW: snappedf(_player.yaw(), 0.01)})


func _on_capture_pressed(origin: Vector3, dir: Vector3) -> void:
	if not _hunting:
		return
	var id: int = BugField.pick(origin, dir, _bugs.bug_positions(), Protocol.CAPTURE_RANGE)
	if id < 0:
		_player.register_miss()
		return
	if _pending.has(id):
		return
	_pending[id] = true
	if _net != null:
		_net.send(Protocol.CAPTURE, {Protocol.F_BUG_ID: id})


func _ensure_built() -> void:
	if _habitat != null:
		return
	_habitat = Habitat.new()
	add_child(_habitat)
	_habitat.build()
	_bugs = BugField.new()
	add_child(_bugs)
	_player = PlayerController.new()
	add_child(_player)
	_player.capture_pressed.connect(_on_capture_pressed)
	_player.set_active(false)
	_build_hud()


func _show_all(v: bool) -> void:
	visible = v
	if _hud != null:
		_hud.visible = v and _hud_visible
	if _habitat != null:
		# Hiding the Node3D already hides the drawing; stop the lizard colliding while hidden too.
		_habitat.process_mode = Node.PROCESS_MODE_INHERIT if v else Node.PROCESS_MODE_DISABLED


func _set_count(n: int) -> void:
	_count_label.text = "Bugs caught: %d" % n


func _update_time_label() -> void:
	var s: int = int(ceilf(_seconds_left))
	# Frame rate and bug count shown for the Gate 2 bug-count ladder on Chromebooks.
	_time_label.text = "Time left: %d:%02d\n%d fps, %d bugs" % [s / 60, s % 60, int(Engine.get_frames_per_second()), _bugs.count() if _bugs != null else 0]


func _flash(text: String) -> void:
	_flash_label.text = text
	_flash_label.modulate.a = 1.0
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.4)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.4)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(12, 12)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.65)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_hud.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	_count_label = _make_label()
	box.add_child(_count_label)
	_time_label = _make_label()
	box.add_child(_time_label)
	_set_count(0)
	# Crosshair: a fixed plus with a dark outline, always identical.
	_add_cross_bar([-10, -1, 20, 2], 2, Color(0, 0, 0, 0.8))
	_add_cross_bar([-1, -10, 2, 20], 2, Color(0, 0, 0, 0.8))
	_add_cross_bar([-10, -1, 20, 2], 0, Color(1, 1, 1, 1))
	_add_cross_bar([-1, -10, 2, 20], 0, Color(1, 1, 1, 1))
	_flash_label = _make_label()
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.anchor_left = 0.5
	_flash_label.anchor_right = 0.5
	_flash_label.anchor_top = 0.5
	_flash_label.anchor_bottom = 0.5
	_flash_label.offset_left = -60
	_flash_label.offset_right = 60
	_flash_label.offset_top = 24
	_flash_label.offset_bottom = 54
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.modulate.a = 0.0
	_hud.add_child(_flash_label)
	_hint_label = _make_label()
	_hint_label.text = HINT_TEXT
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = 12
	_hint_label.offset_right = -12
	_hint_label.offset_top = -64
	_hint_label.offset_bottom = -8
	_hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_hint_label)


func _make_label() -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", HUD_FONT)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## r = [x, y, w, h] in pixels relative to the screen centre; grow adds an outline margin on each side.
func _add_cross_bar(r: Array, grow: int, colour: Color) -> void:
	var cr: ColorRect = ColorRect.new()
	cr.color = colour
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.anchor_left = 0.5
	cr.anchor_right = 0.5
	cr.anchor_top = 0.5
	cr.anchor_bottom = 0.5
	var x: float = float(r[0]) - grow
	var y: float = float(r[1]) - grow
	cr.offset_left = x
	cr.offset_top = y
	cr.offset_right = x + float(r[2]) + grow * 2.0
	cr.offset_bottom = y + float(r[3]) + grow * 2.0
	_hud.add_child(cr)
