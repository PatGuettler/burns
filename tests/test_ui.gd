extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sound_on = false
	scene.save_enabled = false
	for count in range(2, 9):
		scene.player_count = count
		scene._new_game("local")
		await process_frame
		assert(scene.handed_to == -1, "Local play must start behind a handoff screen")
		scene.handed_to = 0
		scene._show_table()
		await process_frame
		assert(_count_cards(scene) == count + 5, "Five public cards and one hidden pile per player")
		scene._act({"type": "draw"})
		await process_frame
		assert(scene.state.players[0].held >= 0)
		scene._act({"type": "end"})
		await process_frame
		assert(scene.state.phase == "review")
	scene._show_rules()
	await process_frame
	scene._show_menu()
	await process_frame
	if "--screenshots" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://build/screenshots")
		root.size = Vector2i(1120, 800)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/screenshots/menu.png")
		scene.player_count = 4
		scene._new_game("local")
		scene.handed_to = 0
		scene._show_table()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/screenshots/table.png")
		root.size = Vector2i(390, 844)
		await process_frame
		scene._show_table()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/screenshots/portrait.png")
	print("PASS: menu, handoffs, rules, 2–8-player tables, reveal and discard UI")
	quit()

func _count_cards(node: Node) -> int:
	var count := 1 if node is BurnsCardView else 0
	for child in node.get_children(): count += _count_cards(child)
	return count
