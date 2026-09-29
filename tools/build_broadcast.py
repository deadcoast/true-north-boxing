"""Rebuild complete offline broadcast lines from retained speech masters. No playback.

Generate masters locally with Piper 1.4.2. Dialogue text comes from the episode
script data. Danielle's authored French stays French in both locales. No runtime
service, chopped phonemes, or generated missing name. Provisional accents only.
"""
import argparse
import array
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "engine/greybox/episode/broadcast.v1.json").read_text(encoding="utf-8"))
    story = json.loads((root / "engine/greybox/episode/letter.v1.json").read_text(encoding="utf-8"))
    output = root / "engine/greybox/audio/broadcast"
    output.mkdir(parents=True, exist_ok=True)
    manifest = {"provenance": data["provenance"], "authority": data["authority"], "build": "tools/build_broadcast.py --ffmpeg <ffmpeg>", "cues": {}}
    for key, cue in data["cues"].items():
        row = {"speaker": cue["speaker"], "clips": {}}
        for language in ("en", "fr_CA"):
            text = story["scenes"][cue["scene"]][cue["line"]][1 if language == "en" else 2] if "scene" in cue else cue[language]
            shared = "fr_CA" if cue.get("bilingual") else language
            voice = "fr_FR-siwis-medium" if cue.get("bilingual") else ("en_US-john-medium" if language == "en" else "fr_FR-tom-medium")
            name = f"{key}_{shared}"
            master = root / f"assets/audio/broadcast/source/{name}.wav"
            destination = output / f"{name}.wav"
            # Retain the whole utterance and its natural spaces. Archive has a
            # narrower broadcast band; modern stream keeps full speech detail.
            filters = "highpass=f=240,lowpass=f=4200" if cue.get("archive") else "highpass=f=90,lowpass=f=10500"
            subprocess.run([args.ffmpeg, "-v", "error", "-y", "-i", str(master), "-af", filters + ",loudnorm=I=-19:TP=-2:LRA=7", "-ar", "24000", "-ac", "1", "-acodec", "pcm_s16le", str(destination)], check=True)
            with wave.open(str(destination), "rb") as wav:
                seconds = wav.getnframes() / wav.getframerate()
                pcm = array.array("h", wav.readframes(wav.getnframes()))
            if sys.byteorder != "little": pcm.byteswap()
            peak = max(abs(x) for x in pcm) / 32768
            if not 0 < peak < 1: raise ValueError(f"Silent or clipped speech: {name}")
            row["clips"][language] = {"text": text, "voice": voice, "length_scale": 0.94, "file": "res://audio/broadcast/" + destination.name, "master": master.relative_to(root).as_posix(), "seconds": seconds, "peak": peak, "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(), "master_sha256": hashlib.sha256(master.read_bytes()).hexdigest()}
        manifest["cues"][key] = row
        print(f"{key}: EN {row['clips']['en']['seconds']:.2f}s / FR {row['clips']['fr_CA']['seconds']:.2f}s")
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
