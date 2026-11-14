class_name GameRoom
extends RefCounted
## One ecosystem's state machine: bugs, lizards, captures, the hunt clock and round bookkeeping.
## No networking and no real clock: every time-dependent method takes now_s (seconds), so tests drive it directly.

# === STATE ===
static var _spawn_cache: PackedVector3Array = PackedVector3Array()

var index: int = 0
var stage: int = 1
var lizards_start: int = 2
var hunt_seconds: float = 45.0
var bug_budget: int = 600
var members: Array[String] = []
var phase: String = Protocol.PH_SETUP
var round_number: int = 1
var paused: bool = false
var bugs: Dictionary = {} # int id -> {pos: Vector3, colour: int, sp: int}
var used_spawn: Dictionary = {} # spawn point index -> true while a bug sits there
var next_bug_id: int = 1 # never reused within the room
var lizards: Array = [] # RoundRules lizard dicts
var captures: Dictionary = {} # lizard_id -> accepted captures this hunt
var history: Array = []
var round_bugs_start: int = 0
var hunt_start_s: float = 0.0
var hunt_end_s: float = 0.0
var mutant_arisen: bool = false
var next_bugs_start: int = 0
var end_reason: String = ""
var last_summary: Dictionary = {}
var hunt_pos: Dictionary = {} # student name -> last accepted Vector3
var hunt_pos_t: Dictionary = {} # student name -> time of that report
var hunt_yaw: Dictionary = {} # student name -> last reported yaw (radians); only drawn by other clients, never checked
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_index: int = 0) -> void:
	index = p_index
	rng.randomize()


## Computed once per process (about 200 ms).
static func spawn_points() -> PackedVector3Array:
	if _spawn_cache.is_empty():
		_spawn_cache = HabitatLayout.spawn_points()
	return _spawn_cache


# === SETUP ===
## Back to round 1 PH_SETUP with this config, fresh bugs, empty history, no lizards. Keeps members and paused.
func setup(cfg: Dictionary, debug_bugs: int = -1) -> void:
	stage = clampi(int(cfg.get("stage", 1)), 1, 4)
	lizards_start = int(cfg.get("lizards_start", 2))
	hunt_seconds = float(clampi(int(cfg.get("hunt_seconds", StageConfig.HUNT_SECONDS_DEFAULT)), StageConfig.HUNT_SECONDS_MIN, StageConfig.HUNT_SECONDS_MAX))
	bug_budget = int(cfg.get("bug_budget", StageConfig.BUG_BUDGET_DEFAULT))
	var want: int = int(cfg.get("bugs_start", 50))
	if debug_bugs >= 0:
		want = debug_bugs
	want = clampi(want, 0, spawn_points().size())
	phase = Protocol.PH_SETUP
	round_number = 1
	bugs.clear()
	used_spawn.clear()
	lizards = []
	captures = {}
	history = []
	mutant_arisen = false
	end_reason = ""
	last_summary = {}
	next_bugs_start = 0
	hunt_pos.clear()
	hunt_pos_t.clear()
	place_bugs(want)
	round_bugs_start = bugs.size()


## True in PH_SETUP of round 1: the only time CONFIGURE takes effect and SET_LIZARDS is allowed.
func is_fresh() -> bool:
	return phase == Protocol.PH_SETUP and round_number == 1


## Adds n bugs at distinct random FREE spawn points. Returns false (and adds nothing) if not enough are free.
func place_bugs(n: int) -> bool:
	if n <= 0:
		return true
	var sp: PackedVector3Array = spawn_points()
	var free: Array[int] = []
	for i: int in range(sp.size()):
		if not used_spawn.has(i):
			free.append(i)
	if n > free.size():
		return false
	for k: int in range(n):
		var j: int = rng.randi_range(k, free.size() - 1)
		var tmp: int = free[k]
		free[k] = free[j]
		free[j] = tmp
		var idx: int = free[k]
		bugs[next_bug_id] = {"pos": sp[idx], "colour": rng.randi_range(0, HabitatLayout.COLOURS.size() - 1), "sp": idx}
		used_spawn[idx] = true
		next_bug_id += 1
	return true


## Round 1 only. Names not in the room are ignored; duplicates dropped.
func set_lizards(names: Array) -> bool:
	if not is_fresh():
		return false
	var clean: Array[String] = []
	for n: Variant in names:
		var s: String = str(n)
		if members.has(s) and not clean.has(s):
			clean.append(s)
	lizards = RoundRules.starting_lizards(clean)
	return true


