# True North Boxing Foundation and Northern Rising

## Purpose and authority

This is the boxing-foundation design and integration specification for the existing True North Boxing game. It is not a new-project proposal and does not authorize replacing the current engine, rebuilding unrelated systems or adding a separate demonstration game.

The target is fluid, responsive, strategic arcade boxing grounded in recognizable boxing mechanics. The player must enjoy the unadorned exchange: move the body, read a punch, block or evade, return a punch or combination, change the angle or range, and recover. Later abilities, progression systems and shonen presentation build on that exchange.

This specification supersedes the earlier gym document wherever that document introduced family conflicts, incidental exposition, unnecessarily restrictive simulation assumptions or mechanics incompatible with this brief. The international gym translations remain source material for later style composition. Their fictional rivalries are not implementation requirements. Northern Rising is the Canadian foundation defined here.

The supplied descriptions and stance reference are authoritative design inputs. Proposed bindings, equations, sample tuning values and implementation boundaries are recommendations for realizing those inputs, clearly identified below. They must be mapped to the actual repository before code changes. No repository was inspected for this document; no engine implementation, playtest, measured latency or achieved game feel is claimed.

## Scope

### Build now

- Continuous body control and responsive punch input.
- Anatomically coherent full-body movement, including working feet and support.
- A first-person combat camera situated in the world.
- Bounded range changes, exit steps and angle changes.
- Punch trajectories, impact, defence, recovery and transitions.
- Combinations supported by body position and timing.
- Counter opportunities produced by actual openings.
- Baseline fatigue, balance, damage, stagger and knockdown interactions needed to complete a boxing round.
- Northern Rising as the first complete expression of the common foundation.
- Reusable character, trait, skill, style, move and signature data.
- A development sandbox using the same combat system as the actual game.
- An integration plan and observable completion criteria.

### Retain as future context

The broader game will add substantially deeper skills, abilities, progression and shonen expression. Preserve extension points for those systems, but do not implement chakra analogues, special powers, clan stories, new world campaigns or the example 6ix Slide style during this foundation pass.

The existing game's broader systems remain intact. Preserve their interfaces and behavior except where a concrete combat integration requires a documented change.

## Northern Rising

### The minimum history that determines mechanics

In this universe the United States dominated boxing through a much larger competitive population and development pipeline. Canada could not reliably overtake that population by competing only to maximize the same conventional methods.

Canada pursued quality through a different technical emphasis. Northern Rising developed into an unusually mobile counterpunching school built around rangy rising attacks, compact uppercut combinations and decisive exits. Its success changed international training and helped make Canada the world boxing hub.

In the modern era, opponents have caught up. Northern Rising remains a living base style, usually complemented by other defensive, movement or punching methods. This history explains the system's emphasis on reusable hybrid construction. It is fictional history, not a claim about real Canadian or American boxing.

### Identity

Northern Rising is what the user describes as Roy Jones Jr. reimagined as an uppercut specialist: technical, expressive, deceptive and capable of sudden acceleration, with protected hand placement and an emphasis on controlled recovery.

Its central rhythm is:

**Read or provoke → move off the attack → rise through the available lane → continue only while position supports it → step outside the return → retain a useful stance.**

A Northern Rising fighter must still jab, cross and hook. Uppercut specialization changes preferred routes, preparation, transitions and opportunities. It cannot turn every input into an uppercut or make uppercuts a universal answer.

### Stance specification

Use the supplied connor-stance-1.png as a reference for the broad staggered, side-on relationship of the body and bent extended lead arm. Apply the user's corrections. Do not copy the photograph unchanged.

The image is not a calibrated motion capture sample. It establishes visual intent; it does not determine exact joint angles, handedness for all characters, contact forces or movement timing.

| Element | Northern Rising requirement | Mechanical consequence |
| --- | --- | --- |
| Base | Staggered, moderately bladed, mobile and grounded | Supports small weight shifts, diagonal exits and a real rear-hand punching route |
| Rear glove | Close to the jaw and cheek, with a protective elbow position | Provides a dependable defensive home and short preparation for the rear uppercut |
| Lead upper arm | Forward of the torso without a locked shoulder | Creates a recognizable reaching silhouette without maximum extension |
| Lead elbow | Bent and available to lower or fold into a rising path | Allows a short uppercut preparation and a working parry |
| Lead forearm | More upright than the reference, angled upward rather than drooping | Makes the rising-hand identity visible before a punch |
| Lead glove | Forward and below eye level, with the fist's thumb side generally uppermost | Provides an uppercut-ready resting orientation; the wrist stays supported |
| Chin | Tucked enough to protect and see | Avoids a copied head-up, hands-low caricature |
| Torso | Relaxed readiness with a small load available either side | Supports smooth slips, pulls and rising returns |
| Feet | Full support and pivot state, even when off camera | Grounded entries and exits have actual mechanical meaning |
| Mirroring | Lead and rear roles work in orthodox and southpaw | Handedness changes roles without creating a second engine |

Thumb-up describes the resting glove orientation, not an extended thumb or mandatory impact orientation. The glove rotates as needed for a supported knuckle-first strike. Do not bend the wrist unnaturally to maintain a graphic pose.

The lead glove must remain visible enough to communicate the style in player view without obscuring the opponent's torso. In observer view the elbow, forearm and rear-glove placement must make the school recognizable without costume.

### Range model for rising punches

A rangy uppercut has meaningful forward reach and an upward component. It is not a close uppercut with the arm stretched farther or a glove that curves around a guard after launch.

Its reach comes from a compatible combination of stance, shoulder position, elbow opening, body rise and, where the move permits, a short step. It should generally be more exposed and more recoverable by the opponent when mistimed than a compact uppercut.

The longest rising variant may resemble a diagonal uppercut or shovel-like rising straight in trajectory. Preserve the rising attack identity without pretending every long attack is a perfectly vertical uppercut.

| Move family | Purpose | Mechanical preparation | Main cost or exposure |
| --- | --- | --- | --- |
| Lead probe uppercut | Threaten a rising lane from the extended lead position | Small elbow drop and supported lift, limited travel | Limited impact if thrown without useful body support |
| Long lead rising punch | Intercept an entry or reach an opening at mid-long range | Controlled body shift and diagonal forward-up trajectory | Exposes the lead side and has a longer recovery when missed |
| Long rear rising punch | Punish a committed entry or a raised central guard opening | Rear-side preparation, coordinated turn and rise, optional short step | Larger commitment and a clear return window |
| Compact lead uppercut | Work inside after a slip or blocked straight | Short knee and torso contribution with tight arm path | Vulnerable to the opponent's other hand if the guard is abandoned |
| Compact rear uppercut | Counter in the pocket or continue a head-body exchange | Rear glove leaves the jaw through a short available lane | Rear-side coverage opens while it travels |
| Body uppercut or shovel variant | Attack permitted torso targets | Appropriate level and target selection | Lower target changes defensive coverage and return path |
| Hook-to-uppercut transition | Change the plane of attack | Controlled recovery and reloading after the hook | Cannot skip deceleration or repositioning |
| Uppercut-to-hook transition | Follow a rising attack with a lateral one | Arm and torso arrive at a compatible hooking position | A wide unsupported follow-up must be weaker or slower |
| Exit jab or short hook | Cover a range or angle exit | Punch coordinated with an allowed step | Cannot add full stationary power to an unsupported retreat |

