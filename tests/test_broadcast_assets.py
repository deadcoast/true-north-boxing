"""The shipped speech must still match its source text, masters and PCM manifest."""
import array
import hashlib
import json
from pathlib import Path
import sys
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


class BroadcastAssets(unittest.TestCase):
    def test_shipped_audio_matches_retained_masters_and_authored_words(self):
        manifest = json.loads((ROOT / "engine/greybox/audio/broadcast/manifest.json").read_text(encoding="utf-8"))
        authored = json.loads((ROOT / "engine/greybox/episode/broadcast.v1.json").read_text(encoding="utf-8"))["cues"]
        story = json.loads((ROOT / "engine/greybox/episode/letter.v1.json").read_text(encoding="utf-8"))
        provenance = json.loads((ROOT / "assets/audio/broadcast/source/provenance.json").read_text(encoding="utf-8"))
        masters = {r["master_sha256"]: r for r in provenance["clips"]}
        self.assertEqual(set(manifest["cues"]), set(authored))
        files = set()
        for key, cue in authored.items():
            for language in ("en", "fr_CA"):
                with self.subTest(cue=key, language=language):
                    clip = manifest["cues"][key]["clips"][language]
                    expected = story["scenes"][cue["scene"]][cue["line"]][1 if language == "en" else 2] if "scene" in cue else cue[language]
                    self.assertEqual(clip["text"], expected)
                    wav_path = ROOT / "engine/greybox" / clip["file"].removeprefix("res://")
                    master = ROOT / clip["master"]
                    self.assertEqual(hashlib.sha256(wav_path.read_bytes()).hexdigest(), clip["sha256"])
                    self.assertEqual(hashlib.sha256(master.read_bytes()).hexdigest(), clip["master_sha256"])
                    self.assertEqual(masters[clip["master_sha256"]]["text"], expected)
                    self.assertTrue((master.parent / (clip["voice"] + ".MODEL_CARD.txt")).is_file())
                    with wave.open(str(wav_path)) as wav:
                        self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 24000))
                        self.assertAlmostEqual(wav.getnframes() / wav.getframerate(), clip["seconds"])
                        pcm = array.array("h", wav.readframes(wav.getnframes()))
                    if sys.byteorder != "little": pcm.byteswap()
                    self.assertGreater(max(abs(x) for x in pcm), 1000)
                    self.assertLess(max(abs(x) for x in pcm), 32767)
                    files.add(wav_path.name)
            if cue.get("bilingual"):
                self.assertEqual(manifest["cues"][key]["clips"]["en"]["file"], manifest["cues"][key]["clips"]["fr_CA"]["file"])
        self.assertEqual(files, {p.name for p in (ROOT / "engine/greybox/audio/broadcast").glob("*.wav")})


if __name__ == "__main__":
    unittest.main()
