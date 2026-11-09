# Bugs & Lizards — Four-Review Synthesis and Scope Decision Record

**Companion to:** `Bugs-and-Lizards-GDD-v0.2.md`  
**Date:** 2026-11-09  
**Status:** Proposed decisions for owner review, **not** authorization to implement every listed idea  
**Source of truth:** 2018 *Science Lesson Sequence: The Bugs & Lizards Game*; GDD v0.1 and independent reviews from Kimi, Manus, Qwen, and Mistral

## 1. Executive decision

**Proceed with GDD v0.2 as a proposed baseline; do not yet authorize the full four-stage build.** The reviews agree that the conceptual design is sound and the original numerical rules should be preserved. They also identify classroom-breaking gaps in v0.1 that can be closed without expanding the game's ambitions: round-recording semantics, extinction handling, tag-in capacity, a precise mutant trigger, reconnection behavior, accessibility, and a real-school Chromebook/network feasibility gate.

The most consequential **new** observation is Mistral's: splitting 25 students into four 6–7-student rooms reduces waiting but also severely caps predator reproduction. That can erase the boom/crash pattern that motivates Stage 3. **Counting unfilled offspring slots accurately is necessary but does not solve this ecological issue.** This remains a decision gate, not a disguised solved problem.

The second major correction is also from Mistral: the source's BUGS graph records **post-capture, pre-reproduction** counts, while the LIZARDS graph records **post-survival and post-recruited-offspring** counts. A uniform post-reproduction graph would not match the original classroom data sheets.

## 2. Verification and review provenance

All four reviews were considered independently. Earlier file-handling confusion briefly returned Qwen's text under the Mistral filename; the corrected Mistral document is distinct. The corrected Mistral review begins, “The GDD is unusually disciplined: stage rules, thresholds, and the ×3 prey equation match the source lesson exactly...” The Qwen review instead begins, “The GDD is unusually disciplined: it keeps the four one-rule stages...” They are separate critiques and were not counted as one.

This synthesis assesses **recommendations**, not votes. Agreement from several reviewers is useful but is not proof of scientific correctness or device performance. For source fidelity, key rules and the paper-organizer sequence were checked against the provided 2018 lesson. No Chromebook hardware or campus networking tests have been performed.

### Reviewer contributions worth preserving

| Reviewer | Strongest distinctive contributions | Main caution |
|---|---|---|
| **Kimi** | Identified the contradiction between server-validated visual perception and client-rendered perception; restored explicit extinction/endpoints; proposed a practical cap accounting rule; emphasized technical risk coupling | Proposed a digital one-tap prediction system for observers that is useful but **not essential** to the first playable version |
| **Manus** | Sharp scientific language about mutation vs adaptation; detailed acceptance checks for authority, browser controls, player skill, and accessibility | Its stronger acceptance matrix is helpful for test planning, but not all features should become implementation requirements at once |
| **Qwen** | Defined minimal reconnect/capture race behavior, offspring accounting, teacher mutant fallback, and realistic classroom deployment gates | Some numeric performance thresholds are useful hypotheses, not verified requirements; paper can substitute for digital predictions |
| **Mistral** | Found the graph-timing mismatch; recognized the small-room cap may defeat Stage 3; restored the lynx–snowshoe hare comparison, learning targets, and paper organizers | Its suggested uncapped dashed-line counterfactual risks inventing ecological outcomes unless a complete separate population model is implemented |

## 3. Decision ledger

**Labels:** **Accept** = GDD v0.2 requirement/clarification; **Modify** = useful idea with a smaller or more accurate implementation; **Defer** = potential post-pilot feature; **Reject for v1** = introduces unacceptable scope, cost, or misleading modeling; **Open/test** = cannot honestly decide without evidence.

