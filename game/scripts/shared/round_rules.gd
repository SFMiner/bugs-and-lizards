class_name RoundRules
extends RefCounted
## Pure round arithmetic for Stages 1-4 (GDD v0.3 §4, §5 tag-in, §7 mutant). No nodes, no networking.
## The public function names and the Dictionary keys documented here are the INTERFACE CONTRACT:
## implementers fill in bodies but do not rename, remove or re-type anything without the manager.
##
## A lizard is a Dictionary:
##   {id: String, student: String, mutant: bool, parent_id: String ("" for starters), generation: int (starters 0)}
## Lizard ids are unique within a room: starters "L1".."Ln", offspring "L<round>-<k>".
## A round runs: resolve_hunt -> new_tagin -> pick/teacher_assign (any number) -> finish_round.

const SURVIVAL_CAPTURES: int = 5
const CAPTURES_PER_OFFSPRING: int = 5
const PREY_MULTIPLIER: int = 3 # each uncaught bug stays and makes two more

const END_NONE: String = ""
const END_ROUNDS: String = "rounds" # the stage's last round is done
const END_FEW_BUGS: String = "few_bugs" # Stage 1: five or fewer bugs remain
const END_NO_BUGS: String = "no_bugs"
const END_NO_LIZARDS: String = "no_lizards"
const END_OVERRUN: String = "overrun" # bugs_next_start > bug_budget; exact count kept


static func survives(captures: int) -> bool:
	return captures >= SURVIVAL_CAPTURES


## Stages 1-2 never earn offspring. Stages 3-4: floor((c - 5) / 5) for a survivor, else 0.
static func earned_offspring(stage: int, captures: int) -> int:
	if stage < 3 or not survives(captures):
		return 0
	return (captures - SURVIVAL_CAPTURES) / CAPTURES_PER_OFFSPRING


## Stage 1: unchanged. Stages 2-4: uncaught * 3.
static func bugs_next_start(stage: int, bugs_uncaught: int) -> int:
	if stage <= 1:
		return bugs_uncaught
	return bugs_uncaught * PREY_MULTIPLIER


## 4 for Stages 1-3, 5 for Stage 4.
static func max_rounds(stage: int) -> int:
	return 5 if stage >= 4 else 4


## Makes the starting lizards for round 1 from student names, ids "L1".."Ln", none mutant.
static func starting_lizards(students: Array) -> Array:
	var out: Array = []
	var n: int = 1
	for s: Variant in students:
		out.append({"id": "L%d" % n, "student": str(s), "mutant": false, "parent_id": "", "generation": 0})
		n += 1
	return out


## Step 3 of §4. captures: {lizard_id: int}; a lizard missing from it caught 0.
## total accepted captures must not exceed bugs_start (push_error and clamp if it does).
## Returns hunt result:
##   {stage, round, bugs_start, bugs_uncaught: int, captures: {id: int},
##    survivors: [lizard], starved: [lizard],
##    slots: [{slot_id: String ("S<k>", k from 1), parent_id: String, parent_mutant: bool}]}
## Slots are listed in lizard order, then slot order per parent.
static func resolve_hunt(stage: int, round_number: int, bugs_start: int, lizards: Array, captures: Dictionary) -> Dictionary:
	var accepted: Dictionary = {}
	var remaining: int = maxi(bugs_start, 0)
	var survivors: Array = []
	var starved: Array = []
	var slots: Array = []
	var slot_k: int = 1
	var requested: int = 0
	for liz: Dictionary in lizards:
		var lid: String = liz["id"]
		var want: int = maxi(int(captures.get(lid, 0)), 0)
		requested += want
		var got: int = mini(want, remaining)
		remaining -= got
		accepted[lid] = got
		if survives(got):
			survivors.append(liz)
			for _i: int in range(earned_offspring(stage, got)):
				slots.append({"slot_id": "S%d" % slot_k, "parent_id": lid, "parent_mutant": bool(liz.get("mutant", false))})
				slot_k += 1
		else:
			starved.append(liz)
	if requested > maxi(bugs_start, 0):
		push_error("RoundRules.resolve_hunt: captures (%d) exceed bugs_start (%d); clamped" % [requested, bugs_start])
	return {"stage": stage, "round": round_number, "bugs_start": bugs_start, "bugs_uncaught": remaining,
		"captures": accepted, "survivors": survivors, "starved": starved, "slots": slots}


