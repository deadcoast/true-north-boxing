# REGISTER COMMANDS 040 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-091 Techniques and the slots (greybox v6, NP_14 C45)**
Same rule as 001–039: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-091 Status DONE** (the row payload below replaces the TODO row from 039).
2. **Add PAC-092** (row below), Status TODO: the Toronto academy's industrialized hybrids, Arc 3's thesis mechanic (NP_07 §10).
   - The academy's squads carry mass-produced hybrids: breadth over bond, each slightly weaker per move, no duo VFX, no feud or alliance history.
   - The club answers with fewer hybrids forged through bonds (C41).

   Alternative: NP_02 §2.2's mirror lab flag, the adaptation tracker's copy of the player's habits as a spar opponent (C44 built the trial's card mirror; the habits copy is open).
3. **Add DATA row** `data/techniques.v1.json` (DATA, "NP_11 s2/s8's techniques as the sim reads them: the technique slots at levels 5/15/25/35/45 and the T0 slot at 5 (one T0, the identity move; natives take no slot); the library's sources cast by their own rule and those not learnable; the HBP shop's three shelves by circuit progress (100 / 400 / 800 HBP; as found, story:regionals, story:provincials_semifinal); the masters and their gates (Whitlock, the conditioning coach, DEX, CARTER, CASSIDY); the quests' fight tapes and the found one; the re-teach in a training slot"). Both copies.
4. **Link PAC-091** to these rows:
   - **MODULE `sim/core.gd`:**
     - `TECH` through `setup`'s last argument, in the content stamp; `_tapes_sync` at setup;
     - the kit: `tech_slots`, `t0_open` (read by `castable`), `learned`, `kit_of`, `tech_class`, `known`, `kit_moves` (on `P["kit"]` at `_load_segment`), `kit_why`, `kit_equip`, `kit_unequip`, `kit_best`;
     - the cast: `cast_move`'s tail, `kit_move`, `wall_move`, `kit_pick`;
     - the shop: `shop_tier_of`, `shop_open`, `shop_list`, `buy_why`, `buy`, `buy_best`;
     - the masters: `master_here`, `_gate_why`, `lesson_why`, `lessons_open`, `lesson`, `_tech_eight` (at `eight_up`);
     - the tapes: `tapes`, `tape_why`, `use_tape`; the re-teach: `reteach_why`, `reteach`, `reteach_best`;
     - `_learn`, `technique_lines`, `teach_aid`, the OVER input `teach`, `seed_learned`, `seed_tapes`;
     - `equip`'s refusal names the kit.
   - **MODULE `sim/profile.gd`:** the hissatsu pick reads `kit_pick`.
   - **MODULE `sim/save.gd`:** each Fighter's `technique_slots`, `native_slots`, `signature_t0`, `slots_open`, `learned`.
   - **MODULE `sim/exhibition.gd`:** the techniques table passed to both engagements.
   - **MODULE `main.gd`:**
     - DUAL OVER's TECHNIQUES lines, `[`, `]`, `'`, `/`, `=`, `-`;
     - the LEARNED, THE SHOP, THE KIT, RE-TEACH and FIGHT TAPE toasts, the matchup card's KIT line;
     - `-- learn=`, `-- tapes=`, `-- demo techniques`;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gates moved in command 6) and the new `engine/greybox/tools/drive_techniques.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_techniques.gd` (TEST, "techniques on the real scene, headless: RORY at the bell with no kit; the dual won and DUAL OVER's TECHNIQUES lines; [ buys the shop's pick into his kit; ] takes Whitlock's Timberfall; ' spends the Black Ice tape into his T0 slot; [.] and / re-teach PRIYA in a training slot; - and = put it down and carry it again; F5's next dual with the matchup card's KIT line; H + K casting Black Ice from the kit. 10/10").
6. **Gates moved — flag for @heat.**
   - **The T0 at level 5** (NP_05 §3, NP_12A's Marginalia). The move-effect helper `with_move` seeds its caster at level 5 (First Snap's and Black Ice's effect gates cast a T0). The Duo and relay gates' helper `q20_mk` seeds PRIYA at level 5 ("at 89 she casts her own Marginalia"; "LB + PISTON her own Marginalia").
   - **C31's equip refusal** names the kit ("... a card equips its own house's natives as its move (the rest of the library goes in the kit, NP_11 s8)"); it said the library was not built.
   - **The content-table gate** lists 27 tables, with `TECH`.
   - **Determinism figures moved with the T0 at level 5:** level-1 PRIYA and JUNE no longer cast their T0s in seven delegated logs. Every gate's condition holds; the figures:
     - the sanctioned log's segment ends, 7 to 6;
     - the assembled filler's tells, 110 to 113 (SPECIAL 5 to 6), and its sensors;
     - the sealed Relay Ladder's card-order Adjacent Trust count, 1 to 2;
     - the staffed corner's heat events, 15 to 12, and conversions, 1 to 0;
     - the exhibition's Adjacent Trust casts, PRIYA's Marginalia giving way to RORY's move;
     - the PI 2 ledger's emphasized tells, 27 to 15;
     - the remixed Yuri's hits in a tell, 21 to 16.
   - The save-and-load line reads 218 KB (was 217): each Fighter record carries its techniques. The smoke's printed save sizes and content stamp moved likewise, no gate's condition.
7. **Note NP_14:**
   - C45 added (5 gates, the taught kit on the scripted log, the techniques drive).
   - The not-claimed bullets on blessings (C31) and the fighter's growth (C44) say what C45 now runs.
   - A new not-claimed bullet names what C45 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C45.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"T0 | Signature | Fighter level 5; every fighter gets exactly one"** with NP_12A's "Her personal T0 Marginalia unlocks at level 5": the T0 slot opens at 5 and holds one T0; a card's own T0 is castable from 5 (below it the motion is its punch). This is the reading that moved the gates and figures in command 6.
   - (b) **"Technique slots at 5/15/25/35/45 (5 slots max + house-native bonus slots which ADD)"**: the card's own move stands outside the five; natives take none.
   - (c) **The sources by the library's `source` field:** `shop:*` and generic go to the shop; `taught:*` to Whitlock and the conditioning coach; `personal:*` to the recruit's own list (Priya's identity T0 and Anders' excepted); `quest:*` to a tape with the quest's flag; `taught` (Black Ice) to a found tape.
   - (d) **"HBP shop (generic library, tiers by circuit progress)", "shop tiers 100–800":** three shelves — as found, the Regionals, the Provincials — at 100 / 400 / 800.
   - (e) **"Masters (recruit/befriend → they teach their list, some gated by BOND or STAT_PROOF)":** a card in the stable, the coach always, a staff role while dressed; free, the gate the price.
   - (f) **Whitlock's "after the player's first survived standing-eight"**: the learner's own first.
   - (g) **"Re-taught to a stablemate via a training-slot session (the original keeps it)"**: one of C43's three daily slots, no Beans; the teacher's learned moves only.
   - (h) **The hybrid** (C41) is known and cast by its own rule, never slotted.
9. **Editorial, to confirm or overrule:**
   - The flag names `story:regionals`, `quest:coach_questline`, `story:arc3`; the quests' tapes on `quest:harbour` and `quest:rink_district`.
   - The masters' gates: DEX at Kizuna Lv2, CARTER at SPD 60, CASSIDY in Arc 3. The prices 100 / 400 / 800.
   - A move learned going straight into the kit when there is room; the profile's pick (his own, then the kit's first); the kit's order as the cast priority within a family.
   - The aid's picks (the dearest open shelf that fits, the first lesson open, the first tape, the first re-teach), the keys `[` `]` `'` `/` `=` `-`, the toasts' wording, `-- learn=`, `-- tapes=`, `-- demo techniques`.
   - To reverse the rules and numbers, edit the table.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-091 row (CSV-ready, todo columns)