| ID | Issue / reviewers | Decision | Why and practical cost | Reflected in GDD v0.2 |
|---|---|---|---|---|
| D01 | **Correct original graph timing** — Mistral | **Accept** | Essential fidelity; small specification/UI-label cost. BUGS = uncaught after hunt, before reproduction; LIZARDS = after starvation and tagged offspring. Show next-round start counts separately. | §§3–4, 8, 11 |
| D02 | **Preserve mathematical rules** — all | **Accept** | No arithmetic changes: five captures to survive, two new bugs per uncaught bug, one lizard slot per additional five captures. | §4 |
| D03 | **Extinction and stage endpoints** — Kimi, supported by others | **Accept** | Existing lesson behavior, not a new system. Stage 1 ends at four rounds or ≤5 bugs; Stages 2–4 end at four rounds or extinction; allow a visible teacher-directed extra round. | §4 |
| D04 | **Make mutant introduction precise** — all | **Accept/modify** | Exactly one member of the first Stage 4 offspring cohort is mutant. If reproduction does not occur, teacher may explicitly stage a demonstration fallback—not a hidden natural mutation. | §§4, 7–8 |
| D05 | **Clarify inheritance and natural selection** — Kimi, Manus, Qwen | **Accept** | The initial mutant's own descendants inherit the modeled trait; nonmutant descendants do not. Mutant success is not guaranteed; mutation, trait, and population-level selection are distinct. No genetics engine needed. | §§4, 7–8 |
| D06 | **Available-classmate cap and honest overflow** — all | **Modify/accept provisionally** | Count earned, activated, and unfilled offspring slots separately. Do not give unplayed offspring imaginary captures. This is low-to-moderate accounting complexity, but **does not fix D07**. | §5 |
| D07 | **Small rooms may eliminate predator boom/crash** — especially Mistral | **Open/test (blocking Stage 3)** | Run capped vs uncapped scenarios **before coding**. Test larger Stage 3 groups (two of 12–13, or one full group) instead of quietly changing reproduction. Room count remains configurable by stage. | §§2, 5, 10, 12 |
| D08 | **Dual, dashed “counterfactual predator population”** — Mistral | **Reject for v1 as proposed** | An unplayed offspring cannot hunt, starve, or affect prey without a separate model. A line claiming these consequences could mislead. Keep only accurate earned/filled/unfilled figures. Reconsider only with a formally specified abstract model. | §§5, 13 |
| D09 | **Autonomous NPC predators** — all advise against | **Reject for v1** | Major AI, balance, performance, and pedagogy expansion; obscures effects of students' choices. | §§5, 13 |
| D10 | **Paper organizer vs digital predictions** — Mistral vs Kimi | **Choose paper; defer digital UI** | Original paper forms already provide prediction, data, and exit responses. Avoid building a separate student response/account system before proving the hunt. A projected prompt is enough initially. | §§2–3, 8, 13 |
| D11 | **Restore grade band and original learning targets** — Mistral | **Accept** | Small documentation fix and direct source fidelity. Source authored for Grade 4; proposed usability target Grades 4–8. Do not claim contemporary standards alignment without review. | §§4, 8 |
| D12 | **Restore lynx–snowshoe hare comparison** — Mistral | **Accept, minimal** | Static teacher-provided slide or image, not a data explorer. Preserve ecological balance as a discussion target while not promising equilibrium in four rounds. | §8 |
| D13 | **Capture authority / client perception boundary** — Kimi, Qwen, Manus, Mistral | **Accept/modify** | Server verifies time, unique bug, range, coarse line-of-sight/reachability. It **cannot verify what the human actually saw** through a client-only vision filter. Do not add sophisticated anti-cheat. | §9 |
| D14 | **Disconnect/rejoin behavior** — Qwen, Manus | **Accept minimal version** | Accepted catches persist on server; reconnect via temporary room token; input stops on disconnect; teacher controls seat release. No persistent profiles or event replay engine. | §9 |
| D15 | **Test managed Chromebooks and school WSS first** — all | **Accept; hard gate** | The browser-only premise may fail on actual school hardware or network. Verify first-person pointer lock, frame rate, loading, WSS, tab suspension, and recovery before full build. | §§9–11 |
| D16 | **Numeric frame-rate/latency benchmarks** — Kimi, Qwen, Mistral | **Modify** | The reviews propose differing values (24–30 fps, average vs p95; different load/rejoin limits). Treat as provisional targets, then set pass/fail budgets from tested school-device data; do not present a made-up hardware guarantee. | §§10–11 |
| D17 | **Bug population/render-cap rule** — all | **Accept minimum; defer clusters** | First benchmark individually collectible static bugs. Don't silently drop, render-cull-and-still-capture, or cap the true population. Source-inspired clusters of ten may be useful, but need design/testing to preserve fair hunting. | §§6, 10, 12 |
| D18 | **Camouflage display consistency** — all | **Accept** | Compare target scenes on different school displays, with different brightness/color calibration. A shader that looks plausible on a desktop is not validated. | §§6–7, 10–11 |
| D19 | **Accessible observer/demo alternatives** — Manus, Qwen, Kimi | **Accept** | No student should be required to hunt in an inaccessible dark scene. Include observer/data role and simple teacher demonstration; phenotype filters stay distinct from accessibility needs. | §§5, 7–8 |
| D20 | **Tag-in fairness / teacher assignment** — all | **Accept small safeguard** | Preserve student choice, add invitation timeout and teacher override, show who hasn't had a turn. Do not create a social matching algorithm. | §§5, 8 |
| D21 | **Who starts hunting** — Mistral, Kimi, Qwen | **Modify** | Teacher selects, with optional random pick and visibility of never-active students. Do not mandate automatic rotation, which could conflict with teacher judgment and student consent. | §§5, 8 |
| D22 | **45-second default hunts** — Qwen, Mistral | **Accept as provisional** | Falls within source's 30–60-second window; remain teacher-adjustable, never hardcoded as a biological parameter. | §4 |
| D23 | **Spectator camera / coaching** — Mistral, others | **Open/test** | Keep spectators from receiving hidden bug-location data; use instructor rules for verbal coaching, which code cannot prevent. A fixed or follow-player view may work; avoid building free-camera/spectator systems before needed. | §§3, 5, 9 |
| D24 | **One habitat and one Stage 4 vision trait** — all | **Accept scope fence** | Preserve camouflage and low-light advantage; defer additional color-vision, glare, motion sensitivity, biome, and dynamic weather variations until core stages work. | §§6–7, 13 |
| D25 | **Godot 4.7.2 / headless WSS / PlayCanvas fallback** — all | **Keep as tested hypothesis** | Familiar stack is sensible, but no evidence yet establishes browser performance on school devices. No simultaneous second-engine implementation. | §§2, 9–10 |

