# REGISTER COMMANDS 050 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-101 District rep (greybox v6, NP_14 C55)**
Same rule as 001–049: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-101 Status DONE** (the row payload below replaces the TODO row from 049).
2. **Add PAC-102** (row below), Status TODO: NP_12 s2's anti-you.
   - "Director Vey, Toronto Ascendant Academy ... recruits YOUR beaten rivals between arcs - the anti-you".
   - The club's passed-over and released recruits (PAC-100: "anything the released card does while away" is not built) turn up in the academy's squad.

   Alternatives: NP_08 s2.4's circuit placements with the Prestige want at ship content (command 9); NP_02 s4's vendor tiers by district rep.
3. **Update DATA row** `data/economy.v1.json` (both copies): `rep` (a scrap won's 1, the flee's 1, the milestones 3 / 10 / 25 paying 1 / 1 / 2 Prestige, the district aliases); the notes' "since PAC-101" sentence.
4. **Update DATA row** `data/recruits.v1.json` (both copies): the grammar's REP owner "sim", with its text; the notes' "since PAC-101".
5. **Update DATA row** `data/faucets.v1.json` (both copies): each phase's `districts` (school and centre; rink and harbour; hill and downtown); the pace text's "since PAC-101".
6. **Link PAC-101** to these rows:
   - **MODULE `sim/core.gd`:**
     - the rep's block: `rep_key`, `rep_of`, `_rep_add`, `flee_why`, `flee`, `rep_lines`;
     - `start_scrap`'s district; `_pay_bout`'s rep after the scrap's toast;
     - `_clause_state`'s REP; the step's `flee` input.
   - **MODULE `sim/faucets.gd`:** `pay_bout`'s district, the phases' districts in turn, the rep and its milestones reported.
   - **MODULE `main.gd`:**
     - `-- district=`; BACKSPACE;
     - the head's district and rep; the OVER screen's DISTRICT REP line;
     - the REP and FLED toasts; the soak's rep summary; the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate; the gates moved in command 8) and the new `engine/greybox/tools/drive_rep.gd`.
