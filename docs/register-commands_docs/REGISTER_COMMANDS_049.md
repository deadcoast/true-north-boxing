# REGISTER COMMANDS 049 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-100 The locker room (greybox v6, NP_14 C54)**
Same rule as 001–048: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-100 Status DONE** (the row payload below replaces the TODO row from 048).
2. **Add PAC-101** (row below), Status TODO: district rep.
   - NP_02 s2: "mid-scrap flee costs small district rep (-1) - rep gates some recruit conditions".
   - NP_08 s2.2's REP(district, n) and s2.4's "district rep milestones" paying Prestige.
   - On the sim, REP() can only be met with a seeded flag (Carter Okafor's REP(rink_district, 3), the Whitecloud blessing's REP(the_hill, 3)), and nothing pays a milestone.

   Alternative: the academy recruiting the club's beaten rivals between arcs (NP_12's "the anti-you").
3. **Update DATA row** `data/economy.v1.json` (both copies): `locker` (the three days, the story's four kept, the flag's Kizuna Lv1, the five browse orders); the notes' "since PAC-100" sentence.
4. **Link PAC-100** to these rows:
   - **MODULE `sim/core.gd`:**
     - the locker's block: `_road_back`, `release_flag`, `release_why`, `release_pick`, `release`, `take_back_why`, `take_back`, `_releases_settle`, `home_district_of_card`, `memory_of`, `card_view`, `locker_browse`, `locker_lines`;
     - `new_day` settles the releases;
     - `approach` refuses a card waiting on a release;
     - `recruit` refuses at the cap, brings a released card back as it left and keeps the memory;
     - `recruit_view`'s warmth / grudge clause;
     - `_sign_price` and the open mat's line;
     - the OVER inputs `release` and `take_back`.
   - **MODULE `sim/save.gd`:** the Fighter record's `memory`.
   - **MODULE `main.gd`:**
     - DUAL OVER's LOCKER ROOM lines; the keys 8, 9, 0 and Shift+0;
     - the RELEASED, TAKEN BACK and GONE toasts;
     - `-- demo locker`, the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (6 smoke gates, 1 determinism gate) and the new `engine/greybox/tools/drive_locker.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_locker.gd` (TEST, "the locker room on the real scene, headless:
   - the LOCKER ROOM lines and RORY's comparison card; 0 on RORY refused;
   - three generics signed;
   - 8 to the browse by slot-role, 9 to the next card;
   - 0 released and Shift+0 taken back; 0 again and three days to GONE, the grudge on the open mat;
   - Shift+0 refused; F5 with the release standing.

   10/10").
6. **Gates moved — flag for @heat.** None. The content stamp is the only older line that moved (the table changed); every other smoke, determinism and geometry line is PAC-099's.
7. **Note NP_14:**
   - C54 added (6 gates, the locker on the delegated log, the locker drive).
   - C29's and C53's not-claimed lines say "since C54".
   - A new not-claimed bullet names what C54 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C54.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"Rare"** as the design's expectation, not a limit: the grudge is its cost.
   - (b) **"Reversible for 3 in-game days"** as undoable until the third day turns (released on day 1, the release stands when day 4 begins). The undo restores the card, role, gear and wall, and leaves no memory.
   - (c) **"Remember (a small grudge/warmth flag)"**:
     - warmth when the card leaves a bond behind (Kizuna Lv1 or more with a stablemate who stays), else a grudge;
     - NP_08 s5's bond web is what the card remembers the club by.
   - (d) **"Return to their district, remain re-recruitable":**
     - a recruit is approachable again through its condition. Warmth waives the condition; a grudge adds a spar won against the card since the release.
     - a generic goes back on the open mat: warmth signs free any day, a grudge costs the priority even on an open-mat day.
     - A returning card comes back as it left.
   - (e) **"Frees cap space"** as NP_08 s1's 100 enforced on a recruit's answer too (the open mat enforced it since PAC-098).
9. **Editorial, to confirm or overrule:**
   - the story's four never released (the captain by NP_02 s1.1's "captain always slotted"; PRIYA, MARCUS and JUNE because NP_12A's scenes need them);
   - the Kizuna Lv1 line for warmth; the grudge's one spar; the grudge's priority;
   - the gear going back to the club's locker;
   - the aid's release pick (the bench's last).

   To reverse the rules, edit `economy.v1.json`'s `locker`.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-100 row (CSV-ready, todo columns)
