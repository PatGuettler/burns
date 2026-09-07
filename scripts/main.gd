extends Control

const CREAM := Color("f4ead6")
const MUTED := Color("adc3bd")
const GOLD := Color("d1ac78")
var content: MarginContainer
var player_count := 4
var game: BurnsGame
var state: Dictionary = {}
var mode := "local"
var screen := "menu"
var selected: Dictionary = {}
var net: BurnsNetwork
var room: Dictionary = {}
var local_seat := 0
var message := ""
var handed_to := -1
var bot_wait := 0.0
var sound_on := true
var player: AudioStreamPlayer
var table_scroll: ScrollContainer
var scroll_position := 0
var settings := ConfigFile.new()
var save_enabled := true
var offline_mode := "local"
const SAVE := "user://burns-save.cfg"

func _ready() -> void:
	net = BurnsNetwork.new()
	add_child(net)
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := 9080
		var address := "127.0.0.1"
		for arg in args:
			if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
			if arg.begins_with("--bind="): address = arg.trim_prefix("--bind=")
			if arg.begins_with("--server-store="): net.store_path = arg.trim_prefix("--server-store=")
		var err := net.serve(port, address)
		if err != OK: push_error("Cannot listen: %s" % error_string(err)); get_tree().quit(1)
		return
	settings.load("user://settings.cfg")
	sound_on = settings.get_value("audio", "enabled", true)
	net.credentials = settings.get_value("network", "credentials", {})
	net.current_url = settings.get_value("network", "url", "")
	player = AudioStreamPlayer.new()
	add_child(player)
	net.changed.connect(_online_state)
	net.notice.connect(func(text: String): message = text; _refresh())
	var background := TextureRect.new()
	background.texture = preload("res://assets/art/card_room_standard.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.05, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 24)
	add_child(content)
	_show_menu()

func _process(delta: float) -> void:
	if not content or screen != "game" or mode != "bots" or not game: return
	bot_wait -= delta
	if bot_wait > 0: return
	bot_wait = 0.8
	var seat := _actor()
	if seat > 0:
		var action := BurnsBot.choose(game, seat)
		if not action.is_empty(): _act(action, seat)

func _clear() -> void:
	if table_scroll and is_instance_valid(table_scroll): scroll_position = table_scroll.scroll_vertical
	table_scroll = null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _paragraph(text: String, font_size := 18, color := MUTED) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", CREAM)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("a34b32") if primary else Color("16383c")
		if key == "hover": style.bg_color = style.bg_color.lightened(0.15)
		if key == "disabled": style.bg_color = Color("253335")
		style.border_color = GOLD if key == "focus" else Color("7b7760")
		style.set_border_width_all(2 if key == "focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(key, style)
	button.pressed.connect(action)
	return button

func _flow(parent: Node) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 12)
	parent.add_child(flow)
	return flow

func _page(title: String) -> VBoxContainer:
	_clear()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	content.add_child(outer)
	var header := _flow(outer)
	header.add_child(_button("‹ Home", _show_menu))
	header.add_child(_label(title, 30))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	return box

func _show_menu() -> void:
	screen = "menu"
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(_label("THE FAMILY CARD TABLE", 16, GOLD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label("Burns", 92))
	box.add_child(_paragraph("A little solitaire. A little rivalry.", 26, CREAM))
	box.add_child(_paragraph("Play your cards. Watch the table.\nCatch the move they missed.", 20))
	var actions := _flow(box)
	actions.add_child(_button("Pass & play", func(): _setup("local"), true))
	actions.add_child(_button("Play computers", func(): _setup("bots")))
	actions.add_child(_button("Online table", _online_setup))
	var extras := _flow(box)
	if game or not room.is_empty() or FileAccess.file_exists(SAVE): extras.add_child(_button("Resume game", _resume))
	extras.add_child(_button("How to play", _show_rules))
	extras.add_child(_button("Sound: on" if sound_on else "Sound: off", _toggle_sound))
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(bottom)
	box.add_child(_paragraph(message if not message.is_empty() else "2–8 PLAYERS  /  52 CARDS  /  ONE SHARP EYE", 16, GOLD))

func _toggle_sound() -> void:
	sound_on = not sound_on
	settings.set_value("audio", "enabled", sound_on)
	settings.save("user://settings.cfg")
	_show_menu()

func _setup(new_mode: String) -> void:
	screen = "setup"
	var box := _page("Gather your table")
	box.add_child(_paragraph("Everyone takes a turn on this device." if new_mode == "local" else "You are Player 1. The other seats are computer opponents."))
	var row := _flow(box)
	row.add_child(_label("Number of players", 22))
	var count := SpinBox.new()
	count.min_value = 2
	count.max_value = 8
	count.value = player_count
	count.custom_minimum_size = Vector2(130, 52)
	count.value_changed.connect(func(value: float): player_count = int(value))
	row.add_child(count)
	box.add_child(_paragraph("Aces first, then rows, then opponents’ discards. Tap a card to select it, then tap its destination. Discard to end your turn; everyone else can call Burns or pass."))
	box.add_child(_button("Deal a new game", func(): _new_game(new_mode), true))
	if game or FileAccess.file_exists(SAVE): box.add_child(_paragraph("Dealing replaces the saved offline game."))

func _new_game(new_mode: String) -> void:
	net.disconnect_room()
	mode = new_mode
	offline_mode = new_mode
	game = BurnsGame.new()
	var names: Array = []
	for i in range(player_count): names.append("You" if mode == "bots" and i == 0 else (("Computer %d" if mode == "bots" else "Player %d") % (i + 1)))
	game.start(names, randi())
	state = game.view()
	handed_to = -1
	selected = {}
	message = ""
	scroll_position = 0
	_save()
	_show_table()

func _actor() -> int:
	if state.is_empty(): return -1
	match state.phase:
		"turn": return int(state.active)
		"review": return int(state.reviewers[0]) if not state.reviewers.is_empty() else -1
		"penalty": return int(state.donors[0]) if not state.donors.is_empty() else -1
	return -1

func _can_act() -> bool:
	if mode == "online":
		if not net.connected: return false
		for seat in room.get("seats", []):
			if not seat.connected: return false
		if state.phase == "review": return local_seat in state.reviewers
		return local_seat == _actor()
	return mode == "local" or _actor() == 0

func _show_table() -> void:
	if state.is_empty(): return
	screen = "game"
	var actor := _actor()
	if mode == "local" and state.phase == "turn" and actor != handed_to:
		_handoff(actor)
		return
	_clear()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	content.add_child(outer)
	var header := _flow(outer)
	header.add_child(_button("‹ Home", _show_menu))
	header.add_child(_label("Burns", 32, GOLD))
	header.add_child(_label("Turn %d · %s" % [state.turn, state.players[state.active].name], 22))
	header.add_child(_button("Rules", _show_rules))
	if mode == "online": header.add_child(_label("Room " + str(room.get("room", "")), 17, MUTED))
	var status := ""
	match state.phase:
		"turn": status = "%s: select a card, then its destination." % state.players[state.active].name
		"review": status = "Turn ended. %s: call Burns or pass." % state.players[actor].name
		"penalty": status = "%s is burnt. %s: choose a penalty card." % [state.players[state.burnt].name, state.players[actor].name]
		"finished": status = "%s wins! Every card is gone." % state.players[state.winner].name
	outer.add_child(_paragraph(status, 21, CREAM))
	if not message.is_empty(): outer.add_child(_paragraph(message, 17, GOLD))
	if mode == "online":
		for seat in room.get("seats", []):
			if not seat.connected: outer.add_child(_paragraph("Paused · waiting for %s to reconnect." % seat.name, 18, GOLD))
		if not net.connected: outer.add_child(_button("Reconnect", _reconnect, true))
	table_scroll = ScrollContainer.new()
	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(table_scroll)
	var board := VBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 16)
	table_scroll.add_child(board)
	board.add_child(_label("01   ACES FIRST", 15, GOLD))
	var foundations := _flow(board)
	for suit in range(4):
		var column := VBoxContainer.new()
		foundations.add_child(column)
		column.add_child(_label(BurnsDeck.SUITS[suit], 16))
		var pile: Array = state.foundations[suit]
		if pile.is_empty():
			var slot := _button("A\n" + BurnsDeck.SYMBOLS[suit], func(): _target("foundation", suit))
			slot.custom_minimum_size = Vector2(76, 114)
			column.add_child(slot)
		else: _card(column, int(pile.back()), func(): _target("foundation", suit), {}, false, 114)
	board.add_child(_label("02   FIVE ROWS · DOWN, ALTERNATING COLORS", 15, GOLD))
	var rows := _flow(board)
	for index in range(5):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		rows.add_child(column)
		var destination := _button(str(index + 1), func(): _target("row", index))
		destination.custom_minimum_size.x = 76
		column.add_child(destination)
		var pile: Array = state.rows[index]
		if pile.is_empty():
			var slot := _button("+", func(): _target("row", index))
			slot.custom_minimum_size = Vector2(76, 114)
			column.add_child(slot)
		else:
			# Overlap sequences while keeping every rank tappable and keyboard reachable.
			var stack := Control.new()
			stack.custom_minimum_size = Vector2(76, 114 + (pile.size() - 1) * 42)
			column.add_child(stack)
			for offset in range(pile.size()):
				var source := {"source": "row", "index": index, "offset": offset}
				var button := _card(stack, int(pile[offset]), func(): _select_or_target(source, "row", index), source, false, 114)
				button.position.y = offset * 42
	board.add_child(_label("03   THE PLAYERS · DISCARD UP OR DOWN", 15, GOLD))
	var seats := _flow(board)
	for i in range(state.players.size()):
		var p: Dictionary = state.players[i]
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 184
		seats.add_child(column)
		var total := int(p.play_count + p.discard_count + p.reserve_count) + (1 if p.held >= 0 else 0)
		column.add_child(_label("%s · %d" % [p.name, total], 18, GOLD if i == state.active else CREAM))
		var piles := HBoxContainer.new()
		piles.add_theme_constant_override("separation", 8)
		column.add_child(piles)
		if p.play_count > 0:
			_card(piles, 0, func(): _pile_action(i, "play"), {}, true, 114)
		else:
			var empty := _button("—", func(): _pile_action(i, "play"))
			empty.custom_minimum_size = Vector2(76, 114)
			piles.add_child(empty)
		if p.discard_top >= 0:
			var source := {"source": "discard", "index": i, "offset": 0}
			_card(piles, int(p.discard_top), func(): _pile_action(i, "discard"), source, false, 114)
		else:
			var empty := _button("Discard", func(): _pile_action(i, "discard"))
			empty.custom_minimum_size = Vector2(76, 114)
			piles.add_child(empty)
		column.add_child(_label("%d hidden · %d discarded" % [p.play_count, p.discard_count], 14, MUTED))
		if p.reserve_count > 0:
			column.add_child(_label("Open pile · %d cards" % p.reserve_count, 15, GOLD))
			var source := {"source": "reserve", "index": i, "offset": 0}
			_card(column, int(p.reserve_top), func(): _pile_action(i, "reserve"), source, false, 114)
			if i == state.active and state.phase == "turn" and _can_act():
				column.add_child(_button("Reveal bottom", func(): _act({"type": "draw", "source": "bottom"})))
		if p.held >= 0:
			column.add_child(_label("Revealed card", 15, GOLD))
			var source := {"source": "held", "index": 0, "offset": 0}
			_card(column, int(p.held), func(): _select(source), source, false, 114)
	var log_box := VBoxContainer.new()
	board.add_child(log_box)
	log_box.add_child(_label("AT THE TABLE", 15, GOLD))
	for entry in state.log.slice(maxi(0, state.log.size() - 4)):
		log_box.add_child(_paragraph(str(entry), 16))
	var controls := _flow(outer)
	if _can_act():
		match state.phase:
			"turn":
				controls.add_child(_button("Reveal top card", func(): _act({"type": "draw"})))
				controls.add_child(_button("Discard / end turn", func(): _act({"type": "end"}), true))
				if mode != "online": controls.add_child(_button("Hint", _hint))
				if not selected.is_empty(): controls.add_child(_button("Cancel selection", func(): selected = {}; _show_table()))
			"review":
				controls.add_child(_button("Call BURNS", func(): _act({"type": "burn"}), true))
				controls.add_child(_button("Pass · no challenge", func(): _act({"type": "pass"})))
			"penalty":
				for source in ["play", "discard", "reserve"]:
					if state.players[actor][source + "_count"] > 0:
						controls.add_child(_button("Give " + {"play": "hidden top", "discard": "discard top", "reserve": "open-pile top"}[source], func(): _act({"type": "donate", "source": source}), true))
	if state.phase == "finished": controls.add_child(_button("Back to the card room", _show_menu, true))
	if table_scroll: table_scroll.set_deferred("scroll_vertical", scroll_position)

func _card(parent: Node, id: int, action: Callable, source: Dictionary, back := false, height := 114) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(76, height)
	button.size = button.custom_minimum_size
	button.clip_contents = false
	button.tooltip_text = "Hidden play pile" if back else BurnsDeck.card_name(id)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var art := BurnsCardView.new()
	art.card_id = id
	art.face_down = back
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(art)
	if not source.is_empty() and source == selected:
		art.modulate = Color("ffe49c")
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _select(source: Dictionary) -> void:
	if not _can_act() or state.phase != "turn": return
	selected = source
	message = "Card selected. Tap an Ace pile, row heading, or another player's discard."
	_show_table()

func _select_or_target(source: Dictionary, target: String, index: int) -> void:
	if not selected.is_empty() and selected != source: _target(target, index)
	else: _select(source)

func _target(target: String, index: int) -> void:
	if selected.is_empty(): message = "Select the card you want to move first."; _show_table(); return
	var action := selected.duplicate()
	action.merge({"type": "move", "target": target, "to": index})
	_act(action)

func _pile_action(seat: int, source: String) -> void:
	if state.phase != "turn" or not _can_act(): return
	if source == "discard" and seat != state.active: _target("opponent", seat)
	elif seat == state.active:
		if source == "play": _act({"type": "draw"})
		else: _select({"source": source, "index": seat, "offset": 0})

func _handoff(actor: int) -> void:
	var box := _page("Pass the table")
	box.add_child(_label(state.players[actor].name, 46, GOLD))
	box.add_child(_paragraph("Your cards are waiting. Take the device, then begin your turn. The next hidden card stays covered until you choose to reveal it.", 23))
	box.add_child(_button("I'm ready", func(): handed_to = actor; _show_table(), true))

func _act(action: Dictionary, seat := -1) -> void:
	if seat == -1: seat = local_seat if mode == "online" else _actor()
	if mode == "online":
		if not _can_act(): return
		net.send_action(action, int(state.revision))
		return
	var error := game.act(seat, action)
	if error.is_empty():
		selected = {}
		message = ""
		state = game.view()
		_save()
		_tone(action.get("type") == "burn")
	else: message = error
	_show_table()

func _hint() -> void:
	var available := game.moves().filter(func(m: Dictionary): return not m.optional)
	available.sort_custom(func(a: Dictionary, b: Dictionary): return a.priority < b.priority)
	if available.is_empty(): message = "No exposed card has a required play. Reveal a card or discard to end your turn."
	else:
		var move: Dictionary = available[0]
		message = game.describe(move)
		selected = {"source": move.source, "index": move.index, "offset": move.offset}
	_show_table()

func _save() -> void:
	if mode == "online" or not game or not save_enabled: return
	var file := ConfigFile.new()
	file.set_value("game", "state", game.s)
	file.set_value("game", "mode", mode)
	var error := file.save(SAVE + ".tmp")
	if error == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE + ".tmp"), ProjectSettings.globalize_path(SAVE))
	else: message = "Could not save this game on the device."

