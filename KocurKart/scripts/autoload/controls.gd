extends Node
## Input configuration (autoload "Controls").
##
## Every gameplay action is registered here, in one place, with keyboard and
## gamepad defaults. Keyboard keys can be rebound from the Controls screen;
## custom bindings are stored by the Settings autoload and re-applied on boot.
## Gameplay code only ever asks for actions, never for raw keys.

const ACTIONS := {
	"accelerate": {"label": "Accelerate", "keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_A], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"brake": {"label": "Brake / Reverse", "keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_B], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	"steer_left": {"label": "Steer Left", "keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"steer_right": {"label": "Steer Right", "keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"drift": {"label": "Drift (hold)", "keys": [KEY_SPACE], "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
	"boost": {"label": "Purr Boost", "keys": [KEY_SHIFT], "buttons": [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER], "axes": []},
	"recover": {"label": "Recover Kart", "keys": [KEY_R], "buttons": [JOY_BUTTON_Y], "axes": []},
	"pause": {"label": "Pause", "keys": [KEY_ESCAPE, KEY_P], "buttons": [JOY_BUTTON_START], "axes": []},
}

## Order shown on the Controls screen.
const ORDER := ["accelerate", "brake", "steer_left", "steer_right", "drift", "boost", "recover", "pause"]
## Actions the player may rebind (the primary key is replaced).
const REBINDABLE := ["accelerate", "brake", "steer_left", "steer_right", "drift", "boost", "recover"]

const STICK_DEADZONE := 0.18
const TRIGGER_DEADZONE := 0.08

var _custom_keys := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_bindings({})


## Rebuilds the input map. `custom` maps action -> primary keycode.
func apply_bindings(custom: Dictionary) -> void:
	_custom_keys = {}
	for action in ACTIONS:
		var def: Dictionary = ACTIONS[action]
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		var deadzone := TRIGGER_DEADZONE if action in ["accelerate", "brake"] else STICK_DEADZONE
		InputMap.add_action(action, deadzone)
		var keys: Array = def["keys"].duplicate()
		if custom.has(action) and action in REBINDABLE:
			var k := int(custom[action])
			if k > 0 and _is_valid_key(k):
				_custom_keys[action] = k
				keys.erase(k)
				keys[0] = k
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in def["buttons"]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		for a in def["axes"]:
			var jm := InputEventJoypadMotion.new()
			jm.axis = a[0]
			jm.axis_value = a[1]
			InputMap.action_add_event(action, jm)
	# Menus should also respond to the gamepad confirm/back buttons.
	_ensure_ui_event("ui_accept", JOY_BUTTON_A)
	_ensure_ui_event("ui_cancel", JOY_BUTTON_B)


func custom_keys() -> Dictionary:
	return _custom_keys.duplicate()


func primary_key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "-"


func binding_text(action: String) -> String:
	var keys: Array[String] = []
	var pads: Array[String] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append(OS.get_keycode_string(ev.physical_keycode))
		elif ev is InputEventJoypadButton:
			pads.append(_button_name(ev.button_index))
		elif ev is InputEventJoypadMotion:
			pads.append(_axis_name(ev.axis, ev.axis_value))
	var text := " / ".join(keys)
	if not pads.is_empty():
		text += "    Pad: " + " / ".join(pads)
	return text


func _is_valid_key(k: int) -> bool:
	return k != KEY_ESCAPE and k != KEY_P and k != KEY_ENTER


func _ensure_ui_event(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	InputMap.action_add_event(action, jb)


func _button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
	return "Button %d" % b


func _axis_name(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_LEFT_X: return "Left Stick " + ("Left" if value < 0.0 else "Right")
	return "Axis %d" % axis
