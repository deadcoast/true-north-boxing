# REGISTER COMMANDS 041 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-092 The Toronto academy's syntheses (greybox v6, NP_14 C46)**
Same rule as 001–040: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-092 Status DONE** (the row payload below replaces the TODO row from 040).
2. **Add PAC-093** (row below), Status TODO: NP_02 §2.2's mirror spar lab flag — the adaptation tracker's copy of the player's own habits as a spar opponent ("the adaptation tracker turned into content").
   - C44 built the trial's mirror of a card's stats; the copy of how the player fights is open.

   Alternative: the academy's recruiting of the club's beaten rivals between arcs (NP_12's "the anti-you"), the squad drawn from the club's own ledgers.
3. **Add DATA row** `data/academy.v1.json` (DATA, "NP_07 s10's Arc 3 thesis as the sim reads it: the Toronto Ascendant Academy, Director Vey's corner (ascendant_a); the synthesis rule - the Forge's composer on two houses' natives from the library, damage x0.85, three a prodigy, 'Synthesis {a}-{b}', source synthesis:academy, vfx_synth, reach +0.3, interruptible in 700 ms; the five prodigies (placeholder handles, a style, one house's dialect, three house pairs each)"). Both copies.
4. **Link PAC-092** to these rows:
   - **MODULE `sim/core.gd`:**
     - `ACAD` through `setup`'s last argument, in the content stamp, out of the snapshot; `academy_on`;
     - `_compose_parts`, the Forge's composer split out of `compose_hybrid` (the forged hybrid unchanged);
     - `synthesize`, `_synth_power`, `prodigy_spec`, `field_academy`, `_synth_try` (at `_boss_step`'s IDLE and RECOVER), `academy_line`, `thesis_line`;
     - `_pick_coach` (Vey's corner while fielded), `_build_enemy_lineup` (only the prodigies dressed, no named bench), `_load_segment` (a prodigy's syntheses).
   - **MODULE `sim/save.gd`:** the settings' `academy`; a load fields the squad.
   - **MODULE `sim/exhibition.gd`:** the academy table passed to both engagements.
   - **MODULE `main.gd`:** `-- academy`; the matchup card's ACADEMY and THESIS lines; the SYNTHESIS toast; the soak's summary; the help lines.
   - **DATA row** `data/hybrids.v1.json`: its notes point at the academy's table (both copies).
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gate moved in command 6) and the new `engine/greybox/tools/drive_academy.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_academy.gd` (TEST, "the academy on the real scene, headless: R1 YURI against ASCENDANT 1 in Vey's corner with Grain & Snow forged; the matchup card's ACADEMY and THESIS lines; his bar at 60 within reach arms Synthesis Tide-Heat with the SYNTHESIS toast, 50 off his bar; J in the windup breaks it; won on segments to R2, the THESIS line relayed now; H + ; casts MARTA's Grain & Snow relayed and it lands. 7/7").
6. **Gates moved — flag for @heat.** The content-table gate lists 28 tables, with `ACAD`. No determinism figure moved: the log is line for line PAC-091's but for the new line and the count.
7. **Note NP_14:**
   - C46 added (5 gates, the academy on the delegated log, the academy drive).
   - C41's not-claimed line on the academy now points at C46.
   - A new not-claimed bullet names what C46 does not build, and its readings.
   - Three reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C46.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"Industrialized synthesis without bonds"**: the Forge's own composer (C41) run on two houses' natives from the library, with no pair, no bond and no native learned. A synthesis and a forged hybrid of the same houses share family and tags and differ by the price-down.
   - (b) **"Mechanically slightly weaker per-move but overwhelming in breadth"**: damage ×0.85 (Synthesis Grain-Snow ×2.13 against Grain & Snow's ×2.5, every synthesis under the 2.4 floor); three a prodigy, fifteen distinct over the twelve houses with natives, against the Forge's ceiling of eight.
   - (c) **"Hybrid techniques mass-produced"** cast by the enemy's own rule: the prodigy's bar pays 50 at his decision point, within reach, the next in his rotation. No CHARGED, no relay, no afterimage, no duo VFX, no feud or alliance history. The half refund on an interrupt stays the player's (as before).
   - (d) **The academy's fighters** as C24's generic cards drilled on one house's dialect with the house left out (no trait, no home bonus), in Director Vey's corner (`ascendant_a`).
   - (e) **"Your club's answer is fewer hybrids, forged through actual relationships"**: C41's forged hybrid relayed ×1.25 with the partner's afterimage, set against his best synthesis on the matchup card's THESIS line.
9. **Editorial, to confirm or overrule:**
   - The ×0.85, the three a prodigy, the reach +0.3; the five prodigies' styles, dialects and house pairs; the handles ASCENDANT 1–5 (placeholders for the content lane).
   - The name rule "Synthesis {motif}-{motif}" from the Forge's motifs; the ids `synthesis:academy`, `vfx_synth`.
   - `-- academy` as a squad fielded against whatever the club dresses (not a format); fielding only between duals.
   - The ACADEMY and THESIS lines' and the SYNTHESIS toast's wording; `-- demo academy`.
   - To reverse the rules and numbers, edit the table.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-092 row (CSV-ready, todo columns)
ID: PAC-092 | Title: The Toronto academy — industrialized hybrids (NP_07 s10, Arc 3's thesis) | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The academy as data: its squads (generic cards on the assembler, C24) carrying hybrids composed without bonds, breadth over depth - more hybrids a fighter, each slightly weaker per move than a forged one, no duo VFX, no afterimage, no feud or alliance history, cast by the enemy side on its own rule. The club's answer on the sim: its forged hybrids (C41) against the academy's, the difference readable on the matchup card and in the numbers. The academy's dual as a format or a squad the sim can field. Gates cover the composer's industrial rule (weaker per move, breadth), the enemy side's casts, the matchup against a forged hybrid; determinism with an academy squad in the log.
BlockedBy: PAC-091 | DependencyType: soft | RelatedWork: NP_07 s10; NP_08 s6; NP_12 s6; NP_04B; NP_14 C13 C14 C24 C41 C46; data/academy.v1.json; data/hybrids.v1.json; data/coaches.v1.json
Notes: 2026-09-24: SMOKE 396/396 GREEN x 24 bosses (9,504 assertions; +5). DETERMINISM 46/46 (the academy on the delegated log: ASCENDANT 1-3 in Vey's corner, four syntheses cast, the squad the academy's to the end; identical twice, different from the same log vs Yuri's squad; no older figure moved). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks, zero script errors: -- demo academy boss=1 (16,000 frames, x2) - 1 and 2 syntheses, 2-12 in R3 at the end; -- demo academy hybrid on the Forge's sanctioned line (60,000 frames, x2) - the five prodigies to the end, 7 and 6 syntheses against 3 and 2 Grain & Snow relayed, 7-18 in R5 at the end; regressions x1 - demo hybrid (Grain & Snow relayed x4), demo techniques (16 learned, 8 kit casts), demo growth (22 steps), the exhibition at home (two duo syncs). One gate moved (command 6).
LearningNotes: The Forge's composer already did the academy's work. It only needed splitting from the pair's ledger: `_compose_parts` takes houses and native lists, and the forged hybrid calls it as before, so every C41 gate held unchanged. The enemy side cast a hissatsu only at his authored desperation. The synthesis rides that same path (`_start_cast("B", ...)`) behind one check at his decision point, so the interrupt, the windup and the resolve come for free. The half refund on an interrupt was only ever the player's, and the gate says so. In a headless scene the key's jab lands only if the prodigy's read is cancelled, as the smoke's `throw_clean` does, so the drive steps it to its landing. The first 60,000-frame sanctioned soak ended with two named bosses in the academy's squad. The format dresses more than it fights, so Vey's corner swapped a named benched boss in. The academy now dresses only its prodigies, and the smoke and determinism gates check the bench and the squad.
StartedAt: 2026-09-24T20:55:40Z | DoneAt: 2026-09-24T22:28:31Z

## PAC-093 row (CSV-ready, todo columns)
ID: PAC-093 | Title: The mirror spar — the adaptation tracker's copy of your habits (NP_02 s2.2 lab flag) | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_02 s2.2's mirror spar lab flag on the sim: a spar opponent assembled (C24's assembler) from the adaptation tracker's record of how the player fights (C7) - his most-thrown rows as strings, his habits as the pattern's SELECT weights, his defensive answers as its punishes - on the fighter's own card. The flag as a spar modifier beside infinite stamina and tell-highlight (C18), its XP and rewards by the scrap table. The copy readable before the bell (what it learned from you). Gates cover the copy built from a seeded tracker, a different habit giving a different copy, the spar's objective judge, the save; determinism with a mirror spar in the log.
BlockedBy: PAC-092 | DependencyType: soft | RelatedWork: NP_02 s2.2; NP_04 s1; NP_11 s4; NP_14 C7 C18 C24 C44; data/scrap_objectives.v1.json; data/pattern_pieces.v1.json
Notes: Alternative for PAC-093: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