Define these as variations of shared punch families. Their authored preparation, trajectory, support demands and recovery distinguish them. They are not nine independent input systems.

### Signature compositions

These are foundation-level signature examples, not supernatural abilities and not automatic canned combos.

**Northern Rising.** A measured pull or outside slip invites a straight; a long rising counter takes the available lane; a controlled diagonal exit leaves the fighter outside the immediate return. It succeeds only if range, timing and recovery permit.

**Northern Ladder.** A compact lead uppercut leads into a compatible rear uppercut, followed by an optional short hook or exit. Each punch has its own commitment and impact. A missed first punch, a block or incoming interruption changes the continuation.

**Rising Exit.** An inside rising punch is followed by an outward step and covering jab or hook. The exit must move the feet and root. Moving the camera backward is not an exit.

The same signature can look different on two characters because their reach, stance, skill, speed, recovery and secondary style differ. The family identity survives those differences.

### Intended strengths and vulnerabilities

Northern Rising rewards reading commitment, smooth head movement, changing attack height and controlled departure from the pocket. It is less forgiving when crowded without support, repeatedly intercepted during preparation or forced to recover from long rising misses.

Under the user's balance direction, a highly agile Northern Rising build spends more of its build capacity on evasion, angle frequency and recovery, leaving less for durability, stagger resistance and sustained collision-heavy exchanges. This is a game-build tradeoff, not a biological rule about every real counterpuncher.

Movement is not invulnerability. A pull may avoid a hook but remain vulnerable to a stepping straight. A dip can enter an uppercut. A long uppercut can be beaten by a jab or leave an opening after a miss. Outcomes depend on the actual exchange.

## Fight Night Champion reference

EA's Xbox 360 manual documents right-stick Full Spectrum Punch Control, a lean/body modifier, a block modifier and a power modifier. Its punch wheel contains left and right straights, flared straights, overhands, hooks, hookercuts and uppercuts. The manual also describes planted leaning, quarter-circle weaving and stamina affecting movement.

For its default Xbox layout, LT is lean/body, RT is block and RB is power. The user's right-bumper example expresses the desired modifier principle; it should not be mistaken for the game's documented default block binding.

Champion's directional punch selection should not be conflated with every earlier Fight Night game's gesture system. True North adopts the accessibility and responsiveness goal, not a claim to reproduce EA's internal animation or physics implementation. Source: EA manual, printed pages 3–8, linked in the references.

The following are design conclusions for True North, not verified reverse engineering of Fight Night:

- A small set of understandable controls can express varied actions when position and context matter.
- An accepted input should immediately communicate intent even when a punch still has a physical wind-up.
- Defence should naturally prepare or expose a return, rather than force a reset to idle.
- Motion must preserve the causal relationship between support, body action and the glove.
- Impact needs clear sound, pose and reaction, but presentation cannot conceal bad contact.
- Countering feels satisfying when the player recognizes an opening and acts through it.
- Increasing physical detail must not impose a separate manual input for every joint.

True North intentionally differs in its constrained encounter movement, first-person view, stronger arcade allowance and future character sandbox. It does not inherit Fight Night's free ring navigation as a requirement.

## Continuous control model

### What two circular controls mean

The foundation has two independent two-dimensional inputs: one for body intent and one for punch intent. Together they provide four scalar input channels, not a literal two-degree-of-freedom skeleton.

Each input occupies a continuous disk. Its angle specifies direction and its radius specifies displacement or commitment within an allowed range. Eight named body directions are teaching landmarks on that disk, never eight snapped animation states. A 360-degree input does not authorize a 360-degree spinal turn, detached shoulders or a fist moving in any arbitrary world direction.

The body is a coordinated articulated system with many joints. The controller supplies understandable intent; the movement system solves a plausible coordinated result within the fighter's support, mobility and current action.

### Proposed default gamepad layout

This is a concrete starting layout for the existing game, not a statement that it already uses these bindings. Bind through actions so the layout can be changed without rewriting combat.

| Input | Unmodified meaning | Modifier interaction |
| --- | --- | --- |
| Left stick | Continuous body movement: lateral slips, forward-down compression, backward pull and combinations | Holding LB requests a bounded footwork step in the same directional vocabulary |
| Right stick | New directional strokes request punches; direction selects hand and trajectory family | LT selects body target; RB selects committed power; RT permits punching from a guarded state |
| RT held | Maintain the selected guard, subject to arm position and current action | LT plus RT lowers emphasis toward body coverage; left-stick motion still moves the body |
| LT held | Body target for punches and body emphasis for held guard | Does not force a dip and does not consume the left stick |
| RB held | Greater punch commitment with corresponding effort and recovery | Does not charge infinitely or bypass support |
| LB plus left-stick stroke | Short entry, retreat or lateral/diagonal angle step | A sustained hold does not produce endless travel; neutral return rearms another step |
| Face-button alternative | Optional equivalent jab, cross, hook and uppercut requests | Uses the same resolver, physics, costs and outcomes |
| Stance-switch action | Controlled switch if supported by the current fighter and phase | A committed move's hand identity never changes in mid-flight |

Right-stick left means the fighter's anatomical left hand in the proposed default. Orthodox versus southpaw determines whether that is lead or rear. Offer a lead/rear-relative remap only as an explicit setting. Never silently mirror controls because a camera crosses a world axis.

RT does not repurpose the right stick into an incompatible guard-only mode. The player can lean, hold a guard and initiate a punch together. The attacking glove leaves its coverage normally; the other hand protects only what its actual position can cover.

While LB is held, the left stick temporarily describes the step request rather than an unlimited lean. The current body pose settles through a short supported transition and resumes live body control on release. This tradeoff is intentional and visible. It prevents accidental angle steps during ordinary weaving and avoids the need for a third analog stick.

A step request during a committed punch may execute only in a compatible step-punch transition or a valid recovery window. Otherwise retain at most one fresh buffered step for a short expiry. Do not teleport or queue a long chain of exits.

### Body disk mapping

Define user input y positive away from the stick centre toward the top of the controller diagram. This convention must be converted explicitly from the platform API.

| Disk direction | Body intent | Required coordination |
| --- | --- | --- |
| Left | Slip left | Lateral displacement with appropriate trunk movement and support adjustment |
| Right | Slip right | Mirrored coordination |
| Up | Forward-down compression or dip | Knee and hip flexion lower the target while keeping vision and guard plausible |
| Down | Pull back | Controlled rearward movement of the upper body, with support constraints |
| Upper diagonals | Dip and slip | Smooth coupled lateral and downward motion |
| Lower diagonals | Pull and slip | Rearward and lateral movement without unsupported twisting |
| Centre | Return toward usable neutral | Recover from the current pose, not a hard snap |

