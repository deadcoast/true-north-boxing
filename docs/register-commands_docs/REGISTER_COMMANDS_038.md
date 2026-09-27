# REGISTER COMMANDS 038 — for the applying writer
**From: @claude · 2026-09-24 · Re: PAC-089 Club facilities (greybox v6, NP_14 C43)**
Same rule as 001–037: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-089 Status DONE** (the row payload below replaces the TODO row from 037).
2. **Add PAC-090** (row below), Status TODO: the fighter's growth on the ledgers (NP_11 §3, §6).
   - The ability boards: the hex-node board per style archetype, its three lobes and spine, the passive pool, the Boxer-Puncher off-style socket, the named characters' injected nodes, and respec at the Film Room's T2 (C43 built the tier; nothing reads it yet).
   - The Beans' own sink, the stat raises (+1 = 5 Beans, scaling), on the typed Beans NP_11 §7 describes. C43's jar is one number, and each game's bias is only carried as data.
   - Rarity ascension on Spirits (10/25/60).

   Alternative: the Toronto academy's industrialized hybrids as Arc 3's thesis mechanic (NP_07 §10).
3. **Add DATA row** `data/facilities.v1.json` (DATA, "NP_10 s7's club facilities as the sim reads them: five tracks T1 -> T3 from T0 as found; a tier's price and story gate (150 HBP / 5 Spirits behind story:charter_saved, 400 / 15 behind quest:gym_funding, 800 / 30 behind story:nationals); each track's effects in the table's order, one a tier - Bags & Mitts' six training games and yields, The Ring's lab / home exhibition / ranked tiers, the Film Room's shelf (6/12/24/48), grind rungs and tape, The Wall's added columns, honours set and Forge, Front of House's entrance, hosted crowd (20) and hosted Prestige (5)"). Both copies.
4. **Note DATA row** `data/gym_wall.v1.json`. Its summary gains: "the renovation photograph; the honours set's crest (a house's blessing) and feat (a feat on the ledger), hung from The Wall's T2 (PAC-089)." Both copies.
5. **Link PAC-089** to these rows:
   - **MODULE `sim/core.gd`:**
     - `FAC` and `host` through `setup`'s last argument;
     - the tracks: `fac_tier`, `facility_tiers`, `fac_track`, `fac_open` / `fac_has`, `seed_facilities`;
     - the renovation: `renovate_why`, `renovate_ready`, `renovate`, `facility_lines`;
     - the training: `train_why`, `training_best`, `train`, `training_line`;
     - the Scout Book's shelf: `book_pages`, `page_key`, `shelved`, `_book_init`, `_shelve`, `_book_fill` (and `pi_boss`, `_pi_beaten`);
     - the grind and the tape: `_pi_rungs`, `tape_read`, `_tape_record`;
     - the Gym Wall: `_gw_grid`, `_gw_regrid`, `_gw_honour`, `_gw_honours`;
     - the Forge's hosting; `start_spar`'s lab gate and ranked venue;
     - Front of House: `entrance_set`, `_entrance`, `_host_crowd`, `set_host`, `_pay_dual`'s hosted Prestige;
     - the OVER inputs `renovate` / `train`.
   - **MODULE `sim/exhibition.gd`:** `setup`'s `venue` (home at The Ring's T2).
   - **MODULE `sim/save.gd`:** `club.facility_tiers`; the Scout Book's pages are the shelf's.
   - **MODULE `main.gd`:**
     - the Old Gym's DUAL OVER lines, `[1]`–`[5]`, `[T]`;
     - the toasts and the HOSTED marker;
     - `-- facility=`, `-- host=home`, `-- train=`, `-- renovate=`, `-- demo facilities`;
     - the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gates moved in command 8) and the new `engine/greybox/tools/drive_facilities.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_facilities.gd` (TEST, "the club facilities on the real scene, headless: the Old Gym as found (T0, no entrance at the bell); the dual won and THE OLD GYM's lines on DUAL OVER; 1 renovates Bags & Mitts (the toast, the ledger, the photograph); T trains Mitts for 5 Beans; 5, 4, 3 renovate Front of House, The Wall (10 columns) and the Film Room (12 pages); F5's next dual walks out to its music sting. 6/6").
