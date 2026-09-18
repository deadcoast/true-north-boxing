# NP-03 — COMBAT ENGINE: "The Hands"

**Project Northpaw design vault · Doc 3/13**
Related: [[NP_04_OPPONENT]] · [[NP_05_TENSION_HISSATSU]] · [[NP_06_AFFINITY]] · [[NP_11_PROGRESSION]]

The Fight Night Champion verb set under the Punch-Out camera. This is the frame-level spec: full input matrix, timing values, damage and composure models, stamina and guard math, movement, clinch, the standing-eight, and the adaptation tracker algorithm. All numbers are launch-tuning baselines (data-driven, hot-reloadable — nothing here hardcoded).

---

## 1. CAMERA & FRAMING (binding constraints)

- **Rig:** fixed chase position, 1.8 m behind player fighter, 0.6 m above head height, 12° downward pitch. Opponent centered, full body always in frame. FOV 55°.
- **Player render:** ~35% frame height; below-shoulder alpha drops to 40% whenever the opponent enters any wind-up state (tell readability override). Player punches render as full-opacity arms only.
- **Lateral tracking:** camera orbits to keep the opponent centered as fighters circle; orbit speed capped so background motion never exceeds tell-motion salience (art bible metric, [[NP_13_SCOPE]] risk R-02).
- **Camera holds** (the only permitted breaks of fixed framing): DROP, hissatsu execution ([[NP_05_TENSION_HISSATSU]] §4), transformation ([[NP_09_TRANSFORMATIONS]]), standing-eight. Each has an authored camera script; neutral play never cuts.

---

## 2. INPUT MATRIX — complete

### 2.1 Punch matrix (RS = right stick; stick side = hand)

| RS direction (right half) | Punch | Startup (ms) | Recovery (ms) | Base dmg | Stamina cost | Guard dmg |
| --- | --- | --- | --- | --- | --- | --- |
| Up | R Straight (cross) | 220 | 300 | 10 | 4 | 6 |
| Up-out (up-right) | R Flared Straight / Overhand | 300 | 380 | 13 | 6 | 8 |
| Out (right) | R Hook | 260 | 340 | 12 | 5 | 7 |
| Down-out | R Hookercut | 320 | 400 | 13 | 6 | 9 |
| Down | R Uppercut | 340 | 420 | 15 | 7 | 12 |

> *(Mirror for left half → jab (L straight, 160/220 ms, dmg 6, cost 2), L hook, etc. The jab is deliberately the fastest, cheapest verb in the game — everything is built on it.)*

### 2.2 Modifiers (stack multiplicatively)

| Modifier | Input | Effect |
| --- | --- | --- |
| **Body** | LT + punch | Target torso: dmg ×0.8 to composure but drains opponent stamina (−6 per clean body hit); ignores 20% of guard |
| **Power** | RB + punch | Dmg ×1.5, startup +40%, whiff/blocked leaves 300 ms punishable OPEN frames, stamina ×2 |
| **Haymaker** | RS pull-back ≥150 ms → forward flick | Dmg ×2.2, startup +90% with full-body telegraph, stagger chance; the highest-risk normal in the game. Also the T1+ hissatsu motion base ([[NP_05_TENSION_HISSATSU]] §4) |
| **Stepping punch** | LS toward out-of-range opponent + punch | Auto-triggers: range +0.5 m, dmg ×1.2, telegraph +30% |
| **Block-punch** | punch while RT held | Startup +15%, exits block instantly — the fast defense→offense hinge |

### 2.3 Defense

| Verb | Input | Rules |
| --- | --- | --- |
| **Block** | RT hold | Auto-guard seeks incoming punch (tracking quality = RFX curve). Absorbs: chip 15% of dmg through; guard meter −(punch guard dmg) |
| **Slip L/R** | LT + LS left/right | 260 ms evade window; feet planted (no movement during); success = 0 damage; whiffed slip = eat full punch +20% (mistime tax) |
| **Duck** | LT + LS down | Beats straights/hooks; loses to uppercuts (uppercut vs. duck: dmg ×1.5 — the rock-paper-scissors under head movement) |
| **Weave** | LT + LS quarter-circle toward opponent | 400 ms, moves head through an arc, repositions 30 cm laterally; beats straights, escapes corner traps |
| **Lean-back** | LT + LS back | Beats hooks at range; heavy stamina (−5); loses ground 20 cm |

### 2.4 Movement

