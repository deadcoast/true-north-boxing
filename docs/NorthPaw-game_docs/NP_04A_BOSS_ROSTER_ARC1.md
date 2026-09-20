# NP-04A — ARC 1 BOSS ROSTER: The Remaining Eight

**Project Northpaw design vault · Expansion of [[NP_04_OPPONENT]] · Vault v1.1**
Related: [[NP_04_OPPONENT]] (grammar, taxonomy, template) · [[NP_07_HOUSES]] · [[NP_10_TACTICS]] · [[NP_12_NARRATIVE]] §4

[[NP_04_OPPONENT]] §8 authored Yuri, Marta, and Sam. This doc authors the other eight named bosses of Arc 1, completing the arc's dual ladder: Survival Dual → Regionals → Provincials → Nationals. Every boss follows the §7 template: identity, philosophy, tells with channel/tier, full PBN, ≥1 BAIT, ≥2 PUNISH, phases, desperation, remix plan, recruitment hook, lesson taught. Windup floors (400/700/1200 ms) hold everywhere; violations are compile errors per PAC-011.

Arc 1 named roster after this doc: **11 of the 24 ship-target bosses** (NP_13 §1). Placement in the beat sheet per [[NP_12_NARRATIVE]] §4.

---

## 1. CASSIDY VANE — Ascendant B-Squad, R3 Pivot *(Survival Dual, Ep 2)*

Out-Boxer · Gale · **No house** — academy product, and the game's first quiet look at what Vey builds. *Philosophy: "You're a checkbox on my transfer application."*

**Tells (Loud, audio):** her corner. An Ascendant assistant coach reads string codes off a tablet — "Sequence Four!" — and Cassidy executes. The player's first audio-channel lesson: hear the code, know the punch. Her own body barely telegraphs; the institution telegraphs for her.

```bash
BOSS Vane_Cassidy
  IDLE: lateral_drift, guard_high, no_taunt
  STRING S1 "Sequence1": TELL(corner_call_S1, 700ms) -> JAB -> JAB -> R_STR
  STRING S2 "Sequence4": TELL(corner_call_S4, 700ms) -> STEP_BACK -> COUNTER_R_STR
  STRING S3 "Sequence7" [phase>=2]: TELL(corner_call_S7, 600ms) -> JAB -> L_HOOK -> R_STR
  SELECT: w(S1)=55, w(S2)=30, w(S3)=15
  INTERRUPT: S1,S3 during TELL -> stagger(800ms)
  BAIT: player_holds_center 4s -> force S1        # she runs the syllabus on schedule
  PUNISH: player_power_whiff -> immediate S2
  PUNISH: player_rope_backing -> S1 speed x1.1    # she herds hesitation
  PHASE 2 @ composure<50%: add S3; corner_call volume drops one tier (they start hiding it)
  DESPERATION: none                                # B-squad is not issued supers
```

Her desperation slot is empty on purpose: Ascendant doesn't spend hissatsu budget on B-squad. She knows it. The Survival Dual is winnable *because* the academy already wrote her off, and the commentary says so.

**Remix plan (Arc 3):** `newstring` + a real desperation — her first, learned outside the academy. **Recruitment:** Arc 2, after Ascendant cuts her — the defector storyline ([[NP_12_NARRATIVE]] §7); condition `QUEST(vane_cut) AND WITNESS(she watches you win a dual at the Old Gym)`. **Lesson:** audio tells, interrupt basics, the first taste of Vey's institution.

---

## 2. MOIRA "UNDERTOW" MacISAAC — Cape Breton Netmen, R4 Hammer *(Regionals pool)*

Slugger · Timber · House MacIsaac — Dex's older cousin, the heir who stayed. *Philosophy: "The sea doesn't chase anybody. It pulls."*

**Tells (Standard, visual-body):** the net-haul — shoulders roll back like taking up a line before every pull-counter. On the ropes her tell tier drops to Subtle (home water).

