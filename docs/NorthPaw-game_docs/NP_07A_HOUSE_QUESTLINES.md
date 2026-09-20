# NP-07A — HOUSE QUESTLINES: Fourteen Families, Fourteen Doors
**Project Northpaw design vault · Expansion of [[NP_07_HOUSES]] · Vault v1.3**
Related: [[NP_07_HOUSES]] · [[NP_08_STABLE]] §2 · [[NP_05A_HISSATSU_LIBRARY]] · [[NP_12_NARRATIVE]] · [[NP_04A_BOSS_ROSTER_ARC1]]

Every house carries one questline with four fixed deliverables: the **SECRET gate event** (the scene that unlocks the house SECRET from `data/hissatsu_library.v1.json`), the **blessing condition** in the [[NP_08_STABLE]] §2.2 grammar (machine-usable, honest once discovered), the **feud-graph mutations** it can fire, and its **rewards**. Beats are written to the [[NP_12_NARRATIVE]] §1 tone law and delivered inside episodes — a questline may span arcs, and its flags gate recruitment, gifts, and Inheritance sources.

This doc also pins the launch feud graph. [[NP_07_HOUSES]] §6 committed to 12 authored edges; they are enumerated here for the first time and shipped as **`data/feud_graph.v1.json`** for PAC-023 (house-ring math) and PAC-027 (recruitment) to consume. Commentary knows every edge; every DEBT and FEUD below is a quest hook by construction.

---

## 1. THE LAUNCH FEUD GRAPH (12 edges, canonical)
| # | Edge | Relation | Origin (one line, commentary-speakable) |
|---|---|---|---|
| E01 | Tremblay — [SEALED] | FEUD | The 1998 Golden Gloves DQ; the record says a man died. Displayed in-game as "Tremblay — Whitlock's club" until Arc 2 |
| E02 | Reyes — MacIsaac | FEUD | A 1974 harbour bet: a boat, a broken hand, two versions of who swung first |
| E03 | Kowalchuk — Whitecloud | ALLIED | Grain roads and winter roads; three generations of shared corners |
| E04 | Okafor — Petrov | DEBT | Petrov trained the first Okafor for free in '89; the house still owes |
| E05 | Moreau — Tremblay | FEUD | The 1983 provincial final split Québec doctrine in two |
| E06 | Tagaq — Whitecloud | ALLIED | The northern circuit; shared billets at −40 |
| E07 | Nguyen-Roy — Delacroix-Cardinal | MARRIAGE | The Roy grandmother was a Delacroix-Cardinal; *Two Rivers* exists because this edge does |
| E08 | Iron — Moreau | DEBT | Moreau bought the Iron gym's fixtures at the estate sale and never felt right about it |
| E09 | Osei — Petrov | ALLIED | Halifax summer teaching camps, twenty years running |
| E10 | MacIsaac — Tagaq | DEBT | A rescue at sea in '96; MacIsaac boats answer Tagaq calls first |
| E11 | Kowalchuk — Reyes | FEUD | The prairie circuit rivalry — the warm feud; both houses would be heartbroken if it ended |
| E12 | Delacroix-Cardinal — Iron | DEBT | Iron's founder learned river-reads from a Delacroix-Cardinal elder; the debt outlived the debtor |

Mutation rules: questlines flip edges via story flags (FEUD→ALLIED is the standard resolution; DEBT→ALLIED on repayment; E01 resolves only through the Arc 2 spine). E11 is authored unresolvable — resolving it is the one outcome both houses refuse, and the game says so. Every mutation writes a same-day Note to the graph data and re-tunes the [[NP_06_AFFINITY]] §3 house ring live.

---

## 2. QUESTLINES

