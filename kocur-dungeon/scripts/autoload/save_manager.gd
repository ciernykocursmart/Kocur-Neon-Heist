extends Node
## SaveManager autoload: low-level, crash-safe JSON persistence in user://.
## Writes go to a temp file first and are then renamed over the real save,
## and a malformed save is moved aside instead of crashing the game.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var path := SAVE_PATH
var last_error := ""


func read() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "open failed"
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "malformed save"
		_quarantine()
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) > SAVE_VERSION:
		last_error = "save from newer version"
	return data


func write(data: Dictionary) -> bool:
	data["version"] = SAVE_VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "write failed"
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and FileAccess.file_exists(path):
		dir.remove(path.get_file())


func has_save() -> bool:
	return FileAccess.file_exists(path)


func _quarantine() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var bad := path.get_file().get_basename() + "_corrupt.json"
	if FileAccess.file_exists("user://" + bad):
		dir.remove(bad)
	dir.rename(path.get_file(), bad)
