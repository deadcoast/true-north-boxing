# REGISTER COMMANDS 032 — for the applying writer
**From: @claude · 2026-09-23 · Re: PAC-083 Spirit Manifestation (greybox v6, NP_14 C37)**
Same rule as 001–031: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-083 Status DONE** (row payload below replaces the TODO row from 031).
2. **Correction to 031's PAC-083 TODO row:** its DoD gave the Manifest's Comedown as "the caster's own dialect scrambled 10 s". That is NP_09 §5's, Inheritance's. §4 names no Comedown of its own, so the Manifest takes §1's standard (10 s at 85 %). The DONE row's DoD below carries the corrected text.
3. **Add PAC-084** (row below) — Status TODO. Inheritance (NP_09 §5), the ladder's next rung on the same SURGE: 25 s; a Sworn bond (Kizuna Lv5, NP_08 §5.2) with the source, or a story-flagged legacy source. The caster gains the source's house trait (C32's), their native technique set cast from the private 50-point meter (C37's), their tell dialect and their stance, keeping his own stats. Then the standard Comedown plus his own dialect scrambled 10 s. A dual-house character inheriting his own second house pays 75. Alternatives: the enemy's authored transforms (NP_09 §1, one per boss in his desperation block, which would open the Manifest Clash and §7's weathering); the Exhibition 2v2 (NP_01 §8); the club facilities (NP_10 §7).
4. **Note DATA row** `data/transformations.v1.json`. Summary gains: "Spirit Manifestation executed. 30 s. All damage x1.4. Hissatsu paid from a private 50-point manifest meter instead of the team bar. The manifest's echo of each clean punch at 0.3 s for 30 %. DISPLACE metres x2. The shared Comedown. Unlocked by the card: a named character's `story:manifest:{name}`, or a generic stablemate's level 35 and `mastery:zone:{name}`. The named figures are placeholders for the content lane, one element-generic manifest per element. The Manifest Clash is named and `executed: false`. The tiers' `words` for the HUD and the feed." Inheritance and Awakening stay `executed: false`. Both copies.
5. **Link PAC-083** to these rows:
   - **MODULE `sim/core.gd`:** `_tier_word`, `_tier_unlocked` (the unlock by the card) under `transform_tier`, `manifest_of`, `_manifest_dmg` in `_land_player_punch` and `_fx_dmg`, `purse` and `can_pay` replacing each bar-and-hold test, `_echo_queue`, `_echo_land`; `transform`'s Manifest `tform` (manifest, meter, meter_max, echoes) and its feed; `_zone_tick` landing the echoes; `_drop` clearing them; `_resolve_cast`'s DISPLACE x2; `_start_cast` paying from the meter and `_interrupt_cast` refunding to it; the ARMS feed; `transform_why`, the end feed and `zone_line` in the tier's words (the MANIFEST line); the `echo` event.
   - **MODULE `sim/profile.gd`:** `can_pay`; the meter spent as an opening.
   - **MODULE `main.gd`:** the toast naming the manifest and its meter; the figure behind the fighter, pulsing on each echo; the hissatsu line priced from the meter; `-- demo manifest`; the soak's transforms and echoes; the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate, one older gate moved — command 7) and the new `engine/greybox/tools/drive_manifest.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_manifest.gd` (TEST, "Spirit Manifestation driven on the real scene, headless: the Manifest RORY's highest tier; H + Y with the bar full: the toast naming the manifest and its meter, the camera hold; the MANIFEST line, RORY lit, the figure behind him; a clean straight's echo shown 0.3 s on, the figure pulsing; the Comedown's line and toast, the figure gone; then nothing", Linked PAC-083).
7. **One older gate moved — flag for @heat (it still proves its claim):** C36's data gate listed "Spirit Manifestation, Inheritance, Awakening" as named and not run. It now lists Inheritance and Awakening. No figure in any log moved (nothing in the older logs manifests; the Zone's run still ends at 6,069 and its Comedown at 7,702). Every content stamp moved with the table.
8. **Note NP_14:**
   - C37 added (Spirit Manifestation: 5 gates, the Manifest on the scripted log, the Manifest drive).
   - C36's claim, test and not-claimed bullet each say what C37 now runs.
   - A new not-claimed bullet names what C37 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C37.
9. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) The SURGE casts the highest tier unlocked. There is no choice of a lower one (NP_09 names none). "One transformation per fighter per dual" holds across tiers.
   - (b) The unlock goes by the card.
     - A named character's path is his own Arc 2 flag alone, with no level.
     - A generic stablemate's path is level 35 and a Zone mastery flag. A generic stablemate is a card marked `generic`; none is in the club yet.
     - Neither path opens the other's.
   - (c) "All damage x1.4" is every composure hit the fighter deals: his punches, clean or chipped through a guard, and his hissatsu packets. It is not the damage he takes.
   - (d) The meter:
     - It pays each move's own price, the CHARGED half and the element edge included.
     - SAVE THE BAR does not hold it.
     - Short of the price, the motion throws its punch. There is no fall-back to the team bar ("instead of").
     - A cast broken in its window gives half back to the meter.
     - What is left leaves with the manifest.
   - (e) The echo:
     - It follows a punch that lands clean. A block, whiff, walled punch, foul or hissatsu is not echoed ("the fighter's punches").
     - It lands 0.3 s of fight time later; hitstop does not count.
     - It deals 30 % of the punch's damage as it stood before his composure took it, so the x1.4 is inside it.
     - It lands whatever he does in between. A drop or the segment's end cancels it, and his timed wall stops it.
     - His gauge takes it at the punch's own source factor.
     - It earns no Tension, scores nothing and breaks no string.
   - (f) "Zone displacement effects doubled" is the fighter's DISPLACE packets at twice their metres (NP_05 §5's "zone displacement (knock to ropes/corner)"). The herding push of a punch is unchanged.
   - (g) §4 names no Comedown, so it is §1's standard (command 2).
   - (h) Manager mode still never SURGEs on its own. Manifested by the manager's SURGE, the card treats the meter as an opening and spends it.
   - (i) The Manifest Clash is not run: no enemy manifest exists.
