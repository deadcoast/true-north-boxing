"""Reconstruct the missing PAC-070 content from the surviving assembler contract.

The original PAC-070 ZIP was absent during source recovery on 2026-09-27.
This is replacement authored content, NOT a claim to recover its original bytes.
Rules come from NP_04 sections 1/3/9 and the unchanged PAC-070 runtime checks.
Named-boss attack strings are never copied into the generic library.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def build(root: Path) -> dict:
    styles = {
        "SWARMER": {"weights": {"2": [60, 40], "3": [50, 35, 15]},
                    "combos": [["JAB", "LT_L_HOOK"], ["LT_R_HOOK", "L_UPC"], ["JAB", "R_UPC", "LT_L_HOOK"]]},
        "OUTBOXER": {"weights": {"2": [65, 35], "3": [55, 30, 15]},
                     "combos": [["JAB", "STEP_R_STR"], ["JAB", "R_STR"], ["JAB", "JAB", "LT_R_HOOK"]]},
        "SLUGGER": {"weights": {"2": [55, 45], "3": [45, 30, 25]},
                    "combos": [["R_HAY", "L_UPC"], ["L_HOOK", "R_UPC"], ["STEP_R_STR", "L_HOOK", "R_HAY"]]},
        "BOXERPUNCHER": {"weights": {"2": [60, 40], "3": [45, 35, 20]},
                         "combos": [["JAB", "R_STR"], ["L_HOOK", "R_STR"], ["JAB", "R_UPC", "L_HOOK"]]},
    }
    strings = []
    for style, record in styles.items():
        for tier in (1, 2, 3):
            for index, combo in enumerate(record["combos"]):
                special = tier == 3 and index == 2
                # Recovery breathing beats make every generic sequence distinct,
                # including the single-verb openings of authored named bosses.
                actions = [*combo, f"pause({180 + 70 * tier + 30 * index})"]
                if tier == 2:
                    actions.insert(1, "pause(140)")
                if special:
                    actions.insert(0, "RUSH(0.4m)")
                strings.append({"id": f"{style.lower()}_t{tier}_{index + 1}",
                    "label": f"Club {style.title()} {('Entry', 'Return', 'Finish')[index]} {tier}",
                    "style": style, "tier": tier, "role": "opener" if index == 0 else "followup",
                    "class": "SPECIAL" if special else "normal", "tell_ms": 700 if special else 450 + index * 75,
                    "actions": actions})
    patterns = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((root / "engine/greybox/patterns").glob("*.json"))]
    houses = json.loads((root / "data/houses.v1.json").read_text(encoding="utf-8"))["houses"]
    dialects = {}
    for house in houses:
        if house == "sealed":
            continue
        examples = [p for p in patterns if p["meta"].get("house", "").lower().replace("house_", "").split("_")[0] == house]
        motifs = []
        for pattern in examples:
            for string in pattern["strings"].values():
                motif = string["tell"]["motif"]
                if motif not in motifs:
                    motifs.append(motif)
        while len(motifs) < 4:
            motifs.append(f"{house}_{('shoulder_set', 'lead_glove_turn', 'rear_heel_load', 'both_gloves_set')[len(motifs)]}")
        dialects[house] = {"house": house, "element": examples[0]["meta"].get("element", "NONE") if examples else "NONE",
            "channel": "visual-body", "motifs": {"normal": motifs[:3], "SPECIAL": motifs[3:4]}}
    for name in ("school", "gym"):
        dialects[name] = {"house": "none", "element": "NONE", "channel": "visual-body",
            "motifs": {"normal": [f"{name}_lead_shoulder", f"{name}_glove_set", f"{name}_heel_turn"], "SPECIAL": [f"{name}_wide_stance"]}}
    hooks = []
    for style in styles:
        for tier, trigger in enumerate(("player_power_whiff", "player_corner_entry", "player_taunt"), 1):
            hooks.append({"id": f"{style.lower()}_punish_{tier}", "style": style, "tier": tier,
                          "trigger": trigger, "response": "immediate {lead}"})
    result = {
        "schema": "PatternPieces/NP_04-s9/v1.0",
        "provenance": {"kind": "reconstructed", "date": "2026-09-27", "original_archive_missing": "PAC-070",
            "rules": "NP_04 sections 1, 3, 9; surviving assembler.gd and original PAC-070 regression checks",
            "content": "Replacement generic combinations, selection weights and fallback motifs; not original-byte recovery or human gameplay approval."},
        "rules": {"default_dialect": "gym", "slot": "R1", "strings_by_tier": {"1": 2, "2": 3, "3": 3},
            "special_at_tier": 3, "interrupt_by_tier": {"1": "all_normal", "2": "first_two", "3": "opener"},
            "interrupt_response": "stagger(800)", "class_floors_ms": {"normal": 400, "SPECIAL": 700, "DESPERATION": 1200},
            "tell_tiers": {"1": {"band": [600, 1200], "shift": 150}, "2": {"band": [450, 700], "shift": 0}, "3": {"band": [400, 500], "shift": -100}},
            "stats_by_tier": {"1": 40, "2": 55, "3": 70}},
        "styles": {style: {"weights": rec["weights"]} for style, rec in styles.items()},
        "strings": strings, "punish": hooks, "dialects": dialects,
    }
    named = [s for p in patterns for s in p["strings"].values()]
    assert len(strings) == 36 and len(hooks) == 12 and len(dialects) == 15
    assert all(s["actions"] != n["actions"] and s["label"] != n["label"] for s in strings for n in named)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    payload = (json.dumps(build(args.root), indent=1, ensure_ascii=False) + "\n").encode("utf-8")
    for name in ("data/pattern_pieces.v1.json", "engine/greybox/pattern_pieces.v1.json"):
        (args.root / name).write_bytes(payload)
    print("Reconstructed pattern pieces: 36 strings, 12 punish hooks, 15 dialects; both copies written")


if __name__ == "__main__":
    main()
