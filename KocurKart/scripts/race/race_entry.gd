class_name RaceEntry
extends RefCounted
## Per-kart race bookkeeping: laps, ordered checkpoints, timing and progress.
##
## Checkpoints are progress thresholds along the main circuit. A kart must
## cross them in order; crossing one backwards undoes it, so driving back and
## forth over the line or skipping part of the lap never earns a lap.

var kart: Kart
var lap := 0                 ## 0 = on the grid behind the line, 1 = first lap
var next_cp := 0             ## index of the next checkpoint to cross
var finished := false
var finish_time := 0.0
var estimated := false       ## finish time extrapolated (race ended early)
var lap_start := 0.0
var lap_times: Array[float] = []
var best_lap := INF
var prev_s := 0.0
var wrong_way_time := 0.0
var off_track_time := 0.0
var position := 1
var cp_count := 10
var points := 0
var recover_cooldown := 0.0


func setup(k: Kart, checkpoints: int) -> void:
	kart = k
	cp_count = checkpoints
	lap = 0
	next_cp = 0   # the finish line itself is checkpoint 0
	prev_s = k.loc.s


## Total progress in metres: completed laps plus distance into this lap.
func progress(track_length: float) -> float:
	if finished:
		return 1.0e9 - finish_time
	var s := prev_s
	return (lap - 1) * track_length + s if lap > 0 else s - track_length


func display_lap(total: int) -> int:
	return clampi(lap, 1, total)
