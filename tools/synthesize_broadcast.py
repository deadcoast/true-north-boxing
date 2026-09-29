"""Offline-only generation of retained broadcast masters; no downloads/playback.

Requires piper-tts==1.4.2 and the three attributed models in --models.
Build runtime WAVs afterward with build_broadcast.py. Never sends script text.
"""
import argparse
import hashlib
import json
from pathlib import Path
import wave


def main():
    from piper import PiperVoice, SynthesisConfig
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "engine/greybox/episode/broadcast.v1.json").read_text(encoding="utf-8"))
    story = json.loads((root / "engine/greybox/episode/letter.v1.json").read_text(encoding="utf-8"))
    output = root / "assets/audio/broadcast/source"
    output.mkdir(parents=True, exist_ok=True)
    voices = {}
    records = []
    for key, cue in data["cues"].items():
        for language in (["fr_CA"] if cue.get("bilingual") else ["en", "fr_CA"]):
            text = story["scenes"][cue["scene"]][cue["line"]][1 if language == "en" else 2] if "scene" in cue else cue[language]
            model = "fr_FR-siwis-medium" if cue.get("bilingual") else ("en_US-john-medium" if language == "en" else "fr_FR-tom-medium")
            path = args.models / (model + ".onnx")
            if model not in voices: voices[model] = PiperVoice.load(path)
            destination = output / f"{key}_{language}.wav"
            # Acronyms and shouting typography are captions; ordinary case
            # avoids letter-by-letter speech. Wording is unchanged.
            spoken = text.lower() if key == "vane_down" else text
            with wave.open(str(destination), "wb") as wav:
                voices[model].synthesize_wav(spoken, wav, syn_config=SynthesisConfig(length_scale=0.94))
            records.append({"cue": key, "language": language, "text": text, "spoken": spoken, "model": model, "model_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "config_sha256": hashlib.sha256(path.with_suffix(".onnx.json").read_bytes()).hexdigest(), "master_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
            print(destination.name, flush=True)
    (output / "provenance.json").write_text(json.dumps({"engine": "Piper 1.4.2 (offline)", "length_scale": 0.94, "clips": records}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
