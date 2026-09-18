# NP-01 — THE SPORT: Rotation Team Boxing
**Project Northpaw design vault · Doc 1/13**
Related: [[NP_02_TWO_LAYER]] · [[NP_03_COMBAT_ENGINE]] · [[NP_05_TENSION_HISSATSU]] · [[NP_10_TACTICS]] · [[NP_12_NARRATIVE]]

This document is the complete rulebook of the invented sport — everything a broadcast commentator, a referee AI, or a systems programmer needs. The sport is fictional but must feel *sanctioned*: consistent rules, a governing body, a season structure, and a broadcast grammar. Inazuma never explains why seventh-graders play televised nationals; neither do we. But the sport itself is airtight.

---

## 1. THE FICTION OF THE INSTITUTION

**In-world name:** *Rotation Boxing*, colloquially **"Rotation"** or **"the Rote."** Governing body: the **CRBF (Canadian Rotation Boxing Federation)**, founded in-fiction 1967 (Centennial year — the sport as a national project). School clubs compete in the **Scholastic Circuit**; the pro tier exists off-screen as aspiration (Arc 3 territory).

**Broadcast grammar** (drives UI and presentation everywhere):
- Every dual has an announce pair: play-by-play + a colour commentator who reads House/Style matchups aloud (this is how the game teaches the affinity stack — see [[NP_06_AFFINITY]]).
- On-screen **score bug**: club crests, DROP count, current segment (R1–R5), segment clock, shared Tension bars.
- Crowd is a system, not wallpaper: crowd heat feeds corner hype actions ([[NP_10_TACTICS]] §6).

**Season structure (Scholastic Circuit, Arc 1):**
| Stage | Format | Stakes |
|---|---|---|
| Exhibition duals | Challenge matches, any time | Rep, recruitment flags |
| **Regionals** | Round-robin pools of 4 clubs | Top 2 advance |
| **Provincials ("Golden Gloves")** | Single-elim bracket of 8 | Champion + runner-up to Nationals |
| **Nationals** | 16-club bracket, televised | Arc 1 finale |

---

## 2. MATCH DEFINITION — THE DUAL

A **DUAL** is one match between two clubs. Canonical structure:

| Parameter | Value | Notes |
|---|---|---|
| Rotation segments | **5** (R1–R5) | Fixed for sanctioned duals; story/exhibition duals may run 3 |
| Segment length | **90 s** | Real-time combat |
| Corner phase | **45 s** between segments | Tactics window; pausable menu over diegetic corner scene |
| Dressed squad | **8** fighters | Selected pre-dual from stable (cap 100) |
| Starting lineup | **5** (one per segment slot) | R5 = Anchor slot by convention, not rule |
| Reserves | **3** | Swappable only during corner phases |
| Staff corner | **3** slots | Coach + cutman + specialist ([[NP_10_TACTICS]]) |
| Officials | 1 referee (in-ring), 2 judges (exchange points) | Referee handles counts, fouls, stoppages |

**Both clubs field one fighter per segment.** The two R1 fighters box segment 1; both retire to the apron; the R2 pair boxes segment 2; etc. Lineup order is sealed pre-dual (see §7, Order Sealing) and revealed slot-by-slot — reading and countering the opponent's order is the formation metagame ([[NP_10_TACTICS]] §2).

### 2.1 Segment slot roles (convention, taught by commentary)
| Slot | Nickname | Conventional job |
|---|---|---|
| R1 | **The Opener** | Set tempo, bank Tension, scout enemy rhythm |
| R2 | **The Second** | Convert or stabilize; classic slot for style-counter picks |
| R3 | **The Pivot** | Mid-dual swing; where coaches spend their first tactic |
| R4 | **The Hammer** | Primary scorer; usually the club's ace striker |
| R5 | **The Anchor** | Keeper analog: protect the lead / complete the comeback |

None of these are enforced — a club that runs its ace at R1 ("Ambush order") is a legal, readable strategy with a name commentators use.

---

## 3. SCORING

