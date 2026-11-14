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
var handicap: int = StageConfig.HANDICAP_DEFAULT # Stage 4 sunglasses, % contrast a wild-type hunter loses
var mutant_slot: String = "" # teacher's CHOOSE_MUTANT pick while the tag-in is open ("" = automatic)
var fallback_pending: bool = false # ADD_MUTANT used: the next round record gets mutant_fallback true
var next_bugs_start: int = 0
var end_reason: String = ""
var last_summary: Dictionary = {}
var open_hunt: Dictionary = {} # RoundRules.resolve_hunt result while a tag-in is open ({} otherwise)
var open_tagin: Dictionary = {} # RoundRules tagin state while a tag-in is open
var open_seconds: float = 0.0 # actual hunt seconds of the round whose tag-in is open
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
	handicap = clampi(int(cfg.get("handicap", StageConfig.HANDICAP_DEFAULT)), StageConfig.HANDICAP_MIN, StageConfig.HANDICAP_MAX)
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
	mutant_slot = ""
	fallback_pending = false
	end_reason = ""
	last_summary = {}
	open_hunt = {}
	open_tagin = {}
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


## Students whose current lizard is a mutant.
func mutant_names() -> Array[String]:
	return _mutants_of(lizards)


static func _mutants_of(list: Array) -> Array[String]:
	var out: Array[String] = []
	for liz: Dictionary in list:
		if bool(liz.get("mutant", false)) and not out.has(str(liz["student"])):
			out.append(str(liz["student"]))
	return out


func is_mutant(student: String) -> bool:
	return mutant_names().has(student)


## Students in next_list whose lizard is a mutant now but were not mutant lizards in prev_list.
static func _new_mutants(prev_list: Array, next_list: Array) -> Array[String]:
	var before: Array[String] = _mutants_of(prev_list)
	var out: Array[String] = []
	for s: String in _mutants_of(next_list):
		if not before.has(s):
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


## Public counts only; never bug positions. hands: {name: true} of raised hands (kept by the session).
func state(now_s: float, hands: Dictionary = {}) -> Dictionary:
	var raised: Array = []
	for m: String in members:
		if hands.has(m):
			raised.append(m)
	return {
		"room": index, "phase": phase, "round": round_number, "stage": stage, "paused": paused,
		"bugs_start": round_bugs_start, "caught": caught_total(), "remaining": bugs.size(),
		"seconds_left": snappedf(seconds_left(now_s), 0.1), "hunters": hunter_names(),
		"members": members.duplicate(), "history": history.duplicate(true), "end_reason": end_reason,
		"hands": raised, "tagin": tagin_wire(), "can_pick": can_pick(hands),
		"mutants": mutant_names(), "mutant_arisen": mutant_arisen, "mutant_slot": mutant_slot,
	}


# === TAG-IN ===
func tagin_open() -> bool:
	return not open_tagin.is_empty()


func _parent_student(parent_id: String) -> String:
	for liz: Dictionary in open_hunt.get("survivors", []):
		if liz["id"] == parent_id:
			return str(liz["student"])
	return ""


func tagin_wire() -> Array:
	var out_slots: Array = []
	if not tagin_open():
		return out_slots
	for sl: Dictionary in open_tagin["slots"]:
		out_slots.append({"slot": sl["slot_id"], "parent": _parent_student(str(sl["parent_id"])),
			"student": sl["student"], "by_teacher": bool(sl["by_teacher"])})
	return out_slots


func _in_a_slot(student: String) -> bool:
	for sl: Dictionary in open_tagin.get("slots", []):
		if sl["student"] == student:
			return true
	return false


func _is_survivor(student: String) -> bool:
	for liz: Dictionary in open_hunt.get("survivors", []):
		if liz["student"] == student:
			return true
	return false


## Names a parent or the teacher may pick now: member, hand raised, not a surviving lizard, not in a slot.
func can_pick(hands: Dictionary) -> Array:
	var out_names: Array = []
	if not tagin_open():
		return out_names
	for m: String in members:
		if hands.has(m) and not _is_survivor(m) and not _in_a_slot(m):
			out_names.append(m)
	return out_names


func _pickable(student: String, hands: Dictionary) -> bool:
	return members.has(student) and hands.has(student) and not _is_survivor(student)


## Returns "" on success, else Protocol.R_PICK_TAKEN or Protocol.R_CANNOT_PICK.
func pick(parent_student: String, student: String, hands: Dictionary) -> String:
	if not tagin_open() or not _pickable(student, hands):
		return Protocol.R_CANNOT_PICK
	var parent_id: String = ""
	for liz: Dictionary in open_hunt["survivors"]:
		if liz["student"] == parent_student:
			parent_id = str(liz["id"])
	var res: Dictionary = RoundRules.pick(open_tagin, parent_id, student)
	if bool(res["ok"]):
		return ""
	return Protocol.R_PICK_TAKEN if str(res["reason"]) == "taken" else Protocol.R_CANNOT_PICK


## Teacher override. Returns "" on success, else Protocol.R_CANNOT_PICK.
func teacher_assign(slot_id: String, student: String, hands: Dictionary) -> String:
	if not tagin_open() or not _pickable(student, hands):
		return Protocol.R_CANNOT_PICK
	var res: Dictionary = RoundRules.teacher_assign(open_tagin, slot_id, student)
	return "" if bool(res["ok"]) else Protocol.R_CANNOT_PICK


