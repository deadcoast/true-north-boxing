# PROJECT NORTHPAW — Game Design Specification v1.0
**Working title (placeholder). Genre:** Action-RPG / shonen sports. **Sport:** North American boxing, rotation team format. **Setting:** Canada.
**Formula:** `INAZUMA ELEVEN (loop) + PUNCH-OUT!! (staging & opponent souls) + FIGHT NIGHT CHAMPION (hands) + NARUTO/DEMON SLAYER (houses & lineage) + CANADA (story)`

---

## 0. DOCTRINE — Non-Negotiable Design Pillars

| # | Pillar | Rule |
|---|--------|------|
| D1 | **Never sand it down** | Twelve-year-olds throw arena-freezing haymakers on national TV, played dead straight. No winking, no "realism" passes. (Hino doctrine.) |
| D2 | **The opponent is the screen** | Fixed Punch-Out POV. Nothing may ever block reads. Every system's VFX must respect tell visibility. |
| D3 | **They're predictable; you can't be** | Opponents run authored, learnable patterns. The player is punished FNC-style for repetition. This asymmetry IS the combat game. |
| D4 | **Three sizes of the sport** | Scrap (snack) / Spar (meal) / Dual (feast). Same verbs at every scale. Grinding never fatigues. |
| D5 | **Friendship is literal mechanical power** | Shared Tension, bond buffs, relay hissatsu, inheritance transforms. Every emotional beat has a mechanical body. |
| D6 | **House style is inherited; the fighter is an individual** | Family culture carries the fighting tradition (Naruto-clan model). Writing keeps every fighter a distinct person inside their lineage — celebration, never caricature. |
| D7 | **Clubs are mixed by default** | Every roster looks like a Canadian classroom. Houses live everywhere; clubs draw from all of them. Ambient, unremarked diversity. |
| D8 | **No feature removal for simplicity** | Complexity is layered, gated by arc, never amputated. |

---

## 1. THE SPORT — Rotation Team Boxing

Invented sport, presented as a national institution. Televised school duals, seventh-graders as household names. Nobody explains why. It's shonen.

### 1.1 Match Format ("DUAL")
- Two clubs, one ring. **5 rotation segments** (R1–R5), fought consecutively, cumulative team score.
- **Dressed squad: 8** fighters per dual (from club stable, cap 100). **Lineup: 5** rotation slots. 3 reserves swappable during corner phases.
- **Slot R5 = ANCHOR** — the keeper analog. Defensive specialist, iron chin, guard-wall hissatsu. Protects leads / completes comebacks.
- **Segment length:** 90 seconds real-time. **Corner phase** between segments: 45 s tactics window (pausable menu over diegetic corner scene).

### 1.2 Scoring
- **DROP (the goal analog):** any knockdown scored = **1 point**. Flash knockdown off a full counter = **2 points**. In-segment KO = **3 points** + opponent's slot forfeits remaining segment time.
- Match winner = most DROPS after R5. Tiebreak ladder: (1) segment wins on exchange points, (2) total clean counters, (3) **sudden-death overtime segment** — both clubs send any dressed fighter, first DROP wins (golden goal).
- Exchange points accrue continuously (clean hits, counters, ring control) — they win segments, feed Tension, and decide tiebreaks, but DROPS are the scoreboard drama.

### 1.3 Ring Geography (the stakes gradient)
| Zone | Role | Effects |
|------|------|---------|
| **Center ring** | Neutral third | +Tension generation on exchange wins; standard damage |
| **Ropes** | Attacking/defending third | +25% damage both ways; knockdown thresholds lowered; cut-off mechanics active |
| **Corners** | Goalmouth | Double-or-nothing: +50% damage, guard decays 2×, flash-counter windows widened for the trapped fighter (desperation reads) |

Cutting the ring = advancing into the attacking third. Ring generalship is the positioning meta-game that decides which exchanges matter.

---

## 2. TWO-LAYER STRUCTURE

### Layer A — Overworld (Action-RPG)
Roam a Canadian hockey town with a squad of 4 (captain always present). School halls, community centre, strip-mall gym, winter streets, rinks you're not welcome at. NPCs, side quests, recruitment leads, training spots, story triggers, item pickup, gacha scouting machines.

