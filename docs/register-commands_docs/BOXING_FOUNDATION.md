# True North Boxing — foundational boxing design

**Working implementation design for PAC-204A. Boxing implementation and acceptance remain open.**

This is the connected design for the entire foundational boxing system. It turns the existing game specifications and the user's movement requirements into one implementation contract. It does not replace the vault, reduce its scope, authorize balance changes, or establish that the current game meets the design. Environment and supporting-cast work is stopped while this foundation is repaired and qualified.

## 1. The experience being built

The player controls a boxer who can move, settle their weight, defend, throw a combination, change level, counter and recover as one continuous action. A jab feels quick because the body organizes a short efficient delivery. A power cross feels heavier because the plant, hip turn, shoulder delivery, contact and recovery express its commitment. A slip creates both a believable body position and an actual opportunity to return fire. A successful exchange ends in a usable boxing stance, ready for the next decision.

The camera presents the opponent facing the player, following the Punch-Out framing specified in NP-03. Fight Night Champion informs the connected verbs and their responsiveness. It does not authorize a side-on match camera. The game's arcade character permits expressive timing and exaggerated motion while preserving recognizable boxing mechanics, legible commitments and honest outcomes.

The foundation must be enjoyable with a plain ring and no progression reward. The sandbox, recruitment and team systems depend on it. Their implementation cannot compensate for unsatisfying hands.

### Authority and scope

| Authority | Binding responsibility |
| --- | --- |
| [DOCTRINE.md](DOCTRINE.md), D2–D4 and D8 | Opponent readability; authored offense/adaptive defense; the same verbs at every fight size; no feature removal for convenience |
| [NP-03](../NorthPaw-game_docs/NP_03_COMBAT_ENGINE.md), §§1–12 | Camera, complete input matrix, movement, defense, resources, counters, clinch, feints, counts, adaptation, feedback and tuning ownership |
| [NP-04](../NorthPaw-game_docs/NP_04_OPPONENT.md), §§1–8 | Character-specific tells, legal interrupt windows, learnable strings, bait/punish behavior and Three Souls |
| [NP-06](../NorthPaw-game_docs/NP_06_AFFINITY.md), §1 | Four style packages and their unchanged triangle |
| [NP-13](../NorthPaw-game_docs/NP_13_SCOPE.md), §§2–3, 5–7 | Combat feel precedes opponents and world content; integrated exit criteria and milestone metrics |
| [NP-02](../NorthPaw-game_docs/NP_02_TWO_LAYER.md) and [VS_SCOPE](VS_SCOPE.md) | Preserve the same boxing across scraps, spars, the episode and duals |
| User's boxing instructions in NDL-013/PAC-204 | Snappy arcade fluidity; planted footwork; foot-to-hip-to-core-to-shoulder-to-arm delivery; smooth defense/counter transitions; builds and styles that affect the way fighters move |

The numerical baseline remains `data/combat_tuning.v1.json` and its runtime copy. Existing stat, style, resource, hit eligibility and progression rules remain authoritative. A visual change cannot quietly alter startup, recovery, range, damage, counter eligibility or the price of an action. A discrepancy between a spec and source is recorded and resolved; existing code is not its own design authority.

## 2. One connected exchange

The normal loop is **establish range → read the opponent → defend or initiate → deliver → resolve contact → recover into the next decision**. These are overlapping responsibilities, not disconnected animation clips.

Input selects an intention. The fixed simulation decides when that intention can begin and what it costs. The body expresses the current legal action, including its remaining commitment. Collision and combat resolution decide the outcome. Animation, camera, sound and feedback present that same outcome at the same moment. The next command inherits the body position and remaining recovery of the preceding action.

At every moment the player must be able to answer: where am I balanced, which hand is working, what is the opponent preparing, can I defend now, and what opening did that exchange create? An interface label cannot be the only visible evidence of a punch, block or miss.

## 3. Camera and visible boxing

The production fight camera stays behind and above the player, centered on the opponent with the opponent's head, hands, body and feet readable. NP-03 specifies the 1.8 m chase baseline, 0.6 m head clearance, 12° pitch, 55° FOV, compact player presentation around 35% of frame height and 40% below-shoulder opacity during opponent wind-ups. These values already exist in tuning and must be consumed and measured, rather than bypassed by a second set of hardcoded presentation constants.

