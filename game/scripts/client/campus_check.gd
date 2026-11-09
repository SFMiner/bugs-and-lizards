extends Node3D
## M1 campus check (GDD Gate 0): a floor and boxes, first-person movement with keys-only turning and
## pointer lock, and an on-screen readout to copy off a Chromebook: frame rate, WebSocket state and
## round-trip time, keys + trackpad together, download size and time to boot, GPU.

const MOVE_SPEED: float = 4.0
const TURN_SPEED: float = 2.2 # rad/s for keys
const MOUSE_SENS: float = 0.003
const TOGETHER_WINDOW_MS: int = 500

var _body: CharacterBody3D
var _head: Node3D
var _label: Label
var _net: NetClient
var _last_key_ms: int = -100000
var _last_mouse_ms: int = -100000
var _together_count: int = 0
var _mouse_moves: int = 0
var _boot_ms: float = -1.0
var _download_kb: float = -1.0
var _fps_min: float = 1000.0
var _log_timer: float = 0.0


func _ready() -> void:
	_build_world()
	_build_hud()
	_net = NetClient.new()
	add_child(_net)
	_net.connect_to()
	_read_page_timing()


func _build_world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.9, 1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6, 1)
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	_add_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.35, 0.55, 0.3, 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 24:
		var size: Vector3 = Vector3(rng.randf_range(0.6, 2.5), rng.randf_range(0.5, 2.0), rng.randf_range(0.6, 2.5))
		var pos: Vector3 = Vector3(rng.randf_range(-17, 17), size.y / 2.0, rng.randf_range(-17, 17))
		if pos.length() < 3.0:
			continue
		_add_box(pos, size, Color.from_hsv(rng.randf(), 0.5, 0.7))
	_body = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.0
	shape.shape = cap
	shape.position.y = 0.5
	_body.add_child(shape)
	_head = Node3D.new()
	_head.position.y = 0.6
	_body.add_child(_head)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 75
	_head.add_child(cam)
	add_child(_body)


func _add_box(pos: Vector3, size: Vector3, colour: Color) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(12, 12)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_label)


func _read_page_timing() -> void:
	if not OS.has_feature("web"):
		_boot_ms = float(Time.get_ticks_msec())
		return
	_boot_ms = float(JavaScriptBridge.eval("performance.now()", true))
	var js: String = "(function(){var t=0;var e=performance.getEntriesByType('resource');for(var i=0;i<e.length;i++){t+=(e[i].transferSize||e[i].encodedBodySize||0);}var n=performance.getEntriesByType('navigation');if(n.length){t+=(n[0].transferSize||0);}return t;})()"
	_download_kb = float(JavaScriptBridge.eval(js, true)) / 1024.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_mouse_moves += 1
		_last_mouse_ms = Time.get_ticks_msec()
		_check_together()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_body.rotate_y(-mm.relative.x * MOUSE_SENS)
			_head.rotation.x = clampf(_head.rotation.x - mm.relative.y * MOUSE_SENS, -1.3, 1.3)


func _check_together() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_key_ms <= TOGETHER_WINDOW_MS and now - _last_mouse_ms <= TOGETHER_WINDOW_MS:
		_together_count += 1


func _physics_process(delta: float) -> void:
	var fwd: float = Input.get_axis("move_back", "move_forward")
	var side: float = Input.get_axis("strafe_left", "strafe_right")
	var turn: float = Input.get_axis("turn_right", "turn_left")
	var look: float = Input.get_axis("look_down", "look_up")
	if fwd != 0.0 or side != 0.0 or turn != 0.0 or look != 0.0:
		_last_key_ms = Time.get_ticks_msec()
	_body.rotate_y(turn * TURN_SPEED * delta)
	_head.rotation.x = clampf(_head.rotation.x + look * TURN_SPEED * 0.6 * delta, -1.3, 1.3)
	var basis: Basis = _body.global_transform.basis
	var dir: Vector3 = (-basis.z * fwd + basis.x * side)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	_body.velocity = Vector3(dir.x * MOVE_SPEED, _body.velocity.y - 9.8 * delta, dir.z * MOVE_SPEED)
	_body.move_and_slide()
	if _body.is_on_floor():
		_body.velocity.y = 0.0


func _process(delta: float) -> void:
	var fps: float = Engine.get_frames_per_second()
	if Time.get_ticks_msec() > 5000 and fps > 0.0:
		_fps_min = minf(_fps_min, fps)
	var rtt: String = ("%d ms" % _net.rtt_ms) if _net.rtt_ms >= 0 else "-"
	var lock: String = "locked" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "not locked (click to lock, Esc to free)"
	var lines: PackedStringArray = [
		"Bugs & Lizards campus check",
		"Frame rate: %d fps (lowest after 5 s: %s)" % [int(fps), "-" if _fps_min > 999.0 else str(int(_fps_min))],
		"WebSocket: %s   round trip: %s" % [_net.state_text(), rtt],
		"Keys + trackpad together: %s (times seen: %d; trackpad moves: %d)" % ["YES" if _together_count > 0 else "not yet", _together_count, _mouse_moves],
		"Pointer: %s" % lock,
		"Download: %s   time to boot: %s" % ["-" if _download_kb < 0.0 else "%.1f MB" % (_download_kb / 1024.0), "%.1f s" % (_boot_ms / 1000.0)],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"Move: W A S D or arrows.  Turn: Left/Right or Q/E.  Look: R/F.",
	]
	_label.text = "\n".join(lines)
	_log_timer += delta
	if _log_timer >= 3.0:
		_log_timer = 0.0
		print("campus: ws=%s rtt=%d fps=%d" % [_net.state_text(), _net.rtt_ms, int(fps)])
