# 1. Overall assessment

The GDD has a strong foundation: it preserves the original four-stage progression, keeps the biological rules explicit, treats the browser-only Chromebook requirement as a real constraint, and correctly separates authoritative population data from client-side visual effects. Its scope discipline is unusually good: no accounts, chat, open world, full genetics, or large NPC ecosystem are required.

The main vulnerability is feasibility, not concept. A first-person 3D multiplayer game with several rooms, authoritative WebSocket networking, teacher controls, reconnect handling, large prey populations, and individualized vision effects may exceed the performance and network reliability of managed school Chromebooks. This is currently acknowledged but not yet reduced to a hard go/no-go prototype gate. Scientifically, Stage 4 also risks presenting a deterministic inherited “mutant” and near-inevitable takeover as natural selection rather than as a deliberately bounded classroom model. The GDD should make that model assumption explicit and ensure that Stage 3 and Stage 4 outcomes remain discussable rather than guaranteed.

# 2. Scientific / instructional corrections

## 2.1 Stage 3 “equilibrium” is too deterministic

> “This illustrates population interaction, equilibrium, and ecological balance.”  
> — Section 4, Stage 3 table

The original lesson expects boom-and-crash behavior, but the simple equations do not guarantee equilibrium or a stable cycle in a short run. Depending on starting population, hunt success, round length, and player skill, the system may crash, remain prey-heavy, or eliminate the prey.

**Correction:** Replace the phrase with:

> “This illustrates interacting populations, resource limitation, and possible boom-and-crash dynamics. A stable equilibrium or repeating cycle is not guaranteed by the simplified rules.”

This is a **scientific wording correction**, not a new mechanic.

The same correction should be applied to:

> “predator-prey cycles are plausible, not guaranteed in a short stochastic run.”  
> — Section 8

That sentence is correct and should be promoted into the Stage 3 learning language and teacher dashboard guidance.

## 2.2 Stage 4 currently implies adaptation is guaranteed

> “One new offspring receives a heritable low-light sensitivity trait; offspring inherit that trait.”  
> — Section 4, Stage 4 table

> “Descendants inherit the modeled trait under the original lesson's simplified rule.”  
> — Section 7

The source lesson intentionally creates one mutant and then gives it a strong perceptual advantage. That is acceptable as a classroom model, but the wording can imply that a mutation necessarily appears, is beneficial, is inherited by all descendants, and spreads through the population.

In real biology, mutation is not directed toward need, inheritance is not necessarily deterministic, and an advantageous trait may fail to spread by chance. The GDD partly acknowledges this in Section 7, but the stage rule should say so too.

**Correction:** Replace the Stage 4 rule with:

> “At the first eligible offspring event, the teacher/game introduces one offspring with a modeled low-light detection advantage. In this simplified demonstration, the trait is inherited by that offspring’s tagged descendants. The advantage may increase the mutant lineage’s chance of finding prey, but takeover is not guaranteed.”

Also replace:

> “The population record distinguishes trait-bearing and non-trait-bearing lizards.”

with:

> “The population record distinguishes trait-bearing and non-trait-bearing lizards, and teacher notes label the inheritance rule as a deliberate simplification.”

## 2.3 “Mutation” and “adaptation” need clearer separation

> “Stage 4 adds low-light conditions and one inherited visual mutation…”  
> — Section 10

This is understandable shorthand, but the game should distinguish:

- **Mutation:** the modeled genetic change introduced in one offspring.
- **Trait:** the low-light detection advantage expressed by that lizard.
- **Natural selection:** differences in survival or reproduction associated with the trait.
- **Adaptation:** a population-level change over generations, not merely an individual changing.

The source lesson’s definition—

> “ADAPTATION: Organisms changing to better suit their environment.”

—is pedagogically common but scientifically imprecise because it can sound like organisms consciously or individually change in response to need.

**Correction:** Add a teacher note:

> “In this model, the individual does not adapt during play. A heritable variant is introduced first; if its carriers survive and reproduce more successfully, the population composition may change. That population-level change is the model’s approximation of adaptation by natural selection.”

No additional genetics system is needed.

## 2.4 Stage 2 must use “uncaught,” not merely “surviving,” in the rule explanation

