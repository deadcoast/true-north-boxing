#!/usr/bin/env python3
"""pbn_compiler.py - PAC-011A: the PBN (Pattern Boss Notation) compiler core.
Engine-independent: parses pbn/*.pbn per NP_04 s2 grammar, enforces the safety
rails as COMPILE ERRORS, and emits behavior-tree JSON to data/patterns/.
Engine integration, hot-reload, and the live visualizer are PAC-011B.

Grammar (strict form; NP_04 s2 blocks normalize to this):
  BOSS <Id>
    META key=value ...                      # style, element, house, slot, arc, wall_gauge...
    IDLE: token, token
    STRING <name> "<Label>" [TAG ...]: TELL(<motif>, <ms>ms) -> ACT -> ACT
       tags: ARMORED | SPECIAL | STATE=<s> | phase>=N | zone==ZONE
    SELECT: w(<name>)=N, ... [| <cond>: w(<name>)+=N ...]
    INTERRUPT: <name>[,<name>] during TELL -> <response>
    BAIT: <trigger> -> force <name>    |    BAIT: none "<authored reason>"
    PUNISH: <trigger> -> <response>
    PHASE <n> @ <cond>: <directives>
    DESPERATION @ <cond>: hissatsu "<Library Name>" [+ arm_only "<Name>"]
    DESPERATION: none "<authored reason>"
    TRANSFORM @ <cond>: <tier> ["<manifest name>"] TELL(<motif>, <ms>ms) "<line>"   # PAC-086: NP_09 s1, authored per boss

Safety rails (errors): TELL floors 400/700/1000ms (normal/SPECIAL/ARMORED);
desperation moves must exist in the library with cinematic >=1200ms; SELECT
must reference declared strings; duplicate string names; unparseable lines;
a TRANSFORM names a tier a boss can cast (data/transformations.v1.json's boss
block), a manifest its name, a tell at the boss floor (1000ms) and a line.
Template rails (errors unless authored-absent with reason): >=1 BAIT, >=2 PUNISH.

Usage:  python3 tools/pbn_compiler.py            # compile pbn/ -> data/patterns/
        python3 tools/pbn_compiler.py --selftest # seeded-violation negative test
"""
import json, os, re, sys, glob, argparse

FLOORS = {"normal": 400, "SPECIAL": 700, "ARMORED": 1000}
DESPERATION_CINE_FLOOR = 1200

def load_library():
    lib = json.load(open("data/hissatsu_library.v2.json"))
    return {m["name"]: m for m in lib["moves"]}

def load_boss_transforms():
    # PAC-086: the tiers a boss can cast and his tell floor, from the transformations table
    try:
        t = json.load(open("data/transformations.v1.json"))
    except OSError:
        return {"tiers": [], "tell_floor_ms": 1000}
    b = t.get("boss", {})
    return {"tiers": [x for x in b.get("tiers", []) if t.get("tiers", {}).get(x, {}).get("executed", False)], "tell_floor_ms": int(b.get("tell_floor_ms", 1000))}

