# REGISTER COMMANDS 036 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-087 Cross-house hybrid research (greybox v6, NP_14 C41)**
Same rule as 001–035: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-087 Status DONE** (row payload below replaces the TODO row from 035).
2. **Add PAC-088** (row below) — Status TODO. The Exhibition 2v2 (NP_01 §8, NP_05 §7). It is the one format with two fighters a side in the ring at once, and the home of Kizuna Lv4's second effect ("2v2 exhibition duo hissatsu"). The library's two festival moves (Double Overtime, Two-Hand Winter) carry `sync_500ms` and have never run. The DoD:
   - the format as data: one segment, two a side;
   - the sim's second fighter on each side, with targeting and the tag-in rules the doc implies;
   - the duo hissatsu cast when both of a Duo pair input its motion within 500 ms;
   - the shared duo wall;
   - the enemy pair's side.

   Alternatives: the club facilities (NP_10 §7: The Wall hosting the Forge, the Film Room, the training slots that pay Beans); the Toronto academy's industrialized hybrids as Arc 3's thesis mechanic (NP_07 §10: "slightly weaker per-move but overwhelming in breadth").
3. **Add DATA row** `data/hybrids.v1.json` (DATA, "NP_08 s6's hybrid research as the sim reads it: the Forge's price (40 Spirits, 30 Beans, between duals), the ceiling (8 a save), E07's discount (quest:third_bridge: Duo, -50%), the composer's rules (the stronger native's family and damage +0.1 over the T3 floor 2.4, a tag from each house capped at 2 s, 2100 + 100 ms a tag, the motif name rules), the cast (x1.25 and the partner's afterimage relayed; CHARGED; the Awakening's slot), a motif word per house", Linked PAC-087). The engine copy `engine/greybox/hybrids.v1.json` rides with it.
4. **Note DATA row** `data/economy.v1.json`. Summary gains: "Lv5 Sworn carries `hybrid`: cross-house pairs' hybrid research opens (NP_08 s6)." This is a one-line edit; both copies.
5. **Link PAC-087** to these rows:
   - **MODULE `sim/core.gd`:**
     - The table: `HYB` (in the content stamp, out of the snapshot) through `setup`.
     - The requirement: `hybrid_level`, `learned_natives`, `forge_terms`, `forge_why`.
     - The Forge: `forge` (and `"*"`), `_forge_record`, `_authored_hybrid`, `compose_hybrid`, `_whole`.
     - The registry: `rewards["hybrids"]` ordered by its `n`; `_hyb_keys`, `hybrids_of`, `hybrid_registry`.
     - The cast: `hybrid_move`, `_hyb_rec`; `castable`, `cast_move` and `t3_pick` taking it first; `_start_cast`'s event and feed; `_hyb_cast_note`.
     - The lines: `_hybrid_check`, `hybrid_line`, `forge_candidates`, `forge_lines`.
     - The choice and the purse: `choose_hybrid`, `_hyb_slot_text` in the Awakening's feed; `seed_purse`.
   - **MODULE `sim/save.gd`:** the `hybrid_slot` card key, `currencies.beans` from the ledger, `hybrid_registry` from the Forge.
   - **MODULE `main.gd`:**
     - F on the DUAL OVER screen and the FORGE lines;
     - the matchup card's HYBRID line;
     - the FORGED, HYBRID and HYBRID SLOT toasts;
     - the afterimage in both elements;
     - `-- purse=`, `-- forge=`, `-- demo hybrid`;
     - `;` as the keyboard's hookercut;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate, one older gate moved — command 8) and the new `engine/greybox/tools/drive_forge.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_forge.gd` (TEST, "hybrid research on the real scene, headless: the sanctioned five sealed YURI, MARTA...; no FORGE lines in the fight; the dual won, the FORGE lines on DUAL OVER; F forges Grain & Snow (the toast, the registry, the purse); F5, R1 YURI without a line, R2 MARTA's HYBRID line priced; H + ; casting it relayed (the toast, the afterimage in both elements); resolved, the debut", Linked PAC-087).
