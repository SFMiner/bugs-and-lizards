class_name HabitatLayout
extends RefCounted
## The habitat as pure data, shared by client (draws it) and server (places bugs). Deterministic: same
## output every call, on every machine. Bugs sit only on open floor or on low slab tops, so every spawn
## point is visible and reachable by construction (GDD §6). Public names are contract: do not rename.

const SIZE: float = 24.0 # square floor, metres, centred on the origin
const HALF: float = SIZE / 2.0
const EYE_HEIGHT: float = 0.5 # lizard camera height above its feet
const START_POS: Vector3 = Vector3(0.0, 0.0, HALF - 2.0) # shared start area (south edge), facing -Z
const START_RADIUS: float = 1.5
const BUG_RADIUS: float = 0.07
const SPAWN_SPACING: float = 0.55
const SEED: int = 20261109

## Surface and bug colours. Bugs draw from these four equally (fixed mix, not inherited: GDD §6).
const COLOURS: Array[Color] = [
	Color(0.32, 0.50, 0.22, 1), # moss green
	Color(0.45, 0.32, 0.18, 1), # soil brown
	Color(0.55, 0.55, 0.52, 1), # stone grey
	Color(0.78, 0.66, 0.30, 1), # dry-leaf yellow
]


## Floor patches: Array of {rect: Rect2 (x, z on the floor), colour: int (index into COLOURS)}.
static func patches() -> Array:
	var out: Array = []
	var cells: int = 4
	var cell: float = SIZE / float(cells)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for ix: int in cells:
		for iz: int in cells:
			out.append({"rect": Rect2(-HALF + ix * cell, -HALF + iz * cell, cell, cell), "colour": rng.randi_range(0, COLOURS.size() - 1)})
	return out


## Solid boxes (rocks, logs, slabs, border walls): Array of {pos: Vector3 (centre), size: Vector3, colour: int,
## slab: bool}. Slabs are 0.2 m tall; bugs may sit on their tops.
static func boxes() -> Array:
	var out: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 1
	# Border walls.
	var wall_h: float = 1.2
	out.append({"pos": Vector3(0, wall_h / 2.0, -HALF - 0.25), "size": Vector3(SIZE + 1.0, wall_h, 0.5), "colour": 2, "slab": false})
	out.append({"pos": Vector3(0, wall_h / 2.0, HALF + 0.25), "size": Vector3(SIZE + 1.0, wall_h, 0.5), "colour": 2, "slab": false})
	out.append({"pos": Vector3(-HALF - 0.25, wall_h / 2.0, 0), "size": Vector3(0.5, wall_h, SIZE), "colour": 2, "slab": false})
	out.append({"pos": Vector3(HALF + 0.25, wall_h / 2.0, 0), "size": Vector3(0.5, wall_h, SIZE), "colour": 2, "slab": false})
	var placed: int = 0
	var tries: int = 0
	while placed < 26 and tries < 500:
		tries += 1
		var slab: bool = placed % 3 == 0
		var size: Vector3
		if slab:
			size = Vector3(rng.randf_range(1.0, 2.2), 0.2, rng.randf_range(1.0, 2.2))
		else:
			size = Vector3(rng.randf_range(0.6, 2.0), rng.randf_range(0.6, 1.4), rng.randf_range(0.6, 2.0))
		var pos: Vector3 = Vector3(rng.randf_range(-HALF + 1.5, HALF - 1.5), size.y / 2.0, rng.randf_range(-HALF + 1.5, HALF - 1.5))
		if Vector2(pos.x - START_POS.x, pos.z - START_POS.z).length() < START_RADIUS + 2.0:
			continue
		var clash: bool = false
		for b: Dictionary in out:
			var bp: Vector3 = b["pos"]
			var bs: Vector3 = b["size"]
			if absf(bp.x - pos.x) < (bs.x + size.x) / 2.0 + 1.0 and absf(bp.z - pos.z) < (bs.z + size.z) / 2.0 + 1.0:
				clash = true
				break
		if clash:
			continue
		out.append({"pos": pos, "size": size, "colour": rng.randi_range(0, COLOURS.size() - 1), "slab": slab})
		placed += 1
	return out


## Every place a bug may be put: floor points clear of boxes and the start area, plus slab tops.
## The bug's centre is BUG_RADIUS above the surface.
static func spawn_points() -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	var bx: Array = boxes()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var n: int = int((SIZE - 1.0) / SPAWN_SPACING)
	for ix: int in n:
		for iz: int in n:
			var x: float = -HALF + 0.5 + ix * SPAWN_SPACING + rng.randf_range(-0.15, 0.15)
			var z: float = -HALF + 0.5 + iz * SPAWN_SPACING + rng.randf_range(-0.15, 0.15)
			if Vector2(x - START_POS.x, z - START_POS.z).length() < START_RADIUS + 1.0:
				continue
			var y: float = 0.0
			var blocked: bool = false
			for b: Dictionary in bx:
				var bp: Vector3 = b["pos"]
				var bs: Vector3 = b["size"]
				var inside: bool = absf(bp.x - x) < bs.x / 2.0 + 0.15 and absf(bp.z - z) < bs.z / 2.0 + 0.15
				if not inside:
					continue
				var on_top: bool = bool(b["slab"]) and absf(bp.x - x) < bs.x / 2.0 - 0.15 and absf(bp.z - z) < bs.z / 2.0 - 0.15
				if on_top:
					y = bs.y
				else:
					blocked = true
					break
			if not blocked:
				pts.append(Vector3(x, y + BUG_RADIUS, z))
	return pts
