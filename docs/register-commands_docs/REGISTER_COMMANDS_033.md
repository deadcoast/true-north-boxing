# REGISTER COMMANDS 033 — for the applying writer
**From: @claude · 2026-09-23 · Re: PAC-084 Inheritance (greybox v6, NP_14 C38)**
Same rule as 001–032: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-084 Status DONE** (row payload below replaces the TODO row from 032).
2. **Add PAC-085** (row below) — Status TODO. Awakening (NP_09 §6), the ladder's summit on the same SURGE. It is story-gated per character: the house SECRET learned and a personal Arc 3 trial, as flags; the protagonist also needs the sealed-house resolution. For 40 s:
   - a chosen prior tier's effects at 75 % strength;
   - +1 hybrid technique slot active;
   - the three rings' caps raised from ×1.5 to ×1.75;
   - a DROP scored while Awakened refunds +15 Tension.

   The "chosen prior tier" needs a way to choose. The proposal: a per-fighter choice set between duals, which would also let a fighter SURGE into a tier below his highest (command 9b).

   Alternatives: the enemy's authored transforms with the Manifest Clash and the weathering (NP_09 §1, §4, §7); the Exhibition 2v2 (NP_01 §8); the club facilities (NP_10 §7).
3. **Note DATA row** `data/transformations.v1.json`. Summary gains:
   - "Inheritance executed. 25 s. The source's house trait beside the caster's own. The source's natives from a private 50-point meter (`meter_pays` inherited). The source's dialect (the enemy misreads). The caster's own stats.
   - The Comedown adds the caster's own dialect scrambled 10 s.
   - Sources by `source_order`: a legacy (`legacy_sources`, flag `legacy:<id>`), a Sworn stablemate of another house, a dual-house card's `house2` at `second_house_cost` 75.
   - The departed coach's slot has house null."

   Awakening stays `executed: false`. Both copies.
4. **Note DATA row** `data/economy.v1.json`. Summary gains: "Kizuna Lv5 Sworn carries `inheritance` (NP_08 s5.2: the Inheritance transformation between the pair unlocked)". Both copies; one line changed, the rest of the file untouched.
5. **Link PAC-084** to these rows:
   - **MODULE `sim/core.gd`:**
     - The sources: `inherit_level`, `inherit_sources`, `inherit_source`, and `_tier_unlocked`'s `inherit`.
     - The begin and end: `transform_cost(name)`, `_inherit_begin`, `_inherit_end`, `P["trait_inh"]` and `_tx`'s reading of it.
     - The moves: `inherited_moves`, `wall_move`, `inherit_pick`, and `cast_move` taking the inherited natives after the relay's T3s.
     - The meter: `_meter_pays`, `purse(mv)`, `can_pay`, `_meter_word`, and `_start_cast` / `_interrupt_cast` on the meter that paid.
     - The dialect: `_misreads` in the read at startup, and the `misread` event.
     - The Comedown: `_zone_tick`'s end and its `scramble_t`, and `_feint` drawing nothing while scrambled or from a misread.
     - The display: `zone_line`'s INHERITANCE line and the Comedown's scramble; `inherit_label`, `_inherit_whose`, `_house_name`.
   - **MODULE `sim/profile.gd`:** `wall_move`, `inherit_pick`, and the meter as an opening.
   - **MODULE `main.gd`:**
     - the toast naming the source;
     - the ghost-frame and the apron figure;
     - the Comedown toast's scramble;
     - the hissatsu line priced by the move;
     - `-- demo inherit`;
     - the soak's sources;
     - the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate, two older gates moved — command 7) and the new `engine/greybox/tools/drive_inherit.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_inherit.gd` (TEST, "Inheritance driven on the real scene, headless: RORY Sworn with SAM; H + Y with the bar full: the toast naming House Tagaq and SAM, the camera hold; the INHERITANCE line, SAM's ghost-frame over RORY, SAM at the apron; H + I arming Sorry Eh from the inherited meter with the team bar untouched; the Comedown's line and toast with RORY's dialect scrambled, the figures gone; then nothing", Linked PAC-084).
