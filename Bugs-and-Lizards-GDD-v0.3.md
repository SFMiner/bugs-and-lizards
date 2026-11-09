# Bugs & Lizards — Game Design Document

**Version:** 0.3 — Source re-check after the four-review synthesis  
**Date:** 2026-11-09  
**Status:** **Approved design baseline** (owner, 2026-11-09). Not an implementation specification, and approval authorises the Gate 0 and Gate 1 prototype work only, not the full four-stage build. Supersedes v0.2, which is kept unchanged.  
**Primary reference:** *Science Lesson Sequence: The Bugs & Lizards Game* (Sean Miner, 2018)  
**Audience:** Designers, educators, developers, and independent AI reviewers

> **Version 0.2 principle:** Restore fidelity to the 2018 classroom sequence and close lesson-breaking ambiguities without adding new gameplay systems. Unverified engineering claims remain prototype gates. This version incorporates four independent critiques (Kimi, Manus, Qwen, and the corrected Mistral review); decisions and rejected suggestions are documented in `Bugs-and-Lizards-Review-Synthesis.md`.
>
> **Version 0.3 principle:** A fifth pass re-read the 2018 lesson, including its four graphic organizers (which are images, so a text-only read misses them), and looked for what v0.2 and the four reviews left out. It adds **no gameplay system**. Each change is a contradiction resolved, an omission filled from the source, or an undefined behaviour given the cheapest honest definition; the change log classifies each one. Passages marked **(v0.3)** are new or changed.

## 1. Elevator pitch

*Bugs & Lizards* is a short-session, first-person, cooperative-classroom/multiplayer ecology game in which students play insect-eating lizards, hunt camouflaged bugs, survive, reproduce, and—in later stages—experience heritable sensory mutations. Several small groups play in **separate ecosystems** at once. A teacher controls the stage and pace; each ecosystem generates population data that students use to make predictions and explain biological phenomena.

The four initial stages are digital adaptations of four consecutive classroom games. They are not four separate engines or campaigns: the same core habitat and round loop gain one new biological rule at a time.

## 2. Design goals and constraints

### Agreed requirements

- **Browser-first; no installation on student devices.** Managed school Chromebooks are the primary target. Students launch via a classroom URL in Chrome.
- **First-person lizard gameplay.** Players experience a lizard's view of the habitat, including differences in vision.
- **Small, simultaneous ecosystems.** A class of roughly 25 may be split into two or more independent groups; An illustrative arrangement is four groups of six or seven **for the early stages**, but Stage 3 may need larger groups to preserve meaningful predator growth. Group size and count must be configurable by stage; no single layout is mandated.
- **Tag-in offspring.** When a lizard earns offspring, its player can pick an available classmate in the same room to become that offspring. This is a central social mechanic, not an incidental UI convenience.
- **Ecological rounds.** Predation, survival, prey reproduction, predator reproduction, and inheritance are measurable, teacher-paced events.
- **Camouflage and color matter.** A stylized aesthetic is appropriate; accurate-enough color relationships, contrast, lighting, and per-player perception are important.
- **Scientific truth over flashy realism.** Simplifications are permitted but must be identified as model assumptions rather than falsely presented as real biological mechanisms.
- **Teacher usable within a class period.** Setup, rounds, prediction, visualization, and discussion must not require a lengthy tutorial or login process.
- **Original teaching artifact preserved.** Initial pilots use the source lesson’s paper graphic organizers for predictions, recording, and exit responses; students do not need digital accounts or form submissions.

### Working assumptions, to validate

- Target **Godot 4.7.2 stable (GDScript)** with the **Compatibility / WebGL 2** renderer, the default single-threaded HTML5 web export, and a browser-based player client. Use the latest tested 4.7 maintenance patch if one becomes available. Keep PlayCanvas as a browser-first fallback if school-device tests fail. **(v0.3)** What has been checked is narrow: on 2026-11-09 the three pages cited in §9 were read and they say what §9 reports. Nothing about Chromebook performance has been checked. Two local facts: the Godot 4.7 editor on the development machine is 4.7-stable, not 4.7.2, and the owner's existing size-reduced web export templates are 2D-only and built from Godot 4.5, so they cannot be used for this game. Plan on the stock 4.7.x web template and measure its download in Gate 0; a custom 3D template is a later optimisation, not a prerequisite.
- Use a **headless authoritative server** with **secure WebSockets (WSS)**, hosting multiple room instances. This is an architectural hypothesis pending prototype tests, not a guarantee of performance on a particular school network.
- Start each ecosystem with **two or three active lizards**; other connected students start in an observer/available-offspring state. Multiple rooms reduce waiting time in Stages 1–2; Stage 3 room sizes require a separate gameplay-model check. **(v0.3)** The source's starting values (§4, "Source defaults") apply **per room**, because each room starts with the same two or three lizards the whole class started with on paper.
- **(v0.3)** **One stage per class period**, as in the source, where the four games are four lessons on different days (and Game 3 "might need to be taught as a two-day lesson"). Nothing needs to persist between days. A teacher who must split a stage across two days re-enters the last recorded counts as the new starting values; the paper organizer holds the history. No save system.
- Plan for approximately **25 concurrent connected browsers across all rooms**, with a small margin; stress-test rather than assuming all Chromebooks perform alike.
- Stylized low-poly 3D habitat; simple silhouettes and readable bugs rather than photorealism.

## 3. Core player experience

1. **Join:** Students open the URL, enter a session/room code, pick their name from the teacher's roster (§5, "Names"), and enter their assigned ecosystem.
2. **Introduce:** Teacher presents the learning targets and the stage's new rule, and may ask aloud what students expect. **(v0.3)** The organizer's *written* prediction is not made here. The source makes it once per stage, at a **prediction stop** after round 2's data is recorded (after round 3 in Stage 4), when students have a trend to extend. Students use the original paper organizer (or a teacher-provided accessible equivalent). No in-app prediction input is required for the first playable build.
3. **Hunt:** Active lizards explore a compact habitat and collect visible/reachable insect targets within a timed round (what counts as a capture: §6). **(v0.3)** Hunters do not see the habitat between hunts, and all start each hunt from a shared start area (§4, step 1). Non-active students can observe and record predictions/data; no spectator should be able to reveal hidden prey locations to active players through game UI.
4. **Resolve:** At round end, the server counts captured insects and determines lizard survival, changes to prey population, and—when enabled—offspring eligibility.
5. **Tag in:** Eligible parents select available classmates to play offspring, inheriting modeled traits in Stage 4.
6. **Study:** The game displays both the original lesson’s round-recording values and the starting totals for the next round (explicitly labeled). Students transcribe the original-style values onto their organizers; teacher can pause before the next hunt.
7. **Repeat/debrief:** The next round starts only when the teacher advances. Stage concludes after a small number of rounds or an ecological endpoint.