Framing, perspective and player representation are solved together. Simply moving the camera farther away, making the entire player almost invisible, or shrinking an opponent is not a substitute for the specified composition. Calibration must cover close range, maximum separation, ring corners, circling, every supported viewport and both fighter builds. If the physical camera values and projected composition cannot be satisfied together, the discrepancy remains explicit at the camera gate; it is not silently rewritten or marked passed.

The player's guard and body state remain understandable. During a punch, that hand's upper arm, forearm and glove remain visible together. A whole-body transparency mask must not erase the arm while leaving a floating opaque glove. Opponent tell visibility has priority over clothing, ropes, player silhouette, particles, HUD and scenery. Foreground clearance applies only to the obstructing presentation and restores correctly when the obstruction ends.

Ordinary fighting has continuous tracking. Camera cuts/holds belong only to the authored DROP, hissatsu, transformation and standing-eight cases. Lateral tracking must preserve opponent orientation and pass the documented motion-salience review; the current 70°/s constant is an implementation choice, not an approved art-bible metric.

Every gameplay review uses this production camera. Side/front inspection cameras can diagnose a foot or elbow, with a visible diagnostic label. They cannot serve as the gameplay demonstration or foundation acceptance evidence.

## 4. The connected body

The user's foot pivot, hip/core rotation, shoulder roll and fist turnover are implemented as eight connected animation responsibilities. This decomposition is an engineering interpretation of the user's instruction, not a claim that the user supplied eight anatomical categories.

| Responsibility | Required visible behavior | Connection to the next responsibility |
| --- | --- | --- |
| 1. Support and plant | Weight settles over a credible support base; the contact foot does not skate | Establishes the foot that can drive or pivot |
| 2. Foot pivot and leg drive | Forefoot contact holds as heel/foot angle changes; knees follow the turn | Drives pelvis rotation and displacement |
| 3. Pelvis and weight transfer | Hip turns and weight moves between the lead/rear support | Carries the torso without dragging planted feet |
| 4. Ribcage/core rotation | Trunk follows and develops the hip turn; it remains connected through bends and level changes | Carries the shoulder girdle |
| 5. Shoulder/scapular delivery | Working shoulder rolls/protracts; opposite side remains organized in guard | Delivers the upper arm without a detached shoulder |
| 6. Upper arm and elbow path | Elbow follows the chosen family and available range | Sets the forearm's line or arc |
| 7. Forearm delivery | Extension/folding and pronation follow that elbow path | Brings the fist onto its intended surface |
| 8. Fist turnover and recovery | Wrist stays aligned; turnover finishes delivery; recoil returns through the connected arm and trunk | Leaves usable balance for defense or the next hand |

These channels overlap. They are not eight serial pauses. A jab has a restrained drive and short return; a committed rear cross and hook express larger rotation. Recovery redistributes weight and folds the elbow into guard instead of reversing an outward arc mechanically. The non-punching hand, head and torso continue to participate.

The render pose interpolates a complete articulated body between fixed simulation samples. Bone lengths, joint connections, planted contacts and fist targets are reconstructed after blending. A smooth glove track does not pass if the elbow flips, shoulder disconnects, knees snap or feet slide. A numerically correct skeleton does not pass if the visible mesh hides the movement or fails to cover the physical striking surface.

## 5. Complete offense

All ten left/right punch rows remain available. Each is assessed at head/body level, close/normal/edge range, both hands, movement and fatigue. The authored startup/recovery table remains in NP-03 §2.1 and the tuning JSON; this design does not create another timing table.

| Family | Delivery and recovery design |
| --- | --- |
| Jab / rear straight | Short direct line, shoulder covering the chin, appropriate hip participation; elbow folds back into a usable guard. The rear cross must express rear-foot drive and torso transfer. |
| Flared straight / overhand | Rising outside route into the target, with corresponding shoulder/torso commitment; controlled return without sweeping through the boxer's own head. |
| Hook | Foot/hip/trunk turn carries the bent arm around the target. Range determines compactness; it cannot become a straight arm moving sideways. Recovery transfers into the opposite hand or guard. |
| Hookercut | Diagonal inside delivery combining rotation and lift; distinct from both the flat hook and vertical uppercut. |
| Uppercut | Leg/body organization brings the bent arm upward inside the opponent's guard; wrist stays aligned, elbow remains credible, and the return folds safely back. |

