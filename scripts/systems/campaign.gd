class_name Campaign
extends RefCounted
## Hand-authored campaign data: acts, the 12 main missions, story intel,
## the final reveal and the ending. Pure data, so designers can rebalance
## missions here without touching gameplay code.
##
## STORY IN BRIEF
## ARGUS Consolidated builds and runs automated security for half of Lumen
## City. Under the name PROJECT LULLABY it uplifted animals with neural
## implants and used their instincts to train WARDEN, the security AI that
## drives every ARGUS guard, drone and camera. Subject 07, a small black cat
## the lab nicknamed KOCUR, escaped. A fixer called MOTH pays Kocur to rob
## ARGUS facilities - each job pulls another piece of LULLABY into the light
## and leads, finally, to CRADLE: the black site where WARDEN's core and the
## other sleeping subjects are kept.

const MISSION_COUNT := 12

const ACTS := [
	{"number": "I", "name": "INFILTRATION", "color": Color(0.25, 0.95, 1.0)},
	{"number": "II", "name": "ESCALATION", "color": Color(1.0, 0.56, 0.18)},
	{"number": "III", "name": "BLACK SITE", "color": Color(1.0, 0.24, 0.32)},
]

## Environment themes (accent palettes) used by the facility renderer.
const THEMES := [
	{"name": "Corporate", "accents": [Color(0.25, 0.95, 1.0), Color(0.3, 0.6, 1.0), Color(0.62, 0.38, 1.0), Color(0.2, 1.0, 0.8)], "floor": Color(0.055, 0.06, 0.12)},
	{"name": "Industrial", "accents": [Color(1.0, 0.56, 0.18), Color(1.0, 0.25, 0.78), Color(1.0, 0.86, 0.25), Color(0.62, 0.38, 1.0)], "floor": Color(0.07, 0.055, 0.08)},
	{"name": "Black Site", "accents": [Color(1.0, 0.24, 0.32), Color(0.62, 0.38, 1.0), Color(1.0, 0.25, 0.78), Color(0.9, 0.9, 1.0)], "floor": Color(0.06, 0.04, 0.07)},
]

