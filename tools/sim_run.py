#!/usr/bin/env python3
"""sim_run.py - PAC-050 metric harness. Simulates player-model vs compiled
bosses and reports the NP_13 s6 combat bands. Run from repo root.

  python3 tools/sim_run.py                 # full metric suite, all bands
  python3 tools/sim_run.py --boss vane --n 200
"""
import sys, os, random, argparse, statistics as st
sys.path.insert(0, os.getcwd())
from sim.engine import Tuning, Fighter, Tracker, Exchange, standing_eight, TICK_MS
from sim.agents import PatternAgent, PlayerModel

BOSS_STATS = {"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}
PLAYER_STATS = {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}

def run_fight(pattern, skill, seed, max_s=270):
    rng = random.Random(seed)
    t = Tuning()
    player = Fighter("player", PLAYER_STATS, t, rng)
    boss = Fighter("boss", BOSS_STATS, t, rng)
    player.pos, boss.pos = 10.0, 14.0
    agent = PatternAgent(pattern, rng)
    model = PlayerModel(skill, rng)
    tracker = Tracker(t)
    ex = Exchange(t, rng)
    stats = {"p_thrown": 0, "p_landed": 0, "p_counters": 0, "flags_seen": set(),
             "gassed_ticks": 0, "ticks": 0, "ttfd_s": None, "drops_for": 0, "drops_against": 0}
    clock = 0.0
    while clock < max_s:
        clock += TICK_MS / 1000.0
        stats["ticks"] += 1
        player.tick(player.busy_ms > 0); boss.tick(boss.busy_ms > 0); tracker.tick()
        if player.stamina < 15: stats["gassed_ticks"] += 1
        # ---- boss acts ----
        for ev in agent.step(boss, player, clock):
            kind = ev[0]
            if kind == "punch":
                _, row, tele, cls = ev
                r = ex.resolve(boss, player, row, tele, model.defend_prob(tele, cls))
                if r["result"] == "DROP":
                    player.drops_taken += 1; stats["drops_against"] += 1
                    if player.drops_taken >= 3 or not standing_eight(player, t, rng):
                        return stats
                elif r["result"] == "EVADED" and rng.random() < model.counter_conv:
                    cr = ex.resolve(player, boss, "R_STRAIGHT", 0, 0.1, counter=True)
                    stats["p_thrown"] += 1
                    if cr["result"] in ("HIT", "DROP"):
                        stats["p_landed"] += 1; stats["p_counters"] += 1
                    if cr["result"] == "DROP":
                        stats["drops_for"] += 1
                        if stats["ttfd_s"] is None: stats["ttfd_s"] = clock
                        boss.drops_taken += 1
                        if boss.drops_taken >= 3 or not standing_eight(boss, t, rng): return stats
            elif kind == "desperation":
                r = ex.resolve(boss, player, "R_HOOKERCUT", 1200, model.defend_prob(1200, "SPECIAL"),
                               mods=["POWER"])
                if r["result"] == "DROP":
                    player.drops_taken += 1; stats["drops_against"] += 1
                    if player.drops_taken >= 3 or not standing_eight(player, t, rng): return stats
        # ---- player acts ----
        if player.busy_ms <= 0:
            p = model.next_punch()
            if p:
                stats["p_thrown"] += 1
                tier = tracker.flagged(model.last)
                tracker.push(p)
                if tier: stats["flags_seen"].add(tuple(model.last[-2:]))
                boss_defend = 0.35 + tracker.defense_bonus(tier)
                pd = Tuning().punch(p)
                player.busy_ms = pd["startup_ms"] + pd["recovery_ms"]
                r = ex.resolve(player, boss, p, pd["startup_ms"], boss_defend,
                               counter=player.counter_window_ms > 0)
                if r["result"] in ("HIT", "DROP", "GUARD_BREAK"):
                    stats["p_landed"] += 1
                if r["result"] == "DROP":
                    stats["drops_for"] += 1
                    if stats["ttfd_s"] is None: stats["ttfd_s"] = clock
                    boss.drops_taken += 1
                    if boss.drops_taken >= 3 or not standing_eight(boss, t, rng): return stats
                player.counter_window_ms = 0
    return stats

def band(label, value, lo, hi, fmt="{:.1f}"):
    ok = " OK " if (lo is None or value >= lo) and (hi is None or value <= hi) else "WARN"
    rng_s = f"{lo}-{hi}" if lo is not None and hi is not None else (f">={lo}" if hi is None else f"<={hi}")
    print(f"  [{ok}]  {label:<44} {fmt.format(value):>8}   band {rng_s}")
    return ok == " OK "

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boss", default="cassidy_vane")
    ap.add_argument("--n", type=int, default=120)
    a = ap.parse_args()
    pat = f"data/patterns/{a.boss}.json"
    print(f"SIM METRICS :: NP_13 s6 bands  vs {a.boss}  (n={a.n}/skill tier, seed-deterministic)")
    print("=" * 74)
    tiers = {"novice": 0.15, "median": 0.45, "skilled": 0.85}
    results = {}
    for name, sk in tiers.items():
        runs = [run_fight(pat, sk, seed) for seed in range(a.n)]
        cr = [r["p_counters"] / max(1, r["p_thrown"]) for r in runs]
        results[name] = {
            "ttfd": [r["ttfd_s"] for r in runs if r["ttfd_s"] is not None],
            "counter_rate": st.mean(cr),
            "gassed_pct": st.mean(r["gassed_ticks"] / r["ticks"] for r in runs) * 100,
            "flags": st.mean(len(r["flags_seen"]) for r in runs),
            "win_pct": st.mean(1.0 if r["drops_for"] > r["drops_against"] else 0.0 for r in runs) * 100}
        print(f"  {name:<8} counter-rate {results[name]['counter_rate']:.3f}   "
              f"gassed {results[name]['gassed_pct']:5.1f}%   flags/fight {results[name]['flags']:.1f}   "
              f"win {results[name]['win_pct']:5.1f}%   ttfd n={len(results[name]['ttfd'])}")
    print("-" * 74)
    ok = True
    nov = results["novice"]["ttfd"]
    if nov:
        ok &= band("time-to-first-DROP p50, novice (s)", st.median(nov), 60, 180)
    else:
        print("  [WARN]  time-to-first-DROP: novice never dropped the boss - tuning finding")
        ok = False
    spread = results["skilled"]["counter_rate"] / max(0.001, results["novice"]["counter_rate"])
    ok &= band("counter-rate spread (skilled/novice)", spread, 3.0, None, "{:.2f}x")
    ok &= band("gassed-state time, median tier (%)", results["median"]["gassed_pct"], None, 15.0)
    ok &= band("adaptation flags per fight, median tier", results["median"]["flags"], 1.0, 3.0)
    print("=" * 74)
    print(f"  VERDICT :: {'GREEN - bands hold on reference sim' if ok else 'FINDINGS - out-of-band values are tuning work, reported honestly'}")

if __name__ == "__main__":
    main()
