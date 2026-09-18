# NP-10 — TACTICS LAYER: The Coach Fantasy

**Project Northpaw design vault · Doc 10/13**
Related: [[NP_01_SPORT]] · [[NP_05_TENSION_HISSATSU]] · [[NP_06_AFFINITY]] · [[NP_08_STABLE]] · [[NP_11_PROGRESSION]]

Everything the player does with a clipboard instead of gloves: the formation screen, scouting, the corner phase second-by-second, the tactics libraries, the staff system, club facilities, and manager mode. Design intent: the coach layer must be a real game a lapsed-fighter player could main — Inazuma's auto-play manager fantasy taken seriously.

---

## 1. THE TACTICS GAME IN ONE SENTENCE

Before the dual you bet on information (order sealing); during it you spend a shared resource (Tension) and scarce actions (tactics, swaps) to bend five fights into one story.

## 2. PRE-DUAL — THE FORMATION SCREEN

Presented as the whiteboard in the Old Gym locker room (diegetic, like all menus).

- **Left: your board.** Drag 8 dressed from the stable; assign R1–R5 + 3 reserves + 3 staff. The Gym Wall's card proximities pre-suggest bonded adjacencies ([[NP_08_STABLE]] §7).
- **Right: their projection.** Scouting intel (§3) renders the enemy's *probable* order as confidence percentages per slot ("R4: Yuri 85%"). Unknowns show as silhouettes.
- **Overlay: the rings.** Hovering any pairing shows the full affinity card ([[NP_06_AFFINITY]] §5): triangle arrow, element arrow, feud banner, projected EP modifier, and a one-line coach note ("She eats sluggers for breakfast" / "Bad wind for us, but this segment will PRINT Tension — see worked example 2, [[NP_06_AFFINITY]] §6: deliberately losing matchups as fuel segments is first-class strategy the UI itself teaches).
- **Named order archetypes** (the game teaches openings like chess): *Standard* (ace at R4), *Ambush* (ace at R1), *Wall-First* (anchor-class at R1 to blunt their ambush), *Relay Ladder* (bond pairs at 2-3 and 3-4 chaining toward R5). Enemy coaches use these archetypes with tells of their own — coach *personalities* are pattern bosses too (§9).

## 3. SCOUTING (information economy)

| Source | Yields |
| --- | --- |
| Pattern Intel grind ([[NP_02_TWO_LAYER]] §3) | Dialect literacy, boss pages |
| **Scout assignment** (stable role, [[NP_08_STABLE]] §1) | Passive: order-confidence % on clubs from that scout's district |
| Tactician staff passive | +15% confidence globally; Scout Book expansions |
| Attending rival duals (overworld events — watchable duals between NPC clubs, a real calendar activity) | Direct order/pattern observation; the *watching tape* fantasy; also where recruitment WITNESS conditions fire in reverse |
| Story leaks | Authored intel beats |
Counter-intelligence exists: some enemy coaches run **decoy seals** (their projection is deliberately poisoned — the confidence % lies). The tactician's Lv3 ability detects decoys. Information warfare stays shallow-but-present: one bluff layer, never recursive.

## 4. THE CORNER PHASE — 45 seconds, second-by-second

Diegetic scene: your fighter on the stool, staff working, the board out. All actions menu-driven over the scene; clock runs; overrun penalty per [[NP_01_SPORT]] §5.
**Action budget per corner: 2 actions** (+1 with Lv3 coach staff). Choosing two of five is the whole phase design:

| Action | Effect |
| --- | --- |
| **Swap** | Reorder upcoming slots / insert reserve. First swap of the dual free; then 15 Tension each |
| **Special Tactic** | Fire one from your equipped set (§5) |
| **Staff active** | Cutman / tactician / hype (§6) |
| **The Talk** | Coach dialogue choice with the *next* fighter (3 options keyed to their personality; correct read: +5% stats their segment; wrong read: nothing — never a penalty for trying to know your kids). Personality data lives on the fighter card; bond levels reveal which talk lands |
| **Save the bar** | Explicit "we're holding for a transform" call: locks Tension spending next segment (AI teammates in auto segments won't spend), banks +5 bonus if the segment is won anyway |

## 5. SPECIAL TACTICS (equip 3 per dual from the club's learned library; cooldown: 1 corner phase between uses)

| Tactic | Cost | Effect (one segment) |
| --- | --- | --- |
| Body Doctrine | 10 T | All your body shots drain double enemy stamina |
| High Guard Order | 10 T | Your fighter's guard decay halved |
| Cut the Ring | 10 T | Herding push +100%; sprint-step free |
| Feint Storm | 10 T | Feints cost 0; enemy PUNISH hooks suppressed 30 s |
| Ice the Clock | 15 T | Segment clock ×0.8 for you while leading on EP (close it out) |
| Read the Corner | 15 T | Enemy tell tier loudened one step this segment |
| Open Season | 15 T | Your counter windows +100 ms; your guard capacity −20% (all-in read stance) |
| Second Wind Call | 20 T | Fighter stamina +40 instantly |
| ... (launch library: 12; learned via facilities §8, staff, and story) | | |

**SUPER TACTICS (one per dual, no Tension cost — the ace card):**

| Super | Effect |
| --- | --- |
| Iron Resolve | Next fighter cannot be DROPPED for 30 s (wobbles instead) |
| The Perfect Round | Next segment: team earns double Tension from all sources |
| Switch-Up | Your fighter's style counts as advantaged on the triangle this segment regardless of truth (the tactical lie made flesh) |
| Hostile Crowd | Enemy corner actions locked next corner phase |
Choose your equipped Super pre-dual; enemy coaches have theirs, authored (§9).

## 6. STAFF SYSTEM (3 dressed of 10-corps)

Staff are collected like fighters ([[NP_08_STABLE]] channels; retired boxers, rival cornermen, a sports-med student, the janitor who used to be somebody). Each has a **passive** (always-on while dressed) and an **active** (corner-phase action, per-dual charges):

| Role | Sample passive | Sample active |
| --- | --- | --- |
| **Cutman** | Corner stamina restore +15 | *Patch Job*: restore 30 composure + clear a story-cut (2 charges) |
| **Tactician** | +15% scout confidence; Scout Book pages richer | *The Reveal*: expose enemy's next slot outright (1) |
| **Hype** | Crowd heat builds 20% faster | *Raise the Roof*: convert crowd heat → +8 Tension (2) |
| **Conditioning coach** | Team stamina regen +10% | *Loosen Up*: next fighter enters at 110 stamina cap (1) |
| **The Professor** (rare) | PI gains ×2 during duals | *Chalk Talk*: grant the player 15 s of tell-highlight next segment (1) |
Staff level via use; Lv3 unlocks a second passive. The head coach (story character, not collectible) provides The Talk (§4) and the club's tactic library growth.

## 7. CLUB FACILITIES (the gym progression tree)

Facilities upgrade with story + HBP + Spirits; each tier is a visible renovation of the Old Gym (the condemned building coming back to life IS the meta-progression fantasy):

| Track | T1 → T3 effects |
| --- | --- |
| Bags & Mitts | Training minigame tiers ([[NP_11_PROGRESSION]] §7), Beans yield +25/50% |
| The Ring | Spar modifiers unlock; 2v2 exhibition hosting; ranked spar board access |
| Film Room | Scout Book capacity; PI grind rate +; decoy detection assist |
| The Wall | Bond board slots, decoration sets, Forge event hosting ([[NP_08_STABLE]] §6) |
| Front of House | Entrance presentation upgrades, crowd heat base +, Prestige from hosted duals |
Final renovation (Arc 3): the gym hosts a televised dual — the condemned building on national broadcast, full circle.

## 8. MANAGER MODE (auto-play)

Any segment can be delegated: your fighter plays via their own AI profile (their stats + style archetype + equipped techniques + *their PI of the opponent* — your recon literally makes your AI teammates smarter). Camera: broadcast angles, free seat selection. The player retains corner phases. Full-dual delegation legal (the pure Inazuma manager fantasy); story-critical final segments may require hands-on (authored, sparingly). Balance: AI segments earn 85% Tension rates — playing is always slightly better, delegating is never punished into irrelevance.

## 9. ENEMY COACHES (the other mind)

Every rival club's coach is data: order archetype tendencies, swap aggressiveness, tactic library, Super choice, decoy usage, and *a tell* (the coach who always burns his Super after conceding a FLASH DROP; the coach who never swaps when leading). Coach patterns are Scout Book content — outcoaching a rival you've studied is a victory the tactics-main player can author entirely from the stool. Arc bosses pair boss fighters with boss coaches; the Toronto academy's coach is the tactics layer's final exam, exactly as their anchor is the combat layer's.