> “Each surviving bug generates two new bugs at the end of a round.”  
> — Section 4, Stage 2 table

The arithmetic correctly defines:

> “survivors = prey_at_round_start - total_successful_captures.”

However, “surviving bug” could be interpreted as a bug that survives some separate health or predator check. The source rule is specifically:

> “each bug NOT caught generates 2 more bugs.”

**Correction:** Use this wording consistently:

> “At the end of the round, each bug that was present at the start and was not captured produces two modeled offspring; the original bug remains, so each uncaught bug contributes three bugs to the next round.”

This preserves the original numeric rule while making the bookkeeping unambiguous.

## 2.5 Stage 3 offspring timing needs to be part of the biological model

The GDD says:

> “Child becomes an active lizard at the next round start, not halfway through a hunt.”  
> — Section 5

That is a good technical rule, but it is also necessary for scientific and mathematical consistency. The offspring should not contribute to the round in which it was earned. The GDD should state that the offspring slot is earned from the parent’s captures in the completed round and becomes a population increase only during the next round’s starting state.

Otherwise students may interpret a parent as receiving immediate help from its offspring.

## 2.6 Stage 4 “extra light receptors” should remain explicitly fictionalized

> “One new offspring receives a heritable low-light sensitivity trait…”  
> — Section 7

The source story describes “extra light receptors,” but the GDD wisely avoids asserting a specific real mutation. Keep it that way. Do not describe the feature as a medically or biologically validated eye mutation unless the design team obtains a qualified biological review.

A safe teacher-facing phrase is:

> “The game uses ‘extra light sensitivity’ as a simplified fictional trait. It is not a complete model of lizard eyes or human color vision.”

# 3. Technical and classroom risks

| Rank | Risk                                                                                  | Probability        | Impact      | What must be tested                                                                                                                                       |
| ---- | ------------------------------------------------------------------------------------- | ------------------:| -----------:| --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | 3D rendering and visual effects perform poorly on older managed Chromebooks           | High               | High        | Actual lowest-spec school Chromebooks; sustained frame rate during a hunt; low-light effect; several visible bugs; teacher dashboard open simultaneously  |
| 2    | School network or firewall blocks WSS, causes unstable latency, or prevents reconnect | Medium–High        | High        | On the actual school network, not a home network; page load, WSS connection, round start, reconnect after Wi-Fi interruption, and classroom tab switching |
| 3    | Browser focus, pointer lock, or tab suspension disrupts first-person play             | High               | High        | ChromeOS managed profile; mouse and trackpad; switching to teacher projection; inactive-tab behavior; returning to the game without corrupting the round  |
| 4    | Prey population growth creates too many rendered or synchronized objects              | High in Stages 2–4 | High        | Start with source-like counts and worst-case growth; measure server load, client frame rate, memory, and network traffic; test aggregated visuals         |
| 5    | Tag-in and offspring invitations fail under real classroom timing                     | Medium             | High        | Multiple simultaneous invitations; accept/decline; duplicate invitations; disconnected invitee; teacher override; child entering only at next round       |
| 6    | 25 connected browsers are stable individually but not as several rooms                | Medium             | High        | Approximately 25 real clients across at least two rooms, with hunts, graph updates, and teacher controls active                                           |
| 7    | Visual camouflage is inconsistent across Chromebook screens                           | High               | Medium–High | Same scene on multiple displays; brightness and color variation; low-light and normal lizards; distinguishability without relying only on hue             |
| 8    | Classroom pacing is too slow because of joining, room assignment, and tag-in          | Medium             | Medium–High | Time from URL distribution to first hunt; teacher intervention count; time between rounds; student idle time                                              |
| 9    | Player skill differences overwhelm the biological signal                              | High               | Medium      | Run several classes or groups; compare capture distributions; test whether the Stage 4 advantage remains observable without being automatic               |
| 10   | Students coach active hunters through observer information                            | Medium             | Medium      | Verify observers receive counts and permitted views but not hidden prey coordinates or unfair live location data                                          |

## Hard prototype gates

The following should be treated as go/no-go gates before building the full four-stage game:

1. A web-exported client loads on the target managed Chromebook profile without installation or special permissions.
2. WSS works on the actual school network.
3. Several clients can complete a timed hunt and receive identical authoritative results.
4. The weakest approved Chromebook remains usable during a hunt with the intended visual treatment.
5. A room can recover from a client disconnect without losing population data.
6. A basic tag-in can be completed by a real student without teacher-side manual repair.

The proposed 30 FPS target is reasonable as an aspiration, but it should not be the only criterion. Input responsiveness, readability, reconnect behavior, and teacher recovery matter more than a nominal frame-rate number.

# 4. Top five proposed changes

## Change 1 — Make the technical spike an explicit go/no-go gate

**Exact GDD section affected:** Section 9, “Preliminary technical architecture — to be proven”; Section 10, “Technical spike.”

**Proposed replacement/addition:**

Add:

> **Full-build gate:** Do not commit to the four-stage 3D multiplayer implementation until the technical spike passes on the intended managed Chromebook class and school network. The spike must demonstrate: browser-only launch, WSS connectivity, two isolated rooms, teacher-controlled rounds, server-authoritative capture results, reconnect after tab/network interruption, and acceptable usability on the slowest approved device.

**Why:** The architecture is the largest project risk. A desktop demonstration or editor preview does not establish Chromebook feasibility.

**Classification:** Must fix  
**Stage affected:** All stages; primarily pre-Stage 1  
**Implementation cost:** S  
**Cut or defer to keep scope stable:** Defer all extra vision traits, rich terrain, moving prey, and visual polish until the gate passes.

## Change 2 — Replace deterministic Stage 4 language with an explicit model assumption

**Exact GDD section affected:** Section 4, Stage 4 row; Section 7, “Stage 4 minimum”; Section 8, teacher feedback loop.

**Proposed replacement/addition:**

> At the first eligible offspring event, the game introduces one offspring with a modeled low-light detection advantage. For this classroom model, the trait is inherited by that offspring’s tagged descendants. The trait changes detection probability or visibility; it does not guarantee survival, reproduction, or population takeover. Teacher materials must identify this as a simplified inheritance rule rather than a complete account of mutation or reptile biology.

**Why:** This preserves the source lesson while preventing students from learning that useful mutations are directed, automatically successful, or guaranteed to spread.

**Classification:** Must fix  
**Stage affected:** Stage 4  
**Implementation cost:** S  
**Cut or defer:** Defer all additional mutation categories and environmental reversals.

## Change 3 — Clarify population state and round-resolution timing

**Exact GDD section affected:** Section 4, “Essential arithmetic” and “Round resolution order”; Section 5, “Tag-in process”; Section 8, teacher controls and graphs.

**Proposed replacement/addition:**

Add a visible state definition:

> Every graph point is labeled either **start-of-round** or **post-resolution**. A child earned in round N enters the active roster at the start of round N+1 and cannot hunt in round N. Stage 2 prey reproduction is calculated from bugs present at the start of the round that were not captured. Stage 3 offspring are added after capture resolution and before the next round begins.

Also require the teacher view to show:

- start-of-round prey and lizard counts;
- captures by lizard;
- starvation results;
- offspring slots earned;
- post-resolution counts;
- normal and trait-bearing lizards separately in Stage 4.

**Why:** The current equations are mostly sound, but students and developers could otherwise mix states and produce off-by-one population errors.

**Classification:** Must fix  
**Stage affected:** Stages 1–4  
**Implementation cost:** M  
**Cut or defer:** Defer exportable reports and complex analytics; a clear round summary is sufficient for the pilot.

## Change 4 — Define a bounded Stage 3 overflow policy before implementation

**Exact GDD section affected:** Section 5, “Unresolved design gate.”

**Proposed replacement/addition:**

Recommend option B for the smallest pilot:

> If earned offspring exceed the number of available classmates, the game records all earned offspring slots but activates only the number that can be filled by available students. The teacher interface must show the difference between **offspring slots earned** and **student lizards activated**. The teacher may assign eligible students using a visible fairness rule. This is a classroom participation cap, not an assertion that the modeled population produced fewer offspring.

A later version can test a more complete population representation, but the first pilot should not add autonomous NPC predators.