## 4. Four decisions where “just accepting a review” would mislead

### 4.1 The small-room issue is a *science* issue, not merely a lobby issue

A six-person room with three starting lizards can never have more than six player-controlled hunters. Even if each parent earns ten offspring slots, the maximum active hunters is bounded by classroom seats. The original whole-class game could have far more lizards hunting before a crash. **A visible “unfilled offspring” field preserves accounting, but does not restore predation pressure.**

**Decision:** Keep small, independent rooms as a valuable mode for Stages 1–2; treat Stage 3 grouping as an evidence-based configuration decision. Before implementing Stage 3, do a simple numeric model and playtest with two larger groups or one classroom-wide group. Do not secretly create AI hunters, cross-room children, or an inaccurate forecast graph.

### 4.2 The graph must distinguish *recording conventions*, not just “end of round”

In the source, the round's BUGS entry precedes new bug placement, but LIZARDS includes selected newborn players. The same classroom scenario therefore has a chart value of 20 bugs after a hunt and a next-round starting value of 60 bugs. Both are true; the labels establish their meaning. A digital graph that shows 60 in the original BUGS round column is not directly comparable with the source organizer.

**Decision:** Primary chart retains the paper semantics, with an explicitly labeled next-start count. Do not build three new chart views or animated graph transitions to explain this; a clear round summary is enough.

### 4.3 Mutation is staged; evolutionary success is not rigged

