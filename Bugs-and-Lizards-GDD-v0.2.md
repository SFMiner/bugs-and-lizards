# Bugs & Lizards — Game Design Document

**Version:** 0.2 — Four-review synthesis  
**Date:** 2026-11-09  
**Status:** Proposed consolidated design baseline; pending owner review; not an implementation specification  
**Primary reference:** *Science Lesson Sequence: The Bugs & Lizards Game* (Sean Miner, 2018)  
**Audience:** Designers, educators, developers, and independent AI reviewers

> **Version 0.2 principle:** Restore fidelity to the 2018 classroom sequence and close lesson-breaking ambiguities without adding new gameplay systems. Unverified engineering claims remain prototype gates. This version incorporates four independent critiques (Kimi, Manus, Qwen, and the corrected Mistral review); decisions and rejected suggestions are documented in `Bugs-and-Lizards-Review-Synthesis.md`.

## 1. Elevator pitch

*Bugs & Lizards* is a short-session, first-person, cooperative-classroom/multiplayer ecology game in which students play insect-eating lizards, hunt camouflaged bugs, survive, reproduce, and—in later stages—experience heritable sensory mutations. Several small groups play in **separate ecosystems** at once. A teacher controls the stage and pace; each ecosystem generates population data that students use to make predictions and explain biological phenomena.

The four initial stages are digital adaptations of four consecutive classroom games. They are not four separate engines or campaigns: the same core habitat and round loop gain one new biological rule at a time.

## 2. Design goals and constraints

### Agreed requirements

- **Browser-first; no installation on student devices.** Managed school Chromebooks are the primary target. Students launch via a classroom URL in Chrome.
- **First-person lizard gameplay.** Players experience a lizard's view of the habitat, including differences in vision.
- **Small, simultaneous ecosystems.** A class of roughly 25 may be split into two or more independent groups; An illustrative arrangement is four groups of six or seven **for the early stages**, but Stage 3 may need larger groups to preserve meaningful predator growth. Group size and count must be configurable by stage; no single layout is mandated.
- **Tag-in offspring.** When a lizard earns offspring, its player can invite an available classmate in the same room to become that offspring. This is a central social mechanic, not an incidental UI convenience.
- **Ecological rounds.** Predation, survival, prey reproduction, predator reproduction, and inheritance are measurable, teacher-paced events.
- **Camouflage and color matter.** A stylized aesthetic is appropriate; accurate-enough color relationships, contrast, lighting, and per-player perception are important.
- **Scientific truth over flashy realism.** Simplifications are permitted but must be identified as model assumptions rather than falsely presented as real biological mechanisms.
- **Teacher usable within a class period.** Setup, rounds, prediction, visualization, and discussion must not require a lengthy tutorial or login process.
- **Original teaching artifact preserved.** Initial pilots use the source lesson’s paper graphic organizers for predictions, recording, and exit responses; students do not need digital accounts or form submissions.

### Working assumptions, to validate

- Target **Godot 4.7.2 stable (GDScript)** with the **Compatibility / WebGL 2** renderer, the default single-threaded HTML5 web export, and a browser-based player client. Use the latest tested 4.7 maintenance patch if one becomes available. Keep PlayCanvas as a browser-first fallback if school-device tests fail.
- Use a **headless authoritative server** with **secure WebSockets (WSS)**, hosting multiple room instances. This is an architectural hypothesis pending prototype tests, not a guarantee of performance on a particular school network.
- Start each ecosystem with **two or three active lizards**; other connected students start in an observer/available-offspring state. Multiple rooms reduce waiting time in Stages 1–2; Stage 3 room sizes require a separate gameplay-model check.
- Plan for approximately **25 concurrent connected browsers across all rooms**, with a small margin; stress-test rather than assuming all Chromebooks perform alike.
- Stylized low-poly 3D habitat; simple silhouettes and readable bugs rather than photorealism.

## 3. Core player experience

