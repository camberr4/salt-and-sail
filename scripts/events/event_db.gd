class_name EventDb
extends RefCounted
## Text encounters with choices. Data only, so new events are one dictionary.
##
## Event:   id, art (file under assets/art/events/), tone (placeholder look),
##          title, text, where (["sea"] or POI kinds), needs (optional
##          conditions: weather states, "night"), weight, choices[]
## Choice:  label, hint (optional), outcomes[] (weighted)
## Outcome: weight, text, gold (+/-), rumor (bool), reveal (px radius around
##          the ship), weather (Weather.State), flare (bool)

const W := Weather.State

static var ALL: Array[Dictionary] = [
	{
		"id": "merchant", "art": "ev_merchant", "tone": "sea", "where": ["sea"], "weight": 1.2,
		"title": "A Merchant Hails You",
		"text": "A fat-bellied trading sloop rides low in the water, her captain waving a spyglass and a ledger. \"Fair winds, friend! I have charts to sell, and news, and very little patience.\"",
		"choices": [
			{"label": "Buy a chart (40 gold)", "hint": "Reveals the sea around you", "cost": 40, "outcomes": [
				{"weight": 1.0, "text": "The captain unrolls a crisp chart and you copy the coastlines in lamplight. The fog of the unknown thins.", "gold": -40, "reveal": 2600}]},
			{"label": "Trade news", "outcomes": [
				{"weight": 1.0, "text": "You swap stories over the rail. He tells you of a place worth a look.", "rumor": true}]},
			{"label": "Wave and sail on", "outcomes": [
				{"weight": 1.0, "text": "You tip your hat. The sloop shrinks behind you."}]},
		],
	},
	{
		"id": "fog_ship", "art": "ev_fog_ship", "tone": "fog", "where": ["sea"], "needs": {"weather": [W.FOG]}, "weight": 2.5,
		"title": "A Ship in the Fog",
		"text": "A tall hull slides out of the mist, silent, no lanterns, sails hanging like wet laundry. No one answers your hail. Something gleams on her deck.",
		"choices": [
			{"label": "Board her", "hint": "Risky", "outcomes": [
				{"weight": 0.55, "text": "Empty decks, cold ashes, and a captain's strongbox bolted to the mast. It opens.", "gold": 180},
				{"weight": 0.45, "text": "The planks give way and something cold drags at your boots. You scramble back, lighter in the purse.", "gold": -60}]},
			{"label": "Fire a warning shot", "outcomes": [
				{"weight": 1.0, "text": "The echo rolls out into the white. Nothing answers. The ghost ship fades from view.", "gold": 0}]},
			{"label": "Turn away quietly", "outcomes": [
				{"weight": 1.0, "text": "You steer wide and do not look back. The fog closes behind you like a door."}]},
		],
	},
	{
		"id": "ghost_lights", "art": "ev_ghost_lights", "tone": "night", "where": ["sea"], "needs": {"night": true}, "weight": 2.5,
		"title": "Lights on the Water",
		"text": "Pale blue flames drift over the swell, bobbing like lanterns carried by the drowned. They seem to want you to follow.",
		"choices": [
			{"label": "Follow the lights", "outcomes": [
				{"weight": 0.6, "text": "They lead you to a drowned lantern heavy with old coins, then wink out.", "gold": 150},
				{"weight": 0.4, "text": "They lead you in circles until dawn threatens. A cold mist settles.", "weather": 1}]},
			{"label": "Keep your distance", "outcomes": [
				{"weight": 1.0, "text": "You hold your course. A lookout swears the lights bowed.", "rumor": true}]},
		],
	},
	{
		"id": "serpent", "art": "ev_sea_serpent", "tone": "storm", "where": ["sea"], "weight": 0.7,
		"title": "Something Beneath the Keel",
		"text": "A shadow longer than your ship slides under the hull. The water rises in a slow, ugly swell. Your crew goes very quiet.",
		"choices": [
			{"label": "Throw an offering (30 gold)", "cost": 30, "outcomes": [
				{"weight": 1.0, "text": "Coins spin down into the dark. The shadow lingers, considers, and leaves.", "gold": -30}]},
			{"label": "Race away", "outcomes": [
				{"weight": 0.7, "text": "You crowd on sail and the swell falls behind you. Nobody speaks for an hour."},
				{"weight": 0.3, "text": "A coil lashes the stern and tears away a locker of coin.", "gold": -60}]},
			{"label": "Reach for the harpoon", "hint": "Glory or ruin", "outcomes": [
				{"weight": 0.35, "text": "The iron bites. The serpent thrashes, sheds a handful of glittering scales, and vanishes. Worth a fortune.", "gold": 220},
				{"weight": 0.65, "text": "The harpoon bounces off. The serpent is not amused. Your purse is lighter and your ears are ringing.", "gold": -80}]},
		],
	},
	{
		"id": "castaway", "art": "ev_castaway", "tone": "sea", "where": ["sea"], "weight": 1.0,
		"title": "A Castaway",
		"text": "A sun-cracked sailor clings to a barrel and waves one arm. \"Water,\" he croaks. \"And a ride, if you've the heart.\"",
		"choices": [
			{"label": "Haul him aboard", "outcomes": [
				{"weight": 1.0, "text": "He drinks, weeps, and presses a salt-stiff purse into your hand. Then he tells you where he lost his ship.", "gold": 60, "rumor": true}]},
			{"label": "Toss him a waterskin", "outcomes": [
				{"weight": 1.0, "text": "He catches it and salutes you with the barrel. You sail on with a lighter conscience than purse.", "gold": -10}]},
			{"label": "Sail past", "outcomes": [
				{"weight": 1.0, "text": "The crew mutters. The wake does not forgive."}]},
		],
	},
	{
		"id": "crate", "art": "ev_crate", "tone": "gold", "where": ["sea"], "weight": 1.0,
		"title": "Floating Cargo",
		"text": "A sealed crate bobs in the swell, stamped with a merchant house you do not recognise. A dozen gulls are very interested.",
		"choices": [
			{"label": "Haul it aboard", "outcomes": [
				{"weight": 0.6, "text": "Bolts of silk and a tin of tea. The dockside will pay well.", "gold": 90},
				{"weight": 0.25, "text": "Rotten fish. The crew will not forgive you.", "gold": -15},
				{"weight": 0.15, "text": "False bottom! Beneath the fish lie gold ingots.", "gold": 200}]},
			{"label": "Leave it", "outcomes": [{"weight": 1.0, "text": "The gulls win. You sail on."}]},
		],
	},
	{
		"id": "dolphins", "art": "ev_dolphins", "tone": "sea", "where": ["sea"], "needs": {"weather": [W.CLEAR]}, "weight": 1.4,
		"title": "Dolphins at the Bow",
		"text": "A pod of dolphins races alongside, leaping in the bow wave as if showing off. The helmsman swears they are pointing somewhere.",
		"choices": [
			{"label": "Follow them", "outcomes": [
				{"weight": 1.0, "text": "They lead you across glittering shallows and bank away. From here, the horizon looks closer.", "reveal": 2200}]},
			{"label": "Enjoy the show", "outcomes": [
				{"weight": 1.0, "text": "For a moment, nobody thinks about gold at all."}]},
		],
	},
	{
		"id": "tavern", "art": "ev_harbour_tavern", "tone": "tavern", "where": ["village"], "weight": 3.0,
		"title": "The Salted Anchor",
		"text": "Smoke, fiddles, and the smell of fried fish. Every chair holds a story and most of them are for sale. A woman with a patch on each eye cleans a glass she cannot possibly see.",
		"choices": [
			{"label": "Buy a round (25 gold)", "cost": 25, "outcomes": [
				{"weight": 1.0, "text": "Tongues loosen with the second barrel. You walk out with two places to look.", "gold": -25, "rumor": true}]},
			{"label": "Gamble at dice", "hint": "Even odds", "outcomes": [
				{"weight": 0.5, "text": "Sixes! The room groans and pays up.", "gold": 70},
				{"weight": 0.5, "text": "The dice love someone else tonight.", "gold": -50}]},
			{"label": "Rest and resupply", "outcomes": [
				{"weight": 1.0, "text": "A bed, a hot meal, a quiet word from the harbourmaster about tomorrow's sky.", "gold": 0}]},
		],
	},
	{
		"id": "wreck_dive", "art": "ev_wreck_dive", "tone": "sea", "where": ["wreck"], "weight": 3.0,
		"title": "The Sunken Hull",
		"text": "Her ribs rise out of the shallows like a drowned whale. Something glints in the dark of the bilge, where the water turns from turquoise to ink.",
		"choices": [
			{"label": "Dive deep", "hint": "Greater prize, greater danger", "outcomes": [
				{"weight": 0.6, "text": "Your lungs burn, but you surface with a coffer of coin.", "gold": 160},
				{"weight": 0.4, "text": "An eel as long as a rope bites you for your trouble. You come up empty.", "gold": -40}]},
			{"label": "Quick salvage", "outcomes": [
				{"weight": 1.0, "text": "Brass fittings and a lantern, quick and safe.", "gold": 55}]},
		],
	},
	{
		"id": "bottle", "art": "ev_bottle", "tone": "gold", "where": ["bottle"], "weight": 3.0,
		"title": "Message in a Bottle",
		"text": "The cork is waxed, the note inside is half pulp. You can read a name, a coastline and one word underlined three times: DON'T.",
		"choices": [
			{"label": "Follow the note", "outcomes": [
				{"weight": 1.0, "text": "A rough sketch of a shore, and a small black cross. You mark it on the chart.", "gold": 20, "rumor": true}]},
			{"label": "Toss it back", "outcomes": [
				{"weight": 1.0, "text": "Some warnings are meant to be heeded. The bottle bobs away."}]},
		],
	},
	{
		"id": "skull", "art": "ev_skull", "tone": "night", "where": ["skull"], "weight": 3.0,
		"title": "The Skull's Grin",
		"text": "At low tide the jaw yawns open. Between the teeth, something yellow catches the light.",
		"choices": [
			{"label": "Reach between the teeth", "outcomes": [
				{"weight": 0.65, "text": "Your fingers close on a fistful of doubloons.", "gold": 220},
				{"weight": 0.35, "text": "The tide shifts and the teeth bite down on your sleeve and your purse.", "gold": -70}]},
			{"label": "Leave an offering (20 gold)", "cost": 20, "outcomes": [
				{"weight": 1.0, "text": "You drop coins into the eye socket. The rock seems to approve. A hidden ledge opens to a second cache.", "gold": 100}]},
		],
	},
	{
		"id": "wisps", "art": "ev_wisps", "tone": "night", "where": ["wisps"], "weight": 3.0,
		"title": "The Wisp Shoal",
		"text": "Cold blue lights circle your bow, then dive. In the shallows below, something huge and square-edged waits.",
		"choices": [
			{"label": "Dive after them", "outcomes": [
				{"weight": 0.7, "text": "A drowned lantern full of coins, still warm.", "gold": 210},
				{"weight": 0.3, "text": "The lights wink out. A cold current drags you back up empty-handed.", "gold": 0}]},
			{"label": "Say a quiet prayer", "outcomes": [
				{"weight": 1.0, "text": "The lights drift apart and leave a trail across the water to somewhere new.", "rumor": true}]},
		],
	},
]


## Picks a weighted, eligible event. `where` is "sea" or a POI kind.
static func pick(where: String, weather_state: int, night: float, rng: RandomNumberGenerator, recent: Array = []) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0.0
	for e in ALL:
		if not where in e["where"]:
			continue
		var needs: Dictionary = e.get("needs", {})
		if needs.has("weather") and not weather_state in needs["weather"]:
			continue
		if needs.get("night", false) and night < 0.5:
			continue
		var w: float = e.get("weight", 1.0)
		if e["id"] in recent:
			w *= 0.2
		pool.append(e)
		total += w
	if pool.is_empty():
		return {}
	var r := rng.randf() * total
	for e in pool:
		var w2: float = e.get("weight", 1.0) * (0.2 if e["id"] in recent else 1.0)
		r -= w2
		if r <= 0.0:
			return e
	return pool[0]


static func roll(choice: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var outs: Array = choice["outcomes"]
	var total := 0.0
	for o in outs:
		total += o.get("weight", 1.0)
	var r := rng.randf() * total
	for o in outs:
		r -= o.get("weight", 1.0)
		if r <= 0.0:
			return o
	return outs[0]
