# NP-04 — OPPONENT ARCHITECTURE: "Their Brain"
**Project Northpaw design vault · Doc 4/13**
Related: [[NP_03_COMBAT_ENGINE]] · [[NP_02_TWO_LAYER]] (Pattern Intel) · [[NP_06_AFFINITY]] · [[NP_07_HOUSES]] (tell dialects) · [[NP_12_NARRATIVE]]

Every named opponent is a hand-authored pattern boss in the Punch-Out tradition: unique strings, readable tells, interrupt windows, phase changes, and remixable rematches. This doc specifies the pattern grammar (a designer-writable notation), the tell taxonomy, the boss design template, three fully authored launch bosses, the generic assembler, and difficulty philosophy.

---

## 1. DESIGN LAW
1. **Authored offense, adaptive defense.** Opponent attack behavior is scripted pattern logic — learnable, consistent, characterful. Only their *defense* adapts (to player repetition, via the tracker in [[NP_03_COMBAT_ENGINE]] §10).
2. **The tell IS the character.** Every tell must express personality/House, not just telegraph. A tell that could belong to anyone is rejected at review.
3. **Every pattern is beatable at PI 0.** Pattern Intel ([[NP_02_TWO_LAYER]] §3) teaches faster; it never gates victory.
4. **Fair wind-ups.** Minimum tell-to-impact time: 400 ms (normals), 700 ms (specials), 1200 ms (hissatsu). Below these = bug, not difficulty.

---

## 2. PATTERN GRAMMAR (designer notation → runtime)

Patterns are written in **PBN (Pattern Boss Notation)**, compiled to behavior trees. Core syntax:

```
BOSS GrainKing_Yuri
  IDLE: circle_slow, guard_mid, taunt@8s
  STRING S1 "Freight":   TELL(shoulder_load, 600ms) -> R_HAY -> L_HOOK -> pause(400)
  STRING S2 "Coupling":  TELL(step_stomp, 500ms) -> STEP_R_STR -> R_UPC
  STRING S3 "Derail" [phase>=2]: TELL(snort_audio, 700ms) -> RUSH(1.2m) -> CLINCH_ATTEMPT
  SELECT: w(S1)=50, w(S2)=30, w(S3)=20  | after_hit_taken: w(S1)+=20 for 6s
  INTERRUPT: S1 during TELL -> stagger(800ms), tension_bonus
  BAIT: player_taunt -> force S1 within 2s        # taunt-baitable
  PUNISH: player_power_whiff -> immediate S2
  PHASE 2 @ composure<60%: speed×1.1, add S3, TELL(shoulder_load) -600ms->500ms... 
  DESPERATION @ composure<25%: hissatsu "Grain Elevator" per hissatsu rules
```

**Primitives:** IDLE behaviors, STRINGs (tell → attack sequence → recovery), SELECT weights (with reactive weight shifts), INTERRUPT definitions (which strings are breakable, during what), BAIT tags (player actions that force strings — the mind-game hooks), PUNISH tags (player mistakes that trigger responses), PHASE blocks (composure/time/score triggered), DESPERATION (scripted hissatsu usage).

Runtime guarantees: strings never chain without a ≥400 ms neutral gap unless authored as a designed blender (rare, boss-tier, always phase-gated).

---

## 3. TELL TAXONOMY

Three channels, three loudness tiers. Every string declares channel + tier.

| Channel | Examples |
|---|---|
| **Visual-body** | Shoulder load, hip coil, glove drop, stance widening, eyebrow wiggle homage |
| **Visual-gear** | Glove tape flash, headgear glint, banner motion behind them (crowd as tell surface) |
| **Audio** | Snort, stomp, coach shout from their corner ("Cut the angle, Marta!" — enemy corners *telegraph on purpose*, a Northpaw signature), skate-blade *shing* for the hockey-crossover boss |