### Q-TREMBLAY — "La Question de 98" *(Arc 1 Provincials → Arc 2)*
**Hook:** Marta's recruitment condition dead-ends at her grandmother, who ends the conversation at Whitlock's name.
**Beats:** (1) The 1998 tape exists in the Film Room, last thirty seconds missing; Priya finds the splice. (2) The Tremblay matriarch grants one spar — survive Marta's *Mirror* for a full segment and she talks: the DQ call came from a judge who never worked again. (3) Whitlock confirms half of it and stops at the other half; flag `tremblay_truce` lifts the feud to cold peace. (4) *Arc 2:* the Hollow Circuit fields a fighter using the sealed house's dialect, Marta's grandmother sees the broadcast, and E01 resolves on her testimony — the DQ was staged to protect Whitlock's friend, whose death the record invented.
**SECRET gate:** *Verglas* is taught by the matriarch herself after `tremblay_truce`, in the Old Gym, to a Tremblay in your stable — she crosses the feud line to do it, and says why.
**Blessing:** `QUEST(la_question_98) AND BEAT_IN(spar) USING STYLE_PROOF(out-boxer)`
**Mutations:** E01 FEUD→ALLIED (Arc 2 finale); E05 unaffected — Moreau's grievance is doctrinal, and Tremblay peace with you sharpens it.
**Rewards:** Marta recruit path; *Verglas*; Whitlock's Arc 2 thread armed.

### Q-KOWALCHUK — "The Barn Lesson" *(Arc 1 Regionals)*
**Hook:** Yuri, recruited, refuses to throw *Harvest Moon* in duals and changes the subject badly.
**Beats:** (1) The patriarch's barn outside Harbourline: the armored finisher put a man in hospital in '02 and the house retired it. (2) The patriarch sets the test — weather Yuri at full power for 60 seconds using defense only (the [[NP_09_TRANSFORMATIONS]] §7 weathering verbs, taught early). (3) He teaches the move to whoever stood the storm, Yuri watching from the rail.
**SECRET gate:** *Harvest Moon*, granted at beat 3; the scene is the [[NP_07_HOUSES]] §4 gift-ceremony template's debut.
**Blessing:** `BEAT_IN(dual[segment]) AND WITNESS(patriarch attends a home dual)`
**Mutations:** none — E03 and E11 are load-bearing warmth.
**Rewards:** *Harvest Moon*; Kowalchuk cousins surface on the String Wall; Beans faucet (barn training spot).

### Q-OKAFOR — "Three Chairs at the Table" *(Arc 1 → Arc 2)*
**Hook:** Carter recruited; two chairs at the Okafor table sit empty on your first visit.
**Beats:** (1) Thanksgiving episode: Ada declines the invitation by text, four words. (2) The third sibling, **Nneka Okafor**, surfaces through the String Wall — she quit boxing when the other two chose clubs over the table. (3) Beat Ascendant in the Nationals semi with Carter dressed; Ada comes home for one dinner, `okafor_table` opens. (4) *Arc 2:* Ada's recruitment lands here, and Nneka corners for the pair — staff recruit, Hype role.
**SECRET gate:** *Eye of the Storm* is taught jointly — the house teaches it only to a fighter both boxing siblings vouch for.
**Blessing:** `BOND(Carter, 4) AND QUEST(okafor_table)`
**Mutations:** E04 DEBT→ALLIED — the house repays Petrov by sending Nneka's community-centre kids to his camps; fires on `okafor_table`.
**Rewards:** Ada + Nneka recruits; *Eye of the Storm*; duo T3 flag for the siblings.

### Q-REYES — "The Bell" *(Arc 1 side, Winnipeg away card)*
**Hook:** A Reyes uncle rings a hand-bell at every dual the family fights; scouts report he rang it once at one of yours.
**Beats:** (1) The away dual in Winnipeg: win the body-shot micro-objective ladder his nephews set as gatekeeping scraps. (2) The uncle explains the bell — it rang the end of the great-grandfather's last fight abroad, and the family kept the sound. (3) *La Campana* is taught over a heavy-bag session that is entirely about restraint: the move is forbidden against anyone above 40 stamina, and breaking that rule in a dual voids the blessing (`reyes_code` flag, revocable — unique in the game).
**SECRET gate:** *La Campana* at beat 3, honor-coded.
**Blessing:** `STAT_PROOF(PWR>=60) AND BEAT_IN(scrap)x3 AND QUEST(the_bell)`
**Mutations:** E02 FEUD→ALLIED available *(Arc 2)* jointly with Q-MACISAAC: both houses' quests must reach their final beat, then the boat from 1974 gets rebuilt in the harbour episode. E11 untouched.
**Rewards:** *La Campana*; Reyes recruit pair; the bell rings at your entrances (Front of House upgrade).