ID: PAC-100 | Title: The locker room (NP_08 s4): the release and its undo, the stable's cap given its valve | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_08 s4 on the sim - "Release (rare, reversible for 3 in-game days) frees cap space - released characters return to their district, remain re-recruitable, and remember (a small grudge/warmth flag; people aren't cartridges)".
- **The release:**
  - a stable card released between duals: the place freed, the role cleared, the ledgers kept;
  - reversible for three days (the calendar's `new_day`), then back in the district;
  - a named recruit re-recruitable through the condition, a generic back on the open mat;
  - the grudge/warmth flag on the record, read by the card's return.
- **The locker room:** browse by slot-role, House, Style and Element (NP_08 s4), as DUAL OVER lines and the aid's pick.
- **Gates:**
  - the release against its absence;
  - the undo inside three days and refused after;
  - the cap reached, then a place freed;
  - the flag through the save;
  - determinism with a release in the log.

Two DoD lines read wider in the build: the browse also runs by the bond web (NP_08 s4's fifth order), and the comparison card is built (NP_08 s4: stats, techniques, trait, dialect, bond lines).
BlockedBy: PAC-099 | DependencyType: soft | RelatedWork: NP_08 s1 s2.1 s2.4 s4 s5; NP_02 s1.1; NP_07 s4; NP_11 s9; NP_12A; NP_14 C29 C52 C53 C54; data/economy.v1.json; data/recruits.v1.json
Notes: 2026-09-26: SMOKE 439/439 GREEN x 24 bosses (10,536 assertions; +6; the diff against PAC-099 identical on every boss - the new gates and the content stamp). DETERMINISM 54/54 (the locker on the delegated log: a release waiting by day 2, the stable 6 against 7; identical twice, different without the releases; every older line PAC-099's). GEOMETRY 5/5, line for line PAC-099's. -- faucets GREEN and -- audit GREEN, every line PAC-099's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: locker 10/10 (new), roles 8/8, scouting 8/8, gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing. Soaks, zero script errors: -- demo locker (two released with grudges, one gone to the open mat by day 5), demo roles, demo scouting, demo growth (29 steps), demo gear boss=1, demo hybrid, demo mirror.
LearningNotes: A recruit's state was read off the stable ("joined" while the card is in it), so a card leaving the stable read as never met and turned up in the machine's rare pool. A "released" state closes that until the release stands. The undo had to restore the ledgers the release touched (the role, the gear, the wall, the recruit record) and drop the memory, or taking a card back would still leave a grudge. Recruits from the story's own lineup were never beaten, so a grudging return asks for their club beaten as well as the spar; warmth waives both. That is the table's condition read honestly. The locker demo sees only a day or two per 60,000 ticks at a day per dual, so it turns a day on each visit between duals, and a release settles inside the soak.
StartedAt: 2026-09-26T06:58:25Z | DoneAt: 2026-09-26T08:18:58Z

## PAC-101 row (CSV-ready, todo columns)
ID: PAC-101 | Title: District rep (NP_02 s2, NP_08 s2.2 / s2.4): REP() off the ledger, the flee's cost, the milestones' Prestige | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: district rep on the sim's ledgers.
- **Rep:**
  - a scrap won in a district raises its rep;
  - NP_02 s2's mid-scrap flee costs 1;
  - NP_08 s2.2's REP(district, n) reads the ledger instead of a seeded flag (Carter Okafor's rink district, the Whitecloud blessing's Hill).
- **Milestones:** NP_08 s2.4's "district rep milestones" pay Prestige. A scout's district may read its rep (PAC-099's scout).
- **The faucet audit:** the milestones counted at story pace, the Prestige share re-read.
- **Gates:** each against its absence; the flee's cost; REP() met on the ledger; the save; determinism with rep in the log.
BlockedBy: PAC-100 | DependencyType: soft | RelatedWork: NP_02 s1.1 s2; NP_08 s2.2 s2.4; NP_11 s6; NP_14 C17 C22 C29 C51 C53; data/scrap_objectives.v1.json; data/recruits.v1.json; data/economy.v1.json; data/faucets.v1.json
Notes: Alternative for PAC-101: the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
