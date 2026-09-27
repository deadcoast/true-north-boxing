# REGISTER COMMANDS 042 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-093 The mirror spar (greybox v6, NP_14 C47)**
Same rule as 001–041: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-093 Status DONE** (the row payload below replaces the TODO row from 041).
2. **Add PAC-094** (row below), Status TODO: NP_11 §5's accessories and gear. Gear is cosmetic-forward (gloves, wraps, robes, mouthguards), with small passive slots (effects of 3 % or less; gear never outweighs boards). Its sources are shops (HBP), circuit prizes, house gifts and festival events. Signature gear is untradeable identity (Yuri's grain-sack wraps).
   - C44 gave each rarity tier its accessory slots; they hold nothing yet.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you"), its squad drawn from the club's own ledgers.
3. **Update DATA row** `data/bouts.v1.json` (both copies):
   - `spar.mirror` holds the mirror's rules: the tracker's count (3), the tier's string cap, three reads seeded (capped at 3), the counter's minimum (2) and weight (×1.3), the row verbs, the feint's 200 ms pause, the label.
   - `lab_flags.mirror` no longer says "not in the greybox".
4. **Link PAC-093** to these rows:
   - **MODULE `sim/core.gd`:**
     - the record: `_habit_track` (from `_track`, on `htokens`), `_habit_read` (at the tracker's flag), `_habit_chance` (at the player's evade and perfect block), `_habit_counter`, `habits_of`, `_habits_w`, `_habit_blank`, `seed_habits`;
     - the copy: `habit_copy`, `_seq_words`, `mirror_card` (habits, reads, counter, `mirror_of`, `learned_from`), `spec_from_card` (habits);
     - the bout: `start_spar`'s `mirror` flag, `_mirror_bell` at `_load_segment`, `_mirror_counter` at the player's whiff, `_end_bout` (no PI for a mirror);
     - `mirror_line`, `habits_line`, `mirror_aid` and the OVER input `mirror`, `mirror_n`;
     - `PUNCH_VERBS` gains `L_HAY` and `L_OVERHAND`.
   - **MODULE `sim/assembler.gd`:** a spec's habits take the first string slots and share the preset's weights; a spec without them draws as before.
   - **MODULE `main.gd`:**
     - `-- habits=` and `-- demo mirror`;
     - DUAL OVER's HABITS line, the matchup card's MIRROR line, THE MIRROR and YOUR COUNTER toasts;
     - `[M]` after a mirror goes back to the dual;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate) and the new `engine/greybox/tools/drive_mirror.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_mirror.gd` (TEST, "the mirror spar on the real scene, headless: the dual won and DUAL OVER's HABITS line; [M] against RORY'S MIRROR with the MIRROR line; its strings his sequences and its reads at 3; J, J, K - the K read at 3 and slipped; his R_HOOK thrown back with the YOUR COUNTER toast; the spar won on EP - the Legend's trial, no PI, the record grown; [M] back to the dual. 8/8").
6. **Gates moved — flag for @heat.** No gate moved. One determinism figure moved: the save-and-load line reads 239 KB (was 218), because the record is in the SaveGame's ledger and the DualState's. The smoke's printed save sizes moved likewise, no gate's condition.
7. **Note NP_14:**
   - C47 added (5 gates, the mirror on the delegated log, the mirror drive).
   - C43's and C44's not-claimed lines on the mirror lab flag now point at C47.
   - C44's claim notes that since C47 the mirror's strings are the record's.
   - A new not-claimed bullet names what C47 does not build, and its readings.
   - Three reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C47.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"Mirror spar (fight a copy of your own fighter — the adaptation tracker turned into content)"**: C44's mirror card on the tracker's record, kept per fighter across every bout. What he throws is the copy's offense; what the tracker reads is its defense. The boss agent runs patterns, so the copy is one.
   - (b) **The copy's offense**: his sequences thrown three times or more (the tracker's own count), ranked by thrown × length, as many as the copy's tier holds, their shares as its SELECT. The Style's pieces fill the rest.
   - (c) **The copy's defense**: C7's read, seeded at the bell with his most-read sequences, fading like any read. Offense stays byte-identical (D3).
   - (d) **His answer**: when its read makes him miss, his most-thrown counter punch at his own rate. It is fixed for the bout, so the copy does not adapt in the fight.
   - (e) **No Pattern Intel** from a mirror; any mirror beaten meets the Legend's trial (NP_11 §4's "beat a mirror match").
