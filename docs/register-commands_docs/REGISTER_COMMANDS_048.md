# REGISTER COMMANDS 048 — for the applying writer
**From: @claude · 2026-09-26 · Re: PAC-099 The stable roles (greybox v6, NP_14 C53)**
Same rule as 001–047: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-099 Status DONE** (the row payload below replaces the TODO row from 047).
2. **Add PAC-100** (row below), Status TODO: NP_08 s4's locker room, the release and its three-day undo.
   - The open mat and the roles can fill the stable to NP_08 s1's cap of 100, and nothing frees a place in it.
   - NP_08 s4 names the valve: "Release (rare, reversible for 3 in-game days) frees cap space - released characters return to their district, remain re-recruitable, and remember".

   Alternatives: district rep (NP_02 s2's flee cost, NP_08 s2.2's REP(), s2.4's rep milestones paying Prestige); or the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
3. **Update DATA row** `data/economy.v1.json` (both copies):
   - `roles`: the training partner's 10 points a Bean and its cap of 3; the scout's district 1 Prestige a day and its 20 on the projection; the cornerman-in-training's 1 use a dual;
   - the home districts: the houseless default (Millbrook Secondary) and twelve Houses' roots on the circuit's districts;
   - the notes' "since PAC-099" sentence.
4. **Update DATA row** `data/faucets.v1.json` (both copies):
   - `pace.bench`: the story-pace bench, three open-mat generics from the circuit, one to each role;
   - the pace text's and the Prestige system line's "since" clauses.
5. **Link PAC-099** to these rows:
   - **MODULE `sim/core.gd`:**
     - the roles' block: `stable_role`, `role_working`, `role_holders`, `home_district`, `district_label`, `partner_bonus`, `partner_pick`, `scout_districts`, `_scouts_pay`, `_trainee_mentor`, `_trainees_feed`, `role_why`, `role_pick`, `assign_role`, `role_back`, `role_text`, `roles_lines`;
     - `train` (the partner along, his bonus), `new_day` (the scouts), `_pay_dual` (the trainees);
     - `_staff_add_use` (shared by a spent charge and a trainee);
     - the projection's scout source; the machine's generic carries its district;
     - the OVER inputs `role` and `day`, and `sign` with a count.
   - **MODULE `sim/save.gd`:** the Fighter record's `stable_role` (the ledger's) and `home_district`; a generic's `district` on the card.
   - **MODULE `sim/faucets.gd`:** the story-pace bench seated from its phase, what the roles paid each phase, the report's bench line.
   - **MODULE `main.gd`:**
     - DUAL OVER's ROLES lines; the keys 7 and Shift+7;
     - the ROLE, THE SCOUTS and THE CORNER toasts, and the training toast's partner;
     - `-- demo roles`, the help lines and the soak's summary.
   - **TEST rows:** `sim/tests.gd` (7 smoke gates, 1 determinism gate) and the new `engine/greybox/tools/drive_roles.gd`.
