"""Prove the archived gameplay roadmap survived canonicalization."""

import csv
import io
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


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
                    "DependencyType",
                ):
                    self.assertEqual(row[field], original[field])
                self.assertEqual(
                    row["BlockedBy"], original["BlockedBy"].replace(",", ";")
                )

    def test_alternate_task_registers_are_archived_only(self):
        for path in ("NORTHPAW_PACER.csv", "docs/northpaw/overview.PACER.csv"):
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()
