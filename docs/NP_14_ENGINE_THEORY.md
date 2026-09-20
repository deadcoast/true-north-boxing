# NP-14 — ENGINE THEORY: Provable Claims and Use Cases
**Project Northpaw design vault · Foundation of `engine/greybox/sim/core.gd` · PCUC discipline: every claim names its test, and the test has been run**

The greybox v1–v5 proved the design. This document is the foundation the engine is rebuilt on (greybox v6): each section states a claim, the mathematics or mechanism behind it, where the industry ceiling sits and why, the executable test in this repo, and **the result of running it**. A claim without a test is not in this document; a claim whose test has not been run is marked as such.

Status legend: **PROVEN** = test run in-container, GREEN, reproduction command below. **MODEL** = a consequence of the model that no external source was found to confirm or deny; it stands until playtest data speaks.

---

## C1 — Deterministic fixed-tick simulation — PROVEN
**Claim.** A combat simulation advanced in fixed ticks (120 Hz, Δt = 1/120 s) from an input log, using no wall-clock reads and a seeded RNG, produces identical state for identical input logs regardless of render frame rate.
**Why it matters.** Frame data (a 160 ms jab is 19.2 ticks; the engine rounds to 19) only *means* something when the tick is the unit. Determinism is the precondition for replays, golden-master regression tests, and rollback netcode — the architecture every serious fighting game since GGPO runs on: simulate from inputs, never from time ([GGPO](https://en.wikipedia.org/wiki/GGPO), [rollback architectures](https://www.snapnet.dev/blog/netcode-architectures-part-2-rollback/), [determinism requirements](https://docs.coherence.io/manual/advanced-topics/competitive-games/determinism-prediction-rollback)).
**Mechanism.** `TNBSim.step(intent)` is the only way time passes. `TNBClock` (`sim/clock.gd`) turns frame deltas into a tick count and an interpolation alpha; `main.gd` draws between the last two ticks. Every ms constant in `combat_tuning.v1.json` becomes ticks at load (`ms()`), so no float time survives into the fight.
**Ceiling and why.** Floating-point non-associativity across compilers is the classic determinism killer for cross-platform rollback; inside one engine build it is a non-issue. Ceiling here: single-build determinism, with all math in one module so a fixed-point swap is local.
**Test.** `-- determinism`: a 24,000-tick scripted input log run three times — twice tick-by-tick, once through the *same* `TNBClock` the game uses fed 7–40 ms frame slices — with `hash_state()` (bit-exact over positions, pools, timers, queues, flags, RNG state) every 60 ticks. A different seed must diverge.
**Result.** 8/8. 400/400 hashes identical across all three runs; the log is shown to exercise both offenses, counters, flash windows, interrupts, drops, eight-counts, segment ends, evasions, blocks, clinch scrambles, sprint-steps and sensors; seed 54321 diverges.

## C2 — Geometric hit resolution replaces dodge tables — PROVEN (table) / MODEL (some cells)
**Claim.** Resolving punches by geometry — a punch is a region in the attacker's frame (reach, lateral window, height band); a defender's head is a point displaced by the active dodge — reproduces the sourced head-movement consensus as an *emergent* table, with no dodge×punch lookup anywhere in the code.
**The regions** (attacker frame, right hand; the left hand mirrors the lateral window). Distance *d* along the line of attack, lateral *l* along the attacker's right, height *h*:

| Punch | reach (m) | lateral window l | height band h |
|---|---|---|---|
| Straight | 2.05 | [−0.18, 0.18] | [1.35, 1.80] |
| Overhand (flared) | 2.00 | [−0.25, 0.25] | [1.10, 1.85] |
| Hook | 1.90 | [−0.15, 0.50] | [1.35, 1.75] |
| Hookercut (haymaker) | 1.90 | [−0.20, 0.55] | [1.20, 1.80] |
| Uppercut | 1.75 | [−0.15, 0.15] | [0.95, 1.90] |

**Why the hook window is asymmetric.** A hook's fist runs on an arc around the punching shoulder (offset ≈ +0.2 m to the attacker's right). Where the fist has reached the target plane *y_t* is the set of laterals with |x − 0.2| ≤ √(r² − y_t²); with r ≈ 0.7 m and y_t ≈ 0.6 m that is x ∈ [−0.16, +0.56] — the region is centred on the shoulder line, not the centreline. A head displaced toward the hooking hand stays inside the arc; a head displaced the other way is past where the arc ends.
**The head displacements** (defender frame): slip ±0.35 m lateral; duck h = 1.15; lean-back +0.30 m distance; weave ±0.40 m lateral **and** h = 1.30 (the bob goes under). Neutral head h = 1.55. Body targets sit at h = 1.10 and follow a slip at only 40 %, so a slip does not move the torso out of a body shot.
**The consensus it must reproduce — what the sources actually say.** Slips are the answer to jabs and straights, inside and outside ([Slipping](https://en.wikipedia.org/wiki/Slipping)). The duck "works best against straight punches" ([four head-movement techniques](https://evolve-mma.com/blog/4-head-movement-techniques-for-boxing-and-how-to-train-them/)); the uppercut is the punch a duck must fear, and dropping vertically rather than forward is what limits it ([ducking](https://www.myboxingcoach.com/body-movement-duck/), coach's reply). Bob-and-weave "moves the head both beneath and laterally of an incoming punch" ([Bob and weave](https://en.wikipedia.org/wiki/Bob_and_weave)). The overhand "arcs the arm downwards onto the target" and "can also be employed when the opponent is bobbing or slipping" ([Overhand punch](https://en.wikipedia.org/wiki/Overhand_punch)). The pull/lean answers a jab or straight and gets hard against long reach ([evolve](https://evolve-mma.com/blog/4-head-movement-techniques-for-boxing-and-how-to-train-them/)).
**The emergent table** (inside spacing 1.55 m; H = hit, · = miss; ◇ = MODEL cell, no source found either way):

| dodge \ punch | STR | FLA | HOK | HKC | UPC |
|---|---|---|---|---|---|
| none | H | H | H | H | H |
| slip-away (from the punching hand) | · | · | · ◇ | · ◇ | · ◇ |
| slip-into | · | · | H ◇ | H ◇ | · ◇ |
| duck | · | H | · ◇ | · ◇ | **H** |
| lean-back (inside) | H | H | H | H | · ◇ |
| weave-into | · | · ◇ | · | H ◇ | · ◇ |
| weave-away | · | · ◇ | · | · ◇ | · ◇ |
| none @ 1.80 m | H | H | H | H | · |
| lean-back @ 1.80 m | · | · | · | · | · |

Sourced rows hold: slips beat straights; the duck beats straights and eats the uppercut; the overhand comes down onto a ducked head and out-reaches a slip only at the edge; the weave goes under hooks; the lean beats the straight at range and fails inside.
**Ceiling and why.** Fight Night Champion and its descendants resolve dodges with canned animation pairs — a slip "beats" a straight because the designer tagged it so; the space between fighters is not consulted. That ceiling exists because animation-driven combat cannot afford geometry disagreeing with the animation. A shapes-first engine has no such debt: geometry decides, animation follows.
**Test.** `-- geometry`: enumerate the 7 dodges × 5 families at 1.55 m plus the two range rows, in both directions (boss→player, player→boss) and for both hands; assert every cell; assert body shots land through slips and ducks; assert that every boss read (`_correct_dodge_for`) is a valid evasion over 400 draws; assert a scheduled read is live on the impact tick for jab, hook, uppercut and haymaker startups.
**Result.** 5/5. 0 mismatches in 4 × 45 cells; 0 of 400 reads would eat the punch.

## C3 — Input buffering removes dropped inputs without adding latency — PROVEN
**Claim.** A punch command issued while the fighter is busy is queued with a 6-tick (50 ms) life and executes on the first legal tick; a command issued while free executes on the *same* tick; a command pressed during hitstop is queued, never eaten. Net added latency for a free fighter: zero.
**Why.** Every modern fighting game buffers ([input buffering](https://supersmashbros.fandom.com/wiki/Input_Buffering), [why buffers exist](https://www.wayline.io/blog/input-buffering-responsive-game-feel), [the leniency debate](https://www.wayline.io/blog/lenient-input-buffers-ruining-fighting-games)); the debate is window length, and 3–8 frames at 60 Hz is the observed band. 6 ticks at 120 Hz sits at the tight end on purpose: FNC's grammar is expressive, and a long buffer would let flicks queue into unintended strings.
**Test.** `-- smoke` stages "C3": free fighter executes same tick; issued 3 ticks before recovery ends → fires on the recovery-end tick; issued 8 ticks before → expires unexecuted; pressed during hitstop → executes on the first unfrozen tick.
**Result.** 4/4 on all 24 bosses. The hitstop case was a real bug: v5 and the first v6 core both dropped inputs during the freeze.

## C4 — Tell floors sit above human choice reaction time by a computed margin — PROVEN (design margin)
**Claim.** Every pattern tell exceeds the expected human choice-RT for its decision by a margin the compiler prints. Hick–Hyman: RT = a + b·log₂(n+1) ([Hick's law](https://en.wikipedia.org/wiki/Hick%27s_law), [Proctor & Schneider 2018](https://pubmed.ncbi.nlm.nih.gov/28434379/)), with a = 225 ms (simple visual RT band 200–250 ms) and b = 150 ms/bit (classic slope). A tell asks a 3-way choice (block / slip / interrupt) → n = 3 → RT ≈ 525 ms; a known pattern collapses it toward n = 1 → RT ≈ 375 ms.
**Consequence.** The 400 ms normal floor clears the known-pattern read by 25 ms and sits 125 ms *under* a cold 3-way decision — normal strings are meant to be read by pattern knowledge (Doctrine D2). The 700 ms SPECIAL floor clears the cold read by 175 ms; the 1000 ms ARMORED floor by 475 ms. The floors encode a pedagogy, and the numbers now say so.
**Ceiling.** Hick–Hyman is a population model; individual variance is large and expert compression is real. The claim is about design margins, never about any single player.
**Test.** `python3 pbn_compiler.py --margins`: per class and per authored string, tell − RT(1) and tell − RT(3); fails if any SPECIAL/ARMORED string is negative at n = 3.
**Result.** GREEN over 80 strings / 24 patterns; worst SPECIAL +175 ms (Ada Okafor S3), worst ARMORED +475 ms (Anders Vey P3S2).

## C5 — Hitstop and slow-time live inside the simulation — PROVEN
**Claim.** Hitstop (frozen ticks on impact) and flash-window slow-time (0.6× rate on the boss's decision timers) are simulation state, never engine clock manipulation. Determinism survives them and replays reproduce feel exactly.
**Test.** `-- smoke`: a landed hit queues freeze ticks; a frozen tick advances no clock. `-- determinism`: the log contains counters, interrupts and flash windows, and the hashes still match.
**Result.** GREEN. `Engine.time_scale` is no longer touched anywhere.

## C6 — One resolution function for both fighters — PROVEN
**Claim.** The boss's defense is a dodge *choice* (a read, with probability shaped by the adaptation tracker and by tell state), scheduled so the dodge is live on the impact tick and resolved through the same geometry as the player's. There is no separate "boss defend roll". Counter windows lower the read probability to a quarter; a flash window to 2 %; a hissatsu to zero: fear is a number applied to a real mechanic.
**Test.** `-- geometry` runs the table in both directions and checks read validity and read timing; `-- smoke` checks `read_prob()` ordering (counter < neutral < flagged).
**Result.** GREEN. The first core fired the dodge at punch startup, so slow punches always found the head back in place — the timing assertion caught it.

## C7 — Adaptation modifies defense only (Doctrine D3), mechanized — PROVEN
**Claim.** The tracker's flags raise the boss's read probability and nothing else; boss offense is the compiled pattern at all times.
**Test.** `-- smoke`: four repeated jabs flag the 2-gram; `read_prob(tier)` rises (0.30 → 0.55); the SELECT weights and every string's tell are byte-identical before and after the flag (punish cooldowns pre-armed so no punish reweight can confound it).
**Result.** GREEN on all 24 bosses.

## C8 — The engine executes every verb the compiler emits — PROVEN (verbs, responses) / PARTIAL (triggers)
**Claim.** A compiled pattern is executable in full: every action verb, every punish response and every phase trigger form resolves to sim behaviour, or the smoke names what does not.
**Mechanism.** `parse_action()` is a small VM: punches (with hand, body, counter multipliers), movement (RUSH/SURGE/ADVANCE/HERD/STEP_IN/GUARD_ADVANCE/GUARD_WALL_ADVANCE/STEP_OUT/STEP_BACK/BACK_STEP/ANGLE_STEP/LATERAL_ARC/POSITION_WIN), timing (DELAY/pause), traps (COUNTER_STATE/COUNTER_ON_BLOCK — a punch into the waiting guard is answered at once), grappling (CLINCH_ATTEMPT/DRAG_ROPEWARD — hold both fighters, drag toward the nearest rope), composites (WALK_STRING/MIXED_STRING/BODY_SERIES). `_parse_response()` is the punish grammar. Sensors the hooks ask for (passive>Ns, holds_center_Ns, guard hold Ns, perfect_play_Ns) are parsed from the pattern itself.
**Test.** `-- smoke`: static coverage over all 24 patterns (`verb_coverage`, `response_coverage`, `phase_coverage`) plus live checks of COUNTER_STATE, CLINCH and the composite expansions.
**Result.** 39/39 verbs, 53/53 responses, 13/13 phase-trigger forms (the `warnings_banked==N` form arrived with the referee model in C9).

## C9 — Every hook is live: sensors fire at their threshold and never early — PROVEN
**Claim.** Each behaviour a pattern hook names is a measurable event in the sim with an explicit threshold, and the smoke proves two things per sensor: it fires on the step the threshold is met, and it has not fired on the step before (or under the contrasting behaviour). A hook whose sensor cannot be defined this way stays inert; none remain.
**Mechanisms** (threshold in parentheses; the authored intent in NP_04):

| sensor | what is measured | fires when | contrast that never fires |
|---|---|---|---|
| `locks_to_single_tempo` (Chiamaka) | the last 6 punch intervals | all within 15 % of their median, median ≤ 1.5 s | five equal intervals; a varied cadence |
| `neutral_reset_attempt` (Deshawn) | ticks out past engagement (+0.5 m) without leading or closing | 120 consecutive ticks | the 119th tick |
| `casts_<house>_native` (Rémy) | the cast hissatsu's `house_id` in the library vs the pattern's META `house` | equal at cast | Aurora Borealis Breaker (no house) |
| `trap_stance_hands_down` (Marta) | she drops her hands after 3 s without a lead (boss-side stance, 50 % per idle selection) | a punch executes during the stance | a punch with her hands up |
| `reacts_to_fake_tell` (Tam) | phase-1 tells with nothing behind them (35 % of selections, drawn identically) | a dodge, block press or punch during a fake | ignoring the fake; phase 2 emits no fakes |
| `audio_assist_reliance` (Choir) | reaction latency to the last three real tells with the audio cue on | all three < 300 ms | the same reactions with the cue off; the second fast reaction |
| `clinch_input_spam` (Alfie) | clinch inputs in an 8 s window | the third | the second |
| `sprint_approach` (Marta, Tam) | a sprint-step's direction vs the line to the boss | toward (dot > 0.5) from beyond 1.4 m | a sprint away |
| `straight_line_retreat` (Moira) | backing displacement without an angle | 1.2 m accumulated | any step before 1.2 m; an angled retreat |
| `backstep_chain3` (Deshawn) | sprint-steps away in a 4 s window | the third | the second |
| `rope_backing` (Vane) | entering ROPES/CORNER with velocity away from the boss | on the transition | sliding along the rope line square to him (rope_touch only) |

**Clinch scramble** (NP_03 §7). A 2 s duel: taps on a cue whose window is RFX-gated (120–220 ms); two beats win position (opponent herded 50 cm ropeward) or, holding BODY on the resolve, a reset (both toward center, +5 stamina); no beats loses it and you are dragged. Boss grabs (`CLINCH_ATTEMPT`) run the same duel; `DRAG_ROPEWARD` needs three beats. Clinch inputs count toward the holding call whether or not a scramble is running.
**Referee** (NP_01 §5). Fouls ladder: warning → −5 EP → a DROP awarded to the opponent on the third. Dirty archetypes foul on the break of clinches they win; the pattern's META `warnings_banked=N` is how many they bank and they never take the next one. `warnings_banked==N` is a phase-trigger form. Holding without work (three grabs in 8 s) is a referee break at −2 EP.
**Test.** `-- smoke` PAC-054 stage: 24 assertions (one fires/never-early pair per sensor, fake-tell existence in phase 1 and absence in phase 2, the scramble won by position, won by reset, and lost, Alfie's ladder 1/2/2 with −5 EP and phase 2 reached, 13/13 trigger forms). `-- determinism` now asserts the log exercises clinches, sprints and sensors and still hashes identically.
**Result.** GREEN on all 24 bosses; determinism 8/8. The soak caught one real bug: two bodies dragged into the same corner collapsed to one point (no facing; the camera's look_at failed) — the sim now keeps bodies 0.7 m apart and peels a double-cornered pair toward center.

## Scoring canon (correction)
Greybox v1–v5 ended a dual on any three drops. NP_01 §3 says otherwise: DROP 1, FLASH DROP 2, SEGMENT KO 3 (three knockdowns in one segment, or a failed count), cumulative across the dual, most points wins, EP breaks ties; a KO forfeits the loser's remaining time and the winner shadowboxes it out for +1 Tension per 10 s. v6 implements the canon and the smoke asserts it (DROP +1, FLASH DROP +2, third drop = KO +3 with the dual continuing into the corner). The second knockdown in a segment removes one beat of standing-eight forgiveness (NP_03 §9).

---

## What this pass does NOT claim
- No cross-platform determinism (float math is engine-native).
- No netcode. The architecture admits rollback; it does not ship it.
- No human-validated tuning. C4 is design margin, not playtest data. The random scripted fighter of the determinism log gets dropped roughly every 20 s and drops the boss about as often — a coverage log, not a balance statement.
- The MODEL cells in the C2 table are consequences of the arc geometry, not sourced boxing consensus; playtests may move a window.
- The PPM/Markov predictor for the tracker is not implemented; the n-gram model stands until a predictor beats it on logged human input, which does not exist yet.
- Low blows and behind-the-head as *player* inputs (the foul ladder exists; only dirty bosses can climb it).
- The clinch duel's cue is a fixed 700 ms beat, not the shrinking cue NP_03 describes; RFX gates the window, not the tempo.

## Reproduction
```
godot --headless --path engine/greybox -- smoke boss=5       # Alfie: referee ladder
godot --headless --path engine/greybox -- determinism
godot --headless --path engine/greybox -- geometry
godot --headless --path engine/greybox -- smoke boss=N      # N = 0..23
godot --headless --path engine/greybox --quit-after 3600 -- demo
python3 pbn_compiler.py --margins
```
Results above: Godot 4.3-stable headless, 2026-09-18, this container.
