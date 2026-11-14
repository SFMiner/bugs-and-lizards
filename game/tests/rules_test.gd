extends SceneTree
## Headless tests for RoundRules. Run with --script res://tests/rules_test.gd

const EXPECTED_TOTAL: int = 314

var passed: int = 0
var failed: int = 0


func _init() -> void:
	test_table()
	test_basics()
	test_hunt_and_tagin()
	test_endpoints()
	test_stage2_walkthrough()
	test_stage4_mutant()
	test_fallback()
	if failed == 0 and passed == EXPECTED_TOTAL:
		print("rules_test: PASS %d/%d" % [passed, EXPECTED_TOTAL])
		quit(0)
	else:
		print("rules_test: FAIL %d failures, %d/%d passed" % [failed, passed, EXPECTED_TOTAL])
		quit(1)


func eq(actual: Variant, expected: Variant, label: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])


func ok(cond: bool, label: String) -> void:
	eq(cond, true, label)


func lizs(n: int) -> Array:
	var names: Array = []
	for i: int in range(n):
		names.append("Kid%d" % (i + 1))
	return RoundRules.starting_lizards(names)


func caps(values: Array) -> Dictionary:
	var d: Dictionary = {}
	for i: int in range(values.size()):
		d["L%d" % (i + 1)] = values[i]
	return d


func fill_all(tagin: Dictionary) -> void:
	var n: int = 1
	for sl: Dictionary in tagin["slots"]:
		RoundRules.teacher_assign(tagin, sl["slot_id"], "Kid%d" % (100 + n))
		n += 1


func count_mutants(lizards: Array) -> int:
	var c: int = 0
	for l: Dictionary in lizards:
		if l["mutant"]:
			c += 1
	return c


# === captures table across stages ===
func test_table() -> void:
	var cs: Array = [0, 4, 5, 9, 10, 14, 15, 20]
	var surv: Array = [false, false, true, true, true, true, true, true]
	var off: Array = [0, 0, 0, 0, 1, 1, 2, 3]
	for stage: int in range(1, 5):
		for i: int in range(cs.size()):
			var c: int = cs[i]
			eq(RoundRules.survives(c), surv[i], "survives s%d c%d" % [stage, c])
			var expect_off: int = off[i] if stage >= 3 else 0
			eq(RoundRules.earned_offspring(stage, c), expect_off, "offspring s%d c%d" % [stage, c])
			var h: Dictionary = RoundRules.resolve_hunt(stage, 1, 100, lizs(1), caps([c]))
			eq(h["survivors"].size(), 1 if surv[i] else 0, "hunt survivors s%d c%d" % [stage, c])
			eq(h["slots"].size(), expect_off, "hunt slots s%d c%d" % [stage, c])
			eq(h["bugs_uncaught"], 100 - c, "hunt uncaught s%d c%d" % [stage, c])


func test_basics() -> void:
	eq(RoundRules.bugs_next_start(1, 40), 40, "s1 next unchanged")
	eq(RoundRules.bugs_next_start(2, 40), 120, "s2 next x3")
	eq(RoundRules.bugs_next_start(3, 7), 21, "s3 next x3")
	eq(RoundRules.bugs_next_start(4, 0), 0, "s4 next of 0")
	eq(RoundRules.max_rounds(1), 4, "max rounds s1")
	eq(RoundRules.max_rounds(3), 4, "max rounds s3")
	eq(RoundRules.max_rounds(4), 5, "max rounds s4")
	var l: Array = RoundRules.starting_lizards(["Ann", "Bo"])
	eq(l.size(), 2, "starting count")
	eq(l[0]["id"], "L1", "starting id 1")
	eq(l[1]["id"], "L2", "starting id 2")
	eq(l[1]["student"], "Bo", "starting student")
	eq(l[0]["mutant"], false, "starting not mutant")
	eq(l[0]["generation"], 0, "starting generation")
	eq(l[0]["parent_id"], "", "starting parent")
	# clamping
	var h: Dictionary = RoundRules.resolve_hunt(2, 1, 10, lizs(2), caps([8, 8]))
	eq(h["captures"]["L1"], 8, "clamp first intact")
	eq(h["captures"]["L2"], 2, "clamp second reduced")
	eq(h["bugs_uncaught"], 0, "clamp uncaught zero")
	eq(h["survivors"].size(), 1, "clamp only first survives")
	eq(h["starved"].size(), 1, "clamp second starved")
	# missing capture entry means 0
	var h2: Dictionary = RoundRules.resolve_hunt(2, 1, 50, lizs(2), {"L1": 6})
	eq(h2["captures"]["L2"], 0, "missing capture is 0")
	eq(h2["starved"][0]["id"], "L2", "missing starves")


