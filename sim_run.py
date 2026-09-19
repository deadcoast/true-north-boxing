#!/usr/bin/env python3
"""sim_run.py - PAC-050 metric harness, measurement layer corrected per the
codex REQ-02 review (REQUISITION_001):
  a) TTFD reports its denominator: droppers n/N, median over droppers only,
     no-drop rate alongside - no survivorship medians presented bare.
  b) win means a FIGHT OUTCOME: KO, or drop-count decision at the time cap;
     drops_for>drops_against alone is no longer called a win.
  c) gassed band is 'present but <15%': presence is checked, zero is a WARN.
  d) adaptation flags are counted as flag EVENTS per 90s SEGMENT (median),
     from Tracker.push instrumentation - never distinct grams per fight.
  e) counter-rate spread is pooled p90/p10 across every run of every tier,
     the NP_13 s6 shape - tier-mean ratios are reported as context only.
Simulated fights, never human playtests; bands here gate the reference, and
P1 playtest data supersedes all of it.

  python3 tools/sim_run.py [--boss cassidy_vane] [--n 120]
"""
import sys, os, random, argparse, statistics as st
sys.path.insert(0, os.getcwd())
from sim.engine import Tuning, Fighter, Tracker, Exchange, standing_eight, TICK_MS
from sim.agents import PatternAgent, PlayerModel

BOSS_STATS = {"PWR": 60, "SPD": 55, "CHN": 60, "RFX": 55, "BLK": 55, "STA": 60, "HRT": 60}
PLAYER_STATS = {"PWR": 45, "SPD": 50, "CHN": 45, "RFX": 50, "BLK": 45, "STA": 50, "HRT": 99}
SEGMENT_S = 90.0

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
    s = {"p_thrown": 0, "p_landed": 0, "p_counters": 0, "flag_events": [],
         "gassed_ticks": 0, "ticks": 0, "ttfd_s": None,
         "drops_for": 0, "drops_against": 0, "outcome": None}
    clock = 0.0

    def finish(outcome):
        s["outcome"] = outcome
        return s

    while clock < max_s:
        clock += TICK_MS / 1000.0
        s["ticks"] += 1
        player.tick(player.busy_ms > 0); boss.tick(boss.busy_ms > 0); tracker.tick()
        if player.stamina < 15: s["gassed_ticks"] += 1
        for ev in agent.step(boss, player, clock):
            kind = ev[0]
            if kind == "punch":
                _, row, tele, cls = ev
                r = ex.resolve(boss, player, row, tele, model.defend_prob(tele, cls))
                if r["result"] == "DROP":
                    player.drops_taken += 1; s["drops_against"] += 1
                    if player.drops_taken >= 3 or not standing_eight(player, t, rng):
                        return finish("KO_LOSS")
                elif r["result"] == "EVADED" and rng.random() < model.counter_conv:
                    cr = ex.resolve(player, boss, "R_STRAIGHT", 0, 0.1, counter=True)
                    s["p_thrown"] += 1
                    if cr["result"] in ("HIT", "DROP"):
                        s["p_landed"] += 1; s["p_counters"] += 1
                    if cr["result"] == "DROP":
                        s["drops_for"] += 1
                        if s["ttfd_s"] is None: s["ttfd_s"] = clock
                        boss.drops_taken += 1
                        if boss.drops_taken >= 3 or not standing_eight(boss, t, rng):
                            return finish("KO_WIN")
            elif kind == "desperation":
                r = ex.resolve(boss, player, "R_HOOKERCUT", 1200,
                               model.defend_prob(1200, "SPECIAL"), mods=["POWER"])
                if r["result"] == "DROP":
                    player.drops_taken += 1; s["drops_against"] += 1
                    if player.drops_taken >= 3 or not standing_eight(player, t, rng):
                        return finish("KO_LOSS")
        if player.busy_ms <= 0:
            p = model.next_punch()
            if p:
                s["p_thrown"] += 1
                tier = tracker.flagged(model.last)
                for _gram, _tier in tracker.push(p):
                    s["flag_events"].append(clock)
                boss_defend = 0.35 + tracker.defense_bonus(tier)
                pd = Tuning().punch(p)
                player.busy_ms = pd["startup_ms"] + pd["recovery_ms"]
                r = ex.resolve(player, boss, p, pd["startup_ms"], boss_defend,
                               counter=player.counter_window_ms > 0)
                if r["result"] in ("HIT", "DROP", "GUARD_BREAK"):
                    s["p_landed"] += 1
                if r["result"] == "DROP":
                    s["drops_for"] += 1
                    if s["ttfd_s"] is None: s["ttfd_s"] = clock
                    boss.drops_taken += 1
                    if boss.drops_taken >= 3 or not standing_eight(boss, t, rng):
                        return finish("KO_WIN")
                player.counter_window_ms = 0
    # time cap: decision on drop count, else no decision
    if s["drops_for"] > s["drops_against"]: return finish("DECISION_WIN")
    if s["drops_for"] < s["drops_against"]: return finish("DECISION_LOSS")
    return finish("NO_DECISION")