func _resume() -> void:
	if mode == "online" and not room.is_empty():
		if state.is_empty(): _lobby()
		else: _show_table()
		return
	mode = offline_mode
	if not game:
		var file := ConfigFile.new()
		if file.load(SAVE) != OK: message = "The saved game could not be opened."; _show_menu(); return
		var saved = file.get_value("game", "state", {})
		game = BurnsGame.new()
		if not game.restore(saved): game = null; message = "Saved game failed validation."; _show_menu(); return
		mode = str(file.get_value("game", "mode", "local"))
	state = game.view()
	handed_to = -1
	_show_table()

func _tone(burn := false) -> void:
	if not sound_on: return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	var duration := 0.22 if burn else 0.07
	var samples := int(duration * stream.mix_rate)
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / stream.mix_rate
		var envelope := sin(PI * i / samples) * exp(-t * 16)
		var frequency := (330.0 + t * 600) if burn else 740.0
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * t) * envelope * 2200))
	stream.data = bytes
	player.stream = stream
	player.play()

func _online_setup() -> void:
	screen = "online"
	var box := _page("An online table")
	box.add_child(_paragraph("Create a private room or join friends using their room code. Everyone connects to the same Burns server."))
	var url := LineEdit.new()
	url.placeholder_text = "Server address (wss://…)"
	url.text = settings.get_value("network", "url", "ws://127.0.0.1:9080")
	url.custom_minimum_size.y = 52
	box.add_child(url)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Your name"
	name_field.text = settings.get_value("network", "name", "Player")
	name_field.max_length = 24
	name_field.custom_minimum_size.y = 52
	box.add_child(name_field)
	var code := LineEdit.new()
	code.placeholder_text = "Room code · leave blank to create a room"
	code.max_length = 8
	code.custom_minimum_size.y = 52
	box.add_child(code)
	box.add_child(_button("Take a seat", func():
		mode = "online"
		settings.set_value("network", "url", url.text.strip_edges())
		settings.set_value("network", "name", name_field.text.strip_edges())
		settings.save("user://settings.cfg")
		var error := net.connect_room(url.text.strip_edges(), name_field.text, code.text)
		message = "Connecting…" if error == OK else "Could not connect: " + error_string(error)
		_refresh(), true))
	if not net.credentials.is_empty(): box.add_child(_button("Reconnect to previous seat", _reconnect))
	box.add_child(_paragraph(message, 18, GOLD))

