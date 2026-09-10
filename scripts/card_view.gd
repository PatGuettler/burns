class_name BurnsCardView
extends Control
## Original engraved art, fitted portraits, and smooth, font-independent suit pips.

var card_id: int = 0
var face_down := false
var empty_slot := false
var compact := false
## Portrait inspection never places gameplay indices over the supplied image.
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
	var accent := Color("ffe2a9") if highlighted or focused else COPPER
	if highlighted or focused:
		var glow := _panel(Color(0.91, 0.7, 0.36, 0.12), Color(0.98, 0.79, 0.43, 0.38), 9, 1)
		glow.shadow_color = Color(0.91, 0.7, 0.36, 0.2)
		glow.shadow_size = 5
		draw_style_box(glow, rect.grow(2))
	var style := _panel(Color("111719"), accent, 7, 2 if highlighted or focused else 1)
	if empty_slot:
		style.bg_color = Color(0.04, 0.11, 0.12, 0.5)
		style.border_color = Color(accent, 0.64)
	elif hovered:
		style.border_color = Color("e2c698")
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 2 if empty_slot else 5
	style.shadow_offset = Vector2(0, 3)
	draw_style_box(style, rect)
	if empty_slot:
		_draw_empty()
		return
	if face_down:
		_draw_card_texture(BurnsDeckArt.BACK, rect.grow(-1.5))
		return
	var portrait := BurnsDeckArt.portrait(card_id)
	if portrait:
		# The complete source image stays at its native aspect ratio, including its frame.
		var fitted := portrait.get_size() * minf(73.0 / portrait.get_width(), 111.0 / portrait.get_height())
		draw_texture_rect(portrait, Rect2((BASE_SIZE - fitted) / 2, fitted), false)
	else:
		_draw_card_texture(BurnsDeckArt.FACE, rect.grow(-1.5))
	var suit := BurnsDeck.suit_of(card_id)
	var color := RED if suit in BurnsDeck.RED_SUITS else INK
	var rank := BurnsDeck.rank_of(card_id)
	if not portrait:
		if rank <= 10:
			if rank == 1:
				draw_arc(Vector2(38, 57), 20.5, 0, TAU, 96, Color(COPPER, 0.7), 0.5, true)
				draw_arc(Vector2(38, 57), 22, 0.1, PI - 0.1, 48, Color(COPPER, 0.3), 0.5, true)
				draw_arc(Vector2(38, 57), 22, PI + 0.1, TAU - 0.1, 48, Color(COPPER, 0.3), 0.5, true)
			for pip in BurnsDeckArt.pip_positions(rank):
				# The lower half is inverted just like a traditional double-ended deck.
				_draw_suit(SUIT_SHAPES[suit], pip, 14 if rank == 1 else 6.3, color, pip.y > 57)
		else:
			_draw_portrait_placeholder(rank, suit, color)
	if portrait and (artwork_only or size.x >= 160): return
	_draw_indices(color, suit)

func _draw_empty() -> void:
	var baseline := 49.0 if slot_suit >= 0 else 64.0
	draw_string(_font(), Vector2(0, baseline), slot_text, HORIZONTAL_ALIGNMENT_CENTER, 76, 22, Color(COPPER, 0.85))
	if slot_suit >= 0:
		_draw_suit(SUIT_SHAPES[slot_suit], Vector2(38, 77), 11, Color(COPPER, 0.75))

func _draw_indices(color: Color, suit: int) -> void:
	# Small rounded index insets leave the engraved frame visible around the card.
	for flipped in [false, true]:
		draw_set_transform(size if flipped else Vector2.ZERO, PI if flipped else 0.0, size / BASE_SIZE)
		var inset := _panel(Color("111719"), Color.TRANSPARENT, 3, 0)
		draw_style_box(inset, Rect2(3, 3, 17, 32))
		var rank_label := BurnsDeck.rank_text(card_id)
		var rank_size := 22
		while _font().get_string_size(rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x > 17:
			rank_size -= 1
		draw_string(_font(), Vector2(3, 23), rank_label, HORIZONTAL_ALIGNMENT_CENTER, 17, rank_size, color)
		_draw_suit(SUIT_SHAPES[suit], Vector2(11.5, 29.5), 4.6, color)

func _draw_portrait_placeholder(rank: int, suit: int, color: Color) -> void:
	# A deliberate court seal until the owner supplies the remaining portraits.
	var center := Vector2(38, 54)
	draw_arc(center, 20, 0, TAU, 96, Color(COPPER, 0.8), 0.7, true)
	draw_arc(center, 18.3, 0, TAU, 96, Color(COPPER, 0.3), 0.4, true)
	var crown := PackedVector2Array([Vector2(25, 44), Vector2(30, 48), Vector2(33, 41), Vector2(38, 47), Vector2(43, 41), Vector2(46, 48), Vector2(51, 44), Vector2(48, 54), Vector2(28, 54)])
	_fill_smooth(crown, COPPER)
	draw_line(Vector2(29, 57), Vector2(47, 57), Color(COPPER, 0.8), 0.75, true)
	for point in [Vector2(25, 43), Vector2(33, 40), Vector2(43, 40), Vector2(51, 43)]:
		draw_circle(point, 0.9, INK, true, -1, true)
	_draw_suit(SUIT_SHAPES[suit], Vector2(38, 65), 4.6, color)
	var title: String = {11: "JACK", 12: "QUEEN", 13: "KING"}[rank]
	draw_string(_font(), Vector2(21, 87), title, HORIZONTAL_ALIGNMENT_CENTER, 34, 7, color)
	if size.x >= 130:
		draw_string(_font(), Vector2(17, 95), "PORTRAIT TO COME", HORIZONTAL_ALIGNMENT_CENTER, 42, 3, COPPER)

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
	# Rounded mesh clips only the template's white outer corners.
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