7. **Two older gates moved — flag for @heat (each still proves its claim):** C36's and C37's data gates listed the tiers named and not run; both now list Awakening alone. No figure in any log moved: the Zone's run still ends at 6,069 with its Comedown at 7,702, and the Manifest's run at 7,664. Every content stamp moved with the two tables.
8. **Note NP_14:**
   - C38 added (Inheritance: 5 gates, Inheritance on the scripted log, the Inheritance drive).
   - C36's claim, test and not-claimed bullet, and C37's test, say what C38 now runs.
   - A new not-claimed bullet names what C38 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C38.
9. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **Sources:** they come in the order story, bond, blood:
     - first a legacy with its flag set and its house written;
     - then the Sworn stablemate with the most Kizuna points (the stable's order on a tie), dressed or not;
     - then his own second house.

     A source must carry a house other than the caster's own, since the tier is a house style. "Between the pair" works both ways.
   - (b) **Inheritance stands over the Manifest and the Zone.** Following 083's highest-tier read, a fighter with a source can no longer SURGE into a lower tier. NP_09 names no choice, but §6's "chosen prior tier" implies one, which is why PAC-085 proposes a choice.
   - (c) **The trait:**
     - It runs beside his own, read as the source would carry it (lineage, disowned, a last-of-line's doubling).
     - Where both carry the same trait, the larger counts.
     - A stat trait scales his stats (to 99) while he wears it, using the trait's own house's feuds, and gives them back at the end.
     - His house rings stay his: the house worn is the style, not the membership.
   - (d) **The natives:**
     - A stablemate lends his unlocked set; an UNSANCTIONED source lends none. A legacy or a second house lends the house's set. SECRETs are excepted.
     - The move the source carries comes first.
     - Each answers its motion after any open T3 and before the card's own move; WALL natives answer the WALL motion.
     - "Cast from the private 50-pt meter" covers the natives only: his own move and the relay's T3s pay the team bar.
     - SAVE THE BAR does not hold the meter. Half of a broken cast comes back to it, and the rest leaves with the Inheritance.
   - (e) **"Enemies literally misread you":**
     - The enemy's read at a punch's startup (C6/C7) keeps its roll and its odds, but a successful read becomes a misread: no dodge, no guard.
     - The sim has no enemy PI on the player; this read is the enemy's only read of him.
     - A feint draws nothing from a misread.
   - (f) **"Stance/animation set"** is presentation. His NP_06 style package stays his.
   - (g) **The Comedown's "own dialect scrambled 10 s":** his feints draw nothing for 10 s (a false tell in his own dialect nobody buys), beside §1's 85 %.
   - (h) **The second house:**
     - It is a card's `house2`, NP_07 §5's marriage line.
     - Its 75 is read as "the whole bar" at 75: the bar still empties, and no bond is needed ("it was always theirs").
     - No card carries a second house yet. MARTA ("dual-house character", NP_04) and Tam (two lineages, NP_07A; E07's marriage) are the content lane's to write.
   - (i) **The legacy:** an authored `legacy_sources` entry with its flag and its house; the departed coach's slot is empty.
   - (j) **Manager mode** never SURGEs on its own. Inheriting by the manager's call, the card casts the strongest native the meter can pay.
10. **Editorial, to confirm or overrule:**
    - The `house2` and `legacy:<id>` names, and the `source_order` key.
    - The feed, toast, ARMS and HUD wording ("the enemy misreads you"), and the tier's `words`.
    - The greybox figures: the source's ghost-frame over the caster at ×1.08, grey at alpha 0.22 for a legacy; a dressed source's capsule at the apron.
    - `-- demo inherit` as the aid's alias.
    - To reverse the numbers and orders, edit the table.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-084 row (CSV-ready, todo columns)
ID: PAC-084 | Title: Inheritance (NP_09 s5) — the third transformation tier on the same SURGE | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: Inheritance as data: NP_09 s5's numbers and its Comedown (the standard plus the caster's own dialect scrambled 10 s), and the legacy sources as story-flagged placeholders. The SURGE casts it when the fighter has a Sworn bond (Kizuna Lv5) with a source in the stable, or a legacy flag, or his own second house. Which source, when several qualify, is flagged. For 25 s he carries the source's house trait (C32's), the source's native set cast from the private 50-point meter (C37's), and the source's tell dialect (the enemy's reads misread him). He keeps his own stats. A dual-house character inheriting his own second house pays 75. Gates cover the unlock, the source chosen, each gain against a control, the scrambled dialect in the Comedown, and the 75. Determinism runs with an Inheritance in the log. The HUD has an INHERITANCE line.
BlockedBy: PAC-083 | DependencyType: soft | RelatedWork: NP_09 s1 s5 s6; NP_08 s5.2; NP_07 s3 s5; NP_04 s8.2; NP_07A; NP_03 s8; NP_14 C6 C7 C11 C31 C32 C37 C38; data/transformations.v1.json; data/economy.v1.json
Notes: 2026-09-23: SMOKE 356/356 GREEN x 24 bosses (8,544 assertions; +5); DETERMINISM 38/38 (the scripted log against Yuri's squad with SAM in the club, Sworn with RORY: the same SURGE at tick 3,000 takes SAM's House Tagaq style, six misreads and one cast from the inherited meter; identical twice, different from the Zone's run); GEOMETRY 5/5; MARGINS GREEN; sim_test 14/14; the hissatsu audit GREEN; the Inheritance drive 6/6 (six parallel runs GREEN), the Manifest drive 6/6, the Zone drive 6/6, the formation drive 12/12, the Duo drive 6/6, the recruit drive 8/8; two runs each of 16,000-frame `-- demo inherit` soaks in the sanctioned format with RORY+SAM, JUNE+MARTA and PRIYA+YURI at Sworn, against Carter's squad (all three inherited in both, MARCUS's Manifest in R4 in one) and against Yuri's squad with a save / load (RORY and JUNE inherited in both, PRIYA in one; the same hash back at tick 3,000 in both), 5 to 10 misreads a run, and the Manifest soak again (RORY and PRIYA manifested in both); zero script errors. Two older gates moved (command 7)
LearningNotes: NP_09 s5's "enemy PI reads" had no player-side counterpart in the sim: bosses keep no intel on the player's dialect. The enemy's one read of the player is C6's read at a punch's startup, so the misread lives there, with the roll kept so every log without an Inheritance draws the same numbers. `trait` is a reserved word in GDScript 2 and would not parse as a variable name. The first rewrite of the economy table re-flowed the whole file through a JSON dump; it was put back and the Lv5 entry added as one line
StartedAt: 2026-09-23T22:19:00Z | DoneAt: 2026-09-23T22:59:00Z

## PAC-085 row (CSV-ready, todo columns)
ID: PAC-085 | Title: Awakening (NP_09 s6) — the summit of the ladder on the same SURGE | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: Awakening as data: NP_09 s6's numbers, and its gate per character (the house SECRET learned and a personal Arc 3 trial as story flags; the protagonist's also the sealed-house resolution). The SURGE casts it for 40 s:
- a chosen prior tier's effects at 75 % strength (Zone-, Manifest- or Inheritance-Awakening), with the choice made per fighter between duals — the same choice lets a fighter SURGE into a tier below his highest;
- +1 hybrid technique slot active (read against the sim's one-move card);
- the three rings' caps x1.5 -> x1.75 for its duration (NP_06 s4's only exception);
- a DROP scored while Awakened refunds +15 Tension.

Gates cover the gate, each stacked tier at 75 % against its full strength, the caps, the refund, and the tier choice. Determinism runs with an Awakening in the log. The HUD has an AWAKENED line.
BlockedBy: PAC-084 | DependencyType: soft | RelatedWork: NP_09 s1 s3 s4 s5 s6; NP_06 s4; NP_07 s7; NP_07A; NP_14 C13 C36 C37 C38; data/transformations.v1.json
Notes: The table already names the tier (executed: false). The SECRET gate events are not built (C31); Awakening reads them as flags. What it is not: the element-storm arena takeover, the house crest in the environment, the leitmotif; enemy transforms; the protagonist's sealed-house unsealing itself (NP_07 s7)