7. **Add TEST row** `engine/greybox/tools/drive_rep.gd` (TEST, "district rep on the real scene, headless:
   - the scrap's district on the head;
   - a scrap won (REP, the DISTRICT REP line);
   - Carter approached on REP(rink_district, 3);
   - three won, the milestone and Carter ready;
   - BACKSPACE mid-scrap (-1); refused after.

   6/6").
8. **Gates moved — flag for @heat.**
   - **C29's recruitment-as-data gate:** the sim reads seven forms and the overworld four (REP moved to the sim).
   - **C51's phase arithmetic:** Prestige includes the phase's rep milestones (Arc 1's club phase 135 -> 139).
   - **Printed only:**
     - C51's verdict report at 18 lines (was 17);
     - C53's bench gate at 1,184 vs 1,160 (was 1,164 vs 1,140);
     - C51's reduced determinism line at 139;
     - the content stamp.
   - No drive moved.
9. **FINDING — flag for @heat.** Prestige stands at 85 % of its want (84.6 %, 14.8 a session): the band's edge.
   - NP_08 s2.4's third source, circuit placements, cannot be paid at story pace without leaving the band.
   - The want would have to grow with the content (NP_08 s9's 60 named at ship against the recruit table's 13), or the scrap's Prestige be read lower. The scrap table's own line is t1 = 1, t2 = 2, t3 = 3, against C22's formula of 2 / 3 / 3, which follows NP_12A's "+2 Prestige".
10. **Note NP_14:**
    - C55 added (5 gates, rep on the delegated log, the rep drive, the finding).
    - C17's, C29's and C52's not-claimed lines say "since C55".
    - A new not-claimed bullet names what C55 does not build, and its readings.
    - Two reproduction lines added.
    - `docs/NP_00_INDEX.md` row 14 now reads C1–C55.
11. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
    - (a) **"Mid-scrap flee costs small district rep (-1)"** as after the first exchange (the fight's first tick): a point, never under 0. Before it, fleeing is free (NP_02 s2.1's "pre-engagement freely").
    - (b) **A scrap won** as +1 in its district. The docs name the flee's cost and not the gain.
    - (c) **"District rep milestones"** as three thresholds, each paid once. The Prestige is sized to NP_11 s6's shared "5-15 (scraps, rep)" a session, of which a story-pace session's scraps already pay 13.5.
    - (d) **REP(district, n)** as the ledger's rep under the docs' names (`rink_district`, `the_hill` by alias). A seeded flag still counts.
    - (e) **The story-pace scraps' districts** by phase: Ep1's (NP_12A: Millbrook Secondary, the community centre), the circuit's questlines' (the Rink District, the harbour), Arc 2's (the Hill, downtown), in turn.
12. **Editorial, to confirm or overrule:**
    - the +1 a scrap;
    - the milestones 3 / 10 / 25 and their 1 / 1 / 2 Prestige;
    - a scrap placed nowhere moving no rep;
    - the flee's key (BACKSPACE);
    - the districts per phase.

    To reverse the rules, edit `economy.v1.json`'s `rep` and `faucets.v1.json`'s phases.
13. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-101 row (CSV-ready, todo columns)
ID: PAC-101 | Title: District rep (NP_02 s2, NP_08 s2.2 / s2.4): REP() off the ledger, the flee's cost, the milestones' Prestige | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: district rep on the sim's ledgers.
- **Rep:**
  - a scrap won in a district raises its rep;
  - NP_02 s2's mid-scrap flee costs 1;
  - NP_08 s2.2's REP(district, n) reads the ledger instead of a seeded flag (Carter Okafor's rink district, the Whitecloud blessing's Hill).
- **Milestones:** NP_08 s2.4's "district rep milestones" pay Prestige. A scout's district may read its rep (PAC-099's scout).
- **The faucet audit:** the milestones counted at story pace, the Prestige share re-read.
- **Gates:** each against its absence; the flee's cost; REP() met on the ledger; the save; determinism with rep in the log.

The build reads two DoD lines as follows. The flee was not built before, so it is built here (NP_02 s2.1: free before the first exchange). The scout's rep ("may read") is left out and named not-claimed in NP_14: the scout pays the district's Prestige as PAC-099 built it.
BlockedBy: PAC-100 | DependencyType: soft | RelatedWork: NP_02 s1.1 s2.1 s4; NP_08 s2.2 s2.4; NP_07A; NP_11 s6; NP_12A; NP_14 C17 C22 C29 C51 C52 C53 C55; data/economy.v1.json; data/recruits.v1.json; data/faucets.v1.json
Notes: 2026-09-26: SMOKE 444/444 GREEN x 24 bosses (10,656 assertions; +5; the diff against PAC-100 identical on every boss - the new gates, the gates moved in command 8, the content stamp). DETERMINISM 55/55 (SCR-15 on the profile in the Rink District: won 6, fled 4, placed nowhere 5; each identical twice, the three different; C51's reduced line at 139). GEOMETRY 5/5, line for line PAC-100's. -- faucets GREEN (exit 0): the milestones 20 Prestige, Prestige 1,184 (85 %, 14.8 a session) - the finding in command 9. -- audit GREEN (3 of 3), its lines PAC-100's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: rep 6/6 (new), locker 10/10, roles 8/8, scouting 8/8, gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing. Soaks, zero script errors: -- demo boss=1 scrap=SCR-15 district=rink (23 won in the rink, two milestones), demo locker, demo roles, demo scouting, demo gear boss=1, demo hybrid, demo mirror, demo growth (22 steps on this run's clock seed; a fixed-seed A/B against PAC-100's code matched at 29 each, the same score and summary).
LearningNotes: The Prestige band ran out before the mechanism did. At story pace a session's scraps already pay 13.5 of NP_11 s6's 5-15, which canon shares between scraps and rep, so the milestones had room for about 26 Prestige over the playthrough; they pay 20. The audit now names what the next source costs (command 9) rather than letting circuit placements land silently. Two ordering bugs fell out of the gates. The scrap's pay rose the rep before its own toast, so the REP toast was overwritten; and _end_bout checked the recruits before the pay moved the rep, so Carter's REP(rink_district, 3) went unnoticed until the next check. The rep now moves after the toast and re-checks the recruits itself. The profile's scrap in the old determinism gate always fails (a DROP), so the rep gate needed an objective the profile wins on its seed, found by probe (SCR-15). The flee had to pass through delegation: it is the player's choice, like the corner keys, not the card's.
StartedAt: 2026-09-26T08:36:56Z | DoneAt: 2026-09-26T10:12:14Z

## PAC-102 row (CSV-ready, todo columns)
ID: PAC-102 | Title: The anti-you (NP_12 s2): the academy recruits the club's beaten rivals between arcs | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_12 s2's Director Vey on the sim - "recruits YOUR beaten rivals between arcs - the anti-you".
- **The academy's recruiting:**
  - between arcs (a story flag), the academy signs the club's beaten rivals it did not recruit - the approachable left waiting, the released (PAC-100) - by the table's order and cap;
  - each fields in the academy's squad with the syntheses C46 gives it;
  - a recruit so taken leaves the club's reach until the academy is beaten (NP_07 s10's Arc 3 thesis).
- **The club's side:** the RECRUITS and String Wall lines name who went to the academy; the grudge/warmth of a released card reads on its new side.
- **Gates:**
  - the recruiting against its absence;
  - a recruited card out of the academy's reach;
  - the academy's squad with the taken;
  - the save;
  - determinism with the arc's turn in the log.
BlockedBy: PAC-101 | DependencyType: soft | RelatedWork: NP_12 s2 s4; NP_07 s10; NP_04A s8; NP_08 s2.1 s4; NP_14 C29 C46 C54; data/academy.v1.json; data/recruits.v1.json
Notes: Alternatives for PAC-102: NP_08 s2.4's circuit placements with the Prestige want at ship content; NP_02 s4's vendor tiers by district rep.
