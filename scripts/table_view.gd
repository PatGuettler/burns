class_name BurnsTableView
extends Control
## Board geometry derives from the available viewport, never from accumulated content height.
## Long rows open a finite selection grid instead of overflowing or scrolling.
var app: Control
var state: Dictionary
var card_rects: Array[Rect2] = []
var card_sources: Array[String] = []
var controls: Array[Control] = []
var hand_seat := 0
const GOLD := Color("d1ac78")
const MUTED := Color("a7b3ad")
const CREAM := Color("f4ead6")

func build(owner_ui: Control, bounds: Vector2) -> void:
	app = owner_ui
	state = app.state
	size = bounds
	var w := bounds.x
	var h := bounds.y
	var wide := (w >= 850 and w / h >= 1.10) or (w / h > 1.55 and w > 620)
	var small := h < 500
	var header_h := 44.0
	place(app._button("‹", app._show_menu), Rect2(0, 0, 44, header_h))
	label_at("Burns", Rect2(56, 0, 90, header_h), 26, GOLD)
	var title := "TURN %d" % state.turn
	if w > 540: title += "  ·  " + str(state.players[state.active].name)
	if w > 500: label_at(title, Rect2(158, 0, w - 304, header_h), 13, MUTED)
	var burn: Button = app._button("BURNS!", app._call_burn, true)
	burn.disabled = not app._can_burn()
	place(burn, Rect2(w - 136, 0, 84, header_h))
	place(app._button("?", app._show_rules), Rect2(w - 44, 0, 44, header_h))
	var actor: int = app._actor()
	hand_seat = actor if app.mode == "local" and actor >= 0 else (app.local_seat if app.mode == "online" else 0)
	var status := ""
	match state.phase:
		"turn": status = "%s · reveal a card or choose a play" % state.players[state.active].name
		"review": status = "%s · call Burns or pass" % state.players[actor].name
		"penalty": status = "%s is burnt · %s gives a card" % [state.players[state.burnt].name, state.players[actor].name]
		"finished": status = "%s wins the table!" % state.players[state.winner].name
	if not app.message.is_empty(): status = app.message
	if app.mode == "online":
		for seat in app.room.get("seats", []):
			if not seat.connected: status = "Paused · waiting for " + seat.name
		if not app.net.connected: status = "Disconnected · tap Reconnect below"
	var status_label := label_at(status, Rect2(0, 44, w, 26), 15, CREAM)
	status_label.tooltip_text = status
	var footer_h := 48.0
	var ruling_height := 68.0 if state.phase == "penalty" else 0.0
	h -= ruling_height
	var hand_h := clampf(h * 0.27, 118, 240)
	var hand_y := h - footer_h - hand_h - 10
	var main_w := w
	if wide:
		var side_w := clampf(w * 0.245, 190, 310)
		main_w = w - side_w - 26
		_opponents(Rect2(main_w + 26, 84, side_w, h - 84 - footer_h - 8), 2)
		var foundation_h := clampf(h * 0.18, 56, 142)
		if small:
			var hand_width := 144.0
			_foundations(Rect2(hand_width + 14, 80, main_w - hand_width - 14, foundation_h))
			_rows(Rect2(hand_width + 14, 80 + foundation_h + 12, main_w - hand_width - 14, h - footer_h - (80 + foundation_h + 12) - 10))
			_compact_hand(Rect2(0, 88, hand_width, h - footer_h - 96))
		else:
			_foundations(Rect2(0, 80, main_w, foundation_h))
			_rows(Rect2(0, 80 + foundation_h + 16, main_w, maxf(65, hand_y - (80 + foundation_h + 16) - 14)))
	else:
		var others: int = state.players.size() - 1
		var opponent_rows := int(ceil(float(others) / 4))
		var row_gap := clampf(w * 0.022, 5, 18)
		var row_minimum := (w - row_gap * 4) / 5 * 1.5 + 24
		var foundation_h := clampf(h * 0.115, 54, 104)
		var opponent_h := clampf(h * (0.145 if opponent_rows == 1 else 0.12), 52, 132 if opponent_rows == 1 else 108)
		# Allocate to actual card proportions before expanding any decorative space.
		var budget := h - footer_h - 78 - 36 - foundation_h - row_minimum
		opponent_h = minf(opponent_h, maxf(44, (budget - hand_h) / opponent_rows))
		hand_h = minf(hand_h, budget - opponent_h * opponent_rows)
		hand_y = h - footer_h - hand_h - 10
		var opponents_h := opponent_h * opponent_rows
		_opponents(Rect2(0, 78, w, opponents_h), mini(4, others))
		var foundation_y := 78 + opponents_h + 8
		_foundations(Rect2(0, foundation_y, w, foundation_h))
		var rows_y := foundation_y + foundation_h + 14
		_rows(Rect2(0, rows_y, w, maxf(65, hand_y - rows_y - 12)))
	if not (wide and small): _hand(Rect2(0, hand_y, main_w, hand_h))
	if ruling_height > 0:
		_burn_banner(Rect2(0, h - footer_h, w, ruling_height - 6))
	_actions(Rect2(0, h + ruling_height - footer_h, w, footer_h), small)
	_mark_evidence()

