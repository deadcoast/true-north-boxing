"""Worklist regressions, including destructive output protection."""

import contextlib
import csv
import io
import os
import tempfile
import unittest
from pathlib import Path

from pacer_views import blockers_done, is_ready, load, main


class DependencyTests(unittest.TestCase):
    def test_semicolon_hard_dependencies(self):
        row = {"BlockedBy": "PAC-001;PAC-002", "DependencyType": "hard"}
        self.assertTrue(
            blockers_done(
                row, {key: {"Status": "DONE"} for key in ("PAC-001", "PAC-002")}
            )
        )
        self.assertFalse(blockers_done(row, {"PAC-001": {"Status": "DONE"}}))

    def test_empty_type_is_hard(self):
        self.assertFalse(blockers_done({"BlockedBy": "PAC-001"}, {}))

    def test_mixed_types_keep_hard_gate(self):
        row = {
            "BlockedBy": "PAC-001;PAC-002;PAC-003",
            "DependencyType": "hard;soft;optional",
        }
        self.assertFalse(blockers_done(row, {}))
        self.assertTrue(blockers_done(row, {"PAC-001": {"Status": "DONE"}}))

    def test_uniform_soft_and_optional(self):
        for kind in ("soft", "optional"):
            self.assertTrue(
                blockers_done(
                    {"BlockedBy": "PAC-001;PAC-002", "DependencyType": kind}, {}
                )
            )

    def test_bad_dependency_grammar_fails_closed(self):
        for blockers, kinds in (
            ("PAC-001,PAC-002", "hard"),
            ("PAC-001;", "hard"),
            ("PAC-001", "hard;soft"),
            ("PAC-001", "typo"),
        ):
            with (
                self.subTest(blockers=blockers, kinds=kinds),
                self.assertRaises(ValueError),
            ):
                blockers_done({"BlockedBy": blockers, "DependencyType": kinds}, {})

    def test_approval_and_status_readiness(self):
        for approval in ("PENDING", "WITHDRAWN"):
            self.assertFalse(
                is_ready({"Status": "TODO", "ApprovalState": approval}, {})
            )
        self.assertFalse(is_ready({"Status": "TODO", "Phase": "PROPOSAL"}, {}))
        self.assertTrue(
            is_ready(
                {"Status": "TODO", "Phase": "PROPOSAL", "ApprovalState": "APPROVED"}, {}
            )
        )
        self.assertTrue(is_ready({"Status": "TODO", "ApprovalState": "LEGACY"}, {}))
        self.assertFalse(is_ready({"Status": "DOING"}, {}))


class ViewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "todo.PACER.csv"
        self.headers = [
            "ID",
            "Title",
            "Phase",
            "Status",
            "Assignee",
            "BlockedBy",
            "DependencyType",
            "Notes",
        ]
        with self.source.open("w", encoding="utf-8-sig", newline="") as target:
            writer = csv.DictWriter(target, fieldnames=self.headers)
            writer.writeheader()
            writer.writerow(
                {
                    "ID": "PAC-001",
                    "Title": "Québec, été",
                    "Phase": "P0",
                    "Status": "TODO",
                    "Assignee": "codex",
                    "BlockedBy": "",
                    "DependencyType": "",
                    "Notes": "first\nsecond",
                }
            )

    def call(self, *args):
        with (
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            return main(["--register", str(self.source), *map(str, args)])

    def test_utf8_multiline_round_trip(self):
        output = self.root / "view.csv"
        self.assertEqual(self.call("--ready", "--out", output), 0)
        self.assertEqual(load(self.source), load(output))

    def test_empty_view_preserves_headers(self):
        output = self.root / "empty.csv"
        self.call("--phase", "missing", "--out", output)
        self.assertEqual(load(output), ([], self.headers))

    def test_header_only_source(self):
        self.source.write_text(",".join(self.headers) + "\n", encoding="utf-8")
        self.call("--ready", "--out", self.root / "empty.csv")
        self.assertEqual(load(self.root / "empty.csv"), ([], self.headers))

    def test_canonical_and_existing_outputs_are_unchanged(self):
        existing = self.root / "important.txt"
        existing.write_text("keep me", encoding="utf-8")
        for output in (self.source, existing):
            before = output.read_bytes()
            with self.subTest(output=output), self.assertRaises(SystemExit) as raised:
                self.call("--out", output)
            self.assertEqual(raised.exception.code, 2)
            self.assertEqual(output.read_bytes(), before)

    def test_hardlink_alias_is_unchanged(self):
        alias = self.root / "alias.csv"
        os.link(self.source, alias)
        before = self.source.read_bytes()
        with self.assertRaises(SystemExit):
            self.call("--out", alias)
        self.assertEqual(self.source.read_bytes(), before)

    def test_new_canonical_name_is_rejected(self):
        output = self.root / "overlord.PACER.csv"
        with self.assertRaises(SystemExit):
            self.call("--out", output)
        self.assertFalse(output.exists())

    def test_malformed_csv_and_duplicate_ids(self):
        original = self.source.read_text(encoding="utf-8-sig")
        for data in (
            "ID,ID\n1,2\n",
            ",".join(self.headers) + "\nPAC-001,short\n",
            original + original.split("\n", 1)[1],
        ):
            self.source.write_text(data, encoding="utf-8")
            with self.subTest(data=data), self.assertRaises(ValueError):
                load(self.source)


if __name__ == "__main__":
    unittest.main()
