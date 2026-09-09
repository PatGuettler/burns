class_name BurnsSafeLayout
extends RefCounted
## Convert platform pixel insets into the logical canvas used by the table.
static func margins(pixels: Vector2, logical: Vector2, safe: Rect2) -> Vector4:
	if pixels.x <= 0 or pixels.y <= 0 or not safe.has_area(): return Vector4(16, 16, 16, 16)
	var visible := safe.intersection(Rect2(Vector2.ZERO, pixels))
	if not visible.has_area(): return Vector4(16, 16, 16, 16)
	var scale := logical / pixels
	return Vector4(maxf(16, visible.position.x * scale.x + 8), maxf(16, visible.position.y * scale.y + 8), maxf(16, (pixels.x - visible.end.x) * scale.x + 8), maxf(16, (pixels.y - visible.end.y) * scale.y + 8))
