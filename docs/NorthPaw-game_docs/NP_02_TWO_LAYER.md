# NP-02 — TWO-LAYER STRUCTURE: Overworld & The Three Sizes

**Project Northpaw design vault · Doc 2/13**
Related: [[NP_01_SPORT]] · [[NP_04_OPPONENT]] · [[NP_08_STABLE]] · [[NP_11_PROGRESSION]] · [[NP_12_NARRATIVE]]

The single most important structural decision inherited from Inazuma: you are never just playing a sports game. You are playing an action-RPG where the dungeon boss is a dual. This doc designs Layer A (the overworld) and the exact mechanics of the three fight sizes, including the pacing math that keeps the loop from fatiguing.

---

## 1. LAYER A — THE OVERWORLD

### 1.1 The town: **Harbourline** (working name)

A mid-size Canadian hockey town, coastal-adjacent, winter-forward. Explored on foot with a squad of 4 (captain always slotted). Districts, each with a gameplay identity:

| District | Identity | Systems present |
| --- | --- | --- |
| **Millbrook Secondary** | Your school. Hub | Story triggers, club room (menu hub), school scraps, rival student NPCs |
| **The Old Gym** | Your condemned club building | Training minigames, bond board wall, facility upgrades, staff NPCs |
| **Rink District** | Hockey's kingdom | The "not welcome here" district; hostile scraps, the rich rival academy's shadow, later a symbolic dual venue |
| **Harbour & Boardwalk** | Working waterfront | Net-hauling training spot, MacIsaac-house content, fishing NPCs, weather system showcase |
| **Downtown Strip** | Strip-mall commerce | Shops (HBP spending), gacha scouting machines, arcade (minigame variants), poster walls (lore) |
| **Community Centre** | Recruitment wellspring | Open-mat scraps, scouting encounters, connection-map NPC hub |
| **The Hill** | Residential | House homes (family/lineage quests), roadwork routes, snow-run training |
| **CRBF Regional Annex** | The federation office | Circuit registration, ranked boards, official spar matchmaking |

**Seasonal dressing:** the calendar (see §1.3) redresses districts — frozen harbour, playoff bunting in the Rink District, summer festival on the boardwalk (2v2 exhibition venue, [[NP_01_SPORT]] §8).

### 1.2 Squad-of-4 rules

- Captain locked in slot 1; slots 2–4 free from the stable.
- Squad composition matters in the overworld: some scraps and quests check for a House member ("only a Tremblay can read this stance"), a Style ("bring a swarmer"), or a bond pair.
- Squad members ambient-comment (bark system) keyed to district + bond level — the cheap, constant characterization channel.

### 1.3 Calendar & session loop

Soft calendar: days advance on story beats and rest actions, not real-time. Each day grants:

- **3 Training Slots** (minigames, [[NP_11_PROGRESSION]] §7)
- Unlimited scraps/spars (fatigue-free by design — grinding is always legal)
- Story/quest advancement
The calendar exists to pace circuit stages ([[NP_01_SPORT]] §1) and seasonal content, never to punish the player with missed content. Nothing is permanently missable except by explicit story choice.

### 1.4 Movement & interaction verbs

Walk/jog, talk, inspect, **glove-up** (initiate/accept a scrap), train (at spots), shop, scout (hold-to-examine an NPC fighter: reveals Style, House if known, recruit-condition hint — feeds [[NP_08_STABLE]]).

---

## 2. THE THREE SIZES — canonical spec

Same verbs at every scale ([[NP_03_COMBAT_ENGINE]] is fully live in all three). What changes: duration, objective, and reward density.

### 2.1 SNACK — the SCRAP (15–30 s)

The random-battle analog. Triggered by: roaming challenger NPCs (visible, avoidable — no invisible encounters), glove-up on any flagged NPC, quest beats, district events.

**Structure:** one micro-objective, full combat sim, hard 30 s cap. Objective met → win. Cap reached → judged on EP.

**Micro-objective library (launch set of 24, tagged by teaching purpose):**

| Objective | Teaches |
| --- | --- |
| Land 3 body shots | Body punching (LT modifier) |
| Make him miss twice | Slip timing |
| Win one exchange in center ring | Zone awareness |
| Land a counter | Counter economy |
| Break his guard once | Power punches / guard math |
| Survive 20 s (no DROP) | Defense fundamentals |
| Land the finisher: uppercut only | Punch-type precision |
| Don't throw the same punch twice in a row | Adaptation tracker awareness |
| Read the tell: interrupt his special once | Interrupt windows ([[NP_04_OPPONENT]] §4) |
| Corner him for 3 seconds | Ring cutting |
| Win without blocking (slips only) | Punch-Out risk pricing |
| First clean hit wins ("first blood") | Neutral-game opener |
| ...(+12 more, incl. House-specific reads) | |

