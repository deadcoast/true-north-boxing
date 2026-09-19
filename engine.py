"""sim/engine.py - headless combat-sim reference (PAC-050).
Pure Python, consumes data/combat_tuning.v1.json verbatim. The NP_03 state
machines at 16ms ticks: stamina, composure, guard, counter windows, zones (1D
reference abstraction), wobble/DROP/standing-eight, and the adaptation tracker.
This is the tested reference PAC-005..009 port to Godot - spec questions get
answered here with numbers, and every constant traces to the tuning file.
"""
import json, random

TICK_MS = 16

class Tuning:
    def __init__(self, path="data/combat_tuning.v1.json"):
        self.d = json.load(open(path))
    def punch(self, name): return self.d["punch_matrix"][name]
    def __getitem__(self, k): return self.d[k]

def lerp(a, b, t): return a + (b - a) * t

class Fighter:
    def __init__(self, name, stats, tuning, rng):
        self.name, self.s, self.t, self.rng = name, stats, tuning, rng
        self.stamina = float(tuning["stamina"]["pool_base"])
        self.comp_max = stats["CHN"] * 2.0
        self.composure = self.comp_max
        g = tuning["guard"]["capacity_by_BLK"]
        self.guard_max = lerp(g["min"], g["max"], stats["BLK"] / 99.0)
        self.guard = self.guard_max
        self.guard_open_ms = 0          # OPEN state after break
        self.busy_ms = 0                # startup+recovery in flight
        self.counter_window_ms = 0      # open window to counter
        self.counter_kind = None
        self.no_comp_regen_ms = 0       # post-count vulnerability
        self.drops_taken = 0
        self.pos = 12.0                 # 1D arena 0..24ft; spawn at center (edge zones are earned, never default)
        self.pinned_ms = 0

    # ---- per-tick upkeep ----
    def tick(self, acting):
        st = self.t["stamina"]
        self.stamina = min(100.0, self.stamina + (st["regen_active_per_s"] if acting else st["regen_neutral_per_s"]) * TICK_MS / 1000.0)
        if self.no_comp_regen_ms > 0:
            self.no_comp_regen_ms -= TICK_MS
        else:
            self.composure = min(self.comp_max, self.composure + self.t["composure"]["regen_per_s"] * TICK_MS / 1000.0)
        if self.guard_open_ms > 0:
            self.guard_open_ms -= TICK_MS
            if self.guard_open_ms <= 0:
                self.guard = self.t["guard"]["break_refill"]
        else:
            self.guard = min(self.guard_max, self.guard + self.t["guard"]["regen_per_s"] * TICK_MS / 1000.0)
        if self.busy_ms > 0: self.busy_ms -= TICK_MS
        if self.counter_window_ms > 0: self.counter_window_ms -= TICK_MS

    def gassed(self):
        for row in self.t["stamina"]["gassed_curve"]:
            if self.stamina > row["above"]:
                return row
        return self.t["stamina"]["gassed_curve"][-1]

    def wobbled(self):
        return self.composure < self.comp_max * self.t["composure"]["wobble_below_pct"] / 100.0

class Tracker:
    """Adaptation tracker per NP_03 s10: 12-token window, 2/3-gram flags."""
    def __init__(self, tuning):
        c = tuning["adaptation_tracker"]
        self.window, self.n, self.flag_at = [], c["window_tokens"], c["flag_at_count"]
        self.ramp, self.cap = c["defense_ramp_per_tier_pct"] / 100.0, c["ramp_cap_pct"] / 100.0
        self.decay_ms, self.flags = c["decay_clear_s"] * 1000, {}   # gram -> [tier, ms_since_seen]
    def push(self, token):
        """Returns list of flag EVENTS this push caused: [(gram, new_tier)] on new
        flag or tier-up. Correct per-segment flag counting hangs off this return
        (codex REQ-02c finding: distinct-grams-per-fight was the wrong measure)."""
        events = []
        self.window.append(token)
        if len(self.window) > self.n: self.window.pop(0)
        for size in (2, 3):
            if len(self.window) >= size:
                gram = tuple(self.window[-size:])
                cnt = sum(1 for i in range(len(self.window) - size + 1)
                          if tuple(self.window[i:i+size]) == gram)
                if cnt >= self.flag_at:
                    prev = self.flags.get(gram, [0, 0])[0]
                    tier = min(3, prev + 1)
                    if tier > prev:
                        events.append((gram, tier))
                    self.flags[gram] = [tier, 0]
        return events
    def tick(self):
        for g in list(self.flags):
            self.flags[g][1] += TICK_MS
            if self.flags[g][1] >= self.decay_ms:
                self.flags[g][0] -= 1; self.flags[g][1] = 0
                if self.flags[g][0] <= 0: del self.flags[g]
    def flagged(self, last_tokens):
        for size in (3, 2):
            g = tuple(last_tokens[-size:]) if len(last_tokens) >= size else None
            if g in self.flags: return self.flags[g][0]
        return 0
    def defense_bonus(self, tier):
        return min(self.cap, self.ramp * tier)