**Core feel:** Brief bursts of active searching alternate with fast, legible moments of decision, observation, and explanation. The game should not become a lengthy survival RPG.

## 4. Four-stage progression: original lesson rules

| Stage | Name | Newly introduced rule | Main scientific idea |
|---|---|---|---|
| 1 | **Bugs & Lizards!** | Each lizard must capture **at least 5 bugs** in a round or starve. Captures reduce the prey count. | Predation, competition, resources, data collection. |
| 2 | **Baby Bugs!** | Each **uncaught bug** produces two new bugs after the round; the original uncaught bug remains, giving three bugs for the next round. | Prey reproduction, population growth, improved models. |
| 3 | **Baby Lizards!** | For every **5 bugs caught beyond the 5 needed for survival**, a lizard can generate one new lizard and select another student to play it. | Predator reproduction, resource limits, boom-and-crash dynamics, interacting populations. |
| 4 | **Mutant Lizards!** | At the first offspring event, **exactly one offspring** receives a modeled low-light vision mutation. Only offspring of that mutant lineage inherit the trait in this simplified model. | Mutation, inheritance, differential survival/reproduction, natural selection. |

All later stages retain earlier applicable rules unless the teacher deliberately chooses a demonstration variant. The original lesson typically uses 30–60 second hunts and about four rounds, but these are **defaults to test**, not forced limits. The default digital hunt length is provisionally 45 seconds, teacher-adjustable; the teacher may add a visible extra round for discussion, as in the original sequence.

**(v0.3) Source defaults.** v0.2 gave no starting bug count and assumed four rounds everywhere. The source says:

| Stage | Starting lizards | Starting bugs | Round columns on the organizer | Written prediction after |
|---|---|---|---|---|
| 1 | 2 | 50 ("or whatever"; 50–75 printed) | 4 | Round 2 |
| 2 | 3 | 75, adjusted from how fast bugs were found last lesson | 4 | Round 2 |
| 3 | 3 | 75, adjusted likewise | 4, plus an extra round if no boom and crash has appeared by round 3 | Round 2 |
| 4 | 3 | 75, adjusted likewise | **5** | **Round 3** ("What do you predict will happen by round 5?") |

The Stage 4 lesson *text* repeats "until four rounds have gone by", but its organizer has five round columns and puts the prediction star on round 3, and the text says mutants usually appear in "round 2 or 3". With four rounds that leaves one or two rounds to watch the mutants spread. **Default Stage 4 to five rounds**; the organizer is the artifact students fill in. Confirmed by the owner, 2026-11-09.

**(v0.3) Calibration target — the number the whole model depends on.** How many bugs a lizard catches per hunt decides survival (5), reproduction (10, 15, …) and so every graph. On paper the teacher set it by ending each hunt when "~half the bugs" were found, "usually 30–60 seconds". With 75 bugs and 3 lizards that is roughly 12 bugs each, enough for about one offspring each in round 1; that rate is what produces the Stage 3 boom "by round 3". In the digital game the rate comes from habitat size, bug density, movement speed and the capture action, none of which is tuned yet. Target for the Gate 1 prototype: **three typical players catch about half of 75 bugs within the default hunt**, with slower players still usually reaching 5. Measure it; do not assume it. This is a tuning target for existing parts, not a new feature.

**Source learning targets and intended audience:** Originally written for Grade 4, adaptable for approximately Grades 4–8 with age-appropriate language and support. Keep the original targets, subject to later standards verification:

| Stage | Original student-facing targets |
|---|---|
| 1 | “I can describe predation.” / “I can explain competition.” |
| 2 | “I can describe how populations interact.” / “I can explain the importance of reproduction.” |
| 3 | “I can explain overpopulation.” / “I can describe ecological balance.” |
| 4 | “I can explain how populations change over time.” / “I can explain how populations adapt to competition.” |

These targets are statements to explore and discuss, **not promises** that every short simulated run will exhibit a repeated population cycle or mutant takeover.

### Essential arithmetic

For each active lizard with `c` captures in a round:

- `survives = (c >= 5)`.
- In Stages 3–4, if it survives: `earned_offspring = floor((c - 5) / 5)`.
- Examples: 4 captures → starves, 0 offspring; 5 → survives, 0; 10 → survives, 1; 15 → survives, 2.

For the prey population in Stages 2–4:

- `survivors = prey_at_round_start - total_successful_captures`.
- `prey_for_next_round = survivors * 3`, because each survivor remains and produces two more.

These are **deliberately simplified model equations**. They do not describe realistic energy budgets, generation times, mating, juvenile survival, or limited prey resources.

### Round state, original organizer values, and endpoints

The 2018 paper graphic organizers **do not record all species at the same instant**. They record bugs **after captures but before prey reproduction** and lizards **after starvation and eligible player-offspring selection**. Simply plotting “the post-reproduction population” for both species would change the paper bug series by a factor of three in Stages 2–4. The digital interface must preserve this convention while also exposing precise state labels.

For round `n`:

1. **Start:** preserve `bugs_start`, `normal_lizards_start`, and (Stage 4) `mutant_lizards_start`. New player offspring earned in the preceding round may hunt now. **(v0.3)** In the source the lizards "go into the hall (or turn around)" while new bugs are hidden, and nobody moves until "go". So: between hunts a hunter's screen shows the round summary, not the habitat; the next round's bug positions are not sent to any student client before the hunt starts; and every lizard starts the hunt from the same start area. Otherwise players scout during the tag-in and study pauses.
2. **Hunt:** server accepts valid bug captures during the timer; each bug can be captured only once.
3. **Resolve hunting:** `bugs_uncaught = bugs_start - accepted_captures`; lizards with fewer than five captures starve, and surviving lizards earn any offspring slots.
4. **Tag-in:** resolve the parents' picks and any teacher assignments. Count only picked/assigned player offspring as lizards joining the next round. An offspring earned in round `n` **cannot** hunt in round `n`.
5. **Record original-style round-`n` data:** `BUGS = bugs_uncaught`; `LIZARDS = surviving_normal_lizards + filled_normal_offspring`; Stage 4 also records `MUTANTS = surviving_mutant_lizards + filled_mutant_offspring`. The lizard series represents **post-birth, pre-next-hunt**, whereas the bug series is **pre-bug-birth**. Label these timings in the legend. **(v0.3)** An offspring is counted by **its own** trait, not its parent's: the first mutant is the child of a normal lizard and is counted under MUTANTS, as the source does ("on this round, enter 1"). LIZARDS in Stage 4 means non-mutant lizards only.
6. **Reproduce uncaught bugs:** in Stages 2–4, `bugs_next_start = bugs_uncaught * 3`; in Stage 1, `bugs_next_start = bugs_uncaught`. This **next-round starting count** is displayed separately from the original-style chart value; the `START` column retains the original initial count.
7. **Advance or end:** teacher begins the next round only after the study/prediction interval. Store both the original-style values and the next-start state without conflating them.

