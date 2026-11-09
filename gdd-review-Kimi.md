# Independent Review — Bugs & Lizards GDD v0.1

## 1. Overall assessment

This is an unusually disciplined GDD. Its strongest features: the stage arithmetic is quoted exactly and correctly from the source (5-bug survival threshold, `floor((c−5)/5)` offspring, `survivors × 3` prey growth); assumptions, requirements, and unresolved gates are explicitly separated; the scope-change policy and non-goals list actively resist mission creep; and the engine claims are honest — I verified Godot 4.7 stable shipped 2026-06-18 and 4.7.2 in August 2026, and the GDD's caveats (no HDR on web, Compatibility/WebGL 2 only, the MultiplayerSpawner fix) match the actual release notes.

The main vulnerability is **risk coupling**: the two least-proven commitments — Godot web export + WSS multiplayer on unmanaged school infrastructure, and the socially load-bearing tag-in mechanic — are stacked in series ahead of any classroom value. If the spike fails late, nothing pedagogically useful exists; if the Stage 3 offspring-capacity gate stays open, the payoff lesson (boom-and-crash) is blocked. The fixes are sequencing and one decisive rule choice, not new systems.

## 2. Scientific / instructional corrections

I checked the GDD's arithmetic against the original organizers; it is faithful (original tables: 10–14 bugs → 1 new lizard, 15–19 → 2, matching `floor((c−5)/5)`). The corrections below are about ambiguity and contradiction, not the numbers.

**(a) Stage 4 inheritance wording is ambiguous and could teach false biology.**

> GDD §4, Stage 4 row: "introduce one offspring with a heritable low-light vision advantage; offspring inherit that trait."
> GDD §7: "Descendants inherit the modeled trait under the original lesson's simplified rule."

As written, "offspring inherit that trait" reads as if *all* offspring in the population inherit. The source is specific: the mutation appears once ("The first time any lizard produces offspring, ONE of the lizards in that generation will be a MUTANT"), and only the mutant's own descendants inherit ("The offspring of a mutant lizard are also mutants"). **Fix:** replace with "one offspring of the first reproduction event in Stage 4 is the mutant; only descendants of the mutant lizard inherit the trait; offspring of non-mutant lizards are normal."

**(b) Internal contradiction: server-validated "visibility" vs client-side perception.**

> GDD §9: "Server validates distance, visibility/reachability rules, capture timing…"
> GDD §7 design rule: "Separate world state … from an individual's *perceived* world (client-side visual transformation)."

If detectability is purely client-side, the server has no honest basis to validate "visibility" per phenotype — unless a server-side perception model is built, which §7 forbids by design. **Fix:** "The server validates capture range, bug-availability, and timing only. Whether a bug is perceivable is resolved on the client; capture reports are client-trust, documented as an accepted classroom threat model (no anti-cheat system)."

**(c) Omission: no extinction or endpoint conditions.**

> GDD §3 step 7: "Stage concludes after a small number of rounds or an ecological endpoint."

The source defines these: Game 1 ends when bugs drop to ~5; Games 2–4 end at four rounds or when bugs or lizards hit 0; total bug wipeout is handled as a teacher-led "migration" discussion (Game 3 vocabulary). The GDD never states what happens at population 0, so a Stage 2 crash or Stage 1 wipeout has undefined behavior — this will surface in the first playtest. **Fix:** add a short "Endpoints" rule: Stage 1 ends at ≤5 bugs or 4 rounds; Stages 2–4 end at 4 rounds or bugs=0 or lizards=0; at bugs=0 the room freezes, graphs display, and the teacher is prompted to lead the migration discussion or reset.

**(d) Omission: mutant trigger unspecified.**
The source makes the teacher designate the mutant among the first generation of offspring (and explicitly warns against handing the advantage to a weaker student). The GDD doesn't say *when* or *who*. **Fix:** one sentence — "the mutant arises once, at the first offspring event of Stage 4, chosen by the teacher or at random from eligible new offspring."

## 3. Technical and classroom risks (ranked)