7. **Note MODULE row `sim/save.gd`:** the save now writes the ledger's Beans, the Forge's `hybrid_registry` and a card's `hybrid_slot` when set. Older saves read unchanged.
8. **One older gate moved — flag for @heat:** the content-table gate (C36's statement, PAC-074's gate) now lists 24 tables with `HYB` among them, and it still proves its claim. No figure in any log moved: the Zone's run still ends at 6,069 (Comedown 7,702), the Manifest's at 7,664, Inheritance's at 7,038, Awakening's at 8,604 and 9,824, Vasile's Zone at 1,731 to 3,731. Every content stamp moved with the new table.
9. **Note NP_14:**
   - C41 added (5 gates, the hybrid on the delegated log, the Forge drive).
   - C23's claim and not-claimed bullet, C22's, C34's, C38's and C39's not-claimed bullets, C39's claim, C36's test and the hissatsu note say what C41 now runs.
   - A new not-claimed bullet names what C41 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C41.
10. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **"Each with ≥1 native technique learned"** counts:
      - his house's natives when NATIVE;
      - its SECRET with his `secret:<NAME>` flag;
      - the house native his card carries (an UNSANCTIONED recruit knows what he carries).
      "From different houses" means two primary houses; a sealed house forges nothing until it opens.
    - (b) **"A Forge event (Beans + Spirits cost + a scene)"** is a between-duals call (or one before the first bell) paying 40 Spirits and 30 Beans from the ledger. These are first-draft prices against NP_11 §6's 3–8 Spirits a dual and 3–10 Beans a training slot.
    - (c) **"Unique to that pair":**
      - one hybrid per pair;
      - the library's authored hybrid of the pair's two houses is that pairing's hybrid while no pair has claimed it (Grain & Snow for Kowalchuk × Tremblay, Two Rivers for Nguyen-Roy × Delacroix-Cardinal);
      - a later pair of the same houses composes its own, under its names.
    - (d) **"Name generated from both house motifs"** is a motif word per house, joined in the houses' order (Grain & Snow reads as Kowalchuk's Grain and Tremblay's Snow). The 13 words are a first draft for the content lane.
    - (e) **"Effect composed from both native families' effect tags"** is the composer's rules, derived to rebuild the library's Grain & Snow exactly:
      - the stronger learned native's family and damage +0.1 over the T3 floor 2.4;
      - from each house, the first non-damage, non-wall effect the fighter knows, its seconds capped at 2;
      - 2100 ms + 100 a tag.
      Two Rivers is authored and not composable, since its afterimage comes from neither house's natives.
    - (f) **"Both fighters can cast it, strongest when relayed between them"** has three parts:
      - either of the pair, under NP_05 §3's T3 rule ("CHARGED state or bonded adjacency");
      - relayed: the partner fought the segment before, either order, which gives ×1.25 and the partner's afterimage (×1.25 is a first draft);
      - it answers its motion before the pair's Duo T3, which it shadows on a shared family.
    - (g) **Q-NGUYEN-ROY's "arms the Two Rivers Forge pairing early" and "Forge discount for E07-pair hybrids"** mean a pair across E07, with `quest:third_bridge` set, forges at Duo (a level early) for half.
    - (h) **The Awakening's "+1 hybrid technique slot active"** is one of his hybrids live for the Awakening: the card's choice between duals, his first forged by default.
    - (i) **A DUAL element** takes no same-element spike and no home bonus, as the library's two authored hybrids have read since C10.
    - (j) **"Carrying … feud/alliance history" (NP_07 §10)** is the edge between the two houses on the day of the Forge (E07 MARRIAGE), kept in the registry. The debut is dated for Q-DELACROIX-CARDINAL's hook ("after your first dual using Two Rivers").
11. **Editorial, to confirm or overrule:**
    - The table's keys and the ids `HYB-NN`.
    - The flag name `quest:third_bridge`.
    - The 13 motif words (Bridge, River, Grain, Snow, Tide, Anvil, Heat, Root, Ledger, Bell, Silence, Light, Iron).
    - The name rule "{name} - {x} & {y}" for a name already forged.
    - The feed's and toasts' wording.
    - F on DUAL OVER, `;` as the keyboard's hookercut, `-- purse=`, `-- forge=`, `-- demo hybrid` (its log's corners keep the sealed order and never hold the bar).
    - The greybox's afterimage in both elements at 2.2.
    - The Delacroix-Cardinal stand-in card in the E07 gate.
    - To reverse the rules and numbers, edit the table.
12. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-087 row (CSV-ready, todo columns)
ID: PAC-087 | Title: Cross-house hybrid research (NP_08 s6) — a Sworn pair of two houses forges a T3 of its own | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: Hybrid research as data. A Sworn (Lv5) pair from different houses, each with at least one native technique learned, researches at a Forge event (its cost on the reward ledger: the Beans and Spirits NP_08 s6 names). The output is a hybrid T3 unique to the pair: its name from both house motifs, its effect composed from both native families' effect tags, castable by either fighter and strongest relayed between them. The launch ceiling is 8 hybrids per save. An Awakened fighter's hybrid slot (NP_09 s6) holds one of his. Gates cover the requirement (each part refused alone), the composition against both parents, the relay's edge, the ceiling, the slot and the save. Determinism runs with a hybrid cast in the log.
BlockedBy: PAC-086 | DependencyType: soft | RelatedWork: NP_08 s5.2 s6; NP_07 s5 s10; NP_07A Q-NGUYEN-ROY Q-DELACROIX-CARDINAL; NP_05 s3 s7 s10; NP_09 s6; NP_11 s6 s9; NP_14 C10 C22 C23 C34 C39 C41; data/hybrids.v1.json; data/economy.v1.json; data/hissatsu_library.v2.json
Notes: 2026-09-24: SMOKE 371/371 GREEN x 24 bosses (8,904 assertions; +5). DETERMINISM 41/41 (YURI and MARTA forged on the delegated log vs Yuri's squad, out R1 and R2, the bar topped up at 3,100: the profile casts Grain & Snow relayed with YURI's afterimage, its debut once; identical twice, different from the unforged log, where the pair's Duo T3 answers the motion). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10, the 24 sources recompiled byte-identical. sim_test 14/14. The hissatsu audit GREEN. Drives: the Forge drive 7/7, the enemy-transformation drive 7/7, the Clash drive 5/5, the Awakening, Inheritance, Manifest and Zone drives 6/6, the formation drive 12/12, the Duo drive 6/6, the recruit drive 8/8. Two runs each of 16,000-frame `-- demo hybrid` soaks in the sanctioned format, YURI and MARTA forged before the bell: vs Yuri's squad, vs Carter's squad, and with a save / load (the same hash back at tick 3,000 in both). Grain & Snow was cast relayed two to four times a run. Zero script errors. One older gate moved (command 8)
LearningNotes: The library's two authored hybrids fixed the composer. Grain & Snow's every field falls out of its parents' natives: Full Load's family and damage +0.1, Grain Elevator's shred, Premiere Neige's auto-slip capped at 2 s, and the T3s' own 2100 + 100 ms a tag. The gate holds the composer to that record. Two Rivers carries an afterimage neither house's natives have, so it stays authored. The save's round trip caught the registry's order: a sorted-key save reordered the ledger's pairs, which would have moved a card's "first forged". The registry now keeps its own forge number. The first demo soak cast nothing, for two reasons the log owned: its corners swapped JUNE into MARTA's slot, and it called SAVE THE BAR, which holds the team bar. The aid now keeps the sealed order and never holds the bar; the sim's own rules were right both times. Found building it: the keyboard had no HAYMAKER motion (no hookercut key), so `;` is now one
StartedAt: 2026-09-24T09:28:32Z | DoneAt: 2026-09-24T10:19:27Z

## PAC-088 row (CSV-ready, todo columns)
ID: PAC-088 | Title: The Exhibition 2v2 (NP_01 s8, NP_05 s7) — two a side in the ring, the duo hissatsu on a 500 ms sync | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The Exhibition 2v2 as a format (one segment, two fighters a side in the ring simultaneously). The sim's second fighter on each side: position, targeting, the partner's state. The duo hissatsu: a Duo pair's festival move (the library's sync_500ms moves: Double Overtime, Two-Hand Winter) cast when both input its motion within 500 ms, the duo wall's shared gauge. The enemy pair's side. Gates cover the format, the sync window each way, the shared wall and a delegated partner. Determinism runs with an exhibition in the log.
BlockedBy: PAC-087 | DependencyType: soft | RelatedWork: NP_01 s8; NP_05 s7 s8; NP_08 s5.2; NP_14 C15 C34; data/formats.v1.json; data/hissatsu_library.v2.json
Notes: The festival's content (where exhibitions happen, the rep and recruitment flags they pay) is the story's. The camera and the presentation of two fighters a side are greybox-first
