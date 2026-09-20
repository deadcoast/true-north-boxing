# NP-04B — ARC 2/3 BOSS ROSTER: The Final Thirteen

**Project Northpaw design vault · Completes the 24-boss ship target ([[NP_13_SCOPE]] §1) · Vault v1.6**
Related: [[NP_04_OPPONENT]] · [[NP_04A_BOSS_ROSTER_ARC1]] · [[NP_05A_HISSATSU_LIBRARY]] §3 (syndicate set) · [[NP_07A_HOUSE_QUESTLINES]] · [[NP_12_NARRATIVE]] §5–§6

Six Hollow Circuit bosses (Arc 2) and seven worlds bosses (Arc 3), all to the [[NP_04_OPPONENT]] §7 template. Arc 2 fights run under **Blind-dual rules** ([[NP_01_SPORT]] §8): no scouting, no slot reveals, and — new rule, this arc's teeth — **PI applies at 0 regardless of what the player has earned**, because the syndicate's dialects are stolen and reassembled; the fights are readable only through live tells, the skill Arc 1 spent 11 bosses building. Every syndicate move cast below already exists in `data/hissatsu_library.v1.json`. The seven worlds desperations are spec'd here and enter the library as v2 under PAC-047 (library law: growth past 80 is a PACER task, [[NP_05A_HISSATSU_LIBRARY]] §1).

This doc also commits the Commissioner's identity, which [[NP_12_NARRATIVE]] §5 left as design space. It is committed here because six fights hang off it: **the Commissioner is Cal, the protagonist's uncle — Whitlock's best friend, the sealed house's fighter from 1998.** The DQ cover-up declared him dead; the CRBF erased the house to bury the fix; he built the Hollow Circuit to prove technique survives erasure — lineage extracted, because his own was. Every syndicate design choice below is one of his arguments.

---

## ARC 2 — THE HOLLOW CIRCUIT

### 12. "THE CARTOGRAPHER" (HC-4) — Hollow Circuit, R1 Opener *(Arc 2 opening dual)*

Out-Boxer · Gale · house UNKNOWN (mask, no crest). *Philosophy: "Your book is my book."*
The Blind-dual thesis statement: he opens with three different erased houses' tell dialects, one per phase — dialects in nobody's Scout Book.

```
BOSS HC4_Cartographer
  PHASE 1 [dialect: erased house "Calloway"]: 
    STRING S1 "Survey": TELL(chin_tuck_double, 500ms) -> JAB -> JAB -> STEP_OUT
    STRING S2 "Plot":   TELL(chin_tuck_double, 500ms) -> COUNTER_R_STR
  PHASE 2 @ composure<70% [dialect: erased house "Berube"]:
    STRING S3 "Traverse": TELL(heel_lift, 480ms) -> ANGLE_STEP -> L_HOOK
    STRING S4 "Contour":  TELL(heel_lift, 480ms) -> LT_R_HOOK
  PHASE 3 @ composure<40% [dialect: erased house "Oduya"]:
    STRING S5 "Redline": TELL(glove_grind_audio, 450ms) -> RUSH(0.8m) -> 3-hit string
  SELECT per phase: even weights - he is a survey, never a personality
  INTERRUPT: all strings during TELL -> stagger(800ms)
  BAIT: none  |  PUNISH: player_passive>6s -> current phase's fastest string
  DESPERATION @ composure<20%: "Hollow Echo" (library) - recasts the last hissatsu the PLAYER used, hollow-mixed
```

Same-tell/different-string pairs (S1/S2, S3/S4) are the phase puzzle: the tell says *when*, live read says *which*. **Remix:** none — he never rematches; the Scout Book page stays half-blank, on purpose. **Recruitment:** none. **Lesson:** live-read discipline with PI stripped; three erased house names enter the record — the arc's mystery given surnames.

### 13. RÉMY MOREAU — Hollow Circuit, R2 *(Q-MOREAU beat 2, [[NP_07A_HOUSE_QUESTLINES]])*

