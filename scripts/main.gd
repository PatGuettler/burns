extends Control

const CREAM := Color("f4ead6")
const MUTED := Color("adc3bd")
var content: MarginContainer
var player_count := 4
var deal_number := 1

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://assets/art/card_room.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.05, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 44)
	add_child(content)
	_show_menu()

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("a34b32") if primary else Color("16383c")
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.15)
		style.border_color = Color("d1ac78") if state == "focus" else Color("7b7760")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 22
		style.content_margin_right = 22
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button

func _show_menu() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	content.add_child(box)
	box.add_child(_label("THE FAMILY CARD TABLE", 17, Color("d1ac78")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label("Burns", 112))
	box.add_child(_label("A little solitaire. A little rivalry.", 28))
	box.add_child(_label("Keep your eyes on the table.\nSomeone is about to miss a play.", 21, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	actions.add_child(_button("Explore the table", _show_table, true))
	actions.add_child(_button("The family rules", _show_rules))
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(bottom_spacer)
	box.add_child(_label("2–8 PEOPLE     /     SIX SUITS     /     ONE SHARP EYE", 16, Color("d1ac78")))
	box.add_child(_label("Design preview · gameplay awaits confirmed house rules", 15, MUTED))

func _show_table() -> void:
	_clear()
	var scroll := ScrollContainer.new()
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	scroll.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	box.add_child(header)
	header.add_child(_button("‹ Home", _show_menu))
	header.add_child(_label("The table", 36))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 18)
	box.add_child(options)
	options.add_child(_label("Players", 20))
	var count := SpinBox.new()
	count.min_value = 2
	count.max_value = 8
	count.value = player_count
	count.custom_minimum_size = Vector2(110, 58)
	count.value_changed.connect(func(value: float): player_count = int(value); _show_table())
	options.add_child(count)
	options.add_child(_button("Deal again", func(): deal_number += 1; _show_table()))
	box.add_child(_label("Deal preview · play piles remain hidden", 18, MUTED))
	var state := BurnsDeck.deal(player_count, deal_number)
	box.add_child(_label("01   ACES AREA", 17, Color("d1ac78")))
	var foundations := HFlowContainer.new()
	foundations.add_theme_constant_override("h_separation", 20)
	box.add_child(foundations)
	for suit in range(6):
		var stack := VBoxContainer.new()
		stack.add_child(_label(BurnsDeck.SUITS[suit], 16))
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(100, 110)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.12, 0.14, 0.8)
		style.border_color = Color("7b7760")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("panel", style)
		var marker := _label("A", 32, MUTED)
		marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(marker)
		stack.add_child(slot)
		foundations.add_child(stack)
	box.add_child(_label("02   FIVE ROWS", 17, Color("d1ac78")))
	var rows := HFlowContainer.new()
	rows.add_theme_constant_override("h_separation", 22)
	box.add_child(rows)
	for row in state.rows:
		var card := BurnsCardView.new()
		card.card_id = row[0]
		rows.add_child(card)
	box.add_child(_label("03   A PLACE FOR EVERYONE", 17, Color("d1ac78")))
	var seats := HFlowContainer.new()
	seats.add_theme_constant_override("h_separation", 26)
	seats.add_theme_constant_override("v_separation", 20)
	box.add_child(seats)
	for index in range(player_count):
		var seat := VBoxContainer.new()
		seat.add_child(_label("Player %d" % (index + 1), 20))
		var card := BurnsCardView.new()
		card.face_down = true
		seat.add_child(card)
		seat.add_child(_label("%d cards · discard 0" % state.players[index].play.size(), 15, MUTED))
		seats.add_child(seat)

func _show_rules() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	content.add_child(box)
	box.add_child(_button("‹ Home", _show_menu))
	box.add_child(_label("The family rules", 46))
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 23)
	text.add_theme_color_override("default_color", CREAM)
	text.text = "Gather 2–8 players. The six-suit deck has 78 cards: diamonds, clubs, cherries, spades, hearts, and dice, each Ace through King.\n\nDeal five cards face up into the rows. Deal the rest face down to the players. Each player also has a discard pile. Never inspect a play pile before its owner’s turn.\n\nOn your turn, play to the Aces area first, then the rows, then other players’ discards, where possible. You may play from your discard or the top of your play pile. Discarding ends your turn.\n\nSpot a missed play? Call Burns before the next player picks up a card. An incorrect play can also be challenged after the player releases the card.\n\nA correctly burnt player receives one card from every other player, taken from their play pile or discard. These cards go on the bottom of the burnt player’s face-down pile.\n\nRules still to confirm: row and discard building, moving rows, filling spaces, winning, false calls, simultaneous callers, and deck variants. This preview does not yet adjudicate a game."
	box.add_child(text)
