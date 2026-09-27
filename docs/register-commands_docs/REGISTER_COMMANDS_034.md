# REGISTER COMMANDS 034 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-085 Awakening (greybox v6, NP_14 C39)**
Same rule as 001–033: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-085 Status DONE** (row payload below replaces the TODO row from 033).
2. **Add PAC-086** (row below) — Status TODO. The enemy's transformations (NP_09 §1, §4, §7). The player's ladder is complete; the other corner still has none. The DoD:
   - a boss's transformation authored per boss in his desperation block, as a new directive in the pattern grammar, felt coming narratively (a tell or a phase line);
   - the Comedown as the player's answer window;
   - the Manifest Clash when both active fighters manifest at once — 5 s of alternating counter-window exchanges at ×0.5 time, pure timing, the winner's manifest ending the loser's;
   - §7's weathering — perfect blocks, slips and clash wins halving the incoming transformation's damage and shaving 1 s each, with "Stood in the Storm" when a boss's transformation is weathered without answering.

   Which bosses transform is the content lane's: the gate authors one on a roster boss's desperation line as a placeholder.

   Alternatives: the Exhibition 2v2 (NP_01 §8); the club facilities (NP_10 §7); hybrid research (NP_08 §6), which would fill Awakening's slot.
3. **Note DATA row** `data/transformations.v1.json`. Summary gains:
   - "Awakening executed: 40 s; a chosen prior tier's effects stacked at 75 % by `stack_rules` (mult, add, period, fraction, keep); the rings' caps x1.75 for the Awakened; +15 Tension back per drop scored; the hybrid slot (no hybrid exists).
   - Gated by `secret:{name}` and `story:trial:{name}`, and for the protagonist RORY also `story:sealed_house_resolved`, with a prior tier to stack.
   - `choice`: a card's `surge_tier` (the tier his SURGE casts) and `awakening_form` (the tier his Awakening stacks), chosen between duals.
   - Every tier executed."

   Both copies.
4. **Link PAC-085** to these rows:
   - **MODULE `sim/core.gd`:**
     - The gate and form: `_awaken_gate`, `awaken_form`, `_tier_unlocked`'s `awaken`, `transform_tier`'s `surge_tier`.
     - The choice: `choose_surge`, `surge_line`.
     - The stacking: `_stack_fx`, `_form_text`, `_n`; `tform["fx"]` / `["form"]` and `_zone_fx` reading them.
     - The fractions: `_frac`, the part-frozen stamina in `_zone_tick`, `_misread_frac`, `_tx` returning a float.
     - The caps: `_tmult(base, x, F)`, `_cap_of`, and `hiss_mult`'s cap.
     - The refund: `_drop`'s refund and the `refund` event.
     - The display: the AWAKENED head in `zone_line`, and the end feed.
   - **MODULE `sim/save.gd`:** `CARD_KEYS` and the Fighter record carry `surge_tier` and `awakening_form`.
   - **MODULE `main.gd`:**
     - `-- surge=`, `-- form=` and `-- demo awaken`;
     - the matchup card's SURGE line;
     - the AWAKENING and AWAKENED DROP toasts;
     - the ring floor lit, the fighter at his brightest;
     - the soak's forms;
     - the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate, three older gates moved — command 7) and the new `engine/greybox/tools/drive_awaken.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_awaken.gd` (TEST, "Awakening driven on the real scene, headless: RORY's gate met and the Manifest chosen; the matchup card's SURGE line; H + Y with the bar full: the toast, the camera hold; the AWAKENED line, the ring lit in his element, his manifest behind him; a drop scored refunding 15 with its toast; the Comedown's line and toast, the ring dark, the figure gone; then nothing", Linked PAC-085).
