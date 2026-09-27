# ENGINE DECISION RECORD — Godot 4
**PAC-002A deliverable · Decision: Heat, 2026-09-18 · Validation: PAC-002B (harness in `latency_harness/`)**

## Decision
**Godot 4.x** (4.3+ recommended). Ratified by Heat 2026-09-18.

## Fit against the spec (why this engine serves this design)
| Requirement | Godot 4 answer |
|---|---|
| Hot-reloadable tuning data ([[NP_03_COMBAT_ENGINE]] §12) | JSON via `FileAccess` + `ResourceLoader` cache bypass; `combat_tuning.v1.json` loads in one call, file-watch reload is ~20 lines |
| Data-driven content DBs (hissatsu, PBN, feud graph) | Same path; PBN compiles to Godot `Resource` trees or plain dictionaries — no engine fight |
| Fixed-camera 3D ring + 2D-grade UI ([[NP_03]] §1, [[NP_01]] §9 score bug) | Camera3D with scripted holds; Control-node UI is a first-class layer, broadcast cards are scenes |
| Stick-flick input grammar ([[NP_03]] §2) | Raw per-frame axis polling (`Input.get_joy_axis`), no input-map smoothing in the path; details below |
| Small team, MIVIM licensing posture | MIT, no royalties, no seat licenses; Python-adjacent GDScript keeps the agent content pipeline in one idiom with the repo's tooling |
| PC first, console later ([[NP_13]] §1) | PC/Steam first-class; console via W4/porting partners at the P-decision gate — flagged as the choice's main open risk, priced below |

## Input path (the part latency lives in)
- Poll the right stick every rendered frame in `_process`, never `_physics_process` — flick detection runs at render rate, uncoupled from the 60 Hz physics tick.
- Project settings for the combat scene: V-Sync OFF (or Mailbox where available), `input_devices/buffering/agile_event_flushing = true`, physics interpolation ON for ring movement so visuals stay smooth while input stays raw.
- Flick = magnitude crossing 0.6 with positive radial velocity; direction = one of 10 sectors mapping the [[NP_03]] §2.1 matrix (5 per hand). Detection math is engine-agnostic and lives in the harness exactly as it will live in the game.

## Known risks, priced
| Risk | Price | Mitigation |
|---|---|---|
| Console ports need partners | Cost at P-gate, post-alpha | Already a NP_13 decision gate; no change |
| GDScript perf ceiling in the sim | Low — the sim is arithmetic on dictionaries | C# or GDExtension migration path per-module if a profile ever demands it |
| Input latency variance across pads/drivers | The actual PAC-002B question | Measured, never assumed — harness below |

## PAC-002B validation protocol (runs on Heat's machine)
1. Open `latency_harness/` in Godot 4.3+, run. Pad connected (the shipping-target pad first, others after).
2. **Latency mode:** flick freely; the harness timestamps poll-detection → punch-state apply → present call per flick and holds a rolling distribution. Pass: **p95 ≤ 50 ms** software-path.
3. **Discrimination mode (TAB):** the harness prompts a direction, you flick, it scores the sector match. Pass: **≥ 99% over 200 prompts** across all 10 sectors.
4. **Full-chain check (optional, honest number):** the white flash square fires on punch-start; film pad + screen with a 240 fps phone camera and count frames from stick movement to flash. Software-path measurement cannot see the display; this can.
5. Quit writes `user://latency_log.csv`. Attach the CSV and the p95 to PAC-002B's Notes; DONE closes PAC-002 and unblocks PAC-005.