1. **Join:** Students open the URL, enter a session/room code and an ephemeral nickname, and enter their assigned ecosystem.
2. **Observe/predict:** Teacher briefly presents the current rule and asks what students expect to happen; students use the original paper organizer (or a teacher-provided accessible equivalent). No in-app prediction input is required for the first playable build.
3. **Hunt:** Active lizards explore a compact habitat and collect visible/reachable insect targets within a timed round. Non-active students can observe and record predictions/data; no spectator should be able to reveal hidden prey locations to active players through game UI.
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

1. **Start:** preserve `bugs_start`, `normal_lizards_start`, and (Stage 4) `mutant_lizards_start`. New player offspring earned in the preceding round may hunt now.
2. **Hunt:** server accepts valid bug captures during the timer; each bug can be captured only once.
3. **Resolve hunting:** `bugs_uncaught = bugs_start - accepted_captures`; lizards with fewer than five captures starve, and surviving lizards earn any offspring slots.
4. **Tag-in:** resolve the available student-offspring invitations and teacher assignments. Count only accepted/assigned player offspring as lizards joining the next round. An offspring earned in round `n` **cannot** hunt in round `n`.
5. **Record original-style round-`n` data:** `BUGS = bugs_uncaught`; `LIZARDS = surviving_normal_lizards + filled_normal_offspring`; Stage 4 also records `MUTANTS = surviving_mutant_lizards + filled_mutant_offspring`. The lizard series represents **post-birth, pre-next-hunt**, whereas the bug series is **pre-bug-birth**. Label these timings in the legend.
6. **Reproduce uncaught bugs:** in Stages 2–4, `bugs_next_start = bugs_uncaught * 3`; in Stage 1, `bugs_next_start = bugs_uncaught`. This **next-round starting count** is displayed separately from the original-style chart value; the `START` column retains the original initial count.
7. **Advance or end:** teacher begins the next round only after the study/prediction interval. Store both the original-style values and the next-start state without conflating them.

For clarity, the game should display a concise round-summary label such as **“Bugs remaining after hunt: 20; bugs at next round start: 60”**. The primary paper-compatible graph uses the original-style entries; an optional non-confusing start-of-round readout need not be a separate graph.

**Endpoints:** Stage 1 ends after four rounds or at five or fewer remaining bugs, by source default; Stages 2–4 end after four rounds or if bugs reach zero or no active lizards survive. Teacher may deliberately extend a viable run by a visible extra round. At prey extinction, stop the room cleanly, retain the completed graph, and offer a teacher discussion prompt about possible migration; migration is **not** implemented as a gameplay system. Teacher-directed reset starts a new attempt.

## 5. Rooms, players, and offspring

### Ecosystems

- Each room has a **separate prey population, active-lizard roster, lighting/vegetation parameters, round clock, and population history**.
- The teacher sees an overview of all rooms. The game should not require a different server computer for every room.
- A session can run either several small rooms or one larger room, if testing supports it. **Room composition can change between stages** without carrying over a room’s population state; do not promise a seamless population transfer.
- Rooms should use the same stage configuration by default to permit comparison; any intentional environmental difference should be visible in the teacher dashboard and recorded with the data.

### Player roles

- **Active lizard:** moves, sees through its phenotype, and captures prey.
- **Available classmate / observer:** can study public data, make predictions, and accept a parent invitation. Must not receive gameplay information that unfairly helps active hunters.
- **Starved lizard:** returns to the available pool (subject to teacher setting), so nobody is permanently excluded from participating.
- **Teacher:** creates rooms, assigns/stages players, starts/pauses/ends rounds, reviews population summaries, and intervenes in tag-in choices when appropriate.

### Tag-in process

1. The server calculates earned offspring slots for each surviving lizard.
2. Parent player chooses among classmates in the room's available pool.
3. Invitee accepts or the teacher can assign a player under a classroom-mode setting.
4. Child becomes an active lizard **at the next round start**, not halfway through a hunt.
5. The new lizard gets a distinct ID, a parent ID, generation number, and inherited traits as relevant.

