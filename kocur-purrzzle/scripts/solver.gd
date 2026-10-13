class_name Solver
extends RefCounted
## Breadth-first solver over the real Puzzle rules. Returns the shortest solution.

static func solve(rows: Array, with_fish := false, cap := 600000) -> Dictionary:
	var pz := Puzzle.new(rows)
	var nodes: Array = [pz._snap()]
	var parent: Array = [-1]
	var mv: Array = [""]
	var seen := {pz.state_key(with_fish): true}
	var head := 0
	var dirs := ["up", "down", "left", "right", "wait"]
	var letters := {"up": "U", "down": "D", "left": "L", "right": "R", "wait": "W"}
	while head < nodes.size():
		if nodes.size() > cap:
			return {"moves": -1, "path": "", "states": nodes.size(), "capped": true}
		var snap: Dictionary = nodes[head]
		for d in dirs:
			pz._restore(snap)
			var r := pz.wait(false) if d == "wait" else pz.move(d, false)
			if not r.ok:
				continue
			if pz.won and (not with_fish or pz.fish.is_empty()):
				var path: String = letters[d]
				var i := head
				while i > 0:
					path = mv[i] + path
					i = parent[i]
				return {"moves": path.length(), "path": path, "states": nodes.size(), "capped": false}
			var k := pz.state_key(with_fish)
			if seen.has(k):
				continue
			seen[k] = true
			nodes.append(pz._snap())
			parent.append(head)
			mv.append(letters[d])
		head += 1
	return {"moves": -1, "path": "", "states": nodes.size(), "capped": false}
