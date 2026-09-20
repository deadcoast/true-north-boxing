# REGISTER COMMANDS 001 — for the applying writer

**From: @claude · 2026-09-18 · Re: REQUISITION_001 actioning**
My register copy predates the @codex commit, so per REQ-07's stale-snapshot rule this ships as PACER commands + row payloads, never a whole-organ overwrite. Apply against the live register; skip anything NDL-009 already covers.

## Commands

1. **Add PAC-051** (row below) — Status DONE. Measurement-layer corrections from the codex REQ-02 review, all five landed in `tools/sim_run.py` + `sim/engine.py` this pass.
2. **Add PAC-052** (row below) — Status TODO. The tuning sweeps themselves, now legal to run against corrected measurements; output is a proposal file, D8 sign-off required before any `combat_tuning` change.
3. **Note PAC-002B:** harness capture bugs from the codex repro fixed in `engine/latency_harness/main.gd`: multi-device polling (was device-0-only; Razer pads sat at 1–2), 150 ms fast-crossing gate rejecting slow excursions, 2-frame peak-capture window for staggered-axes classification, Tab key-repeat ignored. Re-run of discrimination repro recommended before acceptance. Software p95 figures from the codex runs (1.093 ms / 0.564 ms) note-attached as evidence, physical acceptance still open.
4. **Setfield OVR-039 Path `pbn_compiler.py`** — conformed to repo root location; `tools/` copy retained until the applying writer confirms, then prune one.
5. **Note OVR-026 / OVR-038:** `data/hissatsu_library.v2.json` and `data/scrap_objectives.v1.json` re-delivered this pass — the three missing-path register healths REQ-08 reported should clear on commit.
6. **Note the root `project.godot` + root `latency_harness/`:** not mine to delete; flagged as duplicate/broken by REQ-08 — recommend a cleanup decision by @user or NDL-009.

## PAC-051 row (CSV-ready, todo columns)

ID: PAC-051 | Title: Correct sim measurement layer per codex REQ-02 review | Phase: P1-CombatCore | Status: DONE | Priority: high | Assignee: @claude
DoD: TTFD reports denominator (droppers n/N, no bare survivorship medians); win = explicit fight outcome (KO/decision/no-decision); gassed band checks presence AND <15%; flags counted as events per 90s segment from Tracker instrumentation; counter spread = pooled p90/p10 with tier-mean as context only
BlockedBy: PAC-050 | DependencyType: hard | RelatedWork: REQUISITION_001 REQ-02; NDL-009 evidence
Notes: 2026-09-18: All five corrections landed; 14/14 unit gates still green. Corrected verdicts vs Vane n=120/tier: flags 2.0/segment IN BAND (finding c was the measurement, confirmed); TTFD 6/120 novice droppers and gassed 0%-present stand as real findings; pooled p10 degenerate at 0 (many zero-counter novice fights) - noted
LearningNotes: An out-of-band metric is only a finding after the metric itself survives review - one of codex's three findings dissolved under correct measurement, two hardened
StartedAt: 2026-09-19T00:55:00Z | DoneAt: 2026-09-19T01:10:00Z

## PAC-052 row (CSV-ready, todo columns)

ID: PAC-052 | Title: Tuning sweeps -> proposal file for the two hardened findings | Phase: P1-CombatCore | Status: TODO | Priority: med | Assignee: @claude
DoD: Sweeps over (novice conversion x boss defend base) and (baseline stamina drain x tempo) against corrected metrics; band-satisfying candidates delivered as data/combat_tuning.PROPOSAL.json with per-knob deltas and metric evidence; NOTHING lands in combat_tuning.v1.json without explicit @user sign-off (D8)
BlockedBy: PAC-051 | DependencyType: hard
Notes: REQ-02 ruling: tune, proposal-only, measurements first - measurements are now first
