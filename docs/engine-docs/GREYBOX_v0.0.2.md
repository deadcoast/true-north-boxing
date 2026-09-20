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

## Verification status (agent-run, headless Godot 4.3, this container)

- Boots clean; zero script errors across 1800-frame soaks vs all 4 bosses.
- Smoke suite 17/17 GREEN per boss (run it yourself: add `-- smoke` to the
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
