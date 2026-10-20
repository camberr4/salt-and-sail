# Audio

All audio in this folder is **generated placeholder audio** (`tools/gen_audio.py`).
Nothing here is licensed third-party material, so the game runs and ships
without any audio purchases. Replace any file one-to-one with real recordings
or Suno tracks: keep the file name, drop in a `.ogg` (or `.wav`), done. Godot
re-imports it automatically.

## Music (`music/`)

One looping track per weather state. The music director crossfades between
them over 3 seconds whenever the weather changes.

| file | plays during | feel |
|---|---|---|
| `title.ogg` | title screen, voyage log | grand, harp and bells |
| `calm.ogg` | clear skies | 6/8 sea shanty, plucks, light percussion |
| `fog.ogg` | fog | sparse, cold bells, drones |
| `rain.ogg` | rain | soft piano-like pulses |
| `storm.ogg` | storm | timpani, tension |
| `night.ogg` | night | music-box lullaby |

Tips for Suno exports: make them loop cleanly (ends fade into the start),
about 60 to 120 seconds, and export as OGG Vorbis or WAV. Keep peaks around
-3 dBFS. The music bus has its own volume slider in Settings.

## Sound effects (`sfx/`)

One-shots: `click`, `discover`, `coin`, `arrive`, `horn`, `scrape`, `splash`,
`creak`, `thunder`.

Ambience loops (must loop seamlessly): `amb_sea`, `amb_wind`, `amb_rain`,
`amb_night`. Their volumes follow the weather automatically.

The code never fails on a missing file; it just stays silent for that cue.
