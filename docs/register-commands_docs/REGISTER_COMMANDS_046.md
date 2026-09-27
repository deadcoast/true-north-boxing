# REGISTER COMMANDS 046 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-097 The faucet/sink audit (greybox v6, NP_14 C51)**
Same rule as 001–045: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-097 Status DONE** (the row payload below replaces the TODO row from 045).
2. **Add PAC-098** (row below), Status TODO: fix what the faucet/sink audit names, with `-- faucets` GREEN as the acceptance test and `-- audit` staying GREEN on the budget and level the faucet actually pays. All five currencies miss (command 7).

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Add DATA row** `data/faucets.v1.json` (DATA, "NP_11 s6's faucet/sink audit as the audit reads it:
   - the 70% target and its band;
   - the story-pace playthrough to Arc 3's start: NP_12 s8's 24 Arc 1 episodes and Arc 2 at Arc 1's length, NP_02 s5's cadence (75 min a story dual) and 45-minute session shape (5 scraps, 1.5 spars, 1 training slot);
   - three phases with their formats, losses, flags, gym tiers and hosting;
   - the results given, the protagonist's level by Arc 3 (35 ± 2);
   - the sample a segment's XP is measured from;
   - the sinks wanted (eight built as the obsolescence audit builds, every facility track to T3, one Forge);
   - NP_11 s6's typical/session; the system each miss names").

   Both copies. The sim does not read it.
4. **Link PAC-097** to these rows:
   - **MODULE `sim/core.gd`:**
     - `event_xp` (the XP one fight event earns - the segment's accumulator and the audit read it);
     - `pay_segment` (a segment's XP, called by `_end_segment` and the audit);
     - `load_content` reads `faucets`.
   - **MODULE `sim/faucets.gd`** (new, static): `sessions_of`, `mk`, `fight_xp`, `sample`, `pay_dual`, `pay_bout`, `scrap_objective`, `faucet`, `spend_of`, `sinks`, `run`, `lines`.
   - **MODULE `main.gd`:** the `-- faucets` test mode and its help line.
   - **TEST rows:** `sim/tests.gd` (`faucets()`, 5 smoke gates, 1 determinism gate).
   - `sim/audit.gd` is unchanged. There is no drive: nothing on the scene changed.
5. **Gates moved — flag for @heat.** None. The segment's XP now flows through `pay_segment` and `event_xp`, and every older smoke and determinism line is byte-identical.
6. **Note NP_14:**
   - C51 added (5 gates, the audit reduced on the determinism log, `-- faucets`' verdict).
   - C49's and C50's not-claimed lines on the economy's pacing now point at C51.
   - A new not-claimed bullet names what C51 does not build, and its readings.
   - One reproduction line added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C51.
7. **FINDINGS — flag for @heat.** `-- faucets` on this build: **RED, all five currencies.**

   A story-pace playthrough to Arc 3's start (48 story duals, 80 sessions) pays Spirits 900, HBP 3,040, Beans 770 and Prestige 1,140.
   - **XP:** RORY reaches level 21 (22,104 XP), where NP_11 s2's ~35 wants 58,800. The obsolescence audit builds at 35.
   - **HBP:**
     - 23 % of the 13,150 wanted: eight fighters at 800 (the shop's kit) and the gym's 6,750.
     - 38 a session against NP_11 s6's 50-150. NP_02 s4's quests and the story pay nothing on the sim; only wins pay.
     - The obsolescence audit's 3,000 HBP a fighter for its three is 9,000, three times what the faucet pays.
   - **Spirits:**
     - 86 % of the 1,050 wanted.
     - 11.2 a session against NP_11 s6's 3-8: `economy.v1.json` reads 3-8 as a fight's pay, and a session holds a dual's share and a spar and a half.
   - **Beans:** 93 % of the 830 wanted. The wanted raises are the obsolescence audit's jar (100 a fighter), a first draft; NP_11 s6 calls Beans a long tail.
   - **Prestige:** 1,140 paid into no live sink. NP_11 s6's scouting pulls (10) and open-mat priority are not built.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"a story-pace player"** as the critical path:
     - NP_12 s8's 24 Arc 1 episodes, a story dual each;
     - NP_02 s5's "one dual per 60-90 min" (75) and its 45-minute session shape at the midpoints;
     - the optional duals not taken.
   - (b) **NP_11 s6's "Earn (typical/session)"** as per 45-minute session (NP_02 s5's).
   - (c) **"desired sinks"** as the sanctioned dual's eight built as the obsolescence audit builds (priced off each build's ledger), every facility track to T3 and a Forge.
   - (d) **"target - affords 70%"** as a share of the wanted, per currency.
9. **Editorial, to confirm or overrule:**
   - Arc 2 at Arc 1's length; the phase split and its flags and gym tiers; the hosted half of Arc 2;
   - the results (9 in 10 scraps, 7 in 10 spars, 3 in 5 segments in a win, 2 in a loss, the median grade), the captain fighting the overworld;
   - the ±15 band and the ±2 levels;
   - one Forge; a segment's XP measured from the obsolescence audit's builds against its endgame.

   To reverse the rules and numbers, edit `faucets.v1.json`.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-097 row (CSV-ready, todo columns)
ID: PAC-097 | Title: The faucet/sink audit (NP_11 s6) as an executable gate | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_11 s6's faucet/sink audit on the sim, in the obsolescence audit's pattern.
- **The faucet:** a story-pace player's earnings through Arc 3 (XP, Spirits, HBP, Prestige, Beans) read off the sim's own reward paths - the duals, scraps, spars, quests and training slots NP_12 s4's beats imply - on a named schedule.
- **The sinks:** the desired sinks priced from the live tables (ascensions, techniques, gear, raises, facilities, scouting).
- **The verdict:** the share afforded against NP_11 s6's 70 % target, per currency, with the long tails named (Prestige, Beans). The obsolescence audit's budget is checked against the faucet.
- **Gates:** each currency's faucet against its absence; the verdict naming the currency that misses; determinism with the schedule in the log.

Two DoD lines read differently in the build:
- Quests and scouting are in neither the faucet nor the sinks, because neither pays or charges on the sim. The audit names both instead: HBP's missing quest pay and Prestige's missing sink.
- "Each currency's faucet against its absence" is the verdict machinery against opened bars, and the faucet against the economy table's arithmetic to the unit.
BlockedBy: PAC-096 | DependencyType: soft | RelatedWork: NP_11 s2 s6 s7 s10; NP_02 s4 s5; NP_12 s4 s5 s8; NP_13 s6 R-07; NP_14 C22 C43 C49 C50 C51; data/faucets.v1.json; data/economy.v1.json; data/facilities.v1.json; data/audit.v1.json
Notes: 2026-09-26: -- faucets RED (exit 1), all five currencies named (command 7); -- audit GREEN (3 of 3). SMOKE 421/421 GREEN x 24 bosses (10,104 assertions; +5; every older line byte-identical). DETERMINISM 51/51 (the faucet/sink audit reduced: its sample spar and Arc 1's first phase identical twice, a phase one episode longer different; no older line moved). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo growth (29 steps), demo gear boss=1, demo hybrid, demo mirror x3 (one dual and one mirror each; a fixed-seed run on this build and on PAC-095's code matched count for count - two duals, two mirrors, 5 counters, 6 KOs - so the clock seed, not the code, set the count).
LearningNotes: The economy table paid the fights, and nothing held the pay against the curve, the sessions or the sinks. Paying the playthrough through the sim's own paths needed two seams. A segment's XP was one rule written inline in the event handler; `event_xp` and `pay_segment` now carry it, and the audit reads the same lines the fight pays through. Pricing a build as budget less what is left read its Spirits 10 short, because the obsolescence build's trial spars pay into its ledger as it builds; each build is priced off its ledger instead. A delegated dual set up and then delegated leaves R1 standing: the profile takes the segments that load after it, so the gate calls new_dual. The largest finding is structural rather than tuning. XP and HBP are paid by fights alone, while NP_11 s2's ~35 by Arc 3 and s6's HBP 50-150 a session assume the whole overworld pays - quests, story beats, items. The mirror soaks' single dual looked like a regression until a fixed-seed A/B against PAC-095's code matched it count for count.
StartedAt: 2026-09-26T01:27:05Z | DoneAt: 2026-09-26T02:46:20Z

## PAC-098 row (CSV-ready, todo columns)
ID: PAC-098 | Title: Fix what the faucet/sink audit names: XP's pace, HBP's quests, Prestige's sink, Spirits' session pay, the Beans wanted | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: `-- faucets` GREEN with the audit unchanged as the acceptance test, and `-- audit` GREEN on a budget and level the faucet pays. Recommended defaults, each reversible:
- **XP:** the fights' pay brought to NP_11 s2's curve, so a story-pace captain stands near 35 at Arc 3. The curve is canon; the pay per event and per result is a first draft.
- **HBP:** NP_02 s4's quests and the story pay HBP on the ledger when their flags land (NP_11 s6: "quests, wins, story").
- **Prestige:** a live sink - NP_11 s6's scouting pulls (10 Prestige; NP_02 s1.1's scouting machines) against the recruit table.
- **Spirits:** the pay read per session (NP_11 s6's 3-8 a session), or its sinks deepened.
- **Beans:** the story-pace raises wanted named (the jar is a first draft), the long tail left to completionists.
- **Gates:** each fix against its absence; determinism with the fixed faucet in the log.
BlockedBy: PAC-097 | DependencyType: soft | RelatedWork: NP_11 s2 s6 s10; NP_02 s1.1 s4 s5; NP_08 s2; NP_14 C22 C49 C51; data/economy.v1.json; data/faucets.v1.json; data/audit.v1.json
Notes: Alternative for PAC-098: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
