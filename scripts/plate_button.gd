class_name BurnsPlateButton
extends Button
## Engraved plates rather than flat rounded boxes. Each plate is lit from above,
## bevelled at both edges, ruled twice in copper and ticked at the corners, so a
## control reads as the same printed object as a card instead of a theme default.
##
## Hierarchy is carried by KIND, not by size: one warm PRIMARY call to action,
## quiet PLATE choices under it, and QUIET text actions that drop the plate
## entirely. A screen of identical filled pills is what makes a menu look
## untouched, so the tertiary row deliberately has no box at all.

enum Kind {PLATE, PRIMARY, QUIET}

const CREAM := Color("f4ead6")
const COPPER := Color("bd9563")
const GOLD := Color("d1ac78")
## Matches BurnsCardView's silhouette so plates and cards share a corner.
const RADIUS := 7.0
const TICK := 5.0

var kind: Kind = Kind.PLATE
var _held := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The plate and its lettering are drawn here, so the theme must contribute
	# nothing; otherwise Godot's own box shows through underneath.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(func(): _held = true; queue_redraw())
	button_up.connect(func(): _held = false; queue_redraw())

func _draw() -> void:
	var hovered := is_hovered() and not disabled
	var pressed := _held and not disabled
	# A pressed plate sinks into its bed instead of only changing colour.
	var rect := Rect2(Vector2.ZERO, size).grow(-1)
	if pressed: rect.position.y += 1
	if kind == Kind.QUIET:
		_draw_quiet(rect, hovered, pressed)
	else:
		_draw_plate(rect, hovered, pressed)
	if has_focus() and not disabled:
		# Keyboard focus stays unmistakable; the rules screen documents Tab and Enter.
		draw_style_box(_frame(Color(GOLD, 0.95), 2), rect.grow(1))

func _draw_plate(rect: Rect2, hovered: bool, pressed: bool) -> void:
	var primary := kind == Kind.PRIMARY
	var top := Color("c2603c") if primary else Color("1d3538")
	var bottom := Color("8d3f28") if primary else Color("0f1e20")
	if disabled:
		top = Color("222d2e")
		bottom = Color("1a2425")
	elif hovered:
		top = top.lightened(0.10)
		bottom = bottom.lightened(0.08)
	if pressed:
		# Flipping the gradient turns the lighting over and reads as inward travel.
		var swap := top
		top = bottom.darkened(0.05)
		bottom = swap
	if not disabled:
		var bed := StyleBoxFlat.new()
		bed.bg_color = Color("070b0c")
		bed.set_corner_radius_all(int(RADIUS))
		bed.shadow_color = Color(0, 0, 0, 0.16 if pressed else 0.38)
		bed.shadow_size = 3 if pressed else 6
		bed.shadow_offset = Vector2(0, 1 if pressed else 3)
		bed.anti_aliasing = true
		draw_style_box(bed, rect)
	_draw_gradient(rect, top, bottom)
	_draw_bevel(rect, primary, pressed)
	var rule := Color("6d5a44") if disabled else (Color("e7c79c") if primary else COPPER)
	if hovered and not disabled: rule = Color("f0d5ae") if primary else Color("d8b483")
	draw_style_box(_frame(rule, 1), rect)
	var inner := rect.grow(-3)
	if inner.size.x > 8 and inner.size.y > 8:
		draw_style_box(_frame(Color(rule, 0.34), 1), inner)
		_draw_ticks(inner, Color(rule, 0.85 if primary else 0.6))
	_draw_label(rect, CREAM if not disabled else Color("74807c"), 0.0, false)

## No plate at all: letterspaced caps over a hairline rule, so tertiary actions
## sit quietly instead of competing with the call to action above them.
func _draw_quiet(rect: Rect2, hovered: bool, pressed: bool) -> void:
	if hovered or pressed:
		_draw_gradient(rect, Color(0.11, 0.21, 0.22, 0.55), Color(0.06, 0.13, 0.14, 0.55))
		draw_style_box(_frame(Color(COPPER, 0.5), 1), rect)
	var ink := Color("74807c") if disabled else (CREAM if hovered else Color("c3b7a4"))
	_draw_label(rect, ink, 1.4, true)
	if not hovered and not pressed:
		var y := rect.end.y - 7.0
		var inset := rect.size.x * 0.22
		draw_line(Vector2(rect.position.x + inset, y), Vector2(rect.end.x - inset, y), Color(COPPER, 0.34 if disabled else 0.6), 1.0, true)

func _draw_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	# Per-vertex colour gives a real vertical gradient without a texture or shader.
	var points := _rounded(rect)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
	draw_polygon(points, colors)

func _draw_bevel(rect: Rect2, primary: bool, pressed: bool) -> void:
	var radius := minf(RADIUS, minf(rect.size.x, rect.size.y) / 2)
	var lit := Color(1, 0.94, 0.84, 0.06 if pressed else (0.22 if primary else 0.13))
	var shade := Color(0, 0, 0, 0.30)
	var left := rect.position.x + radius
	var right := rect.end.x - radius
	if right <= left: return
	draw_line(Vector2(left, rect.position.y + 1.5), Vector2(right, rect.position.y + 1.5), lit, 1.0, true)
	draw_line(Vector2(left, rect.end.y - 1.5), Vector2(right, rect.end.y - 1.5), shade, 1.0, true)

func _draw_ticks(rect: Rect2, color: Color) -> void:
	var reach := minf(TICK, minf(rect.size.x, rect.size.y) / 3.0)
	if reach < 2.0: return
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var point := rect.position + rect.size * corner
		var step := Vector2(1 - corner.x * 2, 1 - corner.y * 2) * reach
		draw_line(point, point + Vector2(step.x, 0), color, 1.0, true)
		draw_line(point, point + Vector2(0, step.y), color, 1.0, true)

func _draw_label(rect: Rect2, color: Color, tracking: float, caps: bool) -> void:
	if text.is_empty(): return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var label := text.to_upper() if caps else text
	var available := rect.size.x - 16
	while label.length() > 1 and _width(font, label, font_size, tracking) > available:
		label = label.substr(0, label.length() - 2) + "…"
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var origin := Vector2(rect.get_center().x - _width(font, label, font_size, tracking) / 2, baseline)
	# Letterpress: the type is struck into the plate rather than laid on top.
	_draw_tracked(font, origin + Vector2(0, 1), label, font_size, Color(0.02, 0.04, 0.05, 0.55), tracking)
	_draw_tracked(font, origin, label, font_size, color, tracking)

func _draw_tracked(font: Font, origin: Vector2, label: String, font_size: int, color: Color, tracking: float) -> void:
	if is_zero_approx(tracking):
		draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		return
	var pen := origin
	for index in label.length():
		var glyph := label[index]
		draw_string(font, pen, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		pen.x += font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking

func _width(font: Font, label: String, font_size: int, tracking: float) -> float:
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width + tracking * maxf(0, label.length() - 1)

func _frame(color: Color, width: int) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.TRANSPARENT
	frame.border_color = color
	frame.set_border_width_all(width)
	frame.set_corner_radius_all(int(RADIUS))
	frame.anti_aliasing = true
	frame.anti_aliasing_size = 0.6
	return frame

static func _rounded(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := minf(RADIUS, minf(rect.size.x, rect.size.y) / 2)
	var centers := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in range(4):
		for step in range(5):
			var angle := PI + corner * PI / 2 + step * PI / 8
			points.append(centers[corner] + Vector2.from_angle(angle) * radius)
	return points