**Why:** The current open decision blocks Stage 3. Full NPC lizards would materially expand scope and could make the observed population dynamics less transparent.

**Classification:** Must fix  
**Stage affected:** Stage 3 and Stage 4  
**Implementation cost:** M  
**Cut or defer:** Defer NPC lizards, automatic replacement populations, and complex migration mechanics.

## Change 5 — Add a Chromebook accessibility and observer-mode acceptance test

**Exact GDD section affected:** Section 6, “Environment, visual design, and camouflage”; Section 7, “Accessibility constraint”; Section 11, “Success criteria.”

**Proposed replacement/addition:**

Add:

> The pilot must provide at least one non-color-dependent cue for prey visibility and trait distinction, such as outline, pattern, label, or teacher-selected demonstration mode. Accessibility settings must not be confused with the modeled lizard phenotype. A student who cannot comfortably use the first-person hunt must still be able to participate in prediction, observation, data recording, or a teacher-approved alternative role.

Add a test:

> On at least three visually different target Chromebooks, students can identify the intended difference between normal and low-light lizards without relying on hue alone, and the teacher can explain the distinction without revealing hidden prey locations.

**Why:** The original paper game used physical visibility and reachable placement. A digital version can accidentally become a color-vision, brightness, or display-calibration test rather than an ecology model.

**Classification:** Must fix  
**Stage affected:** All stages; especially Stage 4  
**Implementation cost:** M  
**Cut or defer:** Defer fine-grained color-vision simulations and shader-heavy perception effects.

# 5. Three things NOT to add

## 5.1 Do not add autonomous NPC lizard populations in the first playable version

NPC predators would solve the Stage 3 overflow problem superficially, but they would introduce AI behavior, balancing, synchronization, and interpretability costs. Students could no longer tell whether a population change came from their choices or hidden agents. A visible classroom cap plus a distinction between earned slots and activated student offspring is cheaper and more honest.

## 5.2 Do not add full genetics or multiple mutation types

Mendelian inheritance, alleles, sexual reproduction, mutation rates, and pedigrees would turn a four-rule ecology model into a genetics simulation. They are not required to teach the intended contrast between environmental change, heritable variation, and differential success. The current single modeled trait is enough for the pilot.

## 5.3 Do not add a large open world, multiple biomes, or a full insect ecosystem

The source lesson depends on short, legible rounds and visible, reachable prey. A larger world would increase rendering and network costs while making bugs harder to find and population data harder to interpret. One compact habitat with controlled lighting and readable prey is better aligned with the instructional goal.

# 6. Unresolved decisions

## 6.1 Which Chromebook specification is the minimum target?

The GDD cannot responsibly promise a frame rate or visual quality without knowing the actual device range.

**Recommendation:** Obtain the school’s lowest and most common Chromebook models, ChromeOS versions, managed-browser restrictions, and display characteristics. Run the technical spike on those devices before selecting the final rendering budget.

## 6.2 Is first-person 3D necessary if the technical spike fails?

The educational model does not require 3D. First-person perception is a proposed digital adaptation, not part of the original paper game.

**Recommendation:** If browser 3D fails the gate, test a compact 2D or very lightweight pseudo-3D habitat before abandoning the four-stage game. Do not add a second engine or build both approaches in parallel before evidence requires it.

## 6.3 How should unused offspring slots be represented?

The current GDD correctly identifies this as unresolved.

**Recommendation:** For the pilot, record earned slots separately from activated student lizards. Ask the teacher whether showing unused slots helps or confuses students. Do not silently convert unfilled slots into NPCs or delete them from the data.

## 6.4 What fairness rule should govern invitations?

Parent choice is a required social mechanic, but unrestricted popularity-based choice could exclude students.

**Recommendation:** Use a simple visible queue or teacher-managed available pool with invitation expiration. Test whether students understand the rule and whether every willing student receives a reasonable opportunity during a lesson. A complex matching algorithm is unnecessary initially.

## 6.5 How much should Stage 4 guarantee?

The source lesson deliberately creates one mutant and gives it a strong advantage. The game should preserve that setup, but not guarantee takeover.

