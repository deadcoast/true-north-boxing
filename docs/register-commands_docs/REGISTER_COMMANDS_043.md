# REGISTER COMMANDS 043 — for the applying writer
**From: @claude · 2026-09-25 · Re: PAC-094 Accessories and gear (greybox v6, NP_14 C48)**
Same rule as 001–042: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-094 Status DONE** (the row payload below replaces the TODO row from 042).
2. **Add PAC-095** (row below), Status TODO: NP_11 §10's obsolescence audit as an executable gate. Per milestone, take the three earliest-recruitable fighters and build each for the current endgame with live systems only: tier 4, a competitive board, a coherent technique kit, gear.
   - If any cannot reach viability, the failing system — not the fighter — gets fixed.
   - The progression lane is now whole (C43 facilities, C44 growth, C45 techniques, C47 the mirror, C48 gear), so the audit can run on it.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Add DATA row** `data/gear.v1.json` (DATA, "NP_11 s5's accessories and gear as the sim reads them: the cap (3%), the four kinds and their keys on the board passives' hooks (gloves the jab, wraps the guard held, a mouthguard the wobble, a robe the personal Tension), the HBP shop's three shelves, the festival's prizes in order, a blessed house's gift by rule and the houses' styles, eighteen pieces - name, kind, percent, source (shelf and price, flag, owner), colour and look"). Both copies.
4. **Link PAC-094** to these rows:
   - **MODULE `sim/core.gd`:**
     - `GEAR` through `setup`'s last argument, in the content stamp, out of the snapshot;
     - the locker: `gear_item`, `gear_text`, `_gear_derived`, `gear_owned`, `gear_from`, `gear_free`, `_gear_sync` and `gear_seen` (at setup and in `new_dual`), `gear_festival`, `_gq`, `_gq_r`;
     - the card: `gear_worn`, `gear_fx`, `_gear_mult` (at the jab's damage, the guard's decay, the wobble's recovery, the Tension earned), `gear_why`, `_gear_slots_why`, `gear_best`, `wear`, `take_off`;
     - the shop: `gear_shelf_open`, `gear_buy_why`, `gear_buy_best`, `buy_gear`;
     - `gear_lines`, `gear_line`, `gear_aid` and the OVER input `gear`, `seed_gear`; `P["gear"]` and `P["gear_fx"]` at `_load_segment`.
   - **MODULE `sim/exhibition.gd`:** the gear table passed to both engagements; the festival's prize at `_end`.
   - **MODULE `sim/save.gd`:** each Fighter's `gear`; the header.
   - **MODULE `main.gd`:**
     - DUAL OVER's GEAR lines and the keys `\`, `,` and Shift+`,`;
     - the GEAR toasts, the matchup card's GEAR line, `_dress_gear` (the figure in the pieces' colours, the robe at the walk-out);
     - `-- gear=`, `-- demo gear`, the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gate moved in command 6) and the new `engine/greybox/tools/drive_gear.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_gear.gd` (TEST, "gear on the real scene, headless: the dual won and DUAL OVER's GEAR lines; , puts the Regionals Robe on and the figure wears it; , again refused on the slot; Shift+, takes it off; \\ buys the shop's pick; , wears it in its colour; F5's next dual with the matchup card's GEAR line and its passive on him. 7/7").
6. **Gates moved — flag for @heat.** The content-table gate lists 29 tables, with `GEAR`. No determinism figure moved: an unused locker writes nothing, and the story's pieces are derived, not stored.
7. **Note NP_14:**
   - C48 added (5 gates, gear on the delegated log, the gear drive).
   - C44's not-claimed line on gear now points at C48.
   - C23's not-claimed line names the board (C44) and the gear (C48) on the Fighter record.
   - A new not-claimed bullet names what C48 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C48.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"≤3% effects; gear never outweighs boards"**: one passive a piece, its kind's, on the board passive's own hook (Snap, Tight Guard, Iron Jaw, Sparkplug), capped at 3 %. One piece of each kind, so no key carries more than the cap against the board's 15–30 %.
   - (b) **"+1 equip slot for accessories"** (NP_11 §4) with **"gear: [item_id, ...3]"** (NP_11 §9): C44's slots by rarity hold the pieces, one of each kind.
   - (c) **"Signature gear for named characters is untradeable identity"**: in the locker while its owner is in the club, worn only by him, never sold. It waits to be put on rather than being worn from the start (`signature_worn_from_start: false` reverses this). Yuri's Grain-Sack Wraps from NP_11 §5; Efua's mother's wraps from NP_07A Q-OSEI's reward, on `quest:osei_blessing`.
   - (d) **"House gifts"**: a blessed house's colours, once, the piece by its style bias (NP_07 §8), named by rule and never after a cultural object (NP_07 §9).
   - (e) **"Circuit prizes"** as the story's flags; **"festival events"** as an Exhibition 2v2 won on the boardwalk.
   - (f) **"Shops (HBP)"** on the technique shop's three shelves by circuit progress.
