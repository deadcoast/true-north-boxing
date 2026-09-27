# REGISTER COMMANDS 052 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-103 Vendor tiers (greybox v6, NP_14 C57)**
Same rule as 001–051: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-103 Status DONE** (the row payload below replaces the TODO row from 051).
2. **Add PAC-104** (row below), Status TODO: NP_12 s6's Team Canada.
   - "Team Canada assembled from every rival fought: the parade of Arc 1–2 bosses in one locker room, feud graph and all ... strongest version, with Vey's academy absorbed into Team Canada and the thesis argued from inside the same corner."
   - Since PAC-102 the academy beaten gives its rivals back approachable. The absorption, the national roster and Vey in the club's corner are not built.

   Alternatives: NP_08 s2.4's circuit placements (050's command 9: Prestige at the band's edge, so the want is read with them); rep from more than scraps (C55's not-claimed: duals at a venue, district events, quests).
3. **Update DATA row** `data/techniques.v1.json` (both copies: `data/`, `engine/greybox/`): the shop's `district` (downtown) and `text`, t2's `rep` 10 and t3's 25; the notes' "since PAC-103" sentence.
4. **Update DATA row** `data/gear.v1.json` (both copies): the same - the shop's `district` and `text`, t2's `rep` 10 and t3's 25; the notes' "since PAC-103" sentence.
5. **Link PAC-103** to these rows:
   - **MODULE `sim/core.gd`:**
     - the vendor block: `vendor_shop`, `vendor_rep`, `shelf_open_by`, `shelves_open`, `shelf_label`, `shelf_rep_clause`, `vendor_lines`;
     - `shop_open` and `gear_shelf_open` read the vendor tiers; their refusals name the rep;
     - `_rep_add` names the shelves a move opened or closed on the rep's event and returns them; `flee`'s event names those closed;
     - `seed_rep`.
   - **MODULE `sim/faucets.gd`:** each shelf's first phase open and its key (flag or rep), the shops' district rep by phase; the report's vendor line.
   - **MODULE `main.gd`:** `-- rep=`; DUAL OVER's SHOPS lines; the REP and FLED toasts' shelves; `-- demo vendors` and the soak's vendors summary; the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gates moved in command 7) and the new `engine/greybox/tools/drive_vendors.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_vendors.gd` (TEST, "the vendor tiers on the real scene, headless:
   - a scrap on the Downtown Strip at rep 9, both t2 shelves shut;
   - won: DOWNTOWN 10 - the REP toast names the shelves opened, the SHOPS lines read them open by the rep;
   - \ buys the gear shop's pick off t2; [ the technique shop's;
   - BACKSPACE mid-scrap: 9, the FLED toast names the shelves closed, the bought kept; \ buys off t1;
   - F5, won: open again.

   7/7").
7. **Gates moved — flag for @heat.**
   - **C45's shop gate and C48's sources gate:** the t2 and t3 refusals now end with the rep clause ("or DOWNTOWN rep 10 (0 now)"); their assertions carry it. Nothing else in either gate moved.
   - **Printed only:** C51's verdict report at 19 lines (was 18); the content stamp.
   - No drive moved.
8. **Note NP_14:**
   - C57 added (5 gates, the vendor tiers on the log, the vendors drive).
   - C45's shop reading and C55's not-claimed line say "since C57".
   - A new not-claimed bullet names what C57 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C57.
9. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"District rep | Gates | ... vendor tiers"** as a second key to a shelf the story already opens: the rep opens it early and never shuts one the story opened. The older flag gates stand as they were.
   - (b) **The shops' district** as the Downtown Strip (NP_02 s1.1: "Shops (HBP spending)").
   - (c) **The rep as it stands**, not its best: a flee below the line shuts the shelf until a win brings the rep back. What was bought stays bought.
   - (d) **A seeded rep flag** counting as REP() counts it (C55).
10. **Editorial, to confirm or overrule:**
    - the thresholds 10 and 25 (on the rep milestones);
    - both shops in the one district;
    - no price change by rep.

    To reverse the rules, edit the `shop` blocks of `techniques.v1.json` and `gear.v1.json`.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-103 row (CSV-ready, todo columns)
ID: PAC-103 | Title: Vendor tiers (NP_02 s4): the shops' shelves by district rep | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_02 s4's "District rep | Gates | Recruit conditions, vendor tiers" on the sim's shops.
- **The shelves:** each shop (the techniques' shelves, C45; the gear's shop, C48) sits in a district, and a tier opens by that district's rep as well as its story flag, by the table.
- **The club's side:** the shop's lines name the rep a closed tier wants; the REP toast names a tier it opens.
- **The faucet audit:** the tiers opened at story pace re-read against the HBP sinks.
- **Gates:** the tiers against their absence; a tier opened on the ledger's rep and closed below it; the save; determinism with a rep-opened purchase in the log.