### Q-MACISAAC — "What the Water Keeps" *(Arc 1 Regionals → Arc 2)*
**Hook:** Dex will not board his father's boat; Moira will not stop asking him to.
**Beats:** (1) The Netmen dual ([[NP_04A_BOSS_ROSTER_ARC1]] §2) puts the cousins in the same building. (2) The net-haul training episode: Dex works the winch, says nothing, sets a personal best. (3) His father's engine fails in a squall; the Tagaq call goes out and E10 answers it on screen — Dex boards the rescue boat. (4) `macisaac_harbour` closes: Moira recruits, Dex accepts *Prodigal* as his own line's move.
**SECRET gate:** *Rogue Wave* — taught on the boat, at sea, to Dex or Moira only (blood-gated; the one SECRET outsiders never learn — houses keep some doors, and the game respects it).
**Blessing:** `BOND(Dex, 3) AND QUEST(macisaac_harbour)`
**Mutations:** E02 (see Q-REYES); E10 DEBT acknowledged on-screen, stays DEBT — Tagaq refuses repayment ("you'll answer a call someday").
**Rewards:** Moira recruit; *Rogue Wave* (blood-gated); Net Haul minigame tier 3.

### Q-WHITECLOUD — "Seven Winters" *(Arc 1 → Arc 3)*
**Hook:** The Whitecloud elder attends your Regionals dual unannounced and leaves before the fifth segment.
**Beats:** (1) Roadwork with the house's runners on The Hill, seven mornings, calendar-real. (2) The house archive: seven generations of fight records, and a gap where the Iron lineage's last dual should be — the houses shared a card the night Iron ended. (3) The elder grants training rights; *Polaris* waits. (4) *Arc 3:* the elder corners for Team Canada — the deepest lineage endorses the melting-pot roster on national broadcast.
**SECRET gate:** *Polaris* after the seventh roadwork morning plus a dual won from the R4 or R5 slot — the move is for closers, and the house proves you close.
**Blessing:** `REP(the_hill, 3) AND PI_LEVEL(whitecloud, 2)`
**Mutations:** none held; feeds Q-IRON beat 2 with the missing card.
**Rewards:** *Polaris*; Whitecloud recruit; Roadwork Beans yield +50%.

### Q-TAGAQ — "The Quiet Corner" *(Arc 1 Nationals → Arc 2)*
**Hook:** Sam, recruited, corners for a junior at the community centre every Saturday and never mentions it.
**Beats:** (1) The junior's parents work Saturdays; Sam has been the whole corner for a year. (2) True North's old coach visits Harbourline; the *Northern Silence* conversation happens over tea, mostly in pauses. (3) The technique is taught in an empty gym with the crowd audio literally muted — the presentation IS the move.
**SECRET gate:** *Northern Silence* at beat 3; requires Sam at Kizuna 4 with the learner.
**Blessing:** `BOND(Sam, 3) AND WITNESS(win a dual without your crowd-heat actives)`
**Mutations:** E06, E10 both surface in dialogue, both stay as authored.
**Rewards:** *Northern Silence*; junior joins as a scout-role stablemate; Sam bond scene chain.

### Q-NGUYEN-ROY — "The Third Bridge" *(Arc 1 Regionals)*
**Hook:** Tam's recruitment condition includes PI you can only earn from his own club's scraps — he wants to be studied honestly.
**Beats:** (1) The two family homes flank the river; dinner happens on the footbridge between them, weather regardless. (2) The grandmother walks you through the marriage that made the house, E07 on screen — the game's model of a dual-lineage family, unremarked and happy. (3) Tam spars you at PI 2 and joins on the loss he asked for.
**SECRET gate:** *Third Bridge* is taught only to a dual-house fighter in your stable, or to Tam himself — the move requires two lineages in one body, mechanically honest to [[NP_07_HOUSES]] §5's hybrid tax.
**Blessing:** `PI_LEVEL(nguyen-roy, 2) AND BEAT_IN(spar)`
**Mutations:** E07 MARRIAGE is permanent by definition; the quest arms the *Two Rivers* Forge pairing early.
**Rewards:** Tam recruit; *Third Bridge* (conditionally); Forge discount for E07-pair hybrids.

