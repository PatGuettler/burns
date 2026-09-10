class_name BurnsCardButton
extends Button
## Godot's pointer drag protocol also receives emulated primary-touch events.
var table: BurnsTableView
var source: Dictionary = {}
var drop_target: Dictionary = {}
var art: BurnsCardView
var draggable := false
var suppress_click := false
var inspect_elapsed := -1.0
var inspect_origin := Vector2.ZERO

func _get_drag_data(_at_position: Vector2) -> Variant:
	inspect_elapsed = -1.0
	if not draggable or not table.app._can_act() or (table.state.phase != "turn" and not table.app._review_turn_ready()): return null
	var cards := table.drag_cards(source)
	if cards.is_empty(): return null
	suppress_click = true
	var data := {"burns_drag": true, "source": source.duplicate(), "revision": table.state.revision, "table": table.get_instance_id()}
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_size := Vector2(clampf(size.x, 64, 112), clampf(size.x, 64, 112) * 1.48)
	for i in range(mini(cards.size(), 5)):
		var face := BurnsCardView.new()
		face.card_id = cards[i]
		face.highlighted = true
		face.size = card_size
		face.position = Vector2(-card_size.x / 2, -card_size.y * 0.65 + i * 20)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(face)
	if cards.size() > 1:
		var count := Label.new()
		count.text = "%d cards" % cards.size()
		count.position = Vector2(-card_size.x / 2, -card_size.y * 0.65 - 26)
		count.add_theme_font_size_override("font_size", 18)
		count.add_theme_color_override("font_color", Color("ffe1a0"))
		preview.add_child(count)
	set_drag_preview(preview)
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return table.accepts_drop(data, drop_target)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not table.accepts_drop(data, drop_target): return
	if drop_target.kind == "discard":
		table.app._act({"type": "end"})
	else:
		var action: Dictionary = data.source.duplicate()
		action.merge({"type": "move", "target": drop_target.kind, "to": drop_target.index})
		table.app._act(action)

func _notification(what: int) -> void:
	# Lifting a card used to light every pile that would accept it. Finding the
	# play is the skill Burns tests, so a drag now reveals nothing about the table.
	if what == NOTIFICATION_DRAG_END: call_deferred("_release_drag")

func _release_drag() -> void:
	suppress_click = false

func _gui_input(event: InputEvent) -> void:
	if not art or art.face_down or art.empty_slot: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			suppress_click = true
			table.app.call_deferred("_inspect_card", art.card_id)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			inspect_elapsed = 0.0 if event.pressed else -1.0
			inspect_origin = event.position
	elif event is InputEventMouseMotion and event.position.distance_to(inspect_origin) > 10:
		inspect_elapsed = -1.0

func _process(delta: float) -> void:
	if inspect_elapsed < 0: return
	inspect_elapsed += delta
	if inspect_elapsed >= 0.55:
		inspect_elapsed = -1.0
		if get_viewport().gui_is_dragging(): return
		suppress_click = true
		table.app.call_deferred("_inspect_card", art.card_id)