func _online_state(snapshot: Dictionary) -> void:
	room = snapshot
	local_seat = int(snapshot.seat)
	settings.set_value("network", "credentials", net.credentials)
	settings.save("user://settings.cfg")
	state = snapshot.game
	selected = {}
	message = ""
	if state.is_empty(): _lobby()
	else: _show_table()

func _lobby() -> void:
	screen = "lobby"
	var box := _page("Your private table")
	box.add_child(_label(str(room.get("room", "")), 48, GOLD))
	box.add_child(_paragraph("Share this room code with your family. The host starts when everyone is here."))
	for seat in room.get("seats", []):
		box.add_child(_label("%s · %s" % [seat.name, "ready" if seat.connected else "reconnecting"], 22))
	if local_seat == 0:
		var start := _button("Start game", func(): net.start_room(), true)
		start.disabled = room.get("seats", []).size() < 2
		box.add_child(start)
	if not net.connected: box.add_child(_button("Reconnect", _reconnect))
	box.add_child(_paragraph(message, 18, GOLD))

func _reconnect() -> void:
	var error := net.connect_room(net.current_url, "", "", true)
	message = "Reconnecting…" if error == OK else error_string(error)
	_refresh()

func _refresh() -> void:
	match screen:
		"game": _show_table()
		"lobby": _lobby()
		"online": _online_setup()
		_: _show_menu()

