# NP-08 — STABLE, RECRUITMENT & BONDS: The Pokémon Organ
**Project Northpaw design vault · Doc 8/13**
Related: [[NP_02_TWO_LAYER]] · [[NP_07_HOUSES]] · [[NP_10_TACTICS]] · [[NP_11_PROGRESSION]] · [[NP_12_NARRATIVE]]

The retention engine. Every enemy club is a booster pack, every weirdo NPC is potentially yours, and the relationships between the people you collect are themselves a progression system. This doc specifies the stable, all recruitment channels with their condition grammar, the Prestige/gacha economy, the full bond system, cross-house hybrid research, and the bond board UI.

---

## 1. THE STABLE
- Roster cap **100**; dual dressing **8**; overworld squad **4**; staff corps **10** (3 dressed per dual).
- Every stablemate is a full character: House, Style, Element, tell dialect (they exhibit it in spars — your own stable is tell-reading practice), bark set, at least one personal scene.
- **Stable roles beyond fighting:** any stablemate can be assigned as a *training partner* (Beans bonus keyed to their stats), *scout* (passive Prestige from their home district), or *cornerman-in-training* (feeds the staff system, [[NP_10_TACTICS]] §7). Nobody rides the bench doing nothing — the anti-"box mon" rule.

## 2. RECRUITMENT CHANNELS (all launch-active)

### 2.1 Post-dual recruitment (the booster pack)
Beating a club flags 2–4 of its named fighters as **approachable**. Approach in the overworld → their condition surfaces. Rival *bosses* always have authored conditions (never auto-join — earning the boss is content). Condition reveal is honest: the game states requirements outright once discovered (no wiki-bait).

### 2.2 Condition grammar (designer-writable, mixes freely)
`BEAT_IN(scrap|spar|dual[segment])` · `PI_LEVEL(house, n)` · `REP(district, n)` · `QUEST(id)` · `FEUD_RESOLVED(houseA,houseB)` · `BLESSING(house)` · `STAT_PROOF(show a fighter with STAT≥n)` · `STYLE_PROOF(beat me using style X)` · `WITNESS(they must watch you win a dual at venue Y)` · `ITEM(gift)` · `BOND(existing stablemate, level)` — that last one is the connection-map primitive: people join because of *who you already have*.
Example (Marta, [[NP_04_OPPONENT]] §8.2): `QUEST(tremblay_feud) AND FEUD_RESOLVED(tremblay, coach_line) AND BEAT_IN(spar) USING STYLE_PROOF(out-boxer)` — she'll only respect being beaten at her own game.

### 2.3 Connection maps
Visualized as the **String Wall** (corkboard + red string, diegetic in the Old Gym office): recruiting a node reveals adjacent nodes. Masters unlock students (recruit Coach Petrov → his three students surface); families chain (an Okafor sibling in your stable is a BOND-condition key to the other two); houses chain through blessings. Launch content: 6 authored maps, 40+ nodes.

### 2.4 Scouting & the Prestige economy
- **Prestige** earned from scraps (+1–3), district rep milestones, circuit placements.
- **Scouting machines** (downtown + community centre): Prestige-fed gacha dispensing recruit *leads* (a card: silhouette, House hint, district) — the machine never dispenses people, it dispenses *directions to people* (the gacha is a treasure map, dodging the ick of buying humans while keeping pull excitement). Pity: every 10th pull is a rare-tier lead. Leads expire never.
- **Open-mat days** (community centre, calendar-cycled): browsable generic recruits (assembler-built, [[NP_04_OPPONENT]] §9) with visible stats/House — the "filler roster" channel for players who want bodies for training roles.

### 2.5 Story channels
Mentorship-adoptions, disowned heirs, the forbidden daughter, feud resolutions ([[NP_07_HOUSES]] §5–6) — authored recruitment as narrative climax. Target: every Arc 1 rival club yields ≥2 recruitable named characters with real scenes.

## 3. HOUSE-GATED RECRUITMENT
Blessings (`BLESSING(house)`) require standing with the patriarch/matriarch: their personal quest + a REP or FEUD condition. A blessed recruit arrives with house natives unlocked; an unblessed member of the same house arrives UNSANCTIONED ([[NP_07_HOUSES]] §5) — recruiting *around* the family is possible and the game acknowledges the tension in scenes.