The build reads the faucet line as follows. The audit's HBP want is priced from the tables, not the hour, so the re-read names when each shelf opens at story pace and by which key; none opens by the rep ahead of the story, and nothing is paid differently.
BlockedBy: PAC-102 | DependencyType: soft | RelatedWork: NP_02 s1.1 s1.3 s4; NP_08 s2.4; NP_11 s6; NP_14 C45 C48 C51 C55 C57; data/techniques.v1.json; data/gear.v1.json; data/economy.v1.json
Notes: 2026-09-26: SMOKE 454/454 GREEN x 24 bosses (10,896 assertions; +5; the diff against PAC-102 identical on every boss - the new gates, the gates moved in command 7, the content stamp). DETERMINISM 57/57 (the vendor tiers on the log: SCR-15 won downtown from 9, the aid's gear off t2 - the Fitted Guard; placed in the rink, off t1; each identical twice, the two different; every older line PAC-102's). GEOMETRY 5/5, line for line PAC-102's. -- faucets GREEN (exit 0): the vendor tiers' line added - all four shelves open by their flags in arc1_circuit, DOWNTOWN 0 / 0 / 90 by phase, none by the rep ahead of the story; every other line PAC-102's. -- audit GREEN, every line PAC-102's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: vendors 7/7 (new), anti 6/6, rep 6/6, locker 10/10, roles 8/8, scouting 8/8, gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing. Soaks, zero script errors: -- demo vendors (from DOWNTOWN 9 to 29: both t2 shelves opened by the first win, Chinook Rush and four Fitted Guards bought off t2, both t3 shelves opened at 25), demo anti (both duals lost on this run's clock seed: the arc held, nobody signed), demo boss=1 scrap=SCR-15 district=rink, demo locker, demo roles, demo scouting, demo gear boss=1, demo hybrid, demo mirror, demo growth (29 steps).
LearningNotes: The faucet audit could not answer the DoD's question as asked: its HBP want is priced from the tables, not the hour, so a shelf opening early moves nothing in it. What it can say is when each shelf opens at story pace and by which key, so it records that per phase. At story pace the circuit's flags open all four shelves before the club ever scraps downtown (Arc 2), so the rep never opens one early; the club phase's scraps moved onto the Strip open all four by the rep (DOWNTOWN 45 there). The shelf reads the rep as it stands rather than its best, which gives the flee's point a second cost. A flee's FLED toast overwrote the REP toast, as PAC-101 found, so the flee's own event names the shelves it closed. The two refusal strings the older gates pinned word for word now carry the rep; their assertions moved with them (command 7). In the vendors soak the gear aid only fills an open slot and never upgrades, so a club that bought t1 before a shelf opened keeps its t1 pieces; the soak starts at 9 so the first win opens t2 before the aid buys.
StartedAt: 2026-09-26T12:57:00Z | DoneAt: 2026-09-26T14:32:00Z

## PAC-104 row (CSV-ready, todo columns)
ID: PAC-104 | Title: Team Canada (NP_12 s6): every rival fought in one locker room, the academy absorbed | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_12 s6's Team Canada on the sim - "assembled from every rival fought ... feud graph and all", the strongest version "with Vey's academy absorbed into Team Canada and the thesis argued from inside the same corner".
- **The roster:** at Arc 3's turn the club's stable and every rival it fought (the recruit table's beaten, the academy's prodigies once it is beaten) become one national squad by the table's rule; the feud graph's edges live inside it (NP_08 s5's bonds and NP_07's feuds).
- **The academy absorbed:** Vey as a corner the club may dress, the syntheses argued from the club's side (C46's kits on the club's cards).
- **The club's side:** the TEAM CANADA lines (who came, from where, the feuds carried in); the String Wall's closing state.
- **Gates:** the roster against its absence; the academy absorbed only once beaten; a feud edge inside the squad; the save; determinism with the national squad on the log.
BlockedBy: PAC-103 | DependencyType: soft | RelatedWork: NP_12 s2 s6; NP_07 s10; NP_08 s4 s5; NP_09 s6; NP_14 C29 C46 C54 C56; data/academy.v1.json; data/recruits.v1.json; data/feud_graph.v1.json
Notes: Alternatives for PAC-104: NP_08 s2.4's circuit placements with the Prestige want at ship content; rep from more than scraps (C55's not-claimed).
