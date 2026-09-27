#!/usr/bin/env python3
"""Review, merge, apply and verify source-package imports without replacing local work.

Plans and rollback copies live in ignored .PACER/package-import. The committed
packages/import-state.json identifies archives and their last installed contents.
No package can replace a register, delete an omitted file, commit, or push.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import uuid
import zipfile
from contextlib import contextmanager
from pathlib import Path, PurePosixPath

STATE = "packages/import-state.json"
REGISTERS = {f"{name}.PACER.csv" for name in ("todo", "overlord", "organism", "nodule")}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def content_digest(data: bytes) -> str:
    """Git may convert text line endings; do not change binary content identity."""
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return digest(data)
    return digest(data.replace(b"\r\n", b"\n"))


def read_json(path: Path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".package-import-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def write_json(path: Path, obj) -> None:
    atomic_write(path, (json.dumps(obj, indent=2, ensure_ascii=False) + "\n").encode())


def safe_path(root: Path, name: str) -> Path:
    """Reject ambiguous Windows paths, traversal, links and Git internals."""
    parts = PurePosixPath(name).parts
    if not parts or "\\" in name or name.startswith("/") or ":" in name:
        raise ValueError(f"Unsafe path: {name}")
    if any(p in (".", "..") or p.endswith((".", " ")) for p in name.split("/")):
        raise ValueError(f"Unsafe path: {name}")
    reserved = re.compile(r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)", re.IGNORECASE)
    if any(reserved.match(p) or p.casefold() in (".git", ".pacer") for p in parts):
        raise ValueError(f"Protected path: {name}")
    target = root.joinpath(*parts)
    current = root
    for part in parts:
        current = current / part
        if current.is_symlink() or (hasattr(current, "is_junction") and current.is_junction()):
            raise ValueError(f"Linked path: {name}")
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Escaping path: {name}")
    return target


def mapped_path(name: str) -> str:
    name = re.sub(r"^(northpaw|true-north-boxing)/", "", name)
    if re.fullmatch(r"REGISTER_COMMANDS_\d+\.md", name):
        return "docs/register-commands_docs/" + name
    if name.startswith("docs/NP_"):
        return "docs/NorthPaw-game_docs/" + name[5:]
    if name in ("DOCTRINE.md", "VS_SCOPE.md"):
        return "docs/register-commands_docs/" + name
    if name == "docs/NORTHPAW_GDD_v1.md":
        return "docs/TNB_GDD_v1.md"
    return name


def archive_members(root: Path, archive: Path) -> dict[str, tuple[str, bytes]]:
    result = {}
    seen = set()
    total = 0
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            safe_path(root, info.orig_filename.rstrip("/") if info.is_dir() else info.orig_filename)
            if info.is_dir():
                safe_path(root, info.filename.rstrip("/"))
                continue
            safe_path(root, info.filename)
            if stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError(f"Archive contains a link: {info.filename}")
            name = mapped_path(info.filename)
            safe_path(root, name)
            if name.casefold() in seen:
                raise ValueError(f"Duplicate destination: {name}")
            seen.add(name.casefold())
            if Path(name).name.casefold() in {r.casefold() for r in REGISTERS} or name.casefold() == STATE or name.casefold().startswith("packages/"):
                raise ValueError(f"Package must not overwrite registers or archives: {name}")
            total += info.file_size
            if info.file_size > 100_000_000 or total > 1_000_000_000:
                raise ValueError("Source package exceeds the reviewed size limit")
            result[name] = (info.filename, z.read(info))
    if not result:
        raise ValueError("Empty package")
    return result


def get_base(root: Path, row: dict) -> bytes:
    archive = safe_path(root, row["archive"])
    if digest(archive.read_bytes()) != row["archive_sha256"]:
        raise ValueError(f"Baseline archive changed: {archive}")
    with zipfile.ZipFile(archive) as z:
        base = z.read(row["member"])
    if digest(base) != row["source_sha256"]:
        raise ValueError(f"Baseline member changed: {row['member']}")
    return base


def merge_bytes(current: bytes, base: bytes, incoming: bytes, folder: Path):
    for data in (current, base, incoming):
        try:
            data.decode("utf-8")
        except UnicodeDecodeError:
            return None
        if b"\0" in data:
            return None
    files = [folder / n for n in ("ours", "base", "theirs")]
    for path, data in zip(files, (current, base, incoming)):
        path.write_bytes(data.replace(b"\r\n", b"\n"))
    proc = subprocess.run(["git", "merge-file", "-p", *map(str, files)], capture_output=True, check=False)
    # merge-file returns the number of conflicts, capped at 127.
    if not 0 <= proc.returncode <= 127:
        raise ValueError(f"Merge failed ({proc.returncode}): {proc.stderr.decode(errors='replace')}")
    return proc.stdout if proc.returncode == 0 else None


def plan_import(root: Path, archive: Path) -> Path:
    root = root.resolve()
    archive = archive.resolve()
    if not archive.is_relative_to(root / "packages"):
        raise ValueError("Copy the original ZIP into packages/ before planning its import")
    archive_name = archive.relative_to(root).as_posix()
    safe_path(root, archive_name)
    state_path = root / STATE
    previous = state_path.read_bytes() if state_path.exists() else b""
    state = json.loads(previous) if previous else {"schema": 1, "archives": {}, "files": {}}
    archive_sha = digest(archive.read_bytes())
    if archive_name in state["archives"]:
        if state["archives"][archive_name]["sha256"] != archive_sha:
            raise ValueError("An imported archive was replaced; give the new delivery a new filename")
        raise ValueError("This exact archive is already recorded as imported")
    members = archive_members(root, archive)
    folder = root / ".PACER" / "package-import" / uuid.uuid4().hex
    folder.mkdir(parents=True)
    changes = []
    for number, (name, (member, incoming)) in enumerate(members.items()):
        target = safe_path(root, name)
        if target.exists() and not target.is_file():
            raise ValueError(f"Destination is not a file: {name}")
        current = target.read_bytes() if target.exists() else None
        action = "add" if current is None else "update"
        output = incoming
        base_row = state["files"].get(name)
        base = get_base(root, base_row) if base_row else None
        if current is not None:
            if content_digest(current) == content_digest(incoming):
                action, output = "unchanged", current
            elif base is None:
                action, output = "conflict", None
            elif content_digest(current) == content_digest(base):
                pass
            elif content_digest(incoming) == content_digest(base):
                action, output = "keep-local", current
            else:
                output = merge_bytes(current, base, incoming, folder)
                action = "merge" if output is not None else "conflict"
        elif base is not None:
            # A local deletion is a local edit too. Never silently resurrect it.
            action, output = "conflict", None
        slot = folder / str(number)
        slot.mkdir()
        (slot / "incoming").write_bytes(incoming)
        if current is not None:
            (slot / "before").write_bytes(current)
        if base is not None:
            (slot / "base").write_bytes(base)
        if output is not None:
            (slot / "after").write_bytes(output)
        changes.append({"path": name, "member": member, "action": action, "slot": str(number),
                        "before": digest(current) if current is not None else None,
                        "after": digest(output) if output is not None else None,
                        "source_sha256": digest(incoming)})
    if previous:
        (folder / "state-before").write_bytes(previous)
    plan = {"schema": 1, "root": str(root), "archive": archive_name, "archive_sha256": archive_sha,
            "state_before": digest(previous) if previous else None, "status": "planned", "changes": changes}
    write_json(folder / "plan.json", plan)
    return folder / "plan.json"


def load_plan(root: Path, path: Path):
    root = root.resolve()
    path = path.resolve()
    expected = root / ".PACER" / "package-import"
    if not path.is_relative_to(expected) or path.name != "plan.json":
        raise ValueError("Plan must be under this repository's .PACER/package-import directory")
    plan = read_json(path)
    if plan["root"] != str(root):
        raise ValueError("Plan belongs to a different checkout")
    for row in plan["changes"]:
        safe_path(root, row["path"])
        if not re.fullmatch(r"\d+", row["slot"]):
            raise ValueError("Invalid plan slot")
    return plan, path.parent


def resolve_import(root: Path, plan_path: Path, name: str, resolution: Path) -> None:
    plan, folder = load_plan(root, plan_path)
    if plan["status"] != "planned":
        raise ValueError("Only a pending plan can be resolved")
    row = next((r for r in plan["changes"] if r["path"] == name), None)
    if row is None or row["action"] != "conflict":
        raise ValueError("Path is not an unresolved conflict")
    data = resolution.read_bytes()
    if re.search(rb"(?m)^(<<<<<<< |=======\s*$|>>>>>>> )", data):
        raise ValueError("Resolution still contains conflict markers")
    atomic_write(folder / row["slot"] / "after", data)
    row.update(action="resolved", after=digest(data))
    write_json(plan_path, plan)


@contextmanager
def transaction_lock(root: Path):
    """An OS-held writer lock is automatically released if the process exits."""
    lock_path = root / ".PACER" / "package-import.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as handle:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"0"); handle.flush()
        handle.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise ValueError("Another source import is running") from exc
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def apply_import(root: Path, plan_path: Path) -> None:
    with transaction_lock(root.resolve()):
        _apply_import(root, plan_path)


def _apply_import(root: Path, plan_path: Path) -> None:
    root = root.resolve()
    plan, folder = load_plan(root, plan_path)
    if plan["status"] != "planned":
        raise ValueError("Plan has already been applied or rolled back")
    for other in (root / ".PACER" / "package-import").glob("*/plan.json"):
        if read_json(other).get("status") == "applying":
            raise ValueError(f"Interrupted import needs rollback first: {other}")
    archive = safe_path(root, plan["archive"])
    if digest(archive.read_bytes()) != plan["archive_sha256"]:
        raise ValueError("Archive changed after planning")
    current_state = (root / STATE).read_bytes() if (root / STATE).exists() else None
    if (digest(current_state) if current_state is not None else None) != plan["state_before"]:
        raise ValueError("Import state changed after planning")
    outputs = {}
    for row in plan["changes"]:
        if row["action"] == "conflict":
            raise ValueError(f"Resolve conflict before applying: {row['path']}")
        target = safe_path(root, row["path"])
        current = target.read_bytes() if target.exists() else None
        if (digest(current) if current is not None else None) != row["before"]:
            raise ValueError(f"Source changed after planning: {row['path']}")
        after = (folder / row["slot"] / "after").read_bytes()
        if digest(after) != row["after"]:
            raise ValueError(f"Planned output changed: {row['path']}")
        outputs[row["path"]] = after
    state = json.loads(current_state) if current_state else {"schema": 1, "archives": {}, "files": {}}
    for row in plan["changes"]:
        name = row["path"]
        state["files"][name] = {"archive": plan["archive"], "member": row["member"],
            "archive_sha256": plan["archive_sha256"], "source_sha256": row["source_sha256"],
            "installed_sha256": content_digest(outputs[name])}
    state["archives"][plan["archive"]] = {"sha256": plan["archive_sha256"], "files": [r["path"] for r in plan["changes"]]}
    state_after = (json.dumps(state, indent=2, ensure_ascii=False) + "\n").encode()
    plan["state_after"] = digest(state_after)
    plan["status"] = "applying"
    write_json(plan_path, plan)
    # On failure the applying journal and exact originals remain for rollback.
    for row in plan["changes"]:
        name = row["path"]
        if row["action"] not in ("unchanged", "keep-local"):
            atomic_write(safe_path(root, name), outputs[name])
    atomic_write(root / STATE, state_after)
    plan["status"] = "applied"
    write_json(plan_path, plan)


def rollback_import(root: Path, plan_path: Path) -> None:
    with transaction_lock(root.resolve()):
        _rollback_import(root, plan_path)


def _rollback_import(root: Path, plan_path: Path) -> None:
    root = root.resolve()
    plan, folder = load_plan(root, plan_path)
    if plan["status"] not in ("applied", "applying"):
        raise ValueError("No applied transaction to roll back")
    actual_state = digest((root / STATE).read_bytes()) if (root / STATE).exists() else None
    if actual_state not in (plan.get("state_before"), plan.get("state_after")):
        raise ValueError("Import state changed; refusing to discard later work")
    previous = None
    if plan["state_before"] is not None:
        previous = (folder / "state-before").read_bytes()
        if digest(previous) != plan["state_before"]:
            raise ValueError("Rollback state copy is damaged")
    for row in plan["changes"]:
        target = safe_path(root, row["path"])
        actual = digest(target.read_bytes()) if target.exists() else None
        if actual not in (row["before"], row["after"]):
            raise ValueError(f"Source changed; refusing rollback: {row['path']}")
        before = folder / row["slot"] / "before"
        if row["before"] is not None and (not before.exists() or digest(before.read_bytes()) != row["before"]):
            raise ValueError(f"Rollback copy is damaged: {row['path']}")
    for row in reversed(plan["changes"]):
        target = safe_path(root, row["path"])
        if row["before"] is None:
            if target.exists():
                target.unlink()
        else:
            atomic_write(target, (folder / row["slot"] / "before").read_bytes())
    if plan["state_before"] is None:
        (root / STATE).unlink(missing_ok=True)
    else:
        atomic_write(root / STATE, previous)
    plan["status"] = "rolled-back"
    write_json(plan_path, plan)


def verify_imports(root: Path, staged: bool = False) -> dict:
    def git_bytes(name):
        proc = subprocess.run(["git", "show", ":" + name], cwd=root, capture_output=True, check=False)
        if proc.returncode:
            raise ValueError(f"Missing from Git index: {name}")
        return proc.stdout

    if staged:
        changed = subprocess.check_output(["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"], cwd=root).decode().split("\0")
        archives = [n for n in changed if n.startswith("packages/") and n.endswith(".zip")]
        if not archives:
            return {"archives_checked": 0, "files_checked": 0}
        state = json.loads(git_bytes(STATE))
    else:
        state = read_json(root / STATE)
        if state is None:
            raise ValueError("No source-import state exists")
        archives = [p.relative_to(root).as_posix() for p in (root / "packages").glob("*.zip")]
    files_checked = set()
    local_edits = []
    for name in archives:
        row = state["archives"].get(name)
        if row is None:
            raise ValueError(f"Archive has not been imported into source: {name}")
        payload = git_bytes(name) if staged else safe_path(root, name).read_bytes()
        pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize \d+\n", payload.replace(b"\r\n", b"\n"))
        archive_sha = pointer.group(1).decode() if pointer else digest(payload)
        if archive_sha != row["sha256"]:
            raise ValueError(f"Archive differs from its import record: {name}")
        for path in row["files"]:
            current = state["files"].get(path)
            if current is None:
                raise ValueError(f"No installed-source record: {path}")
            safe_path(root, path)
            data = git_bytes(path) if staged else (root / path).read_bytes()
            if content_digest(data) != current["installed_sha256"]:
                if staged:
                    raise ValueError(f"Staged source does not match the import: {path}")
                local_edits.append(path)
            files_checked.add(path)
    return {"archives_checked": len(archives), "files_checked": len(files_checked), "local_edits": sorted(set(local_edits))}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    subs = parser.add_subparsers(dest="command", required=True)
    p = subs.add_parser("plan"); p.add_argument("archive", type=Path)
    for name in ("apply", "rollback"):
        p = subs.add_parser(name); p.add_argument("plan", type=Path)
    p = subs.add_parser("resolve"); p.add_argument("plan", type=Path); p.add_argument("path"); p.add_argument("resolution", type=Path)
    p = subs.add_parser("verify"); p.add_argument("--staged", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            path = plan_import(args.root, args.archive)
            plan = read_json(path)
            print(path)
            for row in plan["changes"]:
                print(f"{row['action']:12} {row['path']}")
            return 1 if any(r["action"] == "conflict" for r in plan["changes"]) else 0
        if args.command == "apply":
            apply_import(args.root, args.plan)
        elif args.command == "rollback":
            rollback_import(args.root, args.plan)
        elif args.command == "resolve":
            resolve_import(args.root, args.plan, args.path, args.resolution)
        else:
            print(json.dumps(verify_imports(args.root, args.staged), indent=2))
        return 0
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
        print(f"IMPORT REFUSED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