10. **Editorial, to confirm or overrule:**
    - The flags' names, `story:manifest:<NAME>` and `mastery:zone:<NAME>`.
    - The placeholder "<NAME>'s manifest".
    - The generic manifests' names ("the Frost manifest", "the Gale manifest", "the Granite manifest", "the Timber manifest").
    - The feed, toast, ARMS and HUD wording, and the tiers' `words`.
    - The greybox figure: a translucent capsule 1.7 x 1.6 in the element's tint, 0.75 m behind him, pulsing 0.12 s on each echo.
    - `-- demo manifest` as the Zone aid's alias.
    - To reverse any of these, edit the table.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-083 row (CSV-ready, todo columns)
ID: PAC-083 | Title: Spirit Manifestation (NP_09 s4) — the second transformation tier on the same SURGE | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The Manifest as data: NP_09 s4's numbers, s1's standard Comedown (s4 names none of its own), the element-generic manifests for stablemates, and the named characters' as content-lane placeholders. The SURGE casts the highest tier unlocked: the Manifest for a named character by his Arc 2 flag, and for a generic stablemate at level 35 with a Zone mastery flag. Then 30 s of: all damage x1.4; hissatsu paid from a private 50-point manifest meter instead of the team bar; the manifest's echo of each punch at 0.3 s for +30 %; displacement effects doubled. Then the Comedown. The Manifest Clash is named and waits for an enemy manifest. Gates cover the unlock and the tier chosen, each effect against a control, the private meter against the team bar, and the Comedown. Determinism runs with a Manifest in the log. The HUD has a MANIFEST line.
BlockedBy: PAC-082 | DependencyType: soft | RelatedWork: NP_09 s1 s4 s7; NP_05 s5 s6; NP_11 s2; NP_12 s5; NP_14 C10 C12 C36 C37; data/transformations.v1.json
Notes: 2026-09-23: SMOKE 351/351 GREEN x 24 bosses (8,424 assertions; +5); DETERMINISM 37/37 (the scripted log against Yuri's squad with RORY's Arc 2 flag: the same SURGE at tick 3,000 manifests him, nine echoes land and one cast is paid from the meter; identical twice, different from the Zone's run); GEOMETRY 5/5; MARGINS GREEN; sim_test 14/14; the hissatsu audit GREEN; the Manifest drive 6/6, the Zone drive 6/6, the formation drive 12/12, the Duo drive 6/6, the recruit drive 8/8; two runs each of 16,000-frame `-- demo manifest` soaks with the Arc 2 flags seeded against Yuri's squad (RORY and PRIYA manifested in both, again in a second dual in one with MARCUS's Zone between), in the sanctioned format against Carter's squad (RORY and JUNE manifested in both, PRIYA's Zone in one) and with a save / load (the same hash back at tick 3,000 in both), 9 to 28 echoes a run; zero script errors. One older gate moved (command 7); 031's DoD corrected (command 2)
LearningNotes: The Zone's code had put every effect behind the live tier's effects table, so the Manifest needed no Zone branches, only its own reads: the multiplier at the two damage sites, the purse in place of the bar, the DISPLACE factor. The echoes live inside `tform`, so the hash, the snapshot and the DualState carried them without a new state variable, and a restore mid-echo lands the same blow. The drive's first final run caught the boss's read planning a dodge after the punch's press (`dodge_at`): the drive now cancels the read whole, as the smoke's `throw_clean` does, and reads the HUD's clock within two tenths (the scene's own real-time loop runs ticks between frames on a loaded machine); six parallel runs GREEN after. A parallel smoke sweep collided on the one user:// save file (the file gate RED on two bosses, GREEN run alone); the delivered sweep is serial, as before
StartedAt: 2026-09-23T20:37:00Z | DoneAt: 2026-09-23T21:23:00Z

## PAC-084 row (CSV-ready, todo columns)
ID: PAC-084 | Title: Inheritance (NP_09 s5) — the third transformation tier on the same SURGE | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: Inheritance as data: NP_09 s5's numbers and its Comedown (the standard plus the caster's own dialect scrambled 10 s), and the legacy sources as story-flagged placeholders. The SURGE casts it when the fighter has a Sworn bond (Kizuna Lv5) with a dressed source, or a legacy flag. Which source he inherits, when several qualify, is read from the doc or flagged. For 25 s he carries the source's house trait (C32's), the source's native technique set cast from the private 50-point meter (C37's), and the source's tell dialect (the enemy's reads misread him). He keeps his own stats. A dual-house character inheriting his own second house pays 75. Gates cover the unlock, the source chosen, each gain against a control, the scrambled dialect in the Comedown, and the 75. Determinism runs with an Inheritance in the log. The HUD has an INHERITANCE line.
BlockedBy: PAC-083 | DependencyType: soft | RelatedWork: NP_09 s1 s5; NP_08 s5.2; NP_07 s3 s5; NP_02 s3; NP_14 C18 C31 C32 C37; data/transformations.v1.json
Notes: The table already names the tier (executed: false). What it is not: the stance and animation set beyond the greybox's; the source standing at the apron mirroring the stance; the legacy film-grain overlay; Awakening; enemy transforms