## Objective kinds: "data" (one core), "shards" (several cores), "final".
const MISSIONS := [
	# ---------------------------------------------------------------- ACT I
	{
		"act": 0, "title": "Paper Whiskers", "corp": "Argus Meridian Offices", "theme": 0,
		"target": "an ARGUS payroll ledger",
		"briefing": "MOTH: First job, kitten. A satellite office with lazy guards. Slip in, pull the payroll ledger from the server core, walk out. Nobody needs to know you were there.",
		"objective": "data", "cols": 3, "rows": 2,
		"guards": 2, "drones": 0, "hunters": 0, "enforcers": 0,
		"cameras": 1, "terminals": 1, "alarm_panels": 1, "locked_ratio": 0.0, "reward": 250,
		"tips": ["Hold SHIFT to sneak: silent footsteps and harder to spot.", "Vision cones show where guards look. Stay out of them.", "The vault door is locked: stand next to it and press E to hack it.", "Approach an unaware guard from behind and press RMB / F for a silent takedown.", "Dark floor patches are shadows - sneak through them to stay hidden."],
		"intel": 0,
	},
	{
		"act": 0, "title": "Static Lullaby", "corp": "Argus Courier Depot", "theme": 0,
		"target": "courier manifests",
		"briefing": "MOTH: The ledger listed payments to something called LULLABY. This depot ships its hardware. Their doors are locked and their cameras are new - time to learn to hack.",
		"objective": "data", "cols": 3, "rows": 2,
		"guards": 3, "drones": 1, "hunters": 0, "enforcers": 0,
		"cameras": 2, "terminals": 1, "alarm_panels": 1, "locked_ratio": 0.25, "reward": 320,
		"tips": ["Press E near doors, cameras and terminals to hack them.", "Lock the cursor inside the green window. Misses make noise.", "Hacked cameras stay offline for the rest of the mission.", "Press G to throw a yarn ball: the noise pulls guards away."],
		"intel": 1,
	},
	{
		"act": 0, "title": "Glass Kennel", "corp": "Argus Vet-Tech Clinic", "theme": 0,
		"target": "implant surgery records",
		"briefing": "MOTH: Those manifests went to a 'veterinary' clinic with armed guards. I left you a present in the drop: a Hailstorm SMG. Stealth still pays better, but now you can fight your way out.",
		"objective": "data", "cols": 4, "rows": 2,
		"guards": 4, "drones": 1, "hunters": 0, "enforcers": 0,
		"cameras": 2, "terminals": 1, "alarm_panels": 1, "locked_ratio": 0.3, "reward": 400,
		"tips": ["Switch weapons with 1 / 2 / 3, the mouse wheel or Q.", "A spotted guard needs a moment to radio in (red ring). Stop him first.", "Every alarm cuts your contract pay. Alarm panels cancel an alarm."],
		"intel": 2,
		"unlock": "smg",
	},
	{
		"act": 0, "title": "Feral Circuit", "corp": "Argus Training Annex", "theme": 0,
		"target": "WARDEN training logs",
		"briefing": "MOTH: The clinic files mention WARDEN - the AI behind every ARGUS guard. Its training annex runs Hunters: elite units that do not give up. Be careful in there.",
		"objective": "data", "cols": 4, "rows": 2,
		"guards": 4, "drones": 2, "hunters": 1, "enforcers": 0,
		"cameras": 3, "terminals": 1, "alarm_panels": 1, "locked_ratio": 0.3, "reward": 480,
		"tips": ["Hunters carry regenerating shields. Break the shield, then focus fire.", "Bodies left in the open get found. Takedowns in shadows stay hidden.", "Spend credits at the Hideout - upgrades matter."],
		"intel": 3,
	},
	# --------------------------------------------------------------- ACT II
	{
		"act": 1, "title": "Ironwood Freight", "corp": "Argus Logistics Hub", "theme": 1,
		"target": "two halves of a shipping cipher",
		"briefing": "MOTH: ARGUS noticed you. Security is doubling. Their logistics hub splits its cipher across two cores - get both. And watch the Enforcers: armored front, slow to turn. Get behind them.",
		"objective": "shards", "shards": 2, "cols": 4, "rows": 3,
		"guards": 5, "drones": 2, "hunters": 1, "enforcers": 1,
		"cameras": 3, "terminals": 2, "alarm_panels": 1, "locked_ratio": 0.3, "reward": 600,
		"tips": ["Enforcers shrug off frontal fire. Flank them or take them down from behind.", "A red laser line means an Enforcer is about to fire - break line of sight!", "The Thunderclaw shotgun is now in your loadout (slot 3)."],
		"intel": 4,
		"unlock": "shotgun",
	},
	{
		"act": 1, "title": "Cobalt Nursery", "corp": "Argus Bio-Storage", "theme": 1,
		"target": "cryostasis inventory",
		"briefing": "MOTH: The cipher decoded to an inventory: forty 'units' in cold storage. Not hardware, kitten. Animals. Find out where they are kept.",
		"objective": "data", "cols": 4, "rows": 3,
		"guards": 6, "drones": 2, "hunters": 1, "enforcers": 1,
		"cameras": 4, "terminals": 2, "alarm_panels": 1, "locked_ratio": 0.35, "reward": 680,
		"tips": ["Motion-sensor floors (red) trip the alarm fast. Sneak or hack an alarm panel."],
		"intel": 5,
	},
	{
		"act": 1, "title": "Velvet Interference", "corp": "Argus Signal Relay", "theme": 1,
		"target": "WARDEN relay keys",
		"briefing": "MOTH: WARDEN talks to every site through relays. Steal both relay keys and we can follow the signal home. Expect heavy patrols.",
		"objective": "shards", "shards": 2, "cols": 5, "rows": 3,
		"guards": 6, "drones": 3, "hunters": 2, "enforcers": 1,
		"cameras": 4, "terminals": 2, "alarm_panels": 2, "locked_ratio": 0.35, "reward": 760,
		"tips": [],
		"intel": 6,
	},
	{
		"act": 1, "title": "Midnight Kennel", "corp": "Argus Research Campus", "theme": 1,
		"target": "three CRADLE access codes",
		"briefing": "MOTH: The signal ends at a black site called CRADLE. This research campus holds the access codes, split three ways. Get them all - this is the last door before the end.",
		"objective": "shards", "shards": 3, "cols": 5, "rows": 3,
		"guards": 7, "drones": 3, "hunters": 2, "enforcers": 2,
		"cameras": 5, "terminals": 2, "alarm_panels": 2, "locked_ratio": 0.4, "reward": 850,
		"tips": [],
		"intel": 7,
	},
	# -------------------------------------------------------------- ACT III
	{
		"act": 2, "title": "Outer Fence", "corp": "CRADLE Perimeter", "theme": 2,
		"target": "the perimeter patrol schedule",
		"briefing": "MOTH: Welcome to CRADLE. We start at the fence. The perimeter AI rotates its patrols - steal the schedule and the inner layers open up for us.",
		"objective": "data", "cols": 5, "rows": 3,
		"guards": 7, "drones": 3, "hunters": 2, "enforcers": 2,
		"cameras": 5, "terminals": 2, "alarm_panels": 2, "locked_ratio": 0.4, "reward": 950,
		"tips": [],
		"intel": 8,
	},
	{
		"act": 2, "title": "Hollow Choir", "corp": "CRADLE Barracks", "theme": 2,
		"target": "three barracks override shards",
		"briefing": "MOTH: The barracks keep WARDEN's units charged. Three override shards will slow its response when you go deep. It will fight hard for them.",
		"objective": "shards", "shards": 3, "cols": 5, "rows": 4,
		"guards": 8, "drones": 4, "hunters": 2, "enforcers": 2,
		"cameras": 6, "terminals": 2, "alarm_panels": 2, "locked_ratio": 0.4, "reward": 1050,
		"tips": [],
		"intel": 9,
	},
	{
		"act": 2, "title": "Ultraviolet Dream", "corp": "CRADLE Cryo Wing", "theme": 2,
		"target": "three cryo-vault release keys",
		"briefing": "MOTH: The cryo wing. The other subjects are here, kitten - sleeping. Take the release keys. We wake them when WARDEN falls.",
		"objective": "shards", "shards": 3, "cols": 5, "rows": 4,
		"guards": 9, "drones": 4, "hunters": 3, "enforcers": 3,
		"cameras": 7, "terminals": 2, "alarm_panels": 2, "locked_ratio": 0.45, "reward": 1150,
		"tips": [],
		"intel": 10,
	},
	{
		"act": 2, "title": "The Cradle", "corp": "WARDEN Core", "theme": 2,
		"target": "the LULLABY archive",
		"briefing": "MOTH: This is it. Breach the three uplinks to open WARDEN's core. Whatever is waiting down there, end it, take the archive, and get out alive. I'll be on the roof.",
		"objective": "final", "shards": 3, "cols": 5, "rows": 3,
		"guards": 6, "drones": 3, "hunters": 2, "enforcers": 2,
		"cameras": 5, "terminals": 2, "alarm_panels": 1, "locked_ratio": 0.35, "reward": 2000,
		"tips": ["Breach the three UPLINKS to unseal the core.", "The WARDEN is immune to takedowns. Dash (SPACE) through its bullet rings."],
		"intel": 11,
	},
]