### Q-PETROV — "The Open Ledger" *(Arc 1 → Arc 3)*
**Hook:** Petrov's gym posts its whole curriculum on the wall, free to photograph; one page frame hangs empty.
**Beats:** (1) The patriarch teaches *System Jab* to anyone who asks, including your rivals, on screen — the house thesis played straight. (2) The empty frame held *Perfect Score*; it came down the day Vey took Anders. (3) Beat an Ascendant fighter using only Petrov-taught technique (`STYLE_PROOF` variant) and the patriarch rehangs the page. (4) *Arc 3:* he teaches it to Anders at last, in your corner, before the thesis fight.
**SECRET gate:** *Perfect Score* at beat 3 — the page goes back up for you first.
**Blessing:** `QUEST(open_ledger) AND STYLE_PROOF(win using petrov-taught moves only)`
**Mutations:** E04 (see Q-OKAFOR); adds a provisional Petrov—Ascendant DEBT edge in Arc 3, owed by *Vey* — the graph's only villain-side debt, and the thesis fight collects it.
**Rewards:** *Perfect Score*; two Petrov students recruit; teaching-item drop rate up.

### Q-OSEI — "The Window" *(Arc 1 Provincials → Arc 2)*
**Hook:** Efua's dual ([[NP_04A_BOSS_ROSTER_ARC1]] §7) ends with her mother leaving before the decision.
**Beats:** (1) Efua recruits UNSANCTIONED if approached early — the game allows recruiting around the family and the scenes carry the tension. (2) The mother's condition for talking: watch the tape of her own title loss, the one that made her lock the style away from her daughter. (3) The kitchen scene — mother and daughter, one table, the stolen wraps between them. `osei_blessing` resolves the internal feud; Efua's *Deep Roots* heals to 100% on the spot, zero migration, per [[NP_05A_HISSATSU_LIBRARY]] §3.
**SECRET gate:** *Deep Roots* — already in Efua's hands; the gate event *legitimizes* it, the library's one inverted unlock.
**Blessing:** `QUEST(osei_blessing) AND FEUD_RESOLVED(osei_internal)`
**Mutations:** internal edge only; E09 warms in dialogue.
**Rewards:** Efua sanctioned (home bonus live); mother joins as Conditioning staff; the wraps become signature gear.

### Q-DELACROIX-CARDINAL — "Where Rivers Meet" *(Arc 1 side → Arc 2)*
**Hook:** An elder of the house requests a meeting after your first dual using *Two Rivers* — the hybrid carries their lineage, and they noticed.
**Beats:** (1) The Red River visit; consultation-governed content per [[NP_07_HOUSES]] §9, the house written by people who can vouch for it. (2) The river-read lesson: an afternoon reading current seams, then the same skill applied to an opponent's weight shifts in a spar. (3) The house formally sanctions the *Two Rivers* pairing; E07 and E12 are told as one story. (4) *Arc 2:* the house identifies the Hollow Circuit's stolen river-read patterns first — they know their own current anywhere.
**SECRET gate:** *The Forks* after beat 2's spar, won by counter hits only.
**Blessing:** `QUEST(where_rivers_meet) AND PI_LEVEL(delacroix-cardinal, 2)`
**Mutations:** E12 DEBT→ALLIED when Q-IRON completes — the debt transfers to the living.
**Rewards:** *The Forks*; house recruit; Scout Book gains the river-read annotation layer (counter-window notes on every page).

### Q-IRON — "Estate Sale" *(Arc 2 spine-adjacent)*
**Hook:** A crated heavy bag in Moreau's gym still wears Iron gym stencils; Jean-Guy will not train on it.
**Beats:** (1) The last Iron — **Vera Iron**, [[NP_07_HOUSES]] §5's last-of-line — works night shifts and answers no letters. (2) The Whitecloud archive gap (Q-WHITECLOUD beat 2) dates the lineage's end to the same card as a Moreau win; Jean-Guy's father never spoke of it. (3) Scout Book archaeology assembles *Iron Doctrine* from three archived pattern pages — the collection loop as excavation, exactly as [[NP_07_HOUSES]] §5 promised. (4) Vera watches you throw her family's move correctly, once, and signs on. Her doubled trait comes with her.
**SECRET gate:** *Iron Doctrine* via archive assembly (beat 3) — the only SECRET no living person teaches.
**Blessing:** none exists — there is no patriarch left to grant one; Vera's condition is `ITEM(iron_gym_stencil_bag) AND QUEST(estate_sale)` — Moreau gives up the bag, settling E08.
**Mutations:** E08 DEBT→ALLIED; E12 DEBT→ALLIED (transfers to Vera); the graph gains a living node where a dead one stood.
**Rewards:** Vera Iron recruit (doubled trait); *Iron Doctrine*; Moreau's Arc 2 alignment nudged one honest step back.

