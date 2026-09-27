# REGISTER COMMANDS 045 — for the applying writer
**From: @claude · 2026-09-25 · Re: PAC-096 What the audit named, fixed (greybox v6, NP_14 C50)**
Same rule as 001–044: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-096 Status DONE** (the row payload below replaces the TODO row from 044).
2. **Add PAC-097** (row below), Status TODO: NP_11 §6's faucet/sink audit as an executable gate. The target is that a story-pace player affords 70 % of the desired sinks.
   - It checks the obsolescence audit's budget: 95 Spirits, 100 Beans and 3,000 HBP a fighter by Arc 3 are still first drafts (C49, C50).
   - NP_13 R-07 names the same audit as the economy's guard against sprawl.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Update DATA row** `data/growth.v1.json` (both copies):
   - `rarity.totals` {Circuit 420, National 490, Legend 490} (NP_11 s1's stat totals by rarity);
   - the Anchor Wall (`s15`, kind `wall`, 3 points, linked to Wallflower and s14) on each of the four layouts, now 61 nodes;
   - `costs.wall`; the notes.
4. **Update DATA row** `data/techniques.v1.json` (both copies):
   - `t2_board` (NP_05 s3: a T2 in a slot wants the Anchor Wall);
   - the masters' `BOARD` (kind `board`), teaching Shield Wall, Windbreak and Palisade behind the node;
   - `board:anchor` out of `not_learnable`; the notes.
5. **Link PAC-096** to these rows:
   - **MODULE `sim/core.gd`:**
     - `rarity_total`, `rarity_base` (under `grown_stats`);
     - `wall_open`, `wall_wanted` (in `node_best`), `_wall_label`, `_t2_why` (in `_learn_why`, `kit_moves`, `kit_why`);
     - `master_here`'s board kind, `_gate_why`'s node gate;
     - `ascend`'s event and line carry the total.
   - **MODULE `main.gd`:** the ASCENDED toast carries the total.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate) and `engine/greybox/tools/drive_growth.gd` (two checks); both moved in command 6.
   - `sim/audit.gd` is unchanged. There is no new drive: on the scene only the toast changed.
