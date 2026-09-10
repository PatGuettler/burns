class_name BurnsCardView
extends Control
## Baked engraved faces, fitted supplied portraits, and smooth, font-independent suit pips.

var card_id: int = 0
var face_down := false
var empty_slot := false
var compact := false
## Portrait inspection never places gameplay indices over the artwork.
var artwork_only := false
var slot_suit := -1
var slot_text := ""
var highlighted := false
var focused := false
var hovered := false
const INK := Color("ede9df")
const RED := Color("f28d7d")
const COPPER := Color("bd9563")
const BASE_SIZE := Vector2(76, 114)
const SUIT_SHAPES := [0, 1, 4, 3]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2.ZERO
	resized.connect(queue_redraw)
	tooltip_text = "Face-down play pile" if face_down else BurnsDeck.card_name(card_id)

func _draw() -> void:
	if compact:
		_draw_compact()
		return
	draw_set_transform(Vector2.ZERO, 0, size / BASE_SIZE)
	var rect := Rect2(Vector2.ZERO, BASE_SIZE)
	var active := highlighted or focused
	var accent := Color("ffe2a9") if active else COPPER
	if active:
		var glow := _panel(Color(0.91, 0.7, 0.36, 0.12), Color(0.98, 0.79, 0.43, 0.38), 9, 1)
		glow.shadow_color = Color(0.91, 0.7, 0.36, 0.2)
		glow.shadow_size = 5
		draw_style_box(glow, rect.grow(2))
	# The artwork carries its own engraved border, so the panel is only a shadow bed.
	var style := _panel(Color("0a0e10"), Color.TRANSPARENT, 7, 0)
	if empty_slot:
		style.bg_color = Color(0.04, 0.11, 0.12, 0.5)
		style.border_color = Color(accent, 0.64)
		style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 2 if empty_slot else 5
	style.shadow_offset = Vector2(0, 3)
	draw_style_box(style, rect)
	if empty_slot:
		_draw_empty()
		return
	if face_down:
		_draw_card_texture(BurnsDeckArt.BACK, rect)
	else:
		_draw_face(rect)
	if active or hovered:
		draw_style_box(_panel(Color.TRANSPARENT, accent if active else Color("e2c698"), 7, 2 if active else 1), rect)

func _draw_face(rect: Rect2) -> void:
	var suit := BurnsDeck.suit_of(card_id)
	var color := RED if suit in BurnsDeck.RED_SUITS else INK
	var supplied := BurnsDeckArt.supplied(card_id)
	if supplied:
		# The complete source image stays at its native aspect ratio, including its frame.
		var fitted := supplied.get_size() * minf(BASE_SIZE.x / supplied.get_width(), BASE_SIZE.y / supplied.get_height())
		draw_texture_rect(supplied, Rect2((BASE_SIZE - fitted) / 2, fitted), false)
		# Those two cards already carry printed indices once they are big enough to read.
		if not artwork_only and size.x < 160:
			_draw_indices(color, suit)
		return
	_draw_card_texture(BurnsDeckArt.face(card_id), rect)
	var rank := BurnsDeck.rank_of(card_id)
	if rank <= 10:
		# The ace pip lands in the empty disc at the heart of its engraved medallion.
		var radius := 14.0 if rank == 1 else 6.6
		for pip in BurnsDeckArt.pip_positions(rank):
			# The lower half is inverted just like a traditional double-ended deck.
			var inverted: bool = pip.y > BurnsDeckArt.PIP_CENTER.y
			_draw_suit(SUIT_SHAPES[suit], pip, radius + 0.7, Color(0.02, 0.03, 0.04, 0.8), inverted)
			_draw_suit(SUIT_SHAPES[suit], pip, radius, color, inverted)
	if not artwork_only:
		_draw_indices(color, suit)

func _draw_empty() -> void:
	var baseline := 49.0 if slot_suit >= 0 else 64.0
	draw_string(_font(), Vector2(0, baseline), slot_text, HORIZONTAL_ALIGNMENT_CENTER, 76, 22, Color(COPPER, 0.85))
	if slot_suit >= 0:
		_draw_suit(SUIT_SHAPES[slot_suit], Vector2(38, 77), 11, Color(COPPER, 0.75))

