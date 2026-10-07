class_name AlarmSystem
extends Node
## Facility-wide alert state with escalation.
##
##   CALM     normal patrols
##   CAUTION  guards move faster and see further (after traces, data theft,
##            or when a full alarm cools down)
##   ALARM    every enemy converges on the last known position, the siren
##            wails and reinforcements warp in. Each new alarm escalates the
##            next wave (more units, elite hunters).

signal level_changed(level: int)

enum Level { CALM, CAUTION, ALARM }

const LEVEL_NAMES := ["STEALTH", "CAUTION", "ALARM"]
const ALARM_DURATION := 24.0
const CAUTION_DURATION := 30.0
const REINFORCE_DELAY := 7.0

var game: Game
var level := Level.CALM
var timer := 0.0
var last_known := Vector2.ZERO
var escalation := 0
var times_raised := 0
var reinforce_timer := -1.0
var _siren_timer := 0.0
var _broadcast_timer := 0.0


func raise_alarm(pos: Vector2, source: String) -> void:
	last_known = pos
	timer = ALARM_DURATION
	if level == Level.ALARM:
		return
	level = Level.ALARM
	times_raised += 1
	escalation += 1
	reinforce_timer = REINFORCE_DELAY
	_siren_timer = 0.0
	Sfx.play("detect", 2.0, 0.8)
	game.notify("ALARM RAISED by %s" % source, Palette.RED)
	_broadcast()
	level_changed.emit(level)


## A confirmed sighting while the alarm is active keeps it going.
func report_sighting(pos: Vector2) -> void:
	if level == Level.ALARM:
		last_known = pos
		timer = ALARM_DURATION


func raise_caution(pos: Vector2) -> void:
	last_known = pos
	if level == Level.CALM:
		level = Level.CAUTION
		timer = CAUTION_DURATION
		level_changed.emit(level)
	elif level == Level.CAUTION:
		timer = CAUTION_DURATION


func reset_alarm() -> void:
	var was := level
	level = Level.CALM
	timer = 0.0
	reinforce_timer = -1.0
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.on_alarm_cleared()
	if was != level:
		level_changed.emit(level)


func time_ratio() -> float:
	match level:
		Level.ALARM:
			return timer / ALARM_DURATION
		Level.CAUTION:
			return timer / CAUTION_DURATION
	return 0.0


func _broadcast() -> void:
	for e in game.get_tree().get_nodes_in_group("enemies"):
		e.on_alarm(last_known)


func _process(delta: float) -> void:
	if game == null or game.mission_over:
		return
	match level:
		Level.ALARM:
			timer -= delta
			_siren_timer -= delta
			if _siren_timer <= 0.0:
				_siren_timer = 1.15
				Sfx.play("alarm", -5.0, 1.0, 0.0)
			_broadcast_timer -= delta
			if _broadcast_timer <= 0.0:
				_broadcast_timer = 2.0
				_broadcast()
			if reinforce_timer > 0.0:
				reinforce_timer -= delta
				if reinforce_timer <= 0.0:
					game.spawn_reinforcements(mini(escalation, 4), escalation >= 2 or int(game.def.get("index", 1)) >= 3)
			if timer <= 0.0:
				level = Level.CAUTION
				timer = CAUTION_DURATION
				game.notify("Alarm timed out - security on CAUTION", Palette.YELLOW)
				for e in game.get_tree().get_nodes_in_group("enemies"):
					e.on_alarm_cleared()
				level_changed.emit(level)
		Level.CAUTION:
			if game.has_data:
				timer = CAUTION_DURATION  # Stays on caution after the theft.
			timer -= delta
			if timer <= 0.0:
				level = Level.CALM
				game.notify("Security back to normal", Palette.GREEN)
				level_changed.emit(level)