**Important science boundary:** One player choosing one 'offspring' is a participation metaphor, *not* an assertion that real lizards reproduce asexually. The original lesson purposely abstracts mating and life stages. Explain that clearly in teacher notes and a short in-game rule explanation; retain the playful parent/offspring language.

**Provisional Stage 3 participation policy (subject to gameplay-model test):** Each surviving lizard earns offspring slots using the exact original formula. The number of **active player-lizards** is limited by available consenting classmates in that room. Record `offspring_slots_earned`, `offspring_players_activated`, and `offspring_slots_unfilled_due_to_capacity` separately. An unfilled slot **does not** become an imaginary hunter, is **not** silently removed from the tally, and does **not** contribute to future catches. Do not mislabel the unfilled count as a living predator population.

**Important unsolved teaching consequence:** In a room with six students and three starting lizards, the maximum number of active predators is six. This can blunt or prevent the pronounced predator boom/crash from the original whole-class game. Recording unfilled slots fixes accounting honesty, **not** the ecological demonstration. Before Stage 3 implementation, run simple capped-versus-uncapped spreadsheet/scripting scenarios using plausible catch counts; then classroom-test Stage 3 using **two larger rooms (about 12–13 students each)** or, if necessary, **one class-wide room**. Keep room size teacher-configurable rather than inventing NPC predator AI. A hypothetical “uncapped counterfactual population” must not be graphed as if its future catches/starvation were known. If the desired classroom pattern cannot emerge reliably, record that as a model limitation and bring the room-design decision back for approval.

**Open after this review:** Exact Stage 3 room-size default and whether a non-player *abstract population* should ever be modeled. That is a separately scoped future decision, **not** authorized by v0.2.

**Classroom safeguard:** Parent chooses from available classmates, with an invitation timeout and teacher override/assignment. Show the teacher who has not yet been active; teacher may select starting lizards or use a simple random pick. There is **no automatic matching algorithm** in v1. Students may decline first-person play and remain in a meaningful observer/data role. Test for unchosen students during pilot rather than assuming a software queue solves classroom relationships.

## 6. Environment, visual design, and camouflage

- Begin with **one compact, reusable habitat**, not several biomes. It should contain patches of differently colored surfaces, vegetation, and varied light levels.
- Bugs must be **visible and reachable from some angle**, without opening containers, mirroring the original hiding rule. Hunting should reward observation and movement rather than pixel hunting or exploitative clipping.
- Bug color and habitat color are meaningful inputs to detectability, without guaranteeing that a given hue is equally distinguishable on every physical display.
- Avoid heavy bloom, high-cost lighting, complex shadows, and photorealistic assets. Favor readable silhouettes, color/contrast control, and efficient geometry/materials.
- In the first prototype, bugs may be static or move only minimally. Do not build a full insect behavior simulation merely to make the world feel alive.
- Displayed insects should represent the simulation consistently. **Do not silently cap, discard, or make unrendered insects collectible** when prey reproduction creates large populations. First benchmark individually collectible static/instanced bugs at increasing counts on Chromebooks. For the earliest classroom pilot, use valid starting conditions that remain within the measured rendering/interaction budget. If a classroom run would exceed it, flag the capacity problem visibly rather than corrupting counts; a labeled cluster-of-ten scheme inspired by the source paper game is a *possible tested extension*, not an assumed mechanic.
- Because camouflage is core gameplay, test intended visibility ordering on differently calibrated school Chromebook displays; do not assume equal RGB values create equal perceptual difficulty.

## 7. Vision traits and mutation

### Stage 4 minimum

