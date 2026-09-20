# REGISTER COMMANDS 004 — for the applying writer
**From: @claude · 2026-09-19 · Re: PAC-055 fouls both ways, shrinking clinch cue, survival grab (greybox v6, NP_14 C9)**
Same rule as 001–003: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands
1. **Setfield PAC-055 Status DONE** (row payload below replaces the TODO row from 003).
2. **Add PAC-056** (row below) — Status TODO. Hissatsu effect VM: the greybox casts one generic ×2.5 effect and every boss desperation is the same haymaker; the library v2 carries typed effects (DMG/DISPLACE/STATE/BUFF/SHRED/WALL/BURN over 87 moves, five families) and counter profiles. Executing them from data is the next fidelity gap, and the Wall Gauge (NP_05 §8) rides on the WALL effect.
3. **Add PAC-057** (row below) — Status TODO. Feints (NP_03 §8): release within 80 ms of startup, 1 stamina, triggers the boss read, −1 guard on the tracker, feint spam tracked like punches. Cheap, and it completes the NP_03 verb set.
4. **Note NP_14 C9:** amended in place — clinch scramble now the shrinking alternating cue, referee now both ways with the geometric foul definitions, "what this pass does not claim" updated. No new claim number; C9's test list grew to 35 assertions.
5. **Note the `pholding` split:** the register's earlier PAC-054 note said holding calls incremented `pwarnings`; they now increment `pholding` (a break penalty is not a warning). HUD shows both.

## PAC-055 row (CSV-ready, todo columns)
ID: PAC-055 | Title: Clinch/foul completion — player fouls, shrinking clinch cue, AI survival grab | Phase: P1-CombatCore | Status: DONE | Priority: low | Assignee: @claude
DoD: Fouls resolved by geometry both ways (body punch into a LEAN = low blow; overhand/haymaker onto a DUCK or WEAVE = behind the head), half damage and no EP on a foul, NP_01 s5 ladder warning / -5 EP / DROP awarded from the third against player and boss, clean bosses pull would-be fouls and dirty bosses foul to META warnings_banked then pull; clinch cue shrinks 700/560/448/358 ms with 30pct windows floored by the RFX window (80-160 ms), alternating L/R stick taps with ENTER/A parity, wrong side spends the cue and an early tap locks it; a wobbled boss (composure < wobble_below_pct) grabs once per segment at 0-range; wobble_move_mult applied to both fighters; all under smoke gates
BlockedBy: PAC-054 | DependencyType: hard | RelatedWork: NP_14 C9; NP_01 s5; NP_03 s7, s2.4, composure thresholds
Notes: 2026-09-19: SMOKE 95/95 GREEN x 24 bosses (2,280 assertions; +11); DETERMINISM 9/9 (log now exercises fouls/pulls and the survival grab); GEOMETRY 5/5; demo soaks Alfie/Vane/Moira 3600 frames zero errors. Emergent rule worth a design read: because clean bosses pull would-be fouls, a lean-back now neutralizes a clean boss's body work and a duck his overhand - the referee is a defensive tool. Bug caught: event payload key "kind" collided with the event kind (foul kinds invisible to filters) - renamed to "foul"
LearningNotes: Writing the foul as geometry rather than as a flag produced the pull mechanic for free; the legal twins (uppercut into a duck lands clean, head punch into a lean is legal) are what make the rule readable and they were only visible once the contrast tests were written
StartedAt: 2026-09-19T18:55:00Z | DoneAt: 2026-09-19T20:10:00Z

## PAC-056 row (CSV-ready, todo columns)
ID: PAC-056 | Title: Hissatsu effect VM — library v2 effects executed from data, boss desperations cast by name, Wall Gauge | Phase: P1-CombatCore | Status: TODO | Priority: high | Assignee: @claude
DoD: core.gd executes every effect type in data/hissatsu_library.v2.json (DMG with mult/bypass/hits/zone_req/chain, DISPLACE, STATE, BUFF, SHRED, WALL, BURN; REDACTED = authored-absent) with a static coverage check over all 87 moves; the three lineup moves and every boss desperation cast their library entry by name (cinematic startup = library startup_cinematic_ms, counter_profile window/interruptible honoured); NP_05 s8 Wall Gauge for anchors (Sam Tagaq first: 100 pts, only counters/power/body damage it, 8 s TRUE OPEN on break, reforms at 60); smoke gates per effect type + determinism coverage
BlockedBy: PAC-055 | DependencyType: soft | RelatedWork: NP_05 s4-s8; data/hissatsu_library.v2.json; NP_04A/B desperation lines
Notes: Largest remaining fidelity gap between the compiled content and what the sim executes; 24 desperations are currently one haymaker

## PAC-057 row (CSV-ready, todo columns)
ID: PAC-057 | Title: Feints (NP_03 s8) — release-within-80ms feint, reads, guard drain, feint spam tracking | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: A punch input released within 80 ms of startup becomes a feint (1 stamina, no punch); the boss read fires on it as on a punch (dodge/guard commit), guard tracker -1; feints enter the adaptation tracker as tokens so three identical feints in 10 s stop drawing reactions; bait tags that name feints resolve; smoke gates for the 80 ms edge (79 feints, 81 punches), the read, the drain and the spam cutoff
BlockedBy: PAC-055 | DependencyType: soft | RelatedWork: NP_03 s8, s10; NP_04 s5 bait tags
Notes: Needs a release edge in the intent (punch held vs tapped) - main.gd samples key/flick release; the flick classifier already has the peak-capture window