**Rewards:** XP trickle, Prestige (+1–3, the scouting currency, [[NP_08_STABLE]] §5), item drops, and **Pattern Intel** (§3). Fleeing: allowed pre-engagement freely; mid-scrap flee costs small district rep (−1) — rep gates some recruit conditions.

**Why 30 seconds is sacred:** the entire grind loop's health rests on scraps being shorter than the walk between them. Any design pushing scrap length up must be rejected at review (Doctrine D4).

### 2.2 MEAL — the SPAR (one 90 s segment)

Replayable 1v1 full segment vs. any *met* club's fighters (met = fought or scouted). Initiated at the CRBF Annex (ranked spars), rival club gyms (challenge spars), or your gym (invite stablemates — this is also the bond-grind venue, [[NP_08_STABLE]] §6).

- Full EP scoring, DROPs enabled, no team Tension (personal Tension bar at 50% scale — hissatsu practicable but transforms locked).
- **Lab flags:** optional spar modifiers — infinite stamina (combo lab), tell-highlight mode (opponent tells outlined; XP −50%), mirror spar (fight a copy of your own fighter — the adaptation tracker turned into content).
- Rewards: full XP, Spirits, bond growth, Pattern Intel at 2× scrap rate.

### 2.3 FEAST — the DUAL

Fully specified in [[NP_01_SPORT]]. Story duals add: cutscene framing, rival philosophy beats, authored referee/crowd moments, recruitment flags on victory ([[NP_08_STABLE]] §2), and remix-locked rematches ([[NP_04_OPPONENT]] §6).

---

## 3. THE RECON SYSTEM — Pattern Intel

The mechanical bridge between layers, and the reason the overworld is *reconnaissance* rather than filler.

**Every opponent archetype has a Pattern Intel level (PI 0–3) tracked per House dialect and per named boss:**

| PI | Earned by | Effect in combat |
| --- | --- | --- |
| PI 0 | — | No assists. Tells exist but unhighlighted |
| PI 1 | 3 scraps vs. the House dialect, or 1 spar | Colour commentator calls the archetype's habit pre-segment ("Watch the shoulder — Grain Kings load up") |
| PI 2 | 6 scraps / 3 spars / 1 dual segment | Tell audio cue slightly emphasized; interrupt windows +10% duration vs. that dialect |
| PI 3 | Named boss only: beat them once, or complete their scout questline | Their pattern page unlocks in the **Scout Book** (menu): tell list, string names, phase notes — written as your tactician's handwriting |

PI never trivializes reads (windows stay skill-gated); it *teaches*. A player who grinds scraps against Grain Kings students walks into the Grain Kings dual already literate in the dialect — the knowledge-transfer loop that makes grinding feel like preparation, not chores.

**The Scout Book** is a collection surface in itself: pattern pages, House dialect pages, and boss remix pages (rematch variants get their own entries). Completionists fill the book; the book is diegetic (your tactician staff member maintains it — staff upgrades expand it, [[NP_10_TACTICS]] §7).

---

## 4. OVERWORLD ECONOMY TOUCHPOINTS

| Source | Currency | Sink |
| --- | --- | --- |
| Scraps | Prestige, XP, items | Gacha machines, scouting |
| Quests | HBP, items, recruit flags | Shops, techniques |
| District rep | Gates | Recruit conditions, vendor tiers |
| Training slots | Beans | Stat raises |
Full economy tables in [[NP_11_PROGRESSION]] §6.

---

## 5. PACING MATH (design targets, tune in beta)

- Median time between available scraps while walking: **< 20 s**.
- Scrap total loop (engage → fight → reward toast): **< 60 s**.
- Story dual cadence Arc 1: one dual per 60–90 min of critical path; 2–4 optional duals available between.
- Session shape target (45-min session): 1 story beat + 4–6 scraps + 1–2 spars + 1 training slot + 1 recruitment step. Every session should advance at least three different meters (XP, bond, Prestige, PI, story) — the "always progressing something" rule.

---

## 6. UI FLOW (layer transitions)

- Scrap: no loading — camera swings to fight framing in-place (overworld arena = wherever you stand; snow, gym floor, boardwalk). Reward toast, camera swings back. Total transition budget: 2 s each way.
- Spar/dual: venue load with entrance presentation (skippable after first view per venue).
- The club-room menu hub mirrors all menus (stable, bond wall, scout book, formation) as physical objects in the Old Gym — menus have a diegetic home, matching the gym-wall bond board ([[NP_08_STABLE]] §7).
