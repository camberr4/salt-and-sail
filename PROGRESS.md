# Salt & Sail: Progress

Working title: **Salt & Sail**. A top-down pirate exploration roguelite for Android, built in Godot 4.

## How to use this file
Every session starts by reading this file. Every milestone ends by updating it and committing.

## Status
- Design: done for now (see docs/DESIGN-SUMMARY.md)
- Code: **Milestone 1 built** (sailing sea, joystick, fog of war, points of interest, weather). See "Milestone 1" below.
- Assets: nothing supplied yet. Everything is generated or code-drawn placeholder; fonts are OFL (Pirata One, Almendra).

## Milestone 1: what is in
- Portrait (1080x1920 base), Godot Compatibility renderer, floating one-thumb joystick (also keyboard, mouse, gamepad on desktop).
- Procedural archipelago per voyage (10x10 portrait screens, about 150 islands, deterministic per seed, generated on a worker thread behind a "Charting the seas" screen). The whole sea is one shader quad: water with swell, caustics and glints, animated surf, beaches, forests, rock, cloud shadows.
- Fog of war: persistent explored mask plus a live spyglass radius; unexplored water is moving murk; remembered water is dimmed.
- Ship drawn in code in layers (shadow, hull, deck, fittings, three masts with topsails, jib, crow's nest, flag), sails follow the wind, heel and bob, foam wake, bow spray.
- Weather: clear, fog, rain, storm, night. Smooth transitions, forecast warnings, wind that helps and hinders, lightning and thunder, lantern light cut out of the night, vision radius shrinks in bad weather.
- Eight points of interest, all animated in code: harbour village (home port is the start), lighthouse (clears fog for miles, rotating beam), treasure islet, skull rock, wreck, whirlpool (pulls the ship, spits it out), message in a bottle, night-only wisps. Visits give gold and rumours (marked on the chart).
- Ambient life: gull flocks around land, dolphin pods leaping beside the ship.
- HUD: gold, chart percentage, round minimap, weather and wind badge, discovery banners, arrival cards. Full sea chart (pan, pinch/zoom, grid refs, markers). Title screen with live sea, pause, settings, voyage log.
- Settings: volumes, joystick size, vibration, Graphics Low/Medium/High (High renders full res, Low/Medium render the sea smaller and scale up), Battery saver (30 fps), FPS counter.
- Audio system with three buses and weather-driven ambience and music crossfades. **All audio is generated placeholder** (`tools/gen_audio.py`), replaceable file for file (see assets/audio/README.md).
- Android: export preset (arm64 AAB, portrait, immersive, only VIBRATE), adaptive icons, docs/ANDROID-EXPORT.md, draft Play listing and six 1080x1920 screenshots in store/.

## What was verified, and what was not
Verified here (software OpenGL under Xvfb, Godot 4.3, with a spot check on 4.7): every screen and state by screenshot, a 2500 frame autopilot soak through a weather change, a full voyage > log > new voyage > log > title cycle, real touch events driving the joystick, all three Graphics tiers aligned and rendering, import clean with no script errors.

**Not verified, please test before shipping:**
- Nothing has run on a real Android device. Performance on real GPUs is unmeasured; that is the main risk (the sea shader is the heavy part). Check frame time on a low-end phone and tune the Graphics tiers (`SeaWorld.SCALES`, quality branches in `shaders/world.gdshader`).
- No `.aab`/`.apk` has been built (no Android SDK in the working environment). The preset is written but unexercised.
- The generated audio has been checked for levels and looping only; nobody has listened to it. Expect to replace the music at least.
- Touch feel (joystick size 170 px base, ship speed/turn rate in `Ship`) needs thumb time on a phone.

## Next
1. Put it on a phone: AAB export per docs/ANDROID-EXPORT.md (upgrade to latest stable Godot first so Play's target API requirement is met), measure, tune, fix.
2. Milestone 2: events, combat, harbour with visible upgrades.
3. Milestone 3: legend, side goals, Atlas, voyage report.
4. Monetisation (free for three voyages, then one-time unlock) needs Google Play Billing. `Game.stats.voyages_started` already counts voyages. Not started.

## Decisions
- Engine: Godot 4, exported to Android. Built on 4.3, opens cleanly in 4.7.
- **Portrait only** (decided at milestone 1, one-handed play). World is 10 by 10 portrait screens.
- Free to try for three voyages, then one-time purchase unlocks the full game. No ads. (Not implemented yet.)
- Each voyage chases one legend, plus three smaller goals. Failed voyages still pay out (Atlas entries, half the gold, remembered clues). (Milestone 3.)
- Ships are drawn in code in layers; the user supplies painted stills and Suno music. Placeholder audio ships until then.
- No network permission, no ads, no analytics: privacy policy can say "collects nothing".
- Package id in the export preset is `com.camberr4.saltandsail` (permanent once published; change before first upload if wanted).

## Open questions
- Sound effects source (Epidemic Sound license for games unconfirmed; fallback CC0 / Sonniss). Until decided the generated effects are in.
- Night-only POIs in the prototype? Implemented as an experiment: the "Wisp Shoal" only appears at night. Keep or drop?
- Suno paid-plan commercial terms.
- Final title: check Play Store for name clashes.
- Where do rumours lead once there are legends (milestone 3)? Today a rumour just marks a "?" on the chart.

## Known bugs / rough edges
- No crashes or script errors found in testing. Rough edges: the ship hull/sail art is code-drawn and plain next to future painted stills; dolphins and gulls are simple; whitecaps in storms look like scattered flecks rather than streaks; the rain ripple rings are large at close zoom.
- Home port is always at the bottom-left of the map.
- Pause on app focus loss is disabled in `--shot` developer runs only.
