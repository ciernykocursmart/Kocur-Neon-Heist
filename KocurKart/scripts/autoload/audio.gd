extends Node
## Audio manager (autoload "Audio"). Placeholder API; filled in milestone 5.

var streams := {}


func play(_name: String, _volume_db := 0.0, _pitch := 1.0) -> void:
	pass


func play_at(_name: String, _pos: Vector3, _volume_db := 0.0, _pitch := 1.0) -> void:
	pass


func play_music(_name: String) -> void:
	pass


func stop_music() -> void:
	pass


func stop_all_loops() -> void:
	pass
