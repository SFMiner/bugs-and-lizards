## 1. Overall assessment

The GDD is unusually disciplined: it keeps the four one-rule stages, preserves the original arithmetic, separates shared world state from perceived vision, and treats the classroom offspring metaphor as a model rather than literal biology. Its strongest choices are teacher pacing, small independent rooms, tag-in as social participation, and explicit non-goals.

The main vulnerability is that several lesson-critical edge cases are unresolved: Stage 3 births can exceed available classmates; Stage 4 mutant appearance is not guaranteed; disconnect/reconnect and capture authority are under-specified; and the Godot/Chromebook/WSS stack is still an assumption. These are not polish issues; they can break a 40-minute class. The document also risks over-relying on visual darkness for Stage 4, which may be inaccessible and hard to calibrate across school displays. The right next step is not more content but a narrow spike: two rooms, Stages 1–2, real Chromebooks, real school network, and explicit rules for offspring capacity and mutant introduction.

---

## 2. Scientific / instructional corrections

I did not find a mathematical error in the preserved Stage 1–3 arithmetic itself. The problems below are missing boundary conditions, instructional framing, or missing teacher controls that can change the lesson if left unresolved.

### 2.1 Stage 4 mutant introduction is underspecified

> “One new offspring receives a heritable low-light sensitivity trait, making bug detection easier in that environment.”

**Problem:** This assumes that an offspring is produced early enough for the mutant to appear. In a short classroom run, lizards may starve before earning offspring, or no lizard may earn enough extra bugs. If that happens, Stage 4 may never introduce the mutant, and the lesson fails. The original lesson intends that “at some point, a mutant lizard is born,” but the digital version needs a deterministic fallback.

**Correction needed:** Add a teacher-visible Stage 4 introduction rule: first eligible offspring becomes mutant; if no offspring is earned by a configured round, the teacher can introduce/assign one mutant. This is not new biology; it is a reliable way to stage the original lesson.

---

### 2.2 Stage 3 offspring rule lacks a participant-capacity boundary

> “For every 5 bugs caught beyond the 5 needed for survival, a lizard can generate one new lizard and select another student to play it.”

**Problem:** The equation can generate more offspring slots than there are available classmates. If the system silently caps births, it changes the population model without telling the teacher. If it adds autonomous NPC lizards, it adds a new ecological agent not present in the original game. Both are instructional problems unless explicitly labeled.

**Correction needed:** State that earned offspring slots are still calculated using the original equation, but active player-lizards are limited by available classmates. Unfilled slots must be logged as a model limitation, not silently ignored or replaced by hidden AI predators.

---

### 2.3 Teacher controls are insufficient for Stage 4

> “Choose the current stage and apply stage-appropriate rules.”

**Problem:** Stage 4’s “stage-appropriate rules” include low-light environment, mutant appearance, mutant tracking, and possibly teacher fallback introduction. The current minimum teacher controls do not include those Stage 4-specific controls.

**Correction needed:** Add teacher controls for Stage 4: set environment dimming level, set mutant introduction round or force mutant introduction, view normal/mutant counts separately, and reset Stage 4 lineage without affecting other rooms.

---

### 2.4 Accessibility constraint is a principle but not a minimum implementation

> “Accessibility constraint: Do not force students with visual differences into an inaccessible experience. Provide equivalent, selectable ways to engage with the scientific contrast (e.g., labeled demo view or complementary non-color cues). Keep actual student accessibility settings distinct from the lizard's modeled phenotype.”

**Problem:** The principle is correct, but without a concrete minimum, Stage 4’s darkened habitat may exclude students with low vision, contrast sensitivity, or motion/first-person discomfort. It may also create inequitable gameplay if one student’s display is simply darker due to hardware or settings.

**Correction needed:** Define a minimum accessibility fallback: teacher projection/demo view, optional high-contrast observer mode, and an observer/data role that still teaches the scientific contrast without forcing an inaccessible player into active hunting.