6. **Add TEST row** `engine/greybox/tools/drive_roles.gd` (TEST, "the stable roles on the real scene, headless:
   - the ROLES lines on an empty bench, 7 refused;
   - seven leads pulled and signed on the open-mat day;
   - 7 eight times - the aid's training partner, five scouts, the cornerman-in-training for the district drawn twice - the eighth refused;
   - T with the partner along (+2 SPD); a day's five districts; F5's dual and the trainee's use; Shift+7 back to the ring.

   8/8").
7. **Gates moved — flag for @heat.** None moved its condition.
   - **Printed only:**
     - C51's verdict gate prints its report at 17 lines (was 16: the bench line);
     - C23's round trip at 16,387 bytes (was 16,255: `home_district` on every record);
     - the content stamp (the tables changed).
   - Every other smoke, determinism and geometry line is PAC-098's.
8. **Note NP_14:**
   - C53 added (7 gates, the roles on the delegated log, the roles drive, `-- faucets` GREEN with the bench).
   - C27's, C28's and C52's not-claimed lines say "since C53"; C52's Prestige share line too.
   - A new not-claimed bullet names what C53 does not build, and its readings.
   - Two reproduction lines added; the `-- faucets` line names the bench.
   - `docs/NP_00_INDEX.md` row 14 now reads C1–C53.
9. **CANON READS — flag for @heat.** Each is the doc's line with a mechanism chosen:
   - (a) **NP_08 s1's "Beans bonus keyed to their stats"** as the partner's lead over the trainee at the game's stat: a Bean per 10 points, typed as that stat.
     - The effect bears on the audit, so it is named here.
     - At story pace the club phase's tier-1 generics lead the captain nowhere, so the faucet's Beans a slot stay at 9.6 against NP_11 s6's 3-10. The band leaves 0.4 a slot of headroom.
     - A partner paid on his own stats alone would break the band. I chose the lead reading on its design (a partner teaches what the trainee lacks, which makes a benched veteran a partner for the rookies), and it also holds the band.
   - (b) **NP_08 s1's "passive Prestige from their home district"** as each covered district paying once a day. NP_10 s3's scout assignment reads its district's clubs' orders (+20).
   - (c) **NP_08 s1's "feeds the staff system"** as staff uses (NP_10 s6: level via use). NP_08 s1 cites "NP_10 s7", which is the facilities; I read it as s6, the staff system.
   - (d) **NP_11 s9's `home_district`:**
     - a House card's is its root (NP_07 s8) on the formation's five circuit districts;
     - a houseless card's is Millbrook Secondary;
     - a generic's is the machine's draw.
   - (e) **The story-pace bench** as three open-mat generics signed from the circuit on (NP_08 s2.4: "for players who want bodies for training roles"), one to each role. The story's own squad is dressed whole.
10. **Editorial, to confirm or overrule:**
    - the 10 points a Bean, the cap of 3, the district's 1 Prestige, the +20, the one use;
    - the roots for Winnipeg, Gatineau, Niagara, Halifax, Red River, Québec City and Northern Ontario;
    - the aid's order (a partner, then a scout per uncovered district, then the corner);
    - the bench's districts and tier, seated at the circuit's start (its first open-mat day falls two days in);
    - a dressed card's role waits rather than lapses.

    To reverse the rules and numbers, edit `economy.v1.json`'s `roles` and `faucets.v1.json`'s `pace.bench`.
11. **PAC-052 (tuning sweeps)** unchanged, still TODO, still proposal-only. **PAC-002B** stays @p1-implementer. NDL-009 untouched.

## PAC-099 row (CSV-ready, todo columns)
ID: PAC-099 | Title: The stable roles (NP_08 s1): training partner, scout, cornerman-in-training | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: NP_08 s1's roles on the sim's ledgers - "any stablemate can be assigned as a training partner (Beans bonus keyed to their stats), scout (passive Prestige from their home district), or cornerman-in-training (feeds the staff system, NP_10 s7)".
- **The roles:**
  - a role set between duals on any stablemate not dressed;
  - the partner's Beans flavour on the training slot (NP_11 s7, C43's partner read);
  - the scout's Prestige by day from their district;
  - the cornerman's feed into the staff corps.
- **The faucet audit:** the scout's Prestige counted in the faucet, the share re-read.
- **Gates:** each role against its absence; a dressed card refused a role; the save; determinism with the roles in the log.

