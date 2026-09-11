extends Control

const DISPLAY_FONT := preload("res://assets/fonts/DejaVuSerif.ttf")
const UI_FONT := preload("res://assets/fonts/DejaVuSans.ttf")
var safe_margins := Vector4(16, 16, 16, 16)
var background_shade: ColorRect
var animations_enabled := true
var active_motion: Control
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
var gallery_card := 0
var gallery_return := "menu"
var gallery_back := false
var gallery_swipe_origin := Vector2.ZERO
var gallery_swiping := false
var previous_screen := ""
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
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.texture = preload("res://assets/art/deck/raven_room.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	background_shade = shade
	shade.color = Color(0.015, 0.04, 0.05, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 16)
	add_child(content)
	_update_safe_area()
	resized.connect(_schedule_layout)
	_show_menu()

func _process(delta: float) -> void:
	if not content or screen != "game" or mode != "bots" or not game: return
	if is_instance_valid(active_motion) and not active_motion.is_queued_for_deletion(): return
	bot_wait -= delta
	if bot_wait > 0: return
	bot_wait = 0.8
	if state.phase == "review":
		for reviewer in state.reviewers:
			if reviewer > 0:
				_act(BurnsBot.choose(game, reviewer), reviewer)
				return
		if _review_turn_ready(): return
		if 0 in state.reviewers:
			_act({"type": "pass"}, 0)
			return
	var seat := _actor()
	if seat > 0:
		var action := BurnsBot.choose(game, seat)
		if not action.is_empty(): _act(action, seat)

func _clear() -> void:
	if is_instance_valid(active_motion): active_motion.queue_free()
	active_motion = null
	if background_shade: background_shade.color.a = 0.30 if screen in ["menu", "deck_gallery"] else 0.62
	if screen != previous_screen:
		previous_screen = screen
		if animations_enabled and not OS.has_feature("headless"):
			content.modulate.a = 0.0
			create_tween().tween_property(content, "modulate:a", 1.0, 0.16)
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

## Quiet actions drop the plate entirely: a page where every choice is an
## identical filled box reads as a default theme rather than a designed screen.
func _button(text: String, action: Callable, primary := false, quiet := false) -> Button:
	var button := BurnsPlateButton.new()
	button.kind = BurnsPlateButton.Kind.PRIMARY if primary else (BurnsPlateButton.Kind.QUIET if quiet else BurnsPlateButton.Kind.PLATE)
	button.text = text
	button.custom_minimum_size = Vector2(maxf(44, UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24), 44)
	button.add_theme_font_size_override("font_size", 16)
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
	var home := BurnsHomeView.new()
	content.add_child(home)
	home.build_home(self, _bounds())

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
	var bounds := _bounds()
	layer.size = bounds
	layer.place(_button("‹ Home", _show_menu), Rect2(0, 0, 88, 44))
	var title := layer.label_at("PASS & PLAY" if new_mode == "local" else "PLAY COMPUTERS", Rect2(100, 0, bounds.x - 100, 44), 13, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var compact := bounds.y < 500
	var header_y := 56.0 if compact else 80.0
	_heading(layer, "Gather your table", Rect2(0, header_y, bounds.x, 48), 25 if compact else 30, true)
	var intro := layer.label_at("One device. Everyone gets a turn." if new_mode == "local" else "You play first. Your rivals are ready.", Rect2(0, header_y + 50, bounds.x, 32), 13, MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count_y := header_y + 92
	layer.place(_button("−", func(): player_count = maxi(2, player_count - 1); _setup(new_mode)), Rect2(bounds.x / 2 - 100, count_y + 4, 48, 48))
	_heading(layer, str(player_count), Rect2(bounds.x / 2 - 40, count_y - 2, 80, 64), 48, true)
	layer.place(_button("+", func(): player_count = mini(8, player_count + 1); _setup(new_mode)), Rect2(bounds.x / 2 + 52, count_y + 4, 48, 48))
	var count_label := layer.label_at("PLAYERS  ·  2–8", Rect2(0, count_y + 60, bounds.x, 22), 11, GOLD)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bounds.y > 550:
		var art_h := minf(200, bounds.y - count_y - 234)
		var art := BurnsCardView.new()
		art.face_down = true
		art.size = Vector2(art_h / 1.5, art_h)
		art.position = Vector2((bounds.x - art.size.x) / 2, count_y + 96)
		layer.add_child(art)
	var hint := layer.label_at("Aces first. Then rows. Then rivals’ discards.", Rect2(0, bounds.y - 88, bounds.x, 28), 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.place(_button("Deal the cards", func(): _new_game(new_mode), true), Rect2(0, bounds.y - 52, bounds.x, 52))

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
	if state.phase == "finished":
		_show_victory()
		return
	screen = "game"
	var actor := _actor()
	if mode == "local" and state.phase == "turn" and actor != handed_to:
		_handoff(actor)
		return
	_clear()
	var table := BurnsTableView.new()
	content.add_child(table)
	table.build(self, _bounds())

func _inspect_row(row: int) -> void:
	if state.is_empty(): return
	screen = "row"
	row_inspection = row
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	layer.state = state
	content.add_child(layer)
	var bounds := _bounds()
	layer.size = bounds
	layer.place(_button("‹ Table", _show_table), Rect2(0, 0, 110, 44))
	# The back button leaves barely half the header on a 320-point phone. The wording
	# stays fixed so rotating the device never rewrites it, and the size gives way instead.
	var header := Rect2(118, 0, bounds.x - 118, 44)
	var title := "Row %d · tap a card" % (row + 1)
	var title_size := 18
	while title_size > 12 and UI_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > header.size.x:
		title_size -= 1
	layer.label_at(title, header, title_size, GOLD)
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
	_update_safe_area()
	match screen:
		"game": _show_table()
		"menu": _show_menu()
		"rules": _show_rules()
		"setup": _setup(setup_mode)
		"row": _inspect_row(row_inspection)
		"burn_caller": _call_burn()
		"deck_gallery": _show_deck_gallery()
		"victory": _show_victory()
		"lobby": _lobby()
		"online": _online_setup()

func _select(source: Dictionary) -> void:
	if not _can_act() or (state.phase != "turn" and not _review_turn_ready()): return
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
	if (state.phase != "turn" and not _review_turn_ready()) or not _can_act(): return
	if source == "discard" and seat != _turn_seat(): _target("opponent", seat)
	elif seat == _turn_seat():
		if source == "play": _act({"type": "draw"})
		elif source == "discard" and selected.get("source") == "held": _act({"type": "end"})
		elif state.players[seat][source + "_count"] > 0: _select({"source": source, "index": seat, "offset": 0})

func _handoff(actor: int) -> void:
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
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
		if not (_can_burn() if action.get("type") == "burn" else _can_act()): return
		net.send_action(action, int(state.revision))
		return
	if seat == 0 and _review_turn_ready() and action.get("type") in ["draw", "move", "end"]:
		game.act(0, {"type": "pass"})
		state = game.view()
		if action.get("source") == "discard" and state.players[0].discard_count == 0 and state.players[0].reserve_count > 0:
			action = action.duplicate()
			action.source = "reserve"
	var motion := BurnsCardMotion.capture(self, action, seat)
	var error := game.act(seat, action)
	if error.is_empty():
		selected = {}
		message = ""
		state = game.view()
		if action.get("type") == "draw": selected = {"source": "held", "index": 0, "offset": 0}
		_save()
		_tone(action.get("type") == "burn")
		if mode == "bots" and action.get("type") == "end" and seat > 0: bot_wait = 2.5
	else: message = error
	if error.is_empty() and action.get("type") == "burn":
		_prepare_burn_result()
	else:
		_show_table()
		if error.is_empty(): BurnsCardMotion.animate(self, motion)

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
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE + ".tmp"), ProjectSettings.globalize_path(SAVE))
	if error != OK: message = "Could not save this game on the device."

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
	var bounds := _bounds()
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
	var previous_burn: int = state.get("burn_serial", 0)
	var keep_gallery := screen == "deck_gallery" and gallery_return == "game"
	room = snapshot
	local_seat = int(snapshot.seat)
	settings.set_value("network", "credentials", net.credentials)
	settings.save("user://settings.cfg")
	state = snapshot.game
	selected = {}
	message = ""
	if state.is_empty(): _lobby()
	elif int(state.get("burn_serial", 0)) > previous_burn: _prepare_burn_result()
	elif keep_gallery: _show_deck_gallery()
	else: _show_table()

func _lobby() -> void:
	screen = "lobby"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
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
		["03 · Share the trouble", "Opponents’ discards build one rank up OR down, in alternating colors. An empty opponent discard cannot be played on. Ace and King do not wrap. Only your own discard is a source; opponents’ piles are destinations."],
		["04 · Reveal, play, discard", "Only reveal your own top card on your turn. Play it, play from your discard, or move the rows. Discard the revealed card to end your turn. The game rejects placements that do not fit, but lets you miss plays or skip priority—watch for Burns."],
		["05 · When the hidden pile runs out", "Your discard becomes an open pile, in the same order. Play its exposed top or reveal its bottom. When you discard again, the remaining open pile becomes face down, without shuffling; its former top is drawn next."],
		["06 · Call Burns", "BURNS! is available to everyone. A correct call requires a missed play or skipped priority after a turn ends. Early, late, and incorrect calls burn the caller. Every other player gives one card from their hidden top, revealed card, discard top, or open-pile top. Gifts go underneath the burnt player’s hidden pile, in clockwise donor order."],
		["07 · Win the table", "Get rid of every personal card, including your discard and open pile. Victory is confirmed after the final Burns window and any penalties. You can also win by donating your last card."],
		["A note about rearranging", "Splitting a row or moving it into an empty row is optional, so endless rearrangements cannot force a Burns. Moving a whole row onto a fitting occupied row frees a space and is required. Unrevealed cards never count as missed plays. Shared-device and online players pass explicitly. Against computers, drawing or playing starts your turn; between computer turns, call Burns during the brief review pause."],
		["Controls", "Drag a card to its destination, or tap to select and place. Hold a face-up card to inspect its artwork. Tap a row card to move it with everything below. Keyboard: Tab to focus, Enter or Space to select. Offline games save after every action. Sound can be turned off on the home screen."]]
	var section: Array = sections[rules_page]
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
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
	burn_title = "Burns confirmed" if state.get("burn_correct", false) else "False call"
	burn_explanation = state.get("burn_message", "")
	bot_wait = 2.5
	_show_table()

func _show_burn_result() -> void:
	# Compatibility for callers restoring an older UI state: adjudication stays on the board.
	_show_table()

func _show_victory() -> void:
	screen = "victory"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
	layer.size = bounds
	var compact := bounds.y < 450
	var top := 20.0 if compact else 54.0
	var kicker := layer.label_at("EVERY CARD PLAYED", Rect2(0, top, bounds.x, 28), 12, GOLD)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var winner := _heading(layer, state.players[state.winner].name, Rect2(0, top + 38, bounds.x, 60), 38, true)
	winner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_heading(layer, "wins the table.", Rect2(0, top + 96, bounds.x, 48), 28, true)
	if not compact:
		var art := BurnsCardView.new()
		art.card_id = 51; art.artwork_only = true
		var height := minf(bounds.y - top - 286, 280)
		art.size = Vector2(height / 1.5, height)
		art.position = Vector2((bounds.x - art.size.x) / 2, top + 160)
		layer.add_child(art)
	layer.place(_button("Play again", func(): _setup(mode if mode != "online" else "local"), true), Rect2(0, bounds.y - 104, bounds.x, 48))
	layer.place(_button("Home", _show_menu), Rect2(0, bounds.y - 48, bounds.x, 44))

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
	theme.default_font = UI_FONT
	theme.default_font_size = 16
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

func _can_burn() -> bool:
	if state.is_empty() or state.phase == "finished": return false
	if mode == "online":
		if not net.connected: return false
		for seat in room.get("seats", []):
			if not seat.connected: return false
	return true

func _call_burn() -> void:
	if not _can_burn(): return
	if mode != "local":
		_act({"type": "burn"}, local_seat if mode == "online" else 0)
		return
	screen = "burn_caller"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
	layer.size = bounds
	layer.label_at("Who called Burns?", Rect2(0, 0, bounds.x, 48), 26, GOLD)
	var columns := 4 if bounds.x > 600 else 2
	for seat in range(state.players.size()):
		var width := bounds.x / columns
		layer.place(_button(state.players[seat].name, func(): _act({"type": "burn"}, seat), true), Rect2((seat % columns) * width, 68 + (seat / columns) * 56, width - 8, 48))
	layer.place(_button("Cancel", _show_table), Rect2(0, bounds.y - 48, bounds.x, 48))

func _show_deck_gallery() -> void:
	screen = "deck_gallery"
	_clear()
	var layer := BurnsTableView.new()
	layer.app = self
	content.add_child(layer)
	var bounds := _bounds()
	layer.size = bounds
	layer.place(_button("‹ Table" if gallery_return == "game" else "‹ Home", _close_gallery), Rect2(0, 0, 88, 44))
	var heading := layer.label_at("THE RAVEN DECK", Rect2(96, 0, bounds.x - 178, 44), 11, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.place(_button("Face" if gallery_back else "Back", func(): gallery_back = not gallery_back; _show_deck_gallery()), Rect2(bounds.x - 74, 0, 74, 44))
	var landscape := bounds.x > bounds.y * 1.4
	var image_area := Rect2(0, 58, bounds.x * 0.54 if landscape else bounds.x, bounds.y - (68 if landscape else 218))
	var height := minf(image_area.size.y, image_area.size.x * 1.5)
	var card := BurnsCardView.new()
	card.name = "GalleryCard"
	card.card_id = gallery_card
	card.face_down = gallery_back
	card.artwork_only = true
	card.size = Vector2(height * 2.0 / 3.0, height)
	card.position = image_area.get_center() - card.size / 2
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_gallery_input)
	layer.add_child(card)
	var panel := Rect2(bounds.x * 0.57, 72, bounds.x * 0.43, bounds.y - 72) if landscape else Rect2(0, bounds.y - 154, bounds.x, 154)
	var caption := "The Noodle King" if gallery_card == 51 else ("Jack of Spades" if gallery_card == 49 else BurnsDeck.card_name(gallery_card))
	if gallery_back: caption = "The Raven Back"
	_heading(layer, caption, Rect2(panel.position, Vector2(panel.size.x, 32)), 21, true)
	var sub := layer.label_at("Swipe to explore  ·  %02d / 52" % (gallery_card + 1), Rect2(panel.position.x, panel.position.y + 34, panel.size.x, 20), 11, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var suit_w := (panel.size.x - 18) / 4
	for suit in range(4):
		var button := _button(["Diamonds", "Clubs", "Hearts", "Spades"][suit], func(): gallery_card = suit * 13 + gallery_card % 13; gallery_back = false; _show_deck_gallery(), not gallery_back and gallery_card / 13 == suit)
		button.add_theme_font_size_override("font_size", 10)
		layer.place(button, Rect2(panel.position.x + suit * (suit_w + 6), panel.end.y - 94, suit_w, 40))
	var nav_w := (panel.size.x - 60) / 2
	layer.place(_button("‹ Previous", func(): _gallery_step(-1)), Rect2(panel.position.x, panel.end.y - 46, nav_w, 44))
	layer.place(_button("K", func(): gallery_card = (gallery_card / 13) * 13 + 12; gallery_back = false; _show_deck_gallery()), Rect2(panel.position.x + nav_w + 6, panel.end.y - 46, 48, 44))
	layer.place(_button("Next ›", func(): _gallery_step(1)), Rect2(panel.end.x - nav_w, panel.end.y - 46, nav_w, 44))

func _gallery_step(direction: int) -> void:
	gallery_card = posmod(gallery_card + direction, 52)
	gallery_back = false
	_show_deck_gallery()

func _gallery_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			gallery_swipe_origin = event.global_position
			gallery_swiping = true
		elif gallery_swiping:
			gallery_swiping = false
			var delta: Vector2 = event.global_position - gallery_swipe_origin
			if absf(delta.x) > 40 and absf(delta.x) > absf(delta.y): _gallery_step(-1 if delta.x > 0 else 1)

func _inspect_card(card: int) -> void:
	gallery_return = "game"
	gallery_card = card
	gallery_back = false
	_show_deck_gallery()

func _close_gallery() -> void:
	gallery_swiping = false
	if gallery_return == "game": _show_table()
	else: _show_menu()

func _bounds() -> Vector2:
	return size - Vector2(safe_margins.x + safe_margins.z, safe_margins.y + safe_margins.w)

func _update_safe_area() -> void:
	if not content: return
	safe_margins = Vector4(16, 16, 16, 16)
	if OS.get_name() in ["Android", "iOS"]:
		safe_margins = BurnsSafeLayout.margins(Vector2(get_window().size), size, Rect2(DisplayServer.get_display_safe_area()))
	var values := [safe_margins.x, safe_margins.y, safe_margins.z, safe_margins.w]
	var sides := ["left", "top", "right", "bottom"]
	for index in range(4): content.add_theme_constant_override("margin_" + sides[index], int(values[index]))

func _heading(layer: BurnsTableView, text: String, rect: Rect2, font_size: int, centered := false) -> Label:
	var label := layer.label_at(text, rect, font_size, CREAM)
	label.add_theme_font_override("font", DISPLAY_FONT)
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _review_turn_ready() -> bool:
	return mode == "bots" and not state.is_empty() and state.phase == "review" and state.reviewers == [0] and (int(state.active) + 1) % state.players.size() == 0

func _turn_seat() -> int:
	return 0 if _review_turn_ready() else int(state.active)
