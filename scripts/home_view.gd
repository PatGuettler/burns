class_name BurnsHomeView
extends BurnsTableView
## The home screen gives the deck center stage, with one fixed set of thumb targets.
func build_home(owner_ui: Control, bounds: Vector2) -> void:
	app = owner_ui
	size = bounds
	var wide := bounds.x >= 700 or (bounds.x > 600 and bounds.x > bounds.y * 1.4)
	var panel_w := minf(400, bounds.x * 0.43) if wide else minf(420, bounds.x)
	var x: float = bounds.x - panel_w - (24 if wide else (bounds.x - panel_w) / 2)
	var actions_y := (bounds.y - 282) / 2 if wide else bounds.y - 282
	var hero := Rect2(8, 8, bounds.x - panel_w - 64, bounds.y - 32) if wide else Rect2(0, 0, bounds.x, actions_y - 12)
	var compact := hero.size.y < 300
	var brand := label_at("GRAPE GAMES  /  THE RAVEN DECK", Rect2(hero.position, Vector2(hero.size.x, 22)), 10, GOLD)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app._heading(self, "Burns", Rect2(hero.position.x, hero.position.y + 22, hero.size.x, 72 if compact else 88), 52 if compact else 72, true)
	var sub := label_at("A little solitaire. A little rivalry.", Rect2(hero.position.x, hero.position.y + (88 if compact else 104), hero.size.x, 28), 13 if compact else 15, CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var art_y := hero.position.y + (119 if compact else 142)
	var art_h := maxf(54, hero.end.y - art_y - 8)
	_fan(Rect2(hero.position.x, art_y, hero.size.x, art_h))
	if wide and bounds.y > 440:
		app._heading(self, "Take a seat.", Rect2(x, maxf(0, actions_y - 66), panel_w, 50), 30)
	var modes: Array = [["Pass & play", "One device. The whole family.", func(): app._setup("local")], ["Play computers", "Your next rival is ready.", func(): app._setup("bots")], ["Online table", "A private room for your people.", app._online_setup]]
	for i in range(3):
		var entry: Array = modes[i]
		var button: Button = app._button("", entry[2], i == 0)
		button.name = ["PassPlay", "Computers", "Online"][i]
		button.tooltip_text = entry[0]
		place(button, Rect2(x, actions_y + i * 62, panel_w, 54))
		var title := label_at(entry[0], Rect2(x + 18, actions_y + i * 62 + 5, panel_w - 56, 23), 17, CREAM)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var description := label_at(entry[1], Rect2(x + 18, actions_y + i * 62 + 28, panel_w - 50, 17), 10, Color("d2c4b2") if i == 0 else MUTED)
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrow := label_at("›", Rect2(x + panel_w - 38, actions_y + i * 62 + 8, 24, 36), 24, GOLD)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var links_y := actions_y + 190
	var deck: Button = app._button("Explore the deck", func(): app.gallery_return = "menu"; app.gallery_card = 51; app.gallery_back = false; app._show_deck_gallery())
	deck.name = "ExploreDeck"
	place(deck, Rect2(x, links_y, panel_w, 42))
	var extras: Array = [["Rules", app._show_rules], ["Sound on" if app.sound_on else "Sound off", app._toggle_sound]]
	if app.game or not app.room.is_empty() or FileAccess.file_exists(app.SAVE): extras.push_front(["Resume", app._resume])
	var width := (panel_w - (extras.size() - 1) * 8) / extras.size()
	for i in range(extras.size()):
		place(app._button(extras[i][0], extras[i][1]), Rect2(x + i * (width + 8), links_y + 50, width, 42))

func _fan(area: Rect2) -> void:
	var h := minf(area.size.y * 0.9, area.size.x * 0.64)
	var w := h * 2.0 / 3.0
	for i in [0, 2, 1]:
		var card := BurnsCardView.new()
		card.card_id = 49 if i == 0 else 51
		card.face_down = i == 2
		card.artwork_only = true
		card.size = Vector2(w, h)
		card.position = Vector2(area.get_center().x - w / 2 + (i - 1) * w * 0.60, area.get_center().y - h / 2 + (6 if i != 1 else 0))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
