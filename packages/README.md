# Import source packages

A ZIP is the original delivery. The runnable, editable source lives in the normal
repository directories. Committing a ZIP alone does not update that source.

From the repository root, enable the included commit guard once per checkout:

```powershell
git config --local core.hooksPath .githooks
```

For each new delivery, copy its unchanged ZIP into `packages/`, then run:

```powershell
.venv\Scripts\python.exe tools\package_import.py plan packages\tnb_pacNNN_name.zip
```

The command prints a plan path and each source change. Review the source changes
in that plan, then apply using the printed path:

```powershell
.venv\Scripts\python.exe tools\package_import.py apply .PACER\package-import\PLAN_ID\plan.json
git diff --stat
.venv\Scripts\python.exe tools\package_import.py verify
.venv\Scripts\python.exe -m unittest discover -s tests -v
.venv\Scripts\python.exe pacer_validator.py
```

Run the package's relevant engine checks as well. Reconcile its register commands
through PACER, retaining original requirements and real acceptance evidence. Stage
the ZIP, changed source, `packages/import-state.json`, and register changes together.
The commit guard checks the **staged** source and receipt, including Git LFS ZIPs.
It rejects an unimported ZIP or a receipt staged without its matching source.

The delivered runtime checks can be run together, with full logs retained:

```powershell
.venv\Scripts\python.exe tools\verify_source_packages.py --godot C:\path\to\Godot_console.exe
```

Existing local changes are merged against the prior original package. Omitted
files stay in place. Unknown baselines, overlapping edits, binary conflicts and
local deletions require an explicit resolution. Nothing is applied while a plan
contains a conflict. To resolve one, put the reviewed complete file somewhere safe:

```powershell
.venv\Scripts\python.exe tools\package_import.py resolve .PACER\package-import\PLAN_ID\plan.json engine/greybox/sim/core.gd .PACER\resolved-core.gd
```

An applied plan retains exact originals and a transaction journal. Roll back with:

```powershell
.venv\Scripts\python.exe tools\package_import.py rollback .PACER\package-import\PLAN_ID\plan.json
```

Rollback refuses to discard edits made after the import. Stale plans are refused;
create a fresh plan if source, the ZIP, or import state changed. If an import was
interrupted, roll it back before applying another. Backups remain local under the
ignored `.PACER/` directory. Keep them until the recovered work is safely backed up.

The importer never executes package instructions, deletes files omitted from a
delivery, overwrites the canonical registers, commits, or pushes. Register ZIPs
are refused for explicit PACER reconciliation. Git hooks can be bypassed with
Git's normal options, so `verify --staged` is also an explicit review check.

## September 27 source recovery

`import-state.json` records the original archives and current integrated source
baselines through PAC-103. Older deliveries remain intact as provenance; their
files may have been superseded by later deliveries. Framework/register-only
archives are explicitly classified as historical, not claimed as source imports.

PAC-070's archive became available during the repair. Both copies of
`pattern_pieces.v1.json` now match its original bytes. The temporary reconstruction
was retired and preserved in Git history and the local recovery snapshot.
`tools/build_pattern_pieces.py --check` verifies the original data. Automated checks
do not establish human gameplay acceptance. See `evidence/source-recovery/report.json`
for the archive/source inventory, retained edits, tests, and recovery boundaries.
