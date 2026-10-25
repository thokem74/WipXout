# Audio sources

The racing sounds are original processed combinations of these CC0 assets.
No audio was extracted from Star Wars films or games.

- **Racing car engine sound loops**, by **domasx2**:
  [source and CC0 declaration](https://opengameart.org/content/racing-car-engine-sound-loops).
  Retained file: `tools/audio_sources/racing/loop_0.wav`. The publisher states
  that this version was remade from a public-domain car recording.
- **Sci-Fi Sounds 1.0**, by **Kenney**:
  [source and CC0 declaration](https://kenney.nl/assets/sci-fi-sounds).
  Retained files: `engineCircular_000.ogg`, `spaceEngineLow_000.ogg`,
  `spaceEngineSmall_000.ogg`, `thrusterFire_000.ogg`, `impactMetal_000.ogg`,
  and `explosionCrunch_000.ogg` under `tools/audio_sources/kenney`.
  Kenney's original `License.txt` is retained alongside the recordings.

Sources were retrieved on 2026-10-25. CC0 dedication:
<https://creativecommons.org/publicdomain/zero/1.0/>.
`tools/audio_sources/manifest.json` records SHA-256 fingerprints of the originals.
The source folder is ignored by Godot and excluded from Android exports.

## Processing and regeneration

Run `python3 tools/generate_audio.py --preview` with Python 3 and FFmpeg installed.
The tool reads the retained originals without network access, filters and layers
them, applies soft saturation, and crossfades loop boundaries. It validates
headroom, loop seams, and distinct outputs, then writes mono 44.1 kHz, 16-bit WAVs
to `assets/audio`. Source recordings are never overwritten.

- **VECTOR / player and ION:** the same lower mechanical texture with uneven
  rhythmic engine pulses, using matching idle and loaded recordings.
- **EMBER:** turbine recordings, a rotary layer, and a restrained whine.
- **Boost:** processed thruster and racing-engine roar.
- **Countdown / GO / wall / finish:** mechanical klaxon pulses, launch blast,
  metallic collision, and a double racing horn.

The optional stereo preview is `builds/pod-race-audio-preview.wav`:
0–7 seconds VECTOR, 7–14 ION, 14–21 EMBER, 21–25 a rival pass-by,
and 25–31 the countdown, launch, wall, and finish cues. Each engine segment
includes idle, acceleration, coasting, braking rundown, and boost.
