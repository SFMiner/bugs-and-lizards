extends SceneTree
## Room-size replay: simulates Stage 3 with the real RoundRules, sampling per-lizard captures from the catch log.
## Run: <godot> --headless --path game --script res://tests/room_size_replay.gd
## Env: BL_CATCHES (csv path), BL_MIN_HUNT (default 30), BL_SIZES ("6,12,25"), BL_RUNS (default 500).

const STAGE: int = 3
const START_LIZARDS: int = 3
const START_BUGS: int = 75
const BUG_BUDGET: int = 600
const MAX_ROUNDS: int = 5
const K_NEAR: int = 10
const MIN_ROWS: int = 20
const UNCAPPED: int = 1 << 30

var rows: Array[Vector2] = [] # x = bugs per hunter, y = captures (sorted by x)


func _init() -> void:
	print("CAVEAT: input catch counts come from bots/tests unless BL_CATCHES points at real class data; bots catch far more than people, so treat these as a pipeline check, not a prediction.")
	var min_hunt: float = float(OS.get_environment("BL_MIN_HUNT")) if OS.get_environment("BL_MIN_HUNT") != "" else 30.0
	var path: String = OS.get_environment("BL_CATCHES") if OS.get_environment("BL_CATCHES") != "" else "user://logs/catches.csv"
	var runs: int = int(OS.get_environment("BL_RUNS")) if OS.get_environment("BL_RUNS") != "" else 500
	var sizes: Array[int] = []
	var sizes_txt: String = OS.get_environment("BL_SIZES") if OS.get_environment("BL_SIZES") != "" else "6,12,25"
	for part: String in sizes_txt.split(",", false):
		sizes.append(int(part))

	var hunts: Dictionary = {}
	if not _load(path, min_hunt, hunts):
		quit(0)
		return
	if rows.size() < MIN_ROWS:
		print("Only %d rows with hunt_seconds_actual >= %s: too few (need %d). Stopping." % [rows.size(), str(min_hunt), MIN_ROWS])
		quit(0)
		return
	rows.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	print("Used %d rows from %d hunts (hunt >= %s s). %d runs per size, seeds 1..%d, k=%d nearest by bugs-per-hunter." % [rows.size(), hunts.size(), str(min_hunt), runs, runs, K_NEAR])
	print("Assumptions: free classmates = seats - surviving lizards (starved lizards' students are free); every free classmate raises a hand; parents always pick, in slot order.")

	for n: int in sizes:
		_report("N=%d seats" % n, n, runs)
	_report("UNCAPPED (counterfactual, NOT a real outcome)", UNCAPPED, runs)
	quit(0)