- Normal lizards struggle in a low-light forest-floor environment.
- At the **first offspring-producing event of Stage 4**, exactly **one** member of that offspring cohort is designated the mutant (automatically or by teacher choice). This is a deliberately scripted classroom-model event, **not** an assertion that a useful mutation arises whenever needed.
- The mutant receives a **modeled low-light detection advantage** in the dim habitat. Only descendants of that mutant lineage inherit the trait under this deliberately simplified inheritance rule. Offspring of non-mutant lizards remain non-mutant.
- If no offspring is earned in time for the Stage 4 lesson, a **teacher-initiated demonstration fallback** can introduce or designate one mutant. Label it as an intervention, separate from the ordinary earned-offspring arithmetic; default suggestion is to offer this after round 2. A forced demonstration must not be concealed in the research data.
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

- Start/stop/pause hunt round; advance to next round.
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
- Clients send inputs/actions, not trusted statements such as 'I caught 10 bugs'. Server validates **range, coarse geometric reachability/line-of-sight where practical, capture timing, bug availability, and unique ownership**. Its validation does **not** claim to know what the human player perceived through a client-side vision filter. The first valid competing attempt wins; no advanced anti-cheat or server-side visual-perception simulation in v1.
- On disconnect, the server retains accepted captures and authoritative ecological state. A resumed session uses an **ephemeral room rejoin token** rather than a persistent student account; input stops while disconnected. The player may resume the same session if the room is still valid. If the player does not return before the next round, the teacher can release or reassign the seat. A disconnect does not retroactively cancel valid captures or secretly create/kill lizards outside the normal rules.
- A room's spectators should not receive exact hidden-prey coordinates if that could enable coaching; public counts and round results can be shared.
- Networking uses **WSS** and a public HTTPS host. The school firewall may still block the endpoint; test on campus.
- Avoid full-state broadcasts per frame. Replicate moving lizards at a modest frequency with smoothing; replicate static bug information and discrete capture/round events as needed. Optimize large prey counts with spatial organization/instancing and profiling rather than assuming hundreds of synchronized physics agents are viable. **Do not make non-rendered prey secretly available for capture.**
- Prefer nickname + temporary session code, without student accounts or collected personally identifying information in the first version. Teacher owns room access and removal controls. Keep data retention minimal and defined before deployment.
- No text chat, voice chat, public matchmaking, or arbitrary student-generated content in the baseline.

**Godot 4.7.2 baseline — advantages, not new requirements:**

- The 4.7 shader editor's inline previews can speed iteration on color-perception, glare, and low-light visual experiments. **They do not guarantee** equivalent results or acceptable frame rates in browser exports.
- Nearest-neighbor filtering for 3D resolution scaling is available if low-resolution rendering needs a deliberately crisp visual style. Lowering rendering resolution is an existing optimization technique, not a new 4.7 speed boost on its own. Test whether its sharper pixel edges help or hinder insect camouflage.
- `Control` offset transforms may simplify animation of offspring invitations and teacher/HUD feedback; simple unanimated UI remains the baseline.
- Godot 4.7.2 includes a `MultiplayerSpawner` replication fix involving removal of spawned nodes; this supports selecting a current maintenance release but does not replace a test of tag-in, death, disconnect, and rejoin flows.
- The new native HDR output does **not** apply to the target HTML5 Compatibility renderer. Do not propose HDR screens, high-end Vulkan lighting, or new `AreaLight3D` features as required solutions to camouflage/vision gameplay. The scientific priority is reliable relative color, contrast, and brightness under ordinary Chromebook displays.
- The 4.7 browser client still uses WebGL 2 / Compatibility, not Forward+ or Mobile, and lacks raw UDP/ENet access. It must use browser-supported networking (planned WSS). The default single-threaded export avoids special cross-origin-isolation requirements at the cost of available CPU parallelism.
- **Browser foreground behavior:** Godot notes that processing pauses when a browser *tab* becomes inactive, potentially disconnecting a multiplayer client. Design the observer mode inside the game and test classroom tab switching, reconnect, and teacher projection. The headless server remains authoritative.

**Compatibility check:** Confirm the specific Godot 4.7 maintenance release, Chromebook hardware, color differences across screens, hosting requirements, and school-network behavior in a real exported prototype. Do not assume desktop editor previews establish Chromebook feasibility.

