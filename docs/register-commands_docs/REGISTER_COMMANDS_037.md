# REGISTER COMMANDS 037 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-088 The Exhibition 2v2 (greybox v6, NP_14 C42)**
Same rule as 001–036: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-088 Status DONE** (the row payload below replaces the TODO row from 036).
2. **Add PAC-089** (row below), Status TODO: the club facilities (NP_10 §7), the gym progression tree. The tree has five tracks, each T1 → T3, paid in story + HBP + Spirits. Its effects reach the sim's ledgers:
   - Bags & Mitts' Beans yield: nothing in the sim earns the Forge's Beans yet (C41).
   - The Ring's "2v2 exhibition hosting": C42's format runs whenever it is asked for.
   - The Film Room's PI grind and Scout Book capacity.
   - The Wall's Forge hosting and bond board slots.
   - Front of House's crowd heat base and Prestige from hosted duals.

   Each tier is a visible renovation, and the ledgers carry the levels.

   Alternative: the Toronto academy's industrialized hybrids as Arc 3's thesis mechanic (NP_07 §10).
3. **Note DATA row** `data/formats.v1.json`. The summary gains:
   - "`exhibition_2v2` (NP_01 s8): one segment, two dressed a side, simultaneous, no Golden DROP, sync_ms 500, partner_answer_ms 250, manager_duo_bar 90."
   - "The one simultaneous format; no rotation."

   Both copies.
