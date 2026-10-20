# Salt & Sail: Progress

Working title: **Salt & Sail**. A top-down pirate exploration roguelite for Android, built in Godot 4.

## How to use this file
Every session starts by reading this file. Every milestone ends by updating it and committing.

## Status
- Design: done for now (see docs/DESIGN-SUMMARY.md)
- Code: not started
- Assets: none supplied yet

## Next
1. Milestone 1: ship sailing on a procedural sea with joystick, fog of war, a few points of interest, weather.
2. Milestone 2: events, combat, harbor with visible upgrades.
3. Milestone 3: legend, side goals, Atlas, voyage report.

## Decisions
- Engine: Godot 4, exported to Android.
- Free to try for three voyages, then one-time purchase unlocks the full game. No ads.
- Each voyage chases one legend, plus three smaller goals. Failed voyages still pay out (Atlas entries, half the gold, remembered clues).
- Ships are drawn in code in layers; the user supplies painted stills and Suno music.

## Open questions
- Sound effects source (Epidemic Sound license for games unconfirmed; fallback CC0 / Sonniss).
- Night-only POIs in the prototype?
- Suno paid-plan commercial terms.
- Final title: check Play Store for name clashes.

## Known bugs
None yet.