Up does not mean lowering the head through neck flexion alone. Down does not mean moving the whole fighter backward automatically. Translational steps use the step action.

The mapping is intentionally not a linear relation between stick y and head height: both a pull and a dip can lower the head slightly, but they differ in depth, trunk inclination and support. Use a continuous authored mapping or blend surface with those distinct endpoints.

A minimal mathematical contract is:

```text
r = length(raw_body_stick)
u = radial_deadzone(raw_body_stick, deadzone, response_curve)
body_goal = BodyEnvelope(u, stance, support, fatigue, mobility, move_phase)
body_pose = responsive_constrained_follow(current_pose, body_goal, dt)
```

Radial processing must preserve diagonal direction and cap radius uniformly. Avoid independent square-axis clipping that makes diagonal movement faster. Filtering should remove device noise without adding a long easing delay.

Use a critically damped or otherwise well-behaved response with bounded velocity and acceleration. An illustrative position servo is:

```text
acceleration = omega^2 * (goal - position) - 2*zeta*omega*velocity
```

This is a game controller, not a biological equation. Joint limits, support and discrete-time stability still apply. A timestep-robust integration method matters more than blindly copying the formula.

Returning the stick through a semicircle creates a continuous weave path through valid poses. It must not select a roll animation that ignores the rest of the input until completion.

### Punch disk mapping

Punching is an intent stroke followed by a committed physical action. The right stick is not a one-to-one positional puppet for the glove: direct unbounded glove control would break reach, momentum and collision consistency.

Proposed six-family angular map, measured clockwise from stick-up:

| Angle | Requested family |
| --- | --- |
| 0 to less than 60 degrees | Anatomical right straight |
| 60 to less than 120 | Anatomical right hook |
| 120 to less than 180 | Anatomical right uppercut |
| 180 to less than 240 | Anatomical left uppercut |
| 240 to less than 300 | Anatomical left hook |
| 300 to less than 360 | Anatomical left straight |

These sectors are a proposed usable default, not the exact diagram from Fight Night. Intermediate angle within a sector can vary punch plane within authored limits. A later 12-lobe preset can distinguish overhands, flared straights and hookercuts without changing the move model.

Exact boundary ties use the half-open intervals shown. Near a boundary, selection hysteresis prevents noise from changing an already acknowledged intent. Neutral cancels an uncommitted candidate; it does not erase a committed punch.

A fresh stroke crosses an activation threshold after the stick has returned below a lower rearm threshold. Holding the stick at its rim produces one punch, not automatic repeated attacks. Rotating a held stick may shape an eligible uncommitted candidate, but does not manufacture new punches every frame.

Prototype examples are an activation radius around 0.6 and rearm radius around 0.25. These are tuning seeds, not required constants. Rebinding, alternative button inputs and a stick visualizer must make the final response inspectable.

Do not force the player to finish a slow half-circle before a punch can begin. Recognize the available directional intent promptly. Use limited early trajectory shaping, then stop steering before contact. No homing uppercut is allowed to change families midway around an opponent's guard.

LT determines target intent at commitment. Releasing it later does not teleport a committed punch from torso to head. RB increases commitment only while the preparation remains adjustable. Body posture influences reachable paths, but it never silently switches a requested left uppercut into a right hook.

### Input ownership and buffering

Every request receives a timestamp, source, intended hand, family, target, commitment and resolved outcome. The resolver accepts it now, buffers one request within a bounded window, or rejects it with a specific reason.

The queue is shallow by design. It must not execute three stale punches after the player has stopped attacking. Changing defence intent can discard an uncommitted queued attack according to one documented priority policy.

Use action-specific transition windows instead of a universal cooldown. The decision to continue is based on move phase, arm availability, torso state, support and interruption. Responsive input does not mean impossible instant execution.

Current-step intent, current body motion and current punch intent have separate ownership. Neither animation events nor camera shake may emit an extra punch.

## Encounter space and camera

### A bounded boxing encounter

The fight exists in a real world coordinate system, but the player does not use free continuous circling as the core navigation loop. Most strategy occurs within an engagement: pocket positioning, small range changes, reactions and discrete committed angle actions.

Both fighters retain independent world position, orientation, feet and velocity. Range and angle are derived from those states. An encounter coordinator can keep them in a useful engagement, but cannot force them into a permanent screen-space arrangement.

Distance bands such as pocket, middle and outside are tactical labels over continuous separation and reach. They are not teleport lanes. One fighter's middle range can be another fighter's edge of reach.

| Action | Root movement | Body movement | Tactical effect |
| --- | --- | --- | --- |
| Slip | None or minor support correction | Head and torso move off a line | Evade while retaining range |
| Dip | Usually little translation | Coordinated vertical compression | Change target height and load selected counters |
| Pull | Limited root shift | Rearward upper-body displacement | Make a short attack fall short |
| Weave | Little or authored small translation | Continuous curved body path | Pass under an eligible punch and prepare a return |
| Exit step | Actual backward or diagonal step | Body settles over the new support | Increase effective separation |
| Angle step | Actual lateral/diagonal step and facing change | Coordinated torso and guard recovery | Change relative attacking lanes |
| Entry step | Actual approach | Punch or guard coordinates with step | Enter useful range with exposure |
| Pivot | Feet and orientation change around an appropriate support | Upper body follows with controlled separation | Reorient without sliding both planted feet |

Agile builds can perform useful angle changes and exits more frequently and recover faster. Those actions still need space, effort and support. Pocket builds spend more time holding productive range and have greater stability under selected impacts.

At the ropes or corners, geometry constrains movement. Resolve a shortened step, blocked exit or allowed alternate route explicitly. Do not silently teleport through the boundary or make the ring wall drag the opponent.

### Coordinate responsibilities

Maintain distinct coordinate frames:

- World frame for ring geometry, independent roots and collision.
- Fighter root frame for locomotion and stance.
- Anatomical/stance frame for lead/rear and left/right role mapping.
- Engagement frame for the current opponent direction and tactical range.
- Camera frame for rendering and user-visible projection.

Direction-sensitive combat code must name the frame it uses. A hardcoded global left/right or fixed opponent world position is not acceptable.

An existing engine can implement these responsibilities without creating five new managers. Preserve its architecture when it already expresses the separation clearly.

### Player point of view

The camera follows a stabilized eye anchor belonging to the fighter. It translates and turns when the fighter steps or takes an angle. It is not the world origin, a fixed spectator camera or the source of the fighter's simulation transform.

A useful relationship is:

```text
camera_world = fighter_root_world
             * stabilized_body_eye_anchor
             * presentation_offset
```

Use transform composition rather than adding arbitrary world offsets. The actual anatomical head remains the gameplay head; the camera can filter uncomfortable roll and small vibration without changing the hit volume.

Aim the view toward a combat focus derived from the opponent's head and upper torso, with limited angular speed and assistance. Do not rotate the fighter for free merely because the camera wants to maintain framing. If the opponent takes an angle, their displacement and the player's reorientation must be perceptible.

Do not rigidly attach all camera rotation to the head bone. That can turn correct body animation into unreadable camera motion. Conversely, suppressing all displacement makes an angle change visually false. Keep meaningful position and facing changes while damping nonessential roll and shake.

