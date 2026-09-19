"""sim/agents.py - the two minds in the reference sim (PAC-050).
PatternAgent drives a compiled data/patterns/*.json boss: idle gaps, tell ->
string -> recovery, phase unlocks, desperation. PlayerModel is a parameterized
human: reaction time vs telegraph, defense skill, offense tempo, punch variety
(the adaptation tracker's food), counter conversion.
"""
import json, random
from .engine import TICK_MS

PUNCH_MAP = {  # PBN action verbs -> punch_matrix rows (movement verbs -> None)
 "JAB": "L_STRAIGHT", "L_STR": "L_STRAIGHT", "R_STR": "R_STRAIGHT",
 "L_HOOK": "L_HOOK", "R_HOOK": "R_HOOK", "R_UPC": "R_UPPERCUT", "L_UPC": "L_UPPERCUT",
 "R_HAY": "R_HOOKERCUT", "R_OVERHAND": "R_FLARED", "CHECK_HOOK": "L_HOOK",
 "LT_L_HOOK": "L_HOOK", "LT_R_HOOK": "R_HOOK", "LT_R_UPC": "R_UPPERCUT",
 "COUNTER_R_STR": "R_STRAIGHT", "COUNTER_L_HOOK": "L_HOOK", "STEP_R_STR": "R_STRAIGHT",
 "UNDER_ELBOW_CROSS": "R_STRAIGHT", "PULL_COUNTER_OVERHAND": "R_FLARED",
}

class PatternAgent:
    def __init__(self, pattern_path, rng):
        self.p = json.load(open(pattern_path))
        self.rng = rng
        self.phase = 1
        self.state = "IDLE"          # IDLE -> TELL -> ACTING -> RECOVER
        self.timer_ms = self.rng.randint(400, 900)
        self.current = None
        self.action_q = []
        self.desperation_used = False

    def _phase_ok(self, name):
        tags = self.p["strings"][name]["tags"]
        for t in tags:
            if t.startswith("phase>="):
                return self.phase >= int(t.split(">=")[1])
        return True

    def _pick(self):
        w = {k: v for k, v in (self.p.get("select") or {"weights": {}})["weights"].items()
             if k in self.p["strings"] and self._phase_ok(k) and v > 0}
        # phase-local strings without base weight get a default
        for k in self.p["strings"]:
            if k not in w and self._phase_ok(k):
                w[k] = 20
        total = sum(w.values())
        r = self.rng.random() * total
        for k, v in w.items():
            r -= v
            if r <= 0: return k
        return next(iter(w))

    def update_phase(self, me, clock_s):
        for ph in self.p["phases"]:
            trig = ph["trigger"]
            n = None
            if "composure<" in trig:
                n = float(trig.split("composure<")[1].split()[0])
                if me.composure <= me.comp_max * n / 100.0:
                    self.phase = max(self.phase, _phase_num(ph["phase"], self.phase))
            elif "clock>" in trig:
                n = float(trig.split("clock>")[1].rstrip("s").split()[0])
                if clock_s > n:
                    self.phase = max(self.phase, _phase_num(ph["phase"], self.phase))

    def step(self, me, foe, clock_s):
        """Returns list of events: ('tell', string) | ('punch', matrix_row, telegraph_ms, cls) | ('desperation', move)"""
        out = []
        self.update_phase(me, clock_s)
        d = self.p.get("desperation") or {}
        if (not self.desperation_used and "move" in d
                and me.composure <= me.comp_max * 0.25):
            self.desperation_used = True
            out.append(("desperation", d["move"]))
            self.state, self.timer_ms = "RECOVER", 1500
            return out
        self.timer_ms -= TICK_MS
        if self.timer_ms > 0:
            return out
        if self.state in ("IDLE", "RECOVER"):
            self.current = self._pick()
            s = self.p["strings"][self.current]
            self.state, self.timer_ms = "TELL", s["tell"]["ms"]
            out.append(("tell", self.current))
        elif self.state == "TELL":
            s = self.p["strings"][self.current]
            self.action_q = [a.split("(")[0].split()[0] for a in s["actions"]]
            self.state = "ACTING"; self.timer_ms = 0
        if self.state == "ACTING":
            while self.action_q:
                a = self.action_q.pop(0)
                if a in PUNCH_MAP:
                    s = self.p["strings"][self.current]
                    out.append(("punch", PUNCH_MAP[a], s["tell"]["ms"], s["class"]))
                    self.timer_ms = 300   # inter-action beat
                    return out
            self.state = "RECOVER"
            self.timer_ms = self.rng.randint(400, 800)   # >=400ms neutral gap guarantee
        return out

def _phase_num(p, cur):
    try: return int(p)
    except ValueError: return cur + 1   # named phases (finale) advance

class PlayerModel:
    """Parameterized human. skill in [0,1] scales reaction, defense, variety."""
    def __init__(self, skill, rng, tempo_ms=900):
        self.skill, self.rng = skill, rng
        self.reaction_ms = 340 - 160 * skill          # 340ms novice -> 180ms sharp
        self.defense_skill = 0.25 + 0.55 * skill
        self.counter_conv = 0.35 + 0.5 * skill
        self.p_repeat = 0.65 - 0.5 * skill            # novices spam; the tracker eats them
        self.tempo_ms = tempo_ms
        self.cooldown = rng.randint(200, 800)
        self.last = ["L_STRAIGHT"]
        self.arsenal = ["L_STRAIGHT", "R_STRAIGHT", "L_HOOK", "R_HOOK", "R_UPPERCUT"]

    def defend_prob(self, telegraph_ms, cls, tracker_bonus=0.0):
        margin = telegraph_ms - self.reaction_ms
        base = 0.0 if margin <= 0 else min(0.92, self.defense_skill * (0.5 + margin / 800.0))
        if cls == "ARMORED": base *= 0.85      # dodge-only pressure
        return max(0.0, min(0.95, base))

    def next_punch(self):
        self.cooldown -= TICK_MS
        if self.cooldown > 0: return None
        self.cooldown = self.tempo_ms + self.rng.randint(-150, 150)
        if self.rng.random() < self.p_repeat:
            pick = self.last[-1]
        else:
            pick = self.rng.choice([p for p in self.arsenal if p != self.last[-1]])
        self.last.append(pick)
        if len(self.last) > 3: self.last.pop(0)
        return pick
