extends SceneTree
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: push_error(message); quit(1); assert(value, message)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sound_on = false
	scene.animations_enabled = false
	scene.save_enabled = false
	var sizes := [Vector2i(320, 568), Vector2i(390, 844), Vector2i(430, 932), Vector2i(844, 390), Vector2i(667, 375), Vector2i(1120, 800), Vector2i(1920, 1080)]
	for viewport_size in sizes:
		root.size = viewport_size
		await process_frame
		await process_frame
		for count in [2, 4, 8]:
			scene.player_count = count
			scene._new_game("local")
			await process_frame
			_validate(scene, viewport_size)
			scene.handed_to = 0
			scene._show_table()
			await process_frame
			_validate(scene, viewport_size)
			check(scene._can_burn(), "Burns available during active turn")
			scene._call_burn()
			await process_frame
			_validate(scene, viewport_size)
			check(scene.screen == "burn_caller", "Shared device identifies caller")
			scene._show_table()
			scene._act({"type": "draw"})
			await process_frame
			_validate(scene, viewport_size)
			check(scene.selected.get("source") == "held", "Revealed card is selected immediately")
			# A long legal row cannot push the hand below the viewport.
			scene.state.rows[0] = [12, 24, 10, 22, 8, 20, 6, 18, 4, 16, 2, 14, 0]
			scene._show_table()
			await process_frame
			_validate(scene, viewport_size)
			scene._inspect_row(0)
			await process_frame
			_validate(scene, viewport_size)
			check(_count_cards(scene) == 13, "Every card in the sequence is selectable without scrolling")
			scene._act({"type": "burn"}, 1)
			await process_frame
			check(scene.screen == "game", "Burns keeps the board visible")
			_validate(scene, viewport_size)
		for gallery_id in [0, 9, 10, 49, 51]:
			scene.gallery_card = gallery_id
			scene._show_deck_gallery()
			await process_frame
			_validate(scene, viewport_size)
		scene.state.phase = "finished"
		scene.state.winner = 0
		scene._show_victory()
		await process_frame
		_validate(scene, viewport_size)
		scene._show_menu()
		await process_frame
		_validate(scene, viewport_size)
		for game_mode in ["local", "bots"]:
			scene._setup(game_mode)
			await process_frame
			_validate(scene, viewport_size)
		scene._online_setup()
		await process_frame
		_validate(scene, viewport_size)
		scene.room = {"room": "12345678", "seats": []}
		for i in range(8): scene.room.seats.append({"name": "Player %d" % i, "connected": true})
		scene._lobby()
		await process_frame
		_validate(scene, viewport_size)
		scene.burn_title = "Burns confirmed"
		scene.burn_explanation = "Player 2 called Burns. A higher-priority play was skipped. The Ace of Diamonds could play to the Aces area.\n\nPlayer 1 receives a card from every other player."
		scene._show_burn_result()
		await process_frame
		_validate(scene, viewport_size)
		for page in range(9):
			scene.rules_page = page
			scene._show_rules()
			await process_frame
			_validate(scene, viewport_size)
		if "--screenshots" in OS.get_cmdline_user_args() and viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1120, 800)]:
			scene.player_count = 8 if viewport_size.x != 1120 else 4
			scene._new_game("local")
			scene.handed_to = 0
			scene._act({"type": "draw"})
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://build/screenshots")
			root.get_texture().get_image().save_png("res://build/screenshots/table-%dx%d.png" % [viewport_size.x, viewport_size.y])
	print("PASS: %d UI bounds, no-scrollbar, sequence selection, and reveal checks at seven phone/desktop sizes" % checks)
	quit()

func _validate(node: Node, viewport_size: Vector2i) -> void:
	check(not node is ScrollContainer and not node is ScrollBar, "No scrolling controls anywhere")
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= viewport_size.x + 1 and rect.end.y <= viewport_size.y + 1, "Visible UI exceeds viewport: %s %s at %s" % [node, rect, viewport_size])
	if node is BurnsTableView:
		for rect in node.card_rects:
			check(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= node.size.x + 1 and rect.end.y <= node.size.y + 1, "Card outside table: %s / %s at %s" % [rect, node.size, viewport_size])
		for i in range(node.card_rects.size()):
			if node.card_sources[i] != "row": continue
			for j in range(node.card_rects.size()):
				if node.card_sources[j] in ["held", "play", "discard", "reserve"]:
					check(not node.card_rects[i].intersects(node.card_rects[j]), "Rows cannot overlap personal cards")
		for control in node.controls:
			check(control.position.x >= -1 and control.position.y >= -1 and control.position.x + control.size.x <= node.size.x + 1 and control.position.y + control.size.y <= node.size.y + 1, "Control outside table: %s at %s / %s" % [control, control.get_rect(), viewport_size])
	for child in node.get_children(): _validate(child, viewport_size)

func _count_cards(node: Node) -> int:
	var count := 1 if node is BurnsCardView else 0
	for child in node.get_children(): count += _count_cards(child)
	return count