### Layer B — The Ring, three sizes (D4)
| Size | Name | Duration | Content | Rewards |
|------|------|----------|---------|---------|
| Snack | **SCRAP** | 15–30 s | Overworld encounter, 1v1, one micro-objective ("land 3 body shots", "make him miss twice", "survive"). Full FNC controls. Can flee w/ small rep loss. | XP trickle, Prestige, item drops, pattern recon |
| Meal | **SPAR** | 1 full segment (90 s) | Replayable vs. any met club. Lab space for new techniques. | Big XP, Spirits, bond growth |
| Feast | **DUAL** | Full 5-segment match | Story boss. Cutscenes, rival philosophy, stakes. | Story progress, recruitment unlocks, Spirits, rarity mats |

**Recon rule:** tell-reading skill transfers between layers. Scraps against a club's students teach you their House/Style pattern-language cheaply before the dual. The overworld is reconnaissance.

---

## 3. COMBAT ENGINE — "The Hands" (Fight Night Champion verb set)

### 3.1 Camera & Staging (Punch-Out staging, D2)
- Fixed camera behind + above the player fighter. Opponent faces screen, full-frame, **the billboard for tells, hissatsu wind-ups, and transformations**.
- Player fighter rendered small-stature / partial silhouette (~35% frame height, low-alpha below shoulders during opponent wind-ups). Modern answer to the NES wireframe: readable self-state, zero read obstruction.
- Camera holds/zooms are reserved for: DROPS, hissatsu execution, transformations, standing-eight. Never during neutral.

### 3.2 Input Map (default gamepad)
| Input | Action |
|-------|--------|
| **RS flick** | Punch. Angle = punch type: up = straight, up-diag = flared straight/overhand, side = hook, down-diag = hookercut, down = uppercut. Left/right side of stick = left/right hand |
| **RS pull-back → forward** | **Haymaker** motion (power version; stagger/drop potential; heavy stamina; telegraphs) |
| **LS** | Movement / ring positioning |
| **LT (hold) + LS** | Lean modifier: slip left/right, duck; plants feet (trades movement for evasion). Quarter-circle toward opponent = weave |
| **LT + RS** | Body punches |
| **RT (hold)** | Block (auto-guard seeks incoming punch; governed by BLK + guard meter decay) |
| **RT + RS** | Punch out of block (fast defense→offense transition) |
| **RB (hold) + RS** | Power punch modifier (harder, opens you to counters, drains stamina) |
| **LB** | Hissatsu arm (see §5.3) |
| **D-pad** | Taunt / callouts / relay signal |
| **LS toward out-of-range opponent + punch** | Stepping punch (auto; more weight, more telegraph) |

### 3.3 Defense & Guard Model
- **Guard meter** per fighter: decays while RT held and per punch absorbed; regenerates when guard is down. Punches begin penetrating a broken guard. BLK stat sets capacity + regen; RFX sets auto-guard tracking quality.
- **Head movement is free but skill-priced:** slips cost nothing on success; mistimed slips eat the full punch (Punch-Out risk pricing). Blocking always leaks chip damage + guard meter.

### 3.4 Tempo Engine (the FNC trinity)
1. **Counter economy:** blocks, slips, weaves, and steps each open a brief counter window; a perfect-timed block opens the widest. Counter hits deal bonus damage and are the premium Tension source.
2. **Stamina = universal currency:** every punch, slip, sprint, and hissatsu draws from stamina; stamina scales damage, hand speed, foot speed, and recovery. Regenerates between exchanges, refills partially at corner phase.
3. **Anti-pattern pressure (D3):** an **Adaptation tracker** watches the player's punch-mix and rhythm; repeated sequences get slipped/countered by any opponent at increasing rates. Opponents themselves run authored patterns and do not adapt their own offense — they adapt only their *defense to you*.

### 3.5 Exchange State Machine
```
NEUTRAL ──(proximity/engage)──► EXCHANGE ──► [outcomes]
  EXCHANGE outcomes:
    clean hit(s)        → exchange points, Tension, damage
    perfect read (tell) → FLASH-COUNTER WINDOW → stun state → free-hit string
    guard break         → OPEN state (defender) → big-damage window
    clinch trigger      → CLINCH SCRAMBLE (stick-mash + timing duel; winner gets position or reset)
    knockdown threshold → DROP → STANDING-EIGHT
STANDING-EIGHT: slowed time, HRT-gated rhythm input check (the penalty-kick moment).
  pass  → fight resumes, temporary vulnerability
  fail  → segment KO
CORNER TRAP: entered when pinned in a corner ≥3 s → all corner-zone modifiers active until escape (weave-out, clinch-win, or counter).
```