Slugger · Frost · House Moreau — the cousin who signed. Unmasked; the only syndicate fighter who shows his face, because shame needs witnesses. *Philosophy: "They were never going to teach me anyway."*
Fights the Moreau kit with the extraction's fingerprints: Jean-Guy's exact strings ([[NP_04A_BOSS_ROSTER_ARC1]] §5, *Cold Forge/Quench/Ingot*) with the frost-breath tell **absent** — extraction copies the punch, never the breath. The dialect literacy the player built on Jean-Guy half-transfers: rhythms match, tells are gone.

- **DESPERATION:** "Extracted: Elevator" is the wrong family's move and he casts it anyway — the syndicate hands loaners to its signees; commentary catches the wrongness (**[FR]** Danielle: "Ce n'est pas un Moreau, ça.").
- **PUNISH:** player perfect-block streak ≥2 → *Quench* (inherited from the true kit). **BAIT:** casting any Moreau native at him forces *Ingot* — the real thing enrages him.
- **Remix:** post-Q-MOREAU, he returns player-side adjacent: his rematch is a *spar*, breath restored, taught back by Jean-Guy. **Recruitment:** through Q-MOREAU completion, arrives with `moreau_shame` flag scenes. **Lesson:** extraction's cost made playable — same punches, no soul, easier to beat; the player proves the arc's thesis with their hands before the story states it.

### 14. "CHOIR" (HC-9) — Hollow Circuit, R3 *(mid-arc)*

Swarmer · Frost · house UNKNOWN. *Philosophy: silence — Choir has no recorded voice.*
The audio-channel horror fight. Casts **"Erased Name"** (library) on hit: commentary loses the ability to say names for 4 s — the teaching channel, Arc 1's constant companion, goes intermittently mute. Gord and Danielle audibly fighting it is the scene.

```
BOSS HC9_Choir
  IDLE: advance_noiseless (footwork audio stripped - the Marta silence, weaponized full-time)
  STRING S1 "Verse":   TELL(shoulder_breath_visual, 450ms) -> JAB -> LT_L_HOOK
  STRING S2 "Refrain": TELL(shoulder_breath_visual, 450ms) -> JAB -> JAB -> R_UPC
  STRING S3 "Hymn" [ARMORED]: TELL(full_stop_1000ms) -> WALK_STRING(2 hooks)
  SELECT: w(S1)=45, w(S2)=40, w(S3)=15
  INTERRUPT: S1,S2 during TELL -> stagger(800ms)
  BAIT: none  |  PUNISH: player_reliance_on_audio (audio-cue assist users): S1/S2 weights swap for 10s
  DESPERATION @ composure<25%: "Erased Name" empowered - 8s mute + tell_jam_audio
```

