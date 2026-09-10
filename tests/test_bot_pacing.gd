extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(390, 844)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.save_enabled = false; app.sound_on = false; app.animations_enabled = true
	app.game = BurnsGame.new()
	app.game.start(["You", "Computer"], 33)
	app.game.s.active = 1
	app.mode = "bots"
	app.state = app.game.view()
	app.bot_wait = 100
	app._show_table()
	await process_frame
	app._act({"type": "draw"}, 1)
	assert(is_instance_valid(app.active_motion), "Computer reveal animates from its visible draw pile")
	await create_timer(0.4).timeout
	assert(not is_instance_valid(app.active_motion), "Motion releases its overlay after landing")
	app._act({"type": "end"}, 1)
	app.bot_wait = 100
	await create_timer(0.4).timeout
	assert(app._review_turn_ready(), "Human may start directly after the last computer finishes")
	assert(app._can_burn(), "The previous turn can still be challenged before drawing")
	var before: int = app.state.revision
	app._pile_action(0, "play")
	assert(app.state.phase == "turn" and app.state.active == 0 and app.state.players[0].held >= 0, "One draw gesture begins the human turn and reveals a card")
	assert(app.state.revision == before + 2, "Review and draw resolve without a separate Pass gesture")
	assert(app.game.invariant())
	print("PASS: computer reveal motion, challenge remains available, one-gesture human turn start, conservation")
	quit()