# === hunt slots, tag-in, finish ===
func test_hunt_and_tagin() -> void:
	var h: Dictionary = RoundRules.resolve_hunt(3, 1, 100, lizs(3), caps([10, 15, 4]))
	eq(h["slots"].size(), 3, "s3 slot count")
	eq(h["slots"][0]["slot_id"], "S1", "slot S1")
	eq(h["slots"][0]["parent_id"], "L1", "S1 parent")
	eq(h["slots"][1]["slot_id"], "S2", "slot S2")
	eq(h["slots"][1]["parent_id"], "L2", "S2 parent")
	eq(h["slots"][2]["parent_id"], "L2", "S3 parent")
	eq(h["slots"][2]["parent_mutant"], false, "S3 parent_mutant")
	eq(h["starved"][0]["id"], "L3", "L3 starved")
	eq(h["bugs_uncaught"], 71, "s3 uncaught")
	var t: Dictionary = RoundRules.new_tagin(h)
	eq(t["slots"].size(), 3, "tagin slots")
	eq(t["slots"][0]["student"], "", "tagin empty")
	eq(t["slots"][0]["by_teacher"], false, "tagin by_teacher false")
	var r1: Dictionary = RoundRules.pick(t, "L2", "Dee")
	eq(r1["ok"], true, "pick ok")
	eq(r1["slot_id"], "S2", "pick lowest slot")
	var r2: Dictionary = RoundRules.pick(t, "L1", "Dee")
	eq(r2["ok"], false, "same student refused")
	eq(r2["reason"], "taken", "taken reason")
	eq(t["slots"][0]["student"], "", "refused did not fill")
	var r3: Dictionary = RoundRules.pick(t, "L1", "Eli")
	eq(r3["ok"], true, "second parent picks another")
	eq(r3["slot_id"], "S1", "second parent slot")
	var r4: Dictionary = RoundRules.pick(t, "L2", "Fay")
	eq(r4["slot_id"], "S3", "next slot for same parent")
	var r5: Dictionary = RoundRules.pick(t, "L2", "Gus")
	eq(r5["ok"], false, "no more slots")
	eq(r5["reason"], "no_slot", "no_slot reason")
	var r6: Dictionary = RoundRules.pick(t, "L3", "Gus")
	eq(r6["reason"], "no_slot", "starved parent no_slot")
	# teacher assign
	var ta: Dictionary = RoundRules.teacher_assign(t, "S1", "Fay")
	eq(ta["ok"], true, "teacher assign ok")
	eq(t["slots"][0]["student"], "Fay", "teacher replaced")
	eq(t["slots"][0]["by_teacher"], true, "by_teacher set")
	eq(t["slots"][2]["student"], "", "student removed from other slot")
	var tb: Dictionary = RoundRules.teacher_assign(t, "S9", "Zed")
	eq(tb["reason"], "no_slot", "teacher no_slot")
	eq(tb["ok"], false, "teacher no_slot not ok")
	# finish with S3 unfilled
	var f: Dictionary = RoundRules.finish_round(h, t)
	var rec: Dictionary = f["record"]
	eq(rec["slots_earned"], 3, "earned 3")
	eq(rec["slots_filled"], 2, "filled 2")
	eq(rec["slots_unfilled"], 1, "unfilled 1")
	eq(rec["LIZARDS"], 4, "LIZARDS 2 survivors + 2 offspring")
	eq(rec["MUTANTS"], 0, "MUTANTS 0")
	eq(rec["WILD"], 4, "WILD = LIZARDS before any mutant")
	eq(rec["mutant_arisen"], false, "no mutant yet")
	eq(rec["BUGS"], 71, "record BUGS")
	eq(rec["bugs_next_start"], 213, "record next")
	eq(f["next_bugs_start"], 213, "next_bugs_start")
	eq(f["next_lizards"].size(), 4, "next lizards size")
	eq(f["next_lizards"][2]["id"], "L1-1", "offspring id 1")
	eq(f["next_lizards"][2]["student"], "Fay", "offspring student")
	eq(f["next_lizards"][2]["parent_id"], "L1", "offspring parent")
	eq(f["next_lizards"][2]["generation"], 1, "offspring generation")
	eq(f["next_lizards"][3]["student"], "Dee", "second offspring")
	eq(f["ended"], false, "not ended")
	eq(f["end_reason"], "", "end_reason empty")
	eq(f["mutant_arisen"], false, "s3 no mutant arisen")
	# unfilled slots never become lizards even when none filled
	var t2: Dictionary = RoundRules.new_tagin(h)
	var f2: Dictionary = RoundRules.finish_round(h, t2)
	eq(f2["next_lizards"].size(), 2, "no fills, only survivors")
	eq(f2["record"]["slots_unfilled"], 3, "all unfilled")
	# stage 1 and 2 do not earn slots even at 20
	var h12: Dictionary = RoundRules.resolve_hunt(2, 1, 100, lizs(1), caps([20]))
	eq(RoundRules.finish_round(h12, RoundRules.new_tagin(h12))["record"]["slots_earned"], 0, "s2 no slots")


