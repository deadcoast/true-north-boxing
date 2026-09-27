"""Compatibility entry point for the canonical root PACER tool."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pacer_views import main

if __name__ == "__main__":
    raise SystemExit(main())