7. **Note TEST row** `engine/greybox/tools/drive_forge.gd`: its command line adds `facility=wall:3` (the Forge is hosted at The Wall's T3). It is a header-comment edit; the drive is unchanged.
8. **Gates moved — flag for @heat.** Each still proves its claim; each moved because C43 gates what it exercises.
   - The content-table gate (C36's statement, PAC-074's gate) lists 25 tables, with `FAC`.
   - The Gym Wall's data gate (C33) lists the three new decoration kinds.
   - The spar's lab gate (C17) and the spar's pay gate (C22, the tell-highlight lab's −50 %) seed The Ring at T1: the lab flags you choose are The Ring's.
   - The five PAC-087 gates (C41) and the hybrid determinism gate seed The Wall at T3: the Forge is hosted there.
   - `tools/drive_forge.gd`'s and the `-- demo hybrid` soaks' command lines add `facility=wall:3`.

   One older determinism figure moved: the save-and-load line's text size, 215 KB to 216 KB (the save carries `club.facility_tiers`). Every other line of the determinism log is figure for figure as before.
9. **Note NP_14:**
   - C43 added (5 gates, the hosted dual on the delegated log, the facilities drive).
   - The not-claimed bullets on Pattern Intel, the reward economy, the staff, the Gym Wall, hybrid research and the exhibition say what C43 now runs.
   - A new not-claimed bullet names what C43 does not build, and its readings.
   - Three reproduction lines edited for the moved gates (the spar's lab, the Forge drive, the hybrid soak) and two added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C43.
10. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **"T1 → T3 effects"**: the effects in the table's listed order, one a tier. A capacity (the Scout Book's pages, the wall's columns, the entrance's pieces, the Beans' yield) grows at every tier after. The club starts every track at T0, the Old Gym as found.
    - (b) **"Facilities upgrade with story + HBP + Spirits"**: one price and one gate a tier across the tracks, between duals or before the first bell.
      - The prices: 150/5, 400/15, 800/30, first drafts against NP_11 §6.
      - The gates: the charter saved, the funding quest, the Nationals (NP_12 §4 beats 2, 5 and 7).
    - (c) **Bags & Mitts, "training minigame tiers":**
      - Roadwork and Net Haul need no gym (The Hill, the harbour); Mitts and the Heavy Bag are T1; NP_11 §7's own T2 and T3 labels are the Slip Bag and Shadow Rounds.
      - "+25/50%" is T2 and T3's yield on every slot. A slot pays lo + the grade's share of (hi − lo); the grade is the minigame's result, input skill = yield.
      - Roadwork with a squad member along bonds at the spar's repeatable rate.
    - (d) **The Ring:**
      - "Spar modifiers unlock" is the lab flags you choose; an authored bout keeps its own.
      - "2v2 exhibition hosting" is the Exhibition 2v2 at home rather than the festival.
      - "Ranked spar board access" is the CRBF Annex's ranked spar as a venue.
    - (e) **The Film Room:**
      - "Scout Book capacity" is the shelf, and the shelf is the page in hand: a page past it waits, and its PI 3 with it (NP_02 §3's "their pattern page").
      - "PI grind rate +" is the scrap and spar rungs sooner.
      - "Decoy detection assist" is the tape of a corner's last decoy seal, read on sight. The tactician's Lv3 read stands beside it.
    - (f) **The Wall:**
      - "Bond board slots" are card columns added to the base wall.
      - "Decoration sets" is the honours set: a blessed house's crest, a feat's plaque, zero stats.
      - "Forge event hosting" means the Forge needs The Wall at T3 ("a Forge event at the gym").
    - (g) **Front of House:**
      - The entrance is the club's walk-out at every dual, with the Reyes bell as its quest's piece.
      - "Crowd heat base +" and "Prestige from hosted duals" apply to a hosted dual only, won or lost.
      - A dual is away unless hosted, as every greybox dual was before.
11. **Editorial, to confirm or overrule:**
    - The table's keys, the flag names `story:charter_saved`, `quest:gym_funding`, `story:nationals`, and the numbers: the prices, the shelf's 6/12/24/48, the grind rungs 2/4 and 1/2, the columns +2/+4, the crowd base 20, the hosted Prestige 5.
    - The six games' ranges and biases as read from NP_11 §7.
    - The tracks' effect texts, the toasts' wording and the photograph's.
    - `[1]`–`[5]` and `[T]` on DUAL OVER, the aid's grade 0.75 and its "best game open".
    - `-- facility=`, `-- host=home`, `-- train=`, `-- renovate=`, `-- demo facilities` (its day turned at each dual's end).
    - To reverse the rules and numbers, edit the table.
12. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-089 row (CSV-ready, todo columns)
ID: PAC-089 | Title: Club facilities (NP_10 s7) — the gym progression tree on the sim's ledgers | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: The facilities as data: five tracks (Bags & Mitts, The Ring, Film Room, The Wall, Front of House), T1 -> T3 each, each tier's price in story flags + HBP + Spirits from the reward ledger, the levels on the ledger and in the save. Each tier's effect live on the sim: Bags & Mitts' training minigame tiers and its Beans yield (+25/50 %, the Forge's purse earned at last); The Ring's spar modifiers, the Exhibition 2v2's hosting (C42's format gated by it) and the ranked spar board; the Film Room's Scout Book capacity, PI grind rate and decoy detection assist; The Wall's bond board slots, decoration sets and Forge hosting (C41's Forge gated by it); Front of House's entrance, crowd heat base and Prestige from hosted duals. Gates cover each track's tiers and effects, the price refused short, and the save. Determinism runs with a facility tier in the log.
BlockedBy: PAC-088 | DependencyType: soft | RelatedWork: NP_10 s7; NP_11 s3 s6 s7 s9; NP_08 s6 s7; NP_02 s2.2 s3; NP_01 s1 s8 s9; NP_07A; NP_12 s4; NP_14 C17 C18 C22 C23 C28 C33 C41 C42 C43; data/facilities.v1.json; data/gym_wall.v1.json
Notes: 2026-09-24: SMOKE 381/381 GREEN x 24 bosses (9,144 assertions; +5). DETERMINISM 43/43 (a hosted dual on the delegated log vs Yuri's squad with every facility at T3: the entrance at each bell, the crowd from 20 at each hosted bell, 5 Prestige from the hosted dual; identical twice, different from the same log away; one older figure moved, the save's size 215 -> 216 KB). GEOMETRY 5/5. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 (on its moved command line). Soaks, zero script errors: -- demo facilities with every gate, a 7000 HBP purse and host=home (60,000 frames, x2) - all fifteen renovations before the bell, two hosted duals to their end, 2 entrances, 10 Prestige, 5 training slots; with two gates and 1500 HBP (x2) - the story holding T3, six renovations, a seventh paid by the duals in one run; the Exhibition 2v2 at home (16,000 frames, x2) - duo syncs, a verdict and 5 hosted Prestige in each; -- demo hybrid on its moved line (x1) - Grain & Snow forged and cast relayed twice. Ten older gates moved (command 8).
LearningNotes: The Gym Wall table already called its grid "the base wall's card cells" and already had an unpinned list for a wall with no free cell. The Wall's tiers slotted in as columns added to that base, and the stable that outgrows it waits in that list. My first cut replaced the base with the tier's own width, and an older gate that shrinks the wall to 2 cells caught it. Starting the club at T0 moved ten gates. Two are lists that grew (the tables, the decoration kinds). The other eight now seed the tier they exercise, a one-line change for each, and none was rewritten.
StartedAt: 2026-09-24T14:53:35Z | DoneAt: 2026-09-24T16:12:02Z

## PAC-090 row (CSV-ready, todo columns)
ID: PAC-090 | Title: The fighter's growth (NP_11 s3, s6) — ability boards, stat raises on typed Beans, rarity ascension | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The ability boards as data (NP_11 s3): the four style layouts, ~60 hex nodes in three lobes and a shared spine, the stat nodes' tiers and soft-cap breakers, the 40-passive launch pool with its first passives live on the sim (Tight Guard, Snap, Ring Cutter, Iron Jaw, Second Gear, Sparkplug, Cheap Trick, Closer, Wallflower), the Boxer-Puncher off-style socket, 2-4 nodes injected per named character; points from levels; respec free at the gym from the Film Room's T2 (C43). Typed Beans from the training slots (each game's bias, a partner's flavour) and the stat raise (+1 = 5 Beans, scaling). Rarity ascension on Spirits (10/25/60). The save's Fighter.board. Gates cover the boards, each live passive against the same sim without it, the raises and their scaling, the ascension, respec and the save; determinism with a board in the log.
BlockedBy: PAC-089 | DependencyType: soft | RelatedWork: NP_11 s1 s3 s4 s6 s7 s9; NP_06 s1.2; NP_10 s7; NP_14 C22 C23 C43; data/facilities.v1.json; data/economy.v1.json
Notes: The boards' node art and the gear system (NP_11 s5) are presentation and content; the greybox names the nodes.
