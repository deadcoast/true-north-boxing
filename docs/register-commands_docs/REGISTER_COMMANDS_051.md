# REGISTER COMMANDS 051 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-102 The anti-you (greybox v6, NP_14 C56)**
Same rule as 001–050: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-102 Status DONE** (the row payload below replaces the TODO row from 050).
2. **Add PAC-103** (row below), Status TODO: NP_02 s4's vendor tiers by district rep.
   - NP_02 s4 names district rep's sinks as "recruit conditions, vendor tiers". PAC-101 built the first; the shops' shelves (C45's techniques, the gear's shop) still open by the story's flags only.
   - It spends the rep PAC-101 earns and needs no call on the economy's want.

   Alternatives: NP_08 s2.4's circuit placements (050's command 9: Prestige at the band's edge, so the want is read with them); NP_12 s6's Team Canada (the academy absorbed, Vey in the club's corner).
3. **Update DATA row** `data/academy.v1.json` (both copies: `data/`, `engine/greybox/`): `recruiting` (the turns `story:nationals` and `story:hollow_circuit`, 3 a turn, its text); the notes' "since PAC-102" sentence.
4. **Link PAC-102** to these rows:
   - **MODULE `sim/core.gd`:**
     - the anti-you's block: `academy_taken`, `academy_left_behind`, `_academy_recruit`, `_academy_beaten`, `academy_fielded`, `academy_kit`, `academy_lines`;
     - `story_mark` turns the arc; `_recruit_after_dual` gives the academy's rivals back when it is beaten;
     - the enemy lineup's overlay of the fielded rivals; the segment's kit for a fielded rival;
     - `approach`'s academy refusal; `recruit_lines` leads with the academy's; the String Wall's "at the academy";
     - the OVER inputs `story` and `academy`.
   - **MODULE `main.gd`:** the ANTI-YOU and ACADEMY BEATEN toasts; `-- demo anti` (the aid turns the arc once someone is left waiting); the soak's anti summary; the help lines.
   - **TEST rows:** `sim/tests.gd` (5 smoke gates, 1 determinism gate) and the new `engine/greybox/tools/drive_anti.gd`.
5. **Add TEST row** `engine/greybox/tools/drive_anti.gd` (TEST, "the anti-you on the real scene, headless, against Moira's squad:
   - the dual won, four of Moira's club flagged, the RECRUITS lines;
   - the arc turned: the academy signs three - the ANTI-YOU toast, the RECRUITS lines, DEX held with no pattern to field;
   - L: the one left approached, the three out of reach;
   - F5 with the academy fielded: its rivals fight ahead of the prodigies, Vey in the corner, the matchup card's ACADEMY line;
   - the academy beaten: the three come over approachable; L surfaces their conditions.

   6/6").
6. **Gates moved — flag for @heat.** None. The content stamp is the only older line that moved (the academy table changed). Every other smoke, determinism and geometry line is PAC-101's.
7. **Note NP_14:**
   - C56 added (5 gates, the anti-you on the delegated log, the anti drive).
   - C46's and C54's not-claimed lines say "since C56".
   - A new not-claimed bullet names what C56 does not build, and its readings.
   - Two reproduction lines added.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C56.
8. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **"Between arcs"** as the arc's closing story flag landing through `story_mark`: the Nationals (NP_12 s4 beat 7) and the Hollow Circuit's end. A seeded flag is the ledger as it stood and signs nobody.
   - (b) **"YOUR beaten rivals"** as the recruit table's fighters the club flagged (approachable or approached) and never signed, releases that stood included (PAC-100's road back), in the order met, 3 a turn.
   - (c) **The academy's hold** as ending when the academy is beaten in a dual: every rival it holds comes over approachable, its release's grudge / warmth kept. That is NP_12 s6's "absorbed into Team Canada" as far as the ledger goes.
   - (d) **A signed rival fielded** on its own pattern with the displaced prodigy's syntheses (NP_07 s10's synthesis without bonds). A signed recruit with no pattern of its own (Dex's card) is held, not fielded.
9. **Editorial, to confirm or overrule:**
   - `story:hollow_circuit` as Arc 2's turn flag (the overworld would set it; the greybox plays no such beat);
   - the 3 a turn;
   - the displaced prodigy's kit rather than the rival's own.

   To reverse the rules, edit `academy.v1.json`'s `recruiting`.
10. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-102 row (CSV-ready, todo columns)
ID: PAC-102 | Title: The anti-you (NP_12 s2): the academy recruits the club's beaten rivals between arcs | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
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

The build reads one DoD line as follows. "Out of the academy's reach" is read as out of the club's reach while the academy holds the card: the approach is refused, the machine never deals it, a later win never flags it again.
BlockedBy: PAC-101 | DependencyType: soft | RelatedWork: NP_12 s2 s4 s6 s7; NP_07 s10; NP_08 s2.1 s4; NP_14 C29 C46 C52 C54 C56; data/academy.v1.json; data/recruits.v1.json
Notes: 2026-09-26: SMOKE 449/449 GREEN x 24 bosses (10,776 assertions; +5; the diff against PAC-101 identical on every boss - the new gates and the content stamp). DETERMINISM 56/56 (the anti-you on the delegated log vs Moira's squad: the academy signs MOIRA, DEX and REMY at the Nationals and is fielded; identical twice, different without the arc's turn; every older line PAC-101's). GEOMETRY 5/5, line for line PAC-101's. -- faucets GREEN and -- audit GREEN, every line PAC-101's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: anti 6/6 (new), rep 6/6, locker 10/10, roles 8/8, scouting 8/8, gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing. Soaks, zero script errors: -- demo anti boss=19 at level 20 (the second dual won flags four, the academy signs three and is fielded, the club loses the third dual to it), demo boss=1 scrap=SCR-15 district=rink, demo locker, demo roles, demo scouting, demo gear boss=1, demo hybrid, demo mirror, demo growth (29 steps on this run's clock seed).
LearningNotes: The save sorts a dictionary's keys, so the academy's signing order came back alphabetical after a load: the ledger keeps an explicit order list beside the taken map. A signed recruit without a pattern of its own (Dex's card) broke the kit's index, because the displaced prodigy was counted over every signing: the kit now indexes the fielded list, and the card is held and says so. The first determinism draft ran against Yuri's squad, lost the dual and signed nobody, so the gate moved to Moira's squad, where the log wins. The first soak turned the arc at its first OVER before any dual was won and spent the turn on nobody, which is the rule working, not the soak: the demo's aid now turns the arc only once someone is left waiting, and runs at level 20 so a dual is won inside the soak's window.
StartedAt: 2026-09-26T10:53:55Z | DoneAt: 2026-09-26T12:37:21Z

## PAC-103 row (CSV-ready, todo columns)
ID: PAC-103 | Title: Vendor tiers (NP_02 s4): the shops' shelves by district rep | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_02 s4's "District rep | Gates | Recruit conditions, vendor tiers" on the sim's shops.
- **The shelves:** each shop (the techniques' shelves, C45; the gear's shop, C48) sits in a district, and a tier opens by that district's rep as well as its story flag, by the table.
- **The club's side:** the shop's lines name the rep a closed tier wants; the REP toast names a tier it opens.
- **The faucet audit:** the tiers opened at story pace re-read against the HBP sinks.
- **Gates:** the tiers against their absence; a tier opened on the ledger's rep and closed below it; the save; determinism with a rep-opened purchase in the log.
BlockedBy: PAC-102 | DependencyType: soft | RelatedWork: NP_02 s4; NP_08 s2.4; NP_11 s6; NP_14 C45 C48 C55; data/techniques.v1.json; data/gear.v1.json; data/economy.v1.json
Notes: Alternatives for PAC-103: NP_08 s2.4's circuit placements with the Prestige want at ship content; NP_12 s6's Team Canada.