# === QUERIES ===
func hunter_names() -> Array[String]:
	var out: Array[String] = []
	for liz: Dictionary in lizards:
		var s: String = liz["student"]
		if not out.has(s):
			out.append(s)
	return out


func lizard_id_of(student: String) -> String:
	for liz: Dictionary in lizards:
		if liz["student"] == student:
			return liz["id"]
	return ""


func caught_total() -> int:
	var n: int = 0
	for v: Variant in captures.values():
		n += int(v)
	return n


func seconds_left(now_s: float) -> float:
	if phase != Protocol.PH_HUNT:
		return 0.0
	return maxf(hunt_end_s - now_s, 0.0)


func count_of(student: String) -> int:
	var lid: String = lizard_id_of(student)
	return int(captures.get(lid, 0)) if lid != "" else 0


func wire_bugs() -> Array:
	var out: Array = []
	for id: int in bugs:
		var b: Dictionary = bugs[id]
		var p: Vector3 = b["pos"]
		var w: Array = Protocol.vec_to_wire(p)
		out.append([id, w[0], w[1], w[2], int(b["colour"])])
	return out


## Public counts only; never bug positions.
func state(now_s: float) -> Dictionary:
	return {
		"room": index, "phase": phase, "round": round_number, "stage": stage, "paused": paused,
		"bugs_start": round_bugs_start, "caught": caught_total(), "remaining": bugs.size(),
		"seconds_left": snappedf(seconds_left(now_s), 0.1), "hunters": hunter_names(),
		"members": members.duplicate(), "history": history.duplicate(true), "end_reason": end_reason,
	}


# === HUNT ===
## PH_SETUP and not paused -> PH_HUNT. prefer = connected student names (used only for the random lizard pick).
func start_hunt(now_s: float, prefer: Array = []) -> bool:
	if phase != Protocol.PH_SETUP or paused:
		return false
	if round_number == 1 and lizards.is_empty():
		var first: Array[String] = []
		var rest: Array[String] = []
		for m: String in members:
			if prefer.has(m):
				first.append(m)
			else:
				rest.append(m)
		_shuffle(first)
		_shuffle(rest)
		first.append_array(rest)
		var pick: Array = first.slice(0, mini(maxi(lizards_start, 0), first.size()))
		lizards = RoundRules.starting_lizards(pick)
	captures = {}
	for liz: Dictionary in lizards:
		captures[liz["id"]] = 0
	round_bugs_start = bugs.size()
	phase = Protocol.PH_HUNT
	hunt_start_s = now_s
	hunt_end_s = now_s + hunt_seconds
	hunt_pos.clear()
	hunt_pos_t.clear()
	for s: String in hunter_names():
		reset_hunter_pos(s, now_s)
	return true


func _shuffle(a: Array[String]) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: String = a[i]
		a[i] = a[j]
		a[j] = t


## A hunter (re)starts at the start area, as told in HUNT_START.
func reset_hunter_pos(student: String, now_s: float) -> void:
	hunt_pos[student] = HabitatLayout.START_POS
	hunt_pos_t[student] = now_s
	hunt_yaw[student] = 0.0


## Accepts the report if it is reachable at MAX_SPEED with 50% slack plus 0.5 m; else keeps the old position.
func submit_position(student: String, p: Vector3, now_s: float, yaw: float = 0.0) -> bool:
	if phase != Protocol.PH_HUNT or not hunt_pos.has(student):
		return false
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
		return false
	var last: Vector3 = hunt_pos[student]
	var elapsed: float = maxf(now_s - float(hunt_pos_t[student]), 0.0)
	if last.distance_to(p) > Protocol.MAX_SPEED * 1.5 * elapsed + 0.5:
		return false
	hunt_pos[student] = p
	hunt_pos_t[student] = now_s
	hunt_yaw[student] = wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0
	return true


## LIZARDS_SEEN payload for one hunter: every other hunter's last accepted position, [name, x, y, z, yaw].
func lizards_wire(except: String) -> Array:
	var out: Array = []
	for s: String in hunter_names():
		if s == except or not hunt_pos.has(s):
			continue
		var p: Array = Protocol.vec_to_wire(hunt_pos[s])
		out.append([s, p[0], p[1], p[2], snappedf(float(hunt_yaw.get(s, 0.0)), 0.01)])
	return out


