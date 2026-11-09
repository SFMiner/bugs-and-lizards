GDD Review — Bugs & Lizards v0.1
================================

1. Overall assessment

---------------------

The GDD is unusually disciplined: stage rules, thresholds, and the ×3 prey equation match the source lesson exactly; assumptions are labeled as assumptions; scope creep is actively fenced off (§13, §14); and the technical spike is correctly positioned as a gate rather than a formality. The strongest design decision is separating shared world state from per-client perceived vision (§7).

The main vulnerability is a compounding bet: the entire experience depends on Godot's 3D web export performing on managed Chromebooks over a school network, none of which is verified. Meanwhile the most design-sensitive risk is already visible on paper: splitting ~25 students into ecosystems of 6–7 breaks Stage 3's boom-and-crash, which in the source depends on a class-sized offspring pool. The remaining gaps are specification omissions, not bad ideas: the round-recording convention conflicts with the source's organizers, the Stage 4 mutant has no defined trigger, learning targets and the data-recording artifact are missing, and the source's real-data evidence step (lynx–snowshoe hare) is absent. All are cheap to fix now and expensive to fix after server code and graphs exist.

2. Scientific / instructional corrections

-----------------------------------------

No arithmetic errors found. I verified every formula in §4 against the source: `survives = (c >= 5)`, `floor((c-5)/5)` offspring, and `survivors * 3` all match the lesson (the source's own lookup table contains a typo, "0–7" for the starve row, and "Arctic hare" where the dataset is snowshoe hare; the GDD's clean formulas are the correct reading, not an error).

**C1. Round-recording convention contradicts the source's organizers.** GDD §4: _"close captures → count surviving bugs → determine lizard starvation/offspring eligibility → perform births/tag-ins → reproduce surviving bugs → record the resulting populations → release new round."_ The source records asymmetrically: the bug value written in each round's column is **post-capture, pre-reproduction** ("If there are 10 bugs left, then we'll place another 20 bugs, for 30 altogether" — new bugs are hidden _after_ the data is recorded), while the lizard value is **post-birth** (offspring are picked, _then_ "How many lizards do we have now? … under 1, on the LIZARDS row"). The GDD's uniform "record after all resolution" inflates the bug line 3× relative to the paper organizers for identical play, so digital graphs cannot be checked against the classroom artifact. This is a data-representation error, not an equation error.

**C2. Equilibrium caution over-reads against the Stage 3 learning target.** GDD §8: _"Avoid describing oscillation or population 'equilibrium' as an automatic consequence of the simple equations."_ Scientifically correct, but the source's Stage 3 target is "I can describe ecological balance," with equilibrium taught _from real data_, not from the classroom run. As written, the sentence invites an implementer to drop the concept. The caution should be scoped: cycles/equilibrium are patterns in long-run and real-world data, not guarantees of a 4-round stochastic run.

**C3. The real-data evidence step is missing entirely.** Source Game 3 closure: _"Fortunately, we have a LOT of data on this subject. One very well studied case is this animal: [Canadian lynx]… Here is one result of such studies [population graph]."_ GDD §8's arc (Question → Prediction → Evidence → Explanation → Model reflection) never includes comparison to real population data, which is the lesson's evidence anchor and the basis for the equilibrium discussion. This is an omission from the source, not new scope: a teacher-facing side-by-side graph view or slide is enough. Use **snowshoe hare**; the source's "Arctic hare" is its own naming error.

**C4. The Stage 4 mutant has no defined trigger.** GDD §4: _"In a dim, canopy-covered habitat, introduce one offspring with a heritable low-light vision advantage."_ The source is deterministic: _"The first time any lizard produces offspring, ONE of the lizards in that generation will be a MUTANT."_ The GDD never says when or how the mutant appears, or whether it is automatic or teacher-triggered; the server needs a rule. The source's framing ("extra light receptors in its eyes") is the model assumption to preserve as-is; GDD §15's tradeoff caution is right.

**C5. No grade band, learning targets, or recording artifact.** The source is a Grade 4 sequence (used through 8th) with per-lesson targets ("I can describe predation.", "I can explain overpopulation.") and a paper graphic organizer that doubles as prediction sheet and exit ticket. GDD §3 says non-active students "record predictions/data" but no artifact is specified, and §2/§8 state no audience age or objectives. For a game whose success criterion #8 is classroom explanation, this is a genuine omission.

3. Technical and classroom risks

--------------------------------

Ranked by probability × impact. "Must test on Chromebooks" = actual school-managed devices on the school network, not desktop previews.

