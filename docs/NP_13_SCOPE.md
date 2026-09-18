# NP-13 — SCOPE & PHASE BREAKDOWN: Production Plan

**Project Northpaw design vault · Doc 13/13**
Related: all docs · Register: `todo.PACER.csv` (41 tasks, P0–P7)

The build plan: what ships, in what order, proven by what milestones, measured how, and where the risks live. Written to be executable by a small team with heavy AI-agent assistance (content pipelines are designed data-first throughout the vault for exactly this reason).

---

## 1. SHIP TARGETS (v1.0)

| Domain | Target |
| --- | --- |
| Story | Arc 1 complete (24 chapters) + Arc 2 complete + Arc 3 complete; post-game Title Defense remix gauntlet |
| Duals | 30 story duals + repeatable circuit/exhibition systems |
| Bosses | 24 named pattern bosses (full PBN + remix), 60 assembler pattern pieces |
| Roster | 300+ recruitables (60 named-with-scenes), 14 houses, 10 staff |
| Techniques | 80 hissatsu (24 at [[NP_05_TENSION_HISSATSU]] §10 quality bar), 8 hybrid slots |
| Systems | Everything in docs 01–11, no cuts without doctrine review (D8) |
| Platforms | PC first; console SKUs post-alpha decision gate |
| Localization | EN + FR-CA at parity ([[NP_12_NARRATIVE]] §8) |

## 2. PHASE PLAN (maps 1:1 to the PACER register)

| Phase | Name | Exit criterion (the milestone build) |
| --- | --- | --- |
| **P0** | Foundation | Doctrine ratified; engine + latency validated; art bible readability standards signed; VS scope locked |
| **P1** | Combat Core | **"Two Hands" build:** full input matrix, guard/stamina/composure/counters, exchange states vs. a dummy — *the game feels good with zero content* |
| **P2** | Opponent Architecture | **"Three Souls" build:** PBN toolkit live; Yuri, Marta, Sam authored & playtested; remix layer works |
| **P3** | Match & Rotation | **"One Dual" build:** full 5-segment dual with scoring, Tension, relay, corner phase, Wall Gauge — the sport exists |
| **P4** | Progression & Affinity | **"The Build" build:** stats→sim live, boards, three rings, hissatsu execution + 24-move library |
| **P5** | Stable, Bonds & Tactics | **"The Club" build:** recruitment channels, bond board, staff, formation screen, tactics libraries, transforms T2–T5 |
| **P6** | Overworld & Narrative | **Vertical slice / demo candidate:** Harbourline district set, scraps/spars, Arc 1 through the Survival Dual |
| **P7** | Content, Balance & Ship | Content DB to targets; Arcs 2–3; balance passes; cert; launch |

**The Vertical Slice** (defined P0, delivered end-P6): Ep1 cold-open flashback → the Letter → 3 scraps → Priya recruitment → Survival Dual (3-segment mini-dual vs. Ascendant B, one authored boss + assembler fillers). One hour. Every layer touched once. This is also the public demo.

## 3. DEPENDENCY SPINE (why this order)

Combat feel (P1) before opponents (P2) — patterns tuned against final hands only. Opponents before the dual (P3) — the sport is only testable with real minds in it. The dual before progression (P4) — stat hooks tuned against real match pacing. Systems before content mass (P7) — the content DB schema ([[NP_11_PROGRESSION]] §9) freezes at P4 exit; content production parallelizes from there (the agent-assisted lane: PBN authoring, house generation, bark writing all run against frozen schemas with human review gates).

## 4. TEAM SHAPE (minimum viable)

Combat designer/engineer pair (P1–P3 critical path) · systems designer (P4–P5) · narrative lead + writer (P6–P7) · art: character/VFX/UI trio + contract animation · audio (tell-audio channel is a *design* dependency, staffed early) · producer running the PACER register as the single source of truth. Cultural consultants contracted per [[NP_07_HOUSES]] §9 from P5 onward — budgeted as production line items, tracked as PAC tasks.