---

### 2.5 The offspring metaphor needs player-facing clarification

> “Important science boundary: One player choosing one 'offspring' is a participation metaphor, not an assertion that real lizards reproduce asexually.”

**Problem:** This caveat exists in the design document, but if the game UI simply says “parent,” “offspring,” or “birth,” students may still infer a false biological mechanism. The original lesson uses this as a participation abstraction, not a reproductive-biology model.

**Correction needed:** Teacher materials and, where practical, UI labels should make the metaphor explicit: “recruited offspring (classroom player)” or “new player-lizard assigned from available classmates.” This is a clarification, not a new mechanic.

---

## 3. Technical and classroom risks

Ranked by combined probability and impact. “Actual Chromebooks” means the managed school devices, not the developer machine.

| Rank | Risk                                                                                | Probability | Impact      | What must be tested on actual Chromebooks / school network                                                                                                                                 |
| ---- | ----------------------------------------------------------------------------------- | -----------:| -----------:| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1    | Godot web export performance on low-end managed Chromebooks                         | High        | High        | Load time, frame rate with 50/100/150 visible bugs, first-person movement, shader/filter cost, input responsiveness. Test on the slowest approved Chromebook, not just a developer laptop. |
| 2    | School firewall/proxy blocks or interferes with WSS                                 | Medium-High | High        | Connect from managed Chromebooks on the actual school network to WSS over HTTPS port. Test reconnect after tab refresh, sleep, and brief network drop.                                     |
| 3    | Stage 3 births exceed available classmates, causing silent caps or social exclusion | High        | Medium-High | Simulate a 6-student room where multiple lizards earn offspring. Verify unfilled slots are logged, teacher override works, and no student is permanently excluded.                         |
| 4    | Bug population scaling exceeds rendering or interaction budget                      | Medium      | High        | Measure maximum stable rendered bug count per room. Test prey reproduction over three rounds with expected counts. Decide whether pilot configurations must stay below that count.         |
| 5    | Capture race conditions / duplicate captures / disconnect during capture            | Medium      | High        | Automated or scripted test: two clients attempt to collect the same bug simultaneously. Verify exactly one capture. Disconnect a client mid-round and verify validated captures persist.   |
| 6    | Browser tab inactivity, refresh, or mouse-capture loss disconnects players          | High        | Medium      | Test tab switching, Chromebook lid close/sleep, accidental Esc from pointer lock, and refresh. Verify ephemeral session rejoin and correct role state.                                     |
| 7    | First-person controls are hard for some students or cause motion discomfort         | Medium-High | Medium-High | Test WASD/arrow keys, trackpad, pointer lock, keyboard ghosting, and camera sensitivity. Provide observer/data role if active play is uncomfortable.                                       |
| 8    | Low-light Stage 4 is inaccessible or inconsistent across displays                   | Medium      | High        | Test on multiple Chromebook displays: brightness, contrast, color shift, and whether normal/mutant difference remains legible. Test teacher demo/high-contrast fallback.                   |
| 9    | Headless Godot authoritative server is heavier or less stable than assumed          | Medium      | High        | Run the server with two rooms and 12 connected clients. Measure CPU, memory, room isolation, and round-event latency. This is server-side, but affects classroom reliability.              |
| 10   | Teacher setup takes too long for one class period                                   | Medium      | Medium      | Have a teacher create two rooms, assign/join students, start Stage 1, pause, reset one room, and show graphs within a realistic class setup window.                                        |

---

## 4. Top five proposed changes

### Change 1: Add an explicit Stage 3 participant-capacity rule for offspring

**GDD section affected:** Section 5, “Rooms, players, and offspring”; also Section 12, “Known risks and decisions still open.”

**Proposed replacement/addition:**