ID: PAC-091 | Title: Teachable techniques and the technique slots (NP_11 s2, s8) | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The technique slots from levels (5/15/25/35/45; the house natives' bonus slots add, NP_07 s7) and the T0 signature at 5. The sources as data and on the ledger: masters (a recruit or befriended fighter teaches his list, some gated by BOND or STAT_PROOF), the HBP shop (the generic library in tiers by circuit progress, 100-800 HBP), fight tapes (single-use teaching items), the house natives (C31) and the hybrids (C41). Transfer: a learned non-native re-taught to a stablemate through a training slot (C43), the original keeping it. The card's equipped kit read by the sim at the bell (which hissatsu he carries into the dual). Gates cover the slots by level, each source refused and paid, the re-teach, the kit in the fight and the save's technique_slots; determinism with a taught kit in the log.
BlockedBy: PAC-090 | DependencyType: soft | RelatedWork: NP_11 s2 s6 s8 s9; NP_05 s3; NP_05A s3; NP_07 s4 s5 s7; NP_12A; NP_14 C31 C41 C43 C44 C45; data/techniques.v1.json; data/hissatsu_library.v2.json
Notes: 2026-09-24: SMOKE 391/391 GREEN x 24 bosses (9,384 assertions; +5). DETERMINISM 45/45 (a taught kit on the scripted log vs Yuri's squad: the kit's casts on the log's motions, ten moves taught between duals by the aid; identical twice, different from the same log with no kits; seven older lines' figures moved with the T0 at level 5, command 6; the save's size 217 -> 218 KB). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo techniques boss=1 (60,000 frames, x2) - the aid's lessons, tapes, a buy and three re-teaches before the bell, Whitlock's Eight Count Answer earned in play by a survived standing-eight, 14 and 9 casts from the kits; -- demo techniques facilities boss=7 (60,000 frames, x2) - the renovations take the HBP, Roadwork from the conditioning coach, Eight Count Answer earned and re-taught in the training slots, 8 and 16 kit casts; regressions x1 - demo growth (22 steps), demo hybrid (Grain & Snow relayed twice), the exhibition at home (two duo syncs). Six gates moved and seven determinism figures (command 6).
LearningNotes: The library already said where every move comes from: its `source` field names the shop's tiers, the masters, the quests, the boss-only rows and the rules that cast the rest. The table maps those tags and adds no move list of its own, so a move re-sourced in the builder moves shop, master or tape with it. The T0 at level 5 is canon twice over, and it was the costly part. PRIYA and JUNE had cast their T0s from level 1 in every log since the Ep1 cards, so two helpers now seed level 5 and seven determinism lines read new figures. The kit and the sources moved nothing on their own; every figure change traces to that one rule.
StartedAt: 2026-09-24T18:31:59Z | DoneAt: 2026-09-24T19:41:28Z

## PAC-092 row (CSV-ready, todo columns)
ID: PAC-092 | Title: The Toronto academy — industrialized hybrids (NP_07 s10, Arc 3's thesis) | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The academy as data: its squads (generic cards on the assembler, C24) carrying hybrids composed without bonds, breadth over depth - more hybrids a fighter, each slightly weaker per move than a forged one, no duo VFX, no afterimage, no feud or alliance history, cast by the enemy side on its own rule. The club's answer on the sim: its forged hybrids (C41) against the academy's, the difference readable on the matchup card and in the numbers. The academy's dual as a format or a squad the sim can field. Gates cover the composer's industrial rule (weaker per move, breadth), the enemy side's casts, the matchup against a forged hybrid; determinism with an academy squad in the log.
BlockedBy: PAC-091 | DependencyType: soft | RelatedWork: NP_07 s10; NP_08 s6; NP_12 s6; NP_04B; NP_14 C24 C41; data/hybrids.v1.json
Notes: Alternative for PAC-092: NP_02 s2.2's mirror lab flag - the adaptation tracker's copy of the player's habits as a spar opponent.