How the build reads three DoD lines, each flagged in command 9:
- The partner's "Beans flavour" is a bonus by his lead over the trainee (a), on top of the quarter's flavour, which is kept.
- The scout also reads his district's clubs on the projection (NP_10 s3).
- The faucet counts all three roles, not the scout's alone.
BlockedBy: PAC-098 | DependencyType: soft | RelatedWork: NP_08 s1 s2.4 s4; NP_10 s3 s6; NP_11 s6 s7 s9; NP_07 s8; NP_02 s1.1; NP_14 C23 C27 C28 C43 C51 C52 C53; data/economy.v1.json; data/faucets.v1.json; data/staff.v1.json; data/formation.v1.json
Notes: 2026-09-26: SMOKE 433/433 GREEN x 24 bosses (10,392 assertions; +7; the diff against PAC-098 identical on every boss - the new gates and the printed-only lines of command 7). DETERMINISM 53/53 (the roles on the delegated log: three signed, a partner and two scouts set, 2 Prestige by day 2; identical twice, different without the roles; every older line PAC-098's). GEOMETRY 5/5, line for line PAC-098's. -- faucets GREEN (exit 0): the bench paid Prestige 24, Beans 0, 42 staff uses; Prestige 83 % (was 81 %), 14.6 a session; the rest unchanged. -- audit GREEN (3 of 3), its lines PAC-098's. MARGINS GREEN. The compiler's selftest 10/10; the 24 sources recompiled byte-identical; sim_test 14/14; the hissatsu audit GREEN. Drives: roles 8/8 (new), scouting 8/8, gear 7/7, mirror 8/8, academy 7/7, techniques 10/10, growth 8/8, facilities 6/6, exhibition 7/7, bzone 7/7, clash 5/5, awaken 6/6, inherit 6/6, manifest 6/6, zone 6/6, formation 12/12, recruit 8/8, duo 6/6, forge 7/7 - no check moved; the printed details that differ are frame timing. Soaks, zero script errors: -- demo roles (seven signed, all three roles, by day 3: 5 Prestige, 2 Beans, 1 staff use), demo scouting, demo growth (29 steps), demo gear boss=1, demo hybrid, demo mirror.
LearningNotes: Every role was a new faucet, and the audit said so before any number was set. The story-pace training slot already paid 9.6 Beans against NP_11 s6's 3-10, so a partner paid on his own stats had no room. Reading "keyed to their stats" as the partner's lead over the trainee is the better design and also holds the band; command 9 names both reasons. The scouts needed a bound for the same reason: a district pays once, however many scouts it has, or the open mat's hundred bodies would print Prestige. The existing seams carried all three roles - the slot, the day's turn and a staffer's use - so nothing new decides a payment. The save gate first failed on the test's own shortcut: cards appended to the stable skip the Gym Wall's pin that a joining card gets, and the round trip exposed it. The log's OVER window is one tick wide, so the determinism gate signs and sets a whole bench in one visit (the OVER input `sign` now takes a count).
StartedAt: 2026-09-26T05:08:37Z | DoneAt: 2026-09-26T06:49:41Z

## PAC-100 row (CSV-ready, todo columns)
ID: PAC-100 | Title: The locker room (NP_08 s4): the release and its undo, the stable's cap given its valve | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: NP_08 s4 on the sim - "Release (rare, reversible for 3 in-game days) frees cap space - released characters return to their district, remain re-recruitable, and remember (a small grudge/warmth flag; people aren't cartridges)".
- **The release:**
  - a stable card released between duals: the place freed, his role cleared, his ledgers kept;
  - reversible for three days (the calendar's `new_day`), then he is back in his district;
  - a named recruit is re-recruitable through his condition, a generic back on the open mat;
  - the grudge/warmth flag on his record, read by his return.
- **The locker room:** browse by slot-role, House, Style and Element (NP_08 s4), as DUAL OVER lines and the aid's pick.
- **Gates:**
  - the release against its absence;
  - the undo inside three days and refused after;
  - the cap reached, then a place freed;
  - the flag through the save;
  - determinism with a release in the log.
BlockedBy: PAC-099 | DependencyType: soft | RelatedWork: NP_08 s1 s2.1 s2.4 s4; NP_11 s9; NP_14 C29 C52 C53; data/economy.v1.json; data/recruits.v1.json
Notes: Alternatives for PAC-100: district rep (NP_02 s2, NP_08 s2.2 / s2.4); the academy recruiting the club's beaten rivals (NP_12's "the anti-you").