### 3.1 Primary: DROPS (the goal analog)
| Event | Points | Definition |
|---|---|---|
| **DROP** | 1 | Any knockdown: fighter's composure pool broken, touches canvas, beats the count |
| **FLASH DROP** | 2 | Knockdown scored *from a flash-counter window* (perfect tell read → counter → down). The highlight-reel goal |
| **SEGMENT KO** | 3 | Fighter fails the standing-eight check or is dropped 3× in one segment (three-knockdown rule). Their segment ends immediately; remaining segment time is forfeit (opponent shadowboxes the clock out — free Tension trickle, +1/10 s, no further DROPs possible) |

DROPS are cumulative across all five segments. **Most DROPS wins the dual.**

### 3.2 Secondary: Exchange Points (EP)
Judges score continuously per segment:
| Action | EP |
|---|---|
| Clean scoring blow (head) | 2 |
| Clean scoring blow (body) | 1 |
| Counter hit | 3 |
| Exchange win (last clean hit before disengage) | 2 |
| Ring control tick (opponent held in your attacking zones 5 s) | 1 |
| Knockdown | 10 |

EP decide **segment wins** (announced per segment — the "rounds won" drama) and feed the tiebreak ladder. EP also drive Tension generation rates ([[NP_05_TENSION_HISSATSU]] §2).

### 3.3 Tiebreak ladder (equal DROPS after R5)
1. Segment wins (EP majority per segment)
2. Total counter hits across the dual
3. **Sudden-death segment (R6, "Golden DROP"):** each club sends any *dressed* fighter (including someone who already fought — exhausted stamina carries over; sending your gassed ace vs. a fresh reserve is a real decision). First DROP wins. No time limit; stamina attrition guarantees resolution.

### 3.4 The count & standing-eight
On a DROP, time slows and the referee's count begins. The downed fighter's player performs the **Standing-Eight Check** — an HRT-gated rhythm input ([[NP_03_COMBAT_ENGINE]] §9). Pass: fight resumes with a 10-second vulnerability state (composure regen halted). Fail: Segment KO. AI fighters roll HRT + narrative flags (bosses scripted to rise at dramatic counts — a boss rising at "nine" is authored, legal, and devastating television).

---

## 4. RING GEOGRAPHY (formalized)

