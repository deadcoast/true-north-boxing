# NP-05 — TENSION & HISSATSU: The Resource Economy

**Project Northpaw design vault · Doc 5/13**
Related: [[NP_03_COMBAT_ENGINE]] · [[NP_06_AFFINITY]] · [[NP_07_HOUSES]] · [[NP_09_TRANSFORMATIONS]] · [[NP_10_TACTICS]]

Tension is the single shared team meter that binds five separate segments into one match, converts clean play into shonen spectacle, and makes "friendship is power" a number. This doc specifies the full economy, hissatsu execution and tiering, the relay system, Wall Gauges, hissatsu counterplay, and a 24-move launch library.

---

## 1. TENSION FUNDAMENTALS

- **One meter per team, 0–100**, persistent across all 5 segments + OT. Both meters visible on the score bug at all times.
- Resets to 0 at dual start (modifiers: certain staff passives start you at 10; certain story duals start the enemy at 50 — authored stakes).
- In spars: personal meter capped at 50 ([[NP_02_TWO_LAYER]] §2.2); scraps: no meter (too short).
- Tension is never lost passively. It is spent, not drained. (Tested alternative — decay — punished defensive play and was cut. Do not reintroduce.)

## 2. EARN TABLE (canonical)

| Event | Team Tension |
| --- | --- |
| Clean counter hit | +3 |
| Flash-counter hit | +5 |
| Perfect block / successful slip | +2 |
| Interrupt-window break (stagger a string) | +5 |
| Exchange win in CENTER zone | +2 |
| DROP scored | +10 |
| Surviving a standing-eight (your fighter rises) | +8 crowd surge |
| Segment win (EP) | +5 at segment end |
| Corner hype action | +8 (staff-dependent, [[NP_10_TACTICS]] §6) |
| Segment KO clock-out trickle | +1 / 10 s |

**Anti-exploit:** hits from adaptation-flagged sequences earn 0 ([[NP_03_COMBAT_ENGINE]] §10). Chip damage through block earns 0. There is no Tension for damage taken (no masochism economy) *except* the standing-eight survival surge.

**Both teams earn.** Enemy clubs run the same economy; enemy AI spends per authored desperation scripts ([[NP_04_OPPONENT]]) and coach logic ([[NP_10_TACTICS]] §9). The dual is a race for the same fuel.

## 3. TIER TABLE

| Tier | Class | Cost | Unlock |
| --- | --- | --- | --- |
| **T0** | Signature | 10 | Fighter level 5; every fighter gets exactly one — their identity move |
| **T1** | Super | 35 | Learned: House-native, taught, or bought ([[NP_11_PROGRESSION]] §8) |
| **T2** | Guard-wall (defensive) | 25 | Anchor-class fighters + defensive boards |
| **T3** | Relay / combination | 50 | Requires CHARGED state (§6) or bonded adjacency ([[NP_08_STABLE]] §6) |
| **T4** | Transformation | 100 (entire bar) | Arc-gated, [[NP_09_TRANSFORMATIONS]] |

## 4. EXECUTION RULES — the motion IS the spellbook

Hissatsu fire via **LB (arm) + the move's motion family** from [[NP_03_COMBAT_ENGINE]] §2. No menus, no QTE. Motion families:

| Family | Motion | Typical tier |
| --- | --- | --- |
| RISE | RS down→up (uppercut arc) | T0/T1 finishers |
| ARC | RS side flick held 100 ms (hook arc) | T1 hooks |
| PISTON | double-flick same direction | T0 jab-class |
| HAYMAKER | pull-back→forward | T1/T3 power |
| WALL | RT + LB hold 400 ms | T2 defensive |
| SURGE | LB + both sticks click | T4 transforms |

- Arming (LB) telegraphs: your fighter's aura flickers — **opponents see your hissatsu coming too** (counterplay, §9). Arm-feinting (arm, don't cast) is legal mind-gaming; costs 2 Tension.
- Insufficient Tension: the motion executes as its normal punch. Never a whiff-lockout — the input grammar stays trustworthy.
- Element/House/Style matching bonuses per [[NP_06_AFFINITY]] §5.

## 5. HISSATSU ANATOMY (schema fields, full schema in [[NP_11_PROGRESSION]] §9)

`startup_cinematic (camera hold, 0.8–2.5 s by tier) → effect_block → aftermath`. Effect blocks compose from: damage packet, composure bypass %, guard-shred, zone displacement (knock to ropes/corner), stamina burn, state inflictions (slow, tell-jam), self-buffs, wall states. Every hissatsu declares an **interrupt/counter profile** (§9) — nothing is uncounterable except T4s.

## 6. THE RELAY (passing, rotation-shaped)

