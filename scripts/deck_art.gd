class_name BurnsDeckArt
extends RefCounted
## Full-card portraits are fitted without cropping or changing the supplied image.
const FACE := preload("res://assets/art/deck/raven_face.png")
const BACK := preload("res://assets/art/deck/raven_back.png")
const PORTRAITS := {49: preload("res://assets/art/deck/faces/jack_spades.tres"), 51: preload("res://assets/art/deck/faces/king_spades.jpg")}

static func portrait(card: int) -> Texture2D:
	return PORTRAITS.get(card)

static func pip_positions(rank: int) -> Array[Vector2]:
	if rank == 1: return [Vector2(38, 57)]
	var result: Array[Vector2] = []
	if rank <= 3:
		result = [Vector2(38, 30), Vector2(38, 84)]
		if rank == 3: result.append(Vector2(38, 57))
		return result
	var ys: Array = [30, 84] if rank <= 5 else ([30, 57, 84] if rank <= 8 else [28, 47, 67, 86])
	for x in [27, 49]:
		for y in ys: result.append(Vector2(x, y))
	match rank:
		5, 9: result.append(Vector2(38, 57))
		7: result.append(Vector2(38, 43))
		8: result.append_array([Vector2(38, 43), Vector2(38, 71)])
		10: result.append_array([Vector2(38, 37), Vector2(38, 77)])
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
