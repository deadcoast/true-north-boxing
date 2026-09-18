#!/usr/bin/env python3
"""pacer_validator.py - mechanical enforcement of AGENTS.md section 7 across all
four PACER organs. Run before every commit that touches a register.

  python3 pacer_validator.py            # validate registers in cwd
  python3 pacer_validator.py --dir path # validate another repo

Exit 0 = green. Exit 1 = violations (each printed with organ, row, rule).
"""
import csv, os, sys, argparse, re

ORGANS = {
    "todo":     ("todo.PACER.csv",     ["ID","Title","Phase","Status","DoD"]),
    "overlord": ("overlord.PACER.csv", ["ID","AssetType","Path","Purpose"]),
    "organism": ("organism.PACER.csv", ["ID","Title","Status","Requirement"]),
    "nodule":   ("nodule.PACER.csv",   ["ID","NoduleName","Intent","Status"]),
}
TODO_STATUS = {"TODO","DOING","REVIEW","DONE"}
OGM_STATUS  = {"VALIDATED_COMPLETE","PACED_REQUIREMENT","SCAFFOLD"}
NDL_STATUS  = {"PLANNED","ACTIVE","ABSORBED"}
REF_RX = re.compile(r"\b(PAC|OVR|OGM|NDL)-\d{3}[A-Z]?\b")

class Report:
    def __init__(self):
        self.fails, self.checks = [], 0
    def check(self, ok, organ, where, rule):
        self.checks += 1
        if not ok:
            self.fails.append((organ, where, rule))
    def section(self, name, before):
        n = len(self.fails) - before
        mark = "FAIL" if n else " OK "
        print(f"  [{mark}]  {name:<34} {'+' + str(n) + ' violation(s)' if n else ''}")