All tells visual by construction — the fight is beatable with sound off, and says so to accessibility players by existing. **Remix:** Arc 3 cameo, unmasked, recruited by *Sam* (the quiet corner recognizes its own — Q-TAGAQ's junior thread pays here). **Recruitment:** Arc 3, `BOND(Sam,4) AND QUEST(choir_name)` — learning their name is the quest. **Lesson:** visual-channel mastery; the commentary's value taught through its absence.

### 15. "SURETY" (HC-0) — Hollow Circuit, R5 Anchor *(pre-finale dual)*

Boxer-Puncher · Granite · house UNKNOWN. *Philosophy: "The debt always transfers."*
The **migrating Wall Gauge** boss ([[NP_12_NARRATIVE]] §5): casts **"Migrant Wall"** (library) — 60-pt gauge that, when broken, migrates to the next syndicate fighter *in a later segment* at 40 pts. Breaking it early means fighting its remainder later; leaving it whole means facing it at full strength at the anchor slot. The dual becomes a resource-routing problem across segments — the tactics layer's Arc 2 exam ([[NP_10_TACTICS]] §4 "Save the bar" call finally has a mirrored enemy version).

- Strings: patient Granite kit (3 strings, Standard tells); the fight's difficulty lives in the gauge math, never in unreadable offense (D3 holds even here).
- **DESPERATION:** none — like Sam, the wall is the argument. The homage is structural and the commentary names it: "We've seen this patience before, eh Gord? Colder, though."
- **Remix:** finale rematch fields TWO gauges. **Recruitment:** none. **Lesson:** cross-segment resource routing; Sam's anchor lessons, inverted against the player.

### 16. "THE ECHO" (HC-7) — Hollow Circuit, R4 Hammer *(finale undercard)*

Slugger · Granite · house: **Iron, extracted.** *Philosophy: none of its own — that is the horror.*
Fields **Iron Doctrine** — the dead lineage's SECRET, extracted from the same archives the player may have excavated in Q-IRON. If Vera Iron is recruited, she is dressed for this dual by story force, and her corner barks carry the fight; if she isn't, the dual seeds her questline in reverse.

- Pattern: Iron-style armored haymaker kit reassembled by the syndicate — fair-windup floors respected, but string *transitions* are 100 ms too clean, machine-spliced; Priya's Scout Book note says exactly that, and the too-clean gap IS the punish window (authored: 500 ms OPEN after every second string).
- **DESPERATION:** "Borrowed Blood" (library) — steals the player's CHARGED relay on hit; protect the chain or feed it.
- **Remix:** none — beating it retires *Iron Doctrine* from syndicate hands permanently (content consequence: the extracted copy leaves the game's enemy pool; Vera's is the only one left). **Recruitment:** none. **Lesson:** relay protection; the difference between inherited and spliced, rendered as a 100 ms gap you can hit.

### 17. THE COMMISSIONER — CAL [SEALED] — Arc 2 final boss, R5

Boxer-Puncher · Frost · **the sealed house, at full power.** *Philosophy: "They erased us. I kept every page."*
The first time the player sees their own house fought — natives *[SEALED-NATIVE-1/2]* cast by the man they belong to, before the player has them ([[NP_07_HOUSES]] §7 unsealing lands in this dual's aftermath). Whitlock works the player's corner and calls Cal's tells from 1998 memory — **corner-call assists replace the Scout Book for this one fight**, the game's two eras of friendship facing each other across the ring.

```
BOSS Commissioner_Cal
  PHASE 1 "TheArgument": sealed-house kit, Subtle tells (breath-pause before entries, 480ms)
    - strings named for CRBF regulation numbers he was erased under: "Article 12", "Schedule C"
  PHASE 2 @ composure<60% "TheMemory": tells LOUDEN one tier - Whitlock's corner calls land earlier and Cal
    hears them; he starts answering Whitlock mid-fight (dialogue inside segments, a first)
  PHASE 3 @ composure<30% "TheAsk": pattern degrades deliberately - SELECT weights drift toward the strings
    Whitlock names, as if being recognized matters more than winning
  DESPERATION @ composure<20%: "The Commissioner's Due" (library) + [SEALED-SECRET] armed but NEVER cast
    - he arms it, holds it, lets the bar drain. The move waits for the player's Arc 3 trial. Authored refusal
  BAIT: none  |  PUNISH: player_hissatsu_arm_feint -> immediate counter (no theatre in this ring)
```

The dual is winnable straight ([[NP_04A]] §8 rule: no robbery inside the ropes; the *arc* resolution is scripted around either outcome). **Remix (Arc 3):** he corners for Team Canada; his "rematch" is the Manifest Clash training gauntlet he runs. **Recruitment:** staff, Arc 3 — Tactician-class, the Scout Book's final expansions are his pages. **Lesson:** everything; and the sealed house arrives as a person before it arrives as a power-up, which is the only order Doctrine D5 permits.

---

## ARC 3 — TRUE NORTH: WORLDS

International clubs enter as visiting philosophies under the same [[NP_07_HOUSES]] §9 consultation standard. Five of seven connect to Canadian houses' origin currents — the melting pot's return tide. Worlds duals restore full PI rules; these are honest fights at the highest floor. Desperations marked **[v2]** are spec'd here, library-landed under PAC-047.

### 18. DESHAWN "TURNPIKE" VAUGHN — Interstate AC (USA), R1

Swarmer · Gale. *Philosophy: "Volume is a skill."* Opening-bell pressure: his SELECT has no idle weight — he is always mid-string, and the neutral game the player knows disappears. Tells ride his gum-chewing tempo (audio, Standard): the chew stops half a beat before every level change. **PUNISH:** any player back-step chain ≥3 → corner-cut rush. **DESPERATION:** "Rush Hour" **[v2]** (T1 PISTON Gale: 5-hit volume string, each hit −1 player guard regen for 3 s). **Lesson:** defending without a neutral reset; Carter's third-period lesson at world tempo.

### 19. ITZEL REYES-ORTEGA, "LA CATEDRAL" — Club Campana (Mexico), R4

Slugger · Granite · the Reyes house's origin line — the great-grandfather's gym still stands and she runs its corner's bell. If any Reyes is in the player's stable, the pre-dual scene is the two bells rung together. *Philosophy: "The body is the truth; the head just files the paperwork."* Pure body doctrine: her strings target torso 80/20, inverting eleven bosses of head-first reads. **BAIT:** high guard held ≥3 s → *Campanada* body cross under the elbows. **DESPERATION:** "La Catedral" **[v2]** (T1 ARC Granite: three-station body series; each station lands −8 stamina — the gassed-curve fight). **Recruitment:** none; she gifts the Reyes stable a technique instead ([[NP_07_HOUSES]] §4 gift ceremony, international edition). **Lesson:** body defense, the guard's blind floor.

### 20. SORA KANNAGI, "THE LIBRARY" — Kanto Gakuin (Japan), R2

Out-Boxer · Frost. *Philosophy: "Everything you have done, someone has done better, and I have read about it."* Fundamentals at maximum: no gimmick, no phase mechanic — Loud-to-Standard tells, textbook strings, every value tuned to the top of the fair range. The design's control group: the boss who proves the base game is the hard game. **DESPERATION:** "Fudōshin" **[v2]** (T2 WALL Frost: 4 s immovable-mind wall; counter-state on break attempt). **Remix:** her rematch adds nothing and tightens nothing — identical, and harder anyway because the player has changed. The Scout Book page says only: *complete.* **Lesson:** mastery without novelty; the humility fight.

### 21. ALFIE CRANE, "THE SCAFFOLD" — Millwall Boxing Club (UK), R3

Swarmer · Timber. *Philosophy: "Fights are won where it's ugly."* Clinch-and-ropes specialist: his herding is the best in the game (+75% push), and his clinch-win rate turns every rope visit into position loss. Referee-warning flirtation per [[NP_01_SPORT]] §5 — he banks exactly two warnings, never the third, and the count is on the score bug. **PUNISH:** player clinch-input spam → over-under reversal, corner placement. **DESPERATION:** "Last Orders" **[v2]** (T1 HAYMAKER Timber: rope-zone only, ×2.6). **Lesson:** clinch mastery, warning-count literacy, winning ugly.

### 22. YORDANIS BARÓ, "EL PROFESOR" — Escuela Nacional (Cuba), R2

Out-Boxer · Gale · the system House Petrov descends from — Petrov's patriarch trained under his teacher, and the pre-dual scene is the two of them arguing pedagogy in two languages while their fighters warm up. *Philosophy: "I am not fighting you. I am correcting you."* His PUNISH set is the game's largest (5 hooks): every player mistake class has an authored answer, and commentary names the correction each time — the fight is a lesson delivered at full hostility. **BAIT:** perfect play for 15 s forces *Examen* (his one Loud string) — excellence is the only thing that draws him out. **DESPERATION:** "Graduación" **[v2]** (T1 RISE Gale: cast only after his Examen lands; if the player never eats Examen, the desperation never comes — a boss whose ceiling the player controls). **Lesson:** the full mistake taxonomy, mirrored.

### 23. CHIAMAKA OKAFOR, "HARMATTAN" — Surulere BC (Nigeria), R4

Swarmer · Gale · the Okafor root line, Lagos. Ada and Carter's second cousin; the three-sibling table scene ([[NP_07A]] Q-OKAFOR) gets its international leaf, and the duo/relay flags between the three Okafors light up if she is ever recruited (post-game). *Philosophy: "Pressure is the family language; I speak it first."* The pressure line at its source: her metronome is *polyrhythmic* — two overlapping attack tempos (600/900 ms), and the tell is which foot carries the beat. Desync mechanics from Ada apply at half value; her rhythm reforms in 1.5 s. **DESPERATION:** "Harmattan" **[v2]** (T1 ARC Gale: dust-wind flurry, tell-jam visual 2 s). **Lesson:** compound rhythm reading — Ada's exam, senior paper.

### 24. IOAN VASILE, "THE STANDARD" — Meridian Institut (Europe), R5 — Arc 3 final boss

Boxer-Puncher · element rotates by segment clock · no house: Meridian abolished lineage intake entirely — Vey's thesis, industrialized continent-wide, a generation ahead. *Philosophy: "We measured everything. Sentiment did not correlate."*
The final exam is Anders' fight at world scale, with the correction the story spent three arcs earning: **Vey is in the player's corner** — Ascendant absorbed into Team Canada ([[NP_12_NARRATIVE]] §6's strongest version, committed), and the counter-picking coach who beat you at Nationals now reads Meridian's order for you. Enemy coach vs. reformed coach is the tactics layer's last fight, running under the player's dual.

```
BOSS Vasile_Ioan
  CLOCK PHASES (by segment time, Sam's clock-scaling at final-boss size):
    0-30s  [FROST kit]:   counter suite, Subtle breath tells
    30-60s [GRANITE kit]: armored advance, Standard tells
    60-90s [GALE kit]:    volume close, tempo tells
  All three kits are SYNTHESIZED CORRECTLY - no dialect flaws, the Anders tell-errors solved.
  The read that remains: the SEAMS. Each kit swap has a fixed 700ms neutral reset, and Vey calls
  every swap from the corner 2s early ("Standard's turning granite - NOW").
  BAIT: none  |  PUNISH: full taxonomy (Baró-class hook set)
  DESPERATION @ composure<25%: "The Mean" [v2] (T2 WALL, element-null: 5s wall that averages
    incoming damage across its duration - burst play feeds it, steady play starves it)
  FINALE @ composure<10%: pattern locks to pure fundamentals - Kannagi's lesson, cited by the
    design at the summit: when everything is stripped away, the base game is what remains
```

Transforms are live both ways; his authored T4 usage fires at the 50% mark, and weathering it ([[NP_09_TRANSFORMATIONS]] §7) earns the fight's hidden achievement. **Remix:** Title Defense runs the full remix gauntlet with him at its gate. **Recruitment:** none. His post-dual line, the series thesis answered: he asks — first question he's asked anyone — what the corner-shouting was like. **Lesson:** all of it, under a clock.

---

## ROSTER LEDGER — SHIP TARGET CLOSED (24/24)

| Arc | Bosses | # |
| --- | --- | --- |
| Arc 1 ([[NP_04A]]) | Vane, Yuri, Moira, Tam, Carter, Moreau, Efua, Marta, Sam, Ada, Anders | 11 |
| Arc 2 | Cartographer, Rémy, Choir, Surety, Echo, **the Commissioner** | 6 |
| Arc 3 | Vaughn, Itzel, Kannagi, Crane, Baró, Chiamaka, **Vasile** | 7 |

Coverage audit: styles ≥5 bosses each across the 24; all elements + rotating/null represented; tell channels — audio 6, visual-gear 3, visual-body 9, composite/structural 6; Blind-dual set fully visual-readable (accessibility holds where PI dies). All 6 library syndicate moves cast by name. New library needs: 7 worlds desperations + "Rush Hour"-class effects → **PAC-047** (library v2 amendment, spec'd inline above). Consultation-flagged content: Itzel, Baró, Chiamaka, Kannagi clubs (NP_07 §9 standard extends to visiting philosophies; PAC-038 gate). Commissioner identity committed: NP_12 §5's open design space is now closed, and Q-SEALED/E01 resolve against it with zero contradiction — the 1976 audio-hole, the scraped charter, Whitlock's fixed dual, and Cal are one record.
