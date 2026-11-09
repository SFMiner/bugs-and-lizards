class_name BugField
extends Node3D
## All bugs of a hunt, drawn with one MultiMeshInstance3D per colour. Bugs are static: no physics bodies.
## Removing a bug scales its instance to nothing. Capture picking is plain arithmetic (see pick()).

const HIDDEN_SCALE: float = 0.00001
const PICK_RADIUS_FACTOR: float = 1.5 # centre-ray tolerance = this * BUG_RADIUS ...
const PICK_ANGLE_TOLERANCE: float = 0.02 # ... plus this many metres per metre of distance

var _multimeshes: Array[MultiMesh] = []
var _instances: Array[MultiMeshInstance3D] = []
var _bugs: Dictionary = {} # id -> {colour: int, index: int}
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
	var per_colour: Array = []
	for c: int in HabitatLayout.COLOURS.size():
		per_colour.append([])
	for wb: Variant in wire_bugs:
		if typeof(wb) != TYPE_ARRAY or (wb as Array).size() < 5:
			continue
		var a: Array = wb
		var colour: int = clampi(int(a[4]), 0, HabitatLayout.COLOURS.size() - 1)
		(per_colour[colour] as Array).append(a)
	for c: int in HabitatLayout.COLOURS.size():
		var list: Array = per_colour[c]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _make_mesh(HabitatLayout.COLOURS[c])
		mm.instance_count = list.size()
		for i: int in list.size():
			var a: Array = list[i]
			var id: int = int(a[0])
			var pos: Vector3 = Vector3(float(a[1]), float(a[2]), float(a[3]))
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
			_bugs[id] = {"colour": c, "index": i}
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
	var mm: MultiMesh = _multimeshes[int(info["colour"])]
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


func _make_mesh(colour: Color) -> Mesh:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = HabitatLayout.BUG_RADIUS
	sm.height = HabitatLayout.BUG_RADIUS * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	sm.material = mat
	return sm
