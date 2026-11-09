class_name Habitat
extends Node3D
## The habitat built in code from HabitatLayout: floor patches, boxes, slabs and border walls, flat colours,
## one directional light with no shadows, ambient colour. build() is idempotent.

const FLOOR_THICKNESS: float = 1.0

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
