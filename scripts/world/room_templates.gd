class_name RoomTemplates
extends RefCounted
## Reusable room building blocks. Each room is a 15x11 tile interior described
## as ASCII art. The generator stitches rooms into a facility grid and carves
## doorways in the shared walls, so door areas (rows 4-6 at the left/right
## edges, columns 6-8 at the top/bottom edges) must stay walkable.
##
## Legend:
##   .  floor            #  wall block          c  crate / cover
##   Z  security zone (motion-sensor floor)
##   h  shadow (walkable; the cat is much harder to see here when sneaking
##      or standing still, and bodies left here are never discovered)
##   S  room centre spot (player spawn / data core / extraction pad)
##   E  guard spawn      D  drone spawn         K  camera mount
##   T  terminal         A  alarm panel         P  pickup

const W := 15
const H := 11

## tags: "spawn" (start room only), "data" (can hold the data core),
##       "arena" (final mission vault; two arena rooms are merged into one).
const TEMPLATES := [
	{
		"name": "Insertion Bay",
		"tags": ["spawn"],
		"rows": [
			"...............",
			".cc.........cc.",
			".c...........c.",
			"...............",
			"...............",
			".......S.......",
			"...............",
			"...............",
			".c...........c.",
			".cc....P....cc.",
			"...............",
		],
	},
	{
		"name": "Atrium",
		"tags": [],
		"rows": [
			"K.............K",
			"...............",
			"..##.......##..",
			"..##...E...##..",
			"...............",
			"....P..S..D....",
			"...............",
			"..##...E...##..",
			"..##.......##..",
			".hh.........hh.",
			"..A............",
		],
	},
	{
		"name": "Server Farm",
		"tags": ["data"],
		"rows": [
			"K..............",
			".#.#.#...#.#.#.",
			".#.#.#...#.#.#.",
			".#.#.#.E.#.#.#.",
			"...............",
			"..P....S....T..",
			"...............",
			".#.#.#...#.#.#.",
			".#.#.#.E.#.#.#.",
			".#.#.#...#.#.#.",
			"..............A",
		],
	},
	{
		"name": "Open Offices",
		"tags": [],
		"rows": [
			"...............",
			".ccc.c...c.ccc.",
			".c.....c.....c.",
			".c.E...c..P..c.",
			"...............",
			"...T...S...D...",
			"...............",
			".c.....c.....c.",
			".c..P..c...E.c.",
			".ccc.c...c.ccc.",
			"K.............K",
		],
	},
	{
		"name": "Research Lab",
		"tags": ["data"],
		"rows": [
			"...............",
			".K...........K.",
			"..ZZZZZ.ZZZZZ..",
			"..Z###Z.Z###Z..",
			"..ZZZZZ.ZZZZZ..",
			"...P...S...A...",
			"..ZZZZZ.ZZZZZ..",
			"..Z###Z.Z###Z..",
			"..ZZZZZ.ZZZZZ..",
			"....E.....D....",
			"...............",
		],
	},
	{
		"name": "Vault",
		"tags": ["data"],
		"rows": [
			"...............",
			".##.........##.",
			".#..ZZZZZZZ..#.",
			"....Z.....Z....",
			"....Z.....Z....",
			"..E.Z..S..Z.E..",
			"....Z.....Z....",
			"....ZZZ.ZZZ....",
			".#hh.......hh#.",
			".##....D....##.",
			"K.............K",
		],
	},
	{
		"name": "Cargo Storage",
		"tags": [],
		"rows": [
			"..............K",
			".cc.cc.....cc..",
			".cc.cc..E..cc..",
			"...............",
			"...ccc...ccc...",
			"..P.c..S..c.T..",
			"...ccc...ccc...",
			"hh...........hh",
			".cc..E....D.cc.",
			".cc.........cc.",
			"...A...........",
		],
	},
	{
		"name": "Crossroads",
		"tags": [],
		"rows": [
			"####.......####",
			"####.......####",
			"####...E...####",
			"##K.........K##",
			"...............",
			"....D..S..P....",
			"...............",
			"##...........##",
			"####.......####",
			"####...E...####",
			"####.......####",
		],
	},
	{
		"name": "Reactor Core",
		"tags": ["data"],
		"rows": [
			"...............",
			"..K.........T..",
			"...............",
			"....#######....",
			"....#ZZZZZ#....",
			"..E.#ZZSZZ#.D..",
			"....#ZZZZZ#....",
			"....##...##....",
			"...............",
			"..P.....E......",
			"...............",
		],
	},
	{
		"name": "Maintenance Tunnels",
		"tags": [],
		"rows": [
			"hh#....h....#hh",
			"h.#..#...#K.#.h",
			"..#..#.E.#..#..",
			"..#..#...#..#..",
			".....#...#.....",
			"..P..h.S.h..T..",
			".....#...#.....",
			"..#..#...#..#..",
			"..#..#.D.#..#..",
			"h.#..#...#..#.h",
			"hh#....h....#hh",
		],
	},
	{
		"name": "Hangar Bay",
		"tags": [],
		"rows": [
			"...............",
			".cccc.....cccc.",
			".cccc..E..cccc.",
			".hhhh.....hhhh.",
			"...............",
			"..D....S....P..",
			"...............",
			".hhhh.....hhhh.",
			".cccc..E..cccc.",
			".cccc.....cccc.",
			"K..A..........K",
		],
	},
	{
		"name": "Data Archive",
		"tags": ["data"],
		"rows": [
			"...............",
			".##.##...##.##.",
			".##.##.K.##.##.",
			".hh.hh...hh.hh.",
			"...............",
			"..E....S....E..",
			"...............",
			".hh.hh...hh.hh.",
			".##.##...##.##.",
			".##.##.D.##.##.",
			"..P.........T..",
		],
	},
	{
		"name": "Security Hub",
		"tags": [],
		"rows": [
			"K......h......K",
			"...............",
			"...#########...",
			"...#.T...A.#...",
			"...#.......#...",
			"..E#...S...#E..",
			"...#.......#...",
			"...####.####...",
			"...............",
			"hh....P.....hhh",
			"hh...........hh",
		],
	},
	{
		"name": "Canteen",
		"tags": [],
		"rows": [
			"...............",
			".c.c.c...c.c.c.",
			"...............",
			".c.c.c.E.c.c.c.",
			"...............",
			"..T....S....D..",
			"...............",
			".c.c.c...c.c.c.",
			"hh...........hh",
			"hhK....P.....hh",
			"hh...........hh",
		],
	},
	{
		"name": "Hydroponics",
		"tags": ["data"],
		"rows": [
			"...............",
			".hhh.ZZZZZ.hhh.",
			".hch.Z...Z.hch.",
			".hhh.Z.E.Z.hhh.",
			".....Z...Z.....",
			"..P..Z.S.Z..A..",
			".....Z...Z.....",
			".hhh.ZZ.ZZ.hhh.",
			".hch.......hch.",
			".hhh...D...hhh.",
			"K.............K",
		],
	},
	{
		"name": "WARDEN Vault",
		"tags": ["arena"],
		"rows": [
			"...............",
			"...............",
			"..##.......##..",
			"..##.......##..",
			"...............",
			".......S.......",
			"...............",
			"..##.......##..",
			"..##.......##..",
			"...............",
			"...............",
		],
	},
]


static func by_tag(tag: String) -> Array:
	var out := []
	for t in TEMPLATES:
		if tag in t["tags"]:
			out.append(t)
	return out


## Templates usable as ordinary (non-spawn) rooms.
static func generic() -> Array:
	var out := []
	for t in TEMPLATES:
		if not ("spawn" in t["tags"]) and not ("arena" in t["tags"]):
			out.append(t)
	return out