For clarity, the game should display a concise round-summary label such as **“Bugs remaining after hunt: 20; bugs at next round start: 60”**. The primary paper-compatible graph uses the original-style entries; an optional non-confusing start-of-round readout need not be a separate graph.

**Endpoints:** Stage 1 ends after four rounds or at five or fewer remaining bugs, by source default; Stages 2–3 end after four rounds, and Stage 4 after five **(v0.3)**, or earlier if bugs reach zero or no active lizards survive. **(v0.3)** One more endpoint, which v0.2 left undefined: if `bugs_next_start` would exceed the habitat's measured bug budget (§6), the room ends there. It shows the exact count and a plain label such as "The bugs have overrun the habitat: 621 bugs". Nothing is capped or discarded. In Stage 2 this is the lesson's intended result (the source's next-steps note reads "Bugs are overrunning the environment"), so there it is an outcome and not an error. A room that ends early waits on its graph until the class moves on. Teacher may deliberately extend a viable run by a visible extra round. At prey extinction, stop the room cleanly, retain the completed graph, and offer a teacher discussion prompt about possible migration; migration is **not** implemented as a gameplay system. Teacher-directed reset starts a new attempt.

## 5. Rooms, players, and offspring

### Ecosystems

- Each room has a **separate prey population, active-lizard roster, lighting/vegetation parameters, round clock, and population history**.
- The teacher sees an overview of all rooms. The game should not require a different server computer for every room.
- A session can run either several small rooms or one larger room, if testing supports it. **Room composition can change between stages** without carrying over a room’s population state; do not promise a seamless population transfer.
- **(v0.3) One teacher, one pace.** "Separate round clock" above means separate *state*, not separate pacing. By default the teacher's start, stop and advance apply to **every room at once**, so the class shares each moment the source treats as a whole-class event: the rule introduction, the count and record, the tag-in, the prediction stop, the Stage 4 mutant announcement and the discussion. Per-room controls are for trouble only (pause, reset, reassign). v0.2 never said which it was, and four independently paced rooms cannot be run by one teacher. Two costs of multiple rooms remain and should be seen in the pilot, not designed around now: the class has several graphs to discuss, not one, and in Stage 4 the first mutant appears in different rounds in different rooms.
- Rooms should use the same stage configuration by default to permit comparison; any intentional environmental difference should be visible in the teacher dashboard and recorded with the data.

### Player roles

- **Active lizard:** moves, sees through its phenotype, and captures prey.
- **Available classmate / observer:** can study public data, make predictions, and raise a hand in the game to be picked as offspring. Must not receive gameplay information that unfairly helps active hunters.
- **Starved lizard:** returns to the available pool (subject to teacher setting), so nobody is permanently excluded from participating.
- **Teacher:** creates rooms, assigns/stages players, starts/pauses/ends rounds, reviews population summaries, and intervenes in tag-in choices when appropriate.

### Tag-in process

1. The server calculates earned offspring slots for each surviving lizard.
2. **(v0.3, owner decision 2026-11-09)** A waiting student who wants to play **raises a hand** in the game: one toggle, lowered by default, changeable at any time. This is the source's rule ("quietly raising their hand") and it is the student's consent.
3. The parent picks from the classmates in the room whose hands are raised, and **the pick is final**: there is no invitation to accept or decline and no timeout. If two parents pick the same student, the first pick the server receives wins and the other parent picks again. If no hand is raised, or the parent has not picked when the teacher advances, the slot is recorded as unfilled; the teacher can assign a student with a raised hand to it first.
4. Child becomes an active lizard **at the next round start**, not halfway through a hunt.
5. The new lizard gets a distinct ID, a parent ID, generation number, and inherited traits as relevant. **(v0.3)** A trait belongs to the lizard, not the student: a student whose mutant lizard starved and who is later picked by a normal parent plays a normal lizard.

**(v0.3) Names.** A parent can only choose a classmate they can recognise in the list, so display names carry weight. v0.2 asked for a free-typed nickname and also for "no arbitrary student-generated content" and no personal information; a free-typed name is both. Owner decision, 2026-11-09: **a teacher-entered roster, for now.** The teacher types the class's display names when setting up the session; a student enters the session code and picks their own name from the list. Students type no free text. The teacher can fix a wrong pick, and names are dropped when the session ends. What the teacher types (first names, initials) is the teacher's choice under the school's privacy rules.

**Important science boundary:** One player choosing one 'offspring' is a participation metaphor, *not* an assertion that real lizards reproduce asexually. The original lesson purposely abstracts mating and life stages. Explain that clearly in teacher notes and a short in-game rule explanation; retain the playful parent/offspring language.

**Provisional Stage 3 participation policy (subject to gameplay-model test):** Each surviving lizard earns offspring slots using the exact original formula. The number of **active player-lizards** is limited by available consenting classmates in that room. Record `offspring_slots_earned`, `offspring_players_activated`, and `offspring_slots_unfilled_due_to_capacity` separately. An unfilled slot **does not** become an imaginary hunter, is **not** silently removed from the tally, and does **not** contribute to future catches. Do not mislabel the unfilled count as a living predator population.

**Important unsolved teaching consequence:** In a room with six students and three starting lizards, the maximum number of active predators is six. This can blunt or prevent the pronounced predator boom/crash from the original whole-class game. Recording unfilled slots fixes accounting honesty, **not** the ecological demonstration. Before Stage 3 implementation, run simple capped-versus-uncapped spreadsheet/scripting scenarios using plausible catch counts; then classroom-test Stage 3 using **two larger rooms (about 12–13 students each)** or, if necessary, **one class-wide room**. Keep room size teacher-configurable rather than inventing NPC predator AI. A hypothetical “uncapped counterfactual population” must not be graphed as if its future catches/starvation were known. If the desired classroom pattern cannot emerge reliably, record that as a model limitation and bring the room-design decision back for approval.

**(v0.3) Three corrections to that test.**

1. **It applies to Stage 4 too.** Stage 4 keeps the Stage 3 rules, and its lesson ("mutants increasing faster than non-mutants") needs free seats for mutant offspring to fill. A full six-seat room shows almost nothing on the MUTANTS row. Wherever this document says "Stage 3 room size", read "Stages 3–4".
2. **It needs measured catch rates, so it comes after Gate 1, not before.** The outcome turns on how catch rate falls as bugs get scarce, and that cannot be guessed. A quick hand calculation shows why: six time-limited lizards may never thin 100+ bugs enough to starve, *or* may strip a small population and crash, depending only on that curve. Use the catch counts logged in Gate 1 as the input.
3. **The fallback contradicts a non-goal and an untested limit.** One class-wide room can reach 20 or more active lizards in a boom. §13 called a 16+ active-lizard game a non-goal, and Gate 2 only tested small rooms. §13 and Gate 2 are amended: many lizards in one room is not required for Stages 1–2, but it must be *measured* before it is offered as the Stage 3–4 answer.

**Open after this review:** Exact Stage 3 room-size default and whether a non-player *abstract population* should ever be modeled. That is a separately scoped future decision, **not** authorized by v0.2.

**Classroom safeguard:** Parent chooses from classmates with raised hands, with teacher override/assignment. Show the teacher who has not yet been active; teacher may select starting lizards or use a simple random pick. There is **no automatic matching algorithm** in v1. Students may decline first-person play, by leaving their hand down, and remain in a meaningful observer/data role. Test for unchosen students during pilot rather than assuming a software queue solves classroom relationships.

## 6. Environment, visual design, and camouflage

- Begin with **one compact, reusable habitat**, not several biomes. It should contain patches of differently colored surfaces, vegetation, and varied light levels.
- Bugs must be **visible and reachable from some angle**, without opening containers, mirroring the original hiding rule. Hunting should reward observation and movement rather than pixel hunting or exploitative clipping.
- **(v0.3) What a capture is.** v0.2 never defined it, and the definition decides whether camouflage and Stage 4 vision matter at all. A capture is a **deliberate, aimed action on one specific bug the player is looking at, from close range** (for example, centre the bug and press a key). Three things would quietly cancel the vision lesson and are excluded: collecting bugs by walking over or near them; any highlight, outline, cursor change or aim assist when the view passes over a bug the player has not noticed; and capturing by sweeping the view while holding or mashing the capture key. Test the last in Gate 1 with a player told to try it. If blind sweeping works, the cheapest remedy is a short delay after a miss; add it only if the test shows the need.
- **(v0.3) Where new bugs go.** The server places each new bug at a random free point from a set of spawn points that are known in advance to be visible and reachable, which is how the "visible from some angle" rule is guaranteed. Uncaught bugs stay where they are. A new bug's colour is drawn from the stage's fixed mix and is **not inherited from its parent**. Inherited bug colour would make the prey evolve camouflage: an attractive idea, but a second selection model that the source does not contain, and it would confound Stage 4. It is a non-goal (§13) and a stated model assumption.
- Bug color and habitat color are meaningful inputs to detectability, without guaranteeing that a given hue is equally distinguishable on every physical display.
- Avoid heavy bloom, high-cost lighting, complex shadows, and photorealistic assets. Favor readable silhouettes, color/contrast control, and efficient geometry/materials.
- In the first prototype, bugs may be static or move only minimally. Do not build a full insect behavior simulation merely to make the world feel alive.
- Displayed insects should represent the simulation consistently. **Do not silently cap, discard, or make unrendered insects collectible** when prey reproduction creates large populations. First benchmark individually collectible static/instanced bugs at increasing counts on Chromebooks. For the earliest classroom pilot, use valid starting conditions that remain within the measured rendering/interaction budget. If a classroom run would exceed it, flag the capacity problem visibly rather than corrupting counts; a labeled cluster-of-ten scheme inspired by the source paper game is a *possible tested extension*, not an assumed mechanic.
- **(v0.3) Stage 2 is meant to break this budget.** Its intended result is runaway growth; the source reports counts "above 300". From the source start of 75 bugs and 3 lizards, the round-4 starting count is about 250 if the lizards keep catching half each round, and about 620 if they keep catching what they caught in round 1 (about 36). These are arithmetic illustrations, not predictions. So "stay within the measured budget" and "show the Stage 2 lesson" pull against each other, and shortening the hunt (the source's own fix) makes it worse. Resolution without a new mechanic: test the bug ladder up to that range (Gate 2), and treat reaching the budget as a labeled endpoint (§4, Endpoints). The last round's reproduction is only ever a number, never rendered, because no hunt follows it.
- Because camouflage is core gameplay, test intended visibility ordering on differently calibrated school Chromebook displays; do not assume equal RGB values create equal perceptual difficulty.

## 7. Vision traits and mutation

### Stage 4 minimum

- Normal lizards struggle in a low-light forest-floor environment. **(v0.3)** In the source every lizard wears sunglasses from Stage 4's first round and the mutant simply takes them off. So only one effect is needed: a handicap on normal lizards. The mutant's view is the ordinary Stage 1–3 view.
- **(v0.3) The handicap must survive the brightness key.** A filter that only darkens the picture is undone by turning the Chromebook's screen brightness up, and a dim screen handicaps a mutant. The handicap has to remove information (lower contrast between bug and background, for instance), not just light. Check it at minimum and maximum screen brightness in Gate 2.
- **(v0.3) The handicap has two limits to tune between.** Too weak and the mutant has no visible advantage (the source wants it "even comically" large). Too strong and no normal lizard reaches 10 captures, so no offspring is born, no mutant ever arises, and every run needs the fallback. On paper mutants appear "usually round 2 or 3"; aim for that.
- At the **first offspring-producing event of Stage 4**, exactly **one** member of that offspring cohort is designated the mutant (automatically or by teacher choice). **(v0.3)** It must be a *filled* offspring, one with a student playing it. When the teacher chooses, the source's advice applies: do not give it to a student who is slower at finding bugs, because that hides the advantage. This is a deliberately scripted classroom-model event, **not** an assertion that a useful mutation arises whenever needed.
- The mutant receives a **modeled low-light detection advantage** in the dim habitat. Only descendants of that mutant lineage inherit the trait under this deliberately simplified inheritance rule. Offspring of non-mutant lizards remain non-mutant.
- If no offspring is earned in time for the Stage 4 lesson, a **teacher-initiated demonstration fallback** can introduce or designate one mutant. Label it as an intervention, separate from the ordinary earned-offspring arithmetic; default suggestion is to offer this after round 2. A forced demonstration must not be concealed in the recorded data.
- The population record distinguishes trait-bearing and non-trait-bearing lizards; a given mutant lineage may still die out or fail to spread. An environmental change (e.g., restored sunlight) remains a **discussion question or controlled later extension**, not a v1 mechanic.

### Candidate later traits — *not automatically in v1*

- Weak low-light sensitivity / night vision difficulties.
- Greater sensitivity to bright light or glare.
- Altered color discrimination, including selective red–green or blue–yellow differences where feasible.
- Heightened responsiveness to motion.

**Design rule:** Separate world state (actual illumination, prey reflectance/appearance, camouflage) from an individual's *perceived* world (client-side visual transformation). A player's vision should not change the underlying shared prey population. Changes in phenotype must affect what can be noticed or detected, **not secretly rewrite locations or spawn more bugs for one player**.

**Science caution:** Screen filters are illustrative approximations, not medically accurate representations of human color-vision deficiencies or complete accounts of reptile visual biology. “Extra light receptors” is the source’s simplified fictional explanation, **not** an established particular lizard-eye mutation. Color vision is not one scalar, and extra light sensitivity does not automatically imply photosensitivity. **Mutation** creates modeled variation in one offspring; **inheritance** passes the modeled trait down its lineage; **natural selection** refers to differential survival/reproduction; **adaptation**, in this context, refers to a population-level change across generations, not an individual deciding or straining to improve its vision. Selection is contingent, not inevitable: an advantageous variant may disappear by chance.

**Minimum accessibility provision:** Do not force students with visual differences or motion sensitivity into an inaccessible experience. Provide a meaningful observer/data role and a teacher-usable comparison/demo view or high-contrast representation with non-color cues. Test a pupil's ability to distinguish the *scientific contrast* across devices without requiring unsafe darkness. Keep actual accessibility choices separate from the modeled lizard phenotype; label when a demo view is not the hunter’s unaided perception. Avoid live spectator views that reveal hidden prey locations to hunters.

## 8. Teaching and feedback loop

A complete stage should support the following instructional arc:

- **Question:** What happened last stage, and what was missing from the model?
- **Prediction:** What should happen after adding the next rule?
- **Evidence:** What happened to prey, lizards, and (later) mutants after each round, using the original paper recording convention?
- **Explanation:** What mechanism could account for the observed pattern?
- **Model reflection:** In what ways does this simplify the biology, and what does it miss?

**Source-faithful assessment:** Use the original stage-specific paper graphic organizers for numerical entries, predictions, and exit responses in v1. Students may use a teacher-provided accessible equivalent. The teacher can project the game’s clearly labeled round summary for transcription. An in-app one-tap prediction or digital organizer is *deferred*, not silently required.

**Stage 3 external evidence (restored from the source lesson):** After reviewing the class population graph, the teacher compares it with a historical **Canadian lynx–snowshoe hare** population graph, using a teacher-provided static slide/image. The source narration once mistakenly says “Arctic hare”; the source figure is snowshoe hare. Discuss *whether* patterns resemble each other and how recorded multi-year population patterns differ from a four-round classroom model. Equilibrium and cycles are legitimate **discussion concepts grounded in real data**, but neither a repeating cycle nor a stable equilibrium is guaranteed in this short simulation. This is a teaching resource, not an interactive dataset explorer.

### Minimum teacher controls

- Start/stop/pause hunt round; advance to next round. **(v0.3)** These act on all rooms by default (§5). During a hunt the teacher sees each room's live caught and remaining counts, because the source's main pacing tool is ending the hunt when about half the bugs are found. The actual length of each hunt is recorded with the round, since it is the variable the teacher is visibly adjusting.
- **(v0.3)** The teacher view marks the prediction stop (after round 2; after round 3 in Stage 4). It is a reminder, not an input form.
- Set initial bug count, starting lizard count, number and membership of rooms, and hunt duration; room configuration may differ by stage.
- Choose the current stage and apply stage-appropriate rules.
- See each room's bug count, normal lizard count, mutant count where relevant, and simple historical graphs with the original round-recording convention and separate next-start totals.
- Override an unsuitable offspring tag-in, reassign a player, and see earned/filled/unfilled offspring slots and who has not yet played.
- Reset a room or stage without disturbing other rooms. Stage 4 additionally needs a low-light setting, designation of the first mutant, and an explicitly marked demonstration fallback if no normal birth occurs. Exporting graphs/data is desirable but not a prerequisite for the initial playable slice.

**Pedagogical guardrail:** Do not rig each simulation to produce a predicted outcome. The original in-person lesson allows teacher adjustments to improve the illustration; the digital version can expose **visible, teacher-controlled scenario settings** and discuss surprising outcomes instead of secretly manufacturing results. Predator-prey cycles may be illustrated, but are not guaranteed in four rounds. **Preserve ecological balance/equilibrium as a Stage 3 teaching target**, taught by contrasting our short experiment with longer-run real-world lynx–hare data rather than claiming that the classroom graph proves a stable equilibrium.

## 9. Preliminary technical architecture — to be proven

```text
School Chromebook browser clients (Godot web export)
       |  HTTPS for game files; WSS for live game state
       v
Hosted authoritative game server (headless Godot)
       |-- Session / Room A ecosystem state
       |-- Session / Room B ecosystem state
       |-- Session / Room C ecosystem state
       `-- Session / Room D ecosystem state

Teacher client (browser) sees room management and summary data.
```

- A **single server** manages multiple isolated rooms, subject to load testing.
- Server owns: identities within a room, captures, survival, reproduction, inherited traits, round timing, and authoritative counts.
- Client owns: first-person camera, local controls, rendering, personal vision effects, non-authoritative animation/interpolation.
- Clients send inputs/actions, not trusted statements such as 'I caught 10 bugs'. Server validates **range, capture timing, bug availability, and unique ownership** (v0.2 also listed coarse line-of-sight; v0.3 defers it, see the next point). Its validation does **not** claim to know what the human player perceived through a client-side vision filter. The first valid competing attempt wins; no advanced anti-cheat or server-side visual-perception simulation in v1.
- **(v0.3) Who owns movement.** v0.2 said the client owns "local controls", that clients send "inputs/actions", and that the server checks range, which together leave open whether the server simulates every lizard's movement. It should not. Baseline: **the client moves its own lizard and reports its position; the server checks only that the reported speed is plausible** and uses that position for the range check. Server-side movement simulation with client prediction and correction is the most expensive networking feature available here, feels worse on a poor connection, and defends against a threat this classroom does not have. For the same reason the line-of-sight check above is **not in v1** unless a pilot shows students capturing through walls; range, timing, uniqueness and speed are enough.
- **(v0.3) How rooms are isolated is an open engineering choice, not a settled fact.** Godot's node-based multiplayer (`MultiplayerSpawner`, `MultiplayerSynchronizer`) assumes one shared world per connection set; several isolated rooms in one server process, with bug positions withheld from some players, needs either per-room multiplayer branches, per-player visibility filters, or one process per room. The alternative is a small hand-written message protocol over the same WebSocket, which may be simpler for a game whose state is a list of static bugs, a few positions and discrete events. Decide in Gate 1 by building one room, then two. The 4.7.2 `MultiplayerSpawner` fix cited below matters only if the node-based route is chosen.
- **(v0.3) The teacher's tab will be hidden.** The teacher shows slides (rules, learning targets, the lynx–hare graph) from the same computer, and a hidden tab stops running. Round timing is already the server's, so a hunt must end on time with the teacher's tab hidden, and the teacher view must rebuild itself from server state when it returns.
- On disconnect, the server retains accepted captures and authoritative ecological state. A resumed session uses an **ephemeral room rejoin token** rather than a persistent student account; input stops while disconnected. The player may resume the same session if the room is still valid. If the player does not return before the next round, the teacher can release or reassign the seat. A disconnect does not retroactively cancel valid captures or secretly create/kill lizards outside the normal rules.
- A room's spectators should not receive exact hidden-prey coordinates if that could enable coaching; public counts and round results can be shared.
- Networking uses **WSS** and a public HTTPS host. The school firewall may still block the endpoint; test on campus. **(v0.3)** Owner decision, 2026-11-09: the server runs on the owner's VPS. It needs a long-running server process and a WSS route through the VPS's web server, which a static game page does not. That web server is shared with other sites, so the route is a change to coordinate, not just a file to upload. Gate 0 is only meaningful against this real host.
- Avoid full-state broadcasts per frame. Replicate moving lizards at a modest frequency with smoothing; replicate static bug information and discrete capture/round events as needed. Optimize large prey counts with spatial organization/instancing and profiling rather than assuming hundreds of synchronized physics agents are viable. **Do not make non-rendered prey secretly available for capture.**
- Use a teacher-entered roster name + temporary session code, without student accounts in the first version (§5, "Names"). Teacher owns room access and removal controls. Keep data retention minimal and defined before deployment.
- No text chat, voice chat, public matchmaking, or student-generated content in the baseline (roster names are typed by the teacher).

**Godot 4.7.2 baseline — advantages, not new requirements:**

- The 4.7 shader editor's inline previews can speed iteration on color-perception, glare, and low-light visual experiments. **They do not guarantee** equivalent results or acceptable frame rates in browser exports.
- Nearest-neighbor filtering for 3D resolution scaling is available if low-resolution rendering needs a deliberately crisp visual style. Lowering rendering resolution is an existing optimization technique, not a new 4.7 speed boost on its own. Test whether its sharper pixel edges help or hinder insect camouflage.
- `Control` offset transforms may simplify animation of tag-in picks and teacher/HUD feedback; simple unanimated UI remains the baseline.
- Godot 4.7.2 includes a `MultiplayerSpawner` replication fix involving removal of spawned nodes; this supports selecting a current maintenance release but does not replace a test of tag-in, death, disconnect, and rejoin flows.
- The new native HDR output does **not** apply to the target HTML5 Compatibility renderer. Do not propose HDR screens, high-end Vulkan lighting, or new `AreaLight3D` features as required solutions to camouflage/vision gameplay. The scientific priority is reliable relative color, contrast, and brightness under ordinary Chromebook displays.
- The 4.7 browser client still uses WebGL 2 / Compatibility, not Forward+ or Mobile, and lacks raw UDP/ENet access. It must use browser-supported networking (planned WSS). The default single-threaded export avoids special cross-origin-isolation requirements at the cost of available CPU parallelism.
- **Browser foreground behavior:** Godot notes that processing pauses when a browser *tab* becomes inactive, potentially disconnecting a multiplayer client. Design the observer mode inside the game and test classroom tab switching, reconnect, and teacher projection. The headless server remains authoritative.

**Compatibility check:** Confirm the specific Godot 4.7 maintenance release, Chromebook hardware, color differences across screens, hosting requirements, and school-network behavior in a real exported prototype. Do not assume desktop editor previews establish Chromebook feasibility.

**Primary references:** [Godot 4.7 release notes](https://godotengine.org/releases/4.7/); [Godot 4.7.2 maintenance notes](https://godotengine.org/article/maintenance-release-godot-4-7-2/); [Godot 4.7 web export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

## 10. Progressive development plan

### Technical spike — **must pass before a full implementation commitment**

**Gate 0: campus connectivity and hardware inventory, before polishing any 3D game.** Identify the oldest and most common target managed Chromebooks; verify HTTPS asset loading, WSS connectivity to the intended host on school Wi-Fi, WebGL 2 availability, first-person mouse/trackpad pointer lock, and permissions. A game that works only from the developer's desktop does **not** pass. **(v0.3)** Also in Gate 0: the download size and cold-load time of a stock-template 3D export (an empty scene is enough), and whether students can move with keys and turn with the trackpad *at the same time*. Some laptops ignore the trackpad while keys are held; whether these Chromebooks do is unknown. Whatever the result, **keyboard-only controls (keys to turn as well as to move) are part of the baseline**: they are the fallback if pointer lock or the trackpad fails, and they are needed by any student who cannot use a pointer.

**Gate 1: minimum running vertical slice.** One small Godot HTML5-exported first-person habitat with individually collectible bugs, two isolated rooms, a headless WSS server, teacher-started/stopped hunts, authoritative single-owner captures, and a minimal readable round summary. Start with one room, then add the second; do not polish a four-room dashboard before basic gameplay works. **(v0.3)** Gate 1 also yields three things later decisions need: logged catch counts per player per hunt at several bug densities (the input to the calibration target in §4 and to the Stage 3–4 room-size test); the result of the blind-sweeping test (§6); and the choice between node-based multiplayer and a plain message protocol (§9). Other lizards need not be drawn for Gate 1; a bug vanishing when someone else takes it is enough to show competition.

**Gate 2: Chromebook pressure test.** Test a controlled ladder of static/instanced bug counts (e.g., 50, 100, 150, 300), sustained hunts on the slowest device, client load time when a class loads simultaneously, responsiveness, temperature-related slowdown, and multiple display colors/brightness settings. Run at least one inexpensive low-light/contrast effect. Test paused/hidden tabs, refresh, transient Wi-Fi loss, pointer-lock recovery, and server-owned state survival. Use a two-room 12–15-student pilot before attempting the ~25-client class target; include simultaneous hunting, not just idle sockets. **(v0.3)** Three additions: extend the bug ladder to the Stage 2 range (about 600; §6) or record where it fails; test the Stage 4 handicap at minimum and maximum screen brightness (§7); and, before a larger room is offered as the Stage 3–4 answer, test 12 and then about 20 lizards moving in **one** room, since every earlier test used small rooms.

**Go/no-go:** No full four-stage implementation until students can reliably join without installation and hunt on school Chromebooks at usable responsiveness and WSS remains connected/recoverable. Target approximately 30 fps when possible; do not freeze a single frame-rate/latency figure as scientific correctness. Define measurable local thresholds **after** inspecting target models. If Godot fails, investigate a leaner browser implementation/PlayCanvas as a separate decision; do not build both engines in parallel.

**Paper/simulation gate before Stage 3 (v0.3: after Gate 1, and covering Stage 4):** Using catch counts measured in Gate 1, run capped vs uncapped population arithmetic scenarios and confirm whether 6–7-player rooms can demonstrate the Stage 3 question and leave room for a Stage 4 mutant lineage to grow. If not, pilot two larger rooms or one class-wide room, without implementing NPC predators or fake counterfactual forecasts.

### Minimum playable instructional build

- Stage 1 complete with two or more rooms, teacher pacing, survival rule, and graphs.
- Stage 2 adds bug reproduction and accurate tracking of larger populations.
- Stage 3 adds lizard reproduction and tag-in. **Validate room-size/offspring-cap science before implementing Stage 3**, including the consequences for boom-and-crash teaching.
- Stage 4 adds low-light conditions, one correctly triggered inherited visual mutation, teacher-labeled fallback if needed, and separately tracked trait-bearing population.

### Later, only if evidence warrants

- Additional visual variants and changes in environmental conditions.
- More extensive teacher exports/reports.
- Adjustable comparisons between room conditions.
- Richer terrain/bug behavior, additional prey species, procedural worlds, or broader genetics.

## 11. Success criteria and tests

A successful early classroom pilot should demonstrate:

1. Students join with **no device installation** on managed Chromebooks; a teacher can run two isolated rooms and eventually approximately 25 concurrent browsers, verified on campus.
2. A class-size set of connected clients (target ~25) is stable, with acceptable input responsiveness and readable visuals on the **slowest relevant Chromebook**, not only the developer's computer.
3. No two players can collect the same bug; 100+ automated boundary cases (including 4/5/10/15 captures, no prey, simultaneous claims, and room isolation) match the published equations; no accepted capture silently disappears on disconnect.
4. At least one offspring is successfully tagged in to a real student, who joins **only** at the next round with the correct parent/lineage data; unfilled and overflow slots are visible to teacher.
5. The prey and predator graph matches server state **and the source paper-organizer convention**, with separately labeled next-round start totals; normal and mutant lizards are distinguished in Stage 4.
6. Camouflage differences are observable, while accessibility alternatives remain available.
7. Teacher can stop or reset a room without affecting unrelated groups.
8. Students can use a paper organizer for prediction/outcome/evidence, explain at least one cause-and-effect pattern and one limitation of the model, and (Stage 3) compare the classroom graph to lynx–snowshoe hare data; classroom usability must be evaluated directly.

9. Stage 1 terminates on its defined threshold; Stages 2–4 terminate cleanly at zero prey/zero surviving lizards, or at the labeled bug-budget endpoint with the exact count shown **(v0.3)**, with graph retained and no automatic migration NPCs.
10. Stage 3 is shown to support the intended population lesson with the **tested** room-size policy, or the lesson limitation is explicitly documented before classroom deployment.
11. **(v0.3)** Three typical players catch about half of the starting bugs within the default hunt (§4, calibration target), or the measured rate and the settings that would reach it are recorded.
12. **(v0.3)** A player told to capture bugs without looking for them (walking over them, sweeping the view while pressing capture) does no better than chance, and a normal Stage 4 lizard gains nothing by raising screen brightness.
13. **(v0.3)** No hunter sees the next round's bugs before the hunt starts.

Numeric performance budgets (download size, frame rate, latency, reconnection allowance) should be set **after** sampling actual school devices and network conditions. A reasonable preliminary aspiration is a smooth-feeling 30 fps on the weakest approved Chromebook, but this is a test target, not a promise. The earliest pilot may use 12–15 connected students in two rooms, then expand to ~25 only after the underlying design passes.

## 12. Known risks and decisions still open

| Issue | Why it matters | Status |
|---|---|---|
| **Browser performance** | Godot web renderer and shader effects may struggle on older Chromebooks. | **Prototype gate.** |
| **School network / WSS** | Browser can load the page but fail to connect to hosted multiplayer. | **Prototype gate.** Owner's report, 2026-11-09: school Chromebooks do load pages from the VPS. Separately, the school firewall sometimes disallows the site and sometimes allows it; this is per occasion (the site is reachable for a session or it is not), not drops scattered through a session. The cause is unknown and finding it is **outside this project**; the owner will raise it with the DOE when the game is ready. A WebSocket has not been tried on campus, and neither has a 3D export, so both remain Gate 0 tests. Consequence for lessons: on a day the firewall disallows the site, the game cannot run at all, so the paper game stays the fallback. |
| **Offspring beyond available students** | Slots are counted honestly, but small rooms may prevent the source lesson’s dramatic predator boom. | **Provisional slot policy chosen; Stage 3 room-size/science test remains a blocker.** |
| **Turn length and observation time** | Very short hunts reduce waiting but may make inquiry rushed. | **45 s provisional, 30–60 s adjustable; test.** |
| **Who begins as a lizard** | Fairness and participation across groups. | **Teacher-select / optional random; teacher sees never-active students; no algorithm.** |
| **Exact color-vision effects** | Scientific legitimacy, shader cost, accessibility. | **Stage 4 first implements low-light difference only.** |
| **What counts as a bug in huge populations** | Insect counts may exceed practical rendered objects. | **Pilot limited by measured individually collectible bug budget; any clusters require separate design approval.** |
| **Unexpected population outcome** | A crash/cycle/mutant takeover is not guaranteed. | **Accept variability and make it discussable.** |
| **Room comparison** | Controlled vs variable settings changes what comparisons establish. | **Same conditions by default; stage-specific room size allowed; cross-room analytics deferred.** |
| **Version and engine fallback** | Need hardware evidence before committing deeply. | **Godot 4.7.2 stable is the provisional build baseline; PlayCanvas remains a test-driven fallback.** |
| **Catch rate (v0.3)** | Every population outcome follows from how many bugs a lizard catches per hunt; nothing sets it yet. | **Target stated (§4); measure in Gate 1.** |
| **Stage 4 length (v0.3)** | Source text says four rounds; its organizer has five and predicts at round 3. | **Decided 2026-11-09: five rounds, prediction after round 3.** |
| **Student display names (v0.3)** | Tag-in needs recognisable names; free-typed names are student content and may be personal data. | **Decided 2026-11-09: teacher-entered roster for now; students pick their name, type nothing.** |
| **Pacing across rooms (v0.3)** | One teacher cannot pace four rooms separately. | **All rooms advance together by default (§5).** |
| **Stage 2 overruns the bug budget (v0.3)** | The lesson's intended result is the thing the budget forbids. | **Labeled endpoint with exact count; ladder tested to about 600.** |
| **Tag-in handshake (v0.3)** | Invite, accept, decline and timeout across several rooms at once costs class time and code. | **Decided 2026-11-09: waiting students raise a hand in the game, and a parent's pick of a raised hand is final. No accept/decline step, no timeout (§5).** |
| **Host (v0.3)** | WSS needs a long-running server; Gate 0 must test the real one. | **Decided 2026-11-09: the owner's VPS. The WSS route on its shared web server is still to be set up.** |
| **Older stub in this folder (v0.3)** | `GDD.md` (2026-10-11) describes a different game with the same name: 2D, single-player, Godot 4.5, Grade 6, Games 1–3 only. | **Decided 2026-11-09: separate projects. `GDD.md` does not govern this one, and nothing in it is a requirement here.** |

## 13. Explicit non-goals for v0.2 / first playable version

- Photorealism, realistic animal anatomy, elaborate animation rigs, or an open-world map.
- Building a full ecosystem with insects independently feeding, mating, competing, or navigating complex terrain.
- Deep genetics, Mendelian pedigrees, multiple-allele systems, sexual selection, or numerous mutation categories.
- Competitive leaderboards, achievements, paid cosmetics, progression currencies, NPC dialogue, or narrative campaigns.
- User accounts, cloud profiles, saved personal identities, social networking, text/voice chat.
- Full learning-management-system integration, formal grading, or adaptive assessment.
- Mobile-phone gameplay and console ports.
- A second biome or day/night cycle *as a core requirement*. A controlled dim-light scenario for Stage 4 is enough.
- A mandatory 16+ **active-lizard** game. The capacity target refers to classroom connectivity across rooms. **(v0.3)** Exception to be tested, not assumed: if one larger room is chosen for Stages 3–4, it can exceed this in a boom (§5).
- **(v0.3)** Inherited bug colour or any other evolution of the prey.
- **(v0.3)** Server-side simulation of player movement, client prediction and correction, or lag compensation.
- **(v0.3)** Saving a session across days.
- Digital graphic organizers or one-tap prediction submissions; paper is sufficient at first.
- A second “counterfactual predator population” graph that suggests unplayed offspring hunt or starve without a defined simulation model.
- Automatic breeding of unplayed offspring, autonomous predators, migration mechanics, or cross-room offspring transfers to repair a small-player-pool problem.

## 14. Scope-change policy for external reviews

Reviewers should treat the above as the baseline, not as a blank canvas. Any suggested change should identify:

1. **What problem in the current design does it solve?**
2. **Is it a scientific correction, accessibility necessity, technical risk mitigation, learning improvement, or optional embellishment?**
3. **Which stage or prototype test would it affect?**
4. **What does it cost** (implementation complexity, Chromebook performance, teaching time, maintenance)?
5. **Can it be deferred without harming the four-stage lesson?**
6. **What feature or complexity would be removed to make room for it?**

Favor **small corrections, clarifications, and testable hypotheses** over new systems. No reviewer should silently redefine the reproduction arithmetic or turn the four short games into a long-form survival game.

## 15. Source fidelity and attribution

The original 2018 classroom sequence supplies the stage names and incremental rules, basic thresholds (5 bugs to survive, 2 baby bugs per **uncaught bug**, 5 additional bugs per offspring), typical 30–60-second rounds, paper-organizer data timing, Stage 3 lynx–snowshoe hare comparison, population-charting pedagogy, and rainforest low-light mutant scenario. The **browser, first-person 3D, multiple rooms, teacher dashboard, in-game hand-raising and picks, visual filters, and network architecture** are proposed digital-design adaptations.

For scientific clarity: the source's visual demonstration (wearing sunglasses or not) should not be translated into an unsupported claim that a particular real-world eye mutation has a known tradeoff. Likewise, this game models one-parent 'births' to allocate classroom roles; it does not model actual lizard reproductive biology.

**(v0.3) Known errors in the source,** so that nobody "restores" them: the Game 3 and 4 organizers' lookup table shows starvation at "0-7" bugs (it is 0–4; the rules beside it say fewer than 5); the Game 3 narration says "Arctic hare" where the figure is snowshoe hare; the Game 4 text says four rounds where its organizer has five; and the Game 2 plan repeats Game 1's objectives. If the paper organizers are printed for a pilot, fix the "0-7" first.

---

### Change log

- **0.3 (2026-11-09):** Fifth pass, against the source lesson and its organizer images. No gameplay system added. Each change is classed as a **contradiction** (two statements that cannot both hold, or a conflict with the source), an **omission** (something the build or the lesson needs that was undefined), or **polish**.
  - *Contradictions resolved:* Stage 4 has five rounds and predicts at round 3 on its organizer, not four and two (§4). The written prediction happens mid-stage, not before every hunt (§3). Free-typed nicknames conflicted with "no student-generated content" (§5, §9). "Separate round clock" per room conflicted with one teacher pacing a class (§5, §8). The one-large-room fallback conflicted with the 16+ lizard non-goal and was untested (§5, §10, §13). The bug budget conflicted with Stage 2's intended outcome, and the overflow behaviour was undefined (§4, §6). Movement authority was stated three incompatible ways (§9). The MUTANTS formula misfiled the first mutant (§4). The room-size gate named Stage 3 but binds Stage 4 as well, and was ordered before the measurements it needs (§5, §10).
  - *Omissions filled:* source starting values (§4); the catch-rate calibration target (§4, §11); what a capture is, and the ways it could bypass vision (§6); no scouting between hunts (§3, §4); where new bugs go and that bug colour is not inherited (§6); the Stage 4 handicap must survive screen brightness and be tuned between two limits (§7); the mutant must be a filled offspring and traits belong to lizards (§5, §7); one stage per class period, no saves (§2); keyboard-only controls and the stock-template download in Gate 0 (§10); live counts for the teacher (§8); hidden teacher tab (§9); room isolation as an open engineering choice (§9); host undecided (§9, §12); source errata (§15).
  - *Polish:* "research data" reworded; line-of-sight validation moved out of v1; other lizards not drawn in Gate 1.
  - *Owner decisions, 2026-11-09:* Stage 4 runs five rounds; names come from a teacher-entered roster for now; the server runs on the owner's VPS; `GDD.md` in this folder is a separate project; tag-in is "raise a hand, and the parent's pick is final", replacing v0.2's invite, accept and timeout (§5). The owner approved all five as written in this document, including the tag-in tie-break and unfilled-slot handling. The owner then approved v0.3 as the design baseline, and reported that school Chromebooks reach the VPS with occasional refusals from the school Wi-Fi (§12).
  - *Verification done:* the three Godot pages cited in §9 were read on 2026-11-09 and match §9's claims. Not verified by anyone: any Chromebook, network, performance, catch-rate or classroom claim.

- **0.2 (2026-11-09):** Synthesized four **distinct** reviews (Kimi, Manus, Qwen, corrected Mistral) and checked pivotal points against the original lesson. Corrected original-style graph timing; restored learning targets, paper organizers, real-data comparison, and stage endpoints; specified one-mutant trigger, capacity accounting, basic rejoin/capture behavior, and Chromebook gates. Identified—rather than concealed—the **small-room Stage 3 predator-boom tradeoff**. Kept speculative vision variants, NPCs, digital prediction systems, and complex data graphs out of v1. Decision-by-decision rationale: `Bugs-and-Lizards-Review-Synthesis.md`.
- **0.1 (2026-11-09):** Created first review baseline from the original lesson and the initial design conversation. Distinguishes agreed requirements, working assumptions, unresolved gates, and deferred enhancements. Updated the technical baseline to **Godot 4.7.2 stable** and documented actual browser-rendering limits and 4.7 features without adding gameplay scope. No implementation decisions are final until technical spike and scope review.