6. **Note MODULE row `sim/save.gd`:** the save now writes a card's `surge_tier` and `awakening_form` when they are set. Older saves read unchanged; a save without them writes back byte-equal.
7. **Three older gates moved — flag for @heat (each still proves its claim):** C36's, C37's and C38's data gates listed the tiers named and not run; they now list none. No figure in any log moved: the Zone's run still ends at 6,069 with its Comedown at 7,702, the Manifest's at 7,664, Inheritance's at 7,038. Every content stamp moved with the table.
8. **Note NP_14:**
   - C39 added (Awakening and the SURGE's choice: 5 gates, Awakening on the scripted log, the Awakening drive).
   - C36's claim, test and not-claimed bullet, C37's test, and C38's test and not-claimed bullet say what C39 now runs.
   - A new not-claimed bullet names what C39 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C39.
9. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **The gate:**
     - The SECRET and the trial are the flags `secret:<NAME>` and `story:trial:<NAME>`. The SECRET gate events (NP_07A) are not built, and whether a houseless fighter has a SECRET is the story's call.
     - The protagonist is RORY (NP_05's "protagonist signature line" is his Aurora Borealis Breaker), with `story:sealed_house_resolved` besides.
     - A prior tier must be unlocked, since Awakening stacks one.
   - (b) **"Stacks a chosen prior tier's effect at 75 % strength"** reads each effect by its kind:
     - a multiplier's reach from ×1 (×0.75 → ×0.8125, ×1.4 → ×1.3, ×2 → ×1.75);
     - an amount (+200 ms → +150, +15 % → +11.25, a 50-point meter → 37.5, +30 % → +22.5);
     - a period at 75 % the frequency (every 3 s → every 4 s);
     - a state's fraction: stamina 75 % frozen, so it moves at a quarter; three reads in four misread; the inherited trait's magnitudes at 75 %, with a use count (Never Twice's one wobble) kept whole;
     - a timing and a route kept (the echo's 0.3 s; which moves the meter pays);
     - the tier's own identity kept whole (the manifest's figure, the Inheritance's source).
   - (c) **"Chosen"** is the card's `awakening_form`, set between duals; it must be a tier he has unlocked, and defaults to his highest prior tier.
   - (d) **The SURGE's choice of a lower tier** (`surge_tier`) is an addition answering 084's command 9b: NP_09 names no choice. It defaults to the highest tier.
   - (e) **"+1 hybrid technique slot active"** is a slot opened on nothing: NP_08 §6's hybrid research is not built.
   - (f) **The caps' ×1.75** applies to his side only, while he is Awakened, on every advantage the sim caps: the hissatsu's ring product and the house traits' multipliers. The opponent's cap stays ×1.5.
   - (g) **The refund** is 15 flat to the team bar per drop he scores (a flash drop and an echo's drop too). It bypasses the earning modifiers (it is a refund, not earnings) and stops at 100.
   - (h) **The Comedown** is the standard one. The stacked tier's own riders (Inheritance's scrambled dialect) belong to casting that tier, not to its 75 %.
10. **Editorial, to confirm or overrule:**
    - The flag names `secret:<NAME>` and `story:trial:<NAME>`.
    - The field names `surge_tier` and `awakening_form`.
    - `-- surge=`, `-- form=` and `-- demo awaken`.
    - The wording of the SURGE line, the AWAKENED line, the feed and the toasts.
    - The greybox: the ring floor lit in the element at 0.7, the fighter's emission at 2.2.
    - `choose_surge` refuses in the fight (between duals only).
    - To reverse the rules and numbers, edit the table.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-085 row (CSV-ready, todo columns)
ID: PAC-085 | Title: Awakening (NP_09 s6) — the summit of the ladder on the same SURGE, and the SURGE's choice of tier | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: Awakening as data: NP_09 s6's numbers and its gate per character (the house SECRET learned and a personal Arc 3 trial as story flags; the protagonist's also the sealed-house resolution). The SURGE casts it for 40 s:
- a chosen prior tier's effects at 75 % strength (Zone-, Manifest- or Inheritance-Awakening), the choice made per fighter between duals — the same kind of choice lets a fighter SURGE into a tier below his highest;
- +1 hybrid technique slot active (read against the sim's one-move card);
- the three rings' caps x1.5 -> x1.75 for its duration (NP_06 s4's only exception);
- a DROP scored while Awakened refunds +15 Tension.

Gates cover the gate, each stacked tier at 75 % against its full strength, the caps, the refund, and the tier choice. Determinism runs with an Awakening in the log. The HUD has an AWAKENED line.
BlockedBy: PAC-084 | DependencyType: soft | RelatedWork: NP_09 s1 s3 s4 s5 s6; NP_06 s4; NP_05 s5; NP_07 s7; NP_07A; NP_08 s6; NP_11 s9; NP_14 C13 C23 C36 C37 C38 C39; data/transformations.v1.json
Notes: 2026-09-24: SMOKE 361/361 GREEN x 24 bosses (8,664 assertions; +5); DETERMINISM 39/39 (the scripted log against Yuri's squad with RORY's gate met: the same SURGE at tick 3,000 Awakens him with the Zone stacked, ten slips, two drops refunded; identical twice, different from the Zone's run); GEOMETRY 5/5; MARGINS GREEN; sim_test 14/14; the hissatsu audit GREEN; the Awakening drive 6/6 (six parallel runs GREEN), the Inheritance drive 6/6, the Manifest drive 6/6, the Zone drive 6/6, the formation drive 12/12, the Duo drive 6/6, the recruit drive 8/8; two runs each of 16,000-frame `-- demo awaken` soaks: against Yuri's squad with RORY's form the Manifest (Awakened with it in both, PRIYA with the Zone in one), in the sanctioned format against Carter's squad with RORY+SAM Sworn and surge=JUNE:zone (RORY's Inheritance-Awakening in both, JUNE's chosen Zone in both) and against Yuri's squad with a save / load and RORY's form the Zone (the same hash back at tick 3,000 in both), one or two refunds a run; zero script errors. Three older gates moved (command 7)
LearningNotes: Every tier since the Zone reads its effects through `_zone_fx`. Awakening therefore only had to put a scaled copy of the chosen tier's effects in `tform`: the Manifest's echo, the Inheritance's natives and the Zone's slips ran unchanged at 75 %. Three effects were booleans, which have no 75 %: they became fractions. The part-frozen stamina scales each tick's change; the misread took an extra roll only below 100 %, so no older log draws a different number. The final run's Zone and Inheritance drives caught the new matchup-card line: "SURGE: IN THE ZONE" read as the Zone's own HUD line to their no-line checks, so the SURGE line names the tier as written ("SURGE: In the Zone"), the upper case staying the live tier's. The caps' gate needed a ring product above x1.5: a house native in its own element against a beaten element (MARTA's Miroir d'Hiver, x1.573) is one
StartedAt: 2026-09-24T07:04:00Z | DoneAt: 2026-09-24T07:52:00Z

## PAC-086 row (CSV-ready, todo columns)
ID: PAC-086 | Title: The enemy's transformations (NP_09 s1, s4, s7) — authored per boss, the Manifest Clash, the weathering | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: A boss's transformation authored per boss: a desperation directive in the pattern grammar that casts a tier on his side, felt coming narratively (a tell or a phase line), never systemic RNG. His tier's effects run on his side of the sim, followed by his Comedown as the player's answer window. The Manifest Clash when both active fighters manifest at once: 5 s at x0.5 time, alternating counter-window exchanges, pure timing, the winner's manifest ending the loser's. NP_09 s7's weathering: perfect blocks, slips and clash wins halving the incoming transformation damage and shaving 1 s each; a boss's transformation weathered without answering is authored as "Stood in the Storm". Gates cover the directive, each of his tier's effects against a control, the Clash, the weathering, and his Comedown. Determinism runs with a boss transformation in the log. The HUD has a line for his tier.
BlockedBy: PAC-085 | DependencyType: soft | RelatedWork: NP_09 s1 s4 s7; NP_04 s2 s7; NP_04A; NP_04B; NP_14 C8 C19 C20 C21 C36 C37 C38 C39; data/transformations.v1.json; data/patterns
Notes: Which bosses transform, and into what, is the content lane's; the gate authors a placeholder on one roster boss's desperation line. What it is not: presentation beyond the greybox's; an enemy Inheritance or Awakening unless a boss is authored with one
