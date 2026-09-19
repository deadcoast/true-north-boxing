#!/usr/bin/env python3
"""sim_test.py - unit gates locking sim/engine.py to the NP_03 spec numbers.
Every assertion cites its tuning key. Run from repo root; exit 1 on any failure.
"""
import sys, os, random
sys.path.insert(0, os.getcwd())
from sim.engine import Tuning, Fighter, Tracker, Exchange, TICK_MS

t = Tuning(); rng = random.Random(7)
S = {"PWR": 50, "SPD": 50, "CHN": 50, "RFX": 50, "BLK": 50, "STA": 50, "HRT": 50}
fails = []
def chk(name, ok):
    print(f"  [{' OK ' if ok else 'FAIL'}]  {name}")
    if not ok: fails.append(name)

# gassed curve thresholds (stamina.gassed_curve)
f = Fighter("x", S, t, rng)
f.stamina = 71; chk("stamina 71 -> full-speed row", f.gassed()["hand_speed"] == 1.00)
f.stamina = 41; chk("stamina 41 -> 0.90 row", f.gassed()["hand_speed"] == 0.90)
f.stamina = 16; chk("stamina 16 -> 0.75 row", f.gassed()["hand_speed"] == 0.75)
f.stamina = 5;  chk("stamina 5  -> danger row, comp regen 0", f.gassed()["composure_regen"] == 0.0)

# composure pool = CHN*2; wobble below 35%
chk("composure pool = CHN*2", f.comp_max == 100.0)
f.composure = 34.9; chk("wobble at <35% pool", f.wobbled())
f.composure = 35.1; chk("no wobble at >35% pool", not f.wobbled())

# guard capacity lerp 80-130 by BLK; break refill 40 after OPEN
g0 = Fighter("g", dict(S, BLK=0), t, rng);  g99 = Fighter("g", dict(S, BLK=99), t, rng)
chk("guard capacity BLK0 ~80 / BLK99 =130", abs(g0.guard_max - 80) < 1 and abs(g99.guard_max - 130) < 0.1)
f.guard = 0.0; f.guard_open_ms = t["guard"]["break_open_ms"]
for _ in range(int(t["guard"]["break_open_ms"] / TICK_MS) + 1): f.tick(False)
chk("guard refills to 40 after OPEN elapses", abs(f.guard - 40) < t["guard"]["regen_per_s"])

# exchange: DROP fires only at composure<=0 on hit; counter mult = 1.6
ex = Exchange(t, random.Random(3))
a = Fighter("a", dict(S, PWR=50), t, rng); d = Fighter("d", S, t, rng)
d.composure = 5.0
r = ex.resolve(a, d, "R_UPPERCUT", 0, 0.0)
chk("hit at low composure -> DROP", r["result"] == "DROP")
a2, d2 = Fighter("a", S, t, rng), Fighter("d", S, t, rng)
base = ex.resolve(a2, d2, "R_STRAIGHT", 0, 0.0)["dmg"]
a3, d3 = Fighter("a", S, t, rng), Fighter("d", S, t, rng)
ctr = ex.resolve(a3, d3, "R_STRAIGHT", 0, 0.0, counter=True)["dmg"]
chk("counter mult applies x1.6", abs(ctr / base - t["counter_mults"]["counter"]) < 0.01)

# zone multipliers: defender on ropes x1.25, corner x1.5
a4, d4 = Fighter("a", S, t, rng), Fighter("d", S, t, rng)
d4.pos = 1.5; ropes = ex.resolve(a4, d4, "R_STRAIGHT", 0, 0.0)["dmg"]
a5, d5 = Fighter("a", S, t, rng), Fighter("d", S, t, rng)
d5.pos = 0.5; corner = ex.resolve(a5, d5, "R_STRAIGHT", 0, 0.0)["dmg"]
chk("ropes x1.25 / corner x1.5 zone mods", abs(ropes/base - 1.25) < 0.01 and abs(corner/base - 1.5) < 0.01)

# tracker: 3rd repeat of a 2-gram flags; decay clears after 8s
tr = Tracker(t)
for _ in range(3): tr.push("JAB"); tr.push("HOOK")
chk("2-gram flagged at 3rd occurrence", tr.flagged(["JAB", "HOOK"]) >= 1)
chk("defense bonus +25%/tier capped 85%", abs(tr.defense_bonus(1) - 0.25) < 0.001 and tr.defense_bonus(9) == 0.85)
for _ in range(int(8000 / TICK_MS) + 2): tr.tick()
chk("flag tier decays after 8s quiet", tr.flagged(["JAB", "HOOK"]) == 0)

# chip through block = 15% of damage
a6, d6 = Fighter("a", S, t, rng), Fighter("d", S, t, rng)
rr = random.Random(0)
ex2 = Exchange(t, rr)
got = None
for _ in range(200):
    d7 = Fighter("d", S, t, rng)
    res = ex2.resolve(Fighter("a", S, t, rng), d7, "R_STRAIGHT", 0, 1.0)
    if res["result"] == "BLOCKED":
        got = res["dmg"] / base; break
chk("block chip = 15% of full damage", got is not None and abs(got - 0.15) < 0.01)

print("-" * 54)
print(f"  {14 - len(fails)}/14 gates green")
sys.exit(1 if fails else 0)
