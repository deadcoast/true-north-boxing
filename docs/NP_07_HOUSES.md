# NP-07 — HOUSES: The Lineage System

**Project Northpaw design vault · Doc 7/13**
Related: [[NP_04_OPPONENT]] (tell dialects) · [[NP_05_TENSION_HISSATSU]] (native techniques) · [[NP_06_AFFINITY]] · [[NP_08_STABLE]] · [[NP_12_NARRATIVE]]

The unit is the **family**. Every notable fighter comes from a boxing house; every house carries a named, inherited technique lineage — signature hissatsu, stance quirks, a tell dialect, secret moves, feuds, and history. House styles flow organically from each family's own story and culture, family by family, exactly like real Canadian families carry things. A hundred houses across every background and neighbourhood: that is the melting pot. This doc is the complete system spec plus the writing law that keeps it celebration, never caricature.

---

## 1. THE WRITING LAW (Doctrine D6/D7 — enforced at content review)

1. **The house style is inherited; the fighter is an individual.** Every house with ≥2 depicted members must show meaningfully different personalities inside the same style (the Neji/Hinata/Hanabi rule). One-note houses fail review.
2. **Heritage flavors houses per-family, never per-group.** A house's style traces to *that family's* specific history — a great-grandfather's ring career abroad, a grandmother who fought in Saskatchewan barns, a father's failed pro run. No house is written as representing "how [group] fights."
3. **Clubs are mixed by default.** Rosters look like Canadian classrooms. House membership crosses every line via marriage, adoption, and mentorship-adoption (§5). Diversity is ambient and unremarked.
4. **No house is villainous by blood.** Houses contain heroes, villains, and everyone else. Feuds are between families and choices, never essences.

## 2. HOUSE SCHEMA (full)

```jsonc
House {
  id, name, motto,                       // "Kowalchuk — 'Load It, Deliver It'"
  region_root, founding_story,           // 2-paragraph canon: who, when, why this style
  generations: int,                      // depth of the lineage (flavor + trait scaling hooks)
  style_bias,                            // weighted, not fixed: e.g. SLUGGER 60/BOXERPUNCHER 40
  element_bias,                          // e.g. GRANITE 80/other 20  ([[NP_06_AFFINITY]] §2.3)
  tell_dialect: {channel, motif, notes}, // [[NP_04_OPPONENT]] §3
  native_techniques: [hissatsu_id],      // 2-4 per house; 1 flagged SECRET (§4)
  house_trait,                           // the passive (§3)
  stance_quirk,                          // cosmetic-mechanical: visible stance signature
  feud_graph: [{house_id, relation, origin_story}],   // FEUD | ALLIED | DEBT | MARRIAGE
  members_named: [fighter_id], heirs, black_sheep, patriarch_matriarch_id,
  blessing_condition                     // recruitment gate ([[NP_08_STABLE]] §3)
}
```

## 3. HOUSE TRAITS (passive library — one per house; launch pool of 20)

| Trait | Effect |
| --- | --- |
| Never Twice | Cannot be dropped twice in one segment (2nd drop → wobble instead). Cooldown: once per dual |
| Deep Roots | +guard regen 50% while trailing on DROPS |
| Long Winter | All stats +10% in R4/R5 slots |
| First Frost | Segment-opening 15 s: counter windows +100 ms |
| Harvest | +1 Tension on every exchange win anywhere (not just center) |
| Load-Bearing | Composure pool +20% while in ropes/corner zones |
| Tide Discipline | Stamina floor: cannot drop below 10 |
| Open Door | Bond growth with all stablemates ×1.5 ([[NP_08_STABLE]] §6) |
| Debt of Honour | +25% all stats vs. feuded houses (stacks with feud Tension, capped by [[NP_06_AFFINITY]] §4) |
| ... (11 more in content DB) | |

> Traits are house-locked, never transferable — the one progression layer money can't touch ([[NP_11_PROGRESSION]] §8 keeps techniques teachable; traits are blood/adoption only).

## 4. NATIVE & SECRET TECHNIQUES

- **Native** (2–4 per house): learnable only by members (blood or adopted, §5). +10% home-advantage effect ([[NP_06_AFFINITY]] §3).
- **SECRET** (1 per house): gated behind a house story event (the patriarch's deathbed lesson, the sealed scroll in the gym basement, winning the family's internal tournament). Secrets are the strongest T1/T2s in the game and the spine of house questlines ([[NP_08_STABLE]] §3).
- Native techniques *can* leak: a house may formally **gift** a technique to an outsider (huge story beat, one per house per save; the ceremony is a cutscene template). Gifted moves lose the +10% home bonus.

## 5. MEMBERSHIP & THE CHARACTER GRAMMAR

Membership routes: **blood**, **marriage-line** (dual-house characters carry both dialects, may learn both native sets at −1 technique slot each — the hybrid tax), **adoption**, and **mentorship-adoption** (a patriarch/matriarch formally takes a no-name student into the house — the single most emotionally loaded recruitment event in the game; reserved for authored arcs).

Full shonen grammar, all mechanically real:

| Archetype | Mechanical expression |
| --- | --- |
| **Prodigy crushed by legacy** | Starts with SECRET unlocked but HRT 20; his arc raises HRT, not moves |
| **Forbidden daughter who steals the style** | Knows natives but flagged UNSANCTIONED: no home bonus until her blessing quest resolves |
| **Last of a dead lineage** | House of one; trait doubled; no living teachers — her SECRET is findable only in the Scout Book archives (collection loop as archaeology) |
| **Disowned heir** | House trait inactive until reconciliation OR he founds a cadet house (endgame: player-witnessed house *creation*) |
| **The no-name** | No house, no trait, no natives — and a hidden +10% XP curve. The grinder who outworks bloodlines; the game's oldest promise, kept in the math |
| **The protagonist** | Sealed house (§7) |

## 6. FEUD & ALLIANCE GRAPH

Relations: FEUD (Tension geysers, [[NP_06_AFFINITY]] §3), ALLIED (bond growth ×1.25 between members), DEBT (one-directional: quest hooks — "our house owes yours"), MARRIAGE (creates dual-house characters). The launch graph ships with 12 authored edges among the 14 named houses; commentary knows every edge. Feuds resolve or deepen through play — the graph is *mutable by story flags*, and resolving a feud is itself a recruitment channel ([[NP_08_STABLE]] §3).

## 7. THE PROTAGONIST'S SEALED HOUSE

The player character presents as a no-name. Arc 1 plays entirely on the no-name curve (the underdog is real, not cosmetic). Arc 2's central reveal: the lost house — **House [REDACTED — narrative doc]**, erased from CRBF records after [[NP_12_NARRATIVE]] §5 events. Unsealing (Arc 2 finale): the house trait comes online, the native set drips in across Arc 3, and the SECRET is the Awakening gate ([[NP_09_TRANSFORMATIONS]] §6). Mechanical rule: unsealing must never invalidate the no-name build the player grew — natives ADD slots rather than replace, and the hidden XP bonus is grandfathered. You were never wasting your time; that's the promise.

## 8. LAUNCH HOUSES (14 named at ship; expanded roster of ~40 via generator + content packs)

| House | Root | Style/Elem bias | Native family | Trait | Notes |
| --- | --- | --- | --- | --- | --- |
| Tremblay | Montréal | Out-Boxer/Frost | Doctrine Tremblay (counter suite) | First Frost | Feud: your coach (origin: a 1998 Golden Gloves DQ) |
| Kowalchuk | Prairies | Slugger/Granite | Grain line (rising power) | Load-Bearing | Warmest family in the game |
| Okafor | Toronto | Swarmer/Gale | Pressure line | Harvest | Three siblings across three rival clubs (built-in triangle) |
| Reyes | Winnipeg | Slugger/Granite | Liver Line (body doctrine) | Debt of Honour | Feud: MacIsaac (a 1970s harbour bet) |
| MacIsaac | Cape Breton | Slugger/Timber | Net-Hauler (pull counters) | Tide Discipline | Trains on the actual boats |
| Whitecloud | Northern ON | Boxer-Puncher/Frost | Long Winter (endurance suite) | Long Winter | Deepest generations count (7) |
| Tagaq | Nunavut→True North | Boxer-Puncher/Frost | Patience line | Never Twice | Sam ([[NP_04_OPPONENT]] §8.3) |
| Nguyen-Roy | Gatineau | Out-Boxer/Gale | Two-bridge footwork | Open Door | Marriage-house: the game's model dual-lineage family |
| Petrov | Niagara | Out-Boxer/Granite | Amateur-system pedagogy | First Frost variant | The teaching house: gifts more techniques than any other |
| Osei | Halifax | Swarmer/Timber | Shell-and-surge | Deep Roots | Forbidden-daughter arc lives here |
| Delacroix-Cardinal | Métis, Red River | Boxer-Puncher/Gale | River-read counters | Harvest variant | Written with cultural consultation — see §9 |
| Iron | (dead lineage) | ?/Granite | LOST | doubled trait | Last-of-line character |
| Moreau | Québec City | Slugger/Frost | Cold-forge hooks | Load-Bearing variant | Villain-adjacent Arc 2 house — by choices, not blood |
| [SEALED] | — | — | — | — | Protagonist |

## 9. CULTURAL EXECUTION STANDARD

Houses whose founding stories draw on living cultures (Indigenous houses foremost) are written with paid cultural consultation, named consultants in credits, and veto authority over their house's content. This is a production commitment, tracked as a PACER task class ([[NP_13_SCOPE]] §5), not a vibe. The melting-pot thesis only works if every family in the pot is written by people who can vouch for it.

## 10. THE MARRIAGE-OF-STYLES ENDGAME

Cross-house max bonds unlock **hybrid technique research** ([[NP_08_STABLE]] §6): two houses' native families fused into moves neither could produce alone (e.g. *Two Rivers*, [[NP_05_TENSION_HISSATSU]] §10). Arc 3's thesis fight: the Toronto academy has *industrialized* synthesis without bonds — hybrid techniques mass-produced, spiritually hollow, mechanically slightly weaker per-move but overwhelming in breadth. Your club's answer is fewer hybrids, forged through actual relationships, each carrying duo VFX and feud/alliance history. The final dual is the melting-pot argument, played with fists.
