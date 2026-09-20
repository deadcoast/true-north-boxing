# NP-11 — CHARACTER PROGRESSION & DATA STRUCTURES

**Project Northpaw design vault · Doc 11/13**
Related: [[NP_03_COMBAT_ENGINE]] · [[NP_05_TENSION_HISSATSU]] · [[NP_07_HOUSES]] · [[NP_08_STABLE]] · [[NP_10_TACTICS]]

The build-craft sandbox: stats and their exact sim hooks, the level curve, ability boards, rarity, currencies with earn/spend rates, teachable techniques, training minigames, and the canonical data schemas. Governing promise: **no fighter is ever content-obsoleted** — your day-one best friend can be built into the endgame.

---

## 1. STATS (7, range 1–99)

| Stat | Sim hooks (exact, per [[NP_03_COMBAT_ENGINE]]) |
| --- | --- |
| **PWR** | Damage formula multiplier (base × PWR/50); guard-shred scaling |
| **SPD** | Hand-speed multiplier on startup frames (99 SPD: −20% startup); foot speed 2.2→3.4 m/s |
| **CHN** | Composure pool = CHN×2; wobble threshold scaling |
| **RFX** | Counter-window widths (+0→+150 ms across range); auto-guard tracking 70→95%; clinch-cue size |
| **BLK** | Guard meter capacity 80→130; guard regen 4→9/s |
| **STA** | Stamina pool 80→120; regen scaling; gassed-curve thresholds shift down 5 pts at 99 |
| **HRT** | Standing-eight beat windows ±60→±140 ms; trailing-state buffs (+5% stats while down on DROPS at HRT 70+); Tension personal-contribution ×1.1 at 80+ |
Soft caps: 70+ costs double board points; 90+ requires rarity tier 3 ([[§4]]). Stat totals by rarity keep early recruits viable: any fighter can reach tier 3.

## 2. LEVELS & XP

- Level 1–50. XP from all three fight sizes ([[NP_02_TWO_LAYER]]); curve: quadratic-gentle (level 50 ≈ 120k XP; a story-pace player hits ~35 by Arc 3 start; 50 is postgame polish).
- Levels grant: **Board Points** (2/level — the ability-board currency), technique slots at 5/15/25/35/45 (5 slots max + house-native bonus slots which ADD, per the [[NP_07_HOUSES]] §7 no-invalidation rule), T0 signature at 5, Zone eligibility at 20.
- Reserve XP: undressed stablemates earn 50% of dual XP (training-partner role boosts to 65%) — the anti-benchrot valve.
- The no-name hidden curve: houseless fighters +10% XP ([[NP_07_HOUSES]] §5).

## 3. ABILITY BOARDS (per-fighter)

Hex-node board, ~60 nodes, three lobes with a shared spine:

- **Body lobe:** stat nodes (+2/+3/+5 tiers), soft-cap breakers.
- **Craft lobe:** passives — e.g. *Tight Guard* (guard decay −20% while holding), *Snap* (jab damage +30%), *Ring Cutter* (herding +25%), *Iron Jaw* (wobble duration −30%), *Second Gear* (gassed-curve penalties −50% between 15–40 stamina). Launch passive pool: 40.
- **Spirit lobe:** Tension/hissatsu economy — *Sparkplug* (personal Tension contribution ×1.15), *Cheap Trick* (T0 cost 8), *Closer* (CHARGED threshold −5), *Wallflower* (T2 durations +1 s).
- **Spine:** style-identity nodes; the **Boxer-Puncher off-style socket** ([[NP_06_AFFINITY]] §1.2) sits here.
- Respec: free at the gym (Film Room T2+). Boards differ by Style archetype (4 board layouts) — not per-character (content sanity), with 2–4 unique nodes injected per *named* character (their personal flavor).

## 4. RARITY TIERS (1–4: Club / Circuit / National / Legend)

Ascension: Spirits + a Trial spar (the fighter must *do* something — beat a mirror match, weather a transform — ascension is diegetic). Tier grants: stat-cap raises (→80/→90/→99), +1 equip slot for accessories, tier-3 unlocks 90+ caps, tier-4 (Legend) unlocks the Awakening eligibility flag (story characters pre-flagged). **Every recruit, including generics, can reach tier 4.** Rarity is a ladder, not a birthright — the system-level restatement of the no-name promise.

## 5. ACCESSORIES & GEAR

