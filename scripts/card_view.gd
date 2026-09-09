class_name BurnsCardView
extends Control
## Engraved raster frames with resolution-independent, font-free suit pips.

var card_id: int = 0
var face_down := false
var empty_slot := false
var compact := false
var slot_suit := -1
var slot_text := ""
var highlighted := false
var focused := false
var hovered := false
const INK := Color("e4e1d9")
const RED := Color("f18b79")
const COPPER := Color("bd9563")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2.ZERO
	resized.connect(queue_redraw)
	tooltip_text = "Face-down play pile" if face_down else BurnsDeck.card_name(card_id)

func _draw() -> void:
	if compact:
		_draw_compact()
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(76, 114))
	var card_size := Vector2(76, 114)
	var rect := Rect2(Vector2.ZERO, card_size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("141919")
	if empty_slot: style.bg_color = Color(0.08, 0.18, 0.19, 0.32)
	if hovered and not empty_slot: style.bg_color = style.bg_color.lightened(0.06)
	style.border_color = Color("ffe1a0") if highlighted or focused else COPPER
	style.set_border_width_all(3 if highlighted or focused else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 2 if empty_slot else 4
	style.shadow_offset = Vector2(0, 3)
	draw_style_box(style, rect)
	if empty_slot:
		draw_string(ThemeDB.fallback_font, Vector2(0, 49 if slot_suit >= 0 else 64), slot_text, HORIZONTAL_ALIGNMENT_CENTER, 76, 22, COPPER)
		if slot_suit >= 0: _draw_suit([0, 1, 4, 3][slot_suit], Vector2(38, 77), 12, COPPER)
		return
	if face_down:
		_draw_card_texture(BurnsDeckArt.BACK, rect.grow(-2))
		return
	var portrait := BurnsDeckArt.portrait(card_id)
	if portrait:
		# Preserve the supplied composition and the person's proportions exactly.
		var fitted := portrait.get_size() * minf(72.0 / portrait.get_width(), 110.0 / portrait.get_height())
		draw_texture_rect(portrait, Rect2((card_size - fitted) / 2, fitted), false)
	else:
		_draw_card_texture(BurnsDeckArt.FACE, rect.grow(-2))
	var suit := BurnsDeck.suit_of(card_id)
	var color := RED if suit in BurnsDeck.RED_SUITS else INK
	var rank := BurnsDeck.rank_of(card_id)
	if not portrait:
		if rank <= 10:
			for pip in BurnsDeckArt.pip_positions(rank):
				_draw_suit([0, 1, 4, 3][suit], pip, 16 if rank == 1 else 6.5, color)
		else:
			_draw_portrait_placeholder(rank, suit, color)
	if portrait and size.x >= 160: return # Gallery shows the complete supplied art untouched.
	# Opaque index gutters keep ranks legible on phones and stacked rows.
	for flipped in [false, true]:
		draw_set_transform(size if flipped else Vector2.ZERO, PI if flipped else 0.0, size / card_size)
		draw_rect(Rect2(3, 3, 18, 34), Color("141919"))
		var rank_label := BurnsDeck.rank_text(card_id)
		var rank_size := 22
		while ThemeDB.fallback_font.get_string_size(rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x > 18:
			rank_size -= 1
		draw_string(ThemeDB.fallback_font, Vector2(3, 23), rank_label, HORIZONTAL_ALIGNMENT_CENTER, 18, rank_size, color)
		_draw_suit([0, 1, 4, 3][suit], Vector2(12, 30), 4.7, color)

func _draw_portrait_placeholder(rank: int, suit: int, color: Color) -> void:
	# Deliberately no invented person: the owner supplies every court portrait.
	draw_arc(Vector2(38, 54), 19, 0, TAU, 64, COPPER, 0.6, true)
	var crown := PackedVector2Array([Vector2(25, 44), Vector2(30, 48), Vector2(33, 41), Vector2(38, 47), Vector2(43, 41), Vector2(46, 48), Vector2(51, 44), Vector2(48, 55), Vector2(28, 55)])
	draw_colored_polygon(crown, COPPER)
	_draw_suit([0, 1, 4, 3][suit], Vector2(38, 65), 5, color)
	var title: String = {11: "JACK", 12: "QUEEN", 13: "KING"}[rank]
	draw_string(ThemeDB.fallback_font, Vector2(0, 86), title, HORIZONTAL_ALIGNMENT_CENTER, 76, 8, color)
	draw_string(ThemeDB.fallback_font, Vector2(0, 94), "PORTRAIT TO COME", HORIZONTAL_ALIGNMENT_CENTER, 76, 4, COPPER)

func _draw_suit(suit: int, center: Vector2, radius: float, color: Color) -> void:
	match suit:
		0:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.7, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.7, 0)]), color)
		1:
			for offset in [Vector2(0, -0.5), Vector2(-0.48, 0.2), Vector2(0.48, 0.2)]:
				draw_circle(center + offset * radius, radius * 0.5, color)
			draw_colored_polygon(PackedVector2Array([center, center + Vector2(-radius * 0.35, radius), center + Vector2(radius * 0.35, radius)]), color)
		2:
			draw_circle(center + Vector2(-radius * 0.48, radius * 0.35), radius * 0.46, color)
			draw_circle(center + Vector2(radius * 0.48, radius * 0.48), radius * 0.46, color)
			draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.48, radius * 0.2), center + Vector2(radius * 0.18, -radius), center + Vector2(radius * 0.48, radius * 0.2)]), color, maxf(1, radius * 0.09), true)
		3, 4:
			var direction := -1.0 if suit == 3 else 1.0
			draw_circle(center + Vector2(-radius * 0.4, -radius * 0.3 * direction), radius * 0.5, color)
			draw_circle(center + Vector2(radius * 0.4, -radius * 0.3 * direction), radius * 0.5, color)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.86, -radius * 0.1 * direction), center + Vector2(radius * 0.86, -radius * 0.1 * direction), center + Vector2(0, radius * direction)]), color)
			if suit == 3:
				draw_colored_polygon(PackedVector2Array([center, center + Vector2(-radius * 0.3, radius), center + Vector2(radius * 0.3, radius)]), color)
		5:
			draw_rect(Rect2(center - Vector2.ONE * radius * 0.8, Vector2.ONE * radius * 1.6), color, false, maxf(1, radius * 0.12))
			for offset in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
				draw_circle(center + offset * radius, radius * 0.12, color)