func place(control: Control, rect: Rect2) -> Control:
	control.custom_minimum_size = Vector2.ZERO
	control.position = rect.position
	control.size = rect.size
	add_child(control)
	controls.append(control)
	return control

func label_at(text: String, rect: Rect2, font_size := 15, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(label, rect)
	return label

func _card(rect: Rect2, card: int, action: Callable, source := {}, back := false, empty := false, caption := "", suit_hint := -1, compact := false) -> BurnsCardButton:
	var button := BurnsCardButton.new()
	button.table = self
	button.source = source.duplicate()
	button.draggable = not back and not empty and not source.is_empty()
	if source.get("source") == "row": button.drop_target = {"kind": "row", "index": source.index}
	if source.get("source") == "discard": button.drop_target = {"kind": "discard", "index": source.index}
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = caption if empty or back else BurnsDeck.card_name(card)
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	var art := BurnsCardView.new()
	button.art = art
	art.card_id = maxi(0, card)
	art.face_down = back
	art.empty_slot = empty
	art.compact = compact
	art.slot_suit = suit_hint
	art.slot_text = caption
	art.highlighted = not source.is_empty() and source == app.selected
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(art)
	button.focus_entered.connect(func(): art.focused = true; art.queue_redraw())
	button.focus_exited.connect(func(): art.focused = false; art.queue_redraw())
	button.mouse_entered.connect(func(): art.hovered = true; art.queue_redraw())
	button.mouse_exited.connect(func(): art.hovered = false; art.queue_redraw())
	button.pressed.connect(func():
		if not button.suppress_click and not get_viewport().gui_is_dragging(): action.call())
	place(button, rect)
	card_rects.append(rect)
	card_sources.append(source.get("source", "other"))
	return button

func _foundations(area: Rect2) -> void:
	var gap := clampf(area.size.x * 0.025, 8, 16)
	var ch := area.size.y - 17
	var cw := minf(ch / 1.5, (area.size.x - 3 * gap) / 4)
	var start := area.position.x + (area.size.x - 4 * cw - 3 * gap) / 2
	var caption := label_at("01  ·  ACES FIRST", Rect2(area.position.x, area.position.y - 2, area.size.x, 17), 10, GOLD)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for suit in range(4):
		var pile: Array = state.foundations[suit]
		var rect := Rect2(start + suit * (cw + gap), area.position.y + 17, cw, ch)
		_card(rect, int(pile.back()) if not pile.is_empty() else 0, func(): app._target("foundation", suit), {}, false, pile.is_empty(), "A", suit).drop_target = {"kind": "foundation", "index": suit}

func _rows(area: Rect2) -> void:
	var gap := clampf(area.size.x * 0.022, 5, 22)
	var cw := minf(146, (area.size.x - gap * 4) / 5)
	var has_sequence := false
	for pile in state.rows:
		if pile.size() > 1: has_sequence = true
	var ch := minf(cw * 1.5, maxf(55, area.size.y - 24 - (24 if has_sequence else 0)))
	cw = minf(cw, ch / 1.5)
	var start := area.position.x + (area.size.x - cw * 5 - gap * 4) / 2
	for row in range(5):
		var pile: Array = state.rows[row]
		var x := start + row * (cw + gap)
		var y := area.position.y + 22
		var title := label_at("ROW %d" % (row + 1), Rect2(x, area.position.y, cw, 20), 11, GOLD)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if pile.is_empty():
			_card(Rect2(x, y, cw, ch), 0, func(): app._target("row", row), {}, false, true, "+").drop_target = {"kind": "row", "index": row}
			continue
		var available := maxf(ch, area.size.y - 22)
		var capacity := maxi(1, int((available - ch) / 23) + 1)
		var visible := mini(pile.size(), capacity)
		var step := minf(35, (available - ch) / maxi(1, visible - 1))
		for visible_index in range(visible):
			var offset := visible_index if visible_index < visible - 1 else pile.size() - 1
			var source := {"source": "row", "index": row, "offset": offset}
			_card(Rect2(x, y + visible_index * step, cw, ch), int(pile[offset]), func(): app._select_or_target(source, "row", row), source)
		# A fixed tap target exposes every card in a long row through a paginated-free grid.
		if pile.size() > visible or pile.size() > 1:
			title.hide()
			var inspect: Button = app._button("%d · %d" % [row + 1, pile.size()], func(): app._inspect_row(row))
			inspect.tooltip_text = "View all %d cards in row %d" % [pile.size(), row + 1]
			inspect.add_theme_font_size_override("font_size", 11)
			place(inspect, Rect2(x, area.position.y, cw, 20))

func _opponents(area: Rect2, columns: int) -> void:
	var others: Array[int] = []
	for seat in range(state.players.size()):
		if seat != hand_seat: others.append(seat)
	var rows := int(ceil(float(others.size()) / columns))
	var cell := Vector2(area.size.x / columns, area.size.y / rows)
	for i in range(others.size()):
		var seat := others[i]
		var p: Dictionary = state.players[seat]
		var origin := area.position + Vector2((i % columns) * cell.x, (i / columns) * cell.y)
		var total := int(p.play_count + p.discard_count + p.reserve_count) + (1 if p.held >= 0 else 0)
		var label := label_at("%s%s · %d" % ["BURN · " if state.phase == "penalty" and seat == state.burnt else "", p.name, total], Rect2(origin, Vector2(cell.x - 6, 19)), 12, GOLD if seat == state.active else MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.tooltip_text = "%s: %d hidden, %d discarded, %d open" % [p.name, p.play_count, p.discard_count, p.reserve_count]
		if cell.y < 86:
			_compact_opponent(p, seat, Rect2(origin.x + 3, origin.y + 19, cell.x - 6, cell.y - 22))
			continue
		var ch := minf(158, cell.y - 26)
		var cw := minf(ch / 1.5, cell.x - 12)
		ch = cw * 1.5
		var has_extra: bool = p.held >= 0 or p.reserve_top >= 0
		if has_extra: cw = minf(cw, (cell.x - 16) / 2); ch = minf(ch, cw * 1.5)
		var x := origin.x + (cell.x - cw * (2 if has_extra else 1) - (4 if has_extra else 0)) / 2
		_card(Rect2(x, origin.y + 20, cw, ch), int(p.discard_top), func(): app._pile_action(seat, "discard"), {}, false, p.discard_top < 0, "—").drop_target = {"kind": "opponent", "index": seat}
		if has_extra:
			var exposed: int = p.held if p.held >= 0 else p.reserve_top
			_card(Rect2(x + cw + 4, origin.y + 20, cw, ch), exposed, func(): app.message = "Only that player's discard is a destination."; app._show_table())

func _hand(area: Rect2) -> void:
	var p: Dictionary = state.players[hand_seat]
	var title := "%s's hand" % p.name
	if state.phase == "penalty": title = "%s · choose a penalty card" % p.name
	_hand_shelf(area)
	var hand_title := label_at(title, Rect2(area.position, Vector2(area.size.x, 20)), 13, GOLD)
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sources := ["play", "discard"]
	if p.reserve_count > 0: sources.append("reserve")
	if p.held >= 0: sources.append("held")
	var gap := clampf(area.size.x * 0.03, 10, 24)
	var ch := maxf(48, area.size.y - 44)
	var cw := minf(ch / 1.5, (area.size.x - 16 - (sources.size() - 1) * gap) / sources.size())
	ch = minf(ch, cw * 1.5)
	var start := area.position.x + (area.size.x - sources.size() * cw - (sources.size() - 1) * gap) / 2
	for i in range(sources.size()):
		var kind: String = sources[i]
		var card := -1
		if kind == "discard": card = int(p.discard_top)
		if kind == "reserve": card = int(p.reserve_top)
		if kind == "held": card = int(p.held)
		var source := {"source": kind, "index": 0 if kind == "held" else hand_seat, "offset": 0}
		var back: bool = kind == "play" and p.play_count > 0
		var rect := Rect2(start + i * (cw + gap), area.position.y + 24 + maxf(0, (area.size.y - 44 - ch) / 2), cw, ch)
		_card(rect, card, func():
			if state.phase == "penalty" and hand_seat == app._actor(): app._act({"type": "donate", "source": kind})
			elif kind == "held": app._select(source)
			else: app._pile_action(hand_seat, kind), source, back, card < 0 and not back, "—")
		var caption: String = {"play": "Draw · %d" % p.play_count, "discard": "Discard", "reserve": "Open top", "held": "Play this"}[kind]
		var label := label_at(caption, Rect2(rect.position.x - 7, rect.end.y, cw + 14, 18), 12, MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _hand_shelf(area: Rect2) -> void:
	# A quiet inset anchors the hand without competing with the engraved artwork.
	var shelf := Panel.new()
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.12, 0.64)
	style.border_color = Color(0.72, 0.57, 0.37, 0.20)
	style.border_width_top = 1
	style.set_corner_radius_all(20)
	shelf.add_theme_stylebox_override("panel", style)
	place(shelf, Rect2(area.position + Vector2(0, 5), area.size - Vector2(0, 2)))

func _actions(area: Rect2, small: bool) -> void:
	var items: Array = []
	if app._can_act():
		match state.phase:
			"turn":
				items.append(["End turn" if state.players[state.active].held < 0 else "Discard & end", func(): app._act({"type": "end"}), true])
				if state.players[state.active].reserve_count > 0:
					items.append(["Draw bottom", func(): app._act({"type": "draw", "source": "bottom"}), false])
				elif not app.selected.is_empty():
					items.append(["Cancel", func(): app.selected = {}; app._show_table(), false])
				elif app.mode != "online": items.append(["Hint", app._hint, false])
			"review":
				items.append(["Pass", func(): app._act({"type": "pass"}), false])
			"penalty":
				for source in ["play", "discard", "reserve", "held"]:
					if state.players[app._actor()][source + "_count"] > 0:
						items.append(["Give " + {"play": "hidden", "discard": "discard", "reserve": "open", "held": "revealed"}[source], func(): app._act({"type": "donate", "source": source}), true])
	if state.phase == "finished": items.append(["Back to the room", app._show_menu, true])
	if app.mode == "online" and not app.net.connected: items = [["Reconnect", app._reconnect, true]]
	if items.is_empty():
		label_at("Watching the table…", area, 15, MUTED)
		return
	var gap := 10.0
	var bw := minf(230, (area.size.x - (items.size() - 1) * gap) / items.size())
	var start := area.position.x + (area.size.x - items.size() * bw - (items.size() - 1) * gap) / 2
	for i in range(items.size()):
		var item: Array = items[i]
		var button: Button = app._button(item[0], item[1], item[2])
		button.add_theme_font_size_override("font_size", 12 if items.size() > 2 else (14 if small else 16))
		place(button, Rect2(start + i * (bw + gap), area.position.y, bw, area.size.y))

func _compact_opponent(p: Dictionary, seat: int, area: Rect2) -> void:
	var has_extra: bool = p.held >= 0 or p.reserve_top >= 0
	var width := (area.size.x - 4) / 2 if has_extra else area.size.x
	_card(Rect2(area.position, Vector2(width, area.size.y)), int(p.discard_top), func(): app._pile_action(seat, "discard"), {}, false, p.discard_top < 0, "+/-", -1, true).drop_target = {"kind": "opponent", "index": seat}
	if has_extra:
		var card: int = p.held if p.held >= 0 else p.reserve_top
		_card(Rect2(area.position.x + width + 4, area.position.y, width, area.size.y), card, func(): app.message = "Exposed card · only the discard is a destination"; app._show_table(), {}, false, false, "", -1, true)

func _compact_hand(area: Rect2) -> void:
	var p: Dictionary = state.players[hand_seat]
	label_at("%s's hand" % p.name, Rect2(area.position, Vector2(area.size.x, 20)), 13, GOLD)
	var sources := ["play", "discard"]
	if p.reserve_count > 0: sources.append("reserve")
	if p.held >= 0: sources.append("held")
	var rows := int(ceil(sources.size() / 2.0))
	var cell := Vector2(area.size.x / 2, (area.size.y - 24) / rows)
	var ch := minf(cell.y - 18, (cell.x - 10) * 1.48)
	var cw := ch / 1.48
	for i in range(sources.size()):
		var kind: String = sources[i]
		var card := -1
		if kind == "discard": card = p.discard_top
		if kind == "reserve": card = p.reserve_top
		if kind == "held": card = p.held
		var source := {"source": kind, "index": 0 if kind == "held" else hand_seat, "offset": 0}
		var back: bool = kind == "play" and p.play_count > 0
		var rect := Rect2(area.position.x + (i % 2) * cell.x + (cell.x - cw) / 2, area.position.y + 24 + (i / 2) * cell.y, cw, ch)
		_card(rect, card, func():
			if state.phase == "penalty" and hand_seat == app._actor(): app._act({"type": "donate", "source": kind})
			elif kind == "held": app._select(source)
			else: app._pile_action(hand_seat, kind), source, back, card < 0 and not back, "—")
		var label := label_at({"play": "Draw", "discard": "Discard", "reserve": "Open top", "held": "Play this"}[kind], Rect2(rect.position.x - 5, rect.end.y, cw + 10, 16), 11, MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func drag_cards(source: Dictionary) -> Array:
	if not source.has_all(["source", "index", "offset"]): return []
	var p: Dictionary = state.players[state.active]
	match source.source:
		"row":
			if source.index < 0 or source.index >= 5: return []
			return state.rows[source.index].slice(source.offset)
		"held": return [p.held] if p.held >= 0 else []
		"discard", "reserve":
			if source.index != state.active: return []
			var top: int = p[source.source + "_top"]
			return [top] if top >= 0 else []
	return []

func accepts_drop(data: Variant, target: Dictionary) -> bool:
	if not data is Dictionary or not data.get("burns_drag", false) or target.is_empty(): return false
	if data.get("table") != get_instance_id() or data.get("revision") != app.state.get("revision"): return false
	if not app._can_act() or app.state.phase != "turn": return false
	var source: Dictionary = data.source
	var cards := drag_cards(source)
	if cards.is_empty(): return false
	var card: int = cards[0]
	match target.kind:
		"discard": return source.source == "held" and target.index == state.active
		"foundation":
			return cards.size() == 1 and BurnsDeck.suit_of(card) == target.index and state.foundations[target.index].size() == BurnsDeck.rank_of(card) - 1
		"row":
			if source.source == "row" and source.index == target.index: return false
			var pile: Array = state.rows[target.index]
			return pile.is_empty() or (BurnsGame.alternate(card, pile.back()) and BurnsDeck.rank_of(pile.back()) == BurnsDeck.rank_of(card) + 1)
		"opponent":
			if source.source == "row" or cards.size() != 1 or target.index == state.active: return false
			var top: int = state.players[target.index].discard_top
			return top >= 0 and (BurnsGame.alternate(card, top) and absi(BurnsDeck.rank_of(card) - BurnsDeck.rank_of(top)) == 1)
	return false

func _burn_banner(area: Rect2) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("34231f")
	style.border_color = Color("c87b51")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	place(panel, area)
	var title := "BURNS · " if state.get("burn_correct", false) else "FALSE CALL · "
	var body := label_at(title + str(state.get("burn_message", "Penalty cards are due.")), Rect2(area.position + Vector2(10, 4), area.size - Vector2(20, 8)), 11 if area.size.x < 600 else 14, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body.text

func _mark_evidence() -> void:
	var evidence: Dictionary = state.get("burn_evidence", {}) if state.phase == "penalty" else {}
	if evidence.is_empty(): return
	for child in get_children():
		if child is BurnsCardButton and child.drop_target.get("kind") == evidence.get("target") and child.drop_target.get("index") == evidence.get("to"):
			child.art.highlighted = true
			child.art.queue_redraw()