Cosmetic-forward (gloves, wraps, robes, mouthguards) with small passive slots (≤3% effects; gear never outweighs boards). Gear sources: shops (HBP), circuit prizes, house gifts, festival events. Signature gear for named characters is untradeable identity (Yuri's grain-sack wraps).

## 6. CURRENCY MATRIX (canonical; earn rates are launch baselines)

| Currency | Earn (typical/session) | Sinks | Notes |
| --- | --- | --- | --- |
| **XP** | continuous | Levels | — |
| **Spirits** | 3–8 (spars/duals) | Rarity ascension (10/25/60), Forge events | The "you fought real matches" currency |
| **HBP (Hot-Blood Points)** | 50–150 (quests, wins, story) | Techniques (shop tiers 100–800), gear, training bookings | The spendy wallet |
| **Prestige** | 5–15 (scraps, rep) | Scouting machine pulls (10), open-mat priority | The grinder's wallet |
| **Beans** | per training slot (3–10) | Stat raises (+1 = 5 Beans, scaling), Forge events | Diegetic: an actual bean jar on the gym counter |
| **Tension** | in-dual only | in-dual only | Never persists ([[NP_05_TENSION_HISSATSU]]) |
| **Kizuna** | pairwise meters | thresholds only | Not spendable ([[NP_08_STABLE]] §5) |
Faucet/sink audit runs per milestone ([[NP_13_SCOPE]] §6): target — a story-pace player affords 70% of desired sinks; completionists find Prestige/Beans the long tails.

## 7. TRAINING MINIGAMES (Beans faucet; 3 slots/day; facility-tiered)

| Minigame | Skill exercised | Beans |
| --- | --- | --- |
| **Mitts** | Punch-matrix accuracy: called combos, RS precision under tempo | 3–6 |
| **Heavy Bag** | Power timing: haymaker release windows, stamina management | 3–6 |
| **Roadwork** (snow routes on The Hill) | Rhythm runner: pacing bar management; squad members along = Kizuna | 3–5 |
| **Slip Bag** (T2) | Head-movement patterns: escalating slip strings | 4–8 |
| **Net Haul** (harbour, unlocked via MacIsaac content) | Pull-timing; PWR-bean specialist | 5–8 |
| **Shadow Rounds** (T3) | Free-form vs. ghost of any Scout Book pattern — the training loop and recon loop shake hands | 6–10 |
Each minigame yields typed Beans (PWR/SPD/etc. bias by game); partner choice adds their stat flavor. Minigames are speedrun-friendly (input-skill = yield) and never mandatory (Beans also drip from quests).

## 8. TEACHABLE TECHNIQUES

Sources: **masters** (recruit/befriend → they teach their list, some gated by BOND or STAT_PROOF), **HBP shop** (generic library, tiers by circuit progress), **teaching items** (single-use scrolls—er, *fight tapes*: found, quest-rewarded, festival prizes), **house natives** (membership/gift only, [[NP_07_HOUSES]] §4), **hybrids** (Forge, [[NP_08_STABLE]] §6). Transfer: any learned non-native technique can be re-taught to a stablemate via a training-slot session (the original keeps it). Constraint: slot scarcity (5+natives) is the build-defining pressure — who carries what, who teaches whom, is stable-wide planning.

## 9. CANONICAL SCHEMAS (v1.0 — source of truth for save + content DB)

```jsonc
Fighter {
  id, name, nickname, age, pronouns, home_district, club_id,
  house_id: string|null, house_status: NATIVE|MARRIAGE|ADOPTED|MENTORSHIP|UNSANCTIONED|null,
  style: SWARMER|OUTBOXER|SLUGGER|BOXERPUNCHER,
  element: FROST|GALE|GRANITE|TIMBER,
  stats: {PWR,SPD,CHN,RFX,BLK,STA,HRT},        // 1-99
  level, xp, rarity: 1..4, board: {layout_id, nodes_taken[], points_free},
  technique_slots: [hissatsu_id], native_slots: [hissatsu_id],
  signature_t0: hissatsu_id, zone_unlocked, manifest_id|null, awakening_flag,
  gear: [item_id, ...3], personality: {talk_profile, bark_set},
  bonds: [{fighter_id, kizuna, level}],
  ai_profile: {archetype_weights, pi_map},       // manager-mode brain
  pattern_ref|null, tell: {channel,tier,motif},  // opponent-side + spar exhibition
  recruit: {channel, conditions[], state}, stable_role: FIGHTER|TRAINING|SCOUT|CORNER_TRAINEE
}
Hissatsu {
  id, name, tier: T0..T4, family: RISE|ARC|PISTON|HAYMAKER|WALL|SURGE,
  element, house_id|null, style_req|null, tension_cost, private_meter_cost|null,
  startup_cinematic_ms, effect: [ {type: DMG|SHRED|BURN|DISPLACE|STATE|BUFF|WALL, params} ],
  counter_profile: {interruptible, window_ms, negation_rules},
  duo_variant|null, hybrid_parents|null, camera_script_id, vfx_set
}
House { /* per [[NP_07_HOUSES]] §2 */ }
Staff { id, name, role, passive(s), active: {effect, charges}, level, recruit }
Club { id, name, crest, coach_profile, tactic_library[], super_equipped,
       facility_tiers{}, entrance_set, roster[], order_archetype_weights, decoy_rate }
DualState {
  segment_idx: 1..6, clock, score: {drops_h, drops_a, ep_by_segment[]},
  tension: {home, away}, relay: {charged, chain}, lineups: {sealed[], revealed[]},
  corner_budget, tactics_cooldowns, supers_used, zone_states, transform_log[],
  adaptation: {window[], flags[]}, crowd_heat, injuries[]
}
SaveGame { calendar, story_flags{}, stable[], staff[], club, currencies{},
  scout_book{pi_map, pages[]}, string_wall{maps[], leads[]}, gym_wall{layout, decorations},
  house_codex{}, feud_graph_state, hybrid_registry[], settings }
```

All content tables (tuning, patterns, houses, moves, tactics) live in hot-reloadable data ([[NP_03_COMBAT_ENGINE]] §12 ownership model extends game-wide).

## 10. THE OBSOLESCENCE AUDIT (recurring design gate)

Per milestone, take the three earliest-recruitable fighters and build them for the current endgame using live systems only. If any cannot reach viability (tier 4, competitive board, coherent technique kit), the failing system — not the fighter — gets fixed. The promise is tested, not assumed.