> Active predator population is limited by the number of connected, available classmates in the room. Earned offspring slots are still calculated using the original rule: `earned_offspring = floor((c - 5) / 5)` for each surviving lizard. If earned slots exceed available classmates, the extra slots are recorded as `unfilled_offspring_due_to_participant_limit`. They do not become autonomous NPC lizards, and they are not silently discarded. The teacher dashboard shows available classmates, earned slots, filled slots, and unfilled slots. Invitations expire at the start of the next round unless accepted; the teacher may assign an available player instead.

**Why:** Without this rule, Stage 3 either silently changes the population model or invites scope creep into AI predators. This preserves the original arithmetic while making the classroom limitation visible.

**Classification:** Must fix.

**Stage affected:** Stage 3 and Stage 4.

**Implementation cost:** M.

**Cut or defer to keep scope stable:** Defer autonomous NPC lizards, AI predators, cross-room migration, and “unplayed lizards count as population” modeling.

---

### Change 2: Guarantee Stage 4 mutant introduction with a teacher-visible fallback

**GDD section affected:** Section 4, “Four-stage progression”; Section 7, “Vision traits and mutation”; Section 8, “Teaching and feedback loop.”

**Proposed replacement/addition:**

> Stage 4 uses a deterministic mutant introduction rule. The first offspring produced by any surviving lizard is marked as the mutant and receives the modeled low-light advantage. If no offspring is produced by the end of a teacher-configured round, default round 2, the teacher may introduce one mutant from the available pool or force the next eligible offspring to be mutant. The trait is inherited by recruited offspring of that mutant under the lesson’s simplified inheritance rule. The UI and teacher notes must label this as a modeled mutation, not a claim about a specific real-world mutation.

**Why:** Stage 4 cannot depend on a lucky reproductive event. The original lesson requires the mutant to appear; the digital version needs a reliable staging rule.

**Classification:** Must fix.

**Stage affected:** Stage 4.

**Implementation cost:** S/M.

**Cut or defer to keep scope stable:** Defer additional mutations, color-vision variants, tradeoff sliders, environmental reversal scenarios, and multi-trait inheritance.

---

### Change 3: Specify authoritative capture, disconnect, and reconnect behavior

**GDD section affected:** Section 9, “Preliminary technical architecture”; partly Section 5 and Section 11.

**Proposed replacement/addition:**

> The server owns bug identities, positions/spawn state, round state, captures, survival, and reproduction outcomes. Clients send movement/update information and capture attempts; they do not send trusted final scores. The server validates that a capture attempt targets an uncaught bug and that the player is within an allowed range/reachability rule. The first valid capture wins. If a client disconnects during a round, captures already validated by the server remain in the round record. The disconnected active lizard stops accepting input; at round resolution, its validated captures count, and survival is determined normally. Reconnection uses an ephemeral session token, not a user account. If the player reconnects before the round ends, they may resume; otherwise they return to the available/observer pool.

**Why:** The current GDD says the server is authoritative but does not define the minimum behavior needed to prevent duplicate captures, lost data, or confusion after disconnects. This is essential for classroom trust.

**Classification:** Must fix.

**Stage affected:** All stages.

**Implementation cost:** M.

**Cut or defer to keep scope stable:** Defer advanced anti-cheat, full physics simulation, lag compensation, replay systems, and detailed forensic logging.

---

### Change 4: Add provisional Chromebook/network performance gates and pilot bug limits

**GDD section affected:** Section 9, “Preliminary technical architecture”; Section 10, “Progressive development plan”; Section 11, “Success criteria and tests.”

**Proposed replacement/addition:**

> Before a classroom pilot, the team must run a technical spike on actual managed Chromebooks and the actual school network. Provisional pilot gates are: client becomes interactive within 60 seconds; secure WebSocket connection succeeds for at least 95% of clients; two rooms with six clients each remain stable for 15 minutes; median frame rate is at least 24 fps on the slowest approved Chromebook, targeting 30 fps; no hitch exceeds 3 seconds during a normal hunt; and capture/round events are visibly resolved within a few seconds. The team must measure the maximum stable rendered bug count per room and set pilot scenarios so expected prey counts remain below that maximum unless visual aggregation is explicitly approved and explained.

