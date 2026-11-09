extends SceneTree
## Headless checks for PopulationGraph (scripts/client/graph.gd): series per stage, point geometry,
## empty history, out-of-range index, values above 999. Run:
##   godot --headless --path <game> --script res://tests/graph_test.gd
## Prints "graph_test: PASS n/N" and exits 0 only when every check passed and the count matches TOTAL.

const TOTAL: int = 21

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var g2: PopulationGraph = PopulationGraph.new()
	g2.size = Vector2(600, 360)
	g2.set_history(_stage2_history(), 2, 75, 3)

	# Series per stage.
	_check(g2.series_names().size() == 2, "stage 2 has 2 series")
	_check(g2.series_names()[0] == "BUGS" and g2.series_names()[1] == "LIZARDS", "stage 2 series are BUGS, LIZARDS")
	var g4: PopulationGraph = PopulationGraph.new()
	g4.size = Vector2(600, 360)
	g4.set_history(_stage4_history(), 4, 75, 3)
	_check(g4.series_names().size() == 3, "stage 4 has 3 series")
	_check(g4.series_names()[2] == "MUTANTS", "stage 4 third series is MUTANTS")

	# Geometry, stage 2: Start is left of round 1, and rounds run left to right.
	_check(g2.point_for("BUGS", 0).x < g2.point_for("BUGS", 1).x, "Start x is left of round 1 x")
	_check(g2.point_for("BUGS", 1).x < g2.point_for("BUGS", 3).x and g2.point_for("BUGS", 3).x < g2.point_for("BUGS", 4).x, "round x increases left to right")
	# Larger value, smaller y: start 75 above round 1 (48), 304 above 114, 620 above 304.
	_check(g2.point_for("BUGS", 0).y < g2.point_for("BUGS", 1).y, "start 75 is drawn above round 1 (48)")
	_check(g2.point_for("BUGS", 3).y < g2.point_for("BUGS", 2).y, "BUGS 304 is drawn above BUGS 114")
	_check(g2.point_for("BUGS", 4).y < g2.point_for("BUGS", 3).y, "BUGS 620 is drawn above BUGS 304")
	_check(g2.point_for("LIZARDS", 1).y < g2.point_for("LIZARDS", 3).y, "LIZARDS 3 is drawn above LIZARDS 2")

	# Every BUGS point lies inside the control.
	var inside: bool = true
	for i: int in range(5):
		var p: Vector2 = g2.point_for("BUGS", i)
		if p.x < 0.0 or p.x > g2.size.x or p.y < 0.0 or p.y > g2.size.y:
			inside = false
	_check(inside, "all BUGS points lie inside the control")

	# Out-of-range index returns the sentinel.
	_check(g2.point_for("BUGS", 9) == Vector2(-1.0, -1.0), "index past the history returns (-1, -1)")

	# Empty history: no crash, Start points still drawn, no round points.
	var ge: PopulationGraph = PopulationGraph.new()
	ge.size = Vector2(600, 360)
	ge.set_history([], 1, 75, 3)
	_check(ge.point_for("BUGS", 0) != Vector2(-1.0, -1.0), "empty history still plots the Start point")
	_check(ge.point_for("LIZARDS", 0) != Vector2(-1.0, -1.0), "empty history plots the LIZARDS Start point")
	_check(ge.point_for("BUGS", 1) == Vector2(-1.0, -1.0), "empty history has no round points")

	# Stage 4: five round columns, and MUTANTS starts at zero.
	_check(g4.point_for("BUGS", 5).x > g4.point_for("BUGS", 4).x, "stage 4 has a fifth round column")
	_check(g4.point_for("MUTANTS", 0).y > g4.point_for("MUTANTS", 1).y, "MUTANTS start at 0 and rise from it")

	# Values over 999 are plotted, not capped.
	var gb: PopulationGraph = PopulationGraph.new()
	gb.size = Vector2(600, 360)
	gb.set_history([{"round": 1, "BUGS": 1500, "LIZARDS": 2}, {"round": 2, "BUGS": 620, "LIZARDS": 2}], 1, 75, 3)
	_check(gb.point_for("BUGS", 1).y >= 0.0, "1500 is inside the plot")
	_check(gb.point_for("BUGS", 1).y < gb.point_for("BUGS", 2).y, "1500 is drawn above 620 (not capped)")

	# Repeated set_history replaces the data.
	g2.set_history([{"round": 1, "BUGS": 300, "LIZARDS": 2}], 2, 75, 3)
	_check(g2.point_for("BUGS", 2) == Vector2(-1.0, -1.0), "a second set_history replaces the old rounds")
	_check(g2.point_for("BUGS", 1).y < g2.point_for("BUGS", 0).y, "a second set_history redraws the new values")

	g2.free()
	g4.free()
	ge.free()
	gb.free()

	print("graph_test: PASS %d/%d" % [_passed, TOTAL])
	if _failed == 0 and _passed == TOTAL:
		quit(0)
	else:
		print("graph_test: FAILED %d (%d of %d passed)" % [_failed, _passed, TOTAL])
		quit(1)


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("graph_test: FAIL " + what)


func _stage2_history() -> Array:
	return [
		{"round": 1, "BUGS": 48, "LIZARDS": 3, "MUTANTS": 0},
		{"round": 2, "BUGS": 114, "LIZARDS": 3, "MUTANTS": 0},
		{"round": 3, "BUGS": 304, "LIZARDS": 2, "MUTANTS": 0},
		{"round": 4, "BUGS": 620, "LIZARDS": 2, "MUTANTS": 0},
	]


func _stage4_history() -> Array:
	return [
		{"round": 1, "BUGS": 40, "LIZARDS": 3, "MUTANTS": 1},
		{"round": 2, "BUGS": 60, "LIZARDS": 3, "MUTANTS": 2},
		{"round": 3, "BUGS": 90, "LIZARDS": 2, "MUTANTS": 2},
		{"round": 4, "BUGS": 130, "LIZARDS": 2, "MUTANTS": 3},
		{"round": 5, "BUGS": 200, "LIZARDS": 1, "MUTANTS": 3},
	]