The lesson intentionally introduces one visual mutant. That event is educational staging, not an assertion that populations mutate when they need to. The student's ability to see dimly lit bugs can improve their chance to catch prey, but student skill, availability, limited room size, and chance may still prevent that lineage from spreading.

**Decision:** Exactly one mutant is designated in the first eligible Stage 4 offspring event; allow an explicit teacher-labeled fallback if none occurs. Only that mutant's descendants inherit the modeled trait. Do not secretly increase their catches, guarantee takeover, or add a full genetics system.

### 4.4 The source includes a real-world comparison; that is not “feature creep”

The original Stage 3 uses Canadian lynx–snowshoe hare data to put a short classroom demonstration in perspective. Omitting it would lose an evidence step that anchors discussion of cycles and ecological balance. But embedding an interactive historical-data platform into the game is not required.

**Decision:** Include teacher-facing support for a **static** graph/slide. Preserve the concept of ecological balance without claiming the 4-round game necessarily reaches equilibrium. The source narration's “Arctic hare” reference should be corrected to **snowshoe hare** for the illustrated dataset.

## 5. Scope budget and release order

| Development gate | Must show | Explicitly excluded at that gate |
|---|---|---|
| **S0: school feasibility** | Actual managed Chromebook loads WebGL2 export; WSS works on school Wi-Fi; pointer lock/trackpad usable | Full game, rich terrain, multiple visual mutations, dashboard polish |
| **S1: technical vertical slice** | One compact first-person hunt, authoritative captures, teacher timer, minimal count display; then two isolated rooms | Dynamic bug AI, cross-room comparison tools, exportable reports |
| **S2: instructional pilot** | Stage 1 and 2 arithmetic, original-style graph, paper organizer, reconnect recovery, small-group classroom pacing | Student prediction forms, accounts, LMS integration |
| **S3: offspring gate** | Validated grouping/number model, invitations, earned/filled/unfilled accounting, no fake hunters | NPC predators, simulated sex/genetics, cross-room migration |
| **S4: mutation gate** | One low-light trait, single correct trigger, inheritance, accessibility/demo path, trait counts | Partial colorblindness variants, photosensitivity, day–night cycles, detailed retina biology |

**Scope-control test:** Any proposal must name which original lesson objective it serves, which gate it belongs to, what gets removed/deferred to pay for it, and what proof would show it is necessary. If no original stage breaks without the feature, it is probably post-pilot.

## 6. Outstanding owner decisions / evidence needs

1. **Stage 3 group size:** After capped-versus-uncapped simulations, is the right configuration two 12–13-person rooms, a single larger room, or another bounded representation? Do not settle this on intuition alone.
2. **First playable visual budget:** What are the lowest and typical managed Chromebook models, and how many individually collectible bugs remain responsive on them?
3. **Campus networking:** Can those devices open the hosted game and maintain secure WebSockets through the school filter/proxy?
4. **Stage 4 fallback presentation:** Should the teacher be able to directly designate an available student as a demonstration mutant, or only force the next earned offspring to be mutant? Either must be visibly labeled as an instructional intervention.
5. **Spectating/assistance:** Which minimal observer view best balances meaningful participation with fair hunting and classroom social rules?

These are design gates, **not invitations** to implement optional systems.

## 7. What did *not* become v0.2

The following remain **out of the first playable scope**: autonomous lizard AI, full insect ecology, deep genetics and multiple inheritance modes, richer or multiple biomes, moving insect swarms, new color-vision mutation families, environmental reversals, complete digital graphic organizers, student accounts and chat, LMS integration, data-export dashboards, an interactive lynx–hare explorer, a second engine built in parallel, and a counterfactual future predator-population line that has no defined simulation underneath it.

These may be good future ideas, but the four-stage ecological inquiry and tag-in gameplay must work first.

## 8. Recommended next action

**Approve, amend, or reject v0.2 as a design baseline, then authorize S0 only.** The first practical action is a **campus-specific compatibility test**, not a month of full-game development. Preserve v0.1 and all four independent reviews unchanged as source history. Any future modification to the game rules should be described as a change to the classroom model, not hidden inside a convenience feature.
