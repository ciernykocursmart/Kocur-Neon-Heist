class_name MissionCatalog
extends RefCounted
## Builds mission definitions (plain Dictionaries consumed by the facility
## generator and the mission controller).
##
## * Campaign missions 1-12 come from the hand-authored Campaign table; the
##   layout seed still derives from the campaign seed, so every new game
##   gets fresh facilities with the same designed difficulty.
## * Endless contracts are procedural and scale with depth without limit.

const CODENAME_A := ["Velvet", "Chrome", "Silent", "Neon", "Static", "Midnight", "Glass", "Hollow", "Ion", "Cobalt", "Feral", "Paper", "Quiet", "Ultraviolet"]
const CODENAME_B := ["Whisker", "Circuit", "Lantern", "Tide", "Cradle", "Mirage", "Pounce", "Echo", "Halo", "Prism", "Lullaby", "Paw", "Purr", "Moth"]
const CORPS := ["Argus Holdings Vault", "Argus Data Annex", "Argus Arms Depot", "Argus Grid Utility", "Argus Finance Spire", "Argus Pharma Lab", "Argus Courier Yard", "WARDEN Remnant Node"]
const TARGETS := ["prototype firmware", "payroll ledgers", "AI training weights", "black-site coordinates", "biometric archives", "encryption keys", "drone schematics", "board-room recordings"]
const THREATS := ["LOW", "GUARDED", "ELEVATED", "HIGH", "SEVERE", "LETHAL"]


static func threat_for(index: int) -> String:
	if index <= 3:
		return THREATS[0] if index == 1 else THREATS[1]
	if index <= 6:
		return THREATS[2]
	if index <= 9:
		return THREATS[3]
	if index <= 11:
		return THREATS[4]
	return THREATS[5]


## Campaign mission (index 1..12).
static func build(index: int, campaign_seed: int) -> Dictionary:
	index = clampi(index, 1, Campaign.MISSION_COUNT)
	var m: Dictionary = Campaign.mission(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kocur:%d:%d" % [campaign_seed, index])
	var act: Dictionary = Campaign.ACTS[int(m["act"])]
	var def := m.duplicate(true)
	def["mode"] = "campaign"
	def["index"] = index
	def["seed"] = rng.randi()
	def["name"] = "%d. %s" % [index, m["title"]]
	def["act_label"] = "ACT %s - %s" % [act["number"], act["name"]]
	def["threat"] = threat_for(index)
	def["shards"] = int(m.get("shards", 1))
	def["final"] = m["objective"] == "final"
	def["alarm_penalty"] = 0.15
	def["max_reinforcements"] = 2 if index <= 4 else (3 if index <= 8 else 4)
	return def


## Endless contract at the given depth (1, 2, 3, ...).
static func build_endless(depth: int, campaign_seed: int) -> Dictionary:
	depth = maxi(1, depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kocur-endless:%d:%d" % [campaign_seed, depth])
	var tier := depth - 1
	var cols := clampi(4 + int(tier / 3.0), 4, 5)
	var rows := clampi(3 + int(tier / 4.0), 3, 4)
	var rooms := cols * rows
	var objective := "shards" if depth % 2 == 0 else "data"
	return {
		"mode": "endless",
		"index": Campaign.MISSION_COUNT + depth,
		"depth": depth,
		"seed": rng.randi(),
		"title": "%s %s" % [CODENAME_A[rng.randi() % CODENAME_A.size()], CODENAME_B[rng.randi() % CODENAME_B.size()]],
		"name": "Endless %d: %s %s" % [depth, CODENAME_A[rng.randi() % CODENAME_A.size()], CODENAME_B[rng.randi() % CODENAME_B.size()]],
		"act_label": "ENDLESS HEIST - DEPTH %d" % depth,
		"act": 2,
		"corp": CORPS[rng.randi() % CORPS.size()],
		"target": TARGETS[rng.randi() % TARGETS.size()],
		"briefing": "MOTH: ARGUS is gone, but its remnants still guard fat vaults. Every contract goes deeper and pays more. How far can one cat go?",
		"theme": depth % 3,
		"objective": objective,
		"shards": 2 + int(tier / 4.0) if objective == "shards" else 1,
		"final": false,
		"cols": cols,
		"rows": rows,
		"guards": mini(6 + int(tier * 0.7), rooms),
		"drones": mini(2 + int(tier / 2.0), rooms),
		"hunters": mini(1 + int(tier / 3.0), 5),
		"enforcers": mini(1 + int(tier / 3.0), 5),
		"cameras": mini(4 + int(tier / 2.0), 9),
		"terminals": 2,
		"alarm_panels": 2,
		"locked_ratio": minf(0.3 + 0.03 * tier, 0.5),
		"reward": 700 + 120 * tier,
		"threat": THREATS[mini(2 + int(tier / 2.0), THREATS.size() - 1)],
		"tips": [],
		"intel": -1,
		"alarm_penalty": 0.1,
		"max_reinforcements": mini(3 + int(tier / 3.0), 6),
	}
