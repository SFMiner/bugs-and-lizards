# Bugs & Lizards — Game Design Document

**Version:** 0.1 — Initial review baseline  
**Date:** 2026-11-09  
**Status:** Concept/design baseline; not an implementation specification  
**Primary reference:** *Science Lesson Sequence: The Bugs & Lizards Game* (Sean Miner, 2018)  
**Audience:** Designers, educators, developers, and independent AI reviewers

> **Version 0.1 principle:** Preserve the simplicity and progressive scientific logic of the classroom game. Make the existing lesson work in a browser before adding new biology, game systems, or narrative.

## 1. Elevator pitch

*Bugs & Lizards* is a short-session, first-person, cooperative-classroom/multiplayer ecology game in which students play insect-eating lizards, hunt camouflaged bugs, survive, reproduce, and—in later stages—experience heritable sensory mutations. Several small groups play in **separate ecosystems** at once. A teacher controls the stage and pace; each ecosystem generates population data that students use to make predictions and explain biological phenomena.

The four initial stages are digital adaptations of four consecutive classroom games. They are not four separate engines or campaigns: the same core habitat and round loop gain one new biological rule at a time.

## 2. Design goals and constraints

### Agreed requirements

- **Browser-first; no installation on student devices.** Managed school Chromebooks are the primary target. Students launch via a classroom URL in Chrome.
- **First-person lizard gameplay.** Players experience a lizard's view of the habitat, including differences in vision.
- **Small, simultaneous ecosystems.** A class of roughly 25 may be split into two or more independent groups; an illustrative arrangement is four groups of six or seven. Group size and count must be configurable.
- **Tag-in offspring.** When a lizard earns offspring, its player can invite an available classmate in the same room to become that offspring. This is a central social mechanic, not an incidental UI convenience.
- **Ecological rounds.** Predation, survival, prey reproduction, predator reproduction, and inheritance are measurable, teacher-paced events.
- **Camouflage and color matter.** A stylized aesthetic is appropriate; accurate-enough color relationships, contrast, lighting, and per-player perception are important.
- **Scientific truth over flashy realism.** Simplifications are permitted but must be identified as model assumptions rather than falsely presented as real biological mechanisms.
- **Teacher usable within a class period.** Setup, rounds, prediction, visualization, and discussion must not require a lengthy tutorial or login process.

### Working assumptions, to validate

- Target **Godot 4.7.2 stable (GDScript)** with the **Compatibility / WebGL 2** renderer, the default single-threaded HTML5 web export, and a browser-based player client. Use the latest tested 4.7 maintenance patch if one becomes available. Keep PlayCanvas as a browser-first fallback if school-device tests fail.
- Use a **headless authoritative server** with **secure WebSockets (WSS)**, hosting multiple room instances. This is an architectural hypothesis pending prototype tests, not a guarantee of performance on a particular school network.
- Start each ecosystem with **two or three active lizards**; other connected students start in an observer/available-offspring state. Multiple rooms reduce waiting time.
- Plan for approximately **25 concurrent connected browsers across all rooms**, with a small margin; stress-test rather than assuming all Chromebooks perform alike.
- Stylized low-poly 3D habitat; simple silhouettes and readable bugs rather than photorealism.

## 3. Core player experience

1. **Join:** Students open the URL, enter a session/room code and an ephemeral nickname, and enter their assigned ecosystem.
2. **Observe/predict:** Teacher briefly presents the current rule and asks what students expect to happen.
3. **Hunt:** Active lizards explore a compact habitat and collect visible/reachable insect targets within a timed round. Non-active students can observe and record predictions/data; no spectator should be able to reveal hidden prey locations to active players through game UI.
4. **Resolve:** At round end, the server counts captured insects and determines lizard survival, changes to prey population, and—when enabled—offspring eligibility.
5. **Tag in:** Eligible parents select available classmates to play offspring, inheriting modeled traits in Stage 4.
6. **Study:** Population counts and a simple graph update; teacher can pause for discussion before initiating the next round.
7. **Repeat/debrief:** The next round starts only when the teacher advances. Stage concludes after a small number of rounds or an ecological endpoint.

**Core feel:** Brief bursts of active searching alternate with fast, legible moments of decision, observation, and explanation. The game should not become a lengthy survival RPG.

## 4. Four-stage progression: original lesson rules