9. **Editorial, to confirm or overrule:**
   - The four kinds' keys, the eighteen pieces' names, looks, colours, percentages and prices.
   - The three prizes' flags, the festival's three prizes and their order, the gift's 2 %.
   - The story's pieces derived rather than stored; copies of a bought piece; the aid's picks (the locker first, his own signature first, then the shop's strongest the purse affords, the cheaper on a tie).
   - The keys `\`, `,` and Shift+`,`; the figure's shapes; `-- gear=`, `-- demo gear`.
   - To reverse the rules and numbers, edit the table.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-094 row (CSV-ready, todo columns)
ID: PAC-094 | Title: Accessories and gear (NP_11 s5) | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_11 s5 on the sim's ledgers: gear as data - gloves, wraps, robes and mouthguards, cosmetic-forward with small passives (3 % or less; never more than a board's), equipped in the accessory slots each rarity tier opens (C44). The sources on the ledger: the HBP shops, circuit prizes, house gifts, festival events; a named character's signature gear untradeable (Yuri's grain-sack wraps). The Fighter record's gear written and read by the save. Gates cover the slots by rarity, each source paid or refused, the passive cap against the boards, the signature lock, the save; determinism with gear equipped in the log.
BlockedBy: PAC-093 | DependencyType: soft | RelatedWork: NP_11 s3 s4 s5 s6 s9 s10; NP_07 s4 s8 s9; NP_07A Q-OSEI; NP_01 s8; NP_14 C22 C31 C42 C43 C44 C45 C48; data/gear.v1.json; data/growth.v1.json
Notes: 2026-09-25: SMOKE 406/406 GREEN x 24 bosses (9,744 assertions; +5). DETERMINISM 48/48 (gear on the delegated log vs Yuri's squad with 900 HBP and the Regionals: RORY in the Regionals Robe, a Fitted Guard each for PRIYA, MARCUS and JUNE; identical twice, different from the same log undressed; no older figure moved, the save's size included). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo gear boss=1 (60,000 frames, x2) - the robe from the locker, three Fitted Guards bought and worn; -- demo gear boss=7 format=sanctioned with the Provincials and Tremblay's blessing (60,000 frames) - four story pieces, all eight dressed, YURI in his own wraps, JUNE in Tremblay's colours; regressions x1 - the exhibition on the boardwalk, demo mirror (7 counters), demo growth (29 steps), demo hybrid. One gate moved (command 6).
LearningNotes: The first build stored the story's pieces in the locker when a flag or a blessing landed. Two save gates caught it: a load re-ran the grants at setup, so the written-back save differed from the one it came from. The fix reads the story's pieces off the ledgers each time (flags, blessings, the club's cards) and stores only what the club buys or wins, so a load, its source and every new dual agree. The toasts keep their own list of pieces announced. Hooking each kind onto the board passive's own line keeps the claim testable: the same measurements C44 took for Snap, Tight Guard, Iron Jaw and Sparkplug show a piece moving its own number by at most 3 % and nothing else. Multiplying by 1.0 when a card wears nothing is exact, so no older figure moved.
StartedAt: 2026-09-25T00:47:34Z | DoneAt: 2026-09-25T01:58:33Z

## PAC-095 row (CSV-ready, todo columns)
ID: PAC-095 | Title: The obsolescence audit (NP_11 s10) as an executable gate | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_11 s10 on the sim: the three earliest-recruitable fighters (the recruit ledger's first joins) built for the current endgame with live systems only - rarity to tier 4 on Spirits and the trials, a competitive board, a coherent technique kit, gear in the slots - and fought against the endgame's bosses by the profile. Viability measured (a win rate or EP margin against a named threshold), and a failing system named, not the fighter. The audit's report as a headless tool the milestone runs. Gates cover the build reaching tier 4 on live systems only, each system's contribution against its absence, the report's verdict; determinism with an audited card in the log.
BlockedBy: PAC-094 | DependencyType: soft | RelatedWork: NP_11 s3 s4 s5 s8 s10; NP_08 s2; NP_14 C29 C43 C44 C45 C48; data/growth.v1.json; data/techniques.v1.json; data/gear.v1.json
Notes: Alternative for PAC-095: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