func _load(path: String, min_hunt: float, hunts: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Cannot open catch log (error %d). Set BL_CATCHES." % FileAccess.get_open_error())
		return false
	f.get_csv_line() # header
	while not f.eof_reached():
		var c: PackedStringArray = f.get_csv_line()
		if c.size() < 10:
			continue
		var secs: float = float(c[6])
		var hunters: int = int(c[7])
		var bugs: int = int(c[5])
		if secs < min_hunt or hunters <= 0 or bugs <= 0:
			continue
		rows.append(Vector2(float(bugs) / float(hunters), float(int(c[9]))))
		hunts["%s|%s|%s|%s|%s" % [c[0], c[1], c[2], c[3], c[4]]] = true
	return true


func _sample(rng: RandomNumberGenerator, ratio: float) -> int:
	var lo: int = 0
	var hi: int = rows.size()
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if rows[mid].x < ratio:
			lo = mid + 1
		else:
			hi = mid
	var l: int = lo - 1
	var r: int = lo
	var picked: Array[int] = []
	while picked.size() < K_NEAR and (l >= 0 or r < rows.size()):
		var take_left: bool = false
		if l >= 0 and r < rows.size():
			take_left = absf(rows[l].x - ratio) <= absf(rows[r].x - ratio)
		else:
			take_left = l >= 0
		if take_left:
			picked.append(int(rows[l].y))
			l -= 1
		else:
			picked.append(int(rows[r].y))
			r += 1
	return picked[rng.randi() % picked.size()]


func _simulate(seed_value: int, seats: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var names: Array = []
	for i: int in range(START_LIZARDS):
		names.append("s%d" % i)
	var lizards: Array = RoundRules.starting_lizards(names)
	var bugs: int = START_BUGS
	var recs: Array = []
	var std_reason: String = ""
	var ext_reason: String = ""
	for rnd: int in range(1, MAX_ROUNDS + 1):
		var ratio: float = float(bugs) / float(lizards.size())
		var counts: Array[int] = []
		var total: int = 0
		for _i: int in range(lizards.size()):
			var cnt: int = _sample(rng, ratio)
			counts.append(cnt)
			total += cnt
		while total > bugs:
			var j: int = rng.randi() % counts.size()
			if counts[j] > 0:
				counts[j] -= 1
				total -= 1
		var caps: Dictionary = {}
		for i: int in range(lizards.size()):
			var liz: Dictionary = lizards[i]
			caps[liz["id"]] = counts[i]
		var hunt: Dictionary = RoundRules.resolve_hunt(STAGE, rnd, bugs, lizards, caps)
		var tagin: Dictionary = RoundRules.new_tagin(hunt)
		var survivors: Array = hunt["survivors"]
		var free: int = seats - survivors.size()
		var fill_n: int = 0
		for sl: Dictionary in tagin["slots"]:
			if free > 0:
				fill_n += 1
				var res: Dictionary = RoundRules.pick(tagin, sl["parent_id"], "f%d_%d" % [rnd, fill_n])
				if bool(res["ok"]):
					free -= 1
		var fin: Dictionary = RoundRules.finish_round(hunt, tagin, {"bug_budget": BUG_BUDGET})
		recs.append(fin["record"])
		var reason: String = fin["end_reason"]
		if bool(fin["ended"]) and not (reason == RoundRules.END_ROUNDS and rnd < MAX_ROUNDS):
			if std_reason == "":
				std_reason = reason
			ext_reason = reason
			break
		if rnd == 4:
			std_reason = "rounds"
		lizards = fin["next_lizards"]
		bugs = int(fin["next_bugs_start"])
	return {"recs": recs, "std": std_reason, "ext": ext_reason}


func _pct(vals: Array[int], p: float) -> int:
	var s: Array[int] = vals.duplicate()
	s.sort()
	return s[int(round(p * float(s.size() - 1)))]


func _boom(series: Array[int], upto: int) -> bool:
	var n: int = mini(upto, series.size())
	for i: int in range(n):
		if series[i] >= START_LIZARDS + 2:
			for j: int in range(i + 1, n):
				if series[j] <= series[i] - 2:
					return true
	return false


func _report(label: String, seats: int, runs: int) -> void:
	var by_round_bugs: Array = []
	var by_round_liz: Array = []
	var by_round_unf: Array = []
	for _r: int in range(MAX_ROUNDS):
		var a: Array[int] = []
		var b: Array[int] = []
		var c: Array[int] = []
		by_round_bugs.append(a)
		by_round_liz.append(b)
		by_round_unf.append(c)
	var boom4: int = 0
	var boom5: int = 0
	var std_end: Dictionary = {}
	var ext_end: Dictionary = {}
	for run: int in range(1, runs + 1):
		var out: Dictionary = _simulate(run, seats)
		var recs: Array = out["recs"]
		var series: Array[int] = []
		for i: int in range(recs.size()):
			var rec: Dictionary = recs[i]
			var ba: Array[int] = by_round_bugs[i]
			var la: Array[int] = by_round_liz[i]
			var ua: Array[int] = by_round_unf[i]
			ba.append(int(rec["BUGS"]))
			la.append(int(rec["LIZARDS"]))
			ua.append(int(rec["slots_unfilled"]))
			series.append(int(rec["LIZARDS"]))
		if _boom(series, 4):
			boom4 += 1
		if _boom(series, 5):
			boom5 += 1
		var s: String = out["std"]
		var e: String = out["ext"]
		std_end[s] = int(std_end.get(s, 0)) + 1
		ext_end[e] = int(ext_end.get(e, 0)) + 1
	print("")
	print("== %s ==" % label)
	print("rnd | BUGS med (p10-p90) | LIZARDS med (p10-p90) | unfilled med | still going")
	for r: int in range(MAX_ROUNDS):
		var bv: Array[int] = by_round_bugs[r]
		if bv.is_empty():
			print("%d   | (no runs reached this round)" % (r + 1))
			continue
		var lv: Array[int] = by_round_liz[r]
		var uv: Array[int] = by_round_unf[r]
		print("%d%s | %d (%d-%d) | %d (%d-%d) | %d | %d%%" % [r + 1, " (extra)" if r == 4 else "",
			_pct(bv, 0.5), _pct(bv, 0.1), _pct(bv, 0.9), _pct(lv, 0.5), _pct(lv, 0.1), _pct(lv, 0.9),
			_pct(uv, 0.5), int(round(100.0 * bv.size() / runs))])
	print("boom and crash (LIZARDS >= start+2, later falls >= 2): by round 4 = %d%%, by round 5 = %d%%" % [int(round(100.0 * boom4 / runs)), int(round(100.0 * boom5 / runs))])
	print("end reasons, 4-round game: %s" % JSON.stringify(std_end))
	print("end reasons, 5-round game: %s" % JSON.stringify(ext_end))