| Stage | Name | Newly introduced rule | Main scientific idea |
|---|---|---|---|
| 1 | **Bugs & Lizards!** | Each lizard must capture **at least 5 bugs** in a round or starve. Captures reduce the prey count. | Predation, competition, resources, data collection. |
| 2 | **Baby Bugs!** | **Each surviving bug generates two new bugs** at the end of a round. That means each survivor contributes itself **plus two offspring** (three total). | Prey reproduction, population growth, improved models. |
| 3 | **Baby Lizards!** | For every **5 bugs caught beyond the 5 needed for survival**, a lizard can generate one new lizard and select another student to play it. | Predator reproduction, resource limits, boom-and-crash dynamics, interacting populations. |
| 4 | **Mutant Lizards!** | In a dim, canopy-covered habitat, introduce one offspring with a heritable low-light vision advantage; offspring inherit that trait. | Mutation, inheritance, differential survival/reproduction, natural selection. |

All later stages retain earlier applicable rules unless the teacher deliberately chooses a demonstration variant. The original lesson typically uses 30–60 second hunts and about four rounds, but these are **defaults to test**, not forced limits.

### Essential arithmetic

For each active lizard with `c` captures in a round:

- `survives = (c >= 5)`.
- In Stages 3–4, if it survives: `earned_offspring = floor((c - 5) / 5)`.
- Examples: 4 captures → starves, 0 offspring; 5 → survives, 0; 10 → survives, 1; 15 → survives, 2.

For the prey population in Stages 2–4:

- `survivors = prey_at_round_start - total_successful_captures`.
- `prey_for_next_round = survivors * 3`, because each survivor remains and produces two more.

These are **deliberately simplified model equations**. They do not describe realistic energy budgets, generation times, mating, juvenile survival, or limited prey resources.

**Round resolution order (proposed):** close captures → count surviving bugs → determine lizard starvation/offspring eligibility → perform births/tag-ins → reproduce surviving bugs → record the resulting populations → release new round. The numbers shown on the graph must clearly indicate whether a point is *start-of-round* or *post-resolution*; do not mix them.

## 5. Rooms, players, and offspring

### Ecosystems

- Each room has a **separate prey population, active-lizard roster, lighting/vegetation parameters, round clock, and population history**.
- The teacher sees an overview of all rooms. The game should not require a different server computer for every room.
- A session can run either several small rooms or one larger room, if testing supports it.
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

**Important science boundary:** One player choosing one 'offspring' is a participation metaphor, *not* an assertion that real lizards reproduce asexually. The original lesson purposely abstracts mating and life stages. Explain that clearly in teacher notes.

**Unresolved design gate:** In Stage 3, what happens when births exceed available classmates? Do we (A) model non-player lizards that hunt, (B) limit active offspring and clearly acknowledge a changed reproduction rule, or (C) use another bounded/representative simulation scheme? The choice materially affects predator-prey dynamics. **Do not silently cap births** or add autonomous AI predators until this is reviewed.

**Classroom safeguard:** Nobody should be left unchosen for an entire lesson because of popularity dynamics. Teacher override, invitation expiration, and a simple fairness mechanism are needed; details remain open.

## 6. Environment, visual design, and camouflage

- Begin with **one compact, reusable habitat**, not several biomes. It should contain patches of differently colored surfaces, vegetation, and varied light levels.
- Bugs must be **visible and reachable from some angle**, without opening containers, mirroring the original hiding rule. Hunting should reward observation and movement rather than pixel hunting or exploitative clipping.
- Bug color and habitat color are meaningful inputs to detectability, without guaranteeing that a given hue is equally distinguishable on every physical display.
- Avoid heavy bloom, high-cost lighting, complex shadows, and photorealistic assets. Favor readable silhouettes, color/contrast control, and efficient geometry/materials.
- In the first prototype, bugs may be static or move only minimally. Do not build a full insect behavior simulation merely to make the world feel alive.
- Displayed insects should represent the simulation consistently. If population grows too large to depict each individual, any visual aggregation must be **explicitly communicated to the player/teacher**.

## 7. Vision traits and mutation

### Stage 4 minimum

- Normal lizards struggle in a low-light forest-floor environment.
- One new offspring receives a **heritable low-light sensitivity trait**, making bug detection easier in that environment.
- Descendants inherit the modeled trait under the original lesson's simplified rule; the population record distinguishes trait-bearing and non-trait-bearing lizards.
- An environmental change (e.g., restored sunlight) may be used as a **teacher-led discussion or controlled extension**, but is not required for the first implementation.