func test_endpoints() -> void:
	# no prey
	var h: Dictionary = RoundRules.resolve_hunt(2, 1, 0, lizs(2), caps([0, 0]))
	var f: Dictionary = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_NO_BUGS, "no prey at start (no lizards too, bugs first)")
	h = RoundRules.resolve_hunt(2, 1, 10, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_NO_BUGS, "all bugs caught")
	eq(f["next_bugs_start"], 0, "no bugs next")
	eq(f["ended"], true, "ended no bugs")
	# all lizards starve
	h = RoundRules.resolve_hunt(2, 1, 75, lizs(3), caps([1, 2, 0]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_NO_LIZARDS, "all starve")
	eq(f["next_lizards"].size(), 0, "no lizards left")
	# 75 start, 3 caught: starvation has priority over overrun
	h = RoundRules.resolve_hunt(2, 1, 75, lizs(1), caps([3]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"bug_budget": 200})
	eq(f["end_reason"], RoundRules.END_NO_LIZARDS, "starvation beats overrun")
	eq(f["next_bugs_start"], 216, "216 exact when all starve")
	# overrun with a survivor
	h = RoundRules.resolve_hunt(2, 1, 75, lizs(2), caps([5, 0]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"bug_budget": 200})
	eq(f["end_reason"], RoundRules.END_OVERRUN, "overrun")
	eq(f["next_bugs_start"], 210, "overrun exact 210")
	eq(f["record"]["bugs_next_start"], 210, "record overrun exact")
	eq(f["ended"], true, "overrun ended")
	h = RoundRules.resolve_hunt(2, 1, 75, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"bug_budget": 195})
	eq(f["end_reason"], RoundRules.END_NONE, "exactly at budget not overrun")
	h = RoundRules.resolve_hunt(2, 1, 75, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"bug_budget": 194})
	eq(f["end_reason"], RoundRules.END_OVERRUN, "one over budget overruns")
	# Stage 1 few bugs
	h = RoundRules.resolve_hunt(1, 1, 30, lizs(2), caps([14, 11]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["record"]["BUGS"], 5, "s1 five remain")
	eq(f["end_reason"], RoundRules.END_FEW_BUGS, "s1 ends at 5 remaining")
	eq(f["next_bugs_start"], 5, "s1 next unchanged")
	h = RoundRules.resolve_hunt(1, 1, 30, lizs(2), caps([12, 11]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_NONE, "s1 7 remain continues")
	h = RoundRules.resolve_hunt(1, 4, 30, lizs(2), caps([6, 6]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_ROUNDS, "s1 round 4 ends")
	h = RoundRules.resolve_hunt(1, 3, 30, lizs(2), caps([6, 6]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["ended"], false, "s1 round 3 continues")
	# few_bugs only applies to stage 1
	h = RoundRules.resolve_hunt(2, 1, 10, lizs(2), caps([5, 0]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_NONE, "s2 with 5 remaining continues")
	# round limits for stages 3 and 4
	h = RoundRules.resolve_hunt(3, 4, 100, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["end_reason"], RoundRules.END_ROUNDS, "s3 round 4 ends")
	h = RoundRules.resolve_hunt(4, 4, 100, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"mutant_arisen": true})
	eq(f["ended"], false, "s4 round 4 continues")
	h = RoundRules.resolve_hunt(4, 5, 100, lizs(2), caps([5, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h), {"mutant_arisen": true})
	eq(f["end_reason"], RoundRules.END_ROUNDS, "s4 round 5 ends")


func test_stage2_walkthrough() -> void:
	var lz: Array = lizs(3)
	var bugs: int = 75
	# round 1: 8+6+4 = 18 caught, L3 starves
	var h: Dictionary = RoundRules.resolve_hunt(2, 1, bugs, lz, caps([8, 6, 4]))
	var f: Dictionary = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["record"]["BUGS"], 57, "wt r1 BUGS")
	eq(f["next_bugs_start"], 171, "wt r1 next")
	eq(f["record"]["LIZARDS"], 2, "wt r1 LIZARDS")
	eq(f["ended"], false, "wt r1 continues")
	lz = f["next_lizards"]
	bugs = f["next_bugs_start"]
	# round 2: 30+30
	h = RoundRules.resolve_hunt(2, 2, bugs, lz, caps([30, 30]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["record"]["BUGS"], 111, "wt r2 BUGS")
	eq(f["next_bugs_start"], 333, "wt r2 next")
	eq(f["record"]["bugs_start"], 171, "wt r2 bugs_start")
	lz = f["next_lizards"]
	bugs = f["next_bugs_start"]
	# round 3: 100+5
	h = RoundRules.resolve_hunt(2, 3, bugs, lz, caps([100, 5]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["record"]["BUGS"], 228, "wt r3 BUGS")
	eq(f["next_bugs_start"], 684, "wt r3 next")
	eq(f["record"]["slots_earned"], 0, "wt r3 no offspring")
	lz = f["next_lizards"]
	bugs = f["next_bugs_start"]
	# round 4: 200+200, last round
	h = RoundRules.resolve_hunt(2, 4, bugs, lz, caps([200, 200]))
	f = RoundRules.finish_round(h, RoundRules.new_tagin(h))
	eq(f["record"]["BUGS"], 284, "wt r4 BUGS")
	eq(f["next_bugs_start"], 852, "wt r4 next")
	eq(f["end_reason"], RoundRules.END_ROUNDS, "wt r4 ends")
	eq(f["next_lizards"].size(), 2, "wt lizards constant")


func stage4_setup(lizards: Array, cs: Array, fill: bool) -> Array:
	var h: Dictionary = RoundRules.resolve_hunt(4, 1, 300, lizards, caps(cs))
	var t: Dictionary = RoundRules.new_tagin(h)
	if fill:
		fill_all(t)
	return [h, t]


func test_stage4_mutant() -> void:
	var setup: Array = stage4_setup(lizs(3), [15, 15, 15], true)
	var h: Dictionary = setup[0]
	var t: Dictionary = setup[1]
	eq(t["slots"].size(), 6, "s4 six slots")
	var f: Dictionary = RoundRules.finish_round(h, t, {"seed": 42})
	eq(count_mutants(f["next_lizards"]), 1, "exactly one mutant")
	eq(f["record"]["MUTANTS"], 1, "record MUTANTS 1")
	eq(f["record"]["LIZARDS"], 9, "record LIZARDS 9 (all)")
	eq(f["record"]["WILD"], 8, "record WILD 8")
	eq(f["record"]["mutant_arisen"], true, "record mutant_arisen")
	eq(f["next_lizards"].size(), 9, "9 lizards next")
	eq(f["mutant_arisen"], true, "mutant_arisen set")
	eq(f["record"]["mutant_fallback"], false, "no fallback flag")
	var m: Dictionary = {}
	for l: Dictionary in f["next_lizards"]:
		if l["mutant"]:
			m = l
	eq(m["generation"], 1, "mutant is offspring")
	var parent_mutant: bool = true
	for l: Dictionary in f["next_lizards"]:
		if l["id"] == m["parent_id"]:
			parent_mutant = l["mutant"]
	eq(parent_mutant, false, "mutant is child of a normal lizard")
	# same seed same result
	var f2: Dictionary = RoundRules.finish_round(h, t, {"seed": 42})
	var same: bool = true
	for i: int in range(f["next_lizards"].size()):
		if f["next_lizards"][i] != f2["next_lizards"][i]:
			same = false
	eq(same, true, "same seed same result")
	# different seeds vary the mutant and always give exactly one
	var seen: Dictionary = {}
	var always_one: bool = true
	for sd: int in range(1, 31):
		var fs: Dictionary = RoundRules.finish_round(h, t, {"seed": sd})
		if count_mutants(fs["next_lizards"]) != 1:
			always_one = false
		for l: Dictionary in fs["next_lizards"]:
			if l["mutant"]:
				seen[l["id"]] = true
	eq(always_one, true, "one mutant for 30 seeds")
	ok(seen.size() > 1, "seeds vary the mutant")
	# mutant_slot honoured
	var fm: Dictionary = RoundRules.finish_round(h, t, {"seed": 42, "mutant_slot": "S4"})
	var mid: String = ""
	var mstudent: String = ""
	for l: Dictionary in fm["next_lizards"]:
		if l["mutant"]:
			mid = l["id"]
			mstudent = l["student"]
	eq(mstudent, t["slots"][3]["student"], "mutant_slot S4 honoured")
	eq(count_mutants(fm["next_lizards"]), 1, "mutant_slot still one mutant")
	eq(mid, "L1-4", "mutant offspring id")
	# mutant_slot unfilled falls back to a random filled slot
	var setup2: Array = stage4_setup(lizs(3), [15, 15, 15], false)
	var t2: Dictionary = setup2[1]
	RoundRules.teacher_assign(t2, "S1", "Xan")
	RoundRules.teacher_assign(t2, "S2", "Yul")
	var fu: Dictionary = RoundRules.finish_round(setup2[0], t2, {"seed": 3, "mutant_slot": "S5"})
	eq(count_mutants(fu["next_lizards"]), 1, "unfilled mutant_slot falls back")
	eq(fu["record"]["slots_unfilled"], 4, "unfilled recorded")
	var ok_student: bool = false
	for l: Dictionary in fu["next_lizards"]:
		if l["mutant"] and (l["student"] == "Xan" or l["student"] == "Yul"):
			ok_student = true
	eq(ok_student, true, "mutant came from a filled slot")
	# already arisen: no new mutant from normal parents
	var fa: Dictionary = RoundRules.finish_round(h, t, {"seed": 42, "mutant_arisen": true})
	eq(count_mutants(fa["next_lizards"]), 0, "no new mutant once arisen")
	# later offspring: mutant parent -> mutant, normal parent -> normal
	var lz: Array = lizs(2)
	lz[0]["mutant"] = true
	var h3: Dictionary = RoundRules.resolve_hunt(4, 2, 300, lz, caps([10, 10]))
	eq(h3["slots"][0]["parent_mutant"], true, "slot knows parent mutant")
	eq(h3["slots"][1]["parent_mutant"], false, "slot knows parent normal")
	var t3: Dictionary = RoundRules.new_tagin(h3)
	fill_all(t3)
	var f3: Dictionary = RoundRules.finish_round(h3, t3, {"mutant_arisen": true})
	eq(f3["next_lizards"][2]["mutant"], true, "mutant parent's child mutant")
	eq(f3["next_lizards"][3]["mutant"], false, "normal parent's child normal")
	eq(f3["record"]["MUTANTS"], 2, "MUTANTS counts survivor + child")
	eq(f3["record"]["LIZARDS"], 4, "LIZARDS counts all")
	eq(f3["record"]["WILD"], 2, "WILD counts normals")
	# stage 4 with nobody filled: no mutant, arisen stays false
	var setup4: Array = stage4_setup(lizs(2), [10, 10], false)
	var f4: Dictionary = RoundRules.finish_round(setup4[0], setup4[1], {"seed": 1})
	eq(f4["mutant_arisen"], false, "no fills no mutant")
	eq(count_mutants(f4["next_lizards"]), 0, "no fills zero mutants")
	# stage 3 never makes a mutant
	var h5: Dictionary = RoundRules.resolve_hunt(3, 1, 300, lizs(2), caps([15, 15]))
	var t5: Dictionary = RoundRules.new_tagin(h5)
	fill_all(t5)
	var f5: Dictionary = RoundRules.finish_round(h5, t5, {"seed": 1})
	eq(count_mutants(f5["next_lizards"]), 0, "stage 3 no mutants")


func test_fallback() -> void:
	var setup: Array = stage4_setup(lizs(3), [10, 10, 10], false)
	var f: Dictionary = RoundRules.finish_round(setup[0], setup[1], {"fallback_mutant": "L2"})
	eq(f["record"]["mutant_fallback"], true, "fallback flagged")
	eq(f["record"]["MUTANTS"], 1, "fallback MUTANTS")
	eq(f["record"]["LIZARDS"], 3, "fallback LIZARDS all")
	eq(f["record"]["WILD"], 2, "fallback WILD")
	eq(f["next_lizards"][1]["mutant"], true, "fallback L2 mutant")
	eq(f["mutant_arisen"], true, "fallback sets arisen")
	# ignored once mutant has arisen
	var g: Dictionary = RoundRules.finish_round(setup[0], setup[1], {"fallback_mutant": "L2", "mutant_arisen": true})
	eq(g["record"]["mutant_fallback"], false, "fallback ignored when arisen")
	eq(count_mutants(g["next_lizards"]), 0, "fallback ignored no mutant")
	# ignored when the id is not a survivor
	var s2: Array = stage4_setup(lizs(3), [10, 10, 2], false)
	var h: Dictionary = RoundRules.finish_round(s2[0], s2[1], {"fallback_mutant": "L3"})
	eq(h["record"]["mutant_fallback"], false, "non-survivor fallback ignored")
	eq(count_mutants(h["next_lizards"]), 0, "non-survivor no mutant")
	# not used when an offspring mutant arises naturally
	var s3: Array = stage4_setup(lizs(2), [15, 15], true)
	var k: Dictionary = RoundRules.finish_round(s3[0], s3[1], {"fallback_mutant": "L1", "seed": 5})
	eq(k["record"]["mutant_fallback"], false, "fallback not needed")
	eq(count_mutants(k["next_lizards"]), 1, "natural mutant only")
	# not used in other stages
	var h2: Dictionary = RoundRules.resolve_hunt(3, 1, 100, lizs(2), caps([10, 10]))
	var f2: Dictionary = RoundRules.finish_round(h2, RoundRules.new_tagin(h2), {"fallback_mutant": "L1"})
	eq(f2["record"]["mutant_fallback"], false, "fallback only stage 4")
