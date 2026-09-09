extends SceneTree
func _init() -> void:
	var path := "res://build/expiry-test.cfg"
	var file := ConfigFile.new()
	var now := Time.get_unix_time_from_system()
	var seats := [{"name": "A", "token": "test", "peer": -1}]
	file.set_value("server", "rooms", {"expired": {"seats": seats, "updated": now - 90000, "game": {}}, "recent": {"seats": seats, "updated": now, "game": {}}})
	assert(file.save(path) == OK)
	var server := BurnsNetwork.new()
	server.store_path = path
	server._restore_rooms()
	assert(server.rooms.has("recent") and not server.rooms.has("expired"))
	assert(file.load(path) == OK)
	assert(not file.get_value("server", "rooms").has("expired"), "Expired room is removed from disk after restart")
	server.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: room expiry removes persisted data while retaining recent reconnectable rooms")
	quit()
