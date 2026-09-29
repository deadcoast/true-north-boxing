# Episode 1 broadcast masters

Authored words: `docs/NorthPaw-game_docs/NP_12A_EP01_SCRIPT.md`, localized in
`engine/greybox/episode/letter.v1.json` and `episode/broadcast.v1.json`.
Danielle's French lines remain French in both locale settings.

These are **provisional synthetic performances**, generated locally with
[Piper 1.4.2](https://github.com/OHF-Voice/piper1-gpl), never sent to a speech
service. The source WAVs are retained, with model/config/audio SHA-256 records
in `source/provenance.json`. Playback is entirely offline; no speech engine or
model weights are included in the game. Canadian accents, directed emotion,
pronunciation review and final cast performance remain unfinished PAC-204 work.

Voice models, attribution and model-card terms:

* Gord, English: [John](https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_US/john/medium), US English, Bryce Beattie's LibriVox-derived voice; model card lists public-domain recordings.
* Gord, French: [Tom](https://huggingface.co/rhasspy/piper-voices/tree/main/fr/fr_FR/tom/medium), France French, [Tjiho French TTS model](https://git.bksp.space/Tjiho/French-tts-model-piper); model card lists AGPLv3.
* Danielle: [Siwis](https://huggingface.co/rhasspy/piper-voices/tree/main/fr/fr_FR/siwis/medium), France French, [SIWIS French Speech Synthesis Database](https://datashare.is.ed.ac.uk/handle/10283/2353), CC BY 4.0. Model card notes fine-tuning from Lessac medium.

The corresponding unmodified model cards are retained beside the masters.
No voice was cloned from a cast member or the user. Piper is a separate
GPL-3.0 build tool; it is not linked into or shipped with the Godot runtime.

To regenerate with locally available dependencies and model weights:

```
python tools/synthesize_broadcast.py --models <local-model-directory>
python tools/build_broadcast.py --ffmpeg <ffmpeg-executable>
```

Generation and build commands do not play sound. The builder retains complete
utterances, filters the archive into a narrower tape band, and normalizes speech
before writing mono PCM WAVs. Runtime narration pauses for controls, actionable
combat tells, counters, clinches, clashes and standing-eight rhythm. The missing
name has no speech asset and remains a one-second silent, caption-free hold.
