extends SceneTree
## Render the actual in-game cards into a review sheet, using Godot's renderer.
func _init() -> void:
	call_deferred("render")

func render() -> void:
	root.size = Vector2i(1456, 820)
	var background := ColorRect.new()
	background.color = Color("0c1719")
	background.size = Vector2(1456, 820)
	root.add_child(background)
	for card in range(52):
		var art := BurnsCardView.new()
		art.card_id = card
		art.size = Vector2(96, 144)
		art.position = Vector2(24 + (card % 13) * 110, 46 + (card / 13) * 180)
		root.add_child(art)
		var label := Label.new()
		label.text = BurnsDeck.card_name(card)
		label.add_theme_font_size_override("font_size", 11)
		label.position = art.position + Vector2(0, 146)
		root.add_child(label)
	var title := Label.new()
	title.text = "BURNS · THE RAVEN DECK · supplied Jack and King of Spades, ten court portrait placeholders"
	title.position = Vector2(24, 10)
	root.add_child(title)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	root.get_texture().get_image().save_png("res://build/screenshots/raven-deck.png")
	quit()