func _draw_indices(color: Color, suit: int) -> void:
	# Index plates sit just inside the artwork window so the engraved frame stays whole.
	var box := Rect2(BurnsDeckArt.WINDOW.position + Vector2(1.3, 1.3), Vector2(15, 27))
	for flipped in [false, true]:
		draw_set_transform(size if flipped else Vector2.ZERO, PI if flipped else 0.0, size / BASE_SIZE)
		draw_style_box(_panel(Color(0.03, 0.05, 0.06, 0.62), Color.TRANSPARENT, 3, 0), box)
		var rank_label := BurnsDeck.rank_text(card_id)
		var rank_size := 20
		while _font().get_string_size(rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x > box.size.x - 2:
			rank_size -= 1
		draw_string(_font(), box.position + Vector2(0, 18), rank_label, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, rank_size, color)
		_draw_suit(SUIT_SHAPES[suit], box.position + Vector2(box.size.x / 2, 23.2), 4.3, color)
	draw_set_transform(Vector2.ZERO, 0, size / BASE_SIZE)

func _draw_suit(suit: int, center: Vector2, radius: float, color: Color, inverted := false) -> void:
	var rotation := -1.0 if inverted else 1.0
	var points := BurnsDeckArt.suit_outline(suit)
	if not points.is_empty():
		var transformed := PackedVector2Array()
		for point in points:
			transformed.append(center + point * radius * rotation)
		_fill_smooth(transformed, color)

func _fill_smooth(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	# Canvas polygons lack edge antialiasing; a matching fine contour smooths them
	# at phone scale without relying on the viewport's MSAA or font suit glyphs.
	var contour := points.duplicate()
	contour.append(points[0])
	draw_polyline(contour, color, 0.35, true)

func _draw_compact() -> void:
	# Draw in actual logical pixels: stretching a card to a narrow strip ruins its rank.
	draw_set_transform(Vector2.ZERO)
	var active := highlighted or focused
	var style := _panel(Color("122022") if empty_slot else Color("111719"), Color("ffe2a9") if active else Color(COPPER, 0.36), int(minf(14, size.y / 2)), 2 if active else 1)
	if hovered: style.border_color = COPPER
	var width := minf(size.x, maxf(64, size.y * 2.3))
	var rect := Rect2((size.x - width) / 2, 0, width, size.y)
	draw_style_box(style, rect)
	var font_size := int(clampf(size.y * 0.65, 11, 24))
	var baseline := size.y / 2 + _font().get_ascent(font_size) / 2 - _font().get_descent(font_size) / 2
	if empty_slot and slot_suit < 0:
		draw_string(_font(), Vector2(rect.position.x, baseline), "—", HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(COPPER, 0.7))
	else:
		var suit := slot_suit if empty_slot else BurnsDeck.suit_of(card_id)
		var color := COPPER if empty_slot else (RED if suit in BurnsDeck.RED_SUITS else INK)
		var rank := "A" if empty_slot else BurnsDeck.rank_text(card_id)
		draw_string(_font(), Vector2(rect.position.x + width * 0.18, baseline), rank, HORIZONTAL_ALIGNMENT_CENTER, width * 0.34, font_size, color)
		_draw_suit(SUIT_SHAPES[suit], Vector2(rect.position.x + width * 0.73, size.y / 2), minf(10, size.y * 0.27), color)

func _draw_card_texture(texture: Texture2D, rect: Rect2) -> void:
	# Rounded mesh clips the artwork's square outer corners to the card silhouette.
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var radius := 5.5
	var centers := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in range(4):
		for step in range(13):
			var angle := PI + corner * PI / 2 + step * PI / 24
			var point: Vector2 = centers[corner] + Vector2.from_angle(angle) * radius
			vertices.append(point)
			uv.append((point - rect.position) / rect.size)
	draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)

func _font() -> Font:
	return get_theme_font("font", "Label")

func _panel(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = fill
	panel.border_color = border
	panel.set_border_width_all(width)
	panel.set_corner_radius_all(radius)
	panel.anti_aliasing = true
	panel.anti_aliasing_size = 0.6
	return panel