| #   | Risk                                                                                                                               | Prob.    | Impact               | Test on real Chromebooks                                                                                                        |
| --- | ---------------------------------------------------------------------------------------------------------------------------------- | -------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 3D WebGL2 performance on old fleet models; download size for 25 simultaneous loads                                                 | High     | Fatal                | Oldest approved model: fps during a 6-client hunt; cold-load time when a full class loads at once                               |
| 2   | School network/firewall blocks WSS to host                                                                                         | Med-High | Fatal                | On-campus test with IT present; HTTPS game files can pass while WSS fails                                                       |
| 3   | Stage 3 offspring pool exhausts in 6–7-student rooms; boom-and-crash never emerges                                                 | High     | High (instructional) | **Costs nothing: spreadsheet simulation of capped vs uncapped runs first**                                                      |
| 4   | Tab-inactive pause → disconnect during teacher projection or student tab-switching                                                 | Med      | Med-High             | Scripted tab-switch/minimize mid-round; reconnect time; no state loss                                                           |
| 5   | Server capture validation ("distance, visibility/reachability") is heavier than it sounds; risk of lag or exploitably loose checks | Med      | Med                  | Two clients racing for the same bug; simulated latency; simplify v1 to proximity + raycast line-of-sight + single-owner capture |
| 6   | Display color variance undermines camouflage fairness across Chromebook models                                                     | Med      | Med                  | Same calibration scene on 3+ different models; check detectability ordering survives                                            |
| 7   | Verbal coaching from co-located spectators (all students share one room IRL)                                                       | High     | Med                  | Cannot be solved in software; mirror the source's social rule + hide prey in spectator clients; classroom observation only      |
| 8   | Fairness: a student never chosen as offspring                                                                                      | Med      | Med (social)         | Teacher override + invitation expiry; classroom observation, not code                                                           |