| Tier | Duration | Used by |
|---|---|---|
| **Loud** | 600–1200 ms, big silhouette change | Early bosses, sluggers |
| **Standard** | 450–700 ms | Mid circuit |
| **Subtle** | 400–500 ms, micro-motion (glove angle, weight shift) | Technicians, late bosses. Subtle tells must still pass the squint test at PI 0 (art bible metric) |

**House dialects** ([[NP_07_HOUSES]] §4): each House defines a base channel + motif that all members inherit; individuals vary tier, timing, and flourish. Learning the dialect pays across the whole House — the recon compounding loop.

---

## 4. INTERRUPT WINDOWS & STUN STATES
- Strings tagged INTERRUPT can be broken by a clean fast hit (jab-class) landed during the TELL phase → **stagger** (800 ms punish state) + Tension +5 + the flash-counter window ([[NP_03_COMBAT_ENGINE]] §5).
- Not every string is interruptible (armored strings exist, always Loud-telegraphed — the "you dodge this, you don't stop it" class).
- Repeated interrupts of the same string teach some bosses (authored, not systemic): phase scripts may swap a burned string for its feint variant on remix ([[NP_04_OPPONENT]] §6).

---

## 5. BAIT & PUNISH HOOKS (the conversation layer)
BAIT tags make bosses *talk* to player behavior: taunt-baitable bosses, aggression-punishers (counter-genius archetypes with PUNISH on any 3-punch player string), patience-punishers (bosses whose SELECT shifts to pressure if the player passives >6 s). Every boss ships with ≥1 BAIT and ≥2 PUNISH hooks — the minimum for a fight to feel like a mind, not a playlist.

---

## 6. REMATCH REMIX SYSTEM
Remix operators applied as a layer over the original PBN (original remains in the Scout Book; remix earns its own page):
| Operator | Effect |
|---|---|
| `feint(Sx)` | String gains a feint variant: tell plays, attack delayed 300 ms or cancelled into another string |
| `tighten(Sx, ms)` | Tell duration reduced (floor: §1 fair minimums) |
| `reweight` | SELECT redistribution (old habits fade) |
| `newstring` | +1 authored string (remixes get real new content, not just math) |
| `phase_shift` | Phase triggers move earlier |
Story rematches use 2–3 operators; the Arc 3 "everyone returns" gauntlet uses full remixes. Circuit escalation, Punch-Out style.

---

