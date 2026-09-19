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

Register: this is PAC-005..009 greybox-tier, in flight as one lane. Guardrail
posture from here: build -> you play -> you say what feels wrong. Proposal
ceremony is retired until vertical slice; D8 sign-off is reserved for cutting
content, never for greybox tuning.
