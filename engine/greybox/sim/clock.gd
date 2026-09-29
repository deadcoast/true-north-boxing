extends RefCounted
const TNBSim := preload("res://sim/core.gd")
# C1: the only place render time meets sim time. Feed it wall-clock frame
# slices; it answers how many fixed 120Hz ticks to run and the interpolation
# alpha for drawing between the last two ticks. The sim never sees a delta.
# The same object drives main.gd and the -- determinism test, so the test
# proves the code the game runs.

const MAX_FRAME := 0.25          # a hitch never queues more than 30 ticks

var acc := 0.0

func advance(delta: float) -> int:
	acc += minf(maxf(delta, 0.0), MAX_FRAME)
	# Equivalent frame partitions can land a few ulps below a tick (e.g. six
	# 144 Hz frames). Do not postpone an input boundary for rounding residue.
	# The tolerance is in ticks: less than 9 picoseconds, not an early frame.
	var n := int(floor(acc / TNBSim.DT + 1e-9))
	acc = maxf(0.0, acc - float(n) * TNBSim.DT)
	return n

func alpha() -> float:
	return clampf(acc / TNBSim.DT, 0.0, 1.0)
