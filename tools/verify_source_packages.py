#!/usr/bin/env python3
"""Run delivered headless regressions and retain commands, logs and verdicts."""
import argparse
import json
import os
import re
import shlex
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path(".PACER/runtime-verification"))
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    jobs = [(f"smoke-{i:02}", [], ["smoke", f"boss={i}"]) for i in range(24)]
    jobs += [(mode, [], [mode]) for mode in ("determinism", "geometry", "audit", "faucets")]
    for path in sorted((root / "engine/greybox/tools").glob("drive*.gd")):
        example = next(line for line in path.read_text(encoding="utf-8").splitlines()
                       if "godot --headless" in line)
        command_args = shlex.split(example.split(" -- ", 1)[1])
        if path.stem == "drive_techniques":
            # The delivered example has an unquoted space in the tape's title.
            command_args = [a for a in command_args if a not in ("tapes=Black", "Ice:1")]
            command_args.append("tapes=Black Ice:1")
        jobs.append((path.stem, ["-s", "tools/" + path.name], command_args))

    def run(job):
        name, flags, command_args = job
        appdata = output / "user-data" / name
        appdata.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, APPDATA=str(appdata), LOCALAPPDATA=str(appdata))
        command = [str(args.godot.resolve()), "--headless", "--audio-driver", "Dummy", "--log-file",
                   str(output / (name + ".engine.log")), "--path",
                   str(root / "engine/greybox"), *flags, "--", *command_args]
        try:
            proc = subprocess.run(command, env=env, capture_output=True, timeout=240, check=False)
            code, payload = proc.returncode, proc.stdout + proc.stderr
        except subprocess.TimeoutExpired as exc:
            code, payload = -999, (exc.stdout or b"") + (exc.stderr or b"")
        text = payload.decode("utf-8", errors="replace")
        (output / (name + ".log")).write_text(text, encoding="utf-8")
        diagnostics = [line for line in text.splitlines()
                       if re.search(r"SCRIPT ERROR|Parse Error|\[FAIL\]|^ERROR:", line)]
        environment = [line for line in diagnostics
                       if line == "ERROR: Failed to read the root certificate store."]
        errors = [line for line in diagnostics if line not in environment]
        verdicts = [line for line in text.splitlines()
                    if re.search(r"(?:VERDICT|DRIVE) :: (?:GREEN|RED)", line)]
        passed = code == 0 and not errors and bool(verdicts) and all(" :: GREEN" in v for v in verdicts)
        row = {"name": name, "passed": passed, "exit": code, "command": command,
               "verdicts": verdicts, "errors": errors, "environment_diagnostics": environment}
        print(json.dumps({k: row[k] for k in ("name", "passed", "verdicts", "errors")}), flush=True)
        return row

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        results = list(pool.map(run, jobs))
    report = {"passed": all(row["passed"] for row in results), "runs": results}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{sum(r['passed'] for r in results)}/{len(results)} runs passed.")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
