#!/usr/bin/env python3
"""pacer_views.py - generate ephemeral, filtered worklist views from the single
canonical NORTHPAW_PACER.csv. Views are READ-ONLY handouts for agents; all
mutations go back through the canonical register via PACER commands.

Usage:
  python3 pacer_views.py --phase P2-Opponent            # one phase's worklist
  python3 pacer_views.py --assignee @agent1             # one agent's tasks
  python3 pacer_views.py --ready                        # TODO tasks with all hard blockers DONE
  python3 pacer_views.py --phase P4-Systems --ready -o view_p4.csv
"""
import csv, argparse, sys

def load(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f)), f

def blockers_done(row, by_id):
    if row.get("DependencyType","").strip() not in ("", "hard"):
        return True  # soft/optional never block readiness
    ids = [b.strip() for b in row.get("BlockedBy","").split(",") if b.strip()]
    return all(by_id.get(i, {}).get("Status") == "DONE" for i in ids)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--register", default="NORTHPAW_PACER.csv")
    ap.add_argument("--phase"); ap.add_argument("--assignee"); ap.add_argument("--status")
    ap.add_argument("--ready", action="store_true", help="TODO with hard blockers satisfied")
    ap.add_argument("-o", "--out", help="write view CSV (default: table to stdout)")
    a = ap.parse_args()

    rows, _ = load(a.register)
    by_id = {r["ID"]: r for r in rows}
    v = rows
    if a.phase:    v = [r for r in v if r["Phase"] == a.phase]
    if a.assignee: v = [r for r in v if r["Assignee"] == a.assignee]
    if a.status:   v = [r for r in v if r["Status"] == a.status]
    if a.ready:    v = [r for r in v if r["Status"] == "TODO" and blockers_done(r, by_id)]

    if a.out:
        with open(a.out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader()
            for r in v: w.writerow(r)
        print(f"# VIEW ONLY - canonical register is {a.register}. {len(v)} rows -> {a.out}")
    else:
        for r in v:
            print(f"{r['ID']}  [{r['Status']:6}] {r['Phase']:14} {r['Title'][:60]}  blk:{r['BlockedBy'] or '-'}")
        print(f"-- {len(v)} rows (view of {a.register})")

if __name__ == "__main__":
    main()
