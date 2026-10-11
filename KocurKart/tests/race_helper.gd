class_name RaceHelper
extends RefCounted
## Shared helpers for tests that run real races.


static func make_race(parent: Node, cfg: Dictionary) -> Race:
	var c := {"mode": "single", "laps": 3, "difficulty": "normal", "autopilot": true, "persist": false,
		"decorate": false, "ui": false, "seed": 11}
	c.merge(cfg, true)
	var race: Race = load("res://scripts/race/race.gd").new()
	race.configure(c)
	parent.add_child(race)
	return race


## Runs physics until the race reaches RESULTS or `max_seconds` of game time.
static func run_to_end(t, race: Race, max_seconds := 400.0) -> bool:
	var frames := int(max_seconds * 60.0)
	for i in frames:
		await t.get_tree().physics_frame
		if race.state == Race.State.RESULTS:
			return true
	return false
