#!/usr/bin/env python3
"""Read canonical PACER tasks and export new, non-destructive worklist views."""
import argparse
import csv
from pathlib import Path


def load(path):
    # Append-only acceptance history exceeds Python's 128 KiB CSV default.
    # Preserve the evidence; keep strict quoting, column and ID validation.
    csv.field_size_limit(max(csv.field_size_limit(), 16 * 1024 * 1024))
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream, strict=True)
        try:
            headers = next(reader)
            if not headers or any(not h for h in headers) or len(set(headers)) != len(headers):
                raise ValueError(f"{path}: empty or duplicate headers")
            rows, seen = [], set()
            for values in reader:
                if len(values) != len(headers):
                    raise ValueError(f"{path}:{reader.line_num}: ragged CSV row")
                row = dict(zip(headers, values))
                if "ID" in row:
                    if not row["ID"] or row["ID"] in seen:
                        raise ValueError(f"{path}: empty or duplicate ID {row['ID']}")
                    seen.add(row["ID"])
                rows.append(row)
            return rows, headers
        except (StopIteration, csv.Error) as exc:
            raise ValueError(f"{path}: malformed CSV: {exc}") from exc


def dependencies(row):
    raw = row.get("BlockedBy", "").strip()
    ids = [v.strip() for v in raw.split(";")] if raw else []
    if any(not v or "," in v for v in ids):
        raise ValueError("BlockedBy must contain semicolon-separated IDs")
    raw = row.get("DependencyType", "").strip()
    kinds = [v.strip() for v in raw.split(";")] if raw else ["hard"]
    if any(k not in ("hard", "soft", "optional") for k in kinds):
        raise ValueError("Unknown dependency type")
    if len(kinds) == 1:
        kinds *= len(ids)
    elif len(kinds) != len(ids):
        raise ValueError("DependencyType count must match BlockedBy")
    return list(zip(ids, kinds))


def blockers_done(row, by_id):
    return all(kind != "hard" or by_id.get(id, {}).get("Status") == "DONE"
               for id, kind in dependencies(row))


def is_ready(row, by_id):
    approval = row.get("ApprovalState", "")
    return (row.get("Status") == "TODO" and approval not in ("PENDING", "WITHDRAWN")
            and (row.get("Phase") != "PROPOSAL" or approval == "APPROVED")
            and blockers_done(row, by_id))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--register", default="todo.PACER.csv")
    for flag in ("phase", "assignee", "status"):
        parser.add_argument("--" + flag)
    parser.add_argument("--ready", action="store_true")
    parser.add_argument("-o", "--out", type=Path)
    args = parser.parse_args(argv)
    try:
        rows, headers = load(args.register)
        by_id = {r["ID"]: r for r in rows}
        view = [r for r in rows if all(not getattr(args, key) or r.get(key.title()) == getattr(args, key)
                                      for key in ("phase", "assignee", "status"))
                and (not args.ready or is_ready(r, by_id))]
        if args.out:
            if args.out.name.lower().endswith(".pacer.csv"):
                raise ValueError("A view cannot use a canonical register filename")
            with args.out.open("x", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=headers)
                writer.writeheader()
                writer.writerows(view)
        else:
            for row in view:
                print(f"{row['ID']} [{row['Status']}] {row.get('Phase', '')} {row.get('Title', '')}")
        print(f"{len(view)} rows (read-only view of {args.register})")
        return 0
    except (ValueError, OSError, KeyError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
