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

## Decor: the owner's models, drawn by the client. Kinds: 0, 9, 10 plants, 1-4 mushrooms, 5 log, 6-8 rocks. Plants and
## mushrooms are walk-through cover: bugs may sit under leaves and caps, only the stem is kept clear. Logs and rocks
## are solid: bugs stay off their whole footprint. Mix by weight (owner, 2026-11-11): 75 plant : 30 fungi : 10 rock : 1 log,
## each group split evenly over its models. Every item is 1x-DECOR_MAX_SCALE its base size (owner: the base size is the smallest).
const DECOR_COUNT: int = 200
const DECOR_GROUPS: Array = [[5], [6, 7, 8], [1, 2, 3, 4], [0, 9, 10]] # placed big first: logs, rocks, fungi, plants
const DECOR_WEIGHTS: Array[int] = [1, 10, 30, 75] # same order as DECOR_GROUPS
const DECOR_MAX_SCALE: Array[float] = [3.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 3.0, 3.0] # plants up to 3x (owner)
const DECOR_SOLID: Array[bool] = [false, false, false, false, false, true, true, true, true, false, false]
const DECOR_LENGTH: Array[float] = [0.7, 0.3, 0.3, 0.3, 0.3, 1.5, 0.6, 0.6, 0.6, 0.7, 0.7] # longest side at scale 1, metres
## Measured from the models with the longest side = 1: full = farthest point from the centre (spacing),
## stem = farthest point in the bottom 10% of the height (kept clear of bugs on walk-through kinds).
const DECOR_FULL: Array[float] = [0.489, 0.459, 0.553, 0.326, 0.355, 0.507, 0.698, 0.545, 0.403, 0.500, 0.538]
const DECOR_STEM: Array[float] = [0.149, 0.242, 0.118, 0.098, 0.179, 0.507, 0.698, 0.545, 0.403, 0.0, 0.446]
const DECOR_CLEAR: float = 0.12 # gap kept between a decor footprint and a bug's centre

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


## Decor items: Array of {pos: Vector3 (base, on the floor), kind: int, yaw: float (radians), scale: float,
## radius: float (full footprint), keep: float (radius kept clear of bug centres, before DECOR_CLEAR)}.
## On open floor only: clear of boxes, the start area and each other.
static func decor() -> Array:
	var kinds: Array[int] = []
	var total_w: int = 0
	for w: int in DECOR_WEIGHTS:
		total_w += w
	var counts: Array[int] = []
	var left: int = DECOR_COUNT
	for g: int in DECOR_GROUPS.size():
		var c: int = DECOR_COUNT * DECOR_WEIGHTS[g] / total_w if g < DECOR_GROUPS.size() - 1 else left
		counts.append(c)
		left -= c
	for g: int in DECOR_GROUPS.size():
		var models: Array = DECOR_GROUPS[g]
		for i: int in counts[g]:
			kinds.append(int(models[i % models.size()]))
	var out: Array = []
	var bx: Array = boxes()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 3
	for kind: int in kinds:
		# Size is picked before the spot, so crowding does not bias the sizes toward small.
		var sc: float = rng.randf_range(1.0, DECOR_MAX_SCALE[kind])
		var r: float = DECOR_FULL[kind] * DECOR_LENGTH[kind] * sc
		for attempt: int in 400:
			var x: float = rng.randf_range(-HALF + 0.3 + r, HALF - 0.3 - r)
			var z: float = rng.randf_range(-HALF + 0.3 + r, HALF - 0.3 - r)
			var yaw: float = rng.randf_range(0.0, TAU)
			if Vector2(x - START_POS.x, z - START_POS.z).length() < START_RADIUS + 1.0 + r:
				continue
			var clash: bool = false
			for b: Dictionary in bx:
				var bp: Vector3 = b["pos"]
				var bs: Vector3 = b["size"]
				if absf(bp.x - x) < bs.x / 2.0 + r + 0.1 and absf(bp.z - z) < bs.z / 2.0 + r + 0.1:
					clash = true
					break
			if not clash:
				for d: Dictionary in out:
					var dp: Vector3 = d["pos"]
					# Leaves and caps may overlap (50% of their spread); solids keep their full spread.
					var ra: float = r if DECOR_SOLID[kind] else r * 0.5
					var rb: float = float(d["radius"]) if DECOR_SOLID[int(d["kind"])] else float(d["radius"]) * 0.5
					if Vector2(dp.x - x, dp.z - z).length() < ra + rb + 0.1:
						clash = true
						break
			if clash:
				continue
			var keep: float = DECOR_STEM[kind] * DECOR_LENGTH[kind] * sc
			out.append({"pos": Vector3(x, 0.0, z), "kind": kind, "yaw": yaw, "scale": sc, "radius": r, "keep": keep})
			break
	return out


## Every place a bug may be put: floor points clear of boxes, decor and the start area, plus slab tops.
## The bug's centre is BUG_RADIUS above the surface.
static func spawn_points() -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	var bx: Array = boxes()
	var dc: Array = decor()
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
			if not blocked and y == 0.0:
				for d: Dictionary in dc:
					var dp: Vector3 = d["pos"]
					if Vector2(dp.x - x, dp.z - z).length() < float(d["keep"]) + DECOR_CLEAR:
						blocked = true
						break
			if not blocked:
				pts.append(Vector3(x, y + BUG_RADIUS, z))
	return pts