```bash
BOSS MacIsaac_Moira
  IDLE: forward_walk_slow, guard_mid, herding_bias(ropes)
  STRING S1 "SetTheNet": TELL(shoulder_roll, 550ms) -> L_HOOK -> R_HOOK (advance 40cm)
  STRING S2 "Haul":      TELL(net_haul, 500ms) -> PULL_COUNTER_OVERHAND (drag target 1m ropeward on hit)
  STRING S3 "Gaff" [target_zone==ROPES]: TELL(net_haul_low, 450ms) -> LT_R_UPC   # body uppercut, x1.25 zone
  SELECT: w(S1)=45, w(S2)=35, w(S3)=20 | target_zone==ROPES: w(S3)+=25
  INTERRUPT: S1 during TELL -> stagger(800ms)
  BAIT: player_holds_center 5s -> force S2 at range   # Haul whiffs badly in open water
  PUNISH: player_straight_line_retreat -> S1 speed x1.15
  PUNISH: player_corner_entry -> immediate S3
  PHASE 2 @ cumulative_player_ropes_time>20s: all damage +10% permanent  # the tide came in
  DESPERATION @ composure<25%: hissatsu "Undertow" (T1 HAYMAKER, Timber; TELL 1200ms)
```

**Remix plan:** `feint(S2)` — the haul that releases into a hook instead. **Recruitment:** `BOND(Dex, 3) AND QUEST(macisaac_harbour)` — Dex's father's episode resolves the black-sheep wound, and Moira follows her cousin. **Lesson:** ring geography as a win condition; center ring is the counterplay, and the matchup card says so out loud.

---

## 3. TAM NGUYEN-ROY — Gatineau Deux-Ponts, R2 Second *(Regionals — the decoy-seal club)*

Out-Boxer · Gale · House Nguyen-Roy, dual-lineage footwork. *Philosophy: "You studied the wrong fight. I made sure of it."*

Coach Wray's club runs decoy seals ([[NP_10_TACTICS]] §3), and Tam carries the deception into the ring: his opening 20 seconds are borrowed clothes.

**Tells (Subtle, visual-body):** true tell — weight shifts fully onto the lead foot before every angle change (the two-bridge step). Opening-phase fake tells — he *performs* other clubs' telegraphs.

```bash
BOSS NguyenRoy_Tam
  IDLE: angle_walk, guard_low_bait, tempo_shift@6s
  STRING S1 "BorrowedCoat" [phase==1]: TELL(fake_shoulder_load, 800ms) -> JAB (delayed 300ms)
     # performs Kowalchuk's freight-load, delivers a jab; floor-legal - real attack is slower than the fake promises
  STRING S2 "TwoBridge": TELL(lead_foot_load, 450ms) -> ANGLE_STEP -> L_STR -> R_STR
  STRING S3 "FarSpan":   TELL(lead_foot_load, 450ms) -> ANGLE_STEP -> STEP_R_STR (range +0.5m)
  SELECT: phase1: w(S1)=50, w(S2)=30, w(S3)=20 | phase2: w(S2)=55, w(S3)=45
  INTERRUPT: S2,S3 during TELL -> stagger(800ms)
  BAIT: player_reacts_to_fake_tell -> immediate S2   # flinching at the costume IS the opening
  PUNISH: player_3punch_string -> S3 counter-exit
  PUNISH: player_sprint_approach -> S2 with widened angle
  PHASE 2 @ clock>30s OR composure<60%: S1 retired; true pattern only
  DESPERATION @ composure<25%: hissatsu "Pont Couvert" (T1 ARC, Gale; TELL 1200ms)
```

**Remix plan:** `reweight` + S1 returns in phase 2 (he stops respecting you). **Recruitment:** `PI_LEVEL(nguyen-roy, 2) AND BEAT_IN(spar)` — he only respects an opponent who did their own scouting. **Lesson:** intel hygiene. Scout Book entries carry a confidence stamp after this dual; the Film Room's decoy-detection upgrade ([[NP_10_TACTICS]] §7) reads as the direct answer to Tam.

