extends RefCounted
## Campaign missions and tactical challenges.
##
## Map legend (one character per tile):
##   .  grass        ,  road         T  forest (+1 DEF, cost 2)   %  mud (cost 2)
##   #  wall         H  pillar       ~  water (impassable, see-through)
##   =  bridge       ^  hill (+1 range, cost 2)   x  thorns (3 dmg at turn start)
##   C  cage with a captive (order = "captives" list, reading order)
##   E  extraction tile   D  defend tile   $  treasure   R  relic altar
##   1-4  hero deployment slots   V  escort (Elder)   W  Moonwell
##   r recruit  g guard  a archer  m mage  s stalker  I Ironpaw  K Pale King  Y pylon
##   other letters: see "named" (named commanders)
##
## objective types: eliminate, defend, survive, escape, rescue_escape, escort,
##   protect, commander, claim, boss
## optional types: turns, no_ko, treasure, free_all, kill_tag, kill_kind, hp_tag, kill_all

const ACTS := {
	1: {"name": "Act I - Shadowwood Valley",
		"intro": "The White Crown Legion has crossed into peaceful Shadowwood Valley. Nox, Bramble and Willow are all that stand between the invaders and the village of Mosswell."},
	2: {"name": "Act II - The Broken Border",
		"intro": "The Legion's scouts are routed, but the border wall has fallen. Captured friends are held in the old keeps. Time to take the fight to them."},
	3: {"name": "Act III - The White Crown War",
		"intro": "With the Ironpaw Commander beaten, only the Pale King remains, hiding behind his Crown Pylons with the stolen relics. One last push."},
}

