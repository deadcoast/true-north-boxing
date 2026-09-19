# TNB GREYBOX - proof of engine
Run (no editor): `godot --path .\engine\greybox`

Blue capsule = you. Red capsule = the boss, driven by the real compiled PBN
(`patterns/` are the same JSONs the game will ship). Yellow flash + swell =
tell; hit him during it = interrupt + flash window. All numbers load from
`combat_tuning.v1.json` - edit it, press R in-game, feel the change.

PAD: LS move | RS flick = punch by angle | RT block (150ms perfect window)
     LT+LS = slip | LT+punch = body | RB = power | LB+haymaker flick @100 = ABB
KEYS: WASD | J/K jab/cross, U/I hooks, O uppercut | Space block | Q/E slip
      Shift power | C body | H hissatsu-arm | ENTER = rise beats when dropped
META: 1-4 boss select (Vane/Yuri/Moreau/Sam) | R reload tuning | F5 rematch

In here already: stamina/composure/guard + gassed curve, counter + flash
windows, adaptation tracker narrated on the feed line (spam a combo, watch
him start blocking it), Tension meter, DROP + standing-eight beats,
three-knockdown rule, 90s segment clock, Punch-Out camera.

## Phase 2 in the build: THE ROTATION DUAL
Three segments, rotation both sides: you fight R1 as RORY, R2 as PRIYA
(fast, fragile, huge reflex windows), R3 as MARCUS (truck with no guard) -
against three different pattern bosses. Corner phase between segments
([1] send next / [2] rest +20 stamina). Tension is ONE shared bar across
the whole dual; bank 25+ in your segment and the next fighter enters
CHARGED - 10s surge, hissatsu arms at 50. Drops + EP score the dual;
verdict card at the end. F5 starts a fresh dual.

## Phase 3 in the build: RING GEOGRAPHY + SPATIAL DODGES
The space is mechanical now. Zones (CENTER / MID / ROPES / CORNER) drive
damage - x1.25 on the ropes, x1.5 in the corner, +2 Tension on center-ring
exchanges. Every landed punch herds the other man 10-20cm; the boss
intercepts your escape angle instead of chasing your position, so circling
out is a read, never a free walk. Three seconds pinned in a corner arms
CORNER TRAP: guard bleeds double, damage peaks, and your counter reads
widen x1.4 - the desperation window. Head movement is spatial: slips
displace you 35cm laterally (uppercuts punish them x1.5), lean-back beats
hooks and gives ground, weave (V, or LT+forward) arcs you around him and
is the trap escape. HUD reads both fighters' zones live.

## Verification status (agent-run, headless Godot 4.3, this container)
- Boots clean; zero script errors across 3600-frame soaks vs all 4 bosses.
- Smoke suite 33/33 GREEN per boss (combat 17 + dual 8 + geography/dodges 8) (run it yourself: add `-- smoke` to the
  command): tracker flagging + narration, stamina drain, tell interrupt +
  flash window + tension pay, DROP + 50pct composure reset, player drop ->
  standing-eight -> rise + regen halt, guard break -> 40 refill, hissatsu
  arm at 100 / bar zeroed with only the drop bonus as residue, live agent
  string cycling with phases.
- Bugs the loop caught and fixed before you ever loaded it: hissatsu
  self-refunding tension on its own landing; desperation arming stalling
  the agent in an empty TELL state (Yuri/Moreau stuck); a Variant-typed
  damage inference that failed to parse at all.
- NOT verified: game feel. That is the part that is yours, whenever.

Posture (PACER CLIENT FIXES, in force): one development thread, [B]-shape -
phases inside a single continuous build, agent verifies in-container with
headless Godot + smoke suites, guardrails protect finished content only.
No proposals, no REVIEW parking, no user load-and-test until the build
reaches coherent operational state.
