extends SceneTree
func _initialize() -> void:
	var S = root.get_node("SaveData")
	S.path = "user://persist_save.json"
	DirAccess.remove_absolute(S.path)
	S.load_game()
	S.record(0, 7, 1, 1)
	S.record(1, 12, 1, 1)
	S.data.settings.sfx = 0.35
	S.save()
	print("A wrote progress")
	quit()
