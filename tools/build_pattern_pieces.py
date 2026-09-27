"""Restore the exact original PAC-070 pattern library from its retained delivery.

A provisional reconstruction was used while the ZIP was missing. The original
archive became available during recovery; its bytes now replace that fallback.
The retired reconstruction is retained in Git history and the recovery snapshot.
"""
import argparse
import hashlib
import zipfile
from pathlib import Path

EXPECTED = "dd33612d59078fb0624b71a6be10605148eb55f4ea882c251ae81e769bdcc713"
PATHS = ("data/pattern_pieces.v1.json", "engine/greybox/pattern_pieces.v1.json")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    with zipfile.ZipFile(args.root / "packages/tnb_pac070_assembler.zip") as archive:
        originals = {name: archive.read(name) for name in PATHS}
    for name, content in originals.items():
        if hashlib.sha256(content).hexdigest() != EXPECTED:
            raise ValueError(f"Original PAC-070 member hash differs: {name}")
    for name, content in originals.items():
        target = args.root / name
        if args.check:
            if target.read_bytes() != content:
                raise ValueError(f"Original PAC-070 bytes differ: {name}")
        else:
            target.write_bytes(content)
    print("Both pattern libraries match the original PAC-070 delivery byte for byte.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
