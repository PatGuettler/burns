class_name BurnsCardMotion
extends RefCounted
## Animate only already-public cards, never infer the next hidden card.
static func capture(app: Control, action: Dictionary, seat: int) -> Dictionary:
	if not app.animations_enabled or app.mode != "bots" or seat <= 0 or app.screen != "game": return {}
	if app.content.get_child_count() == 0: return {}
	var table = app.content.get_child(0)
	if not table is BurnsTableView: return {}
	var player: Dictionary = app.state.players[seat]
	var card := -1
	var source := Rect2()
	match action.get("type"):
		"move":
			match action.get("source"):
				"row": card = app.state.rows[action.index][action.offset]
				"held": card = player.held
				"discard": card = player.discard_top
				"reserve": card = player.reserve_top
		"end": card = player.held if player.held >= 0 else player.reserve_top
		"draw":
			for child in table.get_children():
				if child is BurnsCardButton and child.get_meta("pile", {}) == {"source": "play", "index": seat}:
					source = child.get_global_rect()
		_: return {}
	if card >= 0:
		var control := find_card(table, card)
		if control: source = control.get_global_rect()
	if not source.has_area(): return {}
	return {"source": source, "card": card, "action": action.duplicate(), "seat": seat}

static func find_card(table: Node, card: int) -> BurnsCardButton:
	for child in table.get_children():
		if child is BurnsCardButton and child.art.card_id == card and not child.art.face_down and not child.art.empty_slot:
			return child
	return null

static func animate(app: Control, motion: Dictionary) -> void:
	if motion.is_empty() or app.screen != "game" or app.content.get_child_count() == 0: return
	var card: int = motion.card
	if motion.action.type == "draw": card = app.state.players[motion.seat].held
	if card < 0: return
	var target := find_card(app.content.get_child(0), card)
	if not target: return
	var end := target.get_global_rect()
	if end.position.is_equal_approx(motion.source.position): return
	var face := BurnsCardView.new()
	face.card_id = card
	face.size = motion.source.size
	face.position = motion.source.position
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.z_index = 50
	app.add_child(face)
	app.active_motion = face
	target.modulate.a = 0
	face.tree_exiting.connect(func():
		if is_instance_valid(target): target.modulate.a = 1)
	var tween := face.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "position", end.position, 0.30)
	tween.tween_property(face, "size", end.size, 0.30)
	tween.chain().tween_callback(func():
		if is_instance_valid(target):
			target.modulate.a = 1
			target.art.highlighted = true
			target.art.queue_redraw()
		face.queue_free())
