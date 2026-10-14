extends SceneTree
# For each level: explore every reachable state, then mark states from which the exit can no longer be reached.
# Reports "trap" states (no way to win) that are NOT flagged by the stuck-crate warning.
func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for i in Levels.LIST.size():
		if only.size() > 0 and not only.has(str(i + 1)):
			continue
		var r := analyze(Levels.LIST[i].rows, 150000)
		print("L%02d %-18s states=%d dead=%d unflagged_dead=%d %s" % [i + 1, Levels.LIST[i].name, r.n, r.dead, r.unflagged, r.example])
	quit()

static func analyze(rows: Array, cap: int) -> Dictionary:
	var pz := Puzzle.new(rows)
	var keys := [pz.state_key()]
	var snaps := [pz._snap()]
	var idx := {keys[0]: 0}
	var rev: Array = [[]]
	var good := {}
	var head := 0
	while head < snaps.size():
		if snaps.size() > cap:
			return {"n": snaps.size(), "dead": -1, "unflagged": -1, "example": "capped"}
		for d in ["up", "down", "left", "right", "wait"]:
			pz._restore(snaps[head])
			var res := pz.wait(false) if d == "wait" else pz.move(d, false)
			if not res.ok:
				continue
			if pz.won:
				good[head] = true
				continue
			var k := pz.state_key()
			var j: int
			if idx.has(k):
				j = idx[k]
			else:
				j = snaps.size()
				idx[k] = j
				keys.append(k)
				snaps.append(pz._snap())
				rev.append([])
			rev[j].append(head)
		head += 1
	var q := good.keys()
	while q.size() > 0:
		var s: int = q.pop_back()
		for p in rev[s]:
			if not good.has(p):
				good[p] = true
				q.append(p)
	var dead := 0
	var unflagged := 0
	var ex := ""
	for s in snaps.size():
		if good.has(s):
			continue
		dead += 1
		pz._restore(snaps[s])
		if pz.stuck_crates().is_empty():
			unflagged += 1
			if ex == "":
				ex = "e.g. " + keys[s]
	return {"n": snaps.size(), "dead": dead, "unflagged": unflagged, "example": ex}