def parse(src: str, fname: str, lib: dict):
    boss, errors = {"file": fname, "meta": {}, "idle": [], "strings": {}, "select": None,
                    "interrupt": [], "bait": [], "punish": [], "phases": [], "desperation": None}, []
    def err(line_no, msg): errors.append(f"{fname}:{line_no}: {msg}")

    for i, raw in enumerate(src.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("BOSS "):
            boss["id"] = line[5:].strip()
        elif line.startswith("META "):
            for kv in line[5:].split():
                if "=" in kv:
                    k, v = kv.split("=", 1); boss["meta"][k] = v
        elif line.startswith("IDLE:"):
            boss["idle"] = [t.strip() for t in line[5:].split(",") if t.strip()]
        elif line.startswith("STRING "):
            m = re.match(r'STRING\s+(\w+)\s+"([^"]+)"\s*((?:\[[^\]]+\]\s*)*):\s*TELL\(([^,]+),\s*(\d+)ms\)\s*->\s*(.+)', line)
            if not m:
                err(i, "unparseable STRING line"); continue
            name, label, tagblob, motif, ms, acts = m.groups()
            tags = re.findall(r"\[([^\]]+)\]", tagblob)
            if name in boss["strings"]:
                err(i, f"duplicate string name '{name}'")
            cls = "ARMORED" if any(t == "ARMORED" for t in tags) else \
                  "SPECIAL" if any(t == "SPECIAL" for t in tags) else "normal"
            ms = int(ms)
            if ms < FLOORS[cls]:
                err(i, f"string '{name}': TELL {ms}ms below {cls} floor {FLOORS[cls]}ms")
            boss["strings"][name] = {"label": label, "tags": tags, "tell": {"motif": motif.strip(), "ms": ms},
                                     "class": cls, "actions": [a.strip() for a in acts.split("->")]}
        elif line.startswith("SELECT:"):
            body = line[7:]
            base, *conds = [p.strip() for p in body.split("|")]
            weights = dict(re.findall(r"w\((\w+)\)\s*=\s*(\d+)", base))
            boss["select"] = {"weights": {k: int(v) for k, v in weights.items()},
                             "reweights": conds}
            for s in weights:
                if s not in boss["strings"]:
                    err(i, f"SELECT references undeclared string '{s}'")
        elif line.startswith("INTERRUPT:"):
            m = re.match(r"INTERRUPT:\s*([\w,\s]+?)\s+during TELL\s*->\s*(.+)", line)
            if not m:
                err(i, "unparseable INTERRUPT line"); continue
            names = [n.strip() for n in m.group(1).split(",")]
            for n in names:
                if n not in boss["strings"]:
                    err(i, f"INTERRUPT references undeclared string '{n}'")
                elif boss["strings"][n]["class"] == "ARMORED":
                    err(i, f"INTERRUPT on ARMORED string '{n}' (armored = dodge-only, NP_04 s4)")
            boss["interrupt"].append({"strings": names, "response": m.group(2).strip()})
        elif line.startswith("BAIT:"):
            body = line[5:].strip()
            m = re.match(r'none\s+"([^"]+)"', body)
            if m:
                boss["bait"].append({"authored_absent": m.group(1)})
            else:
                m = re.match(r"(.+?)\s*->\s*force\s+(\w+)", body)
                if not m:
                    err(i, "unparseable BAIT line"); continue
                if m.group(2) not in boss["strings"]:
                    err(i, f"BAIT forces undeclared string '{m.group(2)}'")
                boss["bait"].append({"trigger": m.group(1).strip(), "force": m.group(2)})
        elif line.startswith("PUNISH:"):
            m = re.match(r"PUNISH:\s*(.+?)\s*->\s*(.+)", line)
            if not m:
                err(i, "unparseable PUNISH line"); continue
            boss["punish"].append({"trigger": m.group(1).strip(), "response": m.group(2).strip()})
        elif line.startswith("PHASE "):
            m = re.match(r"PHASE\s+(\w+)\s*@\s*(.+?):\s*(.+)", line)
            if not m:
                err(i, "unparseable PHASE line"); continue
            boss["phases"].append({"phase": m.group(1), "trigger": m.group(2).strip(),
                                   "directives": [d.strip() for d in m.group(3).split(";")]})
        elif line.startswith("DESPERATION"):
            m = re.match(r'DESPERATION:\s*none\s+"([^"]+)"', line)
            if m:
                boss["desperation"] = {"authored_absent": m.group(1)}; continue
            m = re.match(r'DESPERATION\s*@\s*(.+?):\s*hissatsu\s+"([^"]+)"(?:\s*\+\s*arm_only\s+"([^"]+)")?', line)
            if not m:
                err(i, "unparseable DESPERATION line"); continue
            trigger, move, arm = m.groups()
            if move not in lib:
                err(i, f"desperation move '{move}' not in library v2")
            elif lib[move]["startup_cinematic_ms"] < DESPERATION_CINE_FLOOR:
                err(i, f"desperation '{move}' cinematic {lib[move]['startup_cinematic_ms']}ms below {DESPERATION_CINE_FLOOR}ms floor")
            if arm and arm not in lib:
                err(i, f"arm_only move '{arm}' not in library v2")
            boss["desperation"] = {"trigger": trigger.strip(), "move": move, "arm_only": arm}
        elif line.startswith("TRANSFORM"):
            m = re.match(r'TRANSFORM\s*@\s*(.+?):\s*(\w+)(?:\s+"([^"]+)")?\s+TELL\(([^,]+),\s*(\d+)ms\)\s+"([^"]+)"\s*$', line)
            if not m:
                err(i, "unparseable TRANSFORM line"); continue
            trigger, tier, mname, motif, ms, said = m.groups()
            bt = load_boss_transforms()
            if tier not in bt["tiers"]:
                err(i, f"transform tier '{tier}' is not one a boss can cast ({', '.join(bt['tiers'])})")
            if int(ms) < bt["tell_floor_ms"]:
                err(i, f"transform tell {ms}ms below the {bt['tell_floor_ms']}ms floor (NP_09 s1: felt coming)")
            if tier == "manifest" and not mname:
                err(i, "a manifest transform names its manifest")
            if "transform" in boss:
                err(i, "one TRANSFORM per boss (NP_09 s1: one per fighter per dual)")
            tf = {"trigger": trigger.strip(), "tier": tier, "tell": {"motif": motif.strip(), "ms": int(ms)}, "line": said}
            if mname: tf["manifest"] = mname
            boss["transform"] = tf
        else:
            err(i, f"unrecognized line: {line[:60]}")

    # template rails (NP_04 s5: >=1 BAIT, >=2 PUNISH; authored-absent needs a reason)
    if not boss["bait"]:
        errors.append(f"{fname}: no BAIT and no authored-absent reason (template rail)")
    if len(boss["punish"]) < 2 and not any("authored_absent" in b for b in boss["bait"]):
        # bosses with authored-empty bait state institutional character; punish rail still applies
        pass
    if len(boss["punish"]) < 2:
        errors.append(f"{fname}: fewer than 2 PUNISH hooks (template rail)")
    if not boss["strings"]:
        errors.append(f"{fname}: no strings declared")
    if boss.get("select") is None and not boss["phases"]:
        errors.append(f"{fname}: no SELECT and no phase-local selection")
    return boss, errors

# NP_14 C4: Hick-Hyman choice reaction time, RT(n) = a + b*log2(n+1).
# a = 225 ms (simple visual RT band 200-250 ms), b = 150 ms/bit (classic slope).
# Sources: Hick (1952), Hyman (1953); Proctor & Schneider 2018 review.
HH_A_MS, HH_B_MS = 225.0, 150.0
import math
def hick_hyman_ms(n: int) -> float:
    return HH_A_MS + HH_B_MS * math.log2(n + 1)

def margins():
    """Print tell - RT(n) for every string of every pattern, n=1 (known pattern,
    one response) and n=3 (cold read: block / slip / interrupt). Asserts every
    SPECIAL and ARMORED tell clears the cold 3-way decision (NP_14 C4)."""
    lib = load_library()
    rt1, rt3 = hick_hyman_ms(1), hick_hyman_ms(3)
    print(f"PBN TELL MARGINS :: Hick-Hyman a={HH_A_MS:.0f}ms b={HH_B_MS:.0f}ms/bit  RT(1)={rt1:.0f}ms  RT(3)={rt3:.0f}ms")
    print("=" * 78)
    worst = {"normal": None, "SPECIAL": None, "ARMORED": None}
    fails, n_strings = [], 0
    tfs = []
    for path in sorted(glob.glob("pbn/*.pbn")):
        boss, errs = parse(open(path).read(), os.path.basename(path), lib)
        if "transform" in boss:                                   # PAC-086: a boss's transformation tell must clear the cold read too
            tms = boss["transform"]["tell"]["ms"]
            tfs.append(f"{boss.get('id','?')} {boss['transform']['tier']} {tms}ms ({tms - rt3:+.0f}ms vs RT(3))")
            if tms - rt3 < 0:
                fails.append(f"{boss.get('id','?')} TRANSFORM tell {tms}ms is {rt3 - tms:.0f}ms under RT(3)")
        for name, st in boss["strings"].items():
            n_strings += 1
            ms, cls = st["tell"]["ms"], st["class"]
            m1, m3 = ms - rt1, ms - rt3
            if worst[cls] is None or m3 < worst[cls][0]:
                worst[cls] = (m3, f"{boss.get('id','?')}/{name}")
            if cls != "normal" and m3 < 0:
                fails.append(f"{boss.get('id','?')}/{name} {cls} tell {ms}ms is {-m3:.0f}ms under RT(3)")
    for cls in ("normal", "SPECIAL", "ARMORED"):
        m3, who = worst[cls] if worst[cls] else (float("nan"), "-")
        floor = FLOORS[cls]
        print(f"  {cls:<8} floor {floor:>4}ms   floor-RT(1) {floor-rt1:>+6.0f}ms   floor-RT(3) {floor-rt3:>+6.0f}ms   "
              f"worst authored string vs RT(3): {m3:+.0f}ms ({who})")
    print("-" * 78)
    print(f"  {n_strings} strings across {len(glob.glob('pbn/*.pbn'))} patterns")
    print(f"  transformation tells (NP_09 s1, felt coming): {'; '.join(tfs) if tfs else 'none authored'}")
    print("  reading: normal strings are below a COLD 3-way decision on purpose - they are read by pattern")
    print("           knowledge (n->1, RT 375ms). SPECIAL/ARMORED must clear the cold read outright.")
    for f in fails:
        print("  ! " + f)
    print(f"  VERDICT :: {'GREEN - every SPECIAL/ARMORED tell and every transformation tell clears RT(3)' if not fails else 'RED'}")
    sys.exit(0 if not fails else 1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--margins", action="store_true", help="NP_14 C4: print tell - Hick-Hyman RT margins")
    a = ap.parse_args()
    if a.margins:
        margins(); return
    lib = load_library()

    if a.selftest:
        bad = ('BOSS SelfTest\n  STRING s1 "Fast": TELL(x, 200ms) -> JAB\n'
               '  STRING s1 "Dup": TELL(y, 500ms) -> JAB\n'
               '  SELECT: w(s1)=50, w(ghost)=50\n'
               '  INTERRUPT: s1 during TELL -> stagger(800)\n'
               '  DESPERATION @ composure<20: hissatsu "Not A Real Move"\n'
               '  TRANSFORM @ composure<50: awakening TELL(x, 500ms) "too fast, and not his to cast"\n'
               '  TRANSFORM @ clock>45: manifest TELL(x, 1200ms) "a second line, and a manifest with no name"\n')
        _, errs = parse(bad, "selftest.pbn", lib)
        expected = ["below normal floor", "duplicate string", "undeclared string 'ghost'",
                    "not in library", "no BAIT", "fewer than 2 PUNISH", "not one a boss can cast", "transform tell 500ms below",
                    "names its manifest", "one TRANSFORM per boss"]
        hits = [e for e in expected if any(e in x for x in errs)]
        print("PBN COMPILER SELFTEST :: seeded %d violation classes" % len(expected))
        for e in expected:
            print(f"  [{' OK ' if e in hits else 'MISS'}]  catches: {e}")
        sys.exit(0 if len(hits) == len(expected) else 1)

    os.makedirs("data/patterns", exist_ok=True)
    srcs = sorted(glob.glob("pbn/*.pbn"))
    print(f"PBN COMPILER :: PAC-011A core  ({len(srcs)} sources, library v2 loaded)")
    print("=" * 62)
    total_errs, compiled = 0, 0
    for path in srcs:
        boss, errs = parse(open(path).read(), os.path.basename(path), lib)
        tag = "FAIL" if errs else " OK "
        n_s, n_p = len(boss["strings"]), len(boss["phases"])
        print(f"  [{tag}]  {boss.get('id','?'):<22} strings {n_s:>2}  phases {n_p}  "
              f"bait {len(boss['bait'])}  punish {len(boss['punish'])}")
        for e in errs:
            print(f"          ! {e}")
        total_errs += len(errs)
        if not errs:
            out = f"data/patterns/{os.path.splitext(os.path.basename(path))[0]}.json"
            json.dump(boss, open(out, "w"), indent=1)
            compiled += 1
    print("=" * 62)
    print(f"  compiled {compiled}/{len(srcs)}   errors {total_errs}")
    print(f"  VERDICT :: {'GREEN - patterns emitted to data/patterns/' if total_errs == 0 else 'RED'}")
    sys.exit(0 if total_errs == 0 else 1)

if __name__ == "__main__":
    main()
