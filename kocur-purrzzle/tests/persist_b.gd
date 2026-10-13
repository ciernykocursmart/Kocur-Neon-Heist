extends SceneTree
func _initialize() -> void:
	var S = root.get_node("SaveData")
	S.path = "user://persist_save.json"
	S.load_game()
	var ok: bool = S.completed_count() == 2 and S.is_unlocked(2) and not S.is_unlocked(3) and is_equal_approx(S.data.settings.sfx, 0.35)
	DirAccess.remove_absolute(S.path)
	print("B persistence check: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