## Returns {ok: bool, reason: String, count: int}. First valid capture of a bug wins.
func capture(student: String, bug_id: int, now_s: float) -> Dictionary:
	if phase != Protocol.PH_HUNT or now_s > hunt_end_s:
		return {"ok": false, "reason": Protocol.R_NOT_HUNTING, "count": 0}
	var lid: String = lizard_id_of(student)
	if lid == "":
		return {"ok": false, "reason": Protocol.R_NOT_HUNTING, "count": 0}
	if not bugs.has(bug_id):
		return {"ok": false, "reason": Protocol.R_GONE, "count": 0}
	var b: Dictionary = bugs[bug_id]
	var bpos: Vector3 = b["pos"]
	var ppos: Vector3 = hunt_pos.get(student, HabitatLayout.START_POS)
	if ppos.distance_to(bpos) > Protocol.CAPTURE_RANGE + 0.3:
		return {"ok": false, "reason": Protocol.R_RANGE, "count": 0}
	bugs.erase(bug_id)
	used_spawn.erase(int(b["sp"]))
	captures[lid] = int(captures.get(lid, 0)) + 1
	return {"ok": true, "reason": "", "count": int(captures[lid])}


## Ends the hunt (timer expiry or stop). Returns {} if no hunt runs, else
## {summary, rows: [{name, captures}], round, stage, bugs_start, actual, hunters}.
func end_hunt(now_s: float, stopped: bool) -> Dictionary:
	if phase != Protocol.PH_HUNT:
		return {}
	var actual: float = hunt_seconds
	if stopped:
		actual = clampf(now_s - hunt_start_s, 0.0, hunt_seconds)
	actual = snappedf(actual, 0.1)
	var result: Dictionary = RoundRules.resolve_hunt(stage, round_number, round_bugs_start, lizards, captures)
	var tagin: Dictionary = RoundRules.new_tagin(result)
	var fin: Dictionary = RoundRules.finish_round(result, tagin, {
		"bug_budget": bug_budget, "mutant_arisen": mutant_arisen, "seed": rng.randi()})
	var accepted: Dictionary = result["captures"]
	var rows: Array = []
	var by_name: Dictionary = {}
	for liz: Dictionary in lizards:
		var c: int = int(accepted.get(liz["id"], 0))
		rows.append({"name": liz["student"], "captures": c})
		by_name[liz["student"]] = int(by_name.get(liz["student"], 0)) + c
	var survived: Array = []
	for liz: Dictionary in result["survivors"]:
		survived.append(liz["student"])
	var starved: Array = []
	for liz: Dictionary in result["starved"]:
		starved.append(liz["student"])
	var rec: Dictionary = (fin["record"] as Dictionary).duplicate()
	rec["hunt_seconds"] = actual
	history.append(rec)
	var summary: Dictionary = rec.duplicate()
	summary["starved"] = starved
	summary["survived"] = survived
	summary["captures"] = by_name
	summary["ended"] = bool(fin["ended"])
	summary["end_reason"] = str(fin["end_reason"])
	summary["history"] = history.duplicate(true)
	var out: Dictionary = {"summary": summary, "rows": rows, "round": round_number, "stage": stage,
		"bugs_start": round_bugs_start, "actual": actual, "hunters": hunter_names().size()}
	lizards = fin["next_lizards"]
	mutant_arisen = bool(fin["mutant_arisen"])
	next_bugs_start = int(fin["next_bugs_start"])
	end_reason = str(fin["end_reason"])
	last_summary = summary
	phase = Protocol.PH_ENDED if bool(fin["ended"]) else Protocol.PH_STUDY
	return out


## PH_STUDY -> PH_SETUP of the next round. Uncaught bugs stay; new ones go to free spawn points.
func advance() -> bool:
	if phase != Protocol.PH_STUDY:
		return false
	round_number += 1
	captures = {}
	hunt_pos.clear()
	hunt_pos_t.clear()
	var need: int = next_bugs_start - bugs.size()
	if not place_bugs(need):
		phase = Protocol.PH_ENDED
		end_reason = RoundRules.END_OVERRUN
		return true
	phase = Protocol.PH_SETUP
	round_bugs_start = bugs.size()
	return true
