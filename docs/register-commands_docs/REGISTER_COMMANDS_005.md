# REGISTER COMMANDS 005 — for the applying writer
**From: @claude · 2026-09-19 · Re: PAC-056 hissatsu effect VM, desperations by name, Wall Gauge (greybox v6, NP_14 C10)**
Same rule as 001–004: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-056 Status DONE** (row payload below replaces the TODO row from 004).
2. **Setfield PAC-057 (feints) BlockedBy PAC-056** — unchanged otherwise; it is the next phase. The feint's "triggers opponent defensive reads" now has a real consumer (the boss read + the cast interrupt window), so its DoD can name both.
3. **Add PAC-058** (row below) — Status TODO. Corner phase + relay presentation: the 45 s corner with the tactics choices NP_02/NP_10 describe (order sealing, the ace slot, rest vs send), the relay chain and CHARGED entrance shown as the score-bug chain, and the T3 afterimage ghost. The sim carries `relay_chain` and `t3_unlocked` already; the corner is still two keys.
4. **Note NP_14:** C10 added; "what this pass does not claim" extended with the VM's stated limits (family-row geometry for supers, data-only fields, mini-dual no-ops). `docs/NP_00_INDEX.md` row 14 now reads C1–C10.
5. **Note OVR-026 (`data/hissatsu_library.v2.json`):** the sim now reads every field except `duo_variant`, `hybrid_parents`, `camera_script_id`, `vfx_set`, `private_meter_cost` (always null). The library is executable content, not reference content — recommend the row's Tags gain `#executable`.
6. **Note the greybox lineup:** the three carried moves are canon for RORY (Aurora Borealis Breaker) and library-sourced placeholders for PRIYA (First Snap, generic Frost T0) and MARCUS (Chinook Rush, generic Gale T1) until NP_08/NP_11 assign them.

## PAC-056 row (CSV-ready, todo columns)
ID: PAC-056 | Title: Hissatsu effect VM — library v2 effects executed from data, boss desperations cast by name, Wall Gauge | Phase: P1-CombatCore | Status: DONE | Priority: high | Assignee: @claude
DoD: core.gd executes every effect type in data/hissatsu_library.v2.json (DMG with mult/bypass/hits/target/zone_req/base+chain/final-30s, DISPLACE ROPES/CORNER/CENTER, STATE x36 names, BUFF x14 names, SHRED, WALL timed and point, BURN; REDACTED = authored-absent) with a static coverage check over all 87 moves; casts by family motion at tier cost with the CHARGED half-cost and T3 unlock; the counter profile (window_ms, interruptible, negation string) governs interrupts and the resolve; every boss desperation casts its library entry by name with arm_only honoured; NP_05 s8 Wall Gauge for Sam Tagaq (100, source factors, TRUE OPEN 8s x1.25, reforms 60/30, gone on the third) and HC-0's migrant wall; smoke gates per effect and per rule; determinism coverage for casts
BlockedBy: PAC-055 | DependencyType: soft | RelatedWork: NP_05 s4-s9; NP_14 C10; data/hissatsu_library.v2.json; NP_04A/B desperation lines; NP_04 s8.3
Notes: 2026-09-19: SMOKE 124/124 GREEN x 24 bosses (2,976 assertions; +29); DETERMINISM 10/10 (log casts on both sides, lands and interrupts); GEOMETRY 5/5; demo soaks Sam/Yuri/Marta/Cal 3600 frames zero errors. Bugs the gates caught: auto-slip resolving before the wall; buffs declared after a DMG packet never applying to it (declaratives now resolve first); the survival grab firing inside a wobbled caster's cinematic; anchors' gauges shielding the generic drop tests (the tests strip the gauge for those stages and test it on its own). Two v5-era rules retired: hissatsu no longer zeroes the bar (tier cost) and the desperation is no longer one generic haymaker
LearningNotes: Reading the negation string as rules (four shapes) instead of tagging moves made the counterplay data-driven; a move's whole counterplay is one authored line the smoke holds it to. The order of effects in data was found to matter and was made not to
StartedAt: 2026-09-19T19:10:00Z | DoneAt: 2026-09-19T21:05:00Z

## PAC-058 row (CSV-ready, todo columns)
ID: PAC-058 | Title: Corner phase + relay presentation — 45s corner choices, order sealing, chain on the score bug, T3 afterimage | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: The corner is a timed phase (45s feel, skippable) with the NP_02/NP_10 choices as data (send/rest/re-seal order where legal), the relay chain and CHARGED entrance drawn on the score bug, FULL RELAY at chain>=3 applying the T4 discount rule even with no T4 in the library, and the previous fighter's afterimage rendered on T3 casts; smoke gates for the chain arithmetic (lost segment keeps it, <10 contributed breaks it) and the corner timer
BlockedBy: PAC-056 | DependencyType: soft | RelatedWork: NP_02; NP_05 s6-s7; NP_10 s3
Notes: Sim-side the chain exists (relay_chain, t3_unlocked); this is the phase that makes it visible and gives the corner its tactics
