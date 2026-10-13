class_name Levels
extends RefCounted
## Handcrafted campaign. Each level: name, hint (shown before play), rows. Pars come from data/pars.json (solver output).

const REGIONS := [
	{"name": "Sunny Garden", "key": "garden"},
	{"name": "Moonlit Ruins", "key": "ruins"},
	{"name": "Frozen Fishpond", "key": "ice"},
	{"name": "Crystal Catacombs", "key": "crystal"},
	{"name": "Purrfect Temple", "key": "temple"},
]

const LIST := [
	# ---------------- Sunny Garden ----------------
	{"name": "First Steps", "region": 0, "hint": "Move with WASD or the arrow keys. Reach the glowing exit and grab the fish!", "rows": [
		"########",
		"#@..f..#",
		"#.####.#",
		"#f....E#",
		"########"]},
	{"name": "Push It", "region": 0, "hint": "Push the crate onto the paw target. The exit opens when every target is covered. Crates can be pushed, never pulled.", "rows": [
		"#######",
		"#@.$.T#",
		"#.###.#",
		"#f...E#",
		"#######"]},
	{"name": "Two Crates", "region": 0, "hint": "Two crates, two targets. Press Z to undo a move and R to restart.", "rows": [
		"#########",
		"#@.....f#",
		"#.$..$..#",
		"#.......#",
		"#.T..T.E#",
		"#########"]},
	{"name": "Around the Bend", "region": 0, "hint": "A crate against a wall can only slide along it. Think before you push it into a corner!", "rows": [
		"##########",
		"#@.......#",
		"#.$......#",
		"#.####.#.#",
		"#.f..#T..#",
		"#....#.#E#",
		"##########"]},
	{"name": "Garden Gate", "region": 0, "hint": "Three crates share a tiny yard. Order matters.", "rows": [
		"##########",
		"#@.......#",
		"#.$.$.$..#",
		"#........#",
		"#.#T#T#T##",
		"#f.......E",
		"##########"]},
	{"name": "Sunflower Maze", "region": 0, "hint": "A winding hedge. Plan the route for each crate.", "rows": [
		"###########",
		"#@..#.....#",
		"#.$.#.$...#",
		"#...#...#f#",
		"#.#.#.###.#",
		"#.T..T...E#",
		"#f#########",
		"###########"]},

	# ---------------- Moonlit Ruins ----------------
	{"name": "Pressure Plate", "region": 1, "hint": "Stone plates open the iron door while pressed. A crate keeps a plate pressed for you.", "rows": [
		"#########",
		"#@......#",
		"#.$.p.#D#",
		"#.f...#E#",
		"#########"]},
	{"name": "Key and Lock", "region": 1, "hint": "Pick up a key by walking over it. Walk into a locked door to spend the key and open it.", "rows": [
		"##########",
		"#@......f#",
		"#.########",
		"#k..L...E#",
		"##########"]},
	{"name": "Both Plates", "region": 1, "hint": "A door with two plates opens only while both are pressed.", "rows": [
		"#########",
		"#@......#",
		"#.$..$..#",
		"#.......#",
		"#.p..p#D#",
		"#######E#",
		"#########"]},
	{"name": "Plate, Then Key", "region": 1, "hint": "Open the door first, then fetch the key for the second lock.", "rows": [
		"#############",
		"#@.$.p#...#.#",
		"#.....D.k.L.E",
		"#f###########"]},
	{"name": "Key Ring", "region": 1, "hint": "Each key opens exactly one lock. Spend them wisely.", "rows": [
		"###########",
		"#@.k.L.f..#",
		"#.####.####",
		"#.k...L.E##",
		"###########"]},
	{"name": "Ruins Reckoning", "region": 1, "hint": "Plates, keys and crates together. Take your time.", "rows": [
		"############",
		"#@..#...D.E#",
		"#.$.#.k.####",
		"#...L..f#.##",
		"#.$.#.p.#",
		"#.p.#####",
		"#k..#",
		"#####"]},
	# ---------------- Frozen Fishpond ----------------
	{"name": "Slippery Start", "region": 2, "hint": "Ice is slippery: you keep sliding until something stops you.", "rows": [
		"###########",
		"#@..iiiii.#",
		"#...iiiii.#",
		"#...iiiif.#",
		"#.........#",
		"#########E#"]},
	{"name": "Cold Corners", "region": 2, "hint": "Walls and crates stop a slide. Use them to line up.", "rows": [
		"############",
		"#@i##i#i####",
		"#iiiii#i#ii#",
		"#iiiiii#iii#",
		"#iiii#iii#i#",
		"#iii##ii#iE#",
		"############"]},
	{"name": "Frozen Crate", "region": 2, "hint": "Crates slide on ice too. Push one and it keeps going until it hits something.", "rows": [
		"###########",
		"#@..$iiiT.#",
		"#.........#",
		"#.f######E#",
		"###########"]},
	{"name": "Rink Rules", "region": 2, "hint": "A crate on the ice can be a brake for you, or a plug for the target.", "rows": [
		"############",
		"#@ii#ii##i##",
		"##ii#i$ii#i#",
		"#i#iiiiii#i#",
		"#iiiiTi##ii#",
		"##iiiiiiiiE#",
		"############"]},
	{"name": "Chilly Switch", "region": 2, "hint": "Slide a crate onto the plate to open the way.", "rows": [
		"############",
		"#@.$iiiip#.#",
		"#.........D#",
		"#f........E#",
		"############"]},
	{"name": "Thin Ice Fishing", "region": 2, "hint": "Every trick so far, on a bigger pond.", "rows": [
		"#############",
		"#@iii#iiiiii#",
		"#ii#$iiiiiii#",
		"#ii#iii#iiii#",
		"#iiiiiiiTiii#",
		"#iii#iiii#if#",
		"##i#ii#iii#E#",
		"#############"]},
	# ---------------- Crystal Catacombs ----------------
	{"name": "Warp Pads", "region": 3, "hint": "Step on a glowing pad to jump to its twin. Step off and on again to jump back.", "rows": [
		"###########",
		"#@..a#.f..#",
		"#....#....#",
		"#....#..a.E",
		"###########"]},
	{"name": "Past the Wall", "region": 3, "hint": "Pads move you, not crates. Cross over and push from the other side.", "rows": [
		"###########",
		"#@.a.#.....#",
		"#....#.$...#",
		"#...f#a.T.E#",
		"###########"]},
	{"name": "Two Pairs", "region": 3, "hint": "Each letter pairs its own two pads.", "rows": [
		"#############",
		"#@.a#a.b#...#",
		"#...#...#...#",
		"#.f.#...#b.E#",
		"#############"]},
	{"name": "Blink Gates", "region": 3, "hint": "Blue gates are open on even beats, pink gates on odd beats. Press Space to wait a beat.", "rows": [
		"###########",
		"#@..x.y...#",
		"#...#.#...#",
		"#f..x.y..E#",
		"###########"]},
	{"name": "Pulse Corridor", "region": 3, "hint": "Gates block crates too. Push on the beat, and wait with Space when you need to.", "rows": [
		"############",
		"#@.$.x.y.T.#",
		"#..........#",
		"#.f######E##",
		"############"]},
	{"name": "Crystal Crossing", "region": 3, "hint": "Pads, gates and a crate. Find the rhythm.", "rows": [
		"#############",
		"#@..a#...x.E#",
		"#....#.$...#",
		"#.f..#.a.T.##",
		"#############"]},
	# ---------------- Purrfect Temple ----------------
	{"name": "Temple Gate", "region": 4, "hint": "The temple remembers everything you learned.", "rows": [
		"############",
		"#@.$.#...D.#",
		"#....L..p.E#",
		"#.k..#.$...#",
		"############"]},
	{"name": "Plate Relay", "region": 4, "hint": "One crate opens the door, the other needs the room behind it.", "rows": [
		"#############",
		"#@...#....T.#",
		"#.p$.D.$....#",
		"#....#.....E#",
		"#############"]},
	{"name": "Icy Altar", "region": 4, "hint": "Slide the offering onto the altar.", "rows": [
		"#############",
		"#@#iiiii#i#i#",
		"#iii$ii#iiii#",
		"#ii#iiipi#ii#",
		"#iiiiii#iiii#",
		"###iiii#iiDE#",
		"#############"]},
	{"name": "Warp Vault", "region": 4, "hint": "Crates cannot warp, but you can.", "rows": [
		"#############",
		"#@.$.#.a..T.#",
		"#.a..#..$...#",
		"#..p.D.....E#",
		"#############"]},
	{"name": "Rhythm of Ice", "region": 4, "hint": "Slide on the beat.", "rows": [
		"#############",
		"#@ii#ix##iii#",
		"#i#i$ii#iiii#",
		"#iiiiiiiTiii#",
		"##i#i#iiiiyE#",
		"#############"]},
	{"name": "Purrfect Finale", "region": 4, "hint": "The last puzzle. Everything you know, at once. You can do it!", "rows": [
		"###############",
		"#@.$..#...#..E#",
		"#.p...D.$.L...#",
		"#.k.$.#iiiT.a.#",
		"#....a#.......#",
		"###############"]},
]

static var _pars: Dictionary = {}

static func pars() -> Dictionary:
	if _pars.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/pars.json"))
		_pars = parsed if parsed is Dictionary else {}
	return _pars

static func par(i: int) -> int:
	return int(pars().get(str(i), {}).get("par", 0))

static func fish_par(i: int) -> int:
	return int(pars().get(str(i), {}).get("fishpar", 0))

## Move target for the 2nd/3rd star: generous (1.5x the best solution), and always reachable with every fish.
static func target(i: int) -> int:
	return maxi(int(ceil(par(i) * 1.5)) + 3, int(ceil(fish_par(i) * 1.25)) + 2)

## 1 star for finishing, 2 for beating the move target, 3 for target + every fish.
static func stars_for(moves: int, target_moves: int, fish_got: int, fish_total: int) -> int:
	if moves <= target_moves and fish_got >= fish_total:
		return 3
	if moves <= target_moves:
		return 2
	return 1

static func region_start(r: int) -> int:
	var n := 0
	for i in LIST.size():
		if LIST[i].region == r:
			return i
	return n