## 4. ROSTER MANAGEMENT UI
The stable is the Old Gym locker room (diegetic menu): browse by House crest wall, Style, Element, bond web, or slot-role. Comparison card: stats, techniques, trait, dialect, bond lines. Release (rare, reversible for 3 in-game days) frees cap space — released characters return to their district, remain re-recruitable, and remember (a small grudge/warmth flag; people aren't cartridges).

## 5. BOND SYSTEM — KIZUNA

### 5.1 Growth sources
| Source | Kizuna pts |
|---|---|
| Spar together (either side of glove) | +3 |
| Adjacent rotation slots in a dual | +5 (win: +8) |
| Overworld squad together (per story beat) | +2 |
| Shared training slot | +3 |
| Bond scenes (authored, threshold-triggered) | +10 |
| ALLIED houses modifier | ×1.25 · Open Door trait: ×1.5 |

### 5.2 Levels & effects (pairwise, 0–5)
| Lv | Name | Effect (active when relevant) |
|---|---|---|
| 1 | Gymmates | Barks unlock |
| 2 | Corner Voices | If A fights and B is dressed: A +2% all stats |
| 3 | **Adjacent Trust** | Adjacent rotation slots: both +5% stats; relay CHARGED threshold for the pair −5 ([[NP_05_TENSION_HISSATSU]] §6) |
| 4 | Duo | Named duo T3 unlocked (afterimage variant); 2v2 exhibition duo hissatsu |
| 5 | **Sworn** | Inheritance transformation between the pair unlocked ([[NP_09_TRANSFORMATIONS]] §5); cross-house pairs: hybrid research opens (§6) |

### 5.3 Anti-grind valve
Kizuna from repeatable sources soft-caps at +15/day per pair; scenes and duals bypass the cap. Bonds are meant to accrete across a playthrough, not be farmed in an evening.

## 6. CROSS-HOUSE HYBRID RESEARCH (the melting-pot combo system)
Requirements: a Sworn (Lv5) pair from different houses, each with ≥1 native technique learned, + a **Forge event** at the gym (Beans + Spirits cost + a scene). Output: a hybrid T3 unique to that *pair* (name generated from both house motifs; effect composed from both native families' effect tags; both fighters can cast it, strongest when relayed between them). Launch ceiling: 8 hybrids per save (scarcity keeps each one a saga). The Toronto academy's industrialized counterpart: [[NP_07_HOUSES]] §10.

## 7. THE BOND BOARD — the Gym Wall
A literal wall in the Old Gym, and the bond system's UI:
- **Cards** for every stablemate, physically placed by the player; proximity on the wall = default adjacency *preference* auto-suggested in the formation screen ([[NP_10_TACTICS]] §2) — decorating IS planning.
- **Kizuna lines** drawn between cards fill as meters grow; Sworn lines gild.
- **Decorations** (fight posters, polaroids from bond scenes, ticket stubs, hand-wrap graffiti) unlock from play and are freely arranged. Pure expression, zero stats — the scrapbook half of the mechanic, kept sacred from optimization.
- Photo mode on the wall; the wall appears in cutscenes as it currently exists (player decoration canonized into the story's set dressing — cheap, devastatingly effective ownership).

## 8. COLLECTION SURFACES SUMMARY
Stable roster (people) · String Wall (leads & maps) · Scout Book (patterns, [[NP_02_TWO_LAYER]] §3) · Gym Wall (relationships) · Technique library ([[NP_11_PROGRESSION]] §8) · House codex (crests, founding stories, feud graph — fills as houses are encountered). Six collections, one loop: *fight → learn → befriend → own → combine.*

## 9. TARGETS
Ship: 300+ recruitables (60 named-with-scenes, 240 assembler-backed), 14 houses fully authored, 6 connection maps, 30 bond scenes, 8 hybrid slots. Post-launch growth path toward the 1000-class number: new districts ship as recruit ecosystems, not just levels ([[NP_13_SCOPE]] §8).