## Teacher picks the first mutant's slot ("" = automatic). Returns "" on success, else Protocol.R_CANNOT_PICK.
func choose_mutant(slot_id: String) -> String:
	if stage != 4 or not tagin_open() or mutant_arisen:
		return Protocol.R_CANNOT_PICK
	if slot_id != "":
		var ok: bool = false
		for sl: Dictionary in open_tagin["slots"]:
			if sl["slot_id"] == slot_id and sl["student"] != "":
				ok = true
		if not ok:
			return Protocol.R_CANNOT_PICK
	mutant_slot = slot_id
	return ""


## Teacher fallback, between hunts: that student's current lizard becomes a mutant. Returns "" or R_CANNOT_PICK.
func add_mutant(student: String) -> String:
	if stage != 4 or mutant_arisen or tagin_open():
		return Protocol.R_CANNOT_PICK
	if phase != Protocol.PH_STUDY and phase != Protocol.PH_SETUP:
		return Protocol.R_CANNOT_PICK
	for liz: Dictionary in lizards:
		if liz["student"] == student:
			liz["mutant"] = true
			mutant_arisen = true
			fallback_pending = true
			return ""
	return Protocol.R_CANNOT_PICK


## Closes an open tag-in: finishes the round with whoever was picked and returns the final summary
## ({} if no tag-in is open). Goes to PH_ENDED if the round ended, else stays PH_STUDY.
func close_tagin() -> Dictionary:
	if not tagin_open():
		return {}
	var fin: Dictionary = RoundRules.finish_round(open_hunt, open_tagin, {
		"bug_budget": bug_budget, "mutant_arisen": mutant_arisen, "seed": rng.randi(), "mutant_slot": mutant_slot})
	var summary: Dictionary = last_summary.duplicate(true)
	var rec: Dictionary = (fin["record"] as Dictionary).duplicate()
	rec["hunt_seconds"] = open_seconds
	if fallback_pending:
		rec["mutant_fallback"] = true
		fallback_pending = false
	summary["new_mutants"] = _new_mutants(lizards, fin["next_lizards"])
	mutant_slot = ""
	history.append(rec)
	for k: String in rec:
		summary[k] = rec[k]
	summary["ended"] = bool(fin["ended"])
	summary["end_reason"] = str(fin["end_reason"])
	summary["tagin_open"] = false
	summary["history"] = history.duplicate(true)
	open_hunt = {}
	open_tagin = {}
	lizards = fin["next_lizards"]
	mutant_arisen = bool(fin["mutant_arisen"])
	next_bugs_start = int(fin["next_bugs_start"])
	end_reason = str(fin["end_reason"])
	last_summary = summary
	phase = Protocol.PH_ENDED if bool(fin["ended"]) else Protocol.PH_STUDY
	return summary


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
	var opened: bool = not (result["slots"] as Array).is_empty()
	var fin: Dictionary = {}
	if not opened:
		fin = RoundRules.finish_round(result, tagin, {
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
	var summary: Dictionary = {}
	if opened:
		var mutants: int = 0
		for liz: Dictionary in result["survivors"]:
			if bool(liz.get("mutant", false)):
				mutants += 1
		var nxt: int = RoundRules.bugs_next_start(stage, int(result["bugs_uncaught"]))
		summary = {"round": round_number, "stage": stage, "bugs_start": round_bugs_start,
			"BUGS": int(result["bugs_uncaught"]), "bugs_next_start": nxt,
			"LIZARDS": (result["survivors"] as Array).size(), "WILD": (result["survivors"] as Array).size() - mutants,
			"MUTANTS": mutants, "mutant_arisen": mutant_arisen, "new_mutants": [],
			"slots_earned": (result["slots"] as Array).size(), "hunt_seconds": actual,
			"ended": false, "end_reason": "", "tagin_open": true}
	else:
		var rec: Dictionary = (fin["record"] as Dictionary).duplicate()
		rec["hunt_seconds"] = actual
		if fallback_pending:
			rec["mutant_fallback"] = true
			fallback_pending = false
		history.append(rec)
		summary = rec.duplicate()
		summary["new_mutants"] = _new_mutants(lizards, fin["next_lizards"])
		summary["ended"] = bool(fin["ended"])
		summary["end_reason"] = str(fin["end_reason"])
		summary["tagin_open"] = false
	summary["starved"] = starved
	summary["survived"] = survived
	summary["captures"] = by_name
	summary["history"] = history.duplicate(true)
	var out: Dictionary = {"summary": summary, "rows": rows, "round": round_number, "stage": stage,
		"bugs_start": round_bugs_start, "actual": actual, "hunters": hunter_names().size()}
	last_summary = summary
	if opened:
		open_hunt = result
		open_tagin = tagin
		open_seconds = actual
		phase = Protocol.PH_STUDY
		return out
	lizards = fin["next_lizards"]
	mutant_arisen = bool(fin["mutant_arisen"])
	next_bugs_start = int(fin["next_bugs_start"])
	end_reason = str(fin["end_reason"])
	phase = Protocol.PH_ENDED if bool(fin["ended"]) else Protocol.PH_STUDY
	return out


## PH_STUDY -> PH_SETUP of the next round. Uncaught bugs stay; new ones go to free spawn points.
func advance() -> bool:
	if phase != Protocol.PH_STUDY or tagin_open():
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