### Q-MOREAU — "Cold Storage" *(Arc 2)*
**Hook:** The Commissioner's offer letter to Moreau, glimpsed in Jean-Guy's gym bag during the Provincials rematch.
**Beats:** (1) Jean-Guy's refusal scene from [[NP_04A_BOSS_ROSTER_ARC1]] §5 replays with new context — he was refusing *you* the truth, and the syndicate the technique. (2) The syndicate extracts *Le Gel Noir* anyway, from a cousin who signed; the Hollow Circuit fields it and Jean-Guy watches his family's black frost cast hollow. (3) He brings the house to your side to take it back — the questline's dual runs the *Extracted* counterfeit against the true native and the economy argues the theme ([[NP_05A_HISSATSU_LIBRARY]] §3).
**SECRET gate:** *Le Gel Noir* after beat 3's dual, taught in the cold-storage room the house trains in, with the story of why they train cold.
**Blessing:** `QUEST(cold_storage) AND FEUD_RESOLVED(moreau, tremblay)` — E05 must close first; he refuses to bless anyone still carrying his other war.
**Mutations:** E05 FEUD→ALLIED (the 1983 schism argued to a draw over tape, both doctrines conceding a round each); Moreau exits the syndicate thread player-side.
**Rewards:** Jean-Guy recruit; *Le Gel Noir*; syndicate intel channel opens.

### Q-SEALED — "The Name on the Charter" *(Arc 2 finale → Arc 3)*
**Hook:** The CRBF charter-dissolution letter from Ep 1, re-read after the Hollow Circuit reveal — the founding signature line of the Millbrook charter is scraped blank.
**Beats:** structure only, per [[NP_12_NARRATIVE]] §5's design space: (1) the sealed-records vault; (2) the 1998 truth completing E01; (3) the unsealing — trait online, natives dripping per [[NP_07_HOUSES]] §7, *[SEALED-NATIVE-1/2]* ids fill in place. (4) *Arc 3:* the Awakening trial gates *[SEALED-SECRET]* per [[NP_09_TRANSFORMATIONS]] §6.
**SECRET gate:** *[SEALED-SECRET]*, Arc 3 trial; reserved id already in the library.
**Blessing:** self-directed — the protagonist IS the blessing authority by the end, and the first blessing they grant is a scene the player chooses the recipient of (the no-name kid option is authored and the writers' room's dare).
**Mutations:** E01 resolves; the graph gains the restored house as a node with zero feuds — a clean slate the player writes on through play.
**Rewards:** the Arc 2 finale; everything [[NP_07_HOUSES]] §7 promised, adding and never invalidating.

---

## 3. COVERAGE AUDIT
14/14 houses quested; 14/14 SECRET gates land on real library ids; 12/12 edges touched by at least one questline (E03/E06/E11 deliberately held stable and said so); blessing grammar uses 9 of 11 [[NP_08_STABLE]] §2.2 primitives (`BEAT_IN`, `PI_LEVEL`, `REP`, `QUEST`, `FEUD_RESOLVED`, `BLESSING`-implicit, `STAT_PROOF`, `STYLE_PROOF`, `WITNESS`, `ITEM`, `BOND` — all except `BLESSING`-explicit, which these quests *grant*). One revocable blessing (Reyes) and one blood-gated SECRET (MacIsaac) are the two deliberate rule-benders; both are stated in their houses' own terms and gate content, never invalidate it. Staff recruits from questlines: 3 (Nneka, Efua's mother, the Whitecloud elder). New named characters introduced: 3 (Nneka Okafor, Vera Iron, the junior) — the cast cap holds by reusing established people everywhere else.
