# REGISTER COMMANDS 039 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-090 The fighter's growth (greybox v6, NP_14 C44)**
Same rule as 001–038: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-090 Status DONE** (the row payload below replaces the TODO row from 038).
2. **Add PAC-091** (row below), Status TODO: teachable techniques and the technique slots (NP_11 §2, §8).
   - The slots a fighter carries (5 / 15 / 25 / 35 / 45, the house natives' bonus slots adding) and his T0 signature at 5.
   - The sources: masters, the HBP shop, fight tapes, the house natives (C31's), the hybrids (C41's), and the re-teach through a training slot (C43's).
   - The card's equipped kit, read by the sim at the bell.

   Alternative: the Toronto academy's industrialized hybrids as Arc 3's thesis mechanic (NP_07 §10).
3. **Add DATA row** `data/growth.v1.json` (DATA, "NP_11 s3/s4/s6's growth as the sim reads it: the four style layouts (60 hex nodes each - the spine with the stance and the Boxer-Puncher's off-style socket, the Body lobe's stat nodes and soft-cap breakers, the Craft and Spirit lobes' passives), NP_11 s3's nine passives of a 40 pool with their numbers and home styles, two named nodes for each Millbrook card and the rule for a recruit's, the costs and the 70+ doubling, respec at the Film Room's T2, the raises (5, +1 a raise), the typed Beans' partner quarter, rarity's caps 70/80/90/99, Spirits 10/25/60, trials, accessory slots and the Legend's Awakening flag"). Both copies.
4. **Link PAC-090** to these rows:
   - **MODULE `sim/core.gd`:**
     - `GROW` through `setup`'s last argument, in the content stamp;
     - the board: `growth_layout`, `growth_nodes`, `_named_nodes`, `gpoints`, `gpoints_free`, `taken`, `node_cost`, `node_why`, `take_node`, `node_best`, `respec_why`, `respec`, `socket_why`, `socket`;
     - the fighter at the bell: `grown_stats` (`_load_segment`, the carried condition, `_stat_sum`, STAT_PROOF), `passives_of`, `_pas` / `_pv` at the nine hooks;
     - the Beans: `beans_typed`, `beans_untyped`, `_beans_type` (in `train`), `_beans_settle` (after the Forge), `jar_text`, `raise_cost`, `raise_why`, `raise_stat`, `raise_best`;
     - rarity: `rarity_of`, `rarity_cap`, `accessory_slots`, `awaken_eligible` (in `_awaken_gate`), `ascend_why`, `ascend`, `_trial_mark` (`_end_bout`, `_boss_tform_end`), `mirror_card`, `start_mirror` (`start_spar`'s `fighter` / `mirror`, `_build_lineup`);
     - `growth_line`, `grow_aid`, the OVER input `grow`, `seed_growth`, `seed_beans`.
   - **MODULE `sim/save.gd`:** each Fighter's `rarity`, `board` (`layout_id`, `nodes_taken`, `points_free`, `socket`), `raises`, `stats_grown`, `passives`, `awakening_flag`, `accessory_slots`; a generic card's flag kept.
   - **MODULE `sim/exhibition.gd`:** the growth table passed to both engagements.
   - **MODULE `main.gd`:**
     - DUAL OVER's GROWTH lines, `[N]`, Shift+`[N]`, `[Z]`, `[X]`, `[M]`, `[.]`;
     - the THE BOARD, RESPEC, THE JAR, ASCENDED and TRIAL toasts, the training toast's types, the matchup card's PASSIVES line;
     - `-- growth=`, `-- beans=`, `-- nodes=`, `-- demo growth`;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gate moved in command 6) and the new `engine/greybox/tools/drive_growth.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_growth.gd` (TEST, "the fighter's growth on the real scene, headless: RORY at the bell on his card, no passives; the dual won and DUAL OVER's GROWTH lines; N, N take the craft lobe's +2 and Tight Guard; Z raises PWR on the PWR Beans; X ascends RORY to Circuit; Shift+N respecs at the Film Room; F5's next dual with the grown PWR and Tight Guard on him (the matchup card's PASSIVES line); [.] and [M], PRIYA's mirror spar. 8/8").
6. **Gates moved — flag for @heat.**
   - The content-table gate (C36's statement, PAC-074's gate) lists 26 tables, with `GROW`.
   - One older determinism figure moved: the save-and-load line's text size, 216 KB to 217 KB (each Fighter record carries its growth). Every other line of the determinism log is figure for figure as before.
   - Printed figures in the smoke moved with it, no gate's condition: the PAC-069 save's text (14,036 to 15,743 bytes) and its file (80 to 82 KB), and the content stamp's value. Every other smoke line is as it was, on all 24 bosses.
7. **Note NP_14:**
   - C44 added (5 gates, the fighters' growth on the delegated log, the growth drive).
   - The not-claimed bullets on scraps and spars (the mirror), the reward economy and the club facilities say what C44 now runs.
   - A new not-claimed bullet names what C44 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C44.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"70+ costs double board points"**: a stat node's price when that stat stands at 70+ as grown. A stat's "soft-cap breaker" lifts the doubling for that stat. The raises' Beans do not double.
   - (b) **"Stat-cap raises (→80/→90/→99)" and "90+ requires rarity tier 3"**: caps of 70 / 80 / 90 / 99 on growth only. A card's own stats stand as dressed (RORY's HRT 99 at Club). A stat node at the cap is passable and adds nothing, so no lobe is walled off.
   - (c) **The trials**: NP_11 §4 names two for three ascensions. Circuit's is a spar won (editorial), National's a transform weathered (C40's Stood in the Storm), the Legend's the mirror beaten.
   - (d) **The mirror** is the fighter's own card, grown, on strings assembled for it (C24's generic path). It is not NP_02 §2.2's lab flag (a copy of his habits, the tracker as content).
   - (e) **"+1 equip slot for accessories"**: one a tier to the schema's three (1 / 2 / 3 / 3). The gear itself is not built.
   - (f) **The Awakening flag**: a card not marked `generic` is a story character, pre-flagged; a generic's flag is the Legend's. C39's story gate still applies to both.
   - (g) **"+1 = 5 Beans, scaling"**: +1 Bean for each raise already bought on that stat.
   - (h) **Typed Beans**:
     - the types are the stats; a slot's Beans take its game's bias, and "any" is untyped;
     - a partner along types a quarter (rounded) as his best grown stat;
     - the untyped pay any raise and another stat's never do;
     - the Forge spends the untyped first.
   - (i) **"Boards differ by Style archetype"**: the craft passives split by style (Swarmer: Ring Cutter, Second Gear, Iron Jaw; Out-Boxer: Snap, Tight Guard, Second Gear; Slugger: Iron Jaw, Ring Cutter, Tight Guard; Boxer-Puncher: Tight Guard, Snap, and the socket for one of the other three). The Spirit passives are on every board.
   - (j) **"Respec: free at the gym (Film Room T2+)"**: every Board Point back and the socket emptied. The raises' Beans stay spent.
   - (k) **Iron Jaw's "wobble duration −30%"**: the wobble is a composure threshold (below 35 %), so the composure climbs out of it 1/0.7 as fast — 30 % less time wobbled for the same regen path.
9. **Editorial, to confirm or overrule:**
   - The layouts (60 nodes each: the spine 8, the Body lobe 24, the Craft and Spirit strips 14), every price (+2 / +3 / +5 at 1 / 2 / 3, a breaker 2, a passive 3, the socket 2), the Club cap 70 and the partner's quarter.
   - The named nodes: two for each of the eight Millbrook cards (Borealis Wind-up, Millbrook Stubborn; Marginalia, The Plan's Feet; Chinook Shoulders, Arm Talk; First Snap, Small and Busy; Sorry Eh, The Tagaq Shell; Prodigal, Harbour Hands; Grain-Sack Wraps, Elevator Legs; Miroir, Winter Guard), and the rule for a recruit's (+3 on his two best stats).
   - The aid's pick: a passive in reach, else the first step toward the nearest, else the best stat for its price.
   - `[N]`, Shift+`[N]`, `[Z]`, `[X]`, `[M]`, `[.]` on DUAL OVER; `-- growth=`, `-- beans=`, `-- nodes=`, `-- demo growth`; the toasts' wording.
   - To reverse the rules and numbers, edit the table.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-090 row (CSV-ready, todo columns)
ID: PAC-090 | Title: The fighter's growth (NP_11 s3, s6) — ability boards, stat raises on typed Beans, rarity ascension | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The ability boards as data (NP_11 s3): the four style layouts, ~60 hex nodes in three lobes and a shared spine, the stat nodes' tiers and soft-cap breakers, the 40-passive launch pool with its first passives live on the sim (Tight Guard, Snap, Ring Cutter, Iron Jaw, Second Gear, Sparkplug, Cheap Trick, Closer, Wallflower), the Boxer-Puncher off-style socket, 2-4 nodes injected per named character; points from levels; respec free at the gym from the Film Room's T2 (C43). Typed Beans from the training slots (each game's bias, a partner's flavour) and the stat raise (+1 = 5 Beans, scaling). Rarity ascension on Spirits (10/25/60). The save's Fighter.board. Gates cover the boards, each live passive against the same sim without it, the raises and their scaling, the ascension, respec and the save; determinism with a board in the log.
BlockedBy: PAC-089 | DependencyType: soft | RelatedWork: NP_11 s1 s2 s3 s4 s6 s7 s9; NP_06 s1.2; NP_02 s2.2; NP_09 s6; NP_10 s7; NP_14 C22 C24 C39 C40 C41 C43 C44; data/growth.v1.json
Notes: 2026-09-24: SMOKE 386/386 GREEN x 24 bosses (9,264 assertions; +5). DETERMINISM 44/44 (the fighters' growth on the delegated log vs Yuri's squad, the log twice over: the aid's 36 steps before the bell - the four boards to their first passives, RORY to Circuit on his trial - and 8 nodes between the duals; identical twice, different from the same log and ledger with no growth; one older figure moved, the save's size 216 -> 217 KB). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo growth boss=1 at level 12 with nodes=RORY:*,PRIYA:c1+c3 (60,000 frames, x2) - RORY's five passives before the bell, two and three duals, the aid's nodes, raises on the PWR Beans then the untyped and MARCUS to Circuit between them (29 and 36 steps); -- demo growth facilities boss=7 at level 8 (60,000 frames, x2) - seven and six renovations, five training slots typing their Beans, each card's first passive and a raise on the RFX Beans (14 steps each); -- demo hybrid (x1) - Grain & Snow forged and cast relayed three times. One gate moved (command 6); the smoke's printed save sizes and content stamp moved with the new table and records, no gate's condition.
LearningNotes: My first cut refused a stat node at the fighter's cap. The aid's first probe showed what that does to a card already over the cap: RORY's HRT 99 walled him out of the whole Spirit lobe, whose entrance is +2 HRT. The cap now makes such a node passable and worth nothing, so no card is cut off from a lobe by its own stats. The typed jar keeps its one total with the types beside it (the untyped are the difference), so the Forge, the training gates and every older reader of the Beans stayed where they were.
StartedAt: 2026-09-24T16:25:13Z | DoneAt: 2026-09-24T17:37:12Z

## PAC-091 row (CSV-ready, todo columns)
ID: PAC-091 | Title: Teachable techniques and the technique slots (NP_11 s2, s8) | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The technique slots from levels (5/15/25/35/45; the house natives' bonus slots add, NP_07 s7) and the T0 signature at 5. The sources as data and on the ledger: masters (a recruit or befriended fighter teaches his list, some gated by BOND or STAT_PROOF), the HBP shop (the generic library in tiers by circuit progress, 100-800 HBP), fight tapes (single-use teaching items), the house natives (C31) and the hybrids (C41). Transfer: a learned non-native re-taught to a stablemate through a training slot (C43), the original keeping it. The card's equipped kit read by the sim at the bell (which hissatsu he carries into the dual). Gates cover the slots by level, each source refused and paid, the re-teach, the kit in the fight and the save's technique_slots; determinism with a taught kit in the log.
BlockedBy: PAC-090 | DependencyType: soft | RelatedWork: NP_11 s2 s6 s8 s9; NP_07 s4 s7; NP_05 s3; NP_08 s6; NP_14 C31 C41 C43 C44; data/hissatsu_library.v2.json; data/economy.v1.json
Notes: Alternative for PAC-091: the Toronto academy's industrialized hybrids as Arc 3's thesis mechanic (NP_07 s10).