**Recommendation:** Make the mutant introduction deterministic for lesson clarity, while making its later spread dependent on actual captures and survival. If classroom testing shows that the difference is not observable, first adjust lighting contrast or round length—not the biological claims.

## 6.6 Are the source standards and grade labels being retained?

The source document includes standards references and grade-4 learning targets, but the digital GDD does not specify whether those claims are being retained or merely inherited.

**Recommendation:** Either remove standards codes from the game-facing specification or have an educator verify them before publication. Do not present inherited references as independently validated curriculum alignment.

# 7. Revised success criteria

The following criteria define the smallest functional classroom pilot. They separate **bug fixes**, **necessary support systems**, and **future enhancements**.

## A. Bug fixes and scientific correctness

1. The game preserves exactly four stages and the original numeric rules:
   - fewer than 5 captures means starvation;
   - each uncaught prey item contributes itself plus two modeled offspring in Stages 2–4;
   - every five captures beyond the survival requirement earns one offspring slot in Stages 3–4.
2. Server-side results match the published equations for at least 100 automated round-resolution cases, including zero captures, starvation, exact thresholds, multiple offspring, and prey exhaustion.
3. No bug can be captured by two players.
4. A child earned during round N cannot hunt until round N+1.
5. Every graph point is labeled as start-of-round or post-resolution.
6. Stage 4 distinguishes mutation, trait expression, inheritance, and possible selection in the teacher explanation.
7. Stage 3 and Stage 4 do not describe equilibrium, mutant dominance, or population takeover as guaranteed outcomes.
8. The game records earned offspring slots separately from active student lizards when available classmates are insufficient.

## B. Necessary classroom support systems

1. Students join from a managed Chromebook browser with no installation, account, or personal information requirement.
2. A teacher can create at least two independent rooms and place approximately 25 connected browsers across those rooms.
3. The teacher can set the stage, initial prey count, starting lizards, round duration, start, stop, pause, advance, and reset.
4. A teacher can see each room’s prey count, active lizard count, starvation results, offspring slots, and Stage 4 trait counts.
5. At least one real student can be invited and tagged in as an offspring, accept the invitation, and enter at the next round start.
6. Teacher override is available for an expired, declined, duplicate, or unfair invitation.
7. A disconnected client can reconnect without changing authoritative population counts or ending the room.
8. Observers receive public counts and round outcomes but not hidden prey coordinates or other information that gives them an unfair coaching advantage.
9. Each stage can be completed within a normal class period after a short teacher setup.
10. Students have a non-color-only way to participate in the Stage 4 contrast and can use observation, prediction, or data-recording roles if first-person hunting is inaccessible.

## C. Chromebook and network pilot tests

1. The actual school network permits HTTPS page loading and WSS gameplay.
2. The lowest-spec approved Chromebook completes a hunt with responsive controls, readable prey, and no browser crash or sustained unusable slowdown.
3. The pilot tests at least two rooms and approximately 25 connected clients, not merely 25 idle browser tabs.
4. The pilot tests tab switching, teacher projection, temporary Wi-Fi loss, browser focus changes, and reconnect.
5. The pilot tests the low-light effect on multiple Chromebook displays and confirms that the intended contrast remains understandable.
6. The pilot measures load time, input responsiveness, reconnect time, client frame rate, server CPU/memory, and network traffic before setting final numeric performance budgets.

## D. Instructional outcomes

After playing a stage, students should be able to:

1. describe predation and competition in Stage 1;
2. explain how the prey reproduction rule changes population growth in Stage 2;
3. explain how predator reproduction can increase resource pressure and cause possible boom-and-crash behavior in Stage 3;
4. distinguish a heritable variant from population-level selection in Stage 4; and
5. name at least one way the game simplifies real biology.

These should be measured with a short teacher-led exit prompt or graphic organizer, not inferred solely from successful gameplay.

## E. Future enhancements, not pilot requirements

The following may be considered only after the pilot passes:

- additional visual traits;
- environmental reversals such as restored sunlight;
- richer prey movement;
- data export and formal reports;
- controlled comparisons between rooms;
- broader genetics;
- NPC populations;
- additional biomes.

They should not be prerequisites for demonstrating that the original four-stage browser classroom game works.
