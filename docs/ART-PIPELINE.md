# Art pipeline: what to generate, with exact prompts

The 3D sea (terrain, water, ship, trees, wake, lighting, weather) is built and
playable with **procedural placeholder art**. To reach the painted, lifelike look
of the reference screenshots, replace the placeholders with painted assets. This
file lists every asset, its exact specs, and a prompt written to keep the whole
set cohesive. Generate in the order given; the first block is the style anchor.

## 0. Style anchor (paste at the start of EVERY prompt)

> **STYLE:** hand-painted stylised-realistic game art, rich saturated colour, soft
> painterly brush texture with visible but fine strokes, clean readable
> silhouettes, warm sunlight from the upper right with soft cool shadows falling
> to the lower left, high-end mobile game quality, tropical turquoise and deep
> sapphire sea palette, warm sand, lush emerald foliage, weathered honey-brown
> wood, cream canvas sails. Consistent with a premium 3D hand-painted pirate
> exploration game. No text, no watermark, no signature, no frame.

Rules that keep every asset consistent:
- **Camera:** top-down tilted about 68 degrees (looking mostly straight down).
  Nothing is drawn from a side view unless stated.
- **Light:** from the upper right. Highlights on upper-right edges, shade lower left.
- **Palette:** sea turquoise `#4DD6C4` to sapphire `#0A4FA0` to navy `#06265A`;
  sand `#F0DBA0`; grass `#6BB33A`; deep foliage `#1E6B30`; wood `#8A5A2B`;
  canvas `#F2E8CF`; rock `#6F6558`; accent red `#B8392B`; brass `#E8B64A`.
- **Format:** PNG, sRGB. Sprites on **transparent** background (ask the
  generator for "isolated on a plain flat magenta background" then key it out,
  or use its transparent-PNG mode). Tileables must tile seamlessly.
- **Names:** exactly as below, into `assets/art/<folder>/`. I wire them up; no
  code changes are needed from you.

## 1. Terrain textures (tileable, 1024x1024, albedo only, no baked shadows)

Use "seamless tileable texture, flat top-down view, no perspective, no lighting
direction, no shadows" in each prompt. Folder `assets/art/terrain/`.

| file | prompt (after STYLE) |
|---|---|
| `grass.png` | lush tropical meadow grass seen from directly above, short blades and clover, mix of yellow-green and emerald, subtle darker patches |
| `forest_floor.png` | dense jungle canopy seen from directly above, overlapping rounded leaf clusters in deep emerald and teal with small yellow-green highlights |
| `sand_dry.png` | warm pale beach sand seen from directly above, fine grain, a few tiny shells and pebbles, gentle wind ripples |
| `sand_wet.png` | wet darker beach sand seen from directly above, glossy damp sheen, tiny water rivulets |
| `rock_cliff.png` | weathered sandstone cliff face seen from above, vertical strata layers in tan, ochre and grey-brown, cracks and chipped edges |
| `rock_top.png` | rough grey volcanic rock seen from above, lichen patches, cracks, a little moss |
| `earth_dry.png` | dry cracked orange-brown earth with sparse tufts of dry grass, seen from above |

## 2. Water textures (tileable, 1024x1024, greyscale or white-on-black)

Folder `assets/art/water/`. "Seamless tileable, top-down, no colour".

| file | prompt |
|---|---|
| `foam.png` | white sea foam bubbles and lace pattern on black, soft irregular streaks, high contrast, greyscale |
| `caustics.png` | bright underwater sunlight caustic network lines on black, thin glowing web pattern, greyscale |
| `wave_normal.png` | small ocean ripples as a tangent-space normal map (blue-purple), choppy but gentle, seamless |
| `seabed_sand.png` | sandy sea floor seen through clear shallow water, soft ripples, pale yellow-turquoise, no foam |
| `reef.png` | coral reef and seagrass seen from above through clear turquoise water, dark teal and green patches over pale sand |

## 3. Vegetation sprites (transparent PNG, 512x512 each, 3/4 top-down view)

Folder `assets/art/props/`. Each tree seen from above and slightly from the
front, with its own soft shadow ellipse offset to the lower left baked **not** in
(shadow handled in engine). Isolated.

| file | prompt |
|---|---|
| `tree_broadleaf_a.png` | single round tropical broadleaf tree, big layered canopy of overlapping leaf clusters, emerald with sunlit yellow-green tops, short brown trunk barely visible |
| `tree_broadleaf_b.png` | same species, different shape, wider and flatter canopy |
| `tree_pine_a.png` | single tall conifer seen from above and a little from the front, layered drooping branches, deep blue-green with lighter tips |
| `palm_a.png` | single coconut palm seen from above, long curved fronds radiating, bright green with yellow midribs, a few coconuts |
| `palm_b.png` | second palm, fronds drooping more, one leaning |
| `bush_a.png` | small flowering shrub, dark green with tiny red and white flowers |
| `rock_a.png` | one chunky grey-brown boulder with moss on top |
| `rock_b.png` | cluster of three smaller boulders |
| `rock_spire.png` | tall jagged sea stack rock, sandstone strata, white guano streaks |
| `driftwood.png` | bleached driftwood log with roots, on sand |

## 4. Ship (the hero asset). Folder `assets/art/ship/`