const MISSIONS := [
	{
		"id": "m01", "act": 1, "region": "wood", "music": "act1", "slots": 3, "shards": 3,
		"name": "Whiskers in the Woods",
		"brief": "Three White Recruits are trampling the berry bushes. Show them the way home. Click a hero, click a blue tile to move, then click a red-marked enemy twice to attack.",
		"win_text": "The recruits flee, dropping a very confused map. The Legion is bigger than anyone thought...",
		"objective": {"type": "eliminate", "text": "Defeat all enemies"},
		"optional": [
			{"type": "turns", "turns": 5, "shards": 1, "text": "Win within 5 turns"},
			{"type": "no_ko", "shards": 1, "text": "No hero knocked out"},
		],
		"alert": 0,
		"hints": ["Move first, then act. A unit that has acted is greyed out.", "Melee attacks get +2 when another ally is next to the target (flanking)."],
		"map": [
			"TT....T.....TT",
			"T..........r.T",
			"..1..T..T.....",
			".......TT..r..",
			".2..,,,,,,,,..",
			".......T......",
			"..3..T....r...",
			"T.........T..T",
			"TT...TT......T",
		],
	},
	{
		"id": "m02", "act": 1, "region": "wood", "music": "act1", "slots": 3, "shards": 3,
		"name": "Mill Bridge Skirmish",
		"brief": "The Legion holds the mill bridges. White Guards make nearby allies tougher (Shield Wall) - try to break them first, or slip past with Shadow Pounce.",
		"win_text": "The bridges are ours again. The miller offers fish. Bramble accepts on everyone's behalf.",
		"objective": {"type": "eliminate", "text": "Defeat all enemies"},
		"optional": [
			{"type": "turns", "turns": 8, "shards": 1, "text": "Win within 8 turns"},
			{"type": "treasure", "shards": 2, "text": "Grab the fish crate ($)"},
		],
		"alert": 6,
		"hints": ["Forest tiles give +1 DEF but cost 2 movement.", "Rangers cannot shoot adjacent enemies - keep them behind the line."],
		"map": [
			"TT......~~......",
			"T.1.....~~...r..",
			"..T..T..==..g...",
			".2......~~....r.",
			"...,,,,,==,,,,..",
			".3.T....~~..T...",
			"..T.....~~...g..",
			"T.......~~....r.",
			"TT..T...~~..T.$.",
			"TTT.....~~.....T",
		],
	},
	{
		"id": "m03", "act": 1, "region": "wood", "music": "act1", "slots": 3, "shards": 3,
		"name": "Rescue at Mosswell",
		"brief": "Moss the herbalist is caged in the Legion camp. Stand next to her cage and use Free, then bring her back to the exit (E tiles). Two kittens are caged too.",
		"win_text": "Moss is safe and already scolding everyone about bandages. She joins the squad as a Mender!",
		"objective": {"type": "rescue_escape", "tag": "moss", "text": "Free Moss and bring her to an exit tile (E)"},
		"optional": [
			{"type": "free_all", "shards": 2, "text": "Free both kittens"},
			{"type": "no_ko", "shards": 1, "text": "No hero knocked out"},
		],
		"captives": ["kitten", "moss", "kitten"],
		"alert": 5,
		"hints": ["Free: stand next to a cage and press the Free button.", "Escape: a unit standing on an E tile can use Escape."],
		"map": [
			"TT..........TT.T",
			"EE.T.....T...r..",
			"E1....TT.....C..",
			".2..T.....g.....",
			".3.....%%...rC..",
			".......%%.......",
			"..T..T.......T..",
			"....TT..r...C...",
			".T.......r....T.",
			"TT...........TTT",
		],
	},
	{
		"id": "m04", "act": 1, "region": "wood", "music": "act1", "slots": 3, "shards": 4,
		"name": "Shadowwood Shrine",
		"brief": "Archers lead an assault on the old shrine. Hold it: no enemy may stand on a shrine tile (D) at the end of their turn. Survive 6 turns.",
		"win_text": "The shrine stands, and the lanterns light themselves. Somewhere, a very old cat smiles.",
		"objective": {"type": "defend", "turns": 6, "text": "Keep enemies off the shrine (D) for 6 turns"},
		"optional": [
			{"type": "kill_all", "shards": 1, "text": "Defeat every enemy"},
			{"type": "no_ko", "shards": 1, "text": "No hero knocked out"},
		],
		"alert": 0,
		"hints": ["Archers need line of sight - walls and pillars block it, forests do not.", "Press T to show every tile enemies can attack next turn."],
		"reinforcements": [
			{"turn": 2, "units": [["r", 16, 4], ["r", 16, 5]]},
			{"turn": 4, "units": [["r", 16, 2], ["a", 16, 7], ["r", 15, 8]]},
		],
		"map": [
			"TTT....T....TTTTT",
			"T......T.......aT",
			"..1.....^......r.",
			".......TT.......r",
			".2..DD.....T....g",
			"....DD...........",
			".3......TT......a",
			".......^......r..",
			"T......T........T",
			"TTT....T....TTTTT",
		],
	},
	{
		"id": "m05", "act": 2, "region": "border", "music": "act2", "slots": 4, "shards": 4,
		"name": "Over the Border Wall",
		"brief": "The wall is crawling with White Stalkers - fast cats that hunt anyone left alone. Cross the wall and get every hero out through the exits (E). Keep the squad together!",
		"win_text": "Over the wall and into the Broken Border. The Stalkers are left sniffing an empty field.",
		"objective": {"type": "escape", "text": "Every hero on the field must Escape on an E tile"},
		"turn_limit": 12,
		"optional": [
			{"type": "turns", "turns": 9, "shards": 1, "text": "Escape within 9 turns"},
			{"type": "no_ko", "shards": 2, "text": "No hero knocked out"},
		],
		"alert": 7,
		"hints": ["Stalkers get +2 damage against heroes with no ally next to them."],
		"reinforcements": [
			{"turn": 3, "units": [["r", 16, 0], ["r", 16, 11]]},
			{"turn": 6, "units": [["s", 16, 11], ["a", 17, 6]]},
		],
		"map": [
			"..T......#....T..E",
			"1.....T..#.......E",
			"..T......#..s....E",
			"2...%%...,....T...",
			"....%%...#......s.",
			"3.T......#...T....",
			".....T...#.r......",
			"4....^...,........",
			"..T......#..a..T.E",
			".....T...#.......E",
			"..T....r.#..s....E",
			"T........#.......T",
		],
	},
	{
		"id": "m06", "act": 2, "region": "border", "music": "boss", "slots": 4, "shards": 5,
		"name": "Ironpaw's Bastion",
		"brief": "BOSS: The Ironpaw Commander. He marks 3 tiles before his Crushing Blow lands next turn - step out of the marked tiles! After the blow he is Exhausted (DEF 0). Flank him.",
		"win_text": "The Ironpaw Commander is down! In his dungeon you find Soot, a Shadowblade, who joins the squad.",
		"objective": {"type": "boss", "tag": "ironpaw", "text": "Defeat the Ironpaw Commander"},
		"optional": [
			{"type": "turns", "turns": 10, "shards": 2, "text": "Win within 10 turns"},
			{"type": "no_ko", "shards": 2, "text": "No hero knocked out"},
		],
		"alert": 0,
		"hints": ["Hatched orange tiles = an attack landing at the start of the enemy turn."],
		"boss_tag": "ironpaw",
		"map": [
			"HHHH........HHHH",
			"H....a....a....H",
			"H..H........H..H",
			"H......I.......H",
			"H..g........g..H",
			"H....H....H....H",
			"H..............H",
			"H..T..r..r..T..H",
			"H..............H",
			"H....1.2.3.4...H",
			"H..T........T..H",
			"HHHH........HHHH",
		],
	},
	{
		"id": "m07", "act": 2, "region": "border", "music": "act2", "slots": 4, "shards": 4,
		"name": "The Moonwell",
		"brief": "White Mages want to freeze the Moonwell solid. Protect it (W) for 7 turns. Mages heal their friends and chill heroes (-2 MOV) - deal with them early.",
		"win_text": "The Moonwell sparkles on. Every hero feels a little bit braver - and much more hydrated.",
		"objective": {"type": "protect", "tag": "moonwell", "turns": 7, "text": "Protect the Moonwell for 7 turns"},
		"optional": [
			{"type": "kill_kind", "kind": "mage", "shards": 1, "text": "Defeat both White Mages"},
			{"type": "hp_tag", "tag": "moonwell", "ratio": 0.5, "shards": 2, "text": "Moonwell above half health"},
		],
		"alert": 0,
		"reinforcements": [
			{"turn": 3, "units": [["s", 2, 11], ["s", 15, 11]]},
			{"turn": 5, "units": [["r", 1, 0]]},
		],
		"map": [
			".r......TT......a.",
			"....T.........T...",
			"..T....,,,,....T.r",
			".......,..,.......",
			"m...1..,..,..2...m",
			".......,.W,.......",
			"..T....,..,....T..",
			"...3...,,,,..4....",
			".T..............T.",
			"....T...TT...T....",
			".r.....T..T.....r.",
			"..................",
		],
	},
	{
		"id": "m08", "act": 2, "region": "border", "music": "act2", "slots": 4, "shards": 5,
		"name": "The Border Keep",
		"brief": "Captain Snowcap runs this keep and its prison. Defeat him. Prisoners are locked in three cells - free them if you can.",
		"win_text": "Captain Snowcap surrenders his very fancy hat. Pepper the Ranger walks out of her cell and joins you.",
		"objective": {"type": "commander", "tag": "captain", "text": "Defeat Captain Snowcap"},
		"optional": [
			{"type": "free_all", "shards": 2, "text": "Free all three prisoners"},
			{"type": "turns", "turns": 12, "shards": 1, "text": "Win within 12 turns"},
		],
		"captives": ["kitten", "pepper", "kitten"],
		"named": {"c": {"kind": "guard", "name": "Captain Snowcap", "tag": "captain", "hp": 12, "atk": 1, "commander": true}},
		"alert": 5,
		"map": [
			"##################",
			"#1.....#....C#...#",
			"#2.....#.g...#.a.#",
			"#3.....,.....,...#",
			"#4.....#..m..#...#",
			"###,####.....##,##",
			"#.....r#..c..#...#",
			"#.C....#.....,..C#",
			"#......,..g..#...#",
			"#..r...#.....#.r.#",
			"#......#..a..#...#",
			"##################",
		],
	},
	{
		"id": "m09", "act": 3, "region": "crown", "music": "act3", "slots": 4, "shards": 5,
		"name": "The Burning Orchard",
		"brief": "The Legion set the orchard ablaze and sends wave after wave. Survive until the end of turn 7. Ember tiles (thorns) hurt anyone standing on them when their turn starts.",
		"win_text": "The rain arrives just in time, and so does the Legion's retreat. The orchard will grow back.",
		"objective": {"type": "survive", "turns": 7, "text": "Survive 7 turns"},
		"optional": [
			{"type": "kill_all", "shards": 2, "text": "Defeat every enemy"},
			{"type": "no_ko", "shards": 2, "text": "No hero knocked out"},
		],
		"alert": 0,
		"reinforcements": [
			{"turn": 1, "units": [["r", 0, 3], ["r", 17, 3]]},
			{"turn": 3, "units": [["s", 0, 10], ["a", 17, 10], ["r", 9, 11]]},
			{"turn": 5, "units": [["g", 0, 1], ["m", 17, 1], ["s", 8, 0]]},
		],
		"map": [
			"T.x...T...T...x..T",
			"..T.....x.....T...",
			"x....T.....T....x.",
			"...T...1..2...T...",
			".T.....,,,,.....T.",
			"..x....,..,....x..",
			"....T..3..4..T....",
			".T..............T.",
			"...x...T..T...x...",
			"T.....x....x.....T",
			"..T....a.......T..",
			"x...T...TT...T...x",
		],
	},
	{
		"id": "m10", "act": 3, "region": "crown", "music": "act3", "slots": 4, "shards": 5,
		"name": "The Elder's Escape",
		"brief": "Elder Whiskerton knows the secret way into the Pale Citadel. Escort him (V) across the frozen moat to an exit (E). He cannot fight - if he falls, the mission fails.",
		"win_text": "Elder Whiskerton reaches the tunnel, wheezing triumphantly. 'Follow me, youngsters. Mind the icicles.'",
		"objective": {"type": "escort", "tag": "elder", "text": "Bring Elder Whiskerton to an exit tile (E)"},
		"turn_limit": 15,
		"optional": [
			{"type": "turns", "turns": 11, "shards": 2, "text": "Escape within 11 turns"},
			{"type": "no_ko", "shards": 1, "text": "No hero knocked out"},
		],
		"alert": 0,
		"reinforcements": [
			{"turn": 5, "units": [["s", 17, 11]]},
			{"turn": 8, "units": [["r", 17, 0], ["a", 16, 0]]},
		],
		"map": [
			"1V......~~^....a..",
			"2.....T.~~..T.....",
			"3..T....~~...g...E",
			"4.......==.......E",
			"....T...~~..T....E",
			"..^.....~~..s.....",
			"...r....~~....T...",
			".T......==......^.",
			"....r...~~........",
			"..T.....~~..T..m..",
			"........~~........",
			"T.......~~.......T",
		],
	},
	{
		"id": "m11", "act": 3, "region": "crown", "music": "act3", "slots": 4, "shards": 5,
		"name": "The Pale Gate",
		"brief": "Three stolen Crown Relics sit on altars around the Pale Gate. Stand on each altar (R) and use Claim. Marshal Frostfang, an elite Stalker, prowls the courtyard.",
		"win_text": "All three relics recovered! Their glow reveals the way to the throne room.",
		"objective": {"type": "claim", "text": "Claim all three relics (R)"},
		"turn_limit": 18,
		"optional": [
			{"type": "kill_tag", "tag": "marshal", "shards": 2, "text": "Defeat Marshal Frostfang"},
			{"type": "no_ko", "shards": 1, "text": "No hero knocked out"},
		],
		"named": {"c": {"kind": "stalker", "name": "Marshal Frostfang", "tag": "marshal", "hp": 8, "atk": 1, "commander": true}},
		"alert": 6,
		"reinforcements": [
			{"turn": 4, "units": [["r", 17, 3], ["r", 17, 9]]},
			{"turn": 7, "units": [["s", 17, 5], ["a", 17, 1]]},
		],
		"map": [
			".....#....#....R..",
			".....#.a..#.......",
			".....H....H...g...",
			"..T......c........",
			".....H....H....T..",
			"1....#....#.......",
			"2....,....,...s...",
			"3....#....#.......",
			"4....H....H.....a.",
			"..T..........T....",
			".....#.mR.#.......",
			".....#....#.....R.",
		],
	},
	{
		"id": "m12", "act": 3, "region": "crown", "music": "final", "slots": 4, "shards": 6,
		"name": "The Pale Throne",
		"brief": "FINAL BOSS: The Pale King. While his two Crown Pylons stand he cannot be hurt - smash them. He fires the Royal Lance down a marked row or column, and at half health he leaves the throne. Read the marked tiles!",
		"win_text": "The Pale King topples off his throne - and his crown rolls away. Shadowwood Valley is free!",
		"objective": {"type": "boss", "tag": "king", "text": "Defeat the Pale King"},
		"optional": [
			{"type": "turns", "turns": 14, "shards": 2, "text": "Win within 14 turns"},
			{"type": "no_ko", "shards": 2, "text": "No hero knocked out"},
		],
		"alert": 0,
		"boss_tag": "king",
		"map": [
			"HHH....HH....HHH",
			"H..Y..g..g..Y..H",
			"H......K.......H",
			"H..H........H..H",
			"H....a....a....H",
			"H..............H",
			"H.H..T....T..H.H",
			"H..............H",
			"H.....r..r.....H",
			"H..............H",
			"H...1..2..3..4.H",
			"HHH..........HHH",
		],
	},
]

