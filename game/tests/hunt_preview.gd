extends SceneTree
## Desktop preview of the hunt view with no server. Run windowed:
##   BL_SHOT=<png> (save a screenshot after ~60 frames and quit), BL_PREVIEW_BUGS=<n> (default 200).
## Prints the average fps over 120 frames.

var _view: HuntView
var _frame: int = 0
var _t0: int = 0
var _shot: String = ""


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var n: int = 200
	if OS.get_environment("BL_PREVIEW_BUGS") != "":
		n = int(OS.get_environment("BL_PREVIEW_BUGS"))
	_shot = OS.get_environment("BL_SHOT")
	var net: NetClient = NetClient.new()
	_view = HuntView.new()
	root.add_child(_view)
	_view.setup(net)
	var pts: PackedVector3Array = HabitatLayout.spawn_points()
	var bugs: Array = []
	for i: int in mini(n, pts.size()):
		var p: Vector3 = pts[i]
		bugs.append([i, p.x, p.y, p.z, i % 4])
	print("hunt_preview: %d bugs (of %d spawn points)" % [bugs.size(), pts.size()])
	_view.begin_hunt({
		Protocol.F_ROOM: 0,
		Protocol.F_ROUND: 1,
		Protocol.F_SECONDS: 90,
		Protocol.F_BUGS: bugs,
		Protocol.F_POS: Protocol.vec_to_wire(HabitatLayout.START_POS),
		Protocol.F_COUNT: 0,
	})
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 60 and _shot != "":
		var img: Image = root.get_texture().get_image()
		img.save_png(_shot)
		print("hunt_preview: saved %s" % _shot)
	if _frame == 120:
		_t0 = Time.get_ticks_msec()
	if _frame == 240:
		var ms: float = float(Time.get_ticks_msec() - _t0)
		print("hunt_preview: average fps over 120 frames: %.1f" % (120.0 / (ms / 1000.0)))
		quit(0)