Painted parts, all seen from above-and-slightly-behind, bow pointing **up**.
Canvas 1024x2048, transparent, ship centred. The ship hull is about 560 px wide
and 1500 px long.

| file | prompt |
|---|---|
| `hull.png` | wooden pirate sloop hull only, no sails, no masts, seen from above, curved planked sides in honey-brown with a red stripe along the gunwale, pointed bow with bowsprit, stern cabin with small lit windows, deck planks visible, barrels and hatch and wheel on deck, cannons poking over the rail, bow pointing up |
| `hull_dark.png` | identical hull layout, darker aged wood with pitch-black stripe, for the "ghost" variant |
| `sail_main.png` | one large billowing cream canvas gaff sail seen from above, swelling to the right, stitched seams, slightly grubby, wooden boom along the bottom edge, transparent background |
| `sail_fore.png` | smaller billowing cream sail, same style, swelling to the right |
| `sail_jib.png` | small triangular jib sail, swelling right |
| `flag_jolly.png` | black pirate flag with a white skull and crossed bones, flying and rippling to the left |
| `wheel_detail.png` | brass-and-wood ship wheel seen from above |
| `crowsnest.png` | wooden crow's nest platform seen from above with rope rigging lines |

Livery variants (later): repeat `hull.png` with a blue stripe, a gold stripe, a
black-and-white checker stripe.

## 5. Points of interest sprites (transparent, 1024x1024, top-down 3/4)

Folder `assets/art/poi/`. These sit on islands and are lit from the upper right.

| file | prompt |
|---|---|
| `village.png` | small tropical pirate harbour village seen from above, six timber houses with terracotta and teal roofs, wooden pier extending down into the sea with a moored rowboat, lanterns, fishing nets drying, palm trees |
| `lighthouse.png` | white-and-red striped stone lighthouse on a rocky islet seen from above and slightly front, lantern room glowing |
| `treasure.png` | sandy islet with three palms and a big red X marked in the sand, a half-dug hole with a chest and a spade |
| `skull_rock.png` | huge rock formation naturally shaped like a skull with dark eye caves and a jaw of teeth, sea foam at its base |
| `wreck.png` | sunken wooden galleon wreck, broken ribs and snapped mast poking out of shallow turquoise water, torn sail, barnacles |
| `whirlpool.png` | powerful ocean whirlpool seen from above, spiralling dark blue arms with white foam streaks, black eye |
| `bottle.png` | message in a bottle floating, green glass, cork, rolled parchment inside, ripples |
| `wisps.png` | three pale blue-cyan ghost lights hovering above dark water, soft glow, faint trails |

## 6. UI kit (transparent PNG). Folder `assets/art/ui/`

Match the reference UI: dark glass chips, aged parchment, brass rims.

| file | size | prompt |
|---|---|---|
| `panel_parchment.png` | 1024x1024, 9-slice friendly | aged cream parchment panel with torn darker edges and a thin brown ink border, empty centre |
| `chip_glass.png` | 600x160 | dark navy translucent rounded rectangle with a thin silver-grey rim and soft highlight on the top edge, empty |
| `button_primary.png` | 800x200 | polished brass-gold rounded button with a darker bevel and soft highlight, empty |
| `button_wood.png` | 800x200 | carved dark wood rounded button with a brass rim, empty |
| `compass_rose.png` | 1024x1024 | ornate hand-inked compass rose in brown ink on transparent background |
| `icon_set.png` | 2048x1024 | sheet of 16 flat hand-painted icons in a 4x4 grid: coin, binoculars, scroll, anchor, ship wheel, sword, shield, heart, cannonball, hammer, sail, barrel, chest, map, lantern, spyglass |

## 7. Event and encounter illustrations. Folder `assets/art/events/`

Portrait 1080x1350, painted illustration (these are the "stills you provide"; I
build the screens around them). Same STYLE block plus "digital painting
illustration, cinematic framing". Examples to start: `ev_merchant.png`,
`ev_fog_ship.png`, `ev_ghost_lights.png`, `ev_sea_serpent.png`, `ev_harbour_tavern.png`.

## 8. Title key art. `assets/art/title_bg.png`

1080x1920 portrait. "Cinematic key art: a pirate sloop with cream sails
cutting through turquoise water at golden hour, tropical islands in the
distance, dramatic clouds, painted style" plus STYLE. Leave the upper third
calm (the logo sits there) and the lower third darker (buttons sit there). When
this file exists the title screen uses it instead of the live sea.

## 9. How I wire them in (what changes when files appear)

| assets present | effect |
|---|---|
| `terrain/*` | terrain shader samples them in place of procedural noise textures (cliffs, sand, grass, forest) |
| `water/*` | water shader uses the foam, caustics, normal and seabed textures |
| `props/*` | trees and rocks become instanced painted cards (camera-facing, with baked-in lighting) in addition to or instead of the 3D meshes |
| `ship/*` | ship uses the painted hull plus layered sail sprites on top of the 3D motion (bob, heel, billow) |
| `poi/*` | each point of interest is drawn from its sprite with the existing animation on top |
| `ui/*` | HUD and menus switch from code-drawn shapes to 9-slice painted frames |
| `title_bg.png` | already supported |

You can supply them in any order. Each folder works on its own.