## 5. CONTENT PIPELINE GATES (review checklists, enforced per asset class)

- **Boss gate:** [[NP_04_OPPONENT]] §7 template complete; fair-windup audit; PI 0 clear-ability playtest; tell squint-test.
- **House gate:** [[NP_07_HOUSES]] §1 writing law review; consultation sign-off where applicable; feud-graph consistency.
- **Hissatsu gate:** counter-profile defined; camera script within hold budgets; readability over spectacle check.
- **Scene gate:** tone law ([[NP_12_NARRATIVE]] §1); bark coverage minimums; FR-CA parity.
- **Doctrine gate (all):** any asset or change violating D1–D8 escalates to design review; D-violations are never fixed by exception.

## 6. PLAYTEST METRIC SUITE (runs on every milestone build)

| Metric | Healthy band |
| --- | --- |
| Time-to-first-DROP (new players, boss 1) | 60–180 s |
| Counter-rate percentile spread | skill-expressive: p90 ≥ 3× p10 |
| Gassed-state (<15 stamina) frequency | present but <15% of segment time |
| Adaptation flags per segment (median) | 1–3 (the tracker teaches without nagging) |
| Scrap loop total time | <60 s ([[NP_02_TWO_LAYER]] §5) |
| Session progress meters advanced | ≥3 per 45-min session |
| Transform usage | ≥70% of duals see ≥1 transform post-unlock (the bar must get spent) |
| Tactics-only wins (manager mode) | viable but <50% winrate vs. hands-on at equal progression |
| Obsolescence audit ([[NP_11_PROGRESSION]] §10) | pass, every milestone |

## 7. RISK REGISTER (top items)

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-01 | Stick-flick grammar alienates pad-casuals | Accessibility chord preset at parity (P1 scope, not post-ship); onboarding via scrap objective ladder |
| R-02 | Camera orbit vs. tell readability | Art-bible salience metric + automated tell-visibility test scenes (P0 deliverable) |
| R-03 | Two philosophies clash (authored patterns vs. adaptive defense feels unfair) | The narrated-tracker rule ([[NP_03_COMBAT_ENGINE]] §10.3): every adaptation is spoken aloud; playtest the *perception* of fairness explicitly |
| R-04 | House/culture execution failure | §9 consultation standard with veto authority; write law enforced at gate; this is the reputational crown jewel and is resourced like one |
| R-05 | Content mass (300 recruits, 24 bosses) overruns | Assembler + schema-frozen agent pipelines with human gates (§3); named-content quality bar protected by keeping the named count (60/24) fixed while generic counts flex |
| R-06 | Five-segment duals run long for session players | Segment saves mid-dual; manager-mode delegation; mini-dual formats front-loaded |
| R-07 | Economy sprawl (7 currencies) | Faucet/sink audit per milestone ([[NP_11_PROGRESSION]] §6); currencies each own one loop — merge any two that converge |

## 8. POST-LAUNCH SHAPE (design-compatible growth, not committed)

New districts as recruit ecosystems ([[NP_08_STABLE]] §9) · house packs (toward the 40-house roster, [[NP_07_HOUSES]] §8) · seasonal festival formats (2v2 circuits) · Title Defense remix waves · the pro tier (Arc 4 fiction space). All growth reuses frozen schemas; nothing post-launch may require a doctrine amendment.

## 9. REGISTER LINKAGE

`todo.PACER.csv` remains the operational source of truth; this doc is its rationale. Register maintenance per the PACER field rules: ≤3 DOING per agent, dependency gates enforced, LearningNotes accumulated per phase. Doc-to-PAC mapping: P1↔NP-03, P2↔NP-04, P3↔NP-01/05, P4↔NP-06/07/11, P5↔NP-08/09/10, P6↔NP-02/12, P7↔NP-13 targets. When a vault doc changes, its mapped PACs get a Note line same-day — the vault and the register are not allowed to drift.
