# REGISTER COMMANDS 002 — for the applying writer

**From: @claude · 2026-09-18 · Re: greybox v6 engine foundation (NP_14, PCUC)**
Same rule as 001: my register copy predates the live one, so this ships as PACER commands + row payloads, never a whole-organ overwrite. Apply against the live register; skip anything NDL-009 already covers.

## Commands

1. **Add PAC-053** (row below) — Status DONE. The engine foundation: `engine/greybox/sim/core.gd` (deterministic 120 Hz sim core), `sim/clock.gd`, `sim/tests.gd`, `main.gd` rewritten as presentation only. Proof runs recorded in the Notes column and in `engine/greybox/GREYBOX.md`.
2. **Add PAC-054** (row below) — Status TODO. The eleven behaviour detectors and the referee-warning model that NP_14 C8 lists as unimplemented; hooks stay inert until each is written and covered by the smoke.
3. **Add doc row for `docs/NP_14_ENGINE_THEORY.md`** to the overlord organ (DOC, Path `docs/NP_14_ENGINE_THEORY.md`, Summary "Provable claims C1–C8 with test results", Tags #engine #theory #pcuc, Linked PAC-053). `docs/NP_00_INDEX.md` row 14 added this pass.
4. **Add MODULE rows** (IDs by the applying writer): `engine/greybox/sim/core.gd` (TNBSim — the fight), `engine/greybox/sim/clock.gd` (fixed-step accumulator), `engine/greybox/sim/tests.gd` (smoke / determinism / geometry), `engine/greybox/main.gd` (presentation + input → intent). Link all four to PAC-053; core.gd depends on `data/combat_tuning.v1.json` and `data/patterns/*.json` (the greybox carries copies of all 24 now).
5. **Setfield OVR-039 (pbn_compiler.py) Summary** — append "; `--margins` prints Hick–Hyman tell margins (NP_14 C4)". Both copies (root + `tools/`) updated identically; the prune decision from 001 still stands.
6. **Note PAC-011A / NP_01 canon:** greybox v1–v5 ended a dual on any three drops. Not canon. v6 scores DROP 1 / FLASH DROP 2 / SEGMENT KO 3 per NP_01 §3, cumulative, dual = all segments. No doc change needed; the engine was wrong, the vault was right.
7. **Note PAC-050 (Python reference sim):** `sim/engine.py` still carries the v5 dual-ending rule and the dodge matrix. It remains the NP_13 §6 *metrics* reference; the executable truth for combat is now `engine/greybox/sim/core.gd` (C1–C8). Recommend a follow-up PAC to either port the Python sim to the canon scoring or retire it to `archive/` once P1 metrics come from the Godot core — decision for @heat / NDL-009, not taken here.
8. **Note PAC-052 (tuning sweeps):** still TODO, still proposal-only per REQ-02. The determinism log's random fighter is a coverage log, not a balance input; nothing here changes `combat_tuning`.

## PAC-053 row (CSV-ready, todo columns)

ID: PAC-053 | Title: Engine foundation — deterministic sim core with provable claims (NP_14, greybox v6) | Phase: P1-CombatCore | Status: DONE | Priority: high | Assignee: @claude
DoD: TNBSim (engine/greybox/sim/core.gd) is pure (no Nodes, no wall clock, seeded RNG, fixed 120Hz ticks from an intent dict); main.gd is presentation only; headless tests exist and are GREEN for C1 determinism (input-log replay + jittered frame loop, bit-exact hashes), C2/C6 geometric hit resolution (emergent dodge table both directions both hands, read validity, read timing), C3 buffer (same tick / early fire / expiry / through hitstop), C4 tell margins (pbn_compiler --margins), C5 sim-state hitstop, C7 defense-only adaptation, C8 action VM coverage (verbs, punish responses, phase triggers); NP_01 §3 scoring canon implemented and asserted; all 24 compiled bosses load and pass the smoke
BlockedBy: PAC-050 | DependencyType: soft | RelatedWork: docs/NP_14_ENGINE_THEORY.md; engine/greybox/GREYBOX.md; NP_01 s3; NP_03 s9
Notes: 2026-09-18: SMOKE 62/62 GREEN x 24 bosses (1,488 assertions); DETERMINISM 7/7 (400/400 hashes identical across tick-by-tick x2 + jittered 7-40ms frame loop; seed 54321 diverges); GEOMETRY 5/5 (0 mismatches in 4x45 cells; 0/400 invalid reads); MARGINS GREEN (80 strings; worst SPECIAL +175ms, worst ARMORED +475ms vs RT(3)=525ms); real-scene demo soak 3600 frames zero errors. Coverage: 39/39 action verbs, 53/53 punish responses, 12/13 phase-trigger forms (warnings_banked==2 open). Bugs caught by the loop before any human load: inputs eaten during hitstop; boss read dodging at startup instead of impact; Sam Tagaq's non-punch verbs silently skipped in v5; phase-locked punish strings mis-flagged as unknown; v5 dual ending on three total drops (non-canon)
LearningNotes: A claim earns a place in the theory doc only with a named test that has actually run; two of the first-draft C2 "consensus" statements were not in the cited sources and were re-labelled MODEL cells rather than asserted as consensus. The test that checked read TIMING (not just read validity) found the bug that would have made every slow punch unreadable
StartedAt: 2026-09-18T22:40:00Z | DoneAt: 2026-09-19T02:30:00Z

## PAC-054 row (CSV-ready, todo columns)

ID: PAC-054 | Title: Boss sensor completion — 11 behaviour detectors + referee warnings model | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: Each of player_locks_to_single_tempo, player_neutral_reset_attempt, player_casts_moreau_native, trap_stance_hands_down, player_reacts_to_fake_tell, player_audio_assist_reliance, player_clinch_input_spam, player_sprint_approach, player_straight_line_retreat, player_backstep_chain3, player_rope_backing has a detector in core.gd with a smoke assertion that it fires at its threshold and never early; warnings_banked==2 modelled (referee warnings for holding/low blows or authored equivalent) so Alfie Crane's phase 2 is reachable; NP_14 C8 updated to 13/13 trigger forms with results
BlockedBy: PAC-053 | DependencyType: hard | RelatedWork: NP_14 C8; data/patterns/*.json hooks
Notes: Hooks currently inert by construction (unknown sensors never fire), so no boss misbehaves; they simply lack these reads. Player clinch input does not exist yet (NP_03 clinch duel) — sequence that first
