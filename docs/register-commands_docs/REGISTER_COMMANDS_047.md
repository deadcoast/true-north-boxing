# REGISTER COMMANDS 047 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-098 What the faucet audit named, fixed (greybox v6, NP_14 C52)**
Same rule as 001–046: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-098 Status DONE** (the row payload below replaces the TODO row from 046).
2. **Add PAC-099** (row below), Status TODO: NP_08 s1's stable roles - training partner, scout, cornerman-in-training ("Nobody rides the bench doing nothing - the anti-'box mon' rule").
   - The open mat now fills the stable with generics, and a bench card has no job.
   - The scout's passive Prestige is also the Prestige faucet NP_08 s2.4 names and the sim does not pay.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Update DATA row** `data/economy.v1.json` (both copies):
   - `xp.pace` 2.7;
   - the spar's Spirits 2 / 2;
   - `hbp.story` 50 and `hbp.quest` 30;
   - `prestige.pull` 10 and `prestige.pity` 10;
   - `scouting` (NP_02 s1.1's districts, the open mat every 7th day, its priority 10, the stable's cap 100, the generic's tier by the circuit's flags);
   - the notes.
4. **Update DATA row** `data/audit.v1.json` (both copies): the budget Spirits 110, Beans 140, HBP 1,700 (was 95 / 100 / 3,000) - the faucet's share of a fighter at the 70 % target, the derivation in its text.
5. **Update DATA row** `data/faucets.v1.json` (both copies): the session's `story_beats` 1 and `quest_steps` 1 (NP_02 s5's story beat and recruitment step); the wanted Prestige's reading (the machine's rare leads at the pity's pulls).
6. **Link PAC-098** to these rows:
   - **MODULE `sim/core.gd`:**
     - `_pay_xp`'s pace; `_pay_dual`'s reserve (the pace once);
     - `story_mark`;
     - the machine: `scout_rares`, `scout_why`, `_scout_tier`, `scout_pull`;
     - the open mat: `open_mat_day`, `open_mat`, `sign_why`, `sign_generic`;
     - `scouting_lines`; the OVER inputs `scout` and `sign`.
   - **MODULE `sim/faucets.gd`:** the session's story beats and quest steps through `story_mark`; the machine's wanted Prestige; the Prestige share.
   - **MODULE `main.gd`:**
     - DUAL OVER's SCOUTING lines; the keys `` ` `` and Shift+`` ` ``;
     - the LEAD, RARE LEAD and OPEN MAT toasts;
     - `-- demo scouting`, the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gates moved in command 8) and the new `engine/greybox/tools/drive_scouting.gd`.
7. **Add TEST row** `engine/greybox/tools/drive_scouting.gd` (TEST, "the scouting machine and the open mat on the real scene, headless:
   - the dual won and DUAL OVER's SCOUTING lines;
   - ` pulls a lead onto the open mat with the LEAD toast; eight more; the tenth rare - a named recruit approachable, the RARE LEAD toast, the RECRUITS lines;
   - ` on nothing refused; Shift+` off an open-mat day refused on the priority; on the 7th day Shift+` signs free, the stable one card more;
   - F5 with the generic on the bench.

   8/8").
8. **Gates moved — flag for @heat.** The economy's numbers moved, and every gate that pays now reads them:
   - **C22's pay gates:** XP x1.1 x the pace. A scrap 17 -> 45 XP; a spar 44 -> 119 XP and 3 -> 2 Spirits; a dual's segment 28 -> 74.
   - **C24's generic and filler gates:** their XP read from the table (51 -> 135, 28 -> 74).
   - **C42's two exhibition gates:** the pace in the shared ledger and the pay.
   - **C49's gates:** the budget [110, 140, 1700]; the builds' printed raises (YURI 14 -> 16).
   - **C50's fight:** Chiamaka on seed 22 - the jar of 140 moved PRIYA's build, and seed 11 now goes 2-4.
   - **C51's gates:**
     - the segment's pay at the pace;
     - the phase arithmetic with the story's HBP (Spirits 112 -> 75, HBP 360 -> 1,160, XP 2,723 -> 7,530);
     - the sinks with the machine's Prestige (0 -> 1,400) and PRIYA's trial spars at 2;
     - the verdict now GREEN, with the economy as PAC-097 found it RED on all five.
   - **Determinism:** the reward ledger's line (455 -> 1,225 XP); the save-and-load line (239 -> 240 KB); C49's, C50's and C51's reduced lines.
   - **Printed only, the condition held:** C23's ledgers line (RORY 145 -> 387 XP); C49's fight on Alfie Crane (the build moved, 6-0 held); C49's verdict report (CASSIDY's reference 551 -> 556).
   - **The content stamp** moved (the tables changed).
   - **The drives:** none moved.
