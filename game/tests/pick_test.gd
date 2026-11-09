extends SceneTree
## Headless test for BugField.pick. Run: godot --headless --path game --script res://tests/pick_test.gd

const EXPECTED: int = 8

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	var o: Vector3 = Vector3(0, 0.5, 0)
	var fwd: Vector3 = Vector3(0, 0, -1)
	_check("straight ahead in range", BugField.pick(o, fwd, {7: Vector3(0, 0.5, -1.5)}, 2.5), 7)
	_check("out of range", BugField.pick(o, fwd, {7: Vector3(0, 0.5, -3.0)}, 2.5), -1)
	_check("off axis beyond tolerance", BugField.pick(o, fwd, {7: Vector3(0.4, 0.5, -1.0)}, 2.5), -1)
	_check("slightly off axis within tolerance", BugField.pick(o, fwd, {7: Vector3(0.05, 0.5, -1.0)}, 2.5), 7)
	_check("two on the ray picks nearer", BugField.pick(o, fwd, {1: Vector3(0, 0.5, -2.0), 2: Vector3(0, 0.5, -1.0)}, 2.5), 2)
	_check("behind the camera", BugField.pick(o, fwd, {7: Vector3(0, 0.5, 1.0)}, 2.5), -1)
	_check("empty field", BugField.pick(o, fwd, {}, 2.5), -1)
	_check("unnormalised dir works", BugField.pick(o, Vector3(0, 0, -5), {7: Vector3(0, 0.5, -1.0)}, 2.5), 7)
	print("pick_test: %s %d/%d" % ["PASS" if _fail == 0 and _pass == EXPECTED else "FAIL", _pass, EXPECTED])
	quit(0 if _fail == 0 and _pass == EXPECTED else 1)


func _check(label: String, got: int, want: int) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("pick_test: FAILED %s (got %d, want %d)" % [label, got, want])
