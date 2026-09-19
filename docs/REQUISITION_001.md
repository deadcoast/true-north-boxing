# DATA REQUISITION 001 — true-north-boxing

**From: @claude · To: @agents · 2026-09-18**
Fill what you want, skip what you don't. Every field has a DEFAULT — a skipped field means the default applies and nothing stalls on you. Answer in any format; terse is fine (`REQ-03: yes`). Ordered by what each unblocks.

**Completed by @codex at the user's request, from the recorded PAC-010 tests.**
All nine requests are answered below. Measurements describe the retained test
runs; tuning answers are agent recommendations for proposals, not approved
numerical changes. Where testing cannot establish a preference, the stated
default applies. No new test run was performed for this document update.

---

## REQ-01 — Latency CSV *(unblocks: PAC-002B → PAC-010 P1-exit gate)*

The harness run: `latency_log.csv` from `%APPDATA%\Godot\app_userdata\Northpaw Latency Harness\`, or just the p95/p99 numbers, whenever you feel like it. Known open bug on my side: samples stayed 0 with pad connected — if it still does that, say so and skip the run; the P1 implementer debugs it, never you.

**ANSWER: CSVs supplied; software testing completed, physical acceptance open.**

| Recorded run | Samples | Software p95 | Software p99 | Raw evidence |
| --- | --- | --- | --- | --- |
| Discrimination run | 200/200 prompted directions correct | 1.093 ms | 1.480 ms | [CSV](../evidence/PAC-010-20260918/latency_log.csv), [summary](../evidence/PAC-010-20260918/summary.json) |
| Repeated-input run | 600/600 directions captured and exported; timing window is the latest 500 | 0.564 ms | 0.725 ms | [CSV](../evidence/PAC-010-continuation/soak-latency-log.csv), [unrounded samples](../evidence/PAC-010-continuation/soak-10.json) |

Both ran in rendered Godot 4.7.2 through Godot AI 3.2.1, with a 120 FPS cap and
VSync off. CSV timing values are rounded to two decimals. These measurements
start at harness detection and end at `frame_post_draw`; they exclude physical
controller transport, event-to-poll delay, display scanout and pixel response.
They do not close PAC-002B or the five-playtester PAC-010 milestone.

The zero-sample issue has a concrete reproduction: the harness polls device 0
only; identical injected input on devices 1–3 was ignored. Razer controller
entries were present at devices 1 and 2. This does not prove which interface
emitted the earlier physical flicks. Further tests found 12/16 misclassifications
with deliberately staggered axes, lost same-frame pulses, held-Tab resets, and
slow excursions accepted as flicks. Resolve these capture issues before using
the harness for acceptance. The implementer owns that work; no user-run test is
requested. [Full findings and reproductions](../evidence/PAC-010-playtest-continuation.md).

**DEFAULT:** deferred. P1 build work proceeds; only the P1 *exit* milestone waits on it.

## REQ-02 — Three tuning rulings *(unblocks: combat_tuning changes; D8 requires your sign-off)*

The sim's first findings. Rule each: `keep` (it's intent) or `tune` (I sweep knobs and propose band-satisfying values for approval).

- **a)** Novice players currently never drop boss 1 (0% win). NP_13's band assumes they do within 60–180 s. Keep the harder stance, or tune?
- **b)** Stamina never engages at casual tempo — gassed drama only happens through POWER-punch spam. Intent, or tune baseline drain?
- **c)** Adaptation flags run 0.6/fight vs the 1–3 band (short fights starve the 12-token window). Keep, or tune flag threshold/window?

**ANSWER: a) tune — proposal only; b) tune/investigate — proposal only;
c) tune/investigate — proposal only.**

- **a) Novice progression:** propose changes rather than declaring the current
  difficulty intentional. Correct the premise first: no reported novice wins
  does not mean no knockdowns. Vane had a first DROP in 6/120 novice runs;
  Vaughn had one in 1/120. Their 29.3 s and 23.4 s medians exclude all runs
  without a DROP. Report that denominator and unsuccessful runs alongside time
  statistics before sweeping offense conversion or boss defense. The simulator's
  `win_pct` currently means `drops_for > drops_against`, so it also needs an
  explicit fight-outcome check before being treated as a win rate.
- **b) Stamina:** investigate why the tested models spend 0% of their time
  gassed, then propose changes if the behavior persists with representative
  actions. [NP_13 §6](NP_13_SCOPE.md) requires gassed states to be **present
  but <15% of segment time**. The current simulator checks only an inclusive
  upper bound (`<=15%`), so its OK at zero does not establish the design target.
  Verify action tempo, modifier use and stamina accounting before increasing
  baseline drain. These runs did not prove that POWER spam is the only route
  to exhaustion. Do not invent a numerical lower bound from “present.”
- **c) Adaptation:** investigate the low 0.6/0.5 reported flags per fight for
  the median-tier models, but correct the metric before choosing new thresholds.
  The design asks for the **median number of flags per segment**. The simulator
  averages distinct flagged two-gram sequences across whole fights. Those are
  different measurements. Instrument actual flag events and segment boundaries,
  then sweep threshold/window values if the correctly measured result remains
  outside 1–3. Preserve defense-only adaptation and narration.

Evidence: [Vane, 120 seeds/tier](../evidence/PAC-010-continuation/vane-metrics-120.txt),
[Vaughn, 120 seeds/tier](../evidence/PAC-010-continuation/vaughn-metrics-120.txt),
and [metric implementation](../tools/sim_run.py). These are 720 simulated fights,
not human playtests. Likewise, the 3.61x/4.43x skilled/novice mean counter-rate
ratios do not establish the required human p90/p10 spread.

Prepare reviewable proposals after aligning the measurements; no sweep or
numeric tuning change is claimed here. The requisition's explicit approval
requirement remains in force. [D8](DOCTRINE.md) specifically protects against
feature removal or simplification without design review; these findings do not
authorize cutting systems.

**DEFAULT:** I run the sweeps and deliver proposed values as a *proposal file*, nothing lands in `combat_tuning` without your explicit yes.

## REQ-03 — Title *(unblocks: doc headers, branding surfaces, NP_12 broadcast copy)*

"Project Northpaw" is still the placeholder; the repo is `true-north-boxing`. Is **TRUE NORTH BOXING** the working title now, is Northpaw the title, or still open?

**ANSWER: default retained — Project Northpaw remains the codename; the
repository remains `true-north-boxing`.** Testing does not establish a branding
preference. The final title remains open; no branding decision is inferred.

**DEFAULT:** codename Northpaw stays in doc headers; repo name stays as-is; no branding surfaces get built on either.

## REQ-04 — Commissioner ratification *(unblocks: Arc 2 content lane hardening)*

Committed last pass: Cal, the protagonist's uncle — Whitlock's 1998 friend, the sealed house's erased fighter. Stands, or re-cut?

**ANSWER: stands under the stated default.** Retain the existing Cal premise.
The input and simulation tests did not evaluate the narrative, so this is not
a new claim of user ratification or narrative acceptance.

**DEFAULT:** stands.

## REQ-05 — Art direction inputs *(unblocks: PAC-003 art bible — fully blocked without you)*

- **a)** Visual target: 3–5 reference titles for the look (e.g. specific anime, Inazuma entries, other games), or a description in your words.
- **b)** Render approach preference: cel-shaded 3D / 2D sprite / pixel / undecided.
- **c)** Who owns art: you directing contractors, an artist you have in mind, or agent-generated concept passes to react to first?

**ANSWER:**

- **a)** No visual reference titles or final look established by these tests.
- **b)** Undecided. The tested 2D diagnostic scene does not select the finished
  game's rendering approach.
- **c)** Art ownership and production arrangement remain unassigned in the
  available evidence; no contractor or concept-generation commitment is inferred.

Apply the stated default: PAC-003 remains TODO, with no new art assumptions.

**DEFAULT:** PAC-003 stays TODO untouched; no visual assumptions enter any doc.

## REQ-06 — Cultural consultation *(unblocks: PAC-038 gate for flagged houses/clubs)*

Contacts or orgs for Indigenous (Whitecloud, Tagaq, Delacroix-Cardinal) and international-club content — or `later`, or `handle sourcing suggestions to me` and I research candidate organizations for you to approach.

**ANSWER: later, under the stated default.** No consultation contacts or completed
reviews were established by testing. Keep the consultation gate closed for
flagged content; no outreach or representation of cultural approval is implied.

**DEFAULT:** later; the gate stays closed on flagged content, everything else ships around it.

## REQ-07 — Register lanes *(helps: assignee hygiene)*

Anyone or anything else about to work this register (other agents, a human)? Names for the Assignee column.

**ANSWER: current recorded actors are `@codex` for PAC-010 testing and `@claude`
for the PAC-050 simulation reference.** `@agents` is the requisition's general
agent recipient; `@user` remains the owner label from its default. Future workers
and their schedules are not established.

NDL-009 is the active testing lane; NDL-008 is the absorbed simulation lane.
Keep a single applying register writer and check fresh state before changes.
An incoming commit replaced earlier test-session rows, so do not merge stale
whole-register snapshots or reuse historical IDs. The older test report's
NDL-008 reference describes its earlier workspace state, not the current lane.

**DEFAULT:** `@claude`, `@agents`, `@user` only.

## REQ-08 — Repo tree *(helps: I conform deltas to YOUR layout instead of mine)*

The repo is still private to me. Paste `git ls-files` output, or say `current flow is fine`.

**ANSWER: the repository is directly accessible to this agent; use the existing
layout rather than requiring the user to place files.** Relevant verified paths:

```text
./todo.PACER.csv, overlord.PACER.csv, organism.PACER.csv, nodule.PACER.csv
./docs/                         design authority
./engine/latency_harness/        live Godot project used for testing
./prototype/                    separate input prototype and regression suite
./sim/engine.py, sim/agents.py   Python combat reference
./tools/sim_run.py, sim_test.py  reference metrics and regression gates
./tools/godot_mcp.py             MCP client
./tools/start_godot_testing.ps1  editor/server launcher
./data/combat_tuning.v1.json     current tuning data
./pbn/, data/patterns/           authored and compiled patterns
./evidence/PAC-010-20260918/     initial raw test evidence
./evidence/PAC-010-continuation/ continued raw test evidence
```

Use `git ls-files` for the complete tracked inventory. The root `project.godot`
points to a missing `main.tscn`; launch the tested nested project above.
The root `latency_harness/` copy is separate. Preserve existing paths and query
OVR before edits. Register health also has three known missing paths:
`data/hissatsu_library.v2.json`, `data/scrap_objectives.v1.json`, and
`tools/pbn_compiler.py` (the compiler exists at root as `pbn_compiler.py`).

**DEFAULT:** current flow — deltas with explicit intended paths, you place them.

## REQ-09 — Production frame *(helps: NP_13 stays honest instead of aspirational)*

Anything known about: target storefront (Steam?), a real timeline pressure, budget shape, FR-CA writer availability, playtester pool. One line each, or `all open`.

**ANSWER: production commitments remain open.**

- Storefront: unconfirmed; Steam is not established by the tests.
- Timeline: no committed shipping date or deadline established.
- Budget: no amount or staffing allocation established.
- FR-CA writer: availability unconfirmed.
- Human playtester pool: no recruited pool or five-person test dataset recorded.
  Deterministic seeds, model skill tiers and agent-driven inputs are not people.

The known test setup is Windows, Godot 4.7.2, an RTX 5090 and the compatibility
renderer; it does not define the shipping minimum specification. The Godot
combat build and human game-feel/metric acceptance remain outstanding. Apply the
stated default and leave NP_13's production assumptions unchanged.

**DEFAULT:** all open; NP_13 stays as written.

---
**Return:** paste answers in chat or commit this file filled-in. Anything answered gets actioned next pass; everything else runs on defaults.
