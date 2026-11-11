class_name BugField
extends Node3D
## All bugs of a hunt, drawn with one MultiMeshInstance3D per (colour, shape). Bugs are static: no physics bodies.
## Shapes: the models in MODEL_PATHS (merged into one mesh each and recoloured in code), else the code-built beetle.
## Every bug is ONE flat colour, the same as a floor colour: the camouflage is the lesson (GDD §6).
## Removing a bug scales its instance to nothing. Capture picking is plain arithmetic (see pick()).

const HIDDEN_SCALE: float = 0.00001
const PICK_RADIUS_FACTOR: float = 1.5 # centre-ray tolerance = this * BUG_RADIUS ...
const PICK_ANGLE_TOLERANCE: float = 0.02 # ... plus this many metres per metre of distance

var _multimeshes: Array[MultiMesh] = []
var _instances: Array[MultiMeshInstance3D] = []
var _bugs: Dictionary = {} # id -> {mm: int (index into _multimeshes), index: int}
const MODEL_PATHS: Array[String] = ["res://assets/models/beetle.glb", "res://assets/models/spider.glb"]
const MODEL_LENGTH: float = 0.16 # longest side of a model bug, metres (about 2 * BUG_RADIUS)
static var _shapes: Array[Mesh] = [] # uncoloured, normalised meshes, one per shape; built once
var _positions: Dictionary = {} # id -> Vector3, live bugs only


## The bug nearest the origin whose centre lies close to the ray (origin, dir) and within max_range, else -1.
## bugs: id (int) -> Vector3 centre. Static so a headless bot can reuse it.
static func pick(origin: Vector3, dir: Vector3, bugs: Dictionary, max_range: float) -> int:
	if dir.length_squared() < 0.000001:
		return -1
	var d: Vector3 = dir.normalized()
	var best_id: int = -1
	var best_dist: float = INF
	for key: Variant in bugs:
		var centre: Vector3 = bugs[key]
		var v: Vector3 = centre - origin
		var dist: float = v.length()
		if dist > max_range:
			continue
		var along: float = v.dot(d)
		if along <= 0.0:
			continue
		var off: float = (v - d * along).length()
		var tolerance: float = PICK_RADIUS_FACTOR * HabitatLayout.BUG_RADIUS + PICK_ANGLE_TOLERANCE * along
		if off <= tolerance and dist < best_dist:
			best_dist = dist
			best_id = int(key)
	return best_id


func set_bugs(wire_bugs: Array) -> void:
	_clear_nodes()
	_bugs.clear()
	_positions.clear()
	var shapes: Array[Mesh] = _bug_shapes()
	var n_shapes: int = shapes.size()
	var groups: Array = [] # index colour * n_shapes + shape -> Array of wire bugs
	for k: int in HabitatLayout.COLOURS.size() * n_shapes:
		groups.append([])
	for wb: Variant in wire_bugs:
		if typeof(wb) != TYPE_ARRAY or (wb as Array).size() < 5:
			continue
		var a: Array = wb
		var colour: int = clampi(int(a[4]), 0, HabitatLayout.COLOURS.size() - 1)
		(groups[colour * n_shapes + _shape_of(int(a[0]), n_shapes)] as Array).append(a)
	for k: int in groups.size():
		var list: Array = groups[k]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = coloured(shapes[k % n_shapes], HabitatLayout.COLOURS[k / n_shapes])
		mm.instance_count = list.size()
		for i: int in list.size():
			var a: Array = list[i]
			var id: int = int(a[0])
			var pos: Vector3 = Vector3(float(a[1]), float(a[2]), float(a[3]))
			mm.set_instance_transform(i, Transform3D(_facing(id), pos))
			_bugs[id] = {"mm": _multimeshes.size(), "index": i}
			_positions[id] = pos
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		_multimeshes.append(mm)
		_instances.append(mmi)


func remove_bug(id: int) -> void:
	if not _bugs.has(id):
		return
	var info: Dictionary = _bugs[id]
	var mm: MultiMesh = _multimeshes[int(info["mm"])]
	var pos: Vector3 = _positions[id]
	mm.set_instance_transform(int(info["index"]), Transform3D(Basis.from_scale(Vector3.ONE * HIDDEN_SCALE), pos))
	_bugs.erase(id)
	_positions.erase(id)


## id -> Vector3 for every bug still present. Do not modify the returned dictionary.
func bug_positions() -> Dictionary:
	return _positions


func count() -> int:
	return _positions.size()


func _clear_nodes() -> void:
	for mmi: MultiMeshInstance3D in _instances:
		mmi.queue_free()
		remove_child(mmi)
	_instances.clear()
	_multimeshes.clear()