**Primary references:** [Godot 4.7 release notes](https://godotengine.org/releases/4.7/); [Godot 4.7.2 maintenance notes](https://godotengine.org/article/maintenance-release-godot-4-7-2/); [Godot 4.7 web export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

## 10. Progressive development plan

### Technical spike — **must pass before a full implementation commitment**

**Gate 0: campus connectivity and hardware inventory, before polishing any 3D game.** Identify the oldest and most common target managed Chromebooks; verify HTTPS asset loading, WSS connectivity to the intended host on school Wi-Fi, WebGL 2 availability, first-person mouse/trackpad pointer lock, and permissions. A game that works only from the developer's desktop does **not** pass.

**Gate 1: minimum running vertical slice.** One small Godot HTML5-exported first-person habitat with individually collectible bugs, two isolated rooms, a headless WSS server, teacher-started/stopped hunts, authoritative single-owner captures, and a minimal readable round summary. Start with one room, then add the second; do not polish a four-room dashboard before basic gameplay works.

**Gate 2: Chromebook pressure test.** Test a controlled ladder of static/instanced bug counts (e.g., 50, 100, 150, 300), sustained hunts on the slowest device, client load time when a class loads simultaneously, responsiveness, temperature-related slowdown, and multiple display colors/brightness settings. Run at least one inexpensive low-light/contrast effect. Test paused/hidden tabs, refresh, transient Wi-Fi loss, pointer-lock recovery, and server-owned state survival. Use a two-room 12–15-student pilot before attempting the ~25-client class target; include simultaneous hunting, not just idle sockets.

**Go/no-go:** No full four-stage implementation until students can reliably join without installation and hunt on school Chromebooks at usable responsiveness and WSS remains connected/recoverable. Target approximately 30 fps when possible; do not freeze a single frame-rate/latency figure as scientific correctness. Define measurable local thresholds **after** inspecting target models. If Godot fails, investigate a leaner browser implementation/PlayCanvas as a separate decision; do not build both engines in parallel.

**Paper/simulation gate before Stage 3:** Run capped vs uncapped population arithmetic scenarios and confirm whether 6–7-player rooms can demonstrate the Stage 3 question. If not, pilot two larger rooms or one class-wide room, without implementing NPC predators or fake counterfactual forecasts.

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
4. At least one offspring is successfully tagged in to a real student, who joins **only** at the next round with the correct parent/lineage data; rejected/expired invites and overflow slots are visible to teacher.
5. The prey and predator graph matches server state **and the source paper-organizer convention**, with separately labeled next-round start totals; normal and mutant lizards are distinguished in Stage 4.
6. Camouflage differences are observable, while accessibility alternatives remain available.
7. Teacher can stop or reset a room without affecting unrelated groups.
8. Students can use a paper organizer for prediction/outcome/evidence, explain at least one cause-and-effect pattern and one limitation of the model, and (Stage 3) compare the classroom graph to lynx–snowshoe hare data; classroom usability must be evaluated directly.

9. Stage 1 terminates on its defined threshold; Stages 2–4 terminate cleanly at zero prey/zero surviving lizards, with graph retained and no automatic migration NPCs.
10. Stage 3 is shown to support the intended population lesson with the **tested** room-size policy, or the lesson limitation is explicitly documented before classroom deployment.

Numeric performance budgets (download size, frame rate, latency, reconnection allowance) should be set **after** sampling actual school devices and network conditions. A reasonable preliminary aspiration is a smooth-feeling 30 fps on the weakest approved Chromebook, but this is a test target, not a promise. The earliest pilot may use 12–15 connected students in two rooms, then expand to ~25 only after the underlying design passes.

## 12. Known risks and decisions still open

| Issue | Why it matters | Status |
|---|---|---|
| **Browser performance** | Godot web renderer and shader effects may struggle on older Chromebooks. | **Prototype gate.** |
| **School network / WSS** | Browser can load the page but fail to connect to hosted multiplayer. | **Prototype gate.** |
| **Offspring beyond available students** | Slots are counted honestly, but small rooms may prevent the source lesson’s dramatic predator boom. | **Provisional slot policy chosen; Stage 3 room-size/science test remains a blocker.** |
| **Turn length and observation time** | Very short hunts reduce waiting but may make inquiry rushed. | **45 s provisional, 30–60 s adjustable; test.** |
| **Who begins as a lizard** | Fairness and participation across groups. | **Teacher-select / optional random; teacher sees never-active students; no algorithm.** |
| **Exact color-vision effects** | Scientific legitimacy, shader cost, accessibility. | **Stage 4 first implements low-light difference only.** |
| **What counts as a bug in huge populations** | Insect counts may exceed practical rendered objects. | **Pilot limited by measured individually collectible bug budget; any clusters require separate design approval.** |
| **Unexpected population outcome** | A crash/cycle/mutant takeover is not guaranteed. | **Accept variability and make it discussable.** |
| **Room comparison** | Controlled vs variable settings changes what comparisons establish. | **Same conditions by default; stage-specific room size allowed; cross-room analytics deferred.** |
| **Version and engine fallback** | Need hardware evidence before committing deeply. | **Godot 4.7.2 stable is the provisional build baseline; PlayCanvas remains a test-driven fallback.** |

## 13. Explicit non-goals for v0.2 / first playable version

- Photorealism, realistic animal anatomy, elaborate animation rigs, or an open-world map.
- Building a full ecosystem with insects independently feeding, mating, competing, or navigating complex terrain.
- Deep genetics, Mendelian pedigrees, multiple-allele systems, sexual selection, or numerous mutation categories.
- Competitive leaderboards, achievements, paid cosmetics, progression currencies, NPC dialogue, or narrative campaigns.
- User accounts, cloud profiles, saved personal identities, social networking, text/voice chat.
- Full learning-management-system integration, formal grading, or adaptive assessment.
- Mobile-phone gameplay and console ports.
- A second biome or day/night cycle *as a core requirement*. A controlled dim-light scenario for Stage 4 is enough.
- A mandatory 16+ **active-lizard** game. The capacity target refers to classroom connectivity across rooms.
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

The original 2018 classroom sequence supplies the stage names and incremental rules, basic thresholds (5 bugs to survive, 2 baby bugs per **uncaught bug**, 5 additional bugs per offspring), typical 30–60-second rounds, paper-organizer data timing, Stage 3 lynx–snowshoe hare comparison, population-charting pedagogy, and rainforest low-light mutant scenario. The **browser, first-person 3D, multiple rooms, teacher dashboard, offspring invitations, visual filters, and network architecture** are proposed digital-design adaptations.

For scientific clarity: the source's visual demonstration (wearing sunglasses or not) should not be translated into an unsupported claim that a particular real-world eye mutation has a known tradeoff. Likewise, this game models one-parent 'births' to allocate classroom roles; it does not model actual lizard reproductive biology.

---

### Change log

- **0.2 (2026-11-09):** Synthesized four **distinct** reviews (Kimi, Manus, Qwen, corrected Mistral) and checked pivotal points against the original lesson. Corrected original-style graph timing; restored learning targets, paper organizers, real-data comparison, and stage endpoints; specified one-mutant trigger, capacity accounting, basic rejoin/capture behavior, and Chromebook gates. Identified—rather than concealed—the **small-room Stage 3 predator-boom tradeoff**. Kept speculative vision variants, NPCs, digital prediction systems, and complex data graphs out of v1. Decision-by-decision rationale: `Bugs-and-Lizards-Review-Synthesis.md`.
- **0.1 (2026-11-09):** Created first review baseline from the original lesson and the initial design conversation. Distinguishes agreed requirements, working assumptions, unresolved gates, and deferred enhancements. Updated the technical baseline to **Godot 4.7.2 stable** and documented actual browser-rendering limits and 4.7 features without adding gameplay scope. No implementation decisions are final until technical spike and scope review.