6. **Gates moved — flag for @heat.**
   - **The ability boards:** 61 nodes (was 60), the Spirit lobe 15 (was 14), RORY's board 63 (was 62).
   - **The save's Fighter.board:** RORY at Circuit walks out on PWR 59 (was 52). Circuit's 420 lifts his own 384.
   - **C49's gates:**
     - a build reads 4 of 4 slots and no shortfall (was 3 of 4, the kit named);
     - the builder's kits are 5 and 4 steps (were 4 and 3);
     - each verdict case names its system with that fix taken out (the bar alone names the fight itself; totals out, growth; 50 Spirits, rarity; walls out, techniques; bar 0, VIABLE).
   - **The growth drive:** X's toast reads "a 420 stat total at least". F5's RORY walks out on PWR 55 (Circuit's 52 +2 +1; was 48).
   - **Determinism:** C49's reduced line reads DEX 555 with Palisade (was 472), Ioan 6–0 (was 8–0). No other line moved.
7. **Note NP_14:**
   - C50 added (5 gates, the fixes on the determinism log, `-- audit` GREEN).
   - Amended with "since C50" lines, nothing removed: C49's findings and not-claimed line, C45's not-claimed line on the defensive boards, C44's reading of the caps.
   - A new not-claimed bullet names what C50 does not build, and its readings.
   - The `-- audit` reproduction line now reads "since C50 GREEN".
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C50.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **NP_11 s1, "Stat totals by rarity keep early recruits viable":**
     - the least total at each tier, the card's own stats scaled in proportion (his shape kept) to the tier's cap, the board and the raises on top;
     - National's 490 is the late recruits' card (70 a stat), so the catch-up ends where they begin and never moves them;
     - the Legend adds the 99 cap and the Awakening, not a total.
   - (b) **NP_05 s3, the T2 unlock "Anchor-class fighters + defensive boards":**
     - a node on every style's board (the Anchor Wall); taking it makes the board defensive;
     - a T2 in a slot needs it from any source;
     - NP_05 s10's "Anchor board" source is that board teaching the three `board:anchor` walls;
     - anchor-class is not read on its own: the formation reads it from a squad (C27).
9. **Editorial, to confirm or overrule:**
   - the totals 420 / 490 / 490, the proportional split and the overflow to the lowest stat;
   - the node's name, place and price (3);
   - all three walls open to every card, their order;
   - the aid's rule (seek the node when only a WALL can fill a slot);
   - the respec taking a T2 out of the kit.

   To reverse the rules and numbers, edit the two tables.
10. **FINDING — flag for @heat.** `-- audit` is GREEN, 3 of 3 viable:
    - PRIYA 11 of 14 (79 %; her total 547 against the references' 548–551);
    - DEX 14 of 14; YURI 14 of 14;
    - every kit 4 of 4 slots, every move answering.

    Still open, and named in C50's not-claimed: at level 45 five slots meet four free families, so one slot is hollow again. That is the postgame; an audit run there would name it.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-096 row (CSV-ready, todo columns)
ID: PAC-096 | Title: Fix what the audit names: the kit's hollow slot and PRIYA's growth | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: `-- audit` GREEN (3 of 3 viable), with the audit unchanged as the acceptance test.
- **Techniques:** at level 35, every technique slot holds a move that answers a motion, from live sources by Arc 3.
- **Growth:** the earliest card's built total within 10 % of the late recruits' total, by a catch-up on the board or the raises.
- **Gates:** each fix against its absence; no fighter's own numbers edited; determinism with the fixed build in the log.

Delivered through NP_05 s3's defensive board (a fifth family, WALL) and NP_11 s1's stat totals by rarity. Both are canon lines found while reading. 044's recommended defaults (T2 rows on the shop, raises priced by distance) are superseded:
- every T2 is WALL, so a T2 cannot be a second move on a stick family;
- 100 Beans buy about 20 raises at most, against a gap of 94.

The growth fix therefore sits in rarity, not in the board or the raises as the DoD worded it. The audit's growth system named the gap, and NP_11 s1 puts the catch-up in rarity.
BlockedBy: PAC-095 | DependencyType: soft | RelatedWork: NP_11 s1 s2 s3 s4 s10; NP_05 s3 s4 s8 s10; NP_14 C27 C44 C45 C49 C50; data/growth.v1.json; data/techniques.v1.json; data/audit.v1.json
Notes: 2026-09-25: -- audit GREEN (exit 0), 3 of 3 viable: PRIYA 11/14 (total 547 against the references' 548-551), DEX 14/14, YURI 14/14, every kit 4 of 4 slots answering; audit.gd unchanged. SMOKE 416/416 GREEN x 24 bosses (9,984 assertions; +5; five gates moved, command 6; otherwise only the content stamp and the hash of C49's fight). DETERMINISM 50/50 (the fixes on the log: PRIYA built and fought against Chiamaka Okafor, identical twice, different without the totals; C49's reduced line moved). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: growth 8/8 (two checks moved), gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo growth (29 steps), demo gear boss=1 (60,000 frames), demo mirror (one dual, one mirror spar, no counter this run), demo hybrid.
LearningNotes: Both fixes were in the vault already, unread. NP_11 s1 pairs "stat totals by rarity" with "any fighter can reach tier 3", and NP_05 s3 gives T2 its own unlock ("Anchor-class fighters + defensive boards"). C44 had read rarity as caps only, and C45 had parked the board's walls as "not built". A probe settled how the lift is split. PRIYA lifted to 490 by flat fill (every stat to 70) won 10 of 14 as a copy of the late recruits' card; scaled in proportion she won 11 of 14 and stayed the RFX out-boxer. Lifting her own card under the growth, instead of flooring the grown total, keeps every node and raise worth something: a floor over the grown total would have swallowed her first 90 points of training. Taking a fix out is the proof each one is needed: without the totals PRIYA loses to Chiamaka 0-5 and the audit names growth; without the walls her fourth slot stays empty and the audit names the kit. The aid's rule (seek the wall only when a slot has no family left) kept every older board pick below level 35 as it was. The older figures that moved are an ascended card's stats (the totals) and C49's lines, which the fixes answer.
StartedAt: 2026-09-25T05:26:07Z | DoneAt: 2026-09-25T06:30:43Z

## PAC-097 row (CSV-ready, todo columns)
ID: PAC-097 | Title: The faucet/sink audit (NP_11 s6) as an executable gate | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_11 s6's faucet/sink audit on the sim, in the obsolescence audit's pattern.
- **The faucet:** a story-pace player's earnings through Arc 3 (XP, Spirits, HBP, Prestige, Beans) read off the sim's own reward paths - the duals, scraps, spars, quests and training slots NP_12 s4's beats imply - on a named schedule.
- **The sinks:** the desired sinks priced from the live tables (ascensions, techniques, gear, raises, facilities, scouting).
- **The verdict:** the share afforded against NP_11 s6's 70 % target, per currency, with the long tails named (Prestige, Beans). The obsolescence audit's budget is checked against the faucet.
- **Gates:** each currency's faucet against its absence; the verdict naming the currency that misses; determinism with the schedule in the log.
BlockedBy: PAC-096 | DependencyType: soft | RelatedWork: NP_11 s6 s7 s10; NP_13 s6 R-07; NP_12 s4; NP_14 C22 C43 C49 C50; data/economy.v1.json; data/facilities.v1.json; data/audit.v1.json
Notes: Alternative for PAC-097: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