---

## 4. OPPONENT ARCHITECTURE — "Their Brain" (Punch-Out souls)

- **Every named rival is a hand-authored pattern boss.** Unique attack strings, visual/audio **tells** (the tell IS the character: the Québécois technician's glove micro-adjustment; the Prairie slugger's freight-train shoulder load), interrupt windows (fast clean hit inside the window breaks the string → Tension bonus), and per-round phase changes.
- **Rematch remixing:** returning rivals gain feints, faster recoveries, shrunk interrupt windows — the Punch-Out circuit-escalation model.
- **Pattern grammar is House-derived** (§6): all fighters of one House share a tell *dialect*; individuals speak it differently (D6). Learning a House pays off across every fighter in it — the knowledge-collection loop.
- Generic/no-name opponents (scraps, filler slots) are assembled from a pattern-piece library tagged by Style+House.

---

## 5. TENSION & HISSATSU — Resource Economy

### 5.1 Tension (shared team meter, 0–100, persists across all 5 segments)
| Earned by | Amount |
|-----------|--------|
| Clean counter hit | +3 |
| Perfect slip / perfect block | +2 |
| Interrupt-window break | +5 |
| Exchange win in center ring | +2 |
| DROP scored | +10 |
| Surviving standing-eight | +8 (crowd surge) |
| Corner-staff hype action | +variable |

Never earned by punch spam (Adaptation-flagged sequences earn 0). **Your opener grinding a losing segment still banks meter for the closer** — the mechanical spine of D5.

### 5.2 Hissatsu Tiers & Costs
| Tier | Type | Cost | Notes |
|------|------|------|-------|
| T0 | **Signature** (named jab/counter quirk) | 10 | Per-fighter identity move; near-spammable |
| T1 | **Super** (named power technique) | 35 | Camera hold, arena FX |
| T2 | **Guard-wall / defensive** | 25 | Anchor specialty: impossible slips, granite guard, "our house never goes down twice" |
| T3 | **Relay / combination** | 50 | Requires banked relay state (§5.4) or bonded adjacency (§8) |
| T4 | **Transformation** | 100 (full bar, consumed) | See §9. Comeback drama by design |

### 5.3 Execution rule
Hissatsu are **FNC motions performed with LB armed**: e.g., haymaker motion + LB at ≥35 Tension = the fighter's T1 super, not a haymaker. No QTE menus — the hands you trained are the spellbook. Motion-family per hissatsu is defined in its schema (§11.3).

### 5.4 The Relay (passing, translated)
A fighter ending their segment with surplus Tension contribution above threshold banks a **CHARGED** state that passes to the next fighter out. Charged fighters: T3 relay hissatsu unlocked, first hissatsu discounted 50%, entrance buff (10 s stat surge). Chain across 3+ consecutive segments = **FULL RELAY**: the anchor/final fighter's T4 cost drops to 75. Shot-chain fantasy, rotation-shaped.

### 5.5 Anchor-Gauge Bosses
Boss anchors carry a visible **Wall Gauge**: they cannot be dropped until it's ground to zero via clean hits/counters/guard breaks. Attrition puzzle, not RNG wall — the unbeatable-keeper drama.

---

## 6. AFFINITY STACK — Three Rings

Matchup math resolves **Style → Element → House**, multiplicatively, each ring a modest modifier (target: skill always beats math; math decides even fights).

### Ring 1 — STYLE (mechanical triangle)
`SWARMER → beats OUT-BOXER → beats SLUGGER → beats SWARMER`; **BOXER-PUNCHER** = flexible neutral (no bonus, no penalty, widest technique access).
Style modifies real sim parameters:
| Style | Parameter edits |
|-------|----------------|
| Swarmer | Inside hooks −20% stamina; clinch-scramble bonus; range penalty |
| Out-Boxer | Stepping jab +range; movement stamina −15%; guard capacity −10% |
| Slugger | Power punches break guard +30% faster; hand speed −10% |
| Boxer-Puncher | No edits; may equip one off-style passive |

