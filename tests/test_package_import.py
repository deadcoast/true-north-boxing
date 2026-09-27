"""Exercise preservation, stale plans, conflict handling, rollback and ZIP-only commits."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from tools import package_import
from tools.package_import import (
    STATE,
    apply_import,
    archive_members,
    plan_import,
    resolve_import,
    rollback_import,
    transaction_lock,
    verify_imports,
)


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "packages").mkdir()

    def package(self, name, files):
        archive = self.root / "packages" / name
        with zipfile.ZipFile(archive, "w") as z:
            for path, data in files.items():
                info = zipfile.ZipInfo("member")
                info.filename = path  # Preserve unsafe separators for the rejection cases on Windows.
                z.writestr(info, data)
        return archive

    def import_first(self, data="one\ntwo\nthree\nfour\nfive\n"):
        archive = self.package("first.zip", {"code.py": data})
        plan = plan_import(self.root, archive)
        apply_import(self.root, plan)
        return plan

    def test_import_writes_source_and_receipt(self):
        self.import_first()
        self.assertTrue((self.root / "code.py").is_file())
        self.assertEqual(verify_imports(self.root)["archives_checked"], 1)

    def test_omitted_file_is_preserved(self):
        self.import_first()
        plan = plan_import(self.root, self.package("second.zip", {"other.py": "new"}))
        apply_import(self.root, plan)
        self.assertTrue((self.root / "code.py").exists())

    def test_unknown_existing_file_requires_resolution(self):
        (self.root / "code.py").write_text("local")
        plan = plan_import(self.root, self.package("first.zip", {"code.py": "incoming"}))
        with self.assertRaisesRegex(ValueError, "conflict"):
            apply_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "local")

    def test_three_way_merge_preserves_independent_edits(self):
        self.import_first()
        (self.root / "code.py").write_text("LOCAL\ntwo\nthree\nfour\nfive\n")
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "one\ntwo\nthree\nfour\nINCOMING\n"}))
        apply_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "LOCAL\ntwo\nthree\nfour\nINCOMING\n")

    def test_overlapping_edits_refused_then_explicitly_resolved(self):
        self.import_first("base\n")
        (self.root / "code.py").write_text("local\n")
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "incoming\n"}))
        with self.assertRaises(ValueError):
            apply_import(self.root, plan)
        resolution = self.root / "resolution.txt"
        resolution.write_text("local\nincoming\n")
        resolve_import(self.root, plan, "code.py", resolution)
        apply_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "local\nincoming\n")

    def test_local_deletion_is_a_conflict(self):
        self.import_first()
        (self.root / "code.py").unlink()
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "new"}))
        with self.assertRaises(ValueError):
            apply_import(self.root, plan)
        self.assertFalse((self.root / "code.py").exists())

    def test_several_conflicts_are_a_reviewable_plan(self):
        original = "\n".join(str(i) for i in range(40)) + "\n"
        self.import_first(original)
        ours, theirs = original, original
        for number in (3, 16, 30):
            ours = ours.replace(f"\n{number}\n", f"\nlocal {number}\n")
            theirs = theirs.replace(f"\n{number}\n", f"\nincoming {number}\n")
        (self.root / "code.py").write_text(ours)
        plan = plan_import(self.root, self.package("second.zip", {"code.py": theirs}))
        self.assertEqual(json.loads(plan.read_text())["changes"][0]["action"], "conflict")
        with self.assertRaisesRegex(ValueError, "conflict"):
            apply_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), ours)

    def test_stale_source_refuses_all_writes(self):
        self.import_first()
        plan = plan_import(self.root, self.package("second.zip", {"new.py": "new", "code.py": "changed"}))
        (self.root / "code.py").write_text("edited after plan")
        with self.assertRaisesRegex(ValueError, "Source changed"):
            apply_import(self.root, plan)
        self.assertFalse((self.root / "new.py").exists())

    def test_archive_tampering_refused(self):
        plan = plan_import(self.root, self.package("first.zip", {"code.py": "x"}))
        self.package("first.zip", {"code.py": "tampered"})
        with self.assertRaisesRegex(ValueError, "Archive changed"):
            apply_import(self.root, plan)

    def test_stale_state_refused(self):
        first = plan_import(self.root, self.package("first.zip", {"a.py": "a"}))
        second = plan_import(self.root, self.package("second.zip", {"b.py": "b"}))
        apply_import(self.root, first)
        with self.assertRaisesRegex(ValueError, "state changed"):
            apply_import(self.root, second)

    def test_rollback_restores_exact_original_and_state(self):
        self.import_first("old\r\n")
        state_before = (self.root / STATE).read_bytes()
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "new", "new.py": "add"}))
        apply_import(self.root, plan)
        rollback_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_bytes(), b"old\r\n")
        self.assertEqual((self.root / STATE).read_bytes(), state_before)
        self.assertFalse((self.root / "new.py").exists())

    def test_rollback_preserves_subsequent_user_edits(self):
        plan = self.import_first()
        (self.root / "code.py").write_text("later work")
        with self.assertRaisesRegex(ValueError, "refusing rollback"):
            rollback_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "later work")

    def test_interrupted_apply_can_roll_back_without_losing_original(self):
        self.import_first("original")
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "replacement", "later.py": "new"}))
        real_write = package_import.atomic_write
        def fail_later(path, data):
            if path == self.root / "later.py":
                raise OSError("simulated disk failure")
            real_write(path, data)
        with (patch.object(package_import, "atomic_write", side_effect=fail_later),
              self.assertRaisesRegex(OSError, "disk failure")):
            apply_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "replacement")
        rollback_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "original")
        self.assertFalse((self.root / "later.py").exists())

    def test_corrupt_rollback_state_refuses_before_touching_source(self):
        self.import_first("original")
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "replacement"}))
        apply_import(self.root, plan)
        (plan.parent / "state-before").write_text("damaged")
        with self.assertRaisesRegex(ValueError, "state copy is damaged"):
            rollback_import(self.root, plan)
        self.assertEqual((self.root / "code.py").read_text(), "replacement")

    def test_second_writer_is_refused(self):
        plan = plan_import(self.root, self.package("first.zip", {"code.py": "new"}))
        with (transaction_lock(self.root),
              self.assertRaisesRegex(ValueError, "Another source import")):
            apply_import(self.root, plan)
        self.assertFalse((self.root / "code.py").exists())

    def test_real_commit_hook_rejects_zip_only_and_accepts_imported_source(self):
        repo = Path(__file__).resolve().parents[1]
        for name in (".githooks/pre-commit", "tools/package_import.py"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo / name, target)
        hook = self.root / ".githooks/pre-commit"
        hook.chmod(0o755)
        # Use this test's real interpreter, including Windows virtualenv launchers.
        if os.name == "nt":
            target = self.root / ".venv/Scripts/python.exe"
            target.parent.mkdir(parents=True)
            shutil.copy2(sys.executable, target)
            config = Path(sys.prefix) / "pyvenv.cfg"
            if config.exists():
                shutil.copy2(config, self.root / ".venv/pyvenv.cfg")
        env = dict(os.environ, PATH=str(Path(sys.executable).parent) + os.pathsep + os.environ.get("PATH", ""))
        def git(*args):
            return subprocess.run(["git", *args], cwd=self.root, env=env,
                                  capture_output=True, text=True, check=False)
        self.assertEqual(git("init", "-q").returncode, 0)
        for key, value in (("core.hooksPath", ".githooks"), ("user.name", "Import test"),
                           ("user.email", "import-test@example.invalid"), ("commit.gpgsign", "false")):
            self.assertEqual(git("config", key, value).returncode, 0)
        archive = self.package("first.zip", {"code.py": "source\n"})
        self.assertEqual(git("add", "packages/first.zip").returncode, 0)
        blocked = git("commit", "-m", "ZIP only must fail")
        self.assertNotEqual(blocked.returncode, 0)
        self.assertIn("IMPORT REFUSED", blocked.stderr)
        apply_import(self.root, plan_import(self.root, archive))
        self.assertEqual(git("add", "code.py", STATE).returncode, 0)
        accepted = git("commit", "-m", "Source and receipt")
        self.assertEqual(accepted.returncode, 0, accepted.stdout + accepted.stderr)

    def test_traversal_windows_aliases_and_protected_registers(self):
        for name in ("../outside.py", "C:/outside.py", "bad\\name.py", "CON.txt", "a./b.py", ".git/config", "todo.PACER.csv", "TODO.PACER.csv", "packages/import-state.json"):
            with self.subTest(name=name):
                archive = self.package("bad.zip", {name: "no"})
                with self.assertRaises(ValueError):
                    archive_members(self.root, archive)

    def test_case_collisions_refused(self):
        archive = self.package("bad.zip", {"A.py": "one", "a.py": "two"})
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            archive_members(self.root, archive)

    def test_document_paths_follow_current_layout(self):
        plan = plan_import(self.root, self.package("first.zip", {"docs/NP_14_ENGINE_THEORY.md": "theory", "REGISTER_COMMANDS_099.md": "commands"}))
        apply_import(self.root, plan)
        self.assertTrue((self.root / "docs/NorthPaw-game_docs/NP_14_ENGINE_THEORY.md").exists())
        self.assertTrue((self.root / "docs/register-commands_docs/REGISTER_COMMANDS_099.md").exists())

    def test_zip_only_commit_is_rejected_from_staged_state(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.import_first()
        subprocess.run(["git", "add", "."], cwd=self.root, check=True, capture_output=True)
        self.assertEqual(verify_imports(self.root, staged=True)["archives_checked"], 1)
        self.package("second.zip", {"code.py": "new"})
        subprocess.run(["git", "add", "packages/second.zip"], cwd=self.root, check=True)
        with self.assertRaisesRegex(ValueError, "has not been imported"):
            verify_imports(self.root, staged=True)

    def test_staged_old_source_rejected_even_with_new_receipt(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.import_first()
        subprocess.run(["git", "add", "."], cwd=self.root, check=True, capture_output=True)
        plan = plan_import(self.root, self.package("second.zip", {"code.py": "new"}))
        apply_import(self.root, plan)
        subprocess.run(["git", "add", "packages"], cwd=self.root, check=True)
        with self.assertRaisesRegex(ValueError, "Staged source"):
            verify_imports(self.root, staged=True)


if __name__ == "__main__":
    unittest.main()
