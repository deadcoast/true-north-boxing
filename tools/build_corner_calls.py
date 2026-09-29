"""Build offline corner calls from retained speech masters; never play audio.

Masters: edge-tts 7.2.7, en-CA-LiamNeural / fr-CA-AntoineNeural, rate +35%.
https://github.com/rany2/edge-tts --write-media (not edge-playback).
Only exterior silence is trimmed. A bounded, pitch-preserving tempo adjustment
fits the complete line inside the authored tell; no phoneme is cut to fit.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = root / "assets/audio/corner_calls/source"
    output = root / "engine/greybox/audio/corner_calls"
    output.mkdir(parents=True, exist_ok=True)
    clips = []
    for language, voice, words in [
        ("en", "en-CA-LiamNeural", ("Sequence one!", "Sequence four!", "Sequence seven!")),
        ("fr", "fr-CA-AntoineNeural", ("Séquence un !", "Séquence quatre !", "Séquence sept !")),
    ]:
        for number, word, text in zip((1, 4, 7), ("one", "four", "seven"), words):
            master = source / f"{language}_{word}.mp3"
            raw = subprocess.run([args.ffmpeg, "-v", "error", "-i", str(master), "-f", "s16le", "-ac", "1", "-ar", "24000", "-"], check=True, capture_output=True).stdout
            samples = array.array("h", raw)
            if sys.byteorder != "little": samples.byteswap()
            # Retain 20ms before/after all samples above -50dBFS, including quiet
            # final consonants. Never remove an internal gap between syllables.
            voiced = [i for i, sample in enumerate(samples) if abs(sample) > 104]
            if not voiced: raise ValueError(f"Silent master: {master}")
            start, end = max(0, voiced[0] - 480), min(len(samples), voiced[-1] + 481)
            limit = 0.68 if number != 7 else 0.58
            tempo = max(1.0, (end - start) / 24000 / limit)
            if tempo > 1.4: raise ValueError(f"Re-record {master}: tempo {tempo:.3f} exceeds bound")
            destination = output / f"{language}_{number}.wav"
            with tempfile.TemporaryDirectory(prefix="tnb-call-") as temp:
                trimmed = Path(temp) / "trimmed.wav"
                with wave.open(str(trimmed), "wb") as wav:
                    wav.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
                    wav.writeframes(raw[start * 2:end * 2])
                subprocess.run([args.ffmpeg, "-v", "error", "-y", "-i", str(trimmed), "-af", f"atempo={tempo:.6f},afade=t=in:d=0.003", "-acodec", "pcm_s16le", str(destination)], check=True)
            with wave.open(str(destination), "rb") as wav:
                pcm = array.array("h", wav.readframes(wav.getnframes()))
                if sys.byteorder != "little": pcm.byteswap()
                duration = wav.getnframes() / wav.getframerate()
            if duration > limit + 0.02: raise ValueError(f"Call exceeds tell: {destination} {duration}")
            clips.append({"file": destination.relative_to(root).as_posix(), "master": master.relative_to(root).as_posix(), "text": text, "voice": voice, "rate": "+35%", "trim_frames": [start, end], "tempo": round(tempo, 6), "seconds": duration, "peak": max(abs(x) for x in pcm) / 32768, "rms": math.sqrt(sum(x*x for x in pcm) / len(pcm)) / 32768, "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(), "master_sha256": hashlib.sha256(master.read_bytes()).hexdigest()})
    (output / "manifest.json").write_text(json.dumps({"provenance": "Synthetic Canadian English/French functional corner calls, edge-tts 7.2.7. Offline runtime; not final cast recordings or a human listening acceptance.", "source": "https://github.com/rany2/edge-tts", "build": "tools/build_corner_calls.py --ffmpeg <ffmpeg>", "clips": clips}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for clip in clips: print(f"{clip['file']}: {clip['seconds']:.3f}s, tempo {clip['tempo']}, peak {clip['peak']:.3f}")


if __name__ == "__main__":
    main()
