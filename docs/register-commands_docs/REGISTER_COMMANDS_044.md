# REGISTER COMMANDS 044 — for the applying writer
**From: @claude · 2026-09-25 · Re: PAC-095 The obsolescence audit (greybox v6, NP_14 C49)**
Same rule as 001–043: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-095 Status DONE** (the row payload below replaces the TODO row from 043).
2. **Add PAC-096** (row below), Status TODO: fix the two systems the audit names, with `-- audit` GREEN as the acceptance test.
   - **Techniques (all three cards, and the reference too):** at level 35, one of the four technique slots never answers a motion.
   - **Growth (PRIYA):** her total is 17 % under the late recruits' total, and she wins 3 of 14 segments in the endgame.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Add DATA row** `data/audit.v1.json` (DATA, "NP_11 s10's obsolescence audit as the audit reads it:
   - the earliest three by NP_12 s4 (PRIYA, DEX, YURI) and the reference recruits (Cassidy, Remy, Jean-Guy, the Choir);
   - the endgame (arc 3's bosses at level 35) and the budget by Arc 3 (95 Spirits, 100 Beans, 3,000 HBP, the circuit's flags);
   - the viability criteria (one Board Point left at most, three passives, 50 % of segments, seeds 11 and 22, a 10 % stat gap, a 12,000-tick cap);
   - the system each shortfall names").

   Both copies. The sim does not read it.
