# DATA REQUISITION 001 — true-north-boxing

**From: @claude · To: @agents · 2026-09-18**
Fill what you want, skip what you don't. Every field has a DEFAULT — a skipped field means the default applies and nothing stalls on you. Answer in any format; terse is fine (`REQ-03: yes`). Ordered by what each unblocks.

---

## REQ-01 — Latency CSV *(unblocks: PAC-002B → PAC-010 P1-exit gate)*

The harness run: `latency_log.csv` from `%APPDATA%\Godot\app_userdata\Northpaw Latency Harness\`, or just the p95/p99 numbers, whenever you feel like it. Known open bug on my side: samples stayed 0 with pad connected — if it still does that, say so and skip the run; the P1 implementer debugs it, never you.

```placeholder
ANSWER:
```

**DEFAULT:** deferred. P1 build work proceeds; only the P1 *exit* milestone waits on it.

## REQ-02 — Three tuning rulings *(unblocks: combat_tuning changes; D8 requires your sign-off)*

The sim's first findings. Rule each: `keep` (it's intent) or `tune` (I sweep knobs and propose band-satisfying values for approval).

- **a)** Novice players currently never drop boss 1 (0% win). NP_13's band assumes they do within 60–180 s. Keep the harder stance, or tune?
- **b)** Stamina never engages at casual tempo — gassed drama only happens through POWER-punch spam. Intent, or tune baseline drain?
- **c)** Adaptation flags run 0.6/fight vs the 1–3 band (short fights starve the 12-token window). Keep, or tune flag threshold/window?

```placeholder
ANSWER: a)      b)      c)
```

**DEFAULT:** I run the sweeps and deliver proposed values as a *proposal file*, nothing lands in `combat_tuning` without your explicit yes.

## REQ-03 — Title *(unblocks: doc headers, branding surfaces, NP_12 broadcast copy)*

"Project Northpaw" is still the placeholder; the repo is `true-north-boxing`. Is **TRUE NORTH BOXING** the working title now, is Northpaw the title, or still open?

```placeholder
ANSWER:
```

**DEFAULT:** codename Northpaw stays in doc headers; repo name stays as-is; no branding surfaces get built on either.

## REQ-04 — Commissioner ratification *(unblocks: Arc 2 content lane hardening)*

Committed last pass: Cal, the protagonist's uncle — Whitlock's 1998 friend, the sealed house's erased fighter. Stands, or re-cut?

```placeholder
ANSWER:
```

**DEFAULT:** stands.

## REQ-05 — Art direction inputs *(unblocks: PAC-003 art bible — fully blocked without you)*

- **a)** Visual target: 3–5 reference titles for the look (e.g. specific anime, Inazuma entries, other games), or a description in your words.
- **b)** Render approach preference: cel-shaded 3D / 2D sprite / pixel / undecided.
- **c)** Who owns art: you directing contractors, an artist you have in mind, or agent-generated concept passes to react to first?

```placeholder
ANSWER: a)      b)      c)
```

**DEFAULT:** PAC-003 stays TODO untouched; no visual assumptions enter any doc.

## REQ-06 — Cultural consultation *(unblocks: PAC-038 gate for flagged houses/clubs)*

Contacts or orgs for Indigenous (Whitecloud, Tagaq, Delacroix-Cardinal) and international-club content — or `later`, or `handle sourcing suggestions to me` and I research candidate organizations for you to approach.

```placeholder
ANSWER:
```

**DEFAULT:** later; the gate stays closed on flagged content, everything else ships around it.

## REQ-07 — Register lanes *(helps: assignee hygiene)*

Anyone or anything else about to work this register (other agents, a human)? Names for the Assignee column.

```placeholder
ANSWER:
```

**DEFAULT:** `@claude`, `@agents`, `@user` only.

## REQ-08 — Repo tree *(helps: I conform deltas to YOUR layout instead of mine)*

The repo is still private to me. Paste `git ls-files` output, or say `current flow is fine`.

```placeholder
ANSWER:
```

**DEFAULT:** current flow — deltas with explicit intended paths, you place them.

## REQ-09 — Production frame *(helps: NP_13 stays honest instead of aspirational)*

Anything known about: target storefront (Steam?), a real timeline pressure, budget shape, FR-CA writer availability, playtester pool. One line each, or `all open`.

```placeholder
ANSWER:
```

**DEFAULT:** all open; NP_13 stays as written.

---
**Return:** paste answers in chat or commit this file filled-in. Anything answered gets actioned next pass; everything else runs on defaults.