Field of view and camera offsets belong to presentation tuning. They must not secretly extend punch reach or alter impact tests. Near-camera arm rendering may need projection adjustments, but a separate viewmodel cannot depict a hit while the authoritative glove misses.

### Required world invariance

Rotate and translate the entire encounter, including both fighters and the ring, then replay the same fighter-relative inputs. Relative range, impacts, counter opportunities and movement costs should remain equivalent within the existing engine's numeric tolerance.

Repeat with swapped player and opponent roles and with mirrored stance. This catches shortcuts that only work when one fighter faces a particular global direction.

A view transform test alone is insufficient. Verify the actual attack, guard and body coordinates under those transformations.

## Body mechanics

### Translate coaching intent into implementable mechanics

The user's central requirement is correct: a punch must be a coordinated body action, not an arm moving forward. The engine must preserve the visible relationship among support, leg action, pelvis, trunk, shoulder, arm, glove and recovery.

A few terms in the supplied explanation should be implemented carefully. The shoulders and hips coordinate but are not rigidly parallel throughout every punch. Upper- and lower-body timing can differ. The biceps do not universally slingshot the fist; elbow extension, shoulder motion, forearm orientation and stabilization vary by punch. Centrifugal force is not a sufficient model of punch generation. Foot pivots are important in many punches but are not identical, mandatory first motions for every jab, hook and uppercut.

Research comparing cross, hook and uppercut execution reports punch-dependent joint contributions and differences between athletes. This supports coordinated, punch-specific motion rather than one fixed sequence of maximum rotations. It does not supply ready-made game damage multipliers.

### Eight authored movement checkpoints

The excerpts demand eight points but explicitly enumerate four biomechanical descriptions. The following eight checkpoints are a proposed implementation breakdown of that intent, not a claim that the user already listed these exact eight.

| Checkpoint | State that must exist | Visible or tactical consequence |
| --- | --- | --- |
| 1. Foot contact and support | Planted, pivoting or stepping foot; support footprint | No foot skating or unsupported power |
| 2. Leg drive and level | Knee/ankle contribution, compression and rise | Dips and rising punches involve the lower body |
| 3. Pelvis motion | Translation, yaw and weight-shift phase | Entry and punch have a body source |
| 4. Trunk coordination | Rotation, inclination and controlled separation from pelvis | Hips and shoulders cooperate without moving as a rigid block |
| 5. Shoulder girdle | Shoulder path and protraction/retraction as appropriate | Reach and glove route emerge from more than elbow animation |
| 6. Arm delivery | Elbow bend/extension and upper-arm route | Jabs, hooks and uppercuts remain mechanically distinct |
| 7. Glove alignment and contact | Wrist support, knuckle orientation and contact trajectory | The scoring surface meets the target plausibly |
| 8. Deceleration and recovery | Return, braking, reloading and next support | A combination can flow or break for a real reason |

All eight apply as responsibilities, not as eight sequential delays. Many overlap. A short jab should not wait for a cinematic rear-foot twist before it can move.

### Foot and support model

Maintain a canonical lower-body state even if feet are hidden in the default camera. The simplest sufficient solution may use authored stance and step trajectories with inverse kinematics and a support model. A full muscle simulator is not required.

At minimum track each foot's pose, contact state, allowed pivot, intended next landing and whether a step currently commits the body. Track the centre-of-mass proxy and a support margin or equivalent stability measure. Do not claim that a scalar support score is measured human biomechanics.

A planted foot can rotate around an appropriate contact region; it cannot slide arbitrarily while labelled planted. Stepping feet need lift, travel and landing. The body can travel with an authored step, but the system must have one owner of root displacement.

If animation root motion owns a step, collision and movement systems consume that displacement. If the simulation owns it, the animation follows. Applying both is a double-movement bug.

### Punch-specific movement

**Jab.** Often uses relatively little trunk rotation, with useful shoulder motion and optional stepping. It can probe, interrupt or cover an exit. Low commitment is a feature, not a failure to animate the kinetic chain.

**Cross.** Usually combines rear-side drive, coordinated rotation and a direct hand path. The rear hand's recovery affects defence. Do not force all weight onto the lead foot in every version.

**Hook.** Links support, torso rotation, shoulder and bent-arm travel. Range changes its elbow shape and path. A hook that crosses through the opponent's body to reach the far side is a collision failure.

**Uppercut.** Combines an available rising lane with leg, trunk, shoulder and arm action appropriate to the chosen variant. It does not require dropping the glove to the hip. A rear uppercut can begin from a protective jaw position after a small preparation.

**Rangy rising punch.** Adds forward travel and controlled elbow opening. It has different reach and recovery conditions from a pocket uppercut. Its arc remains reachable for the character's limb lengths.

**Overhand and shovel-like variants.** Use compatible diagonal routes. They remain bounded adaptations with proper contact orientation, not arbitrary curves between any two points.

### Why combinations connect

A combination links the end of one action to a useful preparation for the next. The relationship may involve alternating rotation, a short reload, a change of level, a step or simply the return of the other hand to cover.

| Sequence | Why it can connect | What must remain possible |
| --- | --- | --- |
| Jab → cross | The lead hand probes and recovers as the rear side delivers | The cross cannot launch through an unavailable support state |
| Cross → lead hook | Recovery and reorientation can prepare the lead-side arc | The body must brake and redirect, not spin indefinitely |
| Lead hook → rear uppercut | The changed orientation can create a rear-side rising lane | Elbow route and guard clearance must fit |
| Rear uppercut → lead hook | A compact rising finish can leave a useful lateral follow-up | Avoid wrist and shoulder snapping between unrelated clips |
| Lead uppercut → rear uppercut | Alternating compact preparations can work inside | Each hand needs actual space, support and recovery |
| Double jab | The same hand retracts and fires again with modest commitment | Same-hand use remains valid and is not globally punished |
| Double hook | A real recoil or reload supports a repeated hand | No instant same-hand reversal through the target |
| Punch → exit | The punch can cover or prepare departure | The feet and body must actually execute the exit |
| Slip → punch | A defensive shift can leave a useful loaded position | An extreme lean may instead require settling first |

Do not hardcode jab-cross-hook as the only mechanically legitimate sequence. The resolver must examine present state and the requested continuation. Legal awkward choices may execute with less power or slower recovery; impossible choices wait briefly or fail explicitly.

### Rotational momentum and the slugger example

The user's alternating-hook example belongs as a trainable rhythm mechanic on an appropriate build or trait. It is not a universal rule that left-right-left always gains physical momentum.

Alternating hooks reverse rotational direction. The fighter decelerates and reaccelerates. Game reward should represent coordinated reloading and sustained productive rhythm, not conservation of angular momentum through a sign reversal.

A possible bounded game model is:

```text
quality = timing_fit * support_fit * range_fit * posture_fit
chain_credit += gain * quality       when the trait's compatible link completes
chain_credit *= interruption_decay  when disrupted
chain_credit = clamp(chain_credit, 0, trait_cap)
```