All five modifiers must work with the same complete body: **BODY, POWER, HAYMAKER, STEPPING and BLOCK_PUNCH**, including legal combinations. Body targeting changes the attack level through the boxer's knees/hips/trunk and arm path. Power/haymaker express their existing additional commitment. A stepping punch spends its legal travel through actual support changes, lands at the resolved target and finishes balanced. Block-punch leaves the current guard pose continuously while the sim removes block eligibility at the correct time.

Distance is expressed through boxing. Inside punches compact their arc. Out-of-range punches visibly miss and recover. Valid hits reach the actual rendered surface without stretching bones, growing fists or moving a stationary opponent to manufacture contact. No hidden reach bonus is added to make an animation look correct.

## 6. Footwork and defense

Movement is relative to the opponent and the existing ring geometry. Advancing, retreating, lateral steps, circling, stopping, reversals, sprint-steps and herding all retain the authored speed/resource rules. The travel-side foot opens space, the other foot gathers, and turns preserve a usable stance. Direction changes redirect the moving foot and transfer support; they do not slide both feet as a single platform.

| Defense | Whole-body action | Legal continuation |
| --- | --- | --- |
| Block | Hands form the correct guard, elbows protect the body, stance absorbs contact | Release, move, or block-punch with the authored cost/startup |
| Slip left/right | Head moves off line through connected knee/hip/trunk motion over planted feet | Counter starts from the displaced pose within the actual window |
| Duck | Knees and hips lower the body; head remains protected and the posture stays usable | Rise into a permitted punch or return to guard; uppercut vulnerability remains real |
| Weave | Continuous lowered head/body arc with the authored lateral reposition | Exit into balanced stance, counter or escape |
| Lean-back | Weight transfers rearward with the specified ground loss; head and torso move together | Return fire from available range or gather the feet before advancing |
| Range step | Real distance change makes the attack miss | Counter eligibility comes from the actual resolved range miss |

Perfect block, ordinary block, clean evasion, mistimed defense and guard break must produce distinct outcomes. Guard movement alone never grants a free block. Visible head motion and the simulated vulnerable region must agree. Guard break/wobble remove or restrict the appropriate options; animation cannot imply a defense that is mechanically unavailable.

## 7. Transitions and player responsiveness

There is one input/intent path for gamepad, keyboard/mouse and the accessibility preset. The existing six-tick command buffer and hitstop handling are preserved unless an authorized tuning change explicitly replaces them. Buffer acceptance, expiry, release-to-feint and execution remain observable and deterministic. Smoothness comes from anticipation and connected pose transitions, not quietly cancelling recovery or discarding inconvenient inputs.

| Transition | Required behavior |
| --- | --- |
| Neutral → move / guard / attack | Immediate readable preparation; no unrelated idle animation must finish first |
| Move → plant → punch | Carry current momentum into a legal support position; obey stepping eligibility and range |
| Punch → opposite-hand punch | Recover the working side while the next side loads; hips/trunk transfer continuously; next contact respects its real startup |
| Punch → same-hand punch | Retract and reload that hand visibly; no teleport back to the start or repeated impact from a held pose |
| Punch → guard / defense | Retain the current hand/body pose, finish legal commitment and blend into the requested defense as soon as allowed |
| Defense → counter | Use the actual displaced head, support foot and coiled side; counter window starts from the defensive result, not an animation marker |
| Hit / block / miss → recovery | Different physical response paths, each returning control at the correct legal time |
| Startup → feint | Unwind the partial action and retain balance; apply the authored 80 ms rule and actual stamina/recovery cost |
| Hitstop → buffered action | Resume both body and input chronology without eating, duplicating or prematurely executing the command |
| Pause / menu / focus loss → resume | Freeze the same fight state, clear stale held inputs and resume without a pose or camera jump |

Combination validation includes alternating hands, repeated hands, changed levels, a defended middle punch, an interrupted sequence and an exhausted return. A successful twelve-command replay is one sample, not proof of the entire transition system.

## 8. Contact, impact and recovery

The authoritative hit event owns contact timing, target, guard/counter outcome, damage and displacement. Presentation reads those facts. Fist surface, defender surface and reaction agree on the contact frame. On a miss, the fist follows a credible missed path; the defender receives no fabricated impact. On a block, contact reads against the guard and the defender absorbs it through arms/body/support.

