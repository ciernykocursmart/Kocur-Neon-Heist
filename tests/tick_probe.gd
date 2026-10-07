extends Node
## Test helper: two probes (first and last physics priority) bracket every
## physics tick so the suite can measure scripted game-logic cost per tick.

static var tick_start := 0
static var total_us := 0
static var worst_us := 0
static var ticks := 0
var is_end := false


func _physics_process(_delta: float) -> void:
	if not is_end:
		tick_start = Time.get_ticks_usec()
	else:
		var d := Time.get_ticks_usec() - tick_start
		total_us += d
		worst_us = maxi(worst_us, d)
		ticks += 1
