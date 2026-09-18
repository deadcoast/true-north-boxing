#!/usr/bin/env python3
"""hissatsu_audit.py - content gate for the hissatsu library (NP_13 s5 hissatsu
gate, mechanized). Enforces schema conformance and the NP_05A distribution law.
Exit 0 green / 1 violations. Run from repo root after any rebuild.
"""
import json, sys, collections

FAM = {"RISE","ARC","PISTON","HAYMAKER","WALL","SURGE"}
ELEM = {"FROST","GALE","GRANITE","TIMBER","DUAL","ANY"}
TIER_COST = {"T0":10,"T1":35,"T2":25,"T3":50}
CINE = {"T0":(800,1200),"T1":(1200,1800),"T2":(1000,1500),"T3":(1800,2500)}
HOUSES = ["tremblay","kowalchuk","okafor","reyes","macisaac","whitecloud","tagaq",
          "nguyen-roy","petrov","osei","delacroix-cardinal","iron","moreau","sealed"]
DESPERATIONS_04A = ["Undertow","Pont Couvert","Empty Net","Fevrier","Deep Roots","Thesis Defense"]
CANON_05 = ["Aurora Borealis Breaker","Grain Elevator","Premiere Neige","Sorry Eh",
            "Net-Hauler's Yank","Liver Line","Pressure Cooker","Long Winter","Two Rivers"]

def main():
    lib = json.load(open("data/hissatsu_library.v1.json"))
    moves = lib["moves"]
    fails = []
    def chk(ok, where, rule):
        if not ok: fails.append((where, rule))

    print("HISSATSU AUDIT :: NP_13 s5 gate, mechanized")
    print("=" * 58)

    # -- schema conformance ------------------------------------------------
    names, ids = set(), set()
    for m in moves:
        w = m["name"]
        chk(m["id"] not in ids, w, "duplicate id"); ids.add(m["id"])
        chk(w not in names, w, "duplicate name"); names.add(w)
        chk(m["tier"] in TIER_COST, w, f"illegal tier {m['tier']}")
        chk(m["family"] in FAM, w, f"illegal family {m['family']}")
        chk(m["element"] in ELEM, w, f"illegal element {m['element']}")
        chk(m["tension_cost"] >= TIER_COST.get(m["tier"], 0) - 2, w, "cost below tier floor")
        lo, hi = CINE[m["tier"]]
        chk(lo <= m["startup_cinematic_ms"] <= hi, w, f"cinematic {m['startup_cinematic_ms']}ms outside tier budget {lo}-{hi}")
        chk(len(m["effect"]) >= 1, w, "empty effect block")
        cp = m["counter_profile"]
        chk(isinstance(cp.get("interruptible"), bool) and "negation" in cp, w, "counter profile incomplete")
        if m["house_id"] != "sealed":
            chk("REDACTED" not in json.dumps(m["effect"]), w, "redacted payload outside sealed house")
    print(f"  [{'FAIL' if fails else ' OK '}]  schema conformance ({len(moves)} moves)")

    # -- distribution law --------------------------------------------------
    b = len(fails)
    chk(len(moves) == 80, "library", f"count {len(moves)} != 80")
    by_house = collections.defaultdict(list)
    for m in moves:
        if m["house_id"]: by_house[m["house_id"]].append(m)
    for h in HOUSES:
        n = len(by_house[h]); sec = sum(1 for m in by_house[h] if m["secret"])
        if h == "iron":
            chk(n == 1 and sec == 1, h, "dead lineage holds exactly its one SECRET")
        else:
            chk(2 <= n <= 4, h, f"native count {n} outside 2-4 (NP_07 s4)")
            chk(sec == 1, h, f"SECRET count {sec} != 1")
    for nm in DESPERATIONS_04A + CANON_05:
        chk(nm in names, nm, "canon move missing from library")
    elems = collections.Counter(m["element"] for m in moves if m["element"] in ("FROST","GALE","GRANITE","TIMBER"))
    for e, n in elems.items():
        chk(n >= 12, e, f"element underweight ({n} < 12)")
    walls = [m for m in moves if m["family"] == "WALL"]
    chk(all(m["tier"] in ("T2","T3") for m in walls), "walls", "WALL family outside T2/T3")
    chk(sum(1 for m in moves if not m["counter_profile"]["interruptible"] and m["family"] != "WALL") <= 6,
        "armored", "more than 6 armored non-wall moves (dodge-only must stay rare)")
    print(f"  [{'FAIL' if len(fails) > b else ' OK '}]  distribution law")

    # -- verdict -----------------------------------------------------------
    tiers = collections.Counter(m["tier"] for m in moves)
    srcs = collections.Counter(m["source"].split(":")[0] for m in moves)
    print("=" * 58)
    print("  tiers  :: " + " | ".join(f"{t} {tiers[t]}" for t in ("T0","T1","T2","T3")))
    print("  elems  :: " + " | ".join(f"{e} {elems[e]}" for e in ("FROST","GALE","GRANITE","TIMBER"))
          + f" | DUAL/ANY {sum(1 for m in moves if m['element'] in ('DUAL','ANY'))}")
    print("  source :: " + " | ".join(f"{s} {n}" for s, n in sorted(srcs.items(), key=lambda x: -x[1])))
    print(f"  houses :: {len([h for h in HOUSES if by_house[h]])}/14 covered | secrets {sum(1 for m in moves if m['secret'])}")
    if fails:
        print(f"  VERDICT :: RED - {len(fails)} violation(s)")
        for w, r in fails: print(f"    {w:<28} {r}")
        sys.exit(1)
    print("  VERDICT :: GREEN - library gate-clean")
    sys.exit(0)

if __name__ == "__main__":
    main()