def refs(cell):
    return [x.strip() for x in (cell or "").split(";") if x.strip()]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=".")
    a = ap.parse_args()
    os.chdir(a.dir)
    rep = Report()
    data, ids = {}, {}

    print("PACER VALIDATOR :: AGENTS.md s7")
    print("=" * 58)

    # -- load + structure ------------------------------------------------
    b = len(rep.fails)
    for organ, (path, req_cols) in ORGANS.items():
        if not os.path.exists(path):
            rep.check(False, organ, path, "register file missing"); data[organ] = []; continue
        rows = list(csv.DictReader(open(path, newline="")))
        data[organ] = rows
        cols = rows[0].keys() if rows else csv.DictReader(open(path, newline="")).fieldnames or []
        for c in req_cols:
            rep.check(c in cols, organ, path, f"required column absent: {c}")
        seen = set()
        for r in rows:
            rep.check(r["ID"] not in seen, organ, r["ID"], "duplicate ID")
            seen.add(r["ID"])
        ids[organ[:3].upper() if organ != "todo" else "PAC"] = seen
    ids = {"PAC": {r["ID"] for r in data["todo"]},
           "OVR": {r["ID"] for r in data["overlord"]},
           "OGM": {r["ID"] for r in data["organism"]},
           "NDL": {r["ID"] for r in data["nodule"]}}
    rep.section("parse / columns / unique IDs", b)

    # -- todo: statuses, dep resolution, cycles, DONE gate ---------------
    b = len(rep.fails)
    by_id = {r["ID"]: r for r in data["todo"]}
    for r in data["todo"]:
        rep.check(r["Status"] in TODO_STATUS, "todo", r["ID"], f"illegal status {r['Status']}")
        deps = [d.strip() for d in (r.get("BlockedBy","") or "").split(",") if d.strip()]
        for d in deps:
            rep.check(d in by_id, "todo", r["ID"], f"BlockedBy references unknown {d}")
        if r["Status"] == "DONE" and (r.get("DependencyType","hard") or "hard") == "hard":
            open_b = [d for d in deps if by_id.get(d, {}).get("Status") != "DONE"]
            rep.check(not open_b, "todo", r["ID"], f"DONE with open hard blockers {open_b}")
        if r["Status"] in ("DOING","REVIEW","DONE"):
            rep.check(bool(r.get("StartedAt")), "todo", r["ID"], "past TODO without StartedAt")
        if r["Status"] == "DONE":
            rep.check(bool(r.get("DoneAt")), "todo", r["ID"], "DONE without DoneAt")
    # cycle detection (hard edges)
    WHITE, GREY, BLACK = 0, 1, 2
    colour = {i: WHITE for i in by_id}
    def dfs(n, stack):
        colour[n] = GREY
        for d in [x.strip() for x in (by_id[n].get("BlockedBy","") or "").split(",") if x.strip()]:
            if d not in by_id: continue
            if colour[d] == GREY:
                rep.check(False, "todo", n, f"circular dependency via {d}")
            elif colour[d] == WHITE:
                dfs(d, stack + [d])
        colour[n] = BLACK
    for i in by_id:
        if colour[i] == WHITE: dfs(i, [i])
    rep.section("todo: lifecycle + dependency gate", b)

    # -- overlord: symmetry + paths --------------------------------------
    b = len(rep.fails)
    ovr = {r["ID"]: r for r in data["overlord"]}
    for r in data["overlord"]:
        for d in refs(r.get("Requires")):
            ok = d in ovr and r["ID"] in refs(ovr[d].get("RequiredBy"))
            rep.check(ok, "overlord", r["ID"], f"Requires {d} not mirrored in its RequiredBy")
        for d in refs(r.get("RequiredBy")):
            ok = d in ovr and r["ID"] in refs(ovr[d].get("Requires"))
            rep.check(ok, "overlord", r["ID"], f"RequiredBy {d} not mirrored in its Requires")
        if "#dead" not in (r.get("Tags","") or ""):
            rep.check(os.path.exists(r["Path"]), "overlord", r["ID"], f"path missing on disk: {r['Path']}")
    rep.section("overlord: edge symmetry + paths", b)

    # -- organism: status + evidence gate --------------------------------
    b = len(rep.fails)
    for r in data["organism"]:
        rep.check(r["Status"] in OGM_STATUS, "organism", r["ID"], f"illegal status {r['Status']}")
        if r["Status"] == "VALIDATED_COMPLETE":
            rep.check(bool(r.get("AcceptanceEvidence","").strip()), "organism", r["ID"],
                      "VALIDATED_COMPLETE without AcceptanceEvidence")
    rep.section("organism: status + evidence gate", b)

    # -- nodule: lifecycle -----------------------------------------------
    b = len(rep.fails)
    active_targets = []
    for r in data["nodule"]:
        rep.check(r["Status"] in NDL_STATUS, "nodule", r["ID"], f"illegal status {r['Status']}")
        if r["Status"] == "ACTIVE":
            rep.check(len(refs(r.get("SpawnedPACs"))) >= 1, "nodule", r["ID"], "ACTIVE with no SpawnedPACs")
            t = set(refs(r.get("TargetOVR")))
            for prev in active_targets:
                rep.check(not (t & prev), "nodule", r["ID"], "ACTIVE lane overlaps another ACTIVE nodule's TargetOVR")
            active_targets.append(t)
        if r["Status"] == "ABSORBED":
            rep.check(bool(r.get("AbsorbedAt")), "nodule", r["ID"], "ABSORBED without AbsorbedAt")
    rep.section("nodule: lifecycle + lane exclusivity", b)

    # -- cross-file: every reference resolves ----------------------------
    b = len(rep.fails)
    ref_cols = {"todo": ["RelatedWork"], "overlord": ["OGMRefs","PACRefs","NDLRefs"],
                "organism": ["OVRRefs","PACRefs","BlockedByOGM","AbsorbedFromNDL"],
                "nodule": ["TargetOVR","OGMTargets","SpawnedPACs"]}
    for organ, cols in ref_cols.items():
        for r in data[organ]:
            for c in cols:
                for m in REF_RX.finditer(r.get(c,"") or ""):
                    kind, rid = m.group(1), m.group(0)
                    rep.check(rid in ids[kind], organ, r["ID"], f"{c} references unknown {rid}")
    rep.section("cross-file: reference resolution", b)

    # -- verdict ---------------------------------------------------------
    print("=" * 58)
    counts = {o: len(data[o]) for o in ORGANS}
    print(f"  rows :: todo {counts['todo']} | overlord {counts['overlord']}"
          f" | organism {counts['organism']} | nodule {counts['nodule']}"
          f"   checks run :: {rep.checks}")
    if rep.fails:
        print(f"  VERDICT :: RED - {len(rep.fails)} violation(s)")
        for organ, where, rule in rep.fails:
            print(f"    {organ:<9} {where:<9} {rule}")
        sys.exit(1)
    print("  VERDICT :: GREEN - registers commit-safe")
    sys.exit(0)

if __name__ == "__main__":
    main()
