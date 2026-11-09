class_name StageConfig
extends RefCounted
## Stage defaults from GDD v0.3 §4 "Source defaults". Values are per room.

const HUNT_SECONDS_DEFAULT: int = 45
const HUNT_SECONDS_MIN: int = 15
const HUNT_SECONDS_MAX: int = 120
const BUG_BUDGET_DEFAULT: int = 600 # provisional until the Gate 2 bug ladder is measured

const NAMES: Array[String] = ["", "Bugs & Lizards!", "Baby Bugs!", "Baby Lizards!", "Mutant Lizards!"]
const STARTING_LIZARDS: Array[int] = [0, 2, 3, 3, 3]
const STARTING_BUGS: Array[int] = [0, 50, 75, 75, 75]
const PREDICTION_AFTER_ROUND: Array[int] = [0, 2, 2, 2, 3]


## A fresh config Dictionary for CONFIGURE (Protocol.F_CONFIG).
static func defaults(stage: int) -> Dictionary:
	var s: int = clampi(stage, 1, 4)
	return {
		"stage": s,
		"rooms": 1,
		"bugs_start": STARTING_BUGS[s],
		"lizards_start": STARTING_LIZARDS[s],
		"hunt_seconds": HUNT_SECONDS_DEFAULT,
		"bug_budget": BUG_BUDGET_DEFAULT,
	}
