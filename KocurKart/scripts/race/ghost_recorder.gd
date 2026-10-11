class_name GhostRecorder
extends Node
## Time Trial ghost: records the player's line at 10 Hz and, after a valid
## run that beats the stored ghost, saves it (atomically, like the save
## file). The best ghost is replayed as a translucent kart on later runs.
## Purely cosmetic: it never collides and never affects timing.

const RATE := 0.1
const VERSION := 1

var race: Race
var samples: Array = []
var _acc := 0.0
var _ghost_data: Array = []
var _ghost_time := 0.0
var _ghost: Node3D
var _gi := 0


func setup(r: Race) -> void:
	race = r
	race.race_over.connect(_on_race_over)
	_load()


static func ghost_path(track_id: String) -> String:
	return Save.base_dir().path_join("ghost_%s.json" % track_id)


func _load() -> void:
	var p := ghost_path(race.track.def["id"])
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return
	var d: Dictionary = json.data
	if int(d.get("version", 0)) != VERSION or not (d.get("samples") is Array):
		return
	for s in d["samples"]:
		if s is Array and s.size() == 5:
			_ghost_data.append(s)
	_ghost_time = float(d.get("time", 0.0))
	if _ghost_data.size() < 10:
		_ghost_data.clear()
		return
	var app: Dictionary = race.cfg.get("player", {}).duplicate()
	_ghost = KartModel.create(app)
	_ghost.name = "Ghost"
	race.add_child(_ghost)
	for mi in _ghost.find_children("*", "GeometryInstance3D", true, false):
		mi.transparency = 0.6
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false


func has_ghost() -> bool:
	return not _ghost_data.is_empty()


func _physics_process(delta: float) -> void:
	if race == null or race.state == Race.State.COUNTDOWN:
		return
	var k := race.player.kart
	if race.state == Race.State.RACING:
		_acc += delta
		if _acc >= RATE:
			_acc -= RATE
			var p := k.global_position
			samples.append([snappedf(race.race_time, 0.001), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(k.yaw, 0.001)])
	_update_ghost()


func _update_ghost() -> void:
	if _ghost == null:
		return
	var t := race.race_time
	if t > float(_ghost_data[-1][0]):
		_ghost.visible = false
		return
	while _gi < _ghost_data.size() - 2 and float(_ghost_data[_gi + 1][0]) < t:
		_gi += 1
	var a: Array = _ghost_data[_gi]
	var b: Array = _ghost_data[_gi + 1]
	var span := maxf(float(b[0]) - float(a[0]), 0.001)
	var w := clampf((t - float(a[0])) / span, 0.0, 1.0)
	var pa := Vector3(a[1], a[2], a[3])
	var pb := Vector3(b[1], b[2], b[3])
	_ghost.global_position = pa.lerp(pb, w)
	_ghost.rotation = Vector3(0, lerp_angle(float(a[4]), float(b[4]), w), 0)
	_ghost.visible = true


func _on_race_over(res: Dictionary) -> void:
	if not res.get("valid", false) or not race.cfg.get("persist", true):
		return
	var t: float = res["player_time"]
	if _ghost_time > 0.0 and t >= _ghost_time:
		return
	var path := ghost_path(race.track.def["id"])
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "track": race.track.def["id"], "time": t, "samples": samples}))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
