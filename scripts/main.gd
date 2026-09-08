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
var rules_page := 0
var row_inspection := -1
var setup_mode := "local"
var resizing := false
var online_url := ""
var online_name := ""
var online_code := ""
var burn_title := ""
var burn_explanation := ""
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
	_sync_display_density()
	get_window().size_changed.connect(_sync_display_density)
	_apply_ui_theme()
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
		content.add_theme_constant_override("margin_" + side, 16)
	add_child(content)
	resized.connect(_schedule_layout)
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
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(maxf(44, ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24), 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", CREAM)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("b85637") if primary else Color(0.10, 0.23, 0.24, 0.46)
		if key == "hover": style.bg_color = style.bg_color.lightened(0.15)
		if key == "disabled": style.bg_color = Color("253335")
		style.border_color = GOLD
		style.set_border_width_all(2 if key == "focus" else 0)
		style.set_corner_radius_all(28)
		style.content_margin_left = 12
		style.content_margin_right = 12
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
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	outer.add_child(box)
	return box

func _show_menu() -> void:
	screen = "menu"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	var landscape := bounds.y < 500 and bounds.x > 620
	var menu_w := minf(420, bounds.x)
	var title_y := 38.0 if landscape else clampf(bounds.y * 0.12, 36, 110)
	layer.label_at("THE FAMILY CARD TABLE", Rect2(0, 0, bounds.x, 24), 13, GOLD)
	layer.label_at("Burns", Rect2(0, title_y, bounds.x, 92), 76 if bounds.x < 600 else 88, CREAM)
	layer.label_at("A little solitaire. A little rivalry.", Rect2(0, title_y + 96, minf(bounds.x, 520), 36), 18 if landscape else 20, MUTED)
	var action_x := bounds.x * 0.53 if landscape else 0.0
	if landscape: menu_w = bounds.x - action_x
	var action_y := 40.0 if landscape else title_y + 154
	var actions: Array = [["Pass & play  >", func(): _setup("local"), true], ["Play computers  >", func(): _setup("bots"), false], ["Online table  >", _online_setup, false]]
	for i in range(actions.size()):
		var item: Array = actions[i]
		layer.place(_button(item[0], item[1], item[2]), Rect2(action_x, action_y + i * 56, menu_w, 48))
	var extras_y := action_y + 176
	var extras: Array = []
	if game or not room.is_empty() or FileAccess.file_exists(SAVE): extras.append(["Resume", _resume])
	extras.append(["Rules", _show_rules])
	extras.append(["Sound on" if sound_on else "Sound off", _toggle_sound])
	var ew := (menu_w - (extras.size() - 1) * 8) / extras.size()
	for i in range(extras.size()):
		layer.place(_button(extras[i][0], extras[i][1]), Rect2(action_x + i * (ew + 8), extras_y, ew, 44))
	layer.label_at(message if not message.is_empty() else "2–8 PLAYERS  ·  52 CARDS  ·  ONE SHARP EYE", Rect2(0, bounds.y - 24, bounds.x, 24), 12, GOLD)

func _toggle_sound() -> void:
	sound_on = not sound_on
	settings.set_value("audio", "enabled", sound_on)
	settings.save("user://settings.cfg")
	_show_menu()

func _setup(new_mode: String) -> void:
	screen = "setup"
	setup_mode = new_mode
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.place(_button("‹ Back", _show_menu), Rect2(0, 0, 90, 44))
	layer.label_at("Gather your table", Rect2(102, 0, bounds.x - 102, 44), 23, GOLD)
	var introduction := "Take turns on this device." if new_mode == "local" else "You are Player 1. Play against computer opponents."
	var intro := _paragraph(introduction, 19, CREAM)
	layer.place(intro, Rect2(0, 64, bounds.x, 52))
	layer.place(_button("-", func(): player_count = maxi(2, player_count - 1); _setup(new_mode)), Rect2(bounds.x / 2 - 92, 124, 48, 48))
	var count := layer.label_at(str(player_count), Rect2(bounds.x / 2 - 38, 124, 76, 48), 34, GOLD)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.place(_button("+", func(): player_count = mini(8, player_count + 1); _setup(new_mode)), Rect2(bounds.x / 2 + 44, 124, 48, 48))
	var description := _paragraph("Aces first, then rows, then opponents’ discards. Tap a card and its destination. Discard to end your turn; everyone else can call Burns or pass.", 17 if bounds.y > 440 else 14)
	layer.place(description, Rect2(0, 196, bounds.x, bounds.y - 262))
	layer.place(_button("Deal a new game", func(): _new_game(new_mode), true), Rect2(0, bounds.y - 48, bounds.x, 48))

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
	var table := BurnsTableView.new()
	content.add_child(table)
	table.build(self, size - Vector2(32, 32))

func _inspect_row(row: int) -> void:
	if state.is_empty(): return
	screen = "row"
	row_inspection = row
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	layer.state = state
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.place(_button("‹ Table", _show_table), Rect2(0, 0, 110, 44))
	layer.label_at("Row %d · choose a sequence" % (row + 1), Rect2(118, 0, bounds.x - 118, 44), 18, GOLD)
	var pile: Array = state.rows[row]
	var columns := 4 if bounds.x < 600 else 7
	var rows := maxi(1, int(ceil(float(pile.size()) / columns)))
	var cell := Vector2(bounds.x / columns, (bounds.y - 68) / rows)
	var ch := minf(cell.y - 12, (cell.x - 12) * 1.48)
	var cw := ch / 1.48
	for offset in range(pile.size()):
		var source := {"source": "row", "index": row, "offset": offset}
		var rect := Rect2((offset % columns) * cell.x + (cell.x - cw) / 2, 60 + (offset / columns) * cell.y, cw, ch)
		layer._card(rect, int(pile[offset]), func():
			selected = source
			message = "Sequence selected · tap a destination"
			_show_table(), source)

func _schedule_layout() -> void:
	if resizing or not content: return
	resizing = true
	call_deferred("_relayout")

func _relayout() -> void:
	resizing = false
	match screen:
		"game": _show_table()
		"menu": _show_menu()
		"rules": _show_rules()
		"setup": _setup(setup_mode)
		"row": _inspect_row(row_inspection)
		"burn_result": _show_burn_result()
		"lobby": _lobby()
		"online": _online_setup()

func _select(source: Dictionary) -> void:
	if not _can_act() or state.phase != "turn": return
	selected = source
	message = "Selected · tap a destination"
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
		elif source == "discard" and selected.get("source") == "held": _act({"type": "end"})
		elif state.players[seat][source + "_count"] > 0: _select({"source": source, "index": seat, "offset": 0})

func _handoff(actor: int) -> void:
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.place(_button("‹ Home", _show_menu), Rect2(0, 0, 96, 44))
	layer.label_at("Pass the table", Rect2(108, 0, bounds.x - 108, 44), 23, GOLD)
	layer.label_at(state.players[actor].name, Rect2(0, 64, bounds.x, 56), 38, GOLD)
	var text := _paragraph("Take the device, then begin your turn. Your next hidden card stays covered until you choose to reveal it.", 21 if bounds.y > 500 else 17, CREAM)
	layer.place(text, Rect2(0, 136, bounds.x, bounds.y - 200))
	layer.place(_button("I'm ready", func(): handed_to = actor; _show_table(), true), Rect2(0, bounds.y - 48, bounds.x, 48))

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
		if action.get("type") == "draw": selected = {"source": "held", "index": 0, "offset": 0}
		_save()
		_tone(action.get("type") == "burn")
	else: message = error
	if error.is_empty() and action.get("type") == "burn":
		_prepare_burn_result()
	else:
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
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	var compact := bounds.y < 500
	layer.place(_button("‹ Back", _show_menu), Rect2(0, 0, 90, 44))
	layer.label_at("Online table", Rect2(102, 0, bounds.x - 102, 44), 24, GOLD)
	layer.label_at("Use the same server as your friends.", Rect2(0, 56, bounds.x, 30), 16, MUTED)
	if online_url.is_empty(): online_url = settings.get_value("network", "url", "ws://127.0.0.1:9080")
	if online_name.is_empty(): online_name = settings.get_value("network", "name", "Player")
	var url := LineEdit.new()
	url.placeholder_text = "Server address (wss://…)"
	url.text = online_url
	_style_input(url)
	url.text_changed.connect(func(value: String): online_url = value)
	layer.place(url, Rect2(0, 100, bounds.x, 46))
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Your name"
	name_field.text = online_name
	name_field.max_length = 24
	_style_input(name_field)
	name_field.text_changed.connect(func(value: String): online_name = value)
	layer.place(name_field, Rect2(0, 158, (bounds.x - 12) / 2 if compact else bounds.x, 46))
	var code := LineEdit.new()
	code.placeholder_text = "Room code (blank = new)"
	code.text = online_code
	code.max_length = 8
	_style_input(code)
	code.text_changed.connect(func(value: String): online_code = value)
	layer.place(code, Rect2((bounds.x + 12) / 2 if compact else 0.0, 158 if compact else 216, (bounds.x - 12) / 2 if compact else bounds.x, 46))
	var button_y := 216.0 if compact else 278.0
	layer.place(_button("Take a seat", func():
		mode = "online"
		settings.set_value("network", "url", online_url.strip_edges())
		settings.set_value("network", "name", online_name.strip_edges())
		settings.save("user://settings.cfg")
		var error := net.connect_room(online_url.strip_edges(), online_name, online_code)
		message = "Connecting…" if error == OK else "Could not connect: " + error_string(error)
		_refresh(), true), Rect2(0, button_y, bounds.x, 46))
	if not net.credentials.is_empty(): layer.place(_button("Reconnect to previous seat", _reconnect), Rect2(0, button_y + 54, bounds.x, 44))
	layer.label_at(message, Rect2(0, bounds.y - 24, bounds.x, 24), 14, GOLD)

func _online_state(snapshot: Dictionary) -> void:
	var previous_phase: String = state.get("phase", "")
	var keep_result := screen == "burn_result"
	room = snapshot
	local_seat = int(snapshot.seat)
	settings.set_value("network", "credentials", net.credentials)
	settings.save("user://settings.cfg")
	state = snapshot.game
	selected = {}
	message = ""
	if state.is_empty(): _lobby()
	elif keep_result: _show_burn_result()
	elif previous_phase == "review" and state.phase == "penalty": _prepare_burn_result()
	else: _show_table()

func _lobby() -> void:
	screen = "lobby"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.place(_button("‹ Back", _show_menu), Rect2(0, 0, 90, 44))
	layer.label_at("Your private table", Rect2(102, 0, bounds.x - 102, 44), 22, GOLD)
	layer.label_at(str(room.get("room", "")), Rect2(0, 54, bounds.x, 48), 40, GOLD)
	layer.label_at("Share the code. The host starts the game.", Rect2(0, 108, bounds.x, 26), 15, MUTED)
	var seats: Array = room.get("seats", [])
	var columns := 4 if bounds.x > 600 else 2
	for i in range(seats.size()):
		var cell_w := bounds.x / columns
		var label := _paragraph("%s\n%s" % [seats[i].name, "Ready" if seats[i].connected else "Reconnecting"], 16, CREAM)
		layer.place(label, Rect2((i % columns) * cell_w, 152 + (i / columns) * 56, cell_w - 8, 50))
	if not net.connected:
		layer.place(_button("Reconnect", _reconnect, true), Rect2(0, bounds.y - 48, bounds.x, 48))
	elif local_seat == 0:
		var start := _button("Start game", func(): net.start_room(), true)
		start.disabled = seats.size() < 2
		layer.place(start, Rect2(0, bounds.y - 48, bounds.x, 48))

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
	_clear()
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
	var section: Array = sections[rules_page]
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.place(_button("‹ Back", _show_table if not state.is_empty() else _show_menu), Rect2(0, 0, 100, 44))
	layer.label_at("How to play", Rect2(114, 0, bounds.x - 114, 44), 24, GOLD)
	var title := _paragraph(section[0], 23, GOLD)
	layer.place(title, Rect2(0, 64, bounds.x, 64))
	var text := _paragraph(section[1], 19, CREAM)
	var font := ThemeDB.fallback_font
	var font_size := 21
	var body_h := bounds.y - 192
	while font_size > 13 and font.get_multiline_string_size(section[1], HORIZONTAL_ALIGNMENT_LEFT, bounds.x, font_size).y > body_h:
		font_size -= 1
	text.add_theme_font_size_override("font_size", font_size)
	layer.place(text, Rect2(0, 128, bounds.x, body_h))
	var bw := (bounds.x - 74) / 2
	layer.place(_button("‹ Previous", func(): rules_page = (rules_page - 1 + sections.size()) % sections.size(); _show_rules()), Rect2(0, bounds.y - 44, bw, 44))
	var count := layer.label_at("%d / %d" % [rules_page + 1, sections.size()], Rect2(bw + 6, bounds.y - 44, 62, 44), 16, GOLD)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.place(_button("Next ›", func(): rules_page = (rules_page + 1) % sections.size(); _show_rules(), true), Rect2(bounds.x - bw, bounds.y - 44, bw, 44))

func _style_input(field: LineEdit) -> void:
	field.custom_minimum_size.y = 46
	field.context_menu_enabled = false
	field.add_theme_font_size_override("font_size", 16)
	field.add_theme_color_override("font_color", CREAM)
	for key in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("153b40")
		style.set_corner_radius_all(22)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.set_border_width_all(1 if key == "focus" else 0)
		style.border_color = GOLD
		field.add_theme_stylebox_override(key, style)

func _prepare_burn_result() -> void:
	burn_title = "Burns confirmed" if state.burnt == state.active else "False call"
	burn_explanation = "\n\n".join(PackedStringArray(state.log.slice(maxi(0, state.log.size() - 2))))
	_show_burn_result()

func _show_burn_result() -> void:
	screen = "burn_result"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := size - Vector2(32, 32)
	layer.size = bounds
	layer.label_at(burn_title, Rect2(0, 12, bounds.x, 56), 34, GOLD)
	var text := _paragraph(burn_explanation, 21 if bounds.y > 500 else 16, CREAM)
	layer.place(text, Rect2(0, 88, bounds.x, bounds.y - 160))
	layer.place(_button("Continue to the table", _show_table, true), Rect2(0, bounds.y - 48, bounds.x, 48))

func _sync_display_density() -> void:
	# Canvas dimensions are physical pixels on Retina/high-DPI screens. Layout uses
	# logical pixels so a 3x phone still gets phone-sized cards and 44-point controls.
	var density := maxf(1.0, DisplayServer.screen_get_scale())
	if OS.get_name() == "Android": density = maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	elif OS.get_name() == "Windows": density = maxf(1.0, DisplayServer.screen_get_dpi() / 96.0)
	var window := get_window()
	var logical := Vector2i(Vector2(window.size) / density)
	logical.x = maxi(1, logical.x)
	logical.y = maxi(1, logical.y)
	if window.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	if window.content_scale_size != logical: window.content_scale_size = logical

func _apply_ui_theme() -> void:
	theme = Theme.new()
	var tooltip := StyleBoxFlat.new()
	tooltip.bg_color = Color("12383e")
	tooltip.set_corner_radius_all(14)
	tooltip.content_margin_left = 12
	tooltip.content_margin_right = 12
	tooltip.content_margin_top = 8
	tooltip.content_margin_bottom = 8
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", CREAM)
	theme.set_font_size("font_size", "TooltipLabel", 14)
