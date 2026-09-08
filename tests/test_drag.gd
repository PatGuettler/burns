extends SceneTree
var app: Control

func _init() -> void: call_deferred("run")

func fixture() -> void:
	app.game = BurnsGame.new()
	app.game.start(["A", "B"], 1)
	app.game.s.rows = [[16], [2, 14], [], [], []]
	for p in app.game.s.players:
		p.play = []; p.discard = []; p.reserve = []; p.held = -1
	app.game.s.players[0].held = 0
	var deck: Array = BurnsDeck.create_deck()
	for card in [16, 2, 14, 0]: deck.erase(card)
	app.game.s.players[0].play = deck.slice(0, 10)
	app.game.s.players[1].play = deck.slice(10)
	app.mode = "local"
	app.handed_to = 0
	app.state = app.game.view()
	app.selected = {}
	app._show_table()

func button(source_kind: String, index := -1, target := false) -> BurnsCardButton:
	var table: BurnsTableView = app.content.get_child(0)
	for child in table.get_children():
		if child is BurnsCardButton:
			var value: Dictionary = child.drop_target if target else child.source
			if value.get("kind" if target else "source") == source_kind and (index < 0 or value.get("index") == index): return child
	return null

func mouse(position: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event)

func motion(position: Vector2, previous: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func drag(from: Vector2, to: Vector2) -> void:
	motion(from, from)
	mouse(from, true)
	await process_frame
	motion(from + Vector2(20, -20), from)
	await process_frame
	assert(root.gui_is_dragging(), "A pointer movement must begin a real drag")
	motion(to, from + Vector2(20, -20))
	await process_frame
	mouse(to, false)
	await process_frame
	await process_frame
	assert(not root.gui_is_dragging(), "Drop must end the gesture")

func run() -> void:
	root.size = Vector2i(1120, 800)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.save_enabled = false; app.sound_on = false
	fixture()
	await process_frame
	await drag(button("held").get_global_rect().get_center(), button("foundation", 0, true).get_global_rect().get_center())
	assert(app.game.s.foundations[0] == [0] and app.game.s.players[0].held == -1, "Dragging an ace plays it")
	assert(app.game.invariant())
	fixture()
	await process_frame
	var source := button("row", 1)
	# Grab the exposed rank strip so the last card doesn't cover the sequence start.
	await drag(source.get_global_rect().position + Vector2(15, 10), button("row", 0, true).get_global_rect().get_center())
	assert(app.game.s.rows[0] == [16, 2, 14] and app.game.s.rows[1].is_empty(), "Drag moves the entire sequence")
	assert(app.game.invariant())
	fixture()
	await process_frame
	var revision: int = app.game.s.revision
	await drag(button("held").get_global_rect().get_center(), button("foundation", 1, true).get_global_rect().get_center())
	assert(app.game.s.revision == revision and app.game.s.players[0].held == 0, "Invalid drop leaves all cards untouched")
	await drag(button("held").get_global_rect().get_center(), button("discard", 0, true).get_global_rect().get_center())
	assert(app.game.s.phase == "review" and app.game.s.players[0].discard == [0], "Drop on own discard ends turn")
	assert(app.game.invariant())
	fixture()
	await process_frame
	var from := button("held").get_global_rect().get_center()
	var to := button("discard", 0, true).get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0; touch.position = from; touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var movement := InputEventScreenDrag.new()
	movement.index = 0; movement.position = from + Vector2(22, -22); movement.relative = Vector2(22, -22)
	Input.parse_input_event(movement)
	await process_frame
	assert(root.gui_is_dragging(), "Touch movement must start a card drag")
	movement = InputEventScreenDrag.new()
	movement.index = 0; movement.position = to; movement.relative = to - from - Vector2(22, -22)
	Input.parse_input_event(movement)
	await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0; touch.position = to; touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	await process_frame
	assert(app.game.s.phase == "review", "A finger drag can discard and end the turn")
	print("PASS: mouse and touch drags for ace, whole sequence, invalid drop, and ending turn; card conservation")
	quit()
