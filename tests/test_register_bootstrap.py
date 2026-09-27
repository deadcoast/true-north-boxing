"""Preserve roadmap meaning and the documented September 18 dependency splits."""

import csv
import io
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Subsequent canonical planning split engine selection from physical latency and
# parser implementation from gameplay tuning. These are explicit expected edges,
# not a blanket exemption from preserving the original task requirements.
SPLIT_DEPENDENCIES = {
    "PAC-002": ("PAC-002A;PAC-002B", "hard"),
    "PAC-005": ("PAC-002A", "hard"),
    "PAC-010": ("PAC-005;PAC-006;PAC-007;PAC-008;PAC-009;PAC-002B", "hard"),
    "PAC-011": ("PAC-011A;PAC-011B", "hard"),
}


class BootstrapTests(unittest.TestCase):
    def test_original_task_ids_meaning_and_blockers_are_preserved(self):
        with zipfile.ZipFile(
            ROOT / "archive/legacy/pacer-before-bootstrap.zip"
        ) as archive:
            originals = list(
                csv.DictReader(
                    io.StringIO(archive.read("NORTHPAW_PACER.csv").decode("utf-8-sig"))
                )
            )
        with (ROOT / "todo.PACER.csv").open(encoding="utf-8", newline="") as source:
            current = {row["ID"]: row for row in csv.DictReader(source)}
        self.assertEqual(len(originals), 41)
        for original in originals:
            with self.subTest(task=original["ID"]):
                row = current[original["ID"]]
                for field in (
                    "Title",
                    "DoD",
                    "Instructions",
                    "ValidationCriteria",
                ):
                    self.assertEqual(row[field], original[field])
                expected = SPLIT_DEPENDENCIES.get(original["ID"],
                    (original["BlockedBy"].replace(",", ";"), original["DependencyType"]))
                self.assertEqual((row["BlockedBy"], row["DependencyType"]), expected)
        for id in ("PAC-002A", "PAC-002B", "PAC-011A", "PAC-011B"):
            self.assertIn(id, current)
        self.assertIn("PAC-010", current["PAC-011B"]["BlockedBy"].split(";"))

    def test_alternate_task_registers_are_archived_only(self):
        for path in ("NORTHPAW_PACER.csv", "docs/northpaw/overview.PACER.csv"):
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()