## 7. BOSS DESIGN TEMPLATE (authoring checklist)
Identity (House, Style, Element, slot role) → Philosophy in one sentence → Tell motif (channel/tier, personality justification) → 3–5 strings with names → SELECT logic → ≥1 BAIT, ≥2 PUNISH → Phase plan (2–3 phases) → Desperation hissatsu → Remix plan → Recruitment hook ([[NP_08_STABLE]] — beaten bosses are future stablemates; their pattern becomes *your* fighter's AI-assist showcase in exhibition auto-play).

---

## 8. THREE LAUNCH BOSSES (fully authored)

### 8.1 YURI "GRAIN KING" KOWALCHUK — Prairie Grain Kings, R4 Hammer
Slugger · Granite · House Kowalchuk. *Philosophy: "Everything I load, I deliver."*
- **Tells (Loud, visual-body):** the shoulder load — a freight-train wind that starts at the hips. His coach yells the string name from the corner ("FREIGHT!") — the corner shout *is* part of his dialect; he's proud, he wants you to know it's coming, and early players still can't stop it.
- **Strings:** *Freight* (haymaker→hook), *Coupling* (stepping straight→uppercut), *Derail* (phase 2 rush-clinch; wins position toward YOUR corner).
- **BAIT:** taunts force *Freight*. **PUNISH:** whiffed player power punch → instant *Coupling*.
- **Phases:** P2 @60% composure: +10% speed, tells tighten, adds *Derail*. Desperation @25%: **"Grain Elevator"** (T1 rising uppercut hissatsu; interruptible with a Loud 1200 ms tell — the fight's final exam is interrupting it).
- **Lesson taught:** haymaker respect, interrupt fundamentals, corner defense. He is deliberately the game's Bear Hugger slot: enormous, warm, recruitable, beloved.

### 8.2 MARTA OKONKWO-TREMBLAY — Montréal Technique, R2 Second
Out-Boxer · Frost · House Tremblay (by mother's line — dual-house character, see [[NP_07_HOUSES]] §7). *Philosophy: "You'll beat yourself; I'll just hold the mirror."*
- **Tells (Subtle, visual-gear):** the Tremblay glove micro-adjustment — left glove rotates 15° before her counter suite arms. Audio: she goes *quiet* (her footwork sound drops out — silence as a tell).
- **Strings:** *Mirror* (pure counter state 2.5 s: first player punch is slipped→cross countered), *Frost Line* (jab-jab-step-out, EP chip), *Retreat Cutter* (back-step→check hook when player sprints in).
- **BAIT:** she PUNISHES 3-punch player strings (counter), PUNISHES sprint approaches (*Retreat Cutter*); her BAIT is inverted — she *offers* the mirror by dropping her hands (trap stance). Patience beats her: her SELECT shifts to impatient *Frost Line* chips if the player refuses to lead for 8 s, and *Frost Line* is interruptible.
- **Phases:** P2: *Mirror* duration +1 s but gains a burned-out cooldown after each use (she gets greedy — character through pattern math). Desperation: **"Première Neige"** (T2 defensive wall — 5 s untouchable slips; wait it out or spend Tension to break it).
- **Lesson:** feints, patience, punishing counter-fighters. She recruits only via her House questline (settling the Tremblay/your-coach feud, [[NP_08_STABLE]] §3).

### 8.3 "BIG SORRY" SAM TAGAQ — True North Club, R5 Anchor
Boxer-Puncher · Frost · House Tagaq. *Philosophy: "I'm not hard to hit. I'm hard to hurt."* The first Wall Gauge anchor ([[NP_05_TENSION_HISSATSU]] §8).
- **Tells (Standard, audio-forward):** he *apologizes* — a soft "sorry" precedes his power counters (the most Canadian tell in the game; it's genuinely disarming and players will love/hate it).
- **Wall Gauge:** 100 pts; only counter hits, power punches, and body work damage it (jab spam does 0 — teaches gauge literacy). Gauge broken → 8 s TRUE OPEN phase where he's droppable; then gauge reforms at 60.
- **Strings:** *Snowbank* (walk-forward guard advance, herds you ropeward), *Sorry Eh* (the apologized counter — perfect-block bait: he punishes *blocks*, forcing head movement), *Long Winter* (phase 3: stamina-drain body clinch series).
- **Phases:** by segment clock, not composure — he gets *stronger* per 30 s elapsed (the endurance thesis of his club). Desperation: none. He never panics. His fight ends only through the gauge.
- **Lesson:** the anchor puzzle, body punching, clock pressure. Post-recruit he becomes the player's own default Anchor option and the tutorial voice for anchor play.

---

## 9. GENERIC OPPONENT ASSEMBLER
Non-named opponents (scraps, filler slots) assemble from a **pattern-piece library** (launch: 60 pieces) tagged by Style × House-dialect × tier. Assembler rules: 2–3 strings, 1 PUNISH, coherent tell channel per dialect, SELECT weights from Style archetype presets. Named-boss strings never appear in generics (named patterns stay special). Difficulty knob = piece tier + tell tier + composure/stat scaling.

## 10. DIFFICULTY PHILOSOPHY
No difficulty menu for story duals. Difficulty is authored per-boss and paced by the circuit ([[NP_12_NARRATIVE]]). Player-side assists (tell-highlight spar mode, rumble timing channel, accessibility inputs) exist in [[NP_02_TWO_LAYER]] §2.2 and [[NP_03_COMBAT_ENGINE]] §2/§11. Optional post-game "Title Defense" remix gauntlet is the hard mode, earned not selected.
