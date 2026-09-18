"""Exercise the standalone validator against valid and damaged small repositories."""

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

VALIDATOR = Path(__file__).resolve().parents[1] / "pacer_validator.py"


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tasks = [self.task("PAC-001")]
        self.asset = {
            "ID": "OVR-001",
            "AssetType": "FILE",
            "Path": "asset.txt",
            "Purpose": "Québec fixture",
            "NDLRefs": "",
        }
        (self.root / "asset.txt").write_text("asset", encoding="utf-8")
        self.write(
            "organism.PACER.csv",
            [
                {
                    "ID": "OGM-001",
                    "Title": "Future",
                    "Status": "SCAFFOLD",
                    "Requirement": "Future behavior",
                }
            ],
        )
        self.nodule = {
            "ID": "NDL-001",
            "NoduleName": "history",
            "Intent": "Old work",
            "Status": "ABSORBED",
            "Lane": "fixture",
            "CreatedAt": "2026-09-18T00:00:00Z",
            "AbsorbedAt": "2026-09-18T00:01:00Z",
            "AcceptanceEvidence": "Historical fixture",
            "SpawnedPACs": "PAC-001",
            "TargetOVR": "OVR-001",
        }
        self.write("nodule.PACER.csv", [], list(self.nodule))

    @staticmethod
    def task(id):
        return {
            "ID": id,
            "Title": id,
            "Phase": "test",
            "Status": "TODO",
            "DoD": "Fixture",
            "BlockedBy": "",
            "DependencyType": "",
            "StartedAt": "",
            "DoneAt": "",
            "NDLRefs": "",
        }

    def write(self, name, rows, columns=None):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as target:
            writer = csv.DictWriter(target, fieldnames=columns or list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)

    def run_validator(self):
        self.write("todo.PACER.csv", self.tasks)
        self.write("overlord.PACER.csv", [self.asset])
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--dir", str(self.root)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )

    def test_valid_utf8_repository(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_semicolon_mixed_dependencies_enforce_hard_gate(self):
        self.tasks += [self.task("PAC-002"), self.task("PAC-003")]
        self.tasks[0].update(
            Status="DONE",
            StartedAt="2026-09-18T00:00:00Z",
            DoneAt="2026-09-18T00:01:00Z",
            BlockedBy="PAC-002;PAC-003",
            DependencyType="hard;soft",
        )
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertIn("DONE with open hard blockers", result.stdout)
        self.tasks[1].update(
            Status="DONE",
            StartedAt="2026-09-18T00:00:00Z",
            DoneAt="2026-09-18T00:01:00Z",
        )
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_canonical_archived_nodule_resolves_reciprocal_references(self):
        self.tasks[0]["NDLRefs"] = "NDL-001"
        self.asset["NDLRefs"] = "NDL-001"
        self.assertEqual(self.run_validator().returncode, 1)
        self.write("archive/nodules/NDL-001.PACER.csv", [self.nodule])
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_duplicate_live_and_archived_id_is_rejected(self):
        self.write("nodule.PACER.csv", [self.nodule])
        self.write("archive/nodules/NDL-001.PACER.csv", [self.nodule])
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertIn("duplicate ID", result.stdout)

    def test_archive_filename_must_match_its_id(self):
        self.write("archive/nodules/NDL-002.PACER.csv", [self.nodule])
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertIn("invalid canonical nodule archive", result.stdout)

    def test_ragged_and_duplicate_headers_fail_closed(self):
        for text in (
            "ID,Title,Status,Requirement\nOGM-001,too-short\n",
            "ID,ID,Status,Requirement\nOGM-001,duplicate,SCAFFOLD,test\n",
        ):
            (self.root / "organism.PACER.csv").write_text(text, encoding="utf-8")
            result = self.run_validator()
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)

    def test_external_source_path_is_rejected(self):
        self.asset["Path"] = str(VALIDATOR)
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertIn("outside repo", result.stdout)

    def test_semicolon_cycle_is_detected(self):
        self.tasks += [self.task("PAC-002"), self.task("PAC-003")]
        self.tasks[0]["BlockedBy"] = "PAC-002;PAC-003"
        self.tasks[1]["BlockedBy"] = "PAC-001"
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertIn("circular dependency", result.stdout)


if __name__ == "__main__":
    unittest.main()