Impact propagates from the struck region into the body and stance. Strong hits and wobble can require a recovery step. Reactions must not reset an unrelated active limb or overwrite a legally continuing string. The shared freeze clock applies consistently to attacker, defender and contact pose.

NP-03 §11 retains the 40/70/120/200 ms hitstop tiers. Normal jabs do not acquire cinematic camera cuts or large shake. Power/DROP/hissatsu feedback follows its authored budget. Punch sound, impact sound, rumble and counter indication express the same result; tell audio keeps priority. Automated runs use Dummy audio and muted Master. A synthetic sound or software timing result cannot certify final audio performance or physical latency.

## 9. Resources, opponents and fighter identity

Stamina changes real hand speed, foot speed, damage and recovery according to the existing curve. Fatigue must be apparent in the body without adding animation delay beyond the actual rules. Recovery must give the player a useful tactical choice instead of merely waiting for a bar. Composure, wobble, guard damage/break, counter windows and Tension remain connected to the same exchange.

All four styles use the full verb set. Boxer-Puncher remains balanced; Out-Boxer expresses range and economical movement; Swarmer expresses compact pressure and inside work; Slugger expresses heavier commitment and power. Their NP-06 packages and triangle stay intact. Build differences affect authored silhouette, stance and movement identity without silently changing collision dimensions, reach or action timing. Any later physical build/geometry change must update visible body and hit regions together.

Opponent offense remains authored and learnable. Defensive adaptation punishes repetition and narrates the reason. A universal exaggerated shoulder wind-up must not replace an authored subtle gear tell or Cassidy's corner-call dialect. Readability includes the intended channel and the correct opportunity to respond, not merely a glowing glove or text saying that a tell exists.

Clinch entry, the timed scramble, position/reset choice, separation, DROP, standing-eight, rise vulnerability, KO and segment/corner handoff belong to the foundation. They must return the fighter to coherent posture and controls. Scraps, spars, duals, manager-driven fighters and episode fighters consume the same boxing implementation. Existing Tension, relay and technique hooks remain connected; bespoke spectacle development waits for the hands to pass.

## 10. Source responsibilities and observed gaps

| Source | Responsibility in this design |
| --- | --- |
| `sim/core.gd`, tuning and pattern data | Legal action/state, timing, resources, geometry, authored opponent decisions and outcomes |
| `input/combat_input.gd`, `main.gd`, fixed clock | Device intent, buffering, pause/resume and consistent simulation stepping |
| `presentation/boxing_motion.gd` | Connected support, rotation, joint paths, defense and recovery; one coherent pose |
| `presentation/fight_view.gd`, `rig_space.gd` | Render interpolation, geometric alignment, camera composition and visibility |
| `presentation/fighter_visuals.gd`, cast profiles | Visible anatomy/kit attached to that pose, with per-hand visibility classification |
| `presentation/fight_feedback.gd`, HUD and broadcast | Correct event feedback and tell priority |
| Existing native drivers | Regression and measurements; never substitutes for the design's complete playable result |

The current source already contains substantial mechanics. It is retained and reconciled, not discarded for a replacement miniature demo. The following gaps are established by source inspection on 2026-09-29:

1. **Active-arm visibility:** cast upper arms and forearms enter `cast_body`; `FightView.frame` masks that entire set. The opacity decision for an attacking glove does not make its connected arm opaque. Repair per-hand mesh classification and its state transitions.
2. **Player presentation differs from the literal camera specification:** the source applies 40% body opacity in neutral too, multiplies it down to 3.2% inside the clear window, and includes the head. It also uses a variable `look_at` pitch and hardcoded camera constants. Audit the rendered composition against NP-03; do not describe existing constants as full framing compliance.
3. **Coverage endorses an implementation detail:** the cast driver expects every `cast_body` material to carry the same alpha. Replace that assumption with requirements for visible working arms, readable self-state and unobstructed opponent tells across neutral, attack, defense and wind-up.
4. **Completion evidence is too narrow:** the readiness driver checks bounds, limb lengths, cue presence and replay equality. Those are useful invariants; they do not establish convincing movement, complete tell performance or satisfying sustained boxing. Its checks must be combined with the review sequence below.
5. **The shared preview was the wrong evidence:** `film side` explicitly overrides the camera and opacity. A newly captured production-camera replay confirms that normal gameplay uses the behind-player view, but neither clip establishes boxing acceptance.