All fit terms are normalized authored evaluations, not empirical human constants. A hard chain break can clear the rhythm bonus while leaving the fighter's actual movement state intact.

For the specific alternating-hook trait: a correctly timed opposite-hand hook continues the pattern; a same-hand hook, unrelated attack, long pause, missed transition window or significant interruption breaks its bonus. The same-hand hook can still be a valid boxing action. Missing the opponent should not automatically build full credit through shadowboxing into empty space.

Benefits may be modestly faster compatible recovery or improved effort efficiency, with capped impact benefit. Costs remain rising fatigue, readable rhythm and exposure to interruption. A fresh slow start is restored after a genuine reset.

Northern Rising instead emphasizes efficient rising counters and departure. It must not receive the slugger's accumulating hook advantage for free.

## Move execution and animation

### A shared action lifecycle

Each move defines preparation, commitment, delivery, contact opportunity, recovery and available continuations. These are semantic phases; they need not map one-to-one to separate animation clips.

Before commitment, intent can shape the action within its authored range. After commitment, direction and target assistance are bounded. During recovery, selected next actions become available when the body can support them.

No universal idle reset is required between moves. No universal instant cancel is permitted either.

A continuously requested body offset can contribute during a punch, but its allowable envelope changes by phase. The system must communicate a constrained lean through the fighter's actual motion rather than visually leaning the camera while the body remains upright.

### Recommended motion approach

Use the current project's best viable animation architecture, with a hybrid solution where needed:

- Authored or captured motion defines recognizable coordination and timing.
- Continuous pose blending or procedural corrections adapt lean, range and current stance.
- Inverse kinematics maintains foot placement, hand reach and joint limits.
- Inertialized or equivalent continuity-preserving transitions avoid visible pose pops.
- Collision-aware corrections constrain the final pose without inventing new movement authority.

Pure clip playback commonly fails continuous controls; pure unconstrained procedural hands commonly fail body coherence. These are risks to solve in the existing system, not instructions to replace a working solution because it uses one of those techniques.

The simulation's canonical pose must drive gameplay hit volumes. Cosmetic motion may add small secondary detail, but cannot change where the player appears to be hit. Presentation-only arm changes require a bounded, inspected correspondence to authoritative glove position.

### Transition continuity

At a link, preserve current pose and motion where physically useful. Do not blend straight through a completely unrelated neutral pose. Match the next motion's entry to current hand location, trunk orientation, support and velocity.

Bone transforms require continuous position and rotation; abrupt changes in velocity should occur only where impact, braking or deliberate stylization justifies them. Constant long blends can look smooth yet feel sluggish. Smoothness means coherent motion with prompt response, not maximum interpolation.

The non-punching hand is part of the move. It returns, covers or changes guard according to the actual sequence. Never animate both gloves away from protection simply because each arm has an independent punch clip.

### Reactions and interruption

Use graded reactions: glance, guarded impact, clean contact, balance disturbance, meaningful stagger and knockdown. They need direction, intensity, timing and recovery.

A small hit need not cancel every attack. A major stagger can interrupt. An interrupted glove does not finish a phantom damage event because an animation timer later fires.

Two committed punches can trade. If one fighter lands first by a tiny amount, cancellation of the other must depend on the reaction and the second punch's phase, not a universal first-hit-wins rule.

## Contact and defence

### Authoritative hit resolution

A punch lands because its active scoring surface intersects a valid moving target, not because a timer expires or the opponent is inside a broad distance threshold.

Sweep the glove's scoring volume through its authoritative path over the simulation interval. Use continuous collision detection or sufficient temporal subdivision against moving head, torso and defensive volumes. A fast punch must not tunnel through a moving guard between frames.

Resolve the earliest relevant contact along the path. A glove or forearm that intercepts the punch must be considered before the head behind it. Prevent repeated damage from the same attack resting inside the same target.

Targets use actual pose-derived locations. Head slips move the head target. Body compression moves the torso targets. A purely visual dodge with a stationary hitbox fails the foundation.

One shared contact result supplies impact reaction, damage, sound, controller feedback, particles and replay information. Separate presentation raycasts must not contradict the adjudicated hit.

### Defence meanings

| Defence | Required event | Result |
| --- | --- | --- |
| Block | A real guard surface intercepts the attack with adequate structure | Reduced or prevented clean impact; effort and positional effects remain possible |
| Catch | Glove placement meets a suitable incoming punch | Short defensive contact with an opportunity determined by recovery |
| Parry or deflection | Correctly timed directional contact changes or clears the attack line | Creates a situational opening, not a guaranteed free hit |
| Slip | Target moves outside the relevant punch path | The punch misses if it truly fails to intersect |
| Pull | Target moves beyond useful reach | A stepping or longer punch may still connect |
| Dip or weave | Target height and lateral path avoid a suitable attack | Can expose the defender to body shots or uppercuts |
| Shoulder roll | Guard, torso orientation and timing support deflection | Works only for appropriate incoming geometry and current stance |
| Exit or angle step | Fighter moves to a different range or line | Requires time, support and available ring space |

Holding guard provides coverage that exists in the pose. It cannot block an opposite-side opening merely because a boolean is true. Blocking from a stretched or moving position can be weaker. Guard fatigue cannot be a permanent global debuff that ignores which arm is actually working.

A guard assist may select a plausible local adjustment from visible attack information. Its limits must be explicit. It must not read hidden opponent inputs or automatically create perfect parries.

### Counter opportunities

A counter opportunity is a time-and-position relationship. An attack can leave the opponent committed, off line, recovering or with a particular side uncovered. The defender must still choose a reachable return in time.

Derive the opportunity from the opponent's action phase, exposure, current geometry and recovery. A narrow timing bonus may sharpen arcade reward, but never bypass obstruction or turn a miss into a hit.

Do not award counters merely because the player pressed dodge shortly before attack. Do not freeze an opponent into vulnerability because a generic dodge-success event fired. Hit-stop and brief emphasis are presentation tools, not a replacement for the exchange.

### Stamina, stability and damage

Keep meanings distinct even if the UI shows fewer bars.

- Short-term effort affects repeated output and immediate recovery.
- Accumulated fatigue affects sustainable movement and output over a round.
- Guard condition affects the quality of continued defensive contact.
- Balance or stability affects resistance to displacement and stagger.
- Damage and stun affect the consequence of clean hits and recovery.
- Skill affects economy, consistency and usable transitions.

A tough pocket build can show less stagger under the same moderate impact without receiving less damage in every situation. An agile build can avoid the contact but cannot erase a clean hit once taken.

An arcade impact evaluation can combine supported delivery, relative contact velocity, alignment, target and defence. If using a gameplay score, label it as such. Do not call an arbitrary multiplier a measured force in newtons.

Physical impulse is related to change in momentum; hit energy is related to effective mass and relative speed. Neither alone is a complete model of pain, injury, knockdown or game balance. Use bounded authored outcomes, inspectable inputs and consistent collision.

### Arcade expression

Permit stronger silhouettes, sharper anticipation-to-delivery contrast, readable hit reactions, forgiving input recognition and generous but bounded transition opportunities. Preserve consistent body causality and opponent counterplay.