| #   | Risk                                                                                                                                      | Probability | Impact   | Chromebook/campus test required                                                            |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------- | -------- | ------------------------------------------------------------------------------------------ |
| R1  | Compatibility/WebGL 2 renderer + vision shaders below usable frame rate on oldest managed Chromebooks; single-threaded export CPU ceiling | High        | High     | **Yes** — frame capture on the school's oldest model, 10+ min, thermal throttling included |
| R2  | School firewall/content filter blocks or degrades WSS to external host                                                                    | Med-High    | High     | **Yes** — campus-network day zero; test before build commitment, not after                 |
| R3  | Godot pauses processing when a browser tab goes inactive → disconnects during teacher projection/tab switching                            | High        | Medium   | **Yes** — tab-switch and reconnect walkthrough on real devices                             |
| R4  | Prey population explosion (`survivors × 3` reaches 300+ by round 3, as in the source) exceeding render capacity                           | High        | Med-High | Partially — aggregation fallback must be built and labeled regardless                      |
| R5  | Pointer lock / first-person controls on trackpad-only Chromebooks                                                                         | Medium      | Med-High | **Yes** — control scheme usability with actual students                                    |
| R6  | Multi-room + teacher dashboard scope grows before core loop is proven                                                                     | Medium      | Medium   | No — sequencing fix (§4, #5)                                                               |
| R7  | Inter-display color variance invalidates camouflage / Stage 4 contrast                                                                    | Medium      | Medium   | **Yes** — same bug on 3 different screens side by side                                     |
| R8  | 25 concurrent WSS connections on one small server                                                                                         | Low-Med     | Low-Med  | Yes, trivially, during pilot (state is tiny; modest tick rate)                             |

R1–R3 and R5 are the classic failure cluster for Godot-on-Chromebooks; R2 is organizational, not technical — schedule the campus test as a calendar item, not a prototype feature.

## 4. Top five proposed changes

**1. Fix the capture-validation contradiction** — §7 design rule vs §9 ("Server validates distance, visibility/reachability rules").
*Replacement:* server validates range, uniqueness, timing only; detectability is client-trust, documented as accepted for a classroom audience.
*Why:* removes a real contradiction; the only alternative (server-side perception) is the most expensive system in the document and §7 already forbids it.
*Classification:* **Must fix**. *Stages:* all (Stage 4 honesty depends on it). *Cost:* S.
*Cut/defer:* any anti-cheat/perception-validation subsystem.

**2. Define extinction and endpoint conditions** — §3 step 7, §4.
*Replacement:* the "Endpoints" rule quoted in §2(c) above.
*Why:* undefined behavior at population 0 will corrupt every Stage 1–2 playtest; the source already specifies these endings.
*Classification:* **Must fix**. *Stages:* 1–4. *Cost:* S (mostly text + one freeze state).
*Cut/defer:* nothing — this replaces ambiguity, it adds no system.

**3. Resolve the offspring-capacity gate now** — §5 unresolved gate.
*Replacement:* adopt option B-plus: active-lizard cap per room equals the number of connected students in that room; offspring earned beyond the cap are displayed to the teacher as "unrealized offspring," never silently discarded. Reject A (autonomous NPC predators violate §13 non-goals and falsify the equations) and C (undefined).
*Why:* in a 6-student room, three lizards catching 10+ bugs each will exhaust the available pool by round 2 — the gate fires immediately in Stage 3; only B is consistent with the document's own "no silent capping" and "visible teacher settings" principles.
*Classification:* **Must fix (pre-Stage 3 gate, as the GDD already requires)**. *Cost:* M (accounting + teacher display).
*Cut/defer:* all NPC/AI-predator work permanently.

**4. Give observers the prediction mechanism the lesson assumes** — §3 steps 2–3, §8.
*Replacement:* before each round, every non-active student commits a one-tap prediction (up/down/same for bugs and lizards); the teacher sees the aggregate after the round resolves. Mirrors the source's graphic-organizer "ROUND 2 PREDICTION" pedagogy, which the GDD cites but provides no mechanism for.
*Why:* without it, the question→predict→evidence→explain arc in §8 has a missing rung, and observer students — the majority in early rounds — have nothing to do.
*Classification:* **Should improve**. *Stages:* 1–4. *Cost:* S–M.
*Cut/defer:* the full digital graphic organizer and data exports.

**5. Harden the spike exit criteria and reorder delivery** — §10, §11.
*Replacement:* name 2–3 specific school Chromebook models in advance; spike passes only if p95 frame time ≤33 ms on the oldest model during a 10-minute, 2-room, 12-client session, *and* WSS connects from the campus network; deliver a single-room Stage 1 slice before any teacher-dashboard polish.
*Why:* the current criteria ("acceptable frame rate," "test on campus") are unmeasurable; dashboard-first sequencing risks building management UI for an engine target that fails.
*Classification:* **Should improve**. *Stages:* 1. *Cost:* S (test planning).
*Cut/defer:* dashboard exports, cross-room comparison views, replay features until after the Stage 1 pilot.

## 5. Three things NOT to add

1. **Autonomous NPC lizards or bug AI.** The original's dynamics emerge from student hunting plus teacher pacing; every simulated predator breaks the published equations that success criterion 3 (§11) demands be exact, and it is the single largest scope multiplier available (pathing, balance, debugging, performance). The GDD's own §13 forbids it; keep it forbidden.
2. **Persistent student accounts or LMS integration.** The design's privacy posture (nickname + session code, minimal retention) is a genuine strength for 4th–8th graders; accounts add consent, retention, and security obligations that solve no classroom problem, since roles reset every lesson anyway.
3. **The §7 "candidate later traits" list.** The Stage 4 lesson requires exactly one binary, heritable, environmentally favored trait; each additional trait multiplies shader validation, accessibility review, and balance testing for zero lesson gain. Defer all candidates until a Stage 4 pilot demonstrates students reach the adaptation explanation with one trait — the source does.

## 6. Unresolved decisions

- **Offspring capacity:** enough information exists — choose B-plus (§4 #3).
- **Who starts as a lizard:** enough information exists — use a per-room rotation queue (fewest-active-rounds first) with teacher override; this satisfies the fairness safeguard in §5 at near-zero cost.
- **Round length:** keep 30–60 s default, teacher-adjustable (as the source's "Tips & Tricks" intends); a classroom observation session, not a build decision.
- **Detectability model:** adopt documented client-trust (§4 #1); the audience is 4th graders, and the GDD's integrity criteria concern population counts, not per-capture verification.
- **Graph point semantics:** adopt the GDD's own §4 proposal as a hard requirement now — it is a labeling decision, not an open question.
- **Performance, WSS reachability, display color variance:** *not* enough information exists in any document. Cheap tests: borrow the three oldest Chromebooks for one afternoon (R1, R3, R5, R7); one on-campus network day (R2). Both should precede the full implementation commitment the GDD already gates.

## 7. Revised success criteria — smallest functional pilot

Define the pilot as: **Stages 1–2, 2 rooms, 12–15 students, one class period, on campus.**

1. **Deployment:** a student on a fresh managed Chromebook reaches their assigned room in ≤2 clicks and ≤90 seconds after the teacher shares the URL; zero installs; only an ephemeral nickname collected.
2. **Performance:** on the school's oldest Chromebook, p95 frame time ≤33 ms during a 10-minute hunt; no crash or reload required in a 45-minute session.
3. **Connectivity:** a kill-tab test mid-round reconnects within 30 seconds with round data intact; a full 45-minute campus session completes with at most one recoverable dropout per room.
4. **Rule integrity:** a scripted round with known capture counts produces prey and lizard numbers *exactly* equal to `survivors × 3` and `floor((c−5)/5)`; duplicate and out-of-range capture attempts are rejected 100% of the time.
5. **Tag-in:** at least one offspring is invited, accepted, and appears at the next round start carrying parent ID and generation ≥1; teacher override works.
6. **Graph fidelity:** the teacher graph equals server state after every round; every point is labeled start-of-round or post-resolution; the mutant row is tracked separately in Stage 4 tests.
7. **Population honesty:** whenever simulated bugs exceed rendered bugs, the client displays "showing X of Y"; the teacher dashboard always shows exact counts.
8. **Instructional function:** every observer submits at least one up/down/same prediction per stage; the teacher completes one full question→predict→evidence→explain cycle in the period; resetting one room leaves the other untouched.
9. **Endpoint handling (new):** a forced run to bugs=0 freezes cleanly, displays the crash, and offers the teacher the reset/migration-discussion prompt.

These keep the four stages, the original numbers, browser-only deployment, and student tag-in exactly where the source lesson put them — and make the pilot pass/fail measurable instead of aspirational.
