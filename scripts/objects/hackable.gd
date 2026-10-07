class_name Hackable
extends Node2D
## Base for every hackable system. The player hacks it via the timing
## mini-game (see HackOverlay); success calls on_hacked(), failure calls
## on_hack_failed() which by default leaves a trace that raises suspicion.

signal hacked(target: Hackable)

var game: Game
var display_name := "SYSTEM"
var action_name := "HACK"
var difficulty := 2
var interact_radius := 52.0
var hacked_done := false
## Sealed systems show a reason instead of starting a hack.
var sealed := false
## Instant interactables (intel) skip the hacking mini-game.
var instant := false
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func can_interact() -> bool:
	return not hacked_done


func prompt() -> String:
	if sealed:
		return "%s - SEALED" % display_name
	return "[E] %s %s" % [action_name, display_name]


func sealed_reason() -> String:
	return "Locked by facility security"


func describe() -> String:
	return ""


func interact_position() -> Vector2:
	return global_position


func complete_hack() -> void:
	hacked_done = true
	on_hacked()
	hacked.emit(self)


## Override for the gameplay consequence.
func on_hacked() -> void:
	pass


func on_hack_failed() -> void:
	game.alarm.raise_caution(global_position)
	game.emit_noise(global_position, 420.0, true)
	game.notify("TRACE DETECTED - security alerted", Palette.YELLOW)


## Highlight ring shown when the player is in range.
func draw_focus_ring(radius: float) -> void:
	if game != null and game.focus == self:
		var pulse := 0.6 + 0.4 * sin(_t * 6.0)
		draw_arc(to_local(interact_position()), radius, 0, TAU, 32, Palette.with_alpha(Palette.CYAN, 0.6 * pulse), 2.0, true)