**Why:** The GDD correctly treats performance as unproven, but the pilot needs testable thresholds. Without a bug-count operating limit, Stage 2 reproduction can create hundreds of bugs before the team knows whether the client can handle them.

**Classification:** Must fix.

**Stage affected:** All stages.

**Implementation cost:** S/M, mostly testing and configuration.

**Cut or defer to keep scope stable:** Defer large habitats, high bug counts, bloom/complex lighting, animated bug swarms, multiple biomes, and “hundreds of synchronized bugs” until performance evidence exists.

---

### Change 5: Define minimum accessibility and fairness safeguards for Stage 4 and tag-in

**GDD section affected:** Section 7, “Vision traits and mutation”; Section 5, “Rooms, players, and offspring”; Section 8, “Teaching and feedback loop.”

**Proposed replacement/addition:**

> Stage 4 must provide at least one accessible way to teach the low-light contrast without requiring every student to use a darkened first-person view. Minimum supports are: a teacher projection/demo view showing the normal and mutant contrast; an observer/data role for students who cannot comfortably play the active dark view; and a high-contrast or brightness option that does not silently remove the modeled mutant advantage unless used for demo/observer purposes. For tag-in fairness, the teacher dashboard must include teacher assignment mode, invitation expiration, and a visible list of students who have not yet been active. No student may be required to play as an active lizard.

**Why:** Accessibility and social exclusion are classroom realities. A mutation lesson that is visually inaccessible or socially unfair undermines the instructional goal.

**Classification:** Must fix for deployment; some fairness refinements may be “should improve” after first pilot, but the accessibility fallback is essential.

**Stage affected:** Stage 4 primarily; fairness rules affect Stages 3–4.

**Implementation cost:** M.

**Cut or defer to keep scope stable:** Defer detailed color-vision simulation, additional phenotype traits, cosmetic variants, and complex social matching systems.

---

## 5. Three things NOT to add

### 5.1 Autonomous NPC lizards or AI predators to absorb excess offspring

**Do not add.**  
The original lesson’s predator population is made of participating students. Introducing autonomous NPC lizards would create a new ecological agent, require hunting behavior, pathfinding, capture rules, and balancing, and would obscure the classroom participation metaphor. It also turns a manageable design gate into a full simulation problem. The better solution is to cap active player-lizards by available classmates and log unfilled offspring slots as an explicit model limitation.

### 5.2 Deep genetics, Mendelian inheritance, or multiple mutation types

**Do not add.**  
Stage 4 only needs one simplified heritable trait: a modeled low-light advantage inherited by recruited offspring. Adding alleles, dominance, mutation rates, trait tradeoffs, or color-vision genetics would increase scientific risk, UI complexity, accessibility burden, and implementation cost. The original lesson intentionally uses a simple mutation metaphor. Deeper genetics should wait until the four-stage game is proven.

### 5.3 A larger open world, second biome, day/night cycle, or photorealistic rendering

**Do not add.**  
One compact habitat is enough to teach predation, reproduction, population interaction, and adaptation. Larger environments increase performance risk on Chromebooks, raise asset costs, complicate bug visibility/reachability, and consume teacher time without improving the core biological model. The GDD’s non-goal list is correct; keep it.

---

## 6. Unresolved decisions