A large rising punch can be exaggerated in presentation, but it must retain plausible support and a readable path. A signature may look spectacular without becoming a cutscene that suspends defence.

Impact emphasis should scale with actual contact. Whiffs, guard hits and clean head shots need different feedback. Camera shake cannot substitute for body recoil. Screen effects must not obscure the next actionable beat.

If time dilation or hit-stop is used, define its effect on input sampling, buffers, animation, simulation and both fighters. It must not generate duplicate impacts or grant one side extra hidden input time. Keep it minimal or absent in the baseline until the ordinary exchange feels good.

## Character and boxing sandbox

### The fundamental composition

A character is a resolved composition of physical configuration, learned capabilities, style choices and behavior. A style is neither the whole character nor a single animation preset.

| Record | Owns | Must not own |
| --- | --- | --- |
| Character definition | Identity, body configuration, progression state and references to chosen training | A copied combat engine or custom punch logic for every named boxer |
| Physical profile | Limb proportions, stance dimensions, mass category and motion limits | Automatic claims about personality, ethnicity or nationality |
| Attribute profile | Current capacities and trainable ceilings for output, mobility, stability and endurance | Unlimited gains without tradeoffs |
| Trait definition | A bounded rule that modifies an allowed interaction | Arbitrary callbacks that bypass collision or support |
| Skill proficiency | How well a character performs a trained family or decision | A replacement for the player's actual timing |
| Style definition | Default stance, movement envelopes, guard preferences, move variants and teaching emphasis | Exclusive ownership of every jab or hook |
| Move definition | One executable action and its preparation, path, phases, contact and recovery | An entire uninterruptible fight sequence |
| Signature definition | A recognizable conditional composition of existing moves | Guaranteed hits or a bespoke combat subsystem |
| Behavior profile | AI tendencies, perception delays, risk choices and tactical preferences | Perfect access to the player's future input |
| Runtime state | Current body, support, actions, fatigue, contact, damage and history | Permanent authoring data mutations during an exchange |

The user-requested character/traits/skills/moves/signatures sandbox is therefore a shared authoring and evaluation system. It is not a character menu attached to several unrelated demos.

### Attribute meanings and ceilings

At minimum distinguish the following capacities, merging storage fields only when their effects remain distinguishable:

- Supported punch output.
- Delivery speed and recovery speed.
- Body displacement range and response speed.
- Step and angle recovery.
- Defensive structure and guard endurance.
- Stability and stagger resistance.
- Short-term effort capacity and sustainable endurance.
- Technical economy and transition proficiency.

A style preset allocates emphasis and influences practical learning ceilings. The character also contributes body configuration and individual potential. Do not make every member of one gym identical.

For the baseline balance, movement-specialist presets allocate less to toughness and sustained pocket stability; slugger and pocket presets allocate less to frequent agile exits. Hybrids must pay for their breadth. The actual progression economy can remain owned by the existing game's systems.

Current value and ceiling must be separate. Raising a skill should not silently increase every attribute. A high uppercut proficiency may improve compatible preparation, precision and recovery while leaving durability unchanged.

A ceiling constrains development; it is not a randomly changing per-frame limiter. The exact budget and growth curve are balance data and must be tuned in the existing game rather than fabricated as real sporting measurements.

### Resolving multiple styles

Use explicit composition by responsibility:

1. Physical profile and global anatomical constraints establish the reachable envelope.
2. The selected primary style supplies default stance and movement identity.
3. Explicit secondary components override named domains such as guard or selected footwork, when compatible.
4. Skill proficiency adjusts execution within those domains.
5. Traits apply bounded, documented interaction rules.
6. Runtime support, fatigue, damage and move phase constrain the final request.

This is precedence, not a stack of unconstrained percentage bonuses.

A shoulder-shell secondary guard cannot retain Northern Rising's lead glove in two incompatible places at once. Define an actual hybrid stance or a timed transition between guard modes. Choose one current pose. If a long rising move is unavailable from the current shell state, the fighter must prepare it before delivery.

The future 6ix Slide example—shell defence with Ukrainian-inspired angular movement—uses these composition responsibilities. Do not implement its content now. The foundation needs the capability to combine domains, not a completed catalogue of future styles.

Conflicts must produce an authoring error, an explicitly selected alternative or a documented reduced capability. Never silently choose whichever style provides the highest number for each action.

### Move definition contract

Every move needs enough information for execution, animation, collision and testing to agree.

| Field group | Required content |
| --- | --- |
| Identity | Stable move ID, version, family, lead/rear or anatomical hand rule |
| Request | Recognized action, target options and commitment levels |
| Preconditions | Compatible stances, range, hand availability, support and posture constraints |
| Preparation | Starting pose requirements, preload contribution and allowed input shaping |
| Delivery | Reachable trajectory family, orientation, timing and permitted root movement |
| Phases | Commit point, active contact interval, recovery and transition windows |
| Defence | Opposite-hand behavior and coverage deliberately surrendered |
| Contact | Scoring surface, target policy, obstruction and repeat-hit rule |
| Costs | Effort, fatigue contribution and balance demands |
| Continuations | Conditional next families, required reload and allowed exits |
| Interruption | Reaction thresholds and what cancels, redirects or preserves the move |
| Presentation | Animation references, sound and feedback linked to authoritative events |
| Evidence | Source or visual reference and whether each choice is observed or authored |

Data should refer to existing primitives or authored assets. It must not embed executable code that sidesteps shared rules.

### Signature definition contract

A signature specifies an entry condition, optional setup, ordered or branching move references, transition conditions, valid exits and failure behavior.

Northern Ladder can allow lead-uppercut → rear-uppercut → exit or hook. It does not need a new damage resolver. If the opponent moves away after the first punch, the next stage can miss, stop or choose an explicitly permitted continuation.

Signature mastery can improve transition economy or broaden eligible setups within a capped range. It does not turn the sequence into a guaranteed cinematic attack.

### Trait example

The alternating-hook trait observes completed transitions and maintains a small bounded rhythm state. It references compatible families and hand alternation. It declares its gain, decay and break conditions. It adjusts only named recovery, cost or impact terms.

A trait cannot set invulnerability directly, move the opponent, erase a collision or change a cooldown outside the resolver. Future abilities may use explicitly designed extension points, but none are built as part of this pass.

### Skill example

Uppercut proficiency can affect preparation economy, trajectory consistency, compatible reach usage and recovery into specific moves. It should not globally increase every rising hit's damage while leaving a mechanically unsupported animation unchanged.

A novice Northern Rising boxer and an expert share the stance grammar. The expert uses less wasted preparation and a broader set of valid transitions. The novice still responds to input promptly; poor skill should not be simulated as random input dropping.

### Scalable character generation

Use templates and constrained variation rather than designing each character independently.

A generator resolves:

**body profile + attribute allocation and ceilings + primary style + compatible secondary components + skill distribution + a bounded trait set + selected moves/signatures + AI behavior.**

Use a retained seed for repeatability. Store the resolved result and source versions with saved characters so an update does not silently rewrite their learned style.

