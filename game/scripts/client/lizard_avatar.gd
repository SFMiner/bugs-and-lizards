class_name LizardAvatar
extends Node3D
## Another hunter's lizard, as seen by this player. Follows the server's LIZARDS_SEEN reports (about 10 a second)
## smoothly. Uses the owner's model at MODEL_PATH when it exists (its AnimationPlayer's walk and idle animations
## are played by speed); until then, a code-built placeholder lizard that waddles while it moves.
## Faces -Z at yaw 0, like the player. Origin at the feet. No collision: lizards walk through each other.

const MODEL_PATH: String = "res://assets/models/lizard.glb"
const COLOUR: Color = Color(0.30, 0.55, 0.45, 1) # placeholder only
const FOLLOW: float = 12.0 # how fast the drawn lizard catches up with the reported one (1/s)
const WALK_SPEED: float = 0.3 # m/s; slower than this counts as standing still
const STRIDE_SPEED: float = 0.45 # m/s at which the walk animation plays at normal speed (feet keep pace with the ground)

static var _placeholder_mesh: Mesh

var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _speed: float = 0.0
var _body: Node3D
var _anim: AnimationPlayer
var _walk_anim: String = ""
var _idle_anim: String = ""
var _t: float = 0.0


static func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


func _ready() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var ps: PackedScene = load(MODEL_PATH) as PackedScene
		if ps != null:
			_body = ps.instantiate() as Node3D
	if _body == null:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _placeholder()
		_body = mi
	add_child(_body)
	var found: Array[Node] = _body.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_anim = found[0] as AnimationPlayer
		for a: String in _anim.get_animation_list():
			var low: String = a.to_lower()
			if _walk_anim == "" and (low.contains("walk") or low.contains("run")):
				_walk_anim = a
			elif _idle_anim == "" and low.contains("idle"):
				_idle_anim = a
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR # glTF imports them as one-shot


func snap_to(p: Vector3, yaw: float) -> void:
	_target_pos = p
	_target_yaw = yaw
	position = p
	rotation.y = yaw


func set_target(p: Vector3, yaw: float) -> void:
	_speed = Vector2(p.x - _target_pos.x, p.z - _target_pos.z).length() * Protocol.LIZARDS_HZ
	_target_pos = p
	_target_yaw = yaw


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-FOLLOW * delta)
	position = position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	var walking: bool = _speed > WALK_SPEED
	if _anim != null:
		var want: String = _walk_anim if walking else _idle_anim
		if want != "" and _anim.current_animation != want:
			_anim.play(want)
		_anim.speed_scale = clampf(_speed / STRIDE_SPEED, 0.5, 6.0) if walking else 1.0
	elif _body != null:
		# Placeholder waddle: the body swings side to side while walking.
		_t += delta
		_body.rotation.y = sin(_t * 9.0) * 0.12 if walking else lerpf(_body.rotation.y, 0.0, k)


## A simple lizard, about 1.6 m nose to tail, eyes near HabitatLayout.EYE_HEIGHT: body, head, tail, four legs.
static func _placeholder() -> Mesh:
	if _placeholder_mesh != null:
		return _placeholder_mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	st.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3(0.2, 0.15, 0.45)), Vector3(0, 0.3, 0)))
	st.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3(0.13, 0.1, 0.2)), Vector3(0, 0.42, -0.55)))
	var tail: CylinderMesh = CylinderMesh.new()
	tail.top_radius = 0.01 # +Y end becomes the tip, down and back
	tail.bottom_radius = 0.1
	tail.height = 0.8
	tail.radial_segments = 8
	st.append_from(tail, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(96.0)), Vector3(0, 0.24, 0.82)))
	var leg: BoxMesh = BoxMesh.new()
	leg.size = Vector3(0.07, 0.28, 0.07)
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.25, 0.25]:
			st.append_from(leg, 0, Transform3D(Basis(Vector3.BACK, deg_to_rad(30.0) * side), Vector3(side * 0.24, 0.13, z)))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLOUR
	mat.roughness = 1.0
	st.set_material(mat)
	_placeholder_mesh = st.commit()
	return _placeholder_mesh
