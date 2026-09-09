extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sound_on = false
	scene.save_enabled = false
	scene.animations_enabled = false
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	for viewport in [Vector2i(390, 844), Vector2i(320, 568), Vector2i(844, 390), Vector2i(1120, 800)]:
		root.size = viewport
		await process_frame
		await process_frame
		scene._show_menu()
		await capture("home", viewport)
		scene.gallery_card = 49
		scene.gallery_return = "menu"
		scene._show_deck_gallery()
		await capture("gallery", viewport)
		scene.player_count = 4
		scene._new_game("local")
		scene.handed_to = 0
		scene.game.s.rows[0] = [49]
		scene.game.s.rows[1] = [51]
		scene.state = scene.game.view()
		scene._show_table()
		await capture("table", viewport)
	quit()
func capture(label: String, viewport: Vector2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/screenshots/polish-%s-%dx%d.png" % [label, viewport.x, viewport.y])
