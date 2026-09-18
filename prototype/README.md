# PAC-002 input experiment

Engine selected by the user: **Godot 4**. The current experiment runs on the
locally installed **Godot 4.5.1**, using GDScript, the compatibility renderer,
a 120 FPS cap and VSync off. Engine selection is settled; the original physical
latency gate remains open. This is a diagnostic scene, not the P1 Two Hands build.

```powershell
$godot = 'C:\Program Files\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe'
& $godot --path prototype --log-file input-lab.log
& $godot --headless --path prototype --log-file input-tests.log --script tests/test_input.gd
```

Flick the right stick from neutral. For a keyboard diagnostic, Q/W/E are
up-left/up/up-right; A/D left/right; Z/X/C down-left/down/down-right. Each accepted
direction triggers the same placeholder glove animation and emits JSON to stdout.
These keys are diagnostic controls, not the final remapping/accessibility preset.
F5 reloads `input_tuning.json`; invalid tuning leaves the last valid settings intact.
Thresholds are provisional experiment settings, separate from combat frame data.

The recognizer uses neutral rearming, separate activation/reset radii and a maximum
excursion time. Held sticks cannot auto-repeat; slow excursions need a neutral
reset. Devices are isolated and reset on disconnect or focus loss. Axis pairs are
sampled together each rendered frame to avoid classifying a diagonal's first axis
as a cardinal flick. Input accumulation is disabled; frame sampling delay remains
inside the software event-to-trigger measurement.

Telemetry measures **Godot event delivery to animation trigger**, excluding
controller polling, OS transport, render submission, display scanout and pixel
response. It never claims the <=50 ms physical-to-visible target. Headless tests
verify synthetic vectors and scene wiring only; they cannot measure visible
animation or real controller accuracy. The runtime keeps the latest 256 records;
stdout is the full stream.

PAC-002 remains open for a declared target PC/controller/display, high-speed capture
of physical flick onset versus first visible motion, the <=50 ms gate at 120 FPS,
and >=99% measured direction discrimination across eight vectors. Record engine,
renderer, refresh/VSync settings, capture rate, sample count and the raw results.
No passing hardware result is present in this repository yet.

The current synthetic verification is recorded in
[`evidence/PAC-002-godot4.json`](../evidence/PAC-002-godot4.json).
The older headless report is retained as historical evidence; its requirement ID
predates register reconciliation. The current input requirement is OGM-018.

NP-03 defines ten punches but leaves hand selection for an exactly vertical stick
gesture ambiguous. This experiment emits eight direction names; final punch/hand
mapping, haymakers, modifiers, damage and combat timings remain under PAC-005.

Implementation references: [Godot 4.5 Input](https://docs.godotengine.org/en/4.5/classes/class_input.html),
[one-axis joypad events](https://docs.godotengine.org/en/4.5/classes/class_inputeventjoypadmotion.html),
and [command-line execution](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html).