### Candidate later traits — *not automatically in v1*

- Weak low-light sensitivity / night vision difficulties.
- Greater sensitivity to bright light or glare.
- Altered color discrimination, including selective red–green or blue–yellow differences where feasible.
- Heightened responsiveness to motion.

**Design rule:** Separate world state (actual illumination, prey reflectance/appearance, camouflage) from an individual's *perceived* world (client-side visual transformation). A player's vision should not change the underlying shared prey population. Changes in phenotype must affect what can be noticed or detected, **not secretly rewrite locations or spawn more bugs for one player**.

**Science caution:** Screen filters are illustrative approximations, not medically accurate representations of human color-vision deficiencies or complete accounts of reptile visual biology. Color vision is not one scalar, and extra light sensitivity does not automatically imply photosensitivity. Every tradeoff must be explicitly chosen and labeled as a model assumption. Selection is contingent, not inevitable: an advantageous mutation may fail to spread by chance in a small population.

**Accessibility constraint:** Do not force students with visual differences into an inaccessible experience. Provide equivalent, selectable ways to engage with the scientific contrast (e.g., labeled demo view or complementary non-color cues). Keep actual student accessibility settings distinct from the lizard's modeled phenotype.

## 8. Teaching and feedback loop

A complete stage should support the following instructional arc:

- **Question:** What happened last stage, and what was missing from the model?
- **Prediction:** What should happen after adding the next rule?
- **Evidence:** What happened to prey, lizards, and (later) mutants after each round?
- **Explanation:** What mechanism could account for the observed pattern?
- **Model reflection:** In what ways does this simplify the biology, and what does it miss?

### Minimum teacher controls

- Start/stop/pause hunt round; advance to next round.
- Set initial bug count, starting lizard count, number and membership of rooms, and hunt duration.
- Choose the current stage and apply stage-appropriate rules.
- See each room's current prey count, normal lizard count, mutant lizard count where relevant, and simple historical graphs.
- Override an unsuitable offspring tag-in or reassign a player.
- Reset/replay a room or stage. Exporting graphs/data is desirable but not a prerequisite for the initial playable slice.

**Pedagogical guardrail:** Do not rig each simulation to produce a predicted outcome. The original in-person lesson allows teacher adjustments to improve the illustration; the digital version can expose **visible, teacher-controlled scenario settings** and discuss surprising outcomes instead of secretly manufacturing results. Predator-prey cycles are plausible, not guaranteed in a short stochastic run. Avoid describing oscillation or population 'equilibrium' as an automatic consequence of the simple equations.

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
- Clients send inputs/actions, not trusted statements such as 'I caught 10 bugs'. Server validates distance, visibility/reachability rules, capture timing, and that each bug is only caught once.
- A room's spectators should not receive exact hidden-prey coordinates if that could enable coaching; public counts and round results can be shared.
- Networking uses **WSS** and a public HTTPS host. The school firewall may still block the endpoint; test on campus.
- Avoid full-state broadcasts per frame. Replicate moving lizards at a modest frequency with smoothing; replicate static bug information and discrete capture/round events as needed. Optimize large prey counts with spatial organization/instancing and profiling rather than assuming hundreds of synchronized physics agents are viable.
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

- One small web-exported 3D map, mouse/keyboard first-person lizard controls, and a few static collectible bugs.
- One external server using WSS; two separately isolated rooms; several browsers connected.
- A teacher-triggered round timer, server-validated captures, and shared post-round population counts.
- One inexpensive visual-perception effect using actual target Chromebooks.
- Test page load, frame rate, browser focus/mouse capture, inactive-tab/reconnect behavior, visual consistency on differently calibrated Chromebook displays, and whether the school allows HTTPS/WSS to the host.

### Minimum playable instructional build

- Stage 1 complete with two or more rooms, teacher pacing, survival rule, and graphs.
- Stage 2 adds bug reproduction and accurate tracking of larger populations.
- Stage 3 adds lizard reproduction and tag-in. **Resolve the player-capacity design gate before implementing Stage 3.**
- Stage 4 adds low-light conditions and one inherited visual mutation, with a separately tracked trait-bearing population.

### Later, only if evidence warrants

- Additional visual variants and changes in environmental conditions.
- More extensive teacher exports/reports.
- Adjustable comparisons between room conditions.
- Richer terrain/bug behavior, additional prey species, procedural worlds, or broader genetics.

## 11. Success criteria and tests

A successful early classroom pilot should demonstrate:

1. Students join with **no device installation** on managed Chromebooks; teacher can get two or more groups into independent rooms reliably.
2. A class-size set of connected clients (target ~25) is stable, with acceptable input responsiveness and readable visuals on the **slowest relevant Chromebook**, not only the developer's computer.
3. No two players can collect the same bug; surviving/offspring counts match the published equations; no round's data silently disappears on disconnect.
4. At least one offspring is successfully tagged in to a real student, who joins at the next round with the correct parent/lineage data.
5. The prey and predator graph matches the server's state and distinguishes normal and mutant lizards in Stage 4.
6. Camouflage differences are observable, while accessibility alternatives remain available.
7. Teacher can stop or reset a room without affecting unrelated groups.
8. Students can explain at least one cause-and-effect pattern and one limitation of the model after play; classroom usability should be evaluated directly, not inferred from mechanical test success.

Numeric performance budgets (download size, frame rate, latency, reconnection allowance) should be set **after** sampling actual school devices and network conditions. A reasonable preliminary aspiration is a smooth-feeling 30 fps on the weakest approved Chromebook, but this is a test target, not a promise.

## 12. Known risks and decisions still open

| Issue | Why it matters | Status |
|---|---|---|
| **Browser performance** | Godot web renderer and shader effects may struggle on older Chromebooks. | **Prototype gate.** |
| **School network / WSS** | Browser can load the page but fail to connect to hosted multiplayer. | **Prototype gate.** |
| **Offspring beyond available students** | Artificially capping births changes population dynamics; full NPC simulation increases scope. | **Open; resolve before Stage 3.** |
| **Turn length and observation time** | Very short hunts reduce waiting but may make inquiry rushed. | **Test in classroom.** |
| **Who begins as a lizard** | Fairness and participation across groups. | **Teacher-configurable; rotation scheme open.** |
| **Exact color-vision effects** | Scientific legitimacy, shader cost, accessibility. | **Stage 4 first implements low-light difference only.** |
| **What counts as a bug in huge populations** | Insect counts may exceed practical rendered objects. | **Performance/design test.** |
| **Unexpected population outcome** | A crash/cycle/mutant takeover is not guaranteed. | **Accept variability and make it discussable.** |
| **Room comparison** | Controlled vs variable settings changes what comparisons establish. | **Same conditions by default.** |
| **Version and engine fallback** | Need hardware evidence before committing deeply. | **Godot 4.7.2 stable is the provisional build baseline; PlayCanvas remains a test-driven fallback.** |

## 13. Explicit non-goals for v0.1 / first playable version

- Photorealism, realistic animal anatomy, elaborate animation rigs, or an open-world map.
- Building a full ecosystem with insects independently feeding, mating, competing, or navigating complex terrain.
- Deep genetics, Mendelian pedigrees, multiple-allele systems, sexual selection, or numerous mutation categories.
- Competitive leaderboards, achievements, paid cosmetics, progression currencies, NPC dialogue, or narrative campaigns.
- User accounts, cloud profiles, saved personal identities, social networking, text/voice chat.
- Full learning-management-system integration, formal grading, or adaptive assessment.
- Mobile-phone gameplay and console ports.
- A second biome or day/night cycle *as a core requirement*. A controlled dim-light scenario for Stage 4 is enough.
- A mandatory 16+ **active-lizard** game. The capacity target refers to classroom connectivity across rooms.

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

The original 2018 classroom sequence supplies the stage names and incremental rules, basic thresholds (5 bugs to survive, 2 baby bugs per survivor, 5 additional bugs per offspring), typical 30–60-second rounds, population-charting pedagogy, and rainforest low-light mutant scenario. The **browser, first-person 3D, multiple rooms, teacher dashboard, offspring invitations, visual filters, and network architecture** are proposed digital-design adaptations.

For scientific clarity: the source's visual demonstration (wearing sunglasses or not) should not be translated into an unsupported claim that a particular real-world eye mutation has a known tradeoff. Likewise, this game models one-parent 'births' to allocate classroom roles; it does not model actual lizard reproductive biology.

---

### Change log

- **0.1 (2026-11-09):** Created first review baseline from the original lesson and the initial design conversation. Distinguishes agreed requirements, working assumptions, unresolved gates, and deferred enhancements. Updated the technical baseline to **Godot 4.7.2 stable** and documented actual browser-rendering limits and 4.7 features without adding gameplay scope. No implementation decisions are final until technical spike and scope review.
