class_name BurnsDeckArt
extends RefCounted
## Faces are baked by tools/bake_deck.py: engraved frame, centrepiece art and title.
## The two supplied portraits are used whole and are never recomposited or stretched.
const BACK := preload("res://assets/art/deck/back.webp")
## Artwork window inside the baked frame, in BurnsCardView.BASE_SIZE units.
const WINDOW := Rect2(9.3, 9.9, 57.2, 86.7)
const FIELDS := [
	preload("res://assets/art/deck/field_0.webp"), preload("res://assets/art/deck/field_1.webp"),
	preload("res://assets/art/deck/field_2.webp"), preload("res://assets/art/deck/field_3.webp"),
]
const ACES := [
	preload("res://assets/art/deck/ace_0.webp"), preload("res://assets/art/deck/ace_1.webp"),
	preload("res://assets/art/deck/ace_2.webp"), preload("res://assets/art/deck/ace_3.webp"),
]
const COURTS := {
	10: preload("res://assets/art/deck/court_10.webp"), 11: preload("res://assets/art/deck/court_11.webp"),
	12: preload("res://assets/art/deck/court_12.webp"), 23: preload("res://assets/art/deck/court_23.webp"),
	24: preload("res://assets/art/deck/court_24.webp"), 25: preload("res://assets/art/deck/court_25.webp"),
	36: preload("res://assets/art/deck/court_36.webp"), 37: preload("res://assets/art/deck/court_37.webp"),
	38: preload("res://assets/art/deck/court_38.webp"), 50: preload("res://assets/art/deck/court_50.webp"),
}
const SUPPLIED := {
	49: preload("res://assets/art/deck/faces/jack_spades.tres"),
	51: preload("res://assets/art/deck/faces/king_spades.jpg"),
}

## Complete cards the owner supplied. They carry their own frame, so they are
## fitted whole at their native aspect instead of filling the card.
static func supplied(card: int) -> Texture2D:
	return SUPPLIED.get(card)

## The baked full-bleed face for every other card.
static func face(card: int) -> Texture2D:
	if COURTS.has(card):
		return COURTS[card]
	var suit := card / 13
	return ACES[suit] if card % 13 == 0 else FIELDS[suit]

## Pip grid centred on the artwork window rather than on the card.
const PIP_CENTER := Vector2(37.9, 53.25)
const PIP_COLUMNS := [25.4, 50.4]

static func pip_positions(rank: int) -> Array[Vector2]:
	if rank == 1: return [PIP_CENTER]
	var result: Array[Vector2] = []
	if rank <= 3:
		result = [Vector2(PIP_CENTER.x, 26.2), Vector2(PIP_CENTER.x, 80.3)]
		if rank == 3: result.append(PIP_CENTER)
		return result
	var ys: Array = [26.2, 80.3] if rank <= 5 else ([26.2, 53.25, 80.3] if rank <= 8 else [24.3, 43.3, 63.2, 82.2])
	for x in PIP_COLUMNS:
		for y in ys: result.append(Vector2(x, y))
	match rank:
		5, 9: result.append(PIP_CENTER)
		7: result.append(Vector2(PIP_CENTER.x, 39.7))
		8: result.append_array([Vector2(PIP_CENTER.x, 39.7), Vector2(PIP_CENTER.x, 66.8)])
		10: result.append_array([Vector2(PIP_CENTER.x, 33.4), Vector2(PIP_CENTER.x, 73.1)])
	return result

static var _suit_cache: Dictionary = {}

static func suit_outline(shape: int) -> PackedVector2Array:
	if _suit_cache.has(shape): return _suit_cache[shape]
	var points := PackedVector2Array()
	match shape:
		0: # Diamond, deliberately narrower than the rounded suits.
			points = PackedVector2Array([Vector2(0, -1), Vector2(0.66, 0), Vector2(0, 1), Vector2(-0.66, 0)])
		1: # Club: a continuous trefoil silhouette avoids seams between circles.
			points.append(Vector2(-0.32, 1))
			_curve(points, Vector2(-0.2, 0.84), Vector2(-0.14, 0.64), Vector2(-0.13, 0.45))
			_curve(points, Vector2(-0.5, 0.79), Vector2(-0.98, 0.48), Vector2(-0.94, 0.06))
			_curve(points, Vector2(-0.91, -0.35), Vector2(-0.44, -0.53), Vector2(-0.25, -0.28))
			_curve(points, Vector2(-0.65, -0.62), Vector2(-0.34, -1), Vector2(0, -1))
			_curve(points, Vector2(0.34, -1), Vector2(0.65, -0.62), Vector2(0.25, -0.28))
			_curve(points, Vector2(0.44, -0.53), Vector2(0.91, -0.35), Vector2(0.94, 0.06))
			_curve(points, Vector2(0.98, 0.48), Vector2(0.5, 0.79), Vector2(0.13, 0.45))
			_curve(points, Vector2(0.14, 0.64), Vector2(0.2, 0.84), Vector2(0.32, 1))
		3: # Spade: tapered shoulder, curved lobes, flared stem.
			points.append(Vector2(0, -1))
			_curve(points, Vector2(-0.21, -0.66), Vector2(-0.9, -0.26), Vector2(-0.89, 0.1))
			_curve(points, Vector2(-0.92, 0.62), Vector2(-0.34, 0.77), Vector2(-0.12, 0.48))
			_curve(points, Vector2(-0.13, 0.73), Vector2(-0.23, 0.9), Vector2(-0.32, 1))
			points.append(Vector2(0.32, 1))
			_curve(points, Vector2(0.23, 0.9), Vector2(0.13, 0.73), Vector2(0.12, 0.48))
			_curve(points, Vector2(0.34, 0.77), Vector2(0.92, 0.62), Vector2(0.89, 0.1))
			_curve(points, Vector2(0.9, -0.26), Vector2(0.21, -0.66), Vector2(0, -1))
		4: # Heart: continuous Bezier lobes and a clean lower point.
			points.append(Vector2(0, 1))
			_curve(points, Vector2(-0.2, 0.65), Vector2(-0.9, 0.05), Vector2(-0.9, -0.35))
			_curve(points, Vector2(-0.9, -1), Vector2(-0.25, -1.1), Vector2(0, -0.47))
			_curve(points, Vector2(0.25, -1.1), Vector2(0.9, -1), Vector2(0.9, -0.35))
			_curve(points, Vector2(0.9, 0.05), Vector2(0.2, 0.65), Vector2(0, 1))
	# Duplicate endpoints make triangulation less reliable at small scales.
	if points.size() > 1 and points[-1].is_equal_approx(points[0]): points.resize(points.size() - 1)
	_suit_cache[shape] = points
	return points

static func _curve(points: PackedVector2Array, first: Vector2, second: Vector2, end: Vector2) -> void:
	var start := points[-1]
	for step in range(1, 13):
		points.append(start.bezier_interpolate(first, second, end, float(step) / 12.0))