---

## 4. CARTER "ZAMBONI" OKAFOR — Rink District Crossovers, R1 Opener *(Regionals bridge dual)*

Swarmer · Gale · House Okafor — the sibling who plays hockey first and boxes because his house won't let him quit. *Philosophy: "Third period legs win first period fights."*

**Tells (Standard, audio):** the skate-blade *shing* seeded in [[NP_04_OPPONENT]] §3 — he drags his rear foot like a crossover stride before direction changes. On ice he'd be silent; on canvas it sings.

```bash
BOSS Okafor_Carter
  IDLE: circle_fast, guard_mid, taunt@10s
  STRING S1 "Forecheck": TELL(stride_shing, 500ms) -> RUSH(0.8m) -> L_HOOK -> R_HOOK
  STRING S2 "Cycle":     TELL(stride_shing, 450ms) -> LATERAL_ARC -> LT_L_HOOK   # body hook off the circle
  STRING S3 "Slapshot":  TELL(full_windup, 900ms) -> R_HAY
  SELECT: w(S1)=40, w(S2)=40, w(S3)=20 | segment_clock<30s: all speeds x1.12   # third period
  INTERRUPT: S1,S3 during TELL -> stagger(800ms)
  BAIT: player_taunt -> force S3                     # he cannot let a chirp go
  PUNISH: player_static_guard 3s -> S2 to the body
  PUNISH: player_gassed(<40 stamina) -> w(S1)+=30    # forechecks tired legs
  PHASE 2 @ composure<50%: S2 gains a second body hook
  DESPERATION @ composure<25%: hissatsu "Empty Net" (T1 PISTON, Gale; TELL 1200ms)
```

**Remix plan:** `tighten(S2, 420ms)` + `newstring` (a check-hook he learns from watching Marta tape). **Recruitment:** `BEAT_IN(scrap)x3 AND REP(rink_district, 3)` — the bridge-the-town questline; recruiting Carter is the first crack in hockey's wall, and his Okafor siblings light up on the String Wall. **Lesson:** lateral tracking, late-segment stamina discipline, and the first sibling of the Okafor triangle.

---

## 5. JEAN-GUY MOREAU — Québec City Forge, R4 Hammer *(Provincials quarterfinal)*

Slugger · Frost · House Moreau — cold-forge hooks, the villain-adjacent house whose Arc 2 turn is seeded here. *Philosophy: "Cold iron doesn't argue."*

The inverse of Yuri, by design: Arc 1's sluggers taught Loud; Jean-Guy is a **Subtle-tell slugger**, the first proof that power and quiet can share a body. Placed after the player has PI literacy to survive it.

**Tells (Subtle, visual-body + audio):** a slow frost-breath exhale before power — visible vapor, a low audible breath under the crowd. His footwork never changes; the breath is everything.

```bash
BOSS Moreau_JeanGuy
  IDLE: forward_walk_glacial, guard_high, silent
  STRING S1 "ColdForge": TELL(frost_breath, 480ms) -> L_HOOK -> R_HOOK -> LT_R_HOOK
  STRING S2 "Quench":    TELL(frost_breath_long, 700ms) -> pause(300) -> R_OVERHAND
     # the pause punishes early blocks - guard drops on his delay, overhand lands
  STRING S3 "Ingot" [ARMORED]: TELL(double_breath, 1000ms) -> WALK_STRING(3 hooks, uninterruptible)
  SELECT: w(S1)=50, w(S2)=30, w(S3)=20
  INTERRUPT: S1 during TELL -> stagger(800ms)        # S2 pause defeats interrupt timing; S3 armored
  BAIT: player_perfect_block_streak>=2 -> force S2   # he hunts good blockers
  PUNISH: player_rope_touch -> immediate S1
  PUNISH: player_hissatsu_arm_feint -> S2            # he answers theatre with iron
  PHASE 2 @ composure<55%: tighten all tells -60ms (floor-respected); movement +10%
  DESPERATION @ composure<25%: hissatsu "Février" (T1 HAYMAKER, Frost; TELL 1200ms; arena frost creep)
```