- A fighter who personally contributes **≥25 Tension** in their segment ends it **CHARGED**.
- The *next* fighter out inherits: entrance surge (all stats +10% for 10 s), first hissatsu −50% cost, T3 moves unlocked for their segment.
- Consecutive charged segments build a **chain counter** (score bug shows the links). Chain ≥3 = **FULL RELAY**: the current fighter's T4 costs 75 instead of 100, and the team's T3s gain the chain's element trail VFX (the multi-teammate shot-chain fantasy, expressed across time instead of across the pitch).
- A lost segment doesn't break the chain — only a segment with <10 contributed Tension does. The opener who grinds a loss but banks meter keeps the story true: nothing your teammates build is wasted.

## 7. DUO HISSATSU (2v2 exhibition + relay ghosts)

- In 2v2 exhibitions ([[NP_01_SPORT]] §8): true simultaneous duo moves (both players input the motion within 500 ms).
- In standard duals: T3 relay moves render the *previous* fighter as a spirit afterimage joining the technique — the duo fantasy inside the 1v1 format. Bonded pairs ([[NP_08_STABLE]] §6) get named duo variants with unique VFX.

## 8. WALL GAUGE (boss anchors)

- Visible shield bar on gauge-bosses ([[NP_04_OPPONENT]] §8.3). Base 100. Damage sources: counters ×1.0 of dmg, power punches ×0.8, body work ×0.6, hissatsu ×1.5. Jab-class: 0.
- Gauge → 0: **TRUE OPEN** 8 s (droppable, dmg ×1.25), then gauge reforms at a lower cap (100→60→30→gone). Three breaks end the wall permanently — the attrition arc has a finish line, always.
- Player anchors can equip T2 walls that grant a mini-gauge (20 pts, one reform) — the fantasy is earnable, scaled down.

## 9. HISSATSU COUNTERPLAY (both directions)

| Situation | Counter |
| --- | --- |
| Enemy T0/T1 arming | Interrupt during startup cinematic wind-up (jab-class, if move's profile allows) → cancels, refunds them 50%, you +5 Tension |
| Enemy T1 cast | Perfect-timed WALL (T2) negates fully; perfect slip reduces to 40% chip; block reduces to 60% + massive guard shred |
| Enemy T2 wall | Wait it out, or spend: any T1+ breaks a wall at cost parity |
| Enemy T3 relay | Interruptible only during the spirit-afterimage windup (700 ms, Loud) |
| Enemy T4 | Not interruptible. Survivable: transforms answer transforms, or perfect-defense sequences reduce damage 50% (the heroic weathering option — authored to feel like surviving a storm) |

## 10. LAUNCH LIBRARY (24 moves — name / tier / family / element / source / effect sketch)

| Move | T | Family | Elem | Source | Effect |
| --- | --- | --- | --- | --- | --- |
| Aurora Borealis Breaker | T1 | HAYMAKER | Frost | Protagonist signature line | Arena-freeze VFX; dmg ×2.5; ropes displacement |
| First Snap | T0 | PISTON | Frost | Generic Frost | Double-jab, brief foot-freeze slow on hit |
| Chinook Rush | T1 | ARC | Gale | Generic Gale | 3-hook flurry with forward glide |
| Grain Elevator | T1 | RISE | Granite | House Kowalchuk native | Rising uppercut; guard-shred 40 |
| Première Neige | T2 | WALL | Frost | House Tremblay native | 5 s auto-slip wall |
| Sorry Eh | T1 | ARC | Frost | Sam Tagaq personal | Counter-stance: next enemy punch answered ×2 |
| Net-Hauler's Yank | T1 | HAYMAKER | Timber | House MacIsaac native | Pull-counter overhand; drags target 1 m ropeward |
| Liver Line | T1 | ARC+LT | Granite | House Reyes native | Body finisher; stamina burn −25 |
| Pressure Cooker | T0 | PISTON | Gale | House Okafor native | Inside 1-2; +2 bonus Tension on counter use |
| Long Winter | T2 | WALL | Frost | House Whitecloud native | Guard wall + stamina regen ×2 for 4 s |
| Timberfall | T1 | RISE | Timber | Taught (Coach questline) | Delayed-timing uppercut; beats duck reads |
| Black Ice | T0 | PISTON | Frost | Taught | Feint-jab; jams enemy tell audio 3 s (tell-jam — vicious, rare) |
| Thunder Bay | T1 | HAYMAKER | Gale | Bought (HBP shop tier 3) | Stepping haymaker, +range |
| Shield Wall | T2 | WALL | Granite | Anchor board | 20-pt mini Wall Gauge |
| Two Rivers | T3 | ARC | dual | Cross-house hybrid ([[NP_08_STABLE]] §6) | Two-element hook string; afterimage partner |
| Relay: North Star | T3 | RISE | any | FULL RELAY exclusive | Chain-powered rising finisher; dmg × chain length |
| ...(+8: per-boss desperation moves, festival duo moves, Arc 2 syndicate set) | | | | | |

## 11. UI

Meter on score bug (both teams); arm-state aura on fighters; cost pips on the hissatsu quick-card (hold LB: 1 s overlay of your fighter's equipped moves + costs — the only combat menu, and it's an overlay, not a pause).