The ring is 24 ft (oversized — the sport's one physical concession to team spectacle: bigger canvas, more geography). Zones are concentric + corner overlays:

| Zone | Extent | Modifiers (both fighters unless noted) |
|---|---|---|
| **CENTER** | Inner 12 ft circle | Exchange wins: +2 Tension bonus. Baseline damage. Neutral footing |
| **MID-RING** | Between center and ropes | No modifiers. Transit space |
| **ROPES** | Within 2 ft of any rope | Damage ×1.25 both ways; composure thresholds −15% for the fighter *touching* ropes; cut-off mechanics active ([[NP_03_COMBAT_ENGINE]] §6) |
| **CORNER (theirs/yours)** | 4 ft corner quadrants | Damage ×1.5; guard decay ×2 for trapped fighter; trapped fighter's flash-counter windows +40% wider (desperation reads); CORNER TRAP state after 3 s pinned |

**Own-corner vs. far-corner asymmetry:** being trapped in your *own* corner during a segment your staff is active lets the cutman shout a one-time "Get off the ropes!" free escape prompt (once per dual — [[NP_10_TACTICS]] §6).

Ring generalship (cutting the ring, herding to ropes, corner-trapping) is the positional metagame that decides *which exchanges matter* — the soccer field's thirds, compressed. Full movement mechanics in [[NP_03_COMBAT_ENGINE]] §6.

---

## 5. LEGAL TECHNIQUE & FOULS

The sport is boxing: two hands, head and body targets, above the belt. Hissatsu are **sanctioned** — the fiction treats supers as the highest expression of technique, not cheating (the CRBF's founding charter literally names "the elevated arts"). Fouls:

| Foul | Referee response | Systemic effect |
|---|---|---|
| Low blow / behind the head | Warning → EP deduction (−5) → DROP awarded to opponent on third | AI opponents in "dirty" archetypes flirt with warnings deliberately (see Vic the Tick, [[NP_04_OPPONENT]] §8) |
| Holding without work (clinch stall >4 s) | Referee break, −2 EP | Anti-turtle pressure |
| Apron interference (reserve/staff touches ring) | −1 DROP team penalty | Nuclear; exists for story beats |
| Corner phase overrun | Segment starts with fighter at 80% stamina | Enforces tactics-phase time pressure |

**No disqualification mid-dual in normal play** — DQ exists only as an authored story event.

---

## 6. FIGHTER ELIGIBILITY & CONDITION

- **No weight classes.** The shonen handwave, stated once by commentary in episode 1 ("Rotation rules: any body, any size, one ring") and never again. This is load-bearing: it lets a tiny counter-genius fight a giant slugger, which is the entire David/Goliath grammar of the genre.
- **Condition carries across the dual:** a fighter's stamina, guard meter, and composure at segment end persist if they re-enter (via R6, or exhibition formats with repeat slots). Cutman actives partially restore ([[NP_10_TACTICS]] §5).
- **Injury states** (story-authored only, never RNG): a cut that the cutman must manage each corner phase, a damaged hand that disables power modifiers. Used as narrative pressure, flagged in dual setup.

---

## 7. PRE-DUAL PROTOCOL (the sport's chess opening)

1. **Squad declaration** (both clubs declare 8 dressed, public).
2. **Order sealing:** both coaches seal their R1–R5 lineup simultaneously. Sealed orders are hidden.
3. **Slot reveal:** each slot's pairing is revealed only when the segment begins. *However* — scouting intel ([[NP_10_TACTICS]] §3) shows probability estimates of the enemy order pre-dual, and the tactician staff active can reveal the next slot outright during a corner phase.
4. **Corner-phase reordering:** from R2 onward, a coach may swap the upcoming slot's fighter with any reserve or any not-yet-fought lineup member. First swap free; each further swap costs 15 team Tension. (This is the substitution economy — you can counter-pick reactively, but it drains the meter your hissatsu need.)

The sealed-order + costed-reorder loop creates the yomi layer: do I burn Tension to counter their revealed Hammer, or trust my sealed order? Full tactics treatment in [[NP_10_TACTICS]].

---

## 8. ALTERNATE FORMATS (used by story & side content)

| Format | Structure | Where used |
|---|---|---|
| **Mini-dual** | 3 segments, 4 dressed | Early Arc 1, side tournaments |
| **Iron dual** | 5 segments, **3** dressed — fighters must repeat slots, condition carries | Endurance-themed rival (True North Club) signature format |
| **Blind dual** | No scouting, no slot reveals | The masked syndicate's format (Arc 2) |
| **Gauntlet** | 1 fighter vs. 5 segments solo | Training arcs, "prove yourself" story beats |
| **Exhibition 2v2** | Two fighters per side *in ring simultaneously*, one segment | Festival content; the only simultaneous format; duo hissatsu showcase ([[NP_05_TENSION_HISSATSU]] §7) |

---

## 9. PRESENTATION RULES (sport-level, binding on all teams)

- **Entrances are content:** each club has an entrance (music sting, banner, crowd chant). Player club's entrance upgrades with facilities ([[NP_10_TACTICS]] §8).
- **DROP presentation:** camera hold, crowd eruption, score bug flip — the goal-scored moment. Budget the same ceremony weight as a goal in a soccer broadcast.
- **Segment-end card:** EP totals, segment winner, Tension carried — a 4-second broadcast card before the corner phase. Teaches the economy every single segment.
- The commentary team must be able to *say* every mechanic in plain language. If a rule can't be spoken by the colour commentator in one sentence, redesign the rule. (Design gate applied to all docs in this vault.)

---

## 10. GLOSSARY (canonical terms — use everywhere, UI included)
**Dual** (the match) · **Segment** (one rotation bout) · **DROP** (knockdown score) · **Flash Drop** (counter knockdown, 2 pts) · **EP** (exchange points) · **The Count / Standing-Eight** · **Order sealing** · **Ambush order** (ace at R1) · **Golden DROP** (sudden death) · **The Rote** (the sport) · **Wall Gauge** (boss anchor shield, [[NP_05_TENSION_HISSATSU]] §8) · **Charged / Full Relay** ([[NP_05_TENSION_HISSATSU]] §6).