Engine facts check out: Godot 4.7.2 exists as an August 2026 maintenance release with no known incompatibilities ([Godot Engine](https://godotengine.org/article/maintenance-release-godot-4-7-2/)). That verifies the version exists, **not** that it performs on Chromebooks — the GDD correctly refuses to assume this, and the review agrees: nothing in §9 is verified until the spike passes.

4. Top five proposed changes

----------------------------

**Change 1 — Fix the round-recording convention.**

* **Section:** §4 (resolution order) + §8/§11 (graphs).
* **Proposal:** Match the source: each round's displayed bug value = post-capture survivors; lizard value = post-birth count; the next round's start marker shows post-reproduction totals. Alternatively show both as explicitly labeled series. Replace "record the resulting populations" with the source convention.
* **Why:** Without it, digital graphs are incomparable with the paper organizers (C1) and teacher spot-checks fail.
* **Class:** Must fix. **Stage:** all. **Cost:** S.
* **Cut/defer:** graph export/CSV, animated graph transitions.

**Change 2 — Resolve the Stage 3 offspring gate with a bounded, transparent default.**

* **Section:** §5 ("Unresolved design gate").
* **Proposal:** Option B, made honest: cap active offspring at available classmates, and display the uncapped "model population" as a second, dashed line labeled as the model's counterfactual. First step is free: run the capped arithmetic in a spreadsheet to confirm boom-and-crash still emerges at plausible capture rates; keep a one-large-room configuration as a Stage 3 test alternative.
* **Why:** The original dynamics need a class-sized pool; small rooms guarantee the collision. The dual line preserves the science while keeping every student in a real role.
* **Class:** Must fix (blocks Stage 3). **Stage:** 3–4. **Cost:** M.
* **Cut/defer:** NPC lizards entirely; cross-room offspring borrowing; multi-room comparison dashboards.

**Change 3 — Specify the mutant trigger.**

* **Section:** §4 Stage 4 row + §7 "Stage 4 minimum."
* **Proposal:** "At the first offspring event of Stage 4, exactly one member of that cohort is the mutant (source rule); the teacher may instead trigger or reassign it manually." Retain "extra light receptors" as the labeled model assumption.
* **Why:** The server cannot implement an undefined event (C4).
* **Class:** Must fix. **Stage:** 4. **Cost:** S.
* **Cut/defer:** nothing; all other traits stay deferred per §7.

**Change 4 — Restore the real-data comparison and scope the equilibrium caution.**

* **Section:** §8.
* **Proposal:** Add to the instructional arc: "Comparison: teacher shows lynx–snowshoe hare data next to the class graph (static slide or side-by-side view)." Reword the guardrail: equilibrium and cycles are taught _from real data_; the 4-round classroom run may or may not exhibit them, and either outcome is discussable.
* **Why:** Recovers the source's evidence step and Stage 3 learning target without new gameplay (C2, C3).
* **Class:** Must fix (fidelity). **Stage:** 3–4. **Cost:** S.
* **Cut/defer:** interactive data-exploration tools.

**Change 5 — Add grade band, per-stage learning targets, and the recording artifact.**

* **Section:** §2 + §3 step 6 + §8.
* **Proposal:** State Grade 4–8 band; copy the source's per-stage learning targets verbatim; specify that **v1 uses the existing paper graphic organizers** for predictions, outcomes, and assessment (the game's job is to display round data clearly enough to transcribe). Add the source's conduct rules to teacher notes as the social anti-coaching layer.
* **Why:** The organizer is the source's prediction vehicle and exit ticket; leaving the artifact undefined leaves the lesson's assessment layer undefined (C5). Paper-in-v1 is the cheap, faithful choice; an in-app prediction UI can wait for evidence.
* **Class:** Must fix. **Stage:** all. **Cost:** S.
* **Cut/defer:** in-app prediction input; student data capture beyond room codes.

These are all specification completions drawn from the source, not new systems: four are S, one is M, and none adds a mechanic.

5. Three things NOT to add

--------------------------

1. **Autonomous NPC lizards to absorb surplus offspring.** They add AI, balance, and server load; they convert a participation game into a simulation; and the capped-plus-dashed-line scheme (Change 2) achieves the teaching goal for a fraction of the cost. The GDD's own gate language should stay a hard no for v1.

2. **Additional vision traits, color-vision filters, or genetics systems in v1.** The biggest verified-risk category is shader/visual cost on weak Chromebooks, §7 itself warns the color-vision approximations are scientifically shaky, and the source makes its point with exactly one trait. One heritable low-light trait is sufficient for Stage 4's objective; the deferred list in §7 should remain deferred until the pilot proves headroom.

3. **Student accounts / LMS integration / longitudinal data collection.** Tempting for "measuring learning across classes," but it adds privacy review, managed-device friction, and teacher setup time — the three things the design explicitly optimizes against. Room codes + paper organizers already cover identity and assessment. §13's exclusion should be defended, not eroded.

4. Unresolved decisions

-----------------------

* **Stage 3 births vs. students:** enough information to recommend Change 2 (cap + visible counterfactual line). Zero-code validation first: spreadsheet the capped dynamics; if boom-and-crash vanishes at realistic capture rates, fall back to one large room for Stage 3 only.

* **Round-column semantics:** resolved by Change 1; no further question needed.

* **Who begins as a lizard:** enough information. Default to teacher-selected (matches the source's teacher choice, including its "kinetic learners" differentiation note), with a "pick N random" convenience button. No rotation algorithm in v1.

* **Hunt duration:** enough information. Default 45 s, teacher-adjustable, mirroring the source's own "adjust round length" practice — as a visible setting, per the GDD's own no-secret-fudging rule.

* **Huge bug populations:** enough information for a cheap, source-faithful answer: visible clusters of 10 (the source literally "clipped [bugs] together in groups of 10"), with an on-screen label whenever aggregation is active. Set the aggregation threshold (~150) from the spike, not in advance.

* **Spectator camera:** not enough information; recommend follow-lizard first-person POV (spectator sees only what the hunter sees; no free camera with prey visible) and validate with one classroom observation.

* **PlayCanvas fallback:** correctly stays a fallback; spend nothing on it until the Godot spike fails on real hardware.
7. Revised success criteria (smallest functional classroom pilot)

-----------------------------------------------------------------

1. **Load:** on the oldest approved Chromebook, cold load + room join over classroom Wi-Fi completes in ≤ 60 s, with all 25 clients loading in the same session without staff intervention.
2. **Performance:** during a 6-client hunt, the weakest approved model sustains ≥ 25 fps average (logged, not eyeballed).
3. **Connectivity:** a scripted tab-switch and minimize mid-round recovers within 10 s, loses no room state, and requires no teacher action.
4. **Capture integrity:** in 20 scripted two-client races for the same bug, exactly one capture each time; server counts after a scripted capture sequence match the §4 equations exactly (automated check).
5. **Graph fidelity:** for the same scripted play, every displayed round value matches the paper-organizer convention (Change 1), verified by teacher transcription spot-check.
6. **Tag-in:** in a Stage 3 run, at least one offspring is tagged in, joins at the next round start with correct parent ID and generation, and the teacher override path is exercised once.
7. **Stage 4 dry run:** one mutant appears at the first offspring event; its offspring inherit; mutant and non-mutant counts track separately and correctly on the graph.
8. **Camouflage:** on 3+ different Chromebook models, a fixed calibration scene reproduces the intended detectability ordering (contrast-mismatched bugs found faster than matched), and a non-color cue path exists.
9. **Usability:** a teacher who has not read documentation runs setup through a 4-round Stage 1 and debrief inside one class period; students complete at least one prediction/outcome pair on their organizers.

**Verification notes:** all numeric rules checked line-by-line against the uploaded lesson sequence (source of truth); Godot 4.7.2's existence and status checked against the release announcement; Chromebook performance, WSS behavior, and display variance remain unverified by anyone and stay gated behind the spike. Per the source's own framing, the game is an _illustration_ with teacher-controlled, visible variables — every recommendation above preserves that.
