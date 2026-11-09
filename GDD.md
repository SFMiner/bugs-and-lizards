# Bugs & Lizards (digital) — Game Design Document (stub)

Stub 2026-10-11. Not approved, and no code yet. Godot 4.5, web (sims.mr-miner.com), lean 2D template.
Grade 6, *Matter & Energy in Ecosystems*, 601's Part B (Amplify's Bugs & Lizards Games 1–3, run on paper in class).
**Length:** about 10 minutes, in three short parts.

## 1. Learning goal
**Predators and food limit populations, and predator and prey numbers rise and fall together, one behind the other.**
- MS-LS2-1 (resource availability and populations), MS-LS2-4.
- It's the fallback data set and the fast replay for the paper games. The paper rounds are slow and noisy, but this
  runs 20 generations in a minute.
- After playing, students can read the two-line graph: "When the bugs go up, the lizards go up after."

## 2. Player experience
Three parts, matching the paper games:
1. **Predation.** The student is the lizard for 20 seconds: press to snap at bugs under the crosshair (keyboard: arrow
   keys + Space). The bug count falls. Then press "Next generation" a few times: no new bugs, so the line only goes down.
2. **Reproduction.** Uncaught bugs multiply each generation. The line explodes. *"Why aren't we buried in bugs?"*
3. **Predator and prey.** Lizards need a minimum number of bugs to survive. Extra catches add new lizards. Press
   "Run 20 generations" and watch both lines draw. Then compare them with the lynx and hare graph (a picture).

## 3. Model
- Bugs: each survivor makes N offspring per generation, up to a food limit.
- Lizards: each catches bugs in proportion to how many there are. Below the minimum it dies; over the threshold it
  adds a lizard.
- Seeded and deterministic, so the projected class run matches the one students saw. Tune for 2–3 visible cycles.
- Leave out Game 4 (adaptation and camouflage) to match the unit plan: it's natural selection, not 6th grade.

## 4. For 601
- Read-aloud button. Bugs and lizards are big, simple shapes.
- Projected mode: one student is the lizard while the class counts.
- Graph lines need a colour, a dash pattern and a label (the Biodome Rescue rule).

## 5. Open questions for Sean
- Is the 20-second snap round a good idea for the students with attention deficits, or too exciting?
- Should it use the class's own paper-game numbers as the starting values (typed in by the teacher)?