func _draw_compact() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(110, 48))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172224") if empty_slot else Color("141919")
	style.set_corner_radius_all(24)
	style.border_color = COPPER
	style.set_border_width_all(2 if highlighted or focused else 0)
	draw_style_box(style, Rect2(0, 0, 110, 48))
	if empty_slot:
		draw_string(ThemeDB.fallback_font, Vector2(0, 32), "+ / -", HORIZONTAL_ALIGNMENT_CENTER, 110, 20, COPPER)
	else:
		var suit := BurnsDeck.suit_of(card_id)
		var color := RED if suit in BurnsDeck.RED_SUITS else INK
		draw_string(ThemeDB.fallback_font, Vector2(23, 33), BurnsDeck.rank_text(card_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
		_draw_suit([0, 1, 4, 3][suit], Vector2(79, 24), 12, color)

func _draw_card_texture(texture: Texture2D, rect: Rect2) -> void:
	# Rounded mesh clips the raster's outside corners without changing the source asset.
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var radius := 6.0
	var centers := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in range(4):
		for step in range(9):
			var angle := PI + corner * PI / 2 + step * PI / 16
			var point: Vector2 = centers[corner] + Vector2.from_angle(angle) * radius
			vertices.append(point)
			uv.append((point - rect.position) / rect.size)
	draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)
