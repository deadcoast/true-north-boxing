# NP-06 — AFFINITY STACK: The Three Rings

**Project Northpaw design vault · Doc 6/13**
Related: [[NP_03_COMBAT_ENGINE]] · [[NP_05_TENSION_HISSATSU]] · [[NP_07_HOUSES]] · [[NP_10_TACTICS]]

Three stacked affinity layers sit on top of the combat sim: **Style** (mechanical archetype), **Element** (shonen affinity), **House** (lineage, specified fully in [[NP_07_HOUSES]] — this doc covers only its matchup math). Design intent: *skill always beats math; math decides even fights.* Total stacked advantage is capped so no matchup is ever a coinflip-by-spreadsheet.

---

## 1. RING 1 — STYLE (the combat triangle)

`SWARMER → beats → OUT-BOXER → beats → SLUGGER → beats → SWARMER` · **BOXER-PUNCHER** = neutral flex.

### 1.1 Why the triangle points this way (commentary-speakable logic)

- Swarmer beats Out-Boxer: constant pressure denies the range game.
- Out-Boxer beats Slugger: movement and jabs make power irrelevant.
- Slugger beats Swarmer: walking into a puncher's phone booth ends badly.
A hundred years of real boxing discourse — the game inherits it rather than inventing it.

### 1.2 Style parameter packages (applied to the [[NP_03_COMBAT_ENGINE]] sim)

| Style | Buffs | Costs |
| --- | --- | --- |
| **SWARMER** | Inside-range hooks/uppercuts −20% stamina; clinch-scramble windows +25%; herding push +50% | Punch range −10%; guard capacity −10% |
| **OUT-BOXER** | Jab/straight range +12%; movement stamina −15%; back-step speed 85% (vs 70%) | Power-punch damage −10%; corner-trap escapes harder (weave −10% arc) |
| **SLUGGER** | Power/haymaker guard-shred +30%; composure pool +15%; ropes-zone damage +10% | Hand speed −10%; slip windows −15% |
| **BOXER-PUNCHER** | No edits; may equip ONE off-style passive node ([[NP_11_PROGRESSION]] §5) | No triangle bonus ever |

### 1.3 Triangle advantage effects (advantaged side, whole matchup)

- EP from clean hits +10%.
- All counter windows +50 ms.
- Commentary calls the matchup at segment start (the teaching channel).
Disadvantaged side receives no penalty beyond the opponent's bonus — disadvantage is *their* edge, not your debuff (psychologically critical framing; the player is never told "you are weakened").

---

## 2. RING 2 — ELEMENT (Canadian nature cycle)

`FROST → beats → GALE → beats → GRANITE → beats → TIMBER → beats → FROST`
*Deep cold stills any storm; wind erodes stone to sand; stone splits and crushes timber; living timber survives the longest winter.*

### 2.1 What Element touches (and what it doesn't)

Element is the **hissatsu and identity ring** — it does NOT modify normal punches (deliberate: the moment-to-moment sim stays boxing; element lives where the shonen lives).

| Interaction | Effect |
| --- | --- |
| Technique matches user's element (same-element spike) | Hissatsu power ×1.30 |
| User's element beats opponent's | Hissatsu effect ×1.10; hissatsu Tension costs −10% vs. them |
| Opponent's element beats user's | Their walls (T2) last +1 s against you |
| Neutral | — |

### 2.2 Element expression (VFX identity bible)

| Element | Aura & FX language | Personality stereotype (soft, breakable) |
| --- | --- | --- |
| **FROST** | Blue-white crystal, breath-fog, arena frost creep | Patient, precise, quiet |
| **GALE** | Silver streaks, banner-snap wind, speed lines | Fast, restless, loud |
| **GRANITE** | Amber-grey, dust rings, shockwave cracks | Immovable, stubborn, warm |
| **TIMBER** | Deep green-brown, growth patterns, sap-gold glints | Enduring, adaptive, rooted |

> Stereotypes exist to be subverted by characters (a screaming, joyful Frost fighter is a design opportunity, not an error).

### 2.3 Element assignment

Elements are innate per fighter (rolled from House bias tables, [[NP_07_HOUSES]] §3, with 20% off-bias chance — families are tendencies, not laws). Never trainable, never changed. Techniques carry their own element; equipping off-element techniques is legal (you just forgo the ×1.30 spike) — build freedom over purity.

---

## 3. RING 3 — HOUSE (matchup math only; full system in [[NP_07_HOUSES]])

- **Feud bonus:** fighters from feuding Houses ([[NP_07_HOUSES]] §6): both earn +25% Tension from all sources against each other, and commentary runs the feud history. Feuds make matches *louder*, not lopsided — deliberately symmetrical.
- **Dialect familiarity:** your Pattern Intel vs. their House ([[NP_02_TWO_LAYER]] §3) applies its interrupt-window bonuses here.
- **Native-technique home advantage:** House-native hissatsu used by a blood/adopted member: +10% effect (stacks with element spike — the full "this is MY family's move" moment caps at ×1.43).

---

## 4. STACKING FORMULA & THE CAP

`total_mod = style_ring × element_ring × house_ring`, applied per relevant action (EP mods to EP, hissatsu mods to hissatsu).
**Hard cap: ×1.5 on any single computed advantage.** Anything above clamps. Rationale: at ×1.5 a skilled disadvantaged player still wins comfortably; beyond it, matchup math starts playing the game for you. The cap is doctrine-adjacent — raising it requires a design review with playtest data.

## 5. THE MATCHUP CARD (UI)

Pre-segment, 3 s broadcast card: both fighters, style triangle arrow, element cycle arrow, feud banner if active, one commentary line. The whole stack, taught in one glance, every segment, forever. (Formation-screen version with full projections: [[NP_10_TACTICS]] §2.)

## 6. WORKED EXAMPLES

1. **Your Swarmer/Gale vs. their Out-Boxer/Granite:** Style: you advantaged (+10% EP, +50 ms windows). Element: Granite beats... nothing here — Gale beats Granite: your hissatsu ×1.10 and −10% cost. Total: comfortable edge; commentary: "Pressure and wind against stone and range — she has to make this ugly, and she can."
2. **Their Slugger/Timber (House Reyes) vs. your Swarmer/Frost (House Tremblay, feuding with Reyes):** Style: they're advantaged. Element: Frost loses to Timber — their walls +1 s vs. you. House: feud active, both +25% Tension. Result: you're down both rings but the match is a Tension geyser — exactly the segment you slot before your Hammer to fuel a FULL RELAY. Losing matchups have strategic *uses*: doc [[NP_10_TACTICS]] §2 builds on this.
3. **Boxer-Puncher mirror:** no rings active anywhere. Pure sim. The "purist's matchup" — commentary treats it with reverence. These exist on purpose; the stack must know when to shut up.

## 7. BALANCE PHILOSOPHY

- The triangle is the *loud* ring (players plan around it), element the *flavor* ring (players feel it in supers), house the *story* ring (players feel it in their chest). Tuning order when things fight: sim feel > style > element > house.
- Quarterly balance rule for live tuning: no style may exceed 40% usage in ranked spar boards; no element may exceed 30% of top-100 hissatsu equips. Levers: the parameter packages, never the triangle itself. The triangle is sacred.
