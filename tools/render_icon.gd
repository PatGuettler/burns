extends SceneTree
func _init() -> void:
	var icon := Image.load_from_file("res://assets/art/icon.svg")
	assert(not icon.is_empty())
	assert(icon.save_png("res://assets/art/icon.png") == OK)
	quit()