| Decision                                                               | Recommendation where enough information exists                                                                                                                               | Cheap test or question if not enough information                                                                                                                                                             |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| What happens when Stage 3 births exceed available classmates?          | Use Option B: limit active offspring to available classmates and log unfilled slots as a visible model limitation. Do not add NPC predators.                                 | Playtest Stage 3 with two rooms of six students. If population dynamics feel too flat, adjust room size, starting lizards, initial bugs, or round length within the original lesson’s adjustable parameters. |
| Should offspring invites require acceptance or can the teacher assign? | Default to parent invitation with a short expiration, plus teacher assignment override. Teacher assignment should be available from the start for classroom management.      | Observe one class: count expired invitations, unchosen students, and time spent resolving invites.                                                                                                           |
| Who begins as a lizard?                                                | Teacher assigns or rotates initial lizards. Active play should be voluntary; no student should be forced into first-person active play.                                      | Test setup time and ask whether any student felt excluded or pressured.                                                                                                                                      |
| How long should rounds be?                                             | Default 45 seconds, teacher-adjustable from 30 to 60 seconds.                                                                                                                | Test whether 30 seconds is too rushed for prediction and whether 60 seconds creates too much chaos.                                                                                                          |
| What if bug population grows too large to render?                      | Set a maximum rendered bug count from the Chromebook spike. Pilot scenarios should keep expected prey counts below that maximum. Do not silently aggregate bugs for capture. | Render 100, 150, 200, and 300 static/low-animation bugs on target Chromebooks. Measure FPS, memory, and capture usability.                                                                                   |
| When does the mutant appear?                                           | First eligible offspring becomes mutant; teacher fallback by end of round 2 if no offspring has appeared.                                                                    | Playtest Stage 4 with low catch rates to see whether all lizards can starve before mutation occurs.                                                                                                          |
| Is headless Godot the right authoritative server?                      | Not enough information yet. It is plausible but unproven for this use case.                                                                                                  | Run a spike with two rooms and 12 clients. Measure CPU, memory, latency, and stability. If poor, evaluate a thin WebSocket/Node or other lightweight room server before committing.                          |
| Should PlayCanvas be a fallback?                                       | Do not implement in parallel. Treat it only as a contingency if the Godot technical spike fails.                                                                             | If Godot fails Chromebook gates, estimate the cost of porting the smallest Stage 1 slice. Do not start before that evidence exists.                                                                          |
| Should rooms have different environmental conditions?                  | Keep rooms identical by default. Any difference should be teacher-selected, visible in the dashboard, and recorded with the data.                                            | No major implementation question yet; this is a pedagogy/control decision.                                                                                                                                   |
| What if a population crash or mutant outcome does not happen?          | Accept stochastic outcomes. Provide teacher discussion prompts: “What caused this?” and “What would happen with more rounds or different settings?”                          | Test several runs to see how often the expected boom/crash occurs in short sessions. Do not secretly rig outcomes.                                                                                           |

---

## 7. Revised success criteria

### Smallest functional classroom pilot

Assumptions for the smallest credible pilot:

- 12 students total.
- 2 independent rooms, 6 students each.
- 1 teacher dashboard.
- Managed Chromebooks, browser-only, no installation.
- Stages 1–2 are the core pilot.
- Stage 3 and Stage 4 are gate tests after Stages 1–2 pass.
- Paper graphic organizers remain acceptable as prediction/recording fallback.

---

### A. Technical/session success criteria

1. **Joining:** At least 11 of 12 students join the correct room within 5 minutes using a URL/session code and nickname, with no installation.
2. **Teacher setup:** Teacher creates two rooms, starts the first round, and projects a graph within 10 minutes of class start.
3. **Stability:** A 15-minute session with two rooms remains functional. No room-wide crash occurs. Individual client crashes recover without disrupting the other room.
4. **Network:** WSS connections succeed for at least 95% of clients on the school network. If connection fails, the cause is identified and reproducible.
5. **Reconnection:** After a browser refresh or accidental tab switch, a client can rejoin within 20 seconds using an ephemeral session token, or is moved cleanly to the available/observer pool.
6. **No silent data loss:** Round results remain available after a client disconnect. Teacher can see the last completed round for each room.

---

### B. Stage 1 success criteria

1. **Rule correctness:** For each round, the server computes:
   - `bugs_end = bugs_start - total_captures`
   - `lizard_survives = captures >= 5`