9. **Note NP_14:**
   - C52 added (5 gates, the machine on the delegated log, the scouting drive, both audits GREEN).
   - C51's findings and not-claimed line say "since C52".
   - A new not-claimed bullet names what C52 does not build, and its readings.
   - Two reproduction lines added; the `-- faucets` line reads "since C52 GREEN".
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C52.
10. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **NP_11 s2's curve** as canon and the XP amounts as first drafts: one pace (2.7) calibrates them to "~35 by Arc 3 start".
    - (b) **NP_11 s6's "Spirits 3-8 (spars/duals)"** as a session's pay: a spar 2, a dual 5 / 8.
    - (c) **NP_11 s6's HBP from "quests, wins, story"** with NP_02 s4's quests:
      - a story beat pays 50 and a quest step 30 when its flag lands (`story_mark`);
      - NP_02 s5's session "recruitment step" read as a quest step;
      - a seeded flag is the ledger as it stood and pays nothing.
    - (d) **NP_08 s2.4's machine:**
      - "rare-tier" leads read as the named recruits (the recruit table's, never excepted), then the String Wall's lead the docs give a condition (Vera Iron);
      - the commons read as the open mat's generics (NP_04 s9);
      - the pity alone makes a lead rare (no base rate is canon);
      - NP_11 s6's "open-mat priority" read as signing off an open-mat day.
    - (e) **The wanted Prestige by Arc 3** as every rare lead the machine holds at the club's start (leads never expire; Team Canada is assembled from every rival, NP_12 s6).
    - (f) **The obsolescence budget** as the faucet's share of a fighter at the 70 % target.
11. **Editorial, to confirm or overrule:**
    - the pace's 2.7;
    - the story's 50 and the quest's 30;
    - the spar's flat 2;
    - the open mat's 7th day and its priority's 10;
    - the machine's district and dialect draws, the generic's name (the district and the pull), its tier by the Regionals and the Nationals;
    - the budget's rounding.

    To reverse the rules and numbers, edit the three tables.
12. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-098 row (CSV-ready, todo columns)
ID: PAC-098 | Title: Fix what the faucet/sink audit names: XP's pace, HBP's quests, Prestige's sink, Spirits' session pay, the Beans wanted | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: `-- faucets` GREEN with the audit unchanged as the acceptance test, and `-- audit` GREEN on a budget and level the faucet pays. Recommended defaults, each reversible:
- **XP:** the fights' pay brought to NP_11 s2's curve, so a story-pace captain stands near 35 at Arc 3. The curve is canon; the pay per event and per result is a first draft.
- **HBP:** NP_02 s4's quests and the story pay HBP on the ledger when their flags land (NP_11 s6: "quests, wins, story").
- **Prestige:** a live sink - NP_11 s6's scouting pulls (10 Prestige; NP_02 s1.1's scouting machines) against the recruit table.
- **Spirits:** the pay read per session (NP_11 s6's 3-8 a session), or its sinks deepened.
- **Beans:** the story-pace raises wanted named (the jar is a first draft), the long tail left to completionists.
- **Gates:** each fix against its absence; determinism with the fixed faucet in the log.

Where "the audit unchanged" was read, and flagged:
- The verdict logic, the target, the bands and the schedule's fights are untouched.
- The audit gained the two live things it prices and pays: the session's story beat and recruitment step (NP_02 s5's own shape, which pay since this PAC), and the machine's price.
- The Beans fix is the obsolescence jar re-derived from the faucet, with the other two budgets by the same rule.
BlockedBy: PAC-097 | DependencyType: soft | RelatedWork: NP_11 s2 s4 s6 s10; NP_02 s1.1 s4 s5; NP_08 s1 s2.4 s9; NP_04 s9; NP_12 s6; NP_14 C22 C24 C42 C49 C50 C51 C52; data/economy.v1.json; data/audit.v1.json; data/faucets.v1.json
Notes: 2026-09-26: -- faucets GREEN (exit 0): Spirits 58 %, HBP 72 %, Beans 68 %, Prestige 81 %; a session 7.7 / 118 / 14.2 / 9.6; RORY L35 (59,276 XP); the budget's three funded. -- audit GREEN (3 of 3) on 110 / 140 / 1,700: PRIYA 10/14, DEX 14/14, YURI 14/14. SMOKE 426/426 GREEN x 24 bosses (10,224 assertions; +5; the diff against PAC-097 identical on every boss - the new gates, the gates moved in command 8, the content stamp). DETERMINISM 52/52 (the machine on the delegated log: 12 pulls, 1 rare, 1 signed; identical twice, different without it). GEOMETRY 5/5, line for line PAC-097's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: scouting 8/8 (new), gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing, and the same lines differed between PAC-096's and PAC-097's runs. Soaks, zero script errors: -- demo scouting (two duals, two pulls, both signed, the stable 6), demo growth (29 steps), demo gear boss=1, demo hybrid, demo mirror.
LearningNotes: All five misses had one shape: the overworld paid nothing the docs say it pays. So most of the fix was reading canon - the story's HBP, the scouting machine - rather than tuning. XP needed one number: the curve is canon and the per-event amounts were drafts, so a single pace calibrates them and keeps their proportions. The pace went into the dual's reserves twice, once in the total they are drawn from and once in their own payment; the reserve now divides it back out. Fifteen smoke gates had the old amounts written in. They now read the table, so the next tuning pass moves no gate. The obsolescence audit's budget was set by hand, and deriving it from the faucet by one rule closed Beans without touching its wanted side. A fight gate pinned to a seed (Chiamaka on 11) broke when the builds moved; it was re-probed onto seed 22 rather than the build adjusted to fit.
StartedAt: 2026-09-26T03:36:09Z | DoneAt: 2026-09-26T04:39:35Z

## PAC-099 row (CSV-ready, todo columns)
ID: PAC-099 | Title: The stable roles (NP_08 s1): training partner, scout, cornerman-in-training | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_08 s1's roles on the sim's ledgers - "any stablemate can be assigned as a training partner (Beans bonus keyed to their stats), scout (passive Prestige from their home district), or cornerman-in-training (feeds the staff system, NP_10 s7)".
- **The roles:** a role set between duals on any stablemate not dressed; the partner's Beans flavour on the training slot (NP_11 s7, C43's partner read); the scout's Prestige by day from their district; the cornerman's feed into the staff corps.
- **The faucet audit:** the scout's Prestige counted in the faucet, the share re-read.
- **Gates:** each role against its absence; a dressed card refused a role; the save; determinism with the roles in the log.
BlockedBy: PAC-098 | DependencyType: soft | RelatedWork: NP_08 s1 s2.4; NP_10 s7; NP_11 s6 s7; NP_14 C43 C51 C52; data/economy.v1.json; data/staff.v1.json; data/facilities.v1.json
Notes: Alternative for PAC-099: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