4. **Note DATA row** `data/economy.v1.json`. The summary gains: "Lv4 Duo carries `exhibition_duo`: the pair's duo sync in the Exhibition 2v2 (NP_05 s7)." This is a one-line edit; both copies.
5. **Add MODULE row** `engine/greybox/sim/exhibition.gd` (MODULE, "the Exhibition 2v2's coordinator: two engagements in lockstep, one per pair; the shared ledger, bars, crowd and ring clock; the duo sync's window, the AI partner's answer and the manager's call; Two-Hand Winter's shared gauge; the ladder on the pairs' sums and the one pay; the pad's seat; hash, snapshot and restore of the whole").
6. **Link PAC-088** to these rows:
   - **MODULE `sim/exhibition.gd`** (new, command 5):
     - setup and `_mk`;
     - the tick: `step` / `step_pair`, `_sync_input`, `_holds`, `_open`, `_window_tick`, `_fire`, `_miss`, `_manager_call`;
     - the shared state: `_reconcile`, `_link_wall`;
     - the end and the seat: `_check_end` / `_end`, `restart`, `swap_control`, `set_manager`, `set_partner_ai`;
     - the record: `hash_state`, `snapshot` / `restore`, `lines` / `duo_line`.
   - **MODULE `sim/core.gd`:**
     - `exhibit` and `bar_hold` (read by `can_pay`);
     - `_build_lineup`'s simultaneous branch;
     - `_end_dual` → `_exhibit_end`;
     - `_wall_tick`'s owner rule and the WALL resolve's duo mark;
     - `castable` / `_meter_pays` for a duo sync;
     - `_start_cast`'s `duo_sync` fields;
     - `wall_motion()`.
   - **MODULE `main.gd`:**
     - `-- format=exhibition_2v2`, `-- pair=`;
     - both pairs in their halves;
     - the HUD's exhibition lines and the shared wall;
     - the toasts;
     - `\`, F5, F9 and the refused keys;
     - the demo aid, the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate) and the new `engine/greybox/tools/drive_exhibition.gd`.
7. **Add TEST row** `engine/greybox/tools/drive_exhibition.gd` (TEST, "the Exhibition 2v2 on the real scene, headless: the festival format and each pair in its own half, the HUD's lines; H + O calls Double Overtime; PRIYA's profile answers at 250 ms, both halves cast it at RORY's price once, gilded; it lands on both; \ passes the pad; the bell on both - EXHIBITION OVER, one REWARD toast, the bond once; F5 again. 7/7").
8. **The DoD against the build — flag for @heat.** 036's DoD asked for "the sim's second fighter on each side: position, targeting, the partner's state", and its command 2 for "the tag-in rules the doc implies". **The build runs the Exhibition as two engagements in lockstep, one per pair, not a four-body sim.**
   - Position and targeting are per pair. Each fighter fights his own opponent on the ring's geometry, and nobody reaches across. The greybox draws each pair in its own half.
   - There are no tag-ins. NP_01 §8 names none; "in ring simultaneously" is two pairs at once.
   - The partner's state is the coordinator's: one bar, one bell, one ledger, one duo wall, and both pairs on the HUD.
   - "The enemy pair's side": both enemies fight and share one bar; there is no enemy duo.

   **Effort, named, because it chose the model.** The core is one fighter against one boss in every rule (P and B across ~7,100 lines), and C6 keeps one resolution function. A four-body sim means re-plumbing all of it and re-proving every gate. The two-engagement model reuses the sim whole: every older gate and every figure in every log is unchanged. If a true four-body ring (cross-targeting, tags, collisions) is wanted, it is its own PAC.
9. **No older gate moved.** The determinism log's 41 earlier lines are identical to PAC-087's, figure for figure. Every content stamp moved with the two data edits.
10. **Note NP_14:**
    - C42 added (5 gates, the exhibition on the delegated log, the exhibition drive).
    - C15's and C16's claims say what C42 adds (a sixth format record, no rotation; the partner on his profile from the bell and the pad passing mid-segment).
    - The not-claimed bullets on the profile, the formats, the Duo and hybrid research say what C42 now runs.
    - A new not-claimed bullet names what C42 does not build, and its readings.
    - Two reproduction lines added.
    - `docs/NP_00_INDEX.md` row 14 now reads C1–C42.
11. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **"Two fighters per side in ring simultaneously"** is two engagements under one bell (command 8). Pair A is the first card against the boss asked for; pair B is his partner against the enemy's second (the boss list's next). Each engagement holds the pair on its card, so "adjacent" is side by side in the ring and Adjacent Trust is live in both.
    - (b) **One team, one meter (NP_05 §1):** one team bar, one enemy bar and one crowd. Each engagement's change is summed and written back.
    - (c) **One bell:** the ring clock is the lowest of the pairs still fighting. A pair's own hitstop or count never stops it.
    - (d) **A KO** finishes that pair, which stands scored. The other fights on to the bell, and the pad passes to the pair still fighting.
    - (e) **The verdict:** NP_01 §3.3's ladder on the pairs' sums (score, segment wins, counter hits). A tie is a DRAW, with no Golden DROP at a festival (`sudden_death` false).
    - (f) **The pay:** once, as a dual (NP_11 §6). Both fighters get the closing XP; the pair's adjacent Kizuna, Spirits and HBP are paid once. The recruitment flags and the Gym Wall's poster come from pair A's club.
    - (g) **"Both players input the motion within 500 ms":**
      - the motion is the family's (LB + the uppercut flick for RISE, Double Overtime; LB + block held 400 ms for WALL, Two-Hand Winter), taken from the library's two `sync_500ms` moves by the format's `sync_ms`;
      - the first motion opens a 500 ms window, and the other's same motion inside it casts the move in both engagements;
      - the duo's motions are throws, not arm feints.
    - (h) **"Both players":** one pad. The partner on his profile answers at 250 ms (a first draft); a second pair of hands is `step_pair`'s other input (the tests').
    - (i) **Unanswered,** the held motion executes as it would have: the flick as his own the next tick, the WALL as his own at once.
    - (j) **The price:**
      - the caller's, once, NP_06 §2.1's element edge included;
      - each half carries half of it for an interrupt's refund;
      - live at Lv4 Duo (`exhibition_duo`, NP_08 §5.2's "2v2 exhibition duo hissatsu").
    - (k) **The bar is the pair's call.** Both hold it while a window is open. A profile holds it at 90 while the duo can be made (its own hissatsu waits), so an AI partner leaves the call to the pad.
    - (l) **Manager mode:** the profiles call it at 90. Two-Hand Winter goes when either of the pair is below half his composure; otherwise Double Overtime goes once both are inside the uppercut's reach (+0.55 m for the cast's reach and the windup's lunge).
    - (m) **"The only shared gauge in the game":**
      - Two-Hand Winter is one wall dictionary behind both fighters;
      - the first half resolved raises it (that fighter's rings; pair A on a same-tick resolve), and the other's hands join it;
      - its TRUE OPEN runs on its owner's clock, handed to the other pair if the owner is finished.
    - (n) **The festival moves carry no afterimage:** the partner is in the ring.
12. **Editorial, to confirm or overrule:**
    - The format keys (`simultaneous`, `sync_ms`, `partner_answer_ms`, `manager_duo_bar`) and the values 250 and 90.
    - `-- pair=` and `\`.
    - The greybox's halves (the lateral ×0.5, ±1.75 m).
    - The duo's gilding, the toasts' and the verdict's wording ("… WINS THE EXHIBITION").
    - The pad passing to the pair still fighting.
    - The demo aid (the bar topped up at ticks 600 and 2,400 once both pairs fight).
    - Keys the exhibition refuses (the boss switch, the bouts, Shift+F5).
    - To reverse the numbers, edit the format's record.
13. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-088 row (CSV-ready, todo columns)
ID: PAC-088 | Title: The Exhibition 2v2 (NP_01 s8, NP_05 s7) — two a side in the ring, the duo hissatsu on a 500 ms sync | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The Exhibition 2v2 as a format (one segment, two fighters a side in the ring simultaneously). The sim's second fighter on each side: position, targeting, the partner's state. The duo hissatsu: a Duo pair's festival move (the library's sync_500ms moves: Double Overtime, Two-Hand Winter) cast when both input its motion within 500 ms, the duo wall's shared gauge. The enemy pair's side. Gates cover the format, the sync window each way, the shared wall and a delegated partner. Determinism runs with an exhibition in the log.
BlockedBy: PAC-087 | DependencyType: soft | RelatedWork: NP_01 s3.3 s8; NP_05 s1 s7 s8; NP_08 s5.2; NP_10 s7 s8; NP_11 s6; NP_14 C6 C15 C16 C34 C42; data/formats.v1.json; data/economy.v1.json; data/hissatsu_library.v2.json
Notes: 2026-09-24: SMOKE 376/376 GREEN x 24 bosses (9,024 assertions; +5). DETERMINISM 42/42 (the Exhibition 2v2 on the delegated log in the manager's seat, RORY and PRIYA at Duo vs Yuri and Moreau, the bar topped up at 600: the profiles call Double Overtime, both halves cast it, the exhibition runs to its verdict; identical twice, different from the same log at Adjacent Trust; the 41 earlier lines figure for figure as before). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: the exhibition drive 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7. Soaks (16,000 frames, the manager's seat, two runs each, zero script errors): vs Yuri and Moreau at Duo, Double Overtime and Two-Hand Winter in both runs, the shared gauge linked in both, 2 and 1 exhibitions to their verdict; YURI and MARTA Sworn vs Carter and Chiamaka, two duo syncs a run, 2 and 1 verdicts; at Adjacent Trust vs Vasile and Itzel, no duo sync (Lv3), Vasile's Zone in pair A in both, a verdict in each. The model is two engagements under one bell, not a four-body ring (command 8, the effort named). No older gate moved.
LearningNotes: The first cut stripped LB from the input on the tick of the call, and the sim read the missing LB as an arm feint: −2 Tension and a punish hook's sensor. The drive's bar came up 2 short, twice, before the cause showed. Now the duo's motions leave LB up and mark the throw after the step, since an LB rising that same tick resets the sim's own mark. The first probe also had the AI partner spend the full bar on its own hissatsu on the tick the window opened, so the duo never went. That is where "the bar is the pair's call" (canon read k) came from.
StartedAt: 2026-09-24T10:25:58Z | DoneAt: 2026-09-24T11:29:08Z

## PAC-089 row (CSV-ready, todo columns)
ID: PAC-089 | Title: Club facilities (NP_10 s7) — the gym progression tree on the sim's ledgers | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The facilities as data: five tracks (Bags & Mitts, The Ring, Film Room, The Wall, Front of House), T1 → T3 each, each tier's price in story flags + HBP + Spirits from the reward ledger, the levels on the ledger and in the save. Each tier's effect live on the sim: Bags & Mitts' training minigame tiers and its Beans yield (+25/50 %, the Forge's purse earned at last); The Ring's spar modifiers, the Exhibition 2v2's hosting (C42's format gated by it) and the ranked spar board; the Film Room's Scout Book capacity, PI grind rate and decoy detection assist; The Wall's bond board slots, decoration sets and Forge hosting (C41's Forge gated by it); Front of House's entrance, crowd heat base and Prestige from hosted duals. Gates cover each track's tiers and effects, the price refused short, and the save. Determinism runs with a facility tier in the log.
BlockedBy: PAC-088 | DependencyType: soft | RelatedWork: NP_10 s7; NP_11 s6 s7 s9; NP_08 s6 s7; NP_02 s3; NP_01 s1 s8; NP_14 C18 C22 C23 C28 C33 C41 C42
Notes: The renovation's art (the Old Gym coming back to life) and the Arc 3 televised dual are presentation and story; the greybox names the tier on the HUD.