Advantage grants +10% exchange points and widened counter windows vs. the disadvantaged style.

### Ring 2 — ELEMENT (shonen affinity, Canadian nature)
`FROST → beats GALE → beats GRANITE → beats TIMBER → beats FROST`
*(Deep cold stills any storm; wind erodes stone to sand; stone splits and crushes wood; living timber survives the longest winter.)*
Element matching between fighter and technique = **+30% hissatsu power** (the Inazuma same-element spike). Element advantage vs. opponent = +10% hissatsu effect. Cosmetically drives aura/VFX identity.

### Ring 3 — HOUSE (inherited technique lineage) — see §7.

---

## 7. HOUSES — The Lineage System

**The unit is the family** (D6, D7). Every notable fighter comes from a boxing house; every house carries a **named house style** — inherited technique family, stance quirks, signature hissatsu, secret moves, and a tell dialect (§4). House styles flow organically from each family's own history and culture — one traces to a great-grandfather's ring career abroad, another was invented by a grandmother who fought in Saskatchewan barns, another came out of a father's failed pro run. A hundred houses, every background, every neighbourhood: **that's the melting pot.**

### 7.1 House grants
- **Native technique family:** hissatsu learnable only by blood/adopted members (the four-generation liver shot; the family counter-stance).
- **House trait** (passive): e.g., "never dropped twice in one segment," "+guard regen when trailing."
- **Tell dialect** for all house members (recon value compounds).
- **Feud/alliance graph:** decades-old house rivalries and debts — story fuel and recruitment gates.

### 7.2 Character grammar (full Naruto toolkit)
Prodigies crushed by legacy; the daughter forbidden the family style who steals it anyway; the last member of a dead lineage; disowned heirs; **no-name kids with zero house outworking bloodline prodigies** (the eternal underdog seam); and the protagonist with a lost/hidden house — the Arc 2 reveal lives here.

### 7.3 Example houses (starter set — content team expands to ~40 named + generator)
| House | Region | Style bias | Element | Native family (sample) | Trait |
|-------|--------|-----------|---------|------------------------|-------|
| **Tremblay** | Montréal | Out-Boxer | Frost | *Doctrine Tremblay* — matador counter suite | Counter windows +15% when untouched for 10 s |
| **Okafor** | Toronto | Swarmer | Gale | *Okafor Pressure* — chained inside hooks | Stamina regen +20% in clinch |
| **Reyes** | Winnipeg | Slugger | Granite | *Reyes Liver Line* — body-attack finishers | Body damage ignores 25% of guard |
| **MacIsaac** | Cape Breton | Slugger | Timber | *Net-Hauler* — pull-counter overhands | +power in ropes zone |
| **Whitecloud** | Northern ON | Boxer-Puncher | Frost | *Long Winter* — endurance/late-round suite | All stats +10% in R4–R5 |
| **(Protagonist)** | — | — | — | **UNKNOWN — sealed** | — (Arc 2) |

### 7.4 Marriage-of-styles endgame
Two houses' techniques fused through max cross-house bonds (§8) = **hybrid hissatsu neither family could produce alone**. The melting pot as the literal final power tier — and the thing the Toronto final-boss academy has already industrialized (§10).

---

## 8. STABLE, RECRUITMENT & BONDS