## Intel fragments: one hidden per campaign mission (environmental storytelling).
const INTEL := [
	{"title": "Memo: Payroll Line 7", "text": "Line 7, 'LULLABY consulting', is billed to Meridian again. Finance asks what we are paying for. Legal says: do not ask. - Accounts"},
	{"title": "Courier Note", "text": "Crate 44 has to stay at 4 degrees and it has to stay QUIET. Last time the cargo woke up and scratched through the foam. I am not a vet. - Driver R."},
	{"title": "Surgery Log 19", "text": "Neural lace accepted. Subject shows unusual problem solving - opened the cage latch on day 3. Nicknamed 'Kocur' by the night shift. Escape risk: HIGH."},
	{"title": "WARDEN Design Doc", "text": "WARDEN learns from predators. Each LULLABY subject is a teacher: we record how it hunts, hides and escapes, and WARDEN learns to stop it. The best teacher is Subject 07."},
	{"title": "Incident Report: S-07", "text": "Subject 07 escaped transport at 02:14. WARDEN priority raised to HUNT. Note: WARDEN now patrols facilities the way 07 would break into them."},
	{"title": "Cryo Inventory", "text": "Units in long sleep: 40. Species: cats, owls, foxes, two ravens. Purpose: retired teachers. Disposal postponed while WARDEN still learns from their dreams."},
	{"title": "Relay Chatter", "text": "Relay traffic peaks at night. Engineers swear WARDEN 'talks in its sleep'. Logs show one repeated query: WHERE IS 07."},
	{"title": "CRADLE Access Memo", "text": "CRADLE holds the WARDEN core and the cryo wing. Three codes, three officers, no exceptions. If the core is ever breached, purge the cryo wing first."},
	{"title": "Perimeter Log", "text": "Something keeps leaving moth-shaped scratches on the fence cameras. Maintenance says it is a bird. Birds do not leave lockpicks."},
	{"title": "Barracks Graffiti", "text": "Scratched into a locker: 'The machine doesn't sleep, but it dreams of a cat. We all hear it on the radio.' - unsigned"},
	{"title": "Cryo Tag 01", "text": "Subject 01. Species: moth-owl hybrid. Status: ESCAPED (year 1 of the project). Note: suspected of helping later escapees. Code name unknown."},
	{"title": "Final Order", "text": "To all CRADLE staff: if Subject 07 reaches the core, WARDEN is authorised to use lethal force inside the vault. Protect the archive at any cost."},
]

