class_name BurnsCardView
extends Control
## Resolution-independent original card artwork, with no font dependency for suits.

var card_id: int = 0
var face_down := false
var empty_slot := false
var compact := false
var slot_suit := -1
var slot_text := ""
var highlighted := false
var focused := false
var hovered := false
const INK := Color("192d31")
const RED := Color("b24632")
const COPPER := Color("bd9563")

func _ready() -> void:
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
	style.bg_color = Color("123e44") if face_down else Color("f4ead6")
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
		draw_rect(rect.grow(-9), COPPER, false, 1)
		var center := card_size / 2
		for radius in [14.0, 22.0, 30.0]:
			draw_arc(center, radius, 0, TAU, 64, COPPER, 1, true)
		for angle in range(0, 360, 45):
			var direction := Vector2.from_angle(deg_to_rad(angle))
			draw_line(center + direction * 13, center + direction * 31, COPPER, 1, true)
		return
	var suit := BurnsDeck.suit_of(card_id)
	var color := RED if suit in BurnsDeck.RED_SUITS else INK
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 26), BurnsDeck.rank_text(card_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
	draw_string(font, Vector2(card_size.x - 27, card_size.y - 11), BurnsDeck.rank_text(card_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
	_draw_suit([0, 1, 4, 3][suit], card_size / 2, 18, color)
	_draw_suit([0, 1, 4, 3][suit], Vector2(18, 41), 6, color)

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
	style.bg_color = Color("12383e") if empty_slot else Color("f4ead6")
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
