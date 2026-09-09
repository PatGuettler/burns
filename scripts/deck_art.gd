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