## A beetle about 2 * BUG_RADIUS long, built from primitives into one mesh: body, head, six legs, two antennae.
## The whole bug is ONE flat colour, the same as its floor colour: the camouflage is the lesson (GDD §6).
## The mesh origin is the bug's wire position (BUG_RADIUS above the surface); the feet touch the surface.
static func _make_mesh() -> Mesh:
	var r: float = HabitatLayout.BUG_RADIUS
	var ground: float = -r
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: SphereMesh = SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 10
	body.rings = 5
	var body_y: float = ground + 0.045
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.042, 0.032, 0.055)), Vector3(0, body_y, -0.008)))
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.022
	head.height = 0.036
	head.radial_segments = 8
	head.rings = 4
	st.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0, body_y - 0.004, 0.058)))
	var leg: BoxMesh = BoxMesh.new()
	leg.size = Vector3(0.055, 0.007, 0.007)
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var z: float = 0.025 - 0.028 * i
			var splay: float = deg_to_rad(-30.0 + 30.0 * i) * side
			var b: Basis = Basis(Vector3.UP, splay) * Basis(Vector3.BACK, deg_to_rad(-38.0) * side)
			var foot: Vector3 = Vector3(side * 0.062, ground + 0.004, z + sin(splay) * 0.02)
			var hip: Vector3 = Vector3(side * 0.025, body_y - 0.01, z)
			st.append_from(leg, 0, Transform3D(b, (foot + hip) / 2.0))
	var ant: BoxMesh = BoxMesh.new()
	ant.size = Vector3(0.005, 0.005, 0.05)
	for side: float in [-1.0, 1.0]:
		var b2: Basis = Basis(Vector3.UP, deg_to_rad(22.0) * side) * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
		st.append_from(ant, 0, Transform3D(b2, Vector3(side * 0.012, body_y + 0.006, 0.09)))
	return st.commit()


## Which shape a bug gets: random-looking but fixed by its id, so every client shows the same bug.
static func _shape_of(id: int, n_shapes: int) -> int:
	return int(hash(id * 7919 + 13)) % n_shapes if n_shapes > 1 else 0


## The shapes, built once: each model merged into one mesh (its node transforms baked in), scaled so its
## longest side is MODEL_LENGTH, centred, feet on the surface (origin = wire position, BUG_RADIUS up).
## A model that fails to load is skipped; with none left, the code beetle is used.
static func _bug_shapes() -> Array[Mesh]:
	if not _shapes.is_empty():
		return _shapes
	for path: String in MODEL_PATHS:
		var m: Mesh = merge_model(path, MODEL_LENGTH, -HabitatLayout.BUG_RADIUS)
		if m != null:
			_shapes.append(m)
	if _shapes.is_empty():
		_shapes.append(_make_mesh())
	return _shapes


## A model file merged into one mesh (node transforms baked in), scaled so its longest side is `length`,
## centred in x/z, lowest point at y = `base`. Null if it is missing or empty. Also used for the habitat decor.
static func merge_model(path: String, length: float, base: float) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("model missing: %s" % path)
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var root: Node = ps.instantiate()
	var parts: Array = [] # [Mesh, Transform3D relative to root]
	_collect_meshes(root, Transform3D.IDENTITY, parts)
	root.free()
	if parts.is_empty():
		return null
	var box: AABB = AABB()
	var first: bool = true
	for part: Array in parts:
		var b: AABB = (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0:
		return null
	var k: float = length / longest
	var centre: Vector3 = box.get_center()
	# Scale about the model's centre, then lift so its lowest point sits at `base`.
	var fit: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3(-centre.x * k, -box.position.y * k + base, -centre.z * k))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var mesh: Mesh = part[0]
		for si: int in mesh.get_surface_count():
			st.append_from(mesh, si, fit * (part[1] as Transform3D))
	return st.commit()


static func _collect_meshes(node: Node, xf: Transform3D, out: Array) -> void:
	var here: Transform3D = xf
	if node is Node3D:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append([(node as MeshInstance3D).mesh, here])
	for c: Node in node.get_children():
		_collect_meshes(c, here, out)


## The shape with one flat colour. Culling is off: mirrored legs (negative scale) and thin leaves show both faces.
static func coloured(shape: Mesh, colour: Color) -> Mesh:
	var mesh: Mesh = shape.duplicate() as Mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for si: int in mesh.get_surface_count():
		mesh.surface_set_material(si, mat)
	return mesh


## Each bug faces its own way (from its id, so every client agrees); the shape is not round any more.
static func _facing(id: int) -> Basis:
	return Basis(Vector3.UP, fmod(float(id) * 2.39996, TAU))