These are the beginning of the corrective work, not an exhaustive claim that only five issues remain. All listed mechanics and transitions require the integrated review.

## 11. Implementation sequence and single completion boundary

**PAC-204A owns the whole corrective boxing foundation. PAC-204 cannot finish while it remains open.** Existing PAC-202 pass records remain historical evidence for their bounded implementation checks; they do not authorize moving on from the current boxing requirement.

1. **Lock the actual player view and representation.** Resolve the observed camera/opacity/working-arm gaps using NP-03 and D2. Compare production frames across neutral, guard, every attack family, defense and corners. Carry those corrected visibility rules through every cast profile.
2. **Repair the complete connected movement graph.** Review and correct footwork, all ten punches and five modifiers, defense and every transition in §§4–7. Review head/body and close/edge-range contact against rendered surfaces. The deliverable is the whole set working together, not a count of newly added punches.
3. **Integrate exchanges under resistance.** Exercise guard/guard-break, interrupts, counter chains, feints, exhaustion/recovery, herding, corners, clinch, wobble, DROP and rise against the real authored opponents. Correct timing, visual continuity and feedback defects found in those fights.
4. **Qualify style/build and fight-size continuity.** Carry the same controls and body logic through Rory, Priya, Marcus, June, the Three Souls and the Survival cast, with actual stats and outcomes. Exercise scrap, spar, segment swaps and saved/resumed fights. Preserve the existing ecosystem connections without adding unrelated content.
5. **Review the complete foundation from normal launch.** Run the full matrix below, inspect sustained production-camera footage, retain failures and resolve material defects. Keep open any requirement lacking its actual evidence. Environment work resumes only after this foundational boxing boundary is satisfied.

Work can be committed in recoverable increments. A commit, one repaired transition, a green regression suite or a design document is progress within PAC-204A, not completion of the foundation. No requirement is removed to close the task.

## 12. Whole-system acceptance

Use the actual launchable game and controls. Diagnostic fixtures supplement the sessions. Preserve failed runs and distinguish automated command policies from human play.

| Integrated review | What must be demonstrated |
| --- | --- |
| Two Hands, both control schemes | Complete input matrix, buffer/feint boundaries, planted movement and defense→offense transitions against the dummy; enjoyable movement must be assessable with no content reward |
| Live exchanges | Continuous multi-exchange fighting from the production camera, including being attacked, blocked, missed, interrupted, cornered and exhausted; each outcome matches the visible body |
| All families / modifiers | Both hands, head/body, same/alternating hands, moving/standing, inside/edge/outside range; correct commitment, contact and recovery |
| Four styles / actual builds | Shared commands retain meaning while stance, economy and tactical strengths differ; no appearance-specific broken limb, reach or visibility |
| Three Souls and Cassidy | Correct body/gear/audio tells, PI 0 opportunity, authored offense and narrated defensive adaptation; camera/background/effects never defeat the intended read |
| Full fight lifecycle | Clinch, guard break, wobble, DROP, standing-eight, KO, corner and roster handoff remain playable and coherent |
| Render and persistence | 30/60/144 Hz replay consistency; rendered movement at supported viewports; pause/focus/menu and mid-fight save/restore preserve the same exchange |
| Regression | Deterministic sim, all existing bosses, scoring/resources, source recovery and connected episode paths retain their contracts |
| Human and hardware evidence | NP-13 new-player metric populations, perception/feel review, actual input discrimination and physical latency retain their proper evidence boundaries |

NP-13's healthy bands remain unchanged: new-player time-to-first-DROP 60–180 s; counter spread p90 at least three times p10; gassed time present but below 15% of segment time; median adaptation flags 1–3 per segment. Report actual populations and denominators. A scripted driver is not a new-player population. The engine's physical latency/discrimination requirements remain open until measured by the proper method.

An implementer review rejects visible skating, disconnected limbs, arm-only delivery, arbitrary resets between verbs, early/late contact, false misses/hits, unreadable tells, uncontrolled camera shifts, stale inputs and mechanically unavailable actions that appear available. It inspects normal-speed fighting first, then slowed diagnostic views to locate the cause. Fixed-length joints and exact event hashes are necessary checks, not a verdict on boxing quality.

**Current verdict: foundational boxing remains unaccepted. This design defines the connected work to perform; it does not mark that work finished.**