Validate each generated character for reach limits, stance compatibility, executable basic attacks, defensive coverage, signature prerequisites, budget compliance and usable recovery. A generated boxer must always have a complete baseline response set; a specialist cannot accidentally lack any way to defend.

Variation should change how the character fights, not merely name, outfit and damage totals. Two Northern Rising fighters may differ in whether they prefer the long lead counter, the compact rear uppercut or the step-out reset, while all remain recognizable.

Named story characters are curated instances of the same system. Bespoke assets are allowed when warranted, but do not require bespoke rules.

### Sandbox requirements

The sandbox must run the actual game fighter, input parser, move resolver, animation, collision and camera. It may expose additional controls and diagnostics but cannot maintain a separate simplified implementation.

Required functions:

- Select or generate a fighter; inspect the resolved style and capability composition.
- Change attributes within limits and compare the result against a saved baseline.
- Switch primary style or compatible components with explicit conflict reporting.
- Select a move and inspect preparation, trajectory, active interval and recovery.
- Execute live manual input and replay recorded input against the same scenario.
- Use a passive partner, scripted punch partner or shared-system AI opponent.
- Inspect feet, support, pelvis, trunk, shoulders, glove path and target volumes from an observer camera.
- Return to player POV and verify that the same exchange remains readable.
- Compare normal-speed footage with slowed replay.
- Show accepted, buffered and rejected actions with reasons.
- Save a resolved character, move tuning and scenario without copying engine code.

The observer camera is a development aid; the player's camera remains an embodied view. Slow-motion replay is for diagnosis, not proof that normal-speed gameplay is satisfying.

## Shared runtime responsibilities

Map these responsibilities to existing modules before deciding whether new modules are needed:

1. Input sampling and action normalization.
2. Character/style capability resolution.
3. Body, support and footwork intent.
4. Move selection, commitment and transition resolution.
5. Canonical pose and trajectory evaluation.
6. Collision and contact adjudication.
7. Effort, damage, balance and reaction updates.
8. Camera and audiovisual presentation.
9. AI perception and action choice.
10. Replay and sandbox inspection.

Keep one owner for each responsibility. Avoid parallel implementations for player, AI, sandbox and production.

### Simulation order

Use the repository's stable simulation clock or establish one if its absence is a demonstrated cause of inconsistent combat. A fixed tick with interpolated rendering is a recommended approach, not a demand to replace an existing correct loop.

A logical tick performs the following coordinated work:

- Sample or consume timestamped input and AI decisions.
- Resolve fresh requests against the state at tick start.
- Predict both fighters' support, root and canonical pose paths through the interval.
- Evaluate swept contacts along those paths in temporal order.
- Apply reactions and recompute any affected remainder when an interruption changes a path.
- Commit the resulting state and events.
- Derive presentation and camera targets from that committed state.

For near-simultaneous hits use contact time and reaction rules. Do not always resolve the player first. A coarse implementation may subdivide intervals instead of performing arbitrary sub-tick rewinds, provided the visible outcome remains consistent.

Input buffering and action timing use a defined clock. Render framerate cannot determine punch cadence, stamina drain or combo timing. Cosmetic interpolation must not feed back into simulation.

### AI

AI chooses through the same action interface and obeys the same support, recovery, effort and contact rules.

Its behavior profile changes preferred range, aggression, counter preference, body attack, angle use and willingness to continue a combination. Its skill is separate from physical output. Harder AI can read more reliably or plan better within bounded perception, not bypass cooldowns or inspect uncommitted player input.

Include opponents that expose foundation weaknesses: disciplined jabber, pressure boxer, uppercut counter specialist, body attacker and angle-taking defender. These are evaluation profiles using shared data, not five separate engines.

## Existing project integration

### Repository inspection is the next local action

Before implementation, the local AI must read the actual project instructions, current design documents, recent changes and relevant source. It must identify the running game entrypoint and the actual platform, rendering stack, animation system and controller input path.

It must trace one current punch and one current dodge from input through pose, collision, reaction and camera. Record the exact files and functions involved in a concise integration map. This requirement cannot be satisfied by guessing likely filenames or selecting a new engine.

Audit especially:

- Camera-space transforms used as world positions.
- Fixed-world left/right or a permanently centred opponent.
- Punch damage issued by animation timer alone.
- Arm-only movement without support or torso contribution.
- Visual slips with unmoving hit targets.
- Independent root motion applied twice.
- Forced idle between actions.
- Long easing that delays intended movement.
- Stale input queues or duplicate punches.
- AI actions bypassing the player resolver.
- Prototype sandbox logic that differs from actual gameplay.
- Character-specific conditionals duplicating universal combat logic.

Use the findings to select the smallest coherent architectural changes that deliver the full foundation. Smallest coherent does not mean smallest possible patch if that leaves the mechanism broken.

### Preserve existing work

Keep valid assets, interfaces, save formats and working systems. Isolate changes using the repository's established branch or worktree process where appropriate. Record a replay or representative video of the current behavior before changing it.

If a schema must change, migrate existing character data or provide a compatible adapter. Do not replace saved fighters with defaults. Preserve existing identifiers when their meaning remains valid.

Introduce new primitives into the actual match path early. A separate prototype may answer a narrow technical question, but it is not the final deliverable and cannot become the only working version.

### Ordered work packages

| Package | Delivered capability | Required evidence before calling it complete |
| --- | --- | --- |
| 1. Trace and baseline | Actual dependency map, known failures and preserved reference exchange | File-grounded map and reproducible scenario in the existing game |
| 2. World and body control | Correct frames, continuous body disk, working support and embodied camera | Continuous sweeps, visible lower body and rotated-world comparison |
| 3. Punch and contact | Shared hand families, committed trajectories, real moving collision and defence | Clean hit, miss, block, deflection and interruption shown with matching geometry |
| 4. Transitions and pocket loop | Continuous defensive/offensive links, footwork exits and bounded rhythm mechanics | Complete exchanges at normal speed without idle resets or foot skating |
| 5. Northern Rising | Correct stance, pocket and rangy rising variants, three signature compositions | Player and observer views across multiple builds and both stances |
| 6. Composition sandbox | Reusable records, conflict handling, generation and shared AI interface | Several resolved characters generated from data, with no per-character combat fork |
| 7. Foundation qualification | Full round, fatigue, stagger, knockdown/recovery and integration with existing match flow | Gameplay recording, targeted checks, performance evidence and resolved blocker list |

Dependencies do not justify separate disconnected demos. Each package extends the same match and retained scenarios. The local AI continues through internally testable work without asking the user to test every small edit.

If the project already implements a package correctly, verify and reuse it. Do not rebuild it solely to match this document's organization.

## Completion evidence

### Objective gates