## Step 4 of §4. Returns a tag-in state:
##   {slots: [{slot_id, parent_id, parent_mutant, student: "" (unfilled), by_teacher: bool}]}
static func new_tagin(hunt_result: Dictionary) -> Dictionary:
	var slots: Array = []
	for sl: Dictionary in hunt_result.get("slots", []):
		slots.append({"slot_id": sl["slot_id"], "parent_id": sl["parent_id"], "parent_mutant": sl["parent_mutant"],
			"student": "", "by_teacher": false})
	return {"slots": slots}


## A parent picks a student for one of its unfilled slots (the lowest-numbered one). First pick wins:
## a student already placed in any slot is refused. Mutates tagin.
## Returns {ok: bool, reason: String ("", "taken", "no_slot"), slot_id: String}.
## Raised-hand checks are the server's job, not this function's.
static func pick(tagin: Dictionary, parent_id: String, student: String) -> Dictionary:
	var target: Dictionary = {}
	for sl: Dictionary in tagin["slots"]:
		if sl["parent_id"] == parent_id and sl["student"] == "":
			target = sl
			break
	if target.is_empty():
		return {"ok": false, "reason": "no_slot", "slot_id": ""}
	for sl: Dictionary in tagin["slots"]:
		if sl["student"] == student:
			return {"ok": false, "reason": "taken", "slot_id": ""}
	target["student"] = student
	target["by_teacher"] = false
	return {"ok": true, "reason": "", "slot_id": target["slot_id"]}


## Teacher places a student in a specific slot (override): replaces whoever was there. The student
## is first removed from any other slot. Sets by_teacher. Returns {ok, reason ("", "no_slot"), slot_id}.
static func teacher_assign(tagin: Dictionary, slot_id: String, student: String) -> Dictionary:
	var target: Dictionary = {}
	for sl: Dictionary in tagin["slots"]:
		if sl["slot_id"] == slot_id:
			target = sl
			break
	if target.is_empty():
		return {"ok": false, "reason": "no_slot", "slot_id": ""}
	for sl: Dictionary in tagin["slots"]:
		if sl["student"] == student and sl["slot_id"] != slot_id:
			sl["student"] = ""
			sl["by_teacher"] = false
	target["student"] = student
	target["by_teacher"] = true
	return {"ok": true, "reason": "", "slot_id": slot_id}


