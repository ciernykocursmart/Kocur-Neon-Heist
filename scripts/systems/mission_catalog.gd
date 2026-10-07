class_name MissionCatalog
extends RefCounted
## Builds mission definitions deterministically from (campaign seed, mission index).
##
## A mission definition is a plain Dictionary consumed by the facility
## generator and the mission controller. Difficulty scales with the index, so
## the campaign is endless without hand-authoring every level.

const CODENAME_A := ["Velvet", "Chrome", "Silent", "Neon", "Static", "Midnight", "Glass", "Hollow", "Ion", "Cobalt", "Feral", "Paper", "Quiet", "Ultraviolet"]
const CODENAME_B := ["Whisker", "Circuit", "Lantern", "Tide", "Cradle", "Mirage", "Pounce", "Echo", "Halo", "Prism", "Lullaby", "Paw", "Purr", "Moth"]
const CORPS := ["Halcyon Biotech", "Orinoco Data", "Vantablack Logistics", "Meridian Arms", "Sable Grid Utility", "Kestrel Finance", "Lumen Pharma", "Obsidian Couriers"]
const TARGETS := ["prototype firmware", "payroll ledgers", "AI training weights", "black-site coordinates", "biometric archives", "encryption keys", "drone schematics", "board-room recordings"]
const THREATS := ["LOW", "GUARDED", "ELEVATED", "HIGH", "SEVERE", "LETHAL"]


static func build(index: int, campaign_seed: int) -> Dictionary:
	index = max(1, index)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kocur:%d:%d" % [campaign_seed, index])
	var tier := index - 1
	var cols := clampi(3 + int(tier / 2.0), 3, 5)
	var rows := clampi(2 + int(tier / 3.0), 2, 4)
	var rooms := cols * rows
	return {
		"index": index,
		"seed": rng.randi(),
		"name": "Operation %s %s" % [CODENAME_A[rng.randi() % CODENAME_A.size()], CODENAME_B[rng.randi() % CODENAME_B.size()]],
		"corp": CORPS[rng.randi() % CORPS.size()],
		"target": TARGETS[rng.randi() % TARGETS.size()],
		"cols": cols,
		"rows": rows,
		"guards": mini(3 + tier, rooms * 2),
		"drones": mini(1 + int(tier / 2.0), rooms),
		"hunters": 0 if index < 2 else mini(1 + int((index - 2) / 2.0), 4),
		"cameras": mini(2 + int(tier / 2.0), 8),
		"terminals": 1 if index < 3 else 2,
		"alarm_panels": 1 if rooms < 9 else 2,
		"locked_ratio": minf(0.2 + 0.05 * tier, 0.45),
		"reward": 300 + 120 * tier,
		"threat": THREATS[mini(tier, THREATS.size() - 1)],
	}