LS free movement; SPD sets foot speed (2.2–3.4 m/s across stat range). **Sprint-step** (LS click): quick 0.8 m burst, −4 stamina, the ring-cutting tool. Backpedal speed = 70% of forward.

### 2.5 Other

| Verb | Input |
| --- | --- |
| Hissatsu arm | LB hold (see [[NP_05_TENSION_HISSATSU]] §4) |
| Clinch initiate | Both sticks click at 0-range |
| Taunt / relay signal | D-pad (taunts bait AI patterns — some bosses have taunt-triggered strings, [[NP_04_OPPONENT]] §5) |

**KB/M mapping:** mouse-gesture punching (flick vectors mirror RS angles), keys for modifiers. Full remapping; accessibility preset replaces stick-flicks with button chords (design-approved parity, slight EP handicap in ranked spar boards only).

---

## 3. DAMAGE & COMPOSURE MODEL

Two health-like pools per fighter, both visible:

**STAMINA (0–100):** the universal currency. Drains on every action (§2 tables), on absorbed body shots, and passively during power states. Regenerates +4/s while in neutral (no punch, no block), +1/s otherwise. Corner phase restores +30 (cutman modifies). Effects of low stamina — the "gassed" curve:

| Stamina | Hand speed | Foot speed | Damage dealt | Composure regen |
| --- | --- | --- | --- | --- |
| >70 | 100% | 100% | 100% | 100% |
| 40–70 | 90% | 90% | 90% | 75% |
| 15–40 | 75% | 70% | 75% | 40% |
| <15 | 55% | 50% | 55% | 0% (the danger zone — commentary flags it) |

**COMPOSURE (hidden pool = CHN × 2, i.e. 2–198):** the knockdown resource. Damage reduces it; it regenerates +3/s when not being hit (halted 10 s after surviving a count). Thresholds:

- Composure < 35%: **WOBBLE** state — movement −30%, visible stagger animation (the opponent's cue to swarm; yours too).
- Composure ≤ 0 on a hit: **DROP**. Composure resets to 50% of max after a survived count.
- **Flash rule:** a counter hit landing during the attacker's flash-counter window applies dmg ×2 directly and bypasses 25% of remaining composure — flash DROPS are real and earn 2 points ([[NP_01_SPORT]] §3.1).

**Damage formula:**
`dmg = base × (PWR/50) × zone_mod × style_mod × element_mod × counter_mod × stamina_factor × transform_mod`
zone/style/element mods per [[NP_01_SPORT]] §4 and [[NP_06_AFFINITY]]; counter_mod = 1.6 on any counter window hit, 2.0 on flash window.

---

## 4. GUARD MODEL

**Guard meter (0–100, capacity & regen from BLK):**

- Decays −2/s while RT held (holding is priced) and −(guard dmg) per absorbed punch.
- Regen +6/s while guard down and in neutral.
- At 0: **GUARD BREAK** — 600 ms OPEN state (dmg taken ×1.5, cannot block), meter refills to 40 after.
- Auto-guard tracking: at RFX 30, guard finds ~70% of mixups; at RFX 90, ~95%. Body/head mixups specifically test tracking — LT-body punches are the guard-tracker's blind spot at low RFX.

**Perfect Block:** RT pressed within 150 ms *before* impact → zero chip, zero guard damage, opens the widest counter window (see §5). The parry, in boxing clothes.

---

## 5. COUNTER ECONOMY (timing windows)

Every successful defensive action opens a **counter window** — a period where the player's next punch gains counter_mod and premium Tension:

| Defensive action | Window opened | Width (base / at RFX 90) |
| --- | --- | --- |
| Perfect block | 500 ms | 500 / 650 ms |
| Successful slip | 400 ms | 400 / 550 ms |
| Successful duck | 350 ms | 350 / 480 ms |
| Weave through a punch | 450 ms | 450 / 600 ms |
| Step out of stepping-punch range | 300 ms | 300 / 420 ms |
| **Flash-counter (tell read)** | 700 ms, slowed time ×0.6 | Punch-Out's stun-start. Triggered only by interrupting an opponent tell correctly ([[NP_04_OPPONENT]] §4). Hits here can chain: each clean hit inside the window extends it 200 ms, max 3 extensions — the "free-hit string" |

Counter hits: dmg ×1.6 (×2.0 flash), Tension +3 (+5 flash) ([[NP_05_TENSION_HISSATSU]] §2).

---

## 6. RING MOVEMENT GAME (cutting, herding, trapping)

- **Cut-off mechanics:** lateral movement mirrored correctly (stepping to intercept, not chase) closes escape angles; the sim checks angle-of-escape vs. defender position — cutting is skill-expressed through LS reads, not a button.
- **Herding pressure:** each landed punch and each feint (empty stepping motion) pushes the opponent's position bias 10 cm ropeward; sustained pressure literally walks them back.
- **CORNER TRAP:** pinned in a corner quadrant ≥3 s → state active ([[NP_01_SPORT]] §4 modifiers). Escapes: weave (lateral arc), clinch-win (§7), or landing a counter (window escape — the trapped fighter's widened flash windows make corners double-edged by design).

---

## 7. CLINCH SCRAMBLE

Trigger: both fighters at 0-range with clinch input, or automatic after a wobbled fighter grabs (AI survival behavior). Resolution: 2-second mini-duel — alternating stick-rhythm inputs (not mash: *timing* taps on a shrinking cue, RFX-gated). Winner chooses: **position** (place opponent toward ropes/corner, +herding 50 cm) or **reset** (center ring, both +5 stamina). Referee breaks stalls at 4 s ([[NP_01_SPORT]] §5).

---

## 8. FEINTS & THE MIND GAME

- **Feint** = punch input released within 80 ms of startup: costs 1 stamina, no punch, triggers opponent defensive reads. Against pattern bosses, specific feints bait specific strings ([[NP_04_OPPONENT]] §5 bait tags). Against the guard tracker, feints drain enemy guard −1.
- Feint spam is adaptation-tracked like punches (§10) — three identical feints in 10 s stop drawing reactions.

---

## 9. THE STANDING-EIGHT CHECK (the penalty-kick moment)

On a DROP against the player: time drops to ×0.3, referee count audio, screen vignettes. A **rhythm ring** contracts toward center; the player must tap in the true-beat window. Structure:

- 3 beats to pass (rise at the count of eight). HRT stat widens beat windows (±60 ms at HRT 30 → ±140 ms at HRT 90).
- Each successive DROP in the same segment removes one beat of forgiveness (drop 2: perfect+good only; drop 3: auto-KO — the three-knockdown rule).
- Passing: rise animation, 10 s vulnerability (composure regen halted), crowd surge +8 team Tension ([[NP_05_TENSION_HISSATSU]] §2 — surviving is *worth meter*; the comeback engine's ignition).

---

## 10. ADAPTATION TRACKER (Doctrine D3 — "they're predictable; you can't be")

The system that prices player repetition without ever making *opponents* unreadable.

**Algorithm (per segment, per player fighter):**

1. Maintain a rolling window of the last **12 offensive tokens** (token = punch type + level [head/body] + modifier class).
2. Compute n-gram repetition scores for 2-grams and 3-grams within the window.
3. Any n-gram occurring ≥3 times in-window is **flagged**. Flagged sequences:
   - Opponent defensive response rate vs. that sequence ramps: +25% slip/block chance per flag tier (tier 1/2/3), capped at 85%.
   - Tension earned by hits from flagged sequences: **0** ([[NP_05_TENSION_HISSATSU]] §2).
   - Commentary calls it ("He's leaning on that double-hook — [opponent] is timing it now"). The tracker is *always narrated* — the player is never punished by an invisible system.
4. Flags decay: 8 s without the n-gram clears one tier.
5. **Asymmetry guarantee:** the tracker modifies only opponent *defense*. Opponent *offense* remains the authored pattern ([[NP_04_OPPONENT]]) at all times, all difficulties. This line is doctrinal; no exceptions.

**Stat interactions:** none. Adaptation is pure play-expression pressure — it cannot be built around, only played around. (Deliberate: the one system money can't buy through, keeping high-level play honest.)

---

## 11. HIT REACTIONS & GAME FEEL BUDGETS

- Hit-stop: 40 ms normal, 70 ms power, 120 ms counter, 200 ms flash/hissatsu.
- Screen shake reserved: power hits (small), DROP (large), hissatsu (scripted).
- Audio: punch-weight tiers (jab snap → haymaker detonation); tell audio channel is *ducked-under* everything (readability over spectacle, Doctrine D2).
- Rumble: distinct signatures for guard-low warning, wobble, counter-window-open (accessibility channel for window timing).

---

## 12. TUNING TABLE OWNERSHIP

Every number in this doc lives in `combat_tuning.json` (hot-reload). Ownership: combat designer. Changes gated by the playtest metric suite ([[NP_13_SCOPE]] §6): time-to-first-DROP distribution, counter-rate percentile curves, gassed-state frequency.