2. **No duplicate captures:** In at least 10 scripted or observed race tests where two players attempt the same bug, exactly one capture succeeds.
3. **Round control:** Teacher can start, stop, pause, and reset one room without affecting the other room.
4. **Performance:** On the slowest approved Chromebook, median frame rate is at least 24 fps during a normal hunt, with no hitch longer than 3 seconds. Target is 30 fps.
5. **Usability:** Students can move and collect at least one bug without requiring individual technical help from the teacher.

---

### C. Stage 2 success criteria

1. **Reproduction correctness:** For each round, the server computes:
   - `survivors = prey_at_round_start - total_successful_captures`
   - `prey_for_next_round = survivors * 3`
2. **Graph accuracy:** The displayed graph matches the server log exactly and clearly labels whether points are start-of-round or post-resolution counts.
3. **Population cap discipline:** The pilot configuration stays below the maximum rendered bug count established by the technical spike. If expected prey exceeds that count, the configuration is considered invalid for pilot, and the team adjusts starting bugs, round length, or room size rather than silently capping reproduction.
4. **Instructional flow:** Teacher can pause after round 2 for prediction and discussion without losing round state.

---

### D. Stage 3 gate success criteria

Stage 3 should not be used in a full class until Stages 1–2 pass.

1. **Offspring calculation:** The server correctly computes `earned_offspring = floor((c - 5) / 5)` for each surviving lizard.
2. **Tag-in works:** At least one surviving lizard earns an offspring slot, selects an available classmate, and that classmate becomes active at the start of the next round.
3. **Lineage record:** The new lizard has a distinct ID, parent ID, and generation number.
4. **Participant cap visible:** If earned slots exceed available classmates, unfilled slots are logged as `unfilled_offspring_due_to_participant_limit`. No NPC lizards appear.
5. **Teacher override:** The teacher can cancel or reassign an invitation before the next round starts.
6. **No mid-round joins:** New offspring do not join during an active hunt.
7. **Fairness check:** In the pilot session, no student who wants to participate is left unchosen for the entire Stage 3 segment.

---

### E. Stage 4 gate success criteria

Stage 4 should not be used in a full class until Stage 3 tag-in passes.

1. **Mutant introduction:** A mutant appears by the first eligible offspring or by teacher fallback no later than the configured round, default round 2.
2. **Trait tracking:** The dashboard and graph distinguish normal lizards, mutant lizards, and bugs.
3. **Inheritance logic:** If a mutant earns offspring and a classmate accepts/is assigned, the offspring is recorded as mutant. If no mutant reproduces during the pilot, the teacher can manually verify inheritance by assigning one mutant offspring in a controlled test.
4. **Low-light contrast is legible:** On at least two different school Chromebook displays, the difference between normal and mutant vision is observable without requiring unsafe or unusable darkness.
5. **Accessibility fallback:** At least one of the following is available and tested: teacher demo view, observer/data role, or high-contrast demonstration mode.
6. **No forced inaccessible play:** No student is required to be an active lizard in the darkened Stage 4 environment.

---

### F. Instructional success criteria

1. **Prediction:** Students make at least one prediction before Stage 2 and one before Stage 3 or 4, using paper or teacher-projected prompts.
2. **Evidence:** After each stage, students can see the population graph update from server-verified data.
3. **Explanation sample:** In a sampled post-pilot check with six students:
   - At least five can explain that bugs reproduce in Stage 2.
   - At least five can explain that lizards need extra food to produce new lizards in Stage 3.
   - At least four can explain that the Stage 4 advantage is heritable and not caused by the lizard “trying harder.”
4. **Model limitation:** At least half of sampled students can state one way the game simplifies real ecology, such as “bugs reproduce instantly,” “one player becoming a lizard is a classroom model,” or “the mutation is a simplified model.”

These criteria define the smallest functional pilot while still protecting the four-stage progression, the original numeric rules, browser-only Chromebook deployment, and student-tagged offspring.