9. **Editorial, to confirm or overrule:**
   - The floor of 3, the ranking, three reads seeded at up to 3, the counter's minimum 2 and ×1.3, the 200 ms pause for a feint.
   - The record counting the delegated profile's punches (the card's habits, whoever plays him).
   - `L_HAY` and `L_OVERHAND` as the lead hand's verbs.
   - The HABITS and MIRROR lines' and the toasts' wording, `-- habits=`, `-- demo mirror`, `[M]` back to the dual.
   - To reverse the rules and numbers, edit `spar.mirror`.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-093 row (CSV-ready, todo columns)
ID: PAC-093 | Title: The mirror spar — the adaptation tracker's copy of your habits (NP_02 s2.2 lab flag) | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_02 s2.2's mirror spar lab flag on the sim: a spar opponent assembled (C24's assembler) from the adaptation tracker's record of how the player fights (C7) - his most-thrown rows as strings, his habits as the pattern's SELECT weights, his defensive answers as its punishes - on the fighter's own card. The flag as a spar modifier beside infinite stamina and tell-highlight (C18), its XP and rewards by the scrap table. The copy readable before the bell (what it learned from you). Gates cover the copy built from a seeded tracker, a different habit giving a different copy, the spar's objective judge, the save; determinism with a mirror spar in the log.
BlockedBy: PAC-092 | DependencyType: soft | RelatedWork: NP_02 s2.2 s3; NP_04 s9; NP_11 s4; NP_14 C7 C17 C24 C43 C44 C47; data/bouts.v1.json; data/pattern_pieces.v1.json
Notes: 2026-09-24: SMOKE 401/401 GREEN x 24 bosses (9,624 assertions; +5). DETERMINISM 47/47 (the mirror on the delegated log: the dual records RORY, PRIYA and JUNE, the aid spars RORY's mirror on that record - his counter thrown back twice - and goes back; identical twice, different from the same log without the aid; the save-and-load line 218 -> 239 KB, command 6). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo mirror boss=1 facility=ring:1 (60,000 frames, x2) - the duals record the cards, the aid spars their mirrors between duals, 7 and 6 counters thrown back; -- demo spar flags=mirror on a seeded record; regressions x1 - demo academy, demo hybrid, demo growth (29 steps), the exhibition at home (two duo syncs). No gate moved.
LearningNotes: The tracker already watched everything the copy needed and threw it away at every bell. The record keeps its tokens, and the copy is C44's mirror card with the record in its spec, so the assembler, the save and the restore needed no new path. Two DoD lines read differently in the build. "His defensive answers as its punishes" became his counter punch thrown back when its read makes him miss: the tracker records no defensive choice, and the counter is what his defense leads to. "Its rewards by the scrap table" became the spar's pay without the PI tick, since the pattern is his own. The feint needed care: the tracker pops a feinted punch's start, so the record takes it back too, or every feint would count as a thrown punch. The drive must take each key's punch the frame the scene hands it over; a frame late, the copy's 0.3 read can slip a jab before the drive cancels it.
StartedAt: 2026-09-24T23:14:38Z | DoneAt: 2026-09-25T00:31:11Z

## PAC-094 row (CSV-ready, todo columns)
ID: PAC-094 | Title: Accessories and gear (NP_11 s5) | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_11 s5 on the sim's ledgers: gear as data - gloves, wraps, robes and mouthguards, cosmetic-forward with small passives (3 % or less; never more than a board's), equipped in the accessory slots each rarity tier opens (C44). The sources on the ledger: the HBP shops, circuit prizes, house gifts, festival events; a named character's signature gear untradeable (Yuri's grain-sack wraps). The Fighter record's gear written and read by the save. Gates cover the slots by rarity, each source paid or refused, the passive cap against the boards, the signature lock, the save; determinism with gear equipped in the log.
BlockedBy: PAC-093 | DependencyType: soft | RelatedWork: NP_11 s3 s4 s5 s6 s9 s10; NP_07 s4; NP_14 C22 C43 C44; data/growth.v1.json; data/economy.v1.json
Notes: Alternative for PAC-094: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