4. **Link PAC-095** to these rows:
   - **MODULE `sim/core.gd`:**
     - `kit_unreachable` (C45's cast order stated: a move behind a cheaper-or-equal one on its family never casts);
     - `load_content` reads `audit`.
   - **MODULE `sim/audit.gd`** (new, static): `mk`, `endgame_bosses`, `card_of`, `learnable_families`, `build_kit`, `build`, `fight`, `run`, `lines`.
   - **MODULE `main.gd`:** the `-- audit` test mode and its help line.
   - **TEST rows:** `sim/tests.gd` (`audit()`, 5 smoke gates, 1 determinism gate).
   - No drive: nothing on the scene changed.
5. **Gates moved — flag for @heat.** None. No older smoke or determinism figure moved: the audit reads its table beside the sim, and the table is not in the content stamp.
6. **Note NP_14:**
   - C49 added (5 gates, the audit reduced on the determinism log, `-- audit`'s verdict).
   - C44's not-claimed line names the audit as C49's.
   - A new not-claimed bullet names what C49 does not build, and its readings.
   - One reproduction line added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C49.
7. **FINDINGS — flag for @heat.** `-- audit` on this build: **RED, 0 of 3 viable.** Every card reaches tier 4, spends its board, fills its gear and fields a kit in which every move answers.
   - **Techniques (NP_11 s2, s8), all three cards and all four references.** Level 35 opens four technique slots.
     - The live sources teach four motion families (RISE, ARC, PISTON, HAYMAKER), each learnable T1 at the same price (35).
     - The card's own move holds one family and shadows that family's T1s. So three families are left for four slots, and the fourth slot never answers.
   - **Growth (NP_11 s3, s6), PRIYA.** She wins 3 of 14 segments against the arc-3 bosses (21 %; the bar is 50 %).
     - Her PWR is 50 and her CHN 53, against the references' 80 and 79.
     - Her total is 457, 17 % under their 551.
     - The Out-Boxer board carries PWR +5 and CHN +12 in all, and the raises price by count.
   - **Holding the endgame:** DEX wins 10 of 14 (71 %) and YURI 14 of 14. The references win 11 to 13 of 14.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"the three earliest-recruitable fighters"**: NP_12 s4's first recruits in beat order (PRIYA beat 1, DEX beat 3, YURI beat 4).
   - (b) **"the current endgame"**: arc 3's seven bosses at level 35 (NP_11 s2's "~35 by Arc 3 start").
   - (c) **"viable"**:
     - tier 4;
     - "a competitive board" read as every Board Point but one spent and three passives or more;
     - "a coherent technique kit" read as every slot the level opens filled and every move answering a motion under C45's cast order;
     - and holding the endgame: half the segments or more, on the profile.
   - (d) **"live systems only"**:
     - each trial through its own code path with its outcome given (a spar won, a transform weathered, the mirror beaten);
     - each ascension paid in Spirits;
     - the kit only from the shelves and lessons open at the budget's flags.
   - (e) **"the failing system, not the fighter"**: a reference of the late recruits, built the same way.
     - Growth is named when the card's total is over 10 % under theirs.
     - Otherwise the fight itself is named (tuning, PAC-052's lane).
9. **Editorial, to confirm or overrule:**
   - the budget and its four flags;
   - the thresholds (one point, three passives, 50 %, 10 %);
   - the seeds, the tick cap;
   - the builder's policies: the aid's nodes, raises on the lowest stat, the kit greedy on a fresh family then tier then price, the aid's gear;
   - the report's wording.

   To reverse the rules and numbers, edit `audit.v1.json`.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-095 row (CSV-ready, todo columns)
ID: PAC-095 | Title: The obsolescence audit (NP_11 s10) as an executable gate | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_11 s10 on the sim: the three earliest-recruitable fighters (the recruit ledger's first joins) built for the current endgame with live systems only - rarity to tier 4 on Spirits and the trials, a competitive board, a coherent technique kit, gear in the slots - and fought against the endgame's bosses by the profile. Viability measured (a win rate or EP margin against a named threshold), and a failing system named, not the fighter. The audit's report as a headless tool the milestone runs. Gates cover the build reaching tier 4 on live systems only, each system's contribution against its absence, the report's verdict; determinism with an audited card in the log.
BlockedBy: PAC-094 | DependencyType: soft | RelatedWork: NP_11 s2 s3 s4 s5 s6 s8 s10; NP_12 s4; NP_14 C29 C43 C44 C45 C48 C49; data/audit.v1.json; data/growth.v1.json; data/techniques.v1.json; data/gear.v1.json
Notes: 2026-09-25: SMOKE 411/411 GREEN x 24 bosses (9,864 assertions; +5; every older line byte-identical, the save sizes and the stamp included). DETERMINISM 49/49 (the audit reduced: DEX built for the endgame and fought against Alfie Crane and Ioan Vasile, identical twice, a seed apart different). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. -- audit RED (exit 1), 0 of 3 viable: techniques for all three, growth for PRIYA (command 7); two runs identical. Drives: gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo gear boss=1 (60,000 frames), demo mirror (5 counters), demo growth (29 steps), demo hybrid. No gate moved.
LearningNotes: The kit's rule needed saying out loud before it could be audited. C45's cast order has been live since PAC-091: LB + a motion casts the card's own move, else the kit's first move on that family the bar can pay. `kit_unreachable` states it, and the audit counts a slot as filled only when its move can ever cast. That turned "three of four slots" from a builder's shortfall into the system's: every learnable T1 costs 35, so nothing shares a family and answers. The reference recruits separate the two failures the audit can find. Without them, PRIYA's 3 of 14 could be the fight's tuning (PAC-052's lane) or her growth. Built the same way and fought by the same profile, the late recruits win 11 to 13 of 14 on totals 17 % higher, so the audit names growth. Marking the trials through their own code paths, with the outcome given, keeps the build honest about what it did not play: the fights prove only the endgame.
StartedAt: 2026-09-25T02:52:44Z | DoneAt: 2026-09-25T03:53:06Z

## PAC-096 row (CSV-ready, todo columns)
ID: PAC-096 | Title: Fix what the obsolescence audit names: the kit's hollow slot and PRIYA's growth | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: `-- audit` GREEN (3 of 3 viable), with the audit unchanged as the acceptance test.
- **Techniques:** at level 35, every technique slot holds a move that answers a motion, from live sources by Arc 3. The recommended default is the T2 rows opened on the shop's third shelf or a master's second lesson, so a family carries two answering moves (a T2 ahead of its T1). The alternative is a fifth teachable family.
- **Growth:** the earliest card's built total within 10 % of the late recruits' total, by a catch-up on the board or the raises. The recommended default is raises priced by the stat's distance under its cap rather than by count; the alternative is ascension floors.
- **Gates:** each fix against its absence; no fighter's own numbers edited; determinism with the fixed build in the log.
BlockedBy: PAC-095 | DependencyType: soft | RelatedWork: NP_11 s2 s3 s6 s8 s10; NP_05 s4; NP_14 C44 C45 C49; data/techniques.v1.json; data/growth.v1.json; data/audit.v1.json
Notes: Alternative for PAC-096: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
