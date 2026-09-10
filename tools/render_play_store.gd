extends SceneTree
## Write Google Play listing images: 512 icon, 9:16 phone shot, 1024x500 feature graphic.

const OUT := "res://store/play"
const CREAM := Color("f4ead6")
const MUTED := Color("adc3bd")
const GOLD := Color("d1ac78")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_write_icon()
	await _write_feature()
	await _write_phone()
	print("Wrote Play listing images under store/play/")
	quit()

func _write_icon() -> void:
	var icon := Image.load_from_file("res://assets/art/icon_play.svg")
	assert(not icon.is_empty(), "Play icon SVG failed to load")
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	if icon.detect_alpha():
		var flat := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		flat.fill(Color("10383e"))
		flat.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i.ZERO)
		icon = flat
	assert(icon.save_png("res://store/play/icon-512.png") == OK)

func _write_feature() -> void:
	root.size = Vector2i(1024, 500)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/deck/raven_room.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1024, 500)
	root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.05, 0.42)
	shade.size = Vector2(1024, 500)
	root.add_child(shade)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/art/icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(48, 86)
	icon.size = Vector2(328, 328)
	root.add_child(icon)
	_banner_label("THE FAMILY CARD TABLE", Vector2(400, 92), Vector2(592, 28), 16, GOLD)
	_banner_label("Burns", Vector2(400, 128), Vector2(592, 110), 84, CREAM)
	_banner_label("A little solitaire. A little rivalry.", Vector2(400, 250), Vector2(592, 36), 22, MUTED)
	_banner_label("2–8 PLAYERS  ·  52 CARDS  ·  ONE SHARP EYE", Vector2(400, 370), Vector2(592, 28), 14, GOLD)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_rgb(root.get_texture().get_image(), "res://store/play/feature-1024x500.png")

func _banner_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	root.add_child(label)

func _write_phone() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.size = Vector2i(1080, 1920)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sound_on = false
	scene.save_enabled = false
	scene.player_count = 4
	var names: Array = []
	for i in range(4):
		names.append("Player %d" % (i + 1))
	var seed_value := 1
	while seed_value < 8000:
		scene.game = BurnsGame.new()
		scene.game.start(names, seed_value)
		if _placeholder_on_table(scene.game.s):
			seed_value += 1
			continue
		var held: int = scene.game.s.players[0].play.back() if not scene.game.s.players[0].play.is_empty() else -1
		if _is_placeholder(held):
			seed_value += 1
			continue
		break
	assert(seed_value < 8000, "No Play screenshot seed without unfinished court portraits")
	scene.mode = "local"
	scene.offline_mode = "local"
	scene.state = scene.game.view()
	scene.handed_to = 0
	scene.selected = {}
	scene.message = ""
	scene._act({"type": "draw"})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_rgb(root.get_texture().get_image(), "res://store/play/phone-1080x1920.png")
	scene._show_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_rgb(root.get_texture().get_image(), "res://store/play/phone-menu-1080x1920.png")

func _is_placeholder(card: int) -> bool:
	if card < 0:
		return false
	var rank := card % 13 + 1
	return rank >= 11 and card != 49 and card != 51

func _placeholder_on_table(state: Dictionary) -> bool:
	for row in state.rows:
		if _is_placeholder(row[0]):
			return true
	return false

func _save_rgb(image: Image, path: String) -> void:
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	assert(image.save_png(path) == OK)