### 8.1 The Stable (collection engine)
Club roster cap **100**; dress **8** per dual. Target recruit pool at ship: **300+** (v1; expandable toward the 1000-class number post-launch).
**Channels:** (a) post-dual recruitment — beaten rivals ask to join (*every enemy club is a booster pack*); (b) overworld scouting at community centres/schools, some condition-gated (beat them in a scrap, finish their quest, impress their coach, settle their house's feud with yours); (c) **connection maps** through trainers, families, house lineages (recruit the master → unlock three students); (d) gacha scouting machines fed by **Prestige** from scraps; (e) earning a house patriarch's blessing; recruiting the disowned heir.

### 8.2 Bonds
- Sparring, shared quests, adjacency in duals grow **Kizuna lines** between stablemates.
- **Adjacent rotation slots** with a bond: segment stat buffs, relay discount, duo callouts.
- **Cross-house bonds** unlock hybrid technique research (§7.4).
- **Bond board = the gym wall**: fight posters, polaroids, hand-wrap graffiti, player-decorated, mechanically live (placement = adjacency planning UI).

---

## 9. TRANSFORMATION TIERS (per-arc ceiling raiser)

| Tier | Name | Arc | Cost | Effect |
|------|------|-----|------|--------|
| 1 | **Hissatsu** | 1 | per §5.2 | Baseline named techniques |
| 2 | **In the Zone** | 1 (late) | 100 | Flow state: time dilation, auto-slip windows, stamina freeze, 20 s |
| 3 | **Spirit Manifestation** | 2 | 100 | Inner figure erupts behind the fighter (ancestor in old wraps / colossal animal / storm). Full Keshin analog: manifest clash sub-duel vs. opposing manifestations |
| 4 | **Inheritance** | 2 (late) | 100 + bond gate | Temporarily take on a stablemate's or departed mentor's house style mid-match. The guaranteed tear-jerker, as a mechanic |
| 5 | **Awakening** | 3 | 100 + story gate | Latent lineage fully realized; dual-house hybrid state; protagonist's sealed house opens here |

All transforms consume the entire team bar (comeback drama by design). Xenoverse-grade presentation: auras, screen shake, camera worship — played completely straight (D1).

---

## 10. TACTICS LAYER — The Coach Fantasy

- **Pre-dual formation screen:** lineup order vs. their projected order. Sending your matador against their bull is the affinity stack played before a punch is thrown. Scout reports (from scraps/staff) reveal enemy order confidence %.
- **Corner phase (45 s):** rotation swaps (Tension-costed after the first free swap), Special Tactics on cooldown (e.g., *Body Doctrine*: all body shots drain double stamina for one segment), one-per-dual **Super Tactic** (*Iron Resolve*: next fighter cannot be dropped for 30 s), cutman heal, tactician reveals opponent's next slot, hype-man converts crowd → Tension.
- **Staff slots (3):** coach, cutman, +1 specialist — passives and corner actives; recruitable like fighters.
- **Club progression:** gym facilities upgrade (bags → real ring → lights and cameras); facilities gate training minigame tiers.

---

## 11. CHARACTER PROGRESSION & DATA STRUCTURES

### 11.1 Stats → Sim mapping (stats physically alter the FNC sim)
| Stat | Governs |
|------|---------|
| **PWR** | Damage, guard-break force |
| **SPD** | Hand speed, foot speed, stepping range |
| **CHN** | Knockdown threshold, standing-eight base difficulty |
| **RFX** | Counter-window width, auto-guard tracking, slip forgiveness |
| **BLK** | Guard meter capacity + regen |
| **STA** | Stamina pool, drain rates, corner recovery |
| **HRT** | Standing-eight check bonus, trailing-score buffs, Tension gain when losing |

### 11.2 Growth systems
- XP levels (all three fight sizes feed it) + **Ability Board** per fighter (branching node board: stats, passives, technique slots, style-flex nodes).
- **Training Beans** from diegetic training minigames (mitts, heavy bag, roadwork through snow, tire-and-rope in a barn) → rank/stat raises.
- **Spirits** (dual/spar currency) → rarity-tier ascension.
- **Hot-Blood Points (HBP)** → buy techniques, items, accessories, special training.
- **Teachable techniques:** hissatsu transfer via masters, HBP, and teaching items. *Your day-one best friend is never obsolete* (D8-adjacent: no fighter is content-obsoleted).

### 11.3 Core schemas (implementation-ready sketches)
```jsonc
Fighter {
  id, name, age, school_club,
  house_id,            // null = no-name (underdog seam)
  style,               // SWARMER|OUTBOXER|SLUGGER|BOXERPUNCHER
  element,             // FROST|GALE|GRANITE|TIMBER
  stats: {PWR,SPD,CHN,RFX,BLK,STA,HRT},
  level, rarity_tier, ability_board_state,
  techniques: [hissatsu_id],      // includes taught/non-native
  native_family_unlocked: bool,
  bonds: [{fighter_id, kizuna_level}],
  tell_dialect_ref, pattern_ref,  // opponent-side use
  recruit_conditions: [...]
}

House {
  id, name, region, founding_story,   // family history drives flavor
  style_bias, element, tell_dialect,
  native_techniques: [hissatsu_id],
  house_trait, feud_graph: [{house_id, relation}]
}

Hissatsu {
  id, name, tier,                 // T0..T4
  motion_family,                  // FNC input motion that triggers it
  tension_cost, element, house_id?, style_req?,
  effect_block, camera_script, native_only: bool, teachable: bool
}

MatchState {
  segment_idx, clock, score: {home_drops, away_drops, exch_pts},
  tension: {home, away},          // shared team meters
  relay: {charged: bool, chain_len},
  lineups, zone_state, adaptation_tracker
}
```

### 11.4 Economy summary
| Currency | Earned | Spent |
|----------|--------|-------|
| XP | All fights | Levels |
| Spirits | Spars/duals | Rarity ascension |
| HBP | Story, quests, wins | Techniques, items, training |
| Prestige | Scraps, rep | Scouting machines |
| Training Beans | Minigames | Stat/rank raises |
| Tension | In-match play | Hissatsu/transforms (resets per dual) |
| Kizuna | Co-play | Bond tiers (meter, not spent) |

---

## 12. NARRATIVE ENGINE

### 12.1 Premise
A dying boxing club in a **hockey town**. All the funding, crowds, and arena ice-time belong to hockey. The club is one kid with too much heart, a condemned gym, and a survival dual against the elite academy — or the doors close. Endou's setup with a uniquely Canadian ache. Boxing is to this Canada what soccer is to Inazuma's Japan.

### 12.2 Arc structure (the formula, honored exactly)
- **ARC 1 — Provincial circuit.** Club survival → provincial Golden Gloves → nationals. Tiers 1–2 unlock. Rival clubs = themed bosses.
- **ARC 2 — The WTF arc.** The series-signature escalation: masked syndicate / ancient lineage conspiracy / the sealed-house reveal / go ahead and put the aliens here — Inazuma earned aliens by episode 27. Tiers 3–4 unlock.
- **ARC 3 — Worlds.** Team Canada assembled from every rival you've fought, every house in the stable, one corner. Tier 5. The Toronto academy's synthesized-curriculum thesis vs. your bonded melting pot.

### 12.3 Rival club parade (every club mixed-roster, D7; gimmick = training culture + geography + specialty)
| Club | Gimmick | Boss flavor |
|------|---------|-------------|
| Cape Breton Netmen | Train hauling fishing nets | Pull-counter sluggers, rope-zone monsters |
| Prairie Grain Kings | Hit like grain trucks | Guard-break doctrine, slow phase-change boss |
| Montréal Technique | Counter-punching curriculum | Matador anchor with a deep Wall Gauge |
| True North Club | Roadwork at −40 | Late-round stat surges, endurance war |
| Toronto Ascendant Academy | Every house's techniques, synthesized | Final boss: hybrid-style prodigies; the melting pot industrialized without the bonds |

### 12.4 Story/system unification
Recruited rivals become party members with arcs — collection and story are the same system. Post-dual cutscene → recruitment flag → overworld questline → bond content → dual adjacency payoff. Every narrative beat lands in a mechanic (D5).

---

## 13. SCOPE & PHASE BREAKDOWN (PACER-ready)

| Phase | Name | Delivers |
|-------|------|----------|
| P0 | Foundation | Doctrine lock, tech stack, vertical-slice definition, art bible (tell-readability standards) |
| P1 | Combat Core | Camera rig, input map, guard/stamina/counter sim, exchange state machine |
| P2 | Opponent Architecture | Pattern authoring toolkit, tell system, adaptation tracker, 3 hand-authored bosses |
| P3 | Match & Rotation | Segment/dual flow, scoring, Tension, relay, corner phase, anchor Wall Gauge |
| P4 | Progression & Affinity | Stats→sim mapping, ability boards, style/element/house rings, hissatsu execution |
| P5 | Stable, Bonds & Tactics | Recruitment channels, bond board, staff slots, formation screen, tactics |
| P6 | Overworld & Narrative | Town, scrap encounters, quest framework, Arc 1 script, rival club content |
| P7 | Content, Balance & Ship | House/roster content production, remix rematches, Arcs 2–3, balance, ship |

Full task register: `NORTHPAW_PACER.csv` (41 tasks, P0–P7, dependencies gated).

---

*v1.0 — foundation locked per the corrected house model: family-based lineage, heritage-flavored per family history, mixed clubs everywhere, individuals inside traditions.*