**Remix plan (Arc 2, Moreau's turn):** `phase_shift` + `newstring` from the Hollow Circuit's extracted-technique pool — the house that said yes to the Commissioner. **Recruitment:** declined in Arc 1. He looks at the offer letter and closes the gym door — the refusal is a cutscene and an Arc 2 hook. **Lesson:** Subtle tells under pressure, delay-timing versus block instinct, dodge-only armored strings.

---

## 6. ADA OKAFOR — Toronto Ascendant A-Squad, R2 Second *(Nationals semifinal)*

Swarmer · Gale · House Okafor — the sibling who took the scholarship. *Philosophy: "Pressure is a scholarship. I pay it forward."*

House Okafor's pressure line, drilled to academy metronome. Her tell is **the beat itself**: she attacks on a fixed 800 ms tempo, and once the player hears it, every entry is readable. Breaking her rhythm is the fight.

```bash
BOSS Okafor_Ada
  IDLE: advance_metronome(800ms), guard_tight
  STRING S1 "OnTheBeat":  TELL(tempo_step, 400ms) -> JAB -> LT_L_HOOK       # every entry on the metronome
  STRING S2 "Downbeat":   TELL(tempo_step, 400ms) -> JAB -> JAB -> R_UPC
  STRING S3 "SwarmProtocol" [trigger]: TELL(tempo_double, 600ms) -> RUSH -> 4-hit mixed string
  SELECT: w(S1)=55, w(S2)=45 | S3 only via PUNISH
  INTERRUPT: S1,S2 during TELL -> stagger(800ms) AND desync(3s)
     # desync: metronome broken - her SELECT stalls 3s, tells widen +100ms; unique reward state
  BAIT: none - she offers nothing                     # the academy removed her generosity
  PUNISH: player_passive>6s -> force S3
  PUNISH: player_flagged_ngram (adaptation tier>=2) -> S2 targets the flagged opening
  PHASE 2 @ composure<50%: metronome 800ms -> 650ms; desync duration 3s -> 2s
  DESPERATION @ composure<25%: hissatsu "Heat Advisory" overdriven (house native, +2 Tension denial on hit; Pressure Cooker failed the 1200ms desperation cinematic floor at compile - PAC-011A)
```

Her BAIT line is authored empty and the Scout Book says why: Ascendant coaches out generosity. Against her brother Carter's chirping warmth, the roster itself argues the game's thesis.

**Remix plan:** `reweight` + metronome becomes variable (she improvises for the first time — Arc 3 character growth in pattern math). **Recruitment:** Arc 2, `BOND(Carter, 4) AND QUEST(okafor_table)` — the sibling map on the String Wall completes through family, and the third sibling surfaces from it. **Lesson:** rhythm reading, the desync reward loop, and punishing repetition literacy (she is the first boss who reads the player's adaptation flags back at them).

---

## 7. EFUA "SHELLS" OSEI — Halifax Osei Club, R5 Anchor *(Provincials semifinal)*

Swarmer · Timber · House Osei — **UNSANCTIONED** ([[NP_07_HOUSES]] §5): the forbidden daughter who stole the family style through a window. *Philosophy: "They locked the door. I learned the window."*

**Tells (Subtle, visual-gear):** a glint off her mother's old hand-wraps — taken without blessing — as her shoulder rolls into the shell. Her shell posture is the fight's puzzle: head shots skate off it; body work cracks it.

```bash
BOSS Osei_Efua
  IDLE: shell_stance(shoulder_roll), advance_patient
  STRING S1 "Shell" [STATE, 3s]: TELL(wrap_glint, 500ms) -> COUNTER_STATE
     # during Shell: head punches slip-countered; LT body punches land and shorten the state 1s each
  STRING S2 "Window": TELL(wrap_glint_fast, 450ms) -> SURGE(0.6m) -> L_HOOK -> R_HOOK -> LT_R_UPC
  STRING S3 "LockedDoor" [phase>=2]: TELL(double_glint, 600ms) -> GUARD_WALL_ADVANCE (herds 60cm)
  SELECT: w(S1)=45, w(S2)=40, w(S3)=15
  INTERRUPT: S2 during TELL -> stagger(800ms)
  BAIT: player_headhunt_streak>=3 -> force S1        # she invites the mistake she was raised on
  PUNISH: player_whiffed_body_shot -> immediate S2
  PUNISH: player_corner_entry -> S3
  PHASE 2 @ composure<50%: Shell duration 3s -> 4s; adds S3
  DESPERATION @ composure<25%: "Deep Roots" SECRET, UNSANCTIONED CAST
     # fires at 70% power with a visible stumble on the exit - she half-knows the family secret
     # TELL 1200ms; the stumble is a 500ms punish window the fight's whole lesson builds to
```

Her desperation is the characterization: a stolen secret technique, incomplete, cast anyway. The commentary goes quiet for it.

**Remix plan:** post-blessing rematch — the SECRET fires at 100%, no stumble; the remix page in the Scout Book is retitled in her mother's handwriting. **Recruitment:** `QUEST(osei_blessing) AND FEUD_RESOLVED(osei_internal)` — the forbidden-daughter arc from [[NP_07_HOUSES]] §5, landed. Arrives UNSANCTIONED if recruited early; her blessing quest stays live in the stable. **Lesson:** body punching as a system (the LT modifier's graduation exam), patience against counter-shells.

---

## 8. ANDERS VEY — Toronto Ascendant A-Squad, R5 Anchor *(Nationals final — the authored loss)*

Boxer-Puncher · element varies by phase · **formerly House Petrov** — the teaching house's heir, mentorship-adopted by Director Vey. The game's warmest mechanic ([[NP_07_HOUSES]] §5) used coldly, on purpose, seeded two arcs early. *Philosophy: "Every style is a solved problem."*

**The gimmick:** three phases, three borrowed house dialects — synthesis without lineage, fought before Arc 2 names it. Each phase performs a real house's tell channel *slightly wrong*, and player PI in those houses transfers at half value: studying real families literally pays off against the counterfeit.

```bash
BOSS Vey_Anders
  PHASE 1 "TheCounter" [Out-Boxer kit, Frost]:
    STRING P1S1 "MirrorCopy": TELL(glove_turn_NO_silence, 500ms) -> COUNTER_STATE(2s)
       # Tremblay dialect minus its silence - his footwork stays loud; the flaw IS the read
    STRING P1S2 "FrostLineCopy": TELL(glove_turn, 450ms) -> JAB -> JAB -> STEP_OUT
    SELECT: w(P1S1)=40, w(P1S2)=60 | PUNISH: player_3punch_string -> P1S1
  PHASE 2 @ composure<70% [Swarmer kit, Gale]:
    STRING P2S1 "PressureCopy": TELL(tempo_step_offbeat, 450ms) -> JAB -> LT_L_HOOK
       # Okafor metronome he cannot quite hold - the beat drifts; drift is the tell
    STRING P2S2 "SwarmCopy": TELL(tempo_double, 600ms) -> RUSH -> 3-hit string
    SELECT: w(P2S1)=55, w(P2S2)=45 | PUNISH: player_passive>5s -> P2S2
  PHASE 3 @ composure<40% [Slugger kit, Granite]:
    STRING P3S1 "FreightCopy": TELL(shoulder_load_silent_corner, 600ms) -> R_HAY -> L_HOOK
       # Kowalchuk's load with no corner shout - the pride is missing; the silence is wrong and readable
    STRING P3S2 "IngotCopy" [ARMORED]: TELL(double_breath_dry, 1000ms) -> WALK_STRING(2 hooks)
    SELECT: w(P3S1)=60, w(P3S2)=40 | PUNISH: player_rope_touch -> P3S1
  INTERRUPT: all non-armored strings during TELL -> stagger(700ms)
  BAIT: none in any phase
  PI_TRANSFER: tremblay/okafor/kowalchuk PI applies at 50% vs matching phase
  DESPERATION @ composure<20%: "Thesis Defense" (T2 WALL + counter state, 5s; breakable per NP_05 s9)
```

**The authored loss ([[NP_12_NARRATIVE]] §4.7):** the loss is scored at the *dual* level, never the segment level. Anders is fully beatable in his segment by a skilled player — droppable, phase-breakable, honest. The dual math is stacked upstream: Vey's corner counter-picks the player's revealed order across R1–R4 ([[NP_10_TACTICS]] §9's final exam), so the team arrives at R5 behind on DROPs. Beating Anders in the segment while losing the dual is the intended best outcome, is tracked with a flag (`beat_anders_ep1`), and changes his Arc 3 rematch dialogue. Players never eat a scripted defeat inside the ropes; the defeat lives in the coaching, which is the story's actual thesis.

**Remix plan (Arc 3):** the thesis fight — a fourth phase, his own: House Petrov's teaching style, reclaimed. `newstring` set authored from Petrov natives; PI transfer restored to 100% because the style is finally real. **Recruitment:** none. Anders is the anti-you until Arc 3 resolves him. **Lesson:** everything Arc 1 taught, examined once, plus the seed of Arc 2's "lineage without love" spoken in pattern math a full arc before the Commissioner says it out loud.

---

## 9. ROSTER LEDGER (Arc 1 complete)

| # | Boss | Club | Slot | Style/Elem | House | Beat |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Cassidy Vane | Ascendant B | R3 | Out-Boxer/Gale | none | Survival Dual |
| 2 | Yuri Kowalchuk | Grain Kings | R4 | Slugger/Granite | Kowalchuk | Regionals |
| 3 | Moira MacIsaac | Netmen | R4 | Slugger/Timber | MacIsaac | Regionals |
| 4 | Tam Nguyen-Roy | Deux-Ponts | R2 | Out-Boxer/Gale | Nguyen-Roy | Regionals |
| 5 | Carter Okafor | Rink Crossovers | R1 | Swarmer/Gale | Okafor | Regionals bridge |
| 6 | Jean-Guy Moreau | Québec Forge | R4 | Slugger/Frost | Moreau | Provincials QF |
| 7 | Efua Osei | Halifax Osei | R5 | Swarmer/Timber | Osei (UNSANCTIONED) | Provincials SF |
| 8 | Marta Okonkwo-Tremblay | Montréal Technique | R2 | Out-Boxer/Frost | Tremblay | Provincials SF |
| 9 | Sam Tagaq | True North | R5 | Boxer-Puncher/Frost | Tagaq | Nationals QF |
| 10 | Ada Okafor | Ascendant A | R2 | Swarmer/Gale | Okafor | Nationals SF |
| 11 | Anders Vey | Ascendant A | R5 | Boxer-Puncher/varies | Petrov (taken) | Nationals final |

Coverage audit: all four styles bossed ≥2×; all four elements present; tell channels — audio (Vane, Carter, Moreau), visual-gear (Efua, Marta), visual-body (Moira, Tam, Yuri, Ada), composite (Anders, Sam); tiers — Loud 2, Standard 4, Subtle 4, mixed 1. Every §7 template field filled per boss; every desperation TELL at the 1200 ms hissatsu floor; armored strings all ≥1000 ms and Loud-class.

Pipeline note: these eight are design-authored. PBN compile validation lands with PAC-011 (the compiler enforces floors mechanically); boss-gate playtests (PI-0 clearability, squint test) land per boss at implementation under PAC-038's gate discipline.
