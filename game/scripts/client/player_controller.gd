class_name PlayerController
extends CharacterBody3D
## The client's own lizard: capsule body, camera at eye height, keys-only turning plus optional pointer lock.
## Emits capture_pressed(origin, dir) for the camera's centre ray; HuntView decides what that hits.

signal capture_pressed(origin: Vector3, dir: Vector3)

const MOVE_SPEED: float = 3.5 # under Protocol.MAX_SPEED
const TURN_SPEED: float = 2.2 # rad/s for keys
const MOUSE_SENS: float = 0.003
const PITCH_LIMIT: float = 1.2
const GRAVITY: float = 9.8
const STEP_HEIGHT: float = 0.25 # lets the lizard climb the 0.2 m slabs
const BODY_RADIUS: float = 0.2
const BODY_HEIGHT: float = 0.6
## After a capture press that picks nothing, ignore capture presses for this many seconds (0 = off).
const MISS_COOLDOWN: float = 0.0

var active: bool = false
var camera: Camera3D
var _head: Node3D
var _cooldown_left: float = 0.0


func _init() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = BODY_RADIUS
	cap.height = BODY_HEIGHT
	shape.shape = cap
	shape.position.y = BODY_HEIGHT / 2.0
	add_child(shape)
	_head = Node3D.new()
	_head.position.y = HabitatLayout.EYE_HEIGHT
	add_child(_head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.03
	camera.far = 80.0
	_head.add_child(camera)


## Put the lizard at pos (feet), facing -Z, level, and let it move.
func place(pos: Vector3) -> void:
	position = pos # HuntView sits at the world origin, so local equals global
	rotation = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_cooldown_left = 0.0


func set_active(v: bool) -> void:
	active = v
	camera.current = v
	set_physics_process(v)
	if not v:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func yaw() -> float:
	return rotation.y


## Called by HuntView when a capture press picked nothing.
func register_miss() -> void:
	_cooldown_left = MISS_COOLDOWN


func eye_origin() -> Vector3:
	return camera.global_position


func eye_dir() -> Vector3:
	return -camera.global_transform.basis.z


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and (event as InputEventKey).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		rotate_y(-mm.relative.x * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x - mm.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("capture") and not event.is_echo():
		if _cooldown_left <= 0.0:
			capture_pressed.emit(eye_origin(), eye_dir())


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	var fwd: float = Input.get_axis("move_back", "move_forward")
	var side: float = Input.get_axis("strafe_left", "strafe_right")
	var turn: float = Input.get_axis("turn_right", "turn_left")
	var look: float = Input.get_axis("look_down", "look_up")
	rotate_y(turn * TURN_SPEED * delta)
	_head.rotation.x = clampf(_head.rotation.x + look * TURN_SPEED * 0.6 * delta, -PITCH_LIMIT, PITCH_LIMIT)
	var b: Basis = global_transform.basis
	var dir: Vector3 = -b.z * fwd + b.x * side
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var hv: Vector3 = dir * MOVE_SPEED
	if is_on_floor() and hv.length_squared() > 0.0:
		var motion: Vector3 = hv * delta * 2.0
		if test_move(global_transform, motion) and not test_move(global_transform.translated(Vector3(0, STEP_HEIGHT, 0)), motion):
			global_position.y += STEP_HEIGHT
	velocity = Vector3(hv.x, velocity.y - GRAVITY * delta, hv.z)
	move_and_slide()
	if is_on_floor():
		velocity.y = 0.0
