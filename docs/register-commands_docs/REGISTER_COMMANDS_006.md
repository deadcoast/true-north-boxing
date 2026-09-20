# REGISTER COMMANDS 006 — for the applying writer

**From: @claude · 2026-09-19 · Re: PAC-057 feints (greybox v6, NP_14 C11)**
Same rule as 001–005: commands + row payloads against the live register, never a whole-organ overwrite.

## Commands

1. **Setfield PAC-057 Status DONE** (row payload below replaces the TODO row from 004/005).
2. **PAC-058 (corner phase + relay presentation) stays TODO and is next**; no field changes.
3. **Note NP_14:** C11 added; the not-claimed list names boss-side `feint(Sx)` string variants (NP_04 §6) as not implemented and notes that no pattern binds the new `player_feint` sensors yet. `docs/NP_00_INDEX.md` row 14 now reads C1–C11.
4. **Note `data/combat_tuning.v1.json` (OVR row for it):** the `feint` block (cancel_within_ms 80, stamina 1, enemy_guard_drain 1) is now read by the sim; it was reference-only before.
5. **Note for NP_04 authors (@heat / codex content lane):** bait/punish triggers `player_feint` and `player_feint_<straight|hook|hookercut|uppercut|flared>` are live sensors; any boss whose §5 bait tags name a feint can bind them without engine work.

## PAC-057 row (CSV-ready, todo columns)

ID: PAC-057 | Title: Feints (NP_03 s8) — release-within-80ms feint, reads, guard drain, feint spam tracking | Phase: P1-CombatCore | Status: DONE | Priority: med | Assignee: @claude
DoD: A punch input released within 80 ms of startup becomes a feint (1 stamina, punch cost refunded, no punch, 150 ms recovery); the boss read committed to the press stands (scheduled dodge runs, guard commit becomes a 400 ms flinch); a drawn feint drains 1 enemy guard and herds 10 cm; feints enter the adaptation tracker as `F_<row>` tokens; three identical feints in 10 s stop drawing reactions for that row (read cancelled) with a 10 s reset; a feint never interrupts a cast; `player_feint` / `player_feint_<family>` sensors fire; intent carries punch_release (key release / stick return); smoke gates for the 80 ms edge (10 vs 11 ticks), the read over 30 seeds, the drain, the cutoff/other-row/reset, the cast contrast, the tokens, herding + sensors; determinism coverage
BlockedBy: PAC-056 | DependencyType: soft | RelatedWork: NP_03 s6, s8, s10; NP_14 C11; data/combat_tuning.v1.json feint block
Notes: 2026-09-19: SMOKE 130/130 GREEN x 24 bosses (3,120 assertions; +6); DETERMINISM 11/11 (44 feints in the log, 22 drawn); GEOMETRY 5/5; demo soaks Vane/Marta/Tam 3600 frames zero errors. Design note the gates surfaced: the boss's read lead (startup - dodge/2) falls after the 80 ms decision for every hook-class punch and before it for jabs, so feinting slow punches draws more - an emergent reward that matches boxing without a tuning knob
LearningNotes: The pending-punch record already carried what the boss had committed to the press; making the feint read that record instead of re-rolling kept C1 intact and made "he bit" a fact, not a chance
StartedAt: 2026-09-19T21:10:00Z | DoneAt: 2026-09-19T21:55:00Z
