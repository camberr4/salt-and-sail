# Architecture (milestone 1)

Portrait, 1080x1920 base resolution, `canvas_items` stretch with `expand`
aspect (tall phones simply see more sea above and below). Godot's
Compatibility (OpenGL ES 3) renderer for the widest Android reach.

## Flow

`scripts/main.gd` is the only scene script. It owns one `Sea` for its whole
life and swaps what is on top of it:

```
boot -> TITLE (Sea in autopilot, whole map revealed)
     -> LOADING (mist wipe, worker thread generates a new archipelago)
     -> VOYAGE (HUD + joystick) <-> PAUSED (menu / chart / settings)
     -> SUMMARY (voyage log) -> new voyage or back to TITLE
```

Android back button and losing focus both pause.

## The sea

* `WorldGen` makes a 450x800 cell height field (24 px per cell, a 10800x19200
  world, ten portrait screens each way). Islands are noisy ellipses scattered
  with a Poisson-style rejection, then given roles (village, lighthouse,
  treasure, skull rock) and open-water points of interest are placed with a
  best-candidate sampler so they spread out evenly. Generation is
  deterministic per seed and runs on a worker thread.
* The height field is uploaded as a texture. `shaders/world.gdshader` draws
  water, surf, beaches, forests, rock, cloud shadows, rain ripples and the fog
  of war in **one full-screen quad**. The CPU uses the same field for
  collisions, so the visible coastline is the real one.
* `FogOfWar` is a 225x400 byte mask the world and chart shaders sample with
  linear filtering. Vision radius depends on weather.
* At Low/Medium graphics the quad renders into a smaller SubViewport and is
  scaled up behind everything (`SeaWorld`).

## Weather

`Weather` is a five-state machine (clear, fog, rain, storm, night) whose
parameters ease towards each state's profile and are published as shader
globals (`g_*`, declared in `Game`). `atmosphere.gdshader` is one full-screen
pass for night darkness with lantern light cut out of it, fog, rain streaks,
lightning and vignette.

## Entities

* `Ship` holds physics (turn toward the stick, push for speed, wind, slide
  along coasts). `ShipVisual` draws hull, deck, rigging, sails that follow
  the wind, a waving flag, lanterns, all in `_draw` with a small `look`
  dictionary that upgrades and livery will drive in milestone 2.
* `Poi` + `PoiArt`: eight kinds, each drawn in code and animated. Discovery
  happens when the spyglass radius reaches them; visits give gold, rumours,
  a lighthouse reveal, and so on.
* `Ambient` (gulls, dolphins), `Wake`, `Fx` (one pooled particle system).

## Where milestone 2 plugs in

* Events and combat: `Sea._visit()` already returns a result dictionary per
  point of interest; replace the text card with an event scene there.
* Harbour upgrades: `ShipVisual.look` and `Ship.MAX_SPEED`/`TURN_RATE`.
* Saving: `Game.stats` and `Game.save()` exist; add atlas entries beside them.
