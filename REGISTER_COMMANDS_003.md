# REGISTER COMMANDS 003 — for the applying writer
**From: @claude · 2026-09-19 · Re: PAC-054 sensors + clinch scramble + referee (greybox v6, NP_14 C9)**
Same rule as 001/002: commands + row payloads against the live register, never a whole-organ overwrite. Skip anything NDL-009 already covers.

## Commands
1. **Setfield PAC-054 Status DONE** (row payload below replaces the TODO row from 002; DoD met in full, results in Notes).
2. **Add PAC-055** (row below) — Status TODO. The next thread phase: player fouls do not exist as inputs (the ladder exists, only dirty bosses climb it); the clinch cue is a fixed beat rather than NP_03's shrinking cue; NP_04 §7's "AI survival grab after a wobble" is not wired. Small, all inside the same greybox thread.
3. **Note NP_14:** C9 added (sensor table with thresholds and the contrast that never fires; clinch scramble; referee ladder). C8 result line updated to 13/13 trigger forms. `docs/NP_00_INDEX.md` row 14 now reads C1–C9.
4. **Note MODULE rows from 002** (core.gd / clock.gd / tests.gd / main.gd): no new modules this pass; `engine/greybox/hissatsu_library.v2.json` is a carried copy of `data/hissatsu_library.v2.json` (the sim reads `house_id` per move) — list it as DATA under the greybox with a "copy of OVR-026" note, same as the pattern copies.
5. **Note OVR (LINEUP):** the greybox lineup now names each fighter's hissatsu (RORY Aurora Borealis Breaker, PRIYA First Snap, MARCUS Chinook Rush) so the library's house lineage reaches the sim. Content choice, reversible; PRIYA/MARCUS picks are placeholders from the library's personal/generic pools.

## PAC-054 row (CSV-ready, todo columns)
ID: PAC-054 | Title: Boss sensor completion — 11 behaviour detectors + clinch scramble + referee model | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: Each of player_locks_to_single_tempo, player_neutral_reset_attempt, player_casts_<house>_native, trap_stance_hands_down, player_reacts_to_fake_tell, player_audio_assist_reliance, player_clinch_input_spam, player_sprint_approach, player_straight_line_retreat, player_backstep_chain3, player_rope_backing has a detector in core.gd with a smoke assertion that it fires at its threshold and never early (contrast case per sensor); warnings_banked==N modelled via the NP_01 s5 foul ladder on clinch breaks with META warnings_banked as the cap, so Alfie Crane's phase 2 is reachable; player clinch input + NP_03 s7 scramble (RFX-gated cue, position/reset/lose); sprint-step input; NP_14 C9 written with results
BlockedBy: PAC-053 | DependencyType: hard | RelatedWork: NP_14 C9; NP_01 s5; NP_03 s2.4/s7; NP_04 boss entries (Chiamaka, Deshawn, Remy, Marta, Tam, Choir, Alfie, Moira, Vane)
Notes: 2026-09-19: SMOKE 84/84 GREEN x 24 bosses (2,016 assertions; +22 this pass); DETERMINISM 8/8 with clinch/sprint/sensor coverage asserted; GEOMETRY 5/5; demo soaks on Alfie/Marta/Tam/Moira 3600 frames zero errors. Phase-trigger forms 13/13. Bugs caught by the loop: bodies dragged into one corner collapsed to a single point (no facing, camera look_at failed) -> sim keeps bodies 0.7m apart; a lateral slide along the ropes registered as rope_backing because the boss chases the intercept (sensor correct, first test wrong); active clinch state leaked across smoke stages (test helper fixed)
LearningNotes: A sensor is only defined once its never-fires contrast is written; three of the eleven changed shape while writing the contrast (rope_backing needed the square-boss case, tempo lock needed the varied-cadence case, audio reliance needed the assist-off case)
StartedAt: 2026-09-19T07:05:00Z | DoneAt: 2026-09-19T08:20:00Z

## PAC-055 row (CSV-ready, todo columns)
ID: PAC-055 | Title: Clinch/foul completion — player fouls, shrinking clinch cue, AI survival grab | Phase: P1-CombatCore | Status: TODO | Priority: low | Assignee: @claude
DoD: Player-side low blow / behind-the-head exist as risk inputs (body punch during a boss lean-back counts as low; a punch during his weave counts as behind the head) so the NP_01 s5 ladder applies both ways with the DROP-awarded third rung asserted; the clinch cue shrinks across the 2s duel per NP_03 s7 with the RFX gate on the final window; a wobbled boss (composure < wobble_below_pct) auto-grabs once per segment (NP_03 s7 "AI survival behavior"); all three under smoke gates
BlockedBy: PAC-054 | DependencyType: hard
Notes: Scoped small on purpose: the sensor layer is the load-bearing part and it is done; these are rule completions inside the same thread