def pct(vals, p):
    v = sorted(vals)
    return v[min(len(v) - 1, int(p * len(v)))] if v else 0.0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boss", default="cassidy_vane")
    ap.add_argument("--n", type=int, default=120)
    a = ap.parse_args()
    pat = f"data/patterns/{a.boss}.json"
    print(f"SIM METRICS v2 :: NP_13 s6 bands vs {a.boss}  (n={a.n}/tier, seeds 0..{a.n-1}; simulated, not human)")
    print("=" * 86)
    tiers = {"novice": 0.15, "median": 0.45, "skilled": 0.85}
    R, pooled_cr = {}, []
    for name, sk in tiers.items():
        runs = [run_fight(pat, sk, seed) for seed in range(a.n)]
        cr = [r["p_counters"] / max(1, r["p_thrown"]) for r in runs]
        pooled_cr += cr
        droppers = [r["ttfd_s"] for r in runs if r["ttfd_s"] is not None]
        seg_flags = []
        for r in runs:
            fight_s = r["ticks"] * TICK_MS / 1000.0
            n_seg = max(1, int(fight_s // SEGMENT_S) + (1 if fight_s % SEGMENT_S > 5 else 0))
            counts = [0] * n_seg
            for ts in r["flag_events"]:
                counts[min(n_seg - 1, int(ts // SEGMENT_S))] += 1
            seg_flags += counts
        wins = sum(1 for r in runs if r["outcome"] in ("KO_WIN", "DECISION_WIN"))
        gassed_present = sum(1 for r in runs if r["gassed_ticks"] > 0)
        R[name] = {"droppers": droppers, "n": len(runs),
                   "ttfd_med": st.median(droppers) if droppers else None,
                   "cr_mean": st.mean(cr), "seg_flags": seg_flags,
                   "gassed_pct_med": st.median(r["gassed_ticks"] / r["ticks"] for r in runs) * 100,
                   "gassed_present_pct": 100.0 * gassed_present / len(runs),
                   "win_pct": 100.0 * wins / len(runs)}
        d = R[name]
        ttfd = f"{d['ttfd_med']:.1f}s over {len(droppers)}/{d['n']} droppers" if droppers else f"none in {d['n']}"
        print(f"  {name:<8} outcome-wins {d['win_pct']:5.1f}%   first-drop: {ttfd:<28} "
              f"cr {d['cr_mean']:.3f}   gassed-present {d['gassed_present_pct']:4.1f}% of fights")
    print("-" * 86)
    findings = []
    nov = R["novice"]
    if nov["droppers"] and len(nov["droppers"]) >= 0.3 * nov["n"]:
        ok = 60 <= nov["ttfd_med"] <= 180
        print(f"  [{' OK ' if ok else 'WARN'}]  TTFD novice: {nov['ttfd_med']:.1f}s median over {len(nov['droppers'])}/{nov['n']} - band 60-180s")
        if not ok: findings.append("ttfd")
    else:
        print(f"  [WARN]  TTFD novice: only {len(nov['droppers'])}/{nov['n']} fights produced a first drop - "
              "band assumes new players DO drop boss 1; denominator too thin for a median claim")
        findings.append("ttfd_denominator")
    p90, p10 = pct(pooled_cr, 0.90), pct(pooled_cr, 0.10)
    spread = p90 / max(0.001, p10)
    ok = spread >= 3.0
    print(f"  [{' OK ' if ok else 'WARN'}]  counter-rate pooled p90/p10: {p90:.3f}/{p10:.3f} = {spread:.2f}x - band >=3x "
          f"(tier-mean ratio {R['skilled']['cr_mean']/max(0.001,R['novice']['cr_mean']):.2f}x, context only)")
    if not ok: findings.append("spread")
    med = R["median"]
    present = med["gassed_present_pct"] > 0
    under = med["gassed_pct_med"] <= 15.0
    tag = " OK " if present and under else "WARN"
    print(f"  [{tag}]  gassed: present in {med['gassed_present_pct']:.1f}% of median-tier fights, "
          f"median time {med['gassed_pct_med']:.1f}% - band 'present but <15%'"
          + ("  <- NOT PRESENT" if not present else ""))
    if tag == "WARN": findings.append("gassed_presence")
    fl = st.median(med["seg_flags"]) if med["seg_flags"] else 0
    ok = 1.0 <= fl <= 3.0
    print(f"  [{' OK ' if ok else 'WARN'}]  adaptation flag EVENTS per segment, median tier: {fl:.1f} - band 1-3")
    if not ok: findings.append("flags")
    print("=" * 86)
    print(f"  VERDICT :: {'GREEN - bands hold on reference sim' if not findings else 'FINDINGS: ' + ', '.join(findings) + ' - tuning-proposal inputs, nothing auto-tuned'}")

if __name__ == "__main__":
    main()