class Exchange:
    """Resolves one punch from attacker vs defender. Returns event dict."""
    def __init__(self, tuning, rng): self.t, self.rng = tuning, rng

    def resolve(self, atk, dfn, punch_name, telegraph_ms, defend_prob, mods=None, counter=False):
        p = dict(self.t.punch(punch_name)); mods = mods or []
        dmg, guard_dmg, stam = p["dmg"], p["guard_dmg"], p["stamina"]
        if "POWER" in mods:
            m = self.t["modifiers"]["POWER"]; dmg *= m["dmg_mult"]; stam *= m["stamina_mult"]
        atk.stamina = max(0.0, atk.stamina - stam)
        gf = atk.gassed()
        dmg *= gf["dmg"] * (atk.s["PWR"] / 50.0)
        if counter:
            dmg *= self.t["counter_mults"]["counter"]
        # zone: ropes/corner multiplier off defender edge distance
        edge = min(dfn.pos, 24.0 - dfn.pos)
        if edge <= 1.0: dmg *= self.t["zones"]["CORNER"]["dmg_mult"]
        elif edge <= 2.0: dmg *= self.t["zones"]["ROPES"]["dmg_mult"]
        # defense roll
        if dfn.busy_ms <= 0 and dfn.guard_open_ms <= 0 and self.rng.random() < defend_prob:
            if self.rng.random() < 0.55:                      # blocks
                chip = dmg * self.t["guard"]["chip_pct"] / 100.0
                dfn.composure -= chip; dfn.guard -= guard_dmg
                if dfn.guard <= 0:
                    dfn.guard_open_ms = self.t["guard"]["break_open_ms"]
                    return {"result": "GUARD_BREAK", "dmg": chip}
                # perfect block chance opens widest window
                if self.rng.random() < 0.25:
                    dfn.counter_window_ms = self.t["counter_windows_ms"]["perfect_block"]["base"]
                    dfn.counter_kind = "perfect_block"
                return {"result": "BLOCKED", "dmg": chip}
            else:                                             # slips
                dfn.counter_window_ms = self.t["counter_windows_ms"]["slip"]["base"]
                dfn.counter_kind = "slip"
                return {"result": "EVADED", "dmg": 0.0}
        dfn.composure -= dmg
        if dfn.composure <= 0:
            return {"result": "DROP", "dmg": dmg}
        return {"result": "HIT", "dmg": dmg}

def standing_eight(fighter, tuning, rng):
    """Pass probability from HRT beat windows; drop count ladder per NP_03 s9."""
    se = tuning["standing_eight"]
    w = lerp(se["beat_window_ms_by_HRT"]["hrt30"], se["beat_window_ms_by_HRT"]["hrt90"],
             max(0.0, (fighter.s["HRT"] - 30) / 60.0))
    p_beat = min(0.98, 0.45 + w / 200.0)
    beats = se["beats"] - max(0, fighter.drops_taken - 1)     # ladder: fewer forgiving beats
    if beats <= 0: return False
    passed = all(rng.random() < p_beat for _ in range(se["beats"]))
    if passed:
        fighter.composure = fighter.comp_max * tuning["composure"]["post_count_reset_pct"] / 100.0
        fighter.no_comp_regen_ms = tuning["composure"]["regen_halt_after_count_s"] * 1000
    return passed
