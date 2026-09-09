extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var margins := BurnsSafeLayout.margins(Vector2(1170, 2532), Vector2(390, 844), Rect2(0, 141, 1170, 2289))
	assert(margins == Vector4(16, 55, 16, 42), "Phone safe insets use logical points, not physical pixels")
	assert(BurnsSafeLayout.margins(Vector2(2532, 1170), Vector2(844, 390), Rect2(141, 0, 2250, 1107)) == Vector4(55, 16, 55, 29), "Landscape safe areas protect both sides")
	root.size = Vector2i(390, 844)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.animations_enabled = false; app.save_enabled = false; app.sound_on = false
	app.player_count = 2
	app._new_game("local")
	app.handed_to = 0
	app._show_table()
	await process_frame
	var target: BurnsCardButton
	for child in app.content.get_child(0).get_children():
		if child is BurnsCardButton and child.source.get("source") == "row":
			target = child
			break
	assert(target != null)
	var card: int = target.art.card_id
	var before: Dictionary = app.game.s.duplicate(true)
	var point := target.get_global_rect().get_center()
	mouse(point, true)
	await create_timer(0.65).timeout
	assert(app.screen == "deck_gallery" and app.gallery_card == card, "Holding a face-up card opens its full artwork")
	mouse(point, false)
	await process_frame
	assert(app.game.s == before, "Inspecting artwork never plays or reveals a card")
	var gallery = app.content.get_child(0).get_node("GalleryCard")
	var start: Vector2 = gallery.get_global_rect().get_center() + Vector2(45, 0)
	mouse(start, true)
	mouse(start - Vector2(90, 0), false)
	await process_frame
	assert(app.gallery_card == (card + 1) % 52, "Swipe advances artwork without scrolling")
	app._close_gallery()
	await process_frame
	assert(app.screen == "game" and app.game.s == before, "Closing inspection returns to the same turn")
	print("PASS: notch/home-indicator insets, hold-to-inspect, gallery swipe, unchanged game state")
	quit()
func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event)