## Steps 5-7 of §4. lizards_alive = hunt_result.survivors. opts keys (all optional):
##   bug_budget: int (default 1 << 30), mutant_arisen: bool (has this room had its first mutant yet),
##   mutant_slot: String (teacher's choice of which filled slot is the first mutant; "" = automatic),
##   seed: int (automatic mutant choice uses RandomNumberGenerator with this seed over FILLED slots),
##   fallback_mutant: String (Stage 4 teacher fallback: the id of a SURVIVING lizard to make mutant
##   this round, used only while mutant_arisen is false; flagged in the record).
## Stage 4 only: if mutant_arisen is false and at least one slot is filled, exactly one filled
## offspring becomes mutant. Otherwise an offspring is mutant iff its parent is mutant.
## Each filled slot becomes a new lizard {id "L<round>-<k>", student, mutant, parent_id, generation parent+1}.
## Returns:
##   {record: {round, stage, bugs_start, BUGS (= bugs_uncaught), bugs_next_start, LIZARDS (every survivor +
##     every filled offspring), WILD (the non-mutants among them), MUTANTS (the mutants among them),
##     mutant_arisen: bool (a mutant exists by the end of this round; tables and graph show WILD and MUTANTS
##     from the first such round: owner, 2026-11-14), slots_earned, slots_filled, slots_unfilled,
##     mutant_fallback: bool, end_reason},
##    next_lizards: [lizard] (survivors then new offspring), next_bugs_start: int,
##    ended: bool, end_reason: String, mutant_arisen: bool}
## Endpoints (first that applies, in this order): END_NO_BUGS (bugs_uncaught == 0), END_NO_LIZARDS
## (next_lizards empty), END_OVERRUN (bugs_next_start > bug_budget), END_FEW_BUGS (Stage 1 and
## bugs_uncaught <= 5), END_ROUNDS (round >= max_rounds). bugs_next_start is never capped.
static func finish_round(hunt_result: Dictionary, tagin: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var stage: int = hunt_result["stage"]
	var round_number: int = hunt_result["round"]
	var uncaught: int = hunt_result["bugs_uncaught"]
	var budget: int = int(opts.get("bug_budget", 1 << 30))
	var arisen: bool = bool(opts.get("mutant_arisen", false))
	var forced_slot: String = str(opts.get("mutant_slot", ""))
	var fallback_id: String = str(opts.get("fallback_mutant", ""))

	var next_lizards: Array = []
	for liz: Dictionary in hunt_result["survivors"]:
		next_lizards.append(liz.duplicate())

	var filled: Array = []
	var slots_earned: int = 0
	for sl: Dictionary in tagin["slots"]:
		slots_earned += 1
		if sl["student"] != "":
			filled.append(sl)

	# Stage 4: exactly one first mutant among the first filled cohort
	var chosen_slot: String = ""
	if stage == 4 and not arisen and not filled.is_empty():
		for sl: Dictionary in filled:
			if forced_slot != "" and sl["slot_id"] == forced_slot:
				chosen_slot = sl["slot_id"]
		if chosen_slot == "":
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = int(opts.get("seed", 0))
			var pick_idx: int = rng.randi() % filled.size()
			var picked: Dictionary = filled[pick_idx]
			chosen_slot = picked["slot_id"]
		arisen = true

	var k: int = 1
	for sl: Dictionary in filled:
		var is_mutant: bool = bool(sl["parent_mutant"]) or sl["slot_id"] == chosen_slot
		var parent_gen: int = 0
		for liz: Dictionary in next_lizards:
			if liz["id"] == sl["parent_id"]:
				parent_gen = int(liz.get("generation", 0))
		next_lizards.append({"id": "L%d-%d" % [round_number, k], "student": sl["student"], "mutant": is_mutant,
			"parent_id": sl["parent_id"], "generation": parent_gen + 1})
		k += 1

	# Stage 4 teacher fallback: only while no mutant has arisen
	var fallback_used: bool = false
	if stage == 4 and not arisen and fallback_id != "":
		for liz: Dictionary in next_lizards:
			if liz["id"] == fallback_id and not bool(liz["mutant"]):
				liz["mutant"] = true
				fallback_used = true
				arisen = true
				break

	var normal_count: int = 0
	var mutant_count: int = 0
	for liz: Dictionary in next_lizards:
		if bool(liz["mutant"]):
			mutant_count += 1
		else:
			normal_count += 1

	var next_bugs: int = bugs_next_start(stage, uncaught)
	var end_reason: String = END_NONE
	if uncaught == 0:
		end_reason = END_NO_BUGS
	elif next_lizards.is_empty():
		end_reason = END_NO_LIZARDS
	elif next_bugs > budget:
		end_reason = END_OVERRUN
	elif stage == 1 and uncaught <= 5:
		end_reason = END_FEW_BUGS
	elif round_number >= max_rounds(stage):
		end_reason = END_ROUNDS

	var record: Dictionary = {"round": round_number, "stage": stage, "bugs_start": hunt_result["bugs_start"],
		"BUGS": uncaught, "bugs_next_start": next_bugs, "LIZARDS": normal_count + mutant_count,
		"WILD": normal_count, "MUTANTS": mutant_count, "mutant_arisen": arisen,
		"slots_earned": slots_earned, "slots_filled": filled.size(), "slots_unfilled": slots_earned - filled.size(),
		"mutant_fallback": fallback_used, "end_reason": end_reason}
	return {"record": record, "next_lizards": next_lizards, "next_bugs_start": next_bugs,
		"ended": end_reason != END_NONE, "end_reason": end_reason, "mutant_arisen": arisen}