func _show_rules() -> void:
	screen = "rules"
	var box := _page("How to play Burns")
	if not state.is_empty(): box.add_child(_button("Return to the table", _show_table, true))
	var sections := [
		["01 · Make room at the table", "2–8 players share a standard 52-card deck. Five cards start face up as rows; the rest are dealt face down. The four Ace piles build upward, by suit, from Ace to King."],
		["02 · Play in order", "Play to the Aces first, then the rows, then other players’ discards. Rows build down one rank in alternating colors. Move a card with the sequence below it onto a fitting row. Any card can fill an empty row. A row’s exposed last card can go to its Ace pile."],
		["03 · Share the trouble", "Opponents’ discards build one rank up OR down, in alternating colors. An empty discard accepts any card. Ace and King do not wrap. Only your own discard is a source; opponents’ piles are destinations."],
		["04 · Reveal, play, discard", "Only reveal your own top card on your turn. Play it, play from your discard, or move the rows. Discard the revealed card to end your turn. The game rejects placements that do not fit, but lets you miss plays or skip priority—watch for Burns."],
		["05 · When the hidden pile runs out", "Your discard becomes an open pile, in the same order. Play its exposed top or reveal its bottom. When you discard again, the remaining open pile becomes face down, without shuffling; its former top is drawn next."],
		["06 · Call Burns", "Only after the turn ends, each other player calls Burns or passes. A missed required play or skipped priority burns the player. A false call burns the caller instead. Every other player gives one card from their hidden top, discard top, or open-pile top. Gifts go underneath the burnt player’s hidden pile, in clockwise donor order."],
		["07 · Win the table", "Get rid of every personal card, including your discard and open pile. Victory is confirmed after the final Burns window and any penalties. You can also win by donating your last card."],
		["A note about rearranging", "Splitting a row or moving it into an empty row is optional, so endless rearrangements cannot force a Burns. Moving a whole row onto a fitting occupied row frees a space and is required. Unrevealed cards never count as missed plays. Everyone passes explicitly; there is no reaction timer."],
		["Controls", "Tap a card, then an Ace pile, row heading, or opponent discard. Tap a row card to move it with everything below. Keyboard: Tab to focus, Enter or Space to select. Offline games save after every action. Sound can be turned off on the home screen."]]
	for section in sections:
		box.add_child(_label(section[0], 23, GOLD))
		box.add_child(_paragraph(section[1], 20, CREAM))