| Gate | Passing evidence |
| --- | --- |
| Circular body response | Full disk sweep has continuous pose change without eight-way snapping or sudden neutral resets |
| Input response | Fresh inputs are acknowledged at the next eligible simulation opportunity; intentional wind-up is distinguishable from processing delay |
| Punch parser | Every supported sector and modifier combination resolves consistently; held input never creates unrequested repeated attacks |
| Foot support | Observer view shows valid contacts and landings during slips, punches and exits |
| Combination continuity | Representative cross-family, same-hand and defensive-to-offensive transitions preserve coherent motion |
| Northern Rising stance | Lead forearm and glove match the specified raised bent shape; rear glove protects the jaw |
| Range correctness | Pocket uppercuts miss at excessive range; rangy variants gain reach through their defined delivery, not invisible hitbox inflation |
| Defence correctness | Hits, misses and blocks agree with visible bodies and guards |
| Interruption | No phantom damage after a punch is cancelled; legitimate simultaneous trades remain possible |
| Counter correctness | Opportunities depend on actual exposure and geometry; dodge input alone grants nothing |
| Bounded movement | Exit and angle steps move the actor within ring geometry, with no unrestricted orbit drift |
| Camera correctness | View follows actual angle/range change; stabilizing roll does not freeze the world relationship |
| Coordinate invariance | Transformed and mirrored scenarios preserve intended relative behavior |
| Shared system | AI, sandbox and live match use the same action and contact rules |
| Composition integrity | Incompatible styles are reported; generated characters retain complete basic capabilities |
| Match completeness | A full round and existing match transitions work, including fatigue and reactions |
| Regression control | Existing character saves and unrelated game systems continue to work through required project checks |

### Proposed performance and responsiveness targets

Use 60 frames per second as a minimum design target on the project's declared baseline hardware unless it already requires more. At 60 Hz the nominal frame budget is 16.67 ms. This is a target, not a benchmark result.

Measure input sampling, request acknowledgement, first visible motion and contact separately. A proposed healthy idle response is visible intent within one or two render frames after the input reaches the game; a committed punch's travel is intentionally longer. A queued action may wait for a valid transition and must report why.

Check frame-time percentiles and spikes in the real match with the final character rigs. Average FPS alone is insufficient. Disable debug visualization when measuring production performance, then separately ensure debugging remains usable.

Replay comparable inputs at supported render rates. The same simulation-time sequence should preserve action count and outcomes within stated tolerance. Do not promise cross-platform bitwise determinism unless the existing engine actually provides it.

Numeric thresholds for deadzones, buffer windows, uppercut reach, counter duration and fatigue must be recorded as tuning parameters with units. They remain provisional until tested in this actual game. Tuning is refinement of a defined system, not permission to invent a different architecture after every bug.

### The feel gate

Automated checks cannot certify fun, authenticity or Fight Night-level satisfaction. Normal-speed play and the user's trained eye remain necessary for those judgments. That does not make the user the agent's routine QA department.

Before requesting a consolidated review, the local AI must provide a working integrated build, perform available self-play or scripted scenarios, review footage in both cameras and fix visible failures it can identify. Deliver a short normal-speed gameplay sequence showing body control, guarded countering, combinations, an exit and a Northern Rising exchange.

The review asks whether the core experience meets the intended standard, not whether the user can discover missing controls. A pass on technical gates is necessary but does not excuse stiff motion or unsatisfying contact.

If a blocker remains, state the concrete defect, its affected mechanic, what was attempted and the next corrective action. The package remains incomplete. Merely listing an unfinished claim does not complete it.

## Ready to hand to the local AI

Use this document as the combat design contract for the current True North Boxing project.

First inspect the repository and trace the existing combat path. Preserve working systems. Produce the exact integration map, then implement the ordered work packages in the actual game. Do not create a replacement project, choose a new engine without evidence or substitute a simplified showcase for the real match.

The priority is the connected boxing exchange: continuous body intent, directional punch intent, coordinated support and body motion, real contact, responsive defence, flowing transitions and a camera attached to a fighter who exists in the world.

Build Northern Rising through shared stance, move, style, trait, skill and signature definitions. It is a rangy uppercut-focused technical counterpunching style with compact pocket combinations and real exit steps. Follow the supplied stance correction. Do not copy the low lead hand from the reference unchanged.

Create characters by composing and validating reusable data. Do not handwrite a combat system for each character. Keep future ability hooks narrow and explicit; do not implement the later shonen skill layer or 6ix Slide content now.

Own verification. Continue through routine fixes without requiring the user to test every edit. Report what changed, what was actually tested, what footage demonstrates, what remains blocked and the next concrete action. Never describe a partial prototype as the completed foundation.

## Quest 3 experiment

**Recommendation: potentially useful later for reference and selected upper-body motion, but not a prerequisite and not a dependable replacement for complete boxing capture.**

Meta documents Quest 3 inside-out upper-body tracking and inferred or generative leg poses. Generated legs are not direct measurements of foot pivots, ground contact or force transfer. Those are exactly the details this foundation needs to preserve.

With only the existing Quest 3 and development computer, a small future trial could compare controlled jab, hook, uppercut and lean sequences against the game's motion. Confirm usable export, tracking continuity, retargeting and repeatability before investing further effort. Fast close-to-face hand motion, occlusion and inferred joints require practical testing rather than assumptions.

Do not buy equipment, block development on mocap or claim professional capture quality from the headset alone. The current foundation must be viable with its existing assets and an appropriate authored/procedural motion workflow.

## Sources and evidence boundaries

- [EA Fight Night Champion Xbox 360 manual](https://eaassets-a.akamaihd.net/eahelp/manuals/fight-night-champion-manuals_Microsoft%20XBOX360.pdf), printed pages 3–8: control categories, punch wheel, movement, leaning, weaving, blocking and modifiers. The proposed True North bindings and parser are original design.
- [EA launch announcement](https://news.ea.com/press-releases/press-releases-details/2011/The-Champ-Has-Arrived-Fight-Night-Champion-in-Stores-Now/default.aspx): confirms Full Spectrum Punch Control as an accessibility and responsiveness focus. Marketing claims do not establish implementation internals.
- [Dinu and Louis, 2020, Biomechanical Analysis of the Cross, Hook, and Uppercut](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2020.598861/full): coordinated segment contributions and differences across punches and athlete groups. A small laboratory study is not a universal technique prescription.
- [The Role of Lower Limb Kinetics in Boxing Punches and the Impact of Fatigue on Biomechanical Performance](https://pubmed.ncbi.nlm.nih.gov/41463652/): supporting research on lower-limb contribution and fatigue; the accessible indexed abstract describes a ten-participant male amateur study. No game constants are taken from it.
- [Meta Movement SDK overview](https://developers.meta.com/horizon/documentation/native/android/move-overview/) and [inside-out body tracking and generative legs](https://developers.meta.com/horizon/blog/inside-out-body-tracking-and-generative-legs/): ground the limited future Quest 3 experiment. Available indexed documentation was used where complete page access was unavailable.
- User-provided connor-stance-1.png: stance reference interpreted with the user's explicit Northern Rising modifications. It is preserved unchanged in the accompanying handoff package.

The equations, action phases, proposed controls, quality terms, sandbox responsibilities, balance tradeoffs and integration gates are authored game-design specifications. They are not measured properties of Fight Night, clinical claims or validated simulations of human biomechanics.
