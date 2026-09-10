extends SceneTree
## Export approved card-free marketing art. These are promotional panels, not UI captures.
const SOURCE := "res://store/play/source/"

func _init() -> void:
	_export("ember-raven.png", "res://store/play/icon-512.png", Vector2i(512, 512))
	_export("ember-raven.png", "res://assets/art/icon.png", Vector2i(1024, 1024))
	_export("feature.png", "res://store/play/feature-1024x500.png", Vector2i(1024, 500))
	_export("phone-rivalry.png", "res://store/play/phone-1080x1920.png", Vector2i(1080, 1920))
	_export("phone-modes.png", "res://store/play/phone-menu-1080x1920.png", Vector2i(1080, 1920))
	# Keep the full emblem inside Android's adaptive icon safe zone.
	var foreground := Image.create(432, 432, false, Image.FORMAT_RGB8)
	foreground.fill(Color("032023"))
	var mark := Image.load_from_file(SOURCE + "ember-raven.png")
	mark.resize(264, 264, Image.INTERPOLATE_LANCZOS)
	foreground.blit_rect(mark, Rect2i(0, 0, 264, 264), Vector2i(84, 84))
	assert(foreground.save_png("res://assets/art/icon-adaptive.png") == OK)
	print("Exported card-free icon, feature art, and two promotional phone panels.")
	quit()

func _export(source: String, target: String, dimensions: Vector2i) -> void:
	var picture := Image.load_from_file(SOURCE + source)
	assert(picture != null and not picture.is_empty(), source)
	# Generated masters match the target aspect ratios to within rounding.
	assert(absf(float(picture.get_width()) / picture.get_height() - float(dimensions.x) / dimensions.y) < 0.01)
	picture.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	picture.convert(Image.FORMAT_RGB8)
	assert(picture.save_png(target) == OK, target)
