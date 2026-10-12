extends RefCounted
## One unit on the battlefield (hero, enemy, escort or object). Pure data.

var uid := 0
var side := "hero"  ## "hero" or "enemy"
var kind := ""  ## class id for heroes, archetype id for enemies
var hero_id := ""  ## persistent roster id (heroes only)
var name := ""
var hp := 1
var max_hp := 1
var atk := 0
var def := 0
var move := 0
var abilities: Array[String] = []
var pos := Vector2i.ZERO
var start_pos := Vector2i.ZERO  ## where this unit began the current turn (for undo)
var moved := false
var acted := false
var alive := true
var escaped := false
var cooldowns := {}  ## ability id -> turns remaining
var status := {}  ## status id -> turns remaining (stance, chilled, exhausted, iron_guard, drained)
var is_object := false
var is_boss := false
var is_vip := false
var commander := false
var awake := true
var group := 0
var ai := "melee"
var pathfinder := false  ## ignores terrain movement cost
var kills := 0
var special := false  ## class mastery upgrade bought
var tag := ""  ## mission-specific identifier ("captain", "elder", ...)
var boss_state := {}  ## free-form state for boss scripts


func can_act() -> bool:
	return alive and not escaped and not is_object and not acted


func is_done() -> bool:
	return acted or not alive or escaped or is_object


func on_field() -> bool:
	return alive and not escaped


func ability_ready(id: String) -> bool:
	return abilities.has(id) and int(cooldowns.get(id, 0)) <= 0


func has_status(s: String) -> bool:
	return int(status.get(s, 0)) > 0


func effective_move() -> int:
	var m := move
	if has_status("chilled"):
		m -= 2
	return maxi(1, m) if move > 0 else 0


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func describe() -> String:
	return "%s (%s) hp %d/%d at %s" % [name, kind, hp, max_hp, str(pos)]