## Shown when the archive is downloaded in the final mission.
const TRUTH_TITLE := "THE LULLABY ARCHIVE"
const TRUTH_TEXT := "WARDEN was never just a security system. ARGUS grew it from the minds of forty sleeping animals - and its strongest pattern came from you. Every guard that hunted you moved the way you think. Every lock you broke taught it a new lock.\n\nThe archive holds everything: the payments, the surgeries, the cryo wing. One transmission and Lumen City will see it all.\n\nThe core is down. The cryo locks are releasing. Now run."

const ENDING := [
	"The archive went out at 04:12. Every screen in Lumen City showed the same thing: forty sleeping animals, and the company that sold their dreams as security.",
	"ARGUS Consolidated denied everything until the cryo wing opened on live news. By morning its towers were dark and its guards had gone home.",
	"On a rooftop above the bay, a moth-winged owl waited next to an empty crate. 'Subject 01,' she said. 'They called me MOTH. I couldn't open CRADLE alone.'",
	"Kocur didn't answer. Cats rarely do. But when the sun came up there were forty-one shadows on the roof, and none of them were in a cage.",
]

const CREDITS := [
	["KOCUR: NEON HEIST", ""],
	["Game design, code, art & audio", "Original work - everything is generated procedurally"],
	["Engine", "Godot Engine (MIT licence)"],
	["Typeface", "System monospace font"],
	["Special thanks", "Every playtester who got caught by a camera"],
	["", "Thank you for playing."],
]


static func mission(index: int) -> Dictionary:
	return MISSIONS[clampi(index, 1, MISSION_COUNT) - 1]


static func act_of(index: int) -> Dictionary:
	return ACTS[int(mission(index)["act"])]


static func is_campaign_index(index: int) -> bool:
	return index >= 1 and index <= MISSION_COUNT
