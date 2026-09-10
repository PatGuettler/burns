extends SceneTree
## Capture Google Play phone screenshots from the running game, never from artwork.
## Frames are 1080 × 1920 (9:16), laid out at 360 × 640 logical points and drawn at 3×.
const SHOT := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)
const OUT := "res://store/play/screenshots"

var scene

func _init() -> void:
	call_deferred("run")

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sound_on = false
	scene.animations_enabled = false
	scene.save_enabled = false
	# The app derives its canvas from the reported display density; pin it to a phone instead.
	scene.get_window().size_changed.disconnect(scene._sync_display_density)
	root.size = SHOT
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = LOGICAL
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)

	scene._show_menu()
	await capture("01-home")

	deal("local", 4)
	scene._act({"type": "draw"})
	await capture("02-turn")

	deal("local", 4)
	scene._act({"type": "draw"})
	scene._act({"type": "end"})
	await capture("03-burns")

	deal("bots", 3)
	scene._act({"type": "draw"})
	await capture("04-computers")

	scene.player_count = 6
	scene._setup("local")
	await capture("05-players")

	deal("local", 4)
	scene.game.s.rows[0] = [12, 24, 10, 22, 8, 20, 6, 18, 4, 16, 2, 14, 0]
	scene.state = scene.game.view()
	scene._inspect_row(0)
	await capture("06-long-row")

	scene.gallery_card = 51
	scene.gallery_return = "menu"
	scene._show_deck_gallery()
	await capture("07-deck")

	deal("local", 4)
	scene.state.phase = "finished"
	scene.state.winner = 0
	scene._show_victory()
	await capture("08-victory")
	quit()

func deal(mode: String, players: int) -> void:
	seed(20260910)
	scene.player_count = players
	scene._new_game(mode)
	var s = scene.game.s
	s.foundations[0] = [0, 1, 2]
	s.foundations[3] = [39]
	s.rows = [[51, 37], [50, 36, 22], [49], [34, 20], [45]]
	s.players[1].discard = [31]
	s.players[2].discard = [17]
	scene.state = scene.game.view()
	scene.handed_to = 0
	scene._show_table()

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png("%s/%s.png" % [OUT, label])
	print("%s  %dx%d" % [label, image.get_width(), image.get_height()])
