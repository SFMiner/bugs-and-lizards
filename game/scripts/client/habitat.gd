class_name Habitat
extends Node3D
## The habitat built in code from HabitatLayout: floor patches, boxes, slabs and border walls, flat colours,
## one directional light with no shadows, ambient colour, and the decor (owner's plant, mushroom, log and rock
## models, one MultiMesh per kind, one flat colour each). build() is idempotent.

const FLOOR_THICKNESS: float = 1.0
const DECOR_DIR: String = "res://assets/models/plants/"
const DECOR_FILES: Array[String] = ["plant_1", "mushroom_1", "mushroom_2", "mushroom_3", "mushroom_4", "log", "rock_1", "rock_2", "rock_3"]
const DECOR_COLOURS: Array[Color] = [
	Color(0.22, 0.52, 0.20, 1), # plant: leaf green
	Color(0.86, 0.82, 0.70, 1), # cream
	Color(0.72, 0.26, 0.18, 1), # rust red
	Color(0.84, 0.52, 0.22, 1), # orange
	Color(0.58, 0.48, 0.62, 1), # pale violet
	Color(0.38, 0.27, 0.17, 1), # log: bark brown
	Color(0.50, 0.50, 0.47, 1), # rocks: grey
	Color(0.47, 0.46, 0.43, 1),
	Color(0.53, 0.51, 0.46, 1),
]

var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.78, 0.9, 1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.62, 1)
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	add_child(sun)
	_build_floor()
	for b: Dictionary in HabitatLayout.boxes():
		_add_box(b["pos"], b["size"], HabitatLayout.COLOURS[int(b["colour"])])
	_build_decor()


## Plants and mushrooms have no collision (lizards walk through); logs and rocks get a box matching the model's
## bounds. A kind whose model fails to load is left out.
func _build_decor() -> void:
	var by_kind: Array = []
	for k: int in DECOR_FILES.size():
		by_kind.append([])
	for d: Dictionary in HabitatLayout.decor():
		(by_kind[int(d["kind"])] as Array).append(d)
	for k: int in DECOR_FILES.size():
		var list: Array = by_kind[k]
		if list.is_empty():
			continue
		var shape: Mesh = BugField.merge_model(DECOR_DIR + DECOR_FILES[k] + ".glb", HabitatLayout.DECOR_LENGTH[k], 0.0)
		if shape == null:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BugField.coloured(shape, DECOR_COLOURS[k])
		mm.instance_count = list.size()
		var box: AABB = shape.get_aabb()
		for i: int in list.size():
			var d: Dictionary = list[i]
			var sc: float = float(d["scale"])
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, float(d["yaw"])).scaled(Vector3.ONE * sc), d["pos"])
			mm.set_instance_transform(i, xf)
			if HabitatLayout.DECOR_SOLID[k]:
				var body: StaticBody3D = StaticBody3D.new()
				body.transform = Transform3D(Basis(Vector3.UP, float(d["yaw"])), d["pos"])
				var cs: CollisionShape3D = CollisionShape3D.new()
				var bs: BoxShape3D = BoxShape3D.new()
				bs.size = box.size * sc
				cs.shape = bs
				cs.position = box.get_center() * sc
				body.add_child(cs)
				add_child(body)
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _build_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(HabitatLayout.SIZE, FLOOR_THICKNESS, HabitatLayout.SIZE)
	cs.shape = bs
	cs.position.y = -FLOOR_THICKNESS / 2.0
	body.add_child(cs)
	add_child(body)
	for p: Dictionary in HabitatLayout.patches():
		var r: Rect2 = p["rect"]
		var centre: Vector2 = r.get_center()
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(r.size.x, 0.02, r.size.y)
		bm.material = _material(HabitatLayout.COLOURS[int(p["colour"])])
		mi.mesh = bm
		mi.position = Vector3(centre.x, -0.01, centre.y)
		add_child(mi)


func _add_box(pos: Vector3, size: Vector3, colour: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = _material(colour)
	mi.mesh = bm
	body.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _material(colour: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	return mat
