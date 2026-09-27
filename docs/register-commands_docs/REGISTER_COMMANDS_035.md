# REGISTER COMMANDS 035 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-086 The enemy's transformations (greybox v6, NP_14 C40)**
Same rule as 001–034: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-086 Status DONE** (row payload below replaces the TODO row from 034).
2. **Add PAC-087** (row below) — Status TODO. Cross-house hybrid research (NP_08 §6). The transformation ladder is complete on both corners; Awakening's hybrid slot still opens on nothing. The DoD:
   - a Sworn pair from different houses, each with a native learned, researches a hybrid T3 at a Forge event (its cost on the ledger);
   - the move is unique to the pair, its effect composed from both native families' effect tags, castable by either and strongest relayed between them;
   - the launch ceiling of 8 per save;
   - the Awakening's slot filled by one.

   NP_05 §10's *Two Rivers* is the doc's example. Beans, the Forge scene and the name generator's motifs are the content lane's or first drafts.

   Alternatives: the Exhibition 2v2 (NP_01 §8, the only simultaneous format, the duo hissatsu's showcase); the club facilities (NP_10 §7).
3. **Note DATA row** `data/transformations.v1.json`. Summary gains:
   - "`boss`: the tiers a boss may cast (the Zone, the Manifest), the tell floor 1000 ms, one per boss per dual, the grammar, how each effect reads on his side.
   - `shared.weathering`: a perfect block, a slip or a Clash exchange won shaves 1 s; weathered, his damage x0.5; the feat `stood_in_the_storm`.
   - The Manifest's `clash` executed: 5 exchanges in 5 s at x0.5, 180 ms windows, 3 to win, the card 60 %."

   Both copies.
4. **Note TOOL rows** `pbn_compiler.py` and `tools/pbn_compiler.py` (identical):
   - The new line `TRANSFORM @ <cond>: <tier> ["<manifest name>"] TELL(<motif>, <ms>ms) "<line>"` compiles into a pattern's `transform` block.
   - Rails read from the table: a tier a boss can cast, the tell at the floor, a manifest named, one per boss.
   - `--selftest` seeds 10 classes (4 new).
   - `--margins` lists the transformation tells and gates them at RT(3).
5. **Note CONTENT rows:**
   - `pbn/ioan_vasile.pbn` gains his TRANSFORM line (the Zone at composure<50, TELL(breath_held, 1500ms), the line).
   - It compiles to `data/patterns/ioan_vasile.json` and `engine/greybox/patterns/ioan_vasile.json`; no other pattern changed.
   - The vault manifest gains a row for the data copy, as PAC-067 shipped Vey's.
6. **Link PAC-086** to these rows:
   - **MODULE `sim/core.gd`:**
     - The state: `btsurge`, `btform`, `bcomedown`, `btransformed`, `mclash` (in the hash and the snapshot; reset at the dual and the segment).
     - The gathering: `_boss_transform_check` (between his actions; with `_fire_event`'s hooks, his desperation and his survival grab held while he gathers) and `_boss_transform`.
     - The run: `_btform_tick`, `_boss_tform_end`, `_feat`.
     - His Zone: the boss step's rate, `_auto_slips`, `_sfloor`.
     - His Manifest: `_land_boss_punch`, `_fx_dmg`, DISPLACE, `_becho_queue`.
     - The weathering: `_weather`, `_weather_mult`; the player's SURGE marks it answered.
     - The Clash: `_clash_start`, `_clash_step`, `_clash_end` and the CLASH mode.
     - The display: `bzone_line`, `_bword`, the DualState's `transform_log.away`.
     - The test switch: `btransform_on`.
   - **MODULE `main.gd`:**
     - the GATHERING, ENEMY ZONE / MANIFEST, WEATHERED, ENEMY COMEDOWN, STOOD IN THE STORM and Clash toasts and HUD lines;
     - the boss swelling, lit in his element with his figure behind him, dimmed in his Comedown;
     - CLASH input on the ordinary keys;
     - `-- btransform=` and `-- demo clash`;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate, four older gates moved — command 8) and the new `engine/greybox/tools/drive_bzone.gd` and `engine/greybox/tools/drive_clash.gd`.
7. **Add TEST rows:**
   - `engine/greybox/tools/drive_bzone.gd` (TEST, "the enemy's transformation on the real scene, headless, against Vasile: his line on the page; under 50 % the GATHERING line and toast; the hold, ENEMY ZONE's toast, the boss lit; the clock; E (the slip) weathering it; ENEMY COMEDOWN with STOOD IN THE STORM, the boss dimmed, the feat on the ledger; the window shut", Linked PAC-086).
   - `engine/greybox/tools/drive_clash.gd` (TEST, "the Manifest Clash on the real scene, headless, against Moira with the aid's line: her Manifest and figure; H + Y for RORY's; the Clash's toast, mode and cue lines; five exchanges on SPACE and J in their windows, CLASH WON 5 of 5, hers suppressed into her Comedown, his manifest up, five weatherings, the clock where it was", Linked PAC-086).
8. **Four older gates moved — flag for @heat (each still proves its claim):**
   - (a) C37's data gate asserted the Clash not run; it now asserts it run.
   - (b) The smoke helper `boss_desperation` spends an authored transformation first, since it now comes before his desperation. Only The Mean's state gate on Vasile was affected.
   - (c) The smoke's generic stages keep an authored line unrun, as the wall gauge is stripped for them. Only Vasile's, as boss 16, was affected.
   - (d) The Vasile neutral-game determinism gate keeps his line unrun on its four runs, since it watches his clock kits. With his Zone live, the frozen run's R1 ended after one turn.

   No other log figure moved: the Zone's run ends at 6,069 with its Comedown at 7,702, the Manifest's at 7,664, Inheritance's at 7,038, Awakening's at 8,604 and 9,824. Every content stamp moved with the table.
9. **Note NP_14:**
   - C40 added (5 gates, his Zone on the scripted log, the two drives).
   - C4's test now includes the transformation tells.
   - C36's claim and not-claimed bullet, C37's claim, test and not-claimed bullet, and C38's not-claimed bullet say what C40 now runs.
   - A new not-claimed bullet names what C40 does not build, and its readings.
   - Five reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C40.
10. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **Vasile's "his authored T4 usage fires at the 50% mark"** (NP_04B §24):
      - "T4" is NP_05's transformation class;
      - the tier is the Zone, NP_09's universal tier, since he has no house and no named manifest (the Manifest would be a one-line edit of his pattern);
      - the mark is 50 % composure. The alternative is the clock's 45 s.
      - "The fight's hidden achievement" for weathering it is Stood in the Storm.
    - (b) **"Authored per boss (desperation blocks)"** is a TRANSFORM line beside his DESPERATION line, not inside it, since the desperation block keeps its hissatsu. Its trigger uses the phase vocabulary.
    - (c) **"Felt coming narratively"** has three parts:
      - a tell at the ARMORED floor, on fight time behind his guard, with a line said;
      - checked between his actions, never mid-string;
      - "not interruptible" (NP_05 §9's Enemy T4): nothing breaks the gathering, and his hooks, desperation and survival grab wait.
    - (d) **His tiers are the Zone and the Manifest** (a boss casts no Inheritance or Awakening), at the table's durations, his bar emptied, once per boss per dual:
      - His Zone mirrors the player's: his timers ×1/0.75 outside his tells (his tells keep C4's floors), his acting +15 %, the auto-slip on the player's punches, his stamina frozen. There is no counter-window analogue, since bosses counter by authored string.
      - His Manifest has no meter, since bosses cast by composure (C14): damage ×1.4 on punches and hissatsu, the echo on his clean punches, DISPLACE ×2.
      - His Comedown is the shared one, on every stat.
    - (e) **The weathering** is the player's alone. §7 honours "the player who saved nothing"; the boss does not weather the player's transformations.
      - 1 s per perfect-defense action: a perfect block; a slip, whether his own dodge or his Zone's auto-slip; or a Clash exchange won.
      - §7's "reduce incoming transform damage 50% and shave 1 s off its duration each" (NP_05 §9: "perfect-defense sequences reduce damage 50%") is read as halved from the first action for the rest of the transformation. The alternative is a halving that compounds per action.
    - (f) **Stood in the Storm** needs at least one weathering, no transformation of the player's while it ran, and never being knocked down. A Clash's suppression answers it.
    - (g) **The Clash:**
      - "Each 180 ms window at ×0.5" is 360 ms either side of the cue.
      - An early press loses the exchange, and the enemy strikes first.
      - The fight clock and both manifests' clocks wait.
      - The delegated card presses on the cue six times in ten and ignores the pad.
11. **Editorial, to confirm or overrule:**
    - The line's syntax and the table's `boss` and `weathering` keys.
    - The feat's id `stood_in_the_storm` and the ledger key `rewards.feats`.
    - Vasile's line text, "VEY: he has stopped breathing out loud - that is his Zone coming. Weather it." and its motif `breath_held`. These are placeholders for the content lane.
    - The enemy side's strings name "the enemy", not "he" (GATHERING, ENEMY ZONE, ENEMY COMEDOWN, "the enemy's manifest"), since a boss may be anyone.
    - The greybox aids `-- btransform=TIER@TRIGGER[@name]` and `-- demo clash`.
    - The greybox's look: the gathering's glow at 0.35, his tier's at 0.8 (1.4 manifested), his figure a capsule behind him, his Comedown's albedo darkened 0.3.
    - The test switch `btransform_on`.
    - To reverse the rules and numbers, edit the table.
12. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-086 row (CSV-ready, todo columns)
ID: PAC-086 | Title: The enemy's transformations (NP_09 s1, s4, s7) — authored per boss, the Manifest Clash, the weathering | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: A boss's transformation authored per boss: a desperation directive in the pattern grammar that casts a tier on his side, felt coming narratively (a tell or a phase line), never systemic RNG. His tier's effects run on his side of the sim, followed by his Comedown as the player's answer window. The Manifest Clash when both active fighters manifest at once: 5 s at x0.5 time, alternating counter-window exchanges, pure timing, the winner's manifest ending the loser's. NP_09 s7's weathering: perfect blocks, slips and clash wins halving the incoming transformation damage and shaving 1 s each; a boss's transformation weathered without answering is authored as "Stood in the Storm". Gates cover the directive, each of his tier's effects against a control, the Clash, the weathering, and his Comedown. Determinism runs with a boss transformation in the log. The HUD has a line for his tier.
BlockedBy: PAC-085 | DependencyType: soft | RelatedWork: NP_09 s1 s4 s7; NP_05 s9; NP_04 s2 s7; NP_04B s24; NP_14 C4 C13 C14 C36 C37 C38 C39 C40; data/transformations.v1.json; pbn/ioan_vasile.pbn; pbn_compiler.py
Notes: 2026-09-24: SMOKE 366/366 GREEN x 24 bosses (8,784 assertions; +5). DETERMINISM 40/40 (the scripted log against Ioan Vasile: his gathering at 1,546, his Zone at 1,731, weathered six times, its end at 3,731 with Stood in the Storm, his Comedown's end at 4,986; identical twice, different from the log with his line stripped). GEOMETRY 5/5. MARGINS GREEN (his transformation tell +975 ms over RT(3)). The compiler's selftest 10/10, the 24 sources recompiled byte-identical. sim_test 14/14. The hissatsu audit GREEN. Drives: the enemy-transformation drive 7/7, the Clash drive 5/5, the Awakening, Inheritance, Manifest and Zone drives 6/6, the formation drive 12/12, the Duo drive 6/6, the recruit drive 8/8. Two runs each of 16,000-frame soaks: `-- demo boss=16` (his Zone and Stood in the Storm in both); `-- demo clash boss=19 btransform=manifest@composure<80` (Moira's and Remy's Manifests in both, Tam's in one; a Clash in each, the card 3 of 5); `-- demo boss=16 saveload` (the same hash back at tick 3,000 in both). Zero script errors. Four older gates moved (command 8)
LearningNotes: The enemy's side reused the player's machinery where it could (the tier table's effects, `_frac`, the shared Comedown), but the boss's step needed its own guards. The first smoke on Vasile caught two problems. First, his gathering triggers at composure<50, before his desperation at 25, so The Mean's gate cast nothing and the generic drop gates met a raised guard. Second, he could start gathering mid-string, which broke the string gate. The gathering now waits for his actions to end, the generic stages keep his line unrun, and the helper spends it. Three more were caught before the gates were written: a punish hook could force a string over his gathering (the hooks now wait); his Manifest crashed the boss step on a missing time_scale (now read once, defaulted); and the delegated Clash took the demo log's keys as presses (now only the card presses). The Clash drive caught the Comedown's toast overwriting the Clash's verdict; the two now show side by side. The strings say "the enemy", since Moira is not "he"
StartedAt: 2026-09-24T07:55:00Z | DoneAt: 2026-09-24T08:53:51Z

## PAC-087 row (CSV-ready, todo columns)
ID: PAC-087 | Title: Cross-house hybrid research (NP_08 s6) — a Sworn pair of two houses forges a T3 of its own | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: Hybrid research as data. A Sworn (Lv5) pair from different houses, each with at least one native technique learned, researches at a Forge event (its cost on the reward ledger: the Beans and Spirits NP_08 s6 names). The output is a hybrid T3 unique to the pair: its name from both house motifs, its effect composed from both native families' effect tags, castable by either fighter and strongest relayed between them. The launch ceiling is 8 hybrids per save. An Awakened fighter's hybrid slot (NP_09 s6) holds one of his. Gates cover the requirement (each part refused alone), the composition against both parents, the relay's edge, the ceiling, the slot and the save. Determinism runs with a hybrid cast in the log.
BlockedBy: PAC-086 | DependencyType: soft | RelatedWork: NP_08 s5.2 s6; NP_07 s5 s10; NP_05 s7 s10; NP_09 s6; NP_11 s9; NP_14 C10 C22 C34 C39; data/hissatsu_library.v2.json; data/economy.v1.json
Notes: The Forge scene, Beans as a currency and the name generator's motif lists are the content lane's or first drafts. The Toronto academy's industrialized counterpart (NP_07 s10) is story. Not included: the technique-slot model's hybrid tax (NP_07 s5), unless the slot needs it