## Tactical challenges: fixed squads (roster upgrades do not apply).
const CHALLENGES := [
	{
		"id": "c1", "act": 1, "region": "wood", "music": "act2", "unlock": "m04", "challenge": true,
		"name": "Challenge: Bridge of Fools",
		"brief": "Bramble and Willow versus six over-eager recruits. Win within 8 turns - use the bridges as choke points.",
		"win_text": "Six recruits, two bridges, zero chance.",
		"squad": [["bramble", 3], ["willow", 3]],
		"objective": {"type": "eliminate", "text": "Defeat all enemies"},
		"turn_limit": 8,
		"optional": [{"type": "no_ko", "text": "No hero knocked out"}],
		"alert": 0,
		"map": [
			"TT....~~~~....TT",
			"T.....~~~~..r..T",
			"..1...====....r.",
			"......~~~~.r...r",
			"..2...====....r.",
			"T.....~~~~..r..T",
			"TT....~~~~....TT",
		],
	},
	{
		"id": "c2", "act": 2, "region": "border", "music": "act3", "unlock": "m08", "challenge": true,
		"name": "Challenge: Night of Stalkers",
		"brief": "Stalkers hunt in the dark. Nox, Bramble and Moss must survive 6 turns. Never leave anyone alone.",
		"win_text": "Dawn breaks. The Stalkers slink away, defeated by basic teamwork.",
		"squad": [["nox", 4], ["bramble", 4], ["moss", 4]],
		"objective": {"type": "survive", "turns": 6, "text": "Survive 6 turns"},
		"optional": [{"type": "no_ko", "text": "No hero knocked out"}],
		"alert": 0,
		"reinforcements": [
			{"turn": 2, "units": [["s", 0, 6]]},
			{"turn": 4, "units": [["s", 11, 6]]},
		],
		"map": [
			"T..T....T..T",
			"..s......s..",
			"T....TT....T",
			"...1.TT.2...",
			"T....,,3...T",
			"..T......T..",
			"T..........T",
		],
	},
	{
		"id": "c3", "act": 3, "region": "crown", "music": "boss", "unlock": "m12", "challenge": true,
		"name": "Challenge: Iron Rematch",
		"brief": "Ironpaw is back with friends. Nox, Bramble and Willow, no upgrades. Defeat him within 12 turns.",
		"win_text": "Ironpaw retires to a quiet life of competitive napping.",
		"squad": [["nox", 4], ["bramble", 4], ["willow", 4]],
		"objective": {"type": "boss", "tag": "ironpaw", "text": "Defeat the Ironpaw Commander"},
		"turn_limit": 12,
		"optional": [{"type": "no_ko", "text": "No hero knocked out"}],
		"alert": 0,
		"boss_tag": "ironpaw",
		"map": [
			"HHH........HHH",
			"H...a....a...H",
			"H.H...I....H.H",
			"H...g....g...H",
			"H....H..H....H",
			"H............H",
			"H..T......T..H",
			"H...1..2..3..H",
			"H............H",
			"HHH........HHH",
		],
	},
]


static func get_mission(id: String) -> Dictionary:
	for m: Dictionary in MISSIONS:
		if m["id"] == id:
			return m
	for c: Dictionary in CHALLENGES:
		if c["id"] == id:
			return c
	return {}


static func mission_ids() -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in MISSIONS:
		out.append(m["id"])
	return out


static func challenge_ids() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in CHALLENGES:
		out.append(c["id"])
	return out


static func index_of(id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i]["id"] == id:
			return i
	return -1
