class_name BurnsBot
extends RefCounted
## Decisions depend only on exposed cards. No reading the next play-pile card.
static func choose(game: BurnsGame, seat: int) -> Dictionary:
	var state := game.view()
	if state.phase == "review" and seat in state.reviewers:
		# Public board at turn end is sufficient to challenge a remaining legal play.
		# Do not inspect the engine's private adjudication record.
		var visible := game.moves()
		for move in visible:
			if not move.get("optional", false): return {"type": "burn"}
		return {"type": "pass"}
	if state.phase == "penalty" and seat == state.donors[0]:
		var p: Dictionary = state.players[seat]
		return {"type": "donate", "source": "discard" if p.discard_count > 0 else ("play" if p.play_count > 0 else "reserve")}
	if state.phase != "turn" or seat != state.active: return {}
	var moves := game.moves()
	moves = moves.filter(func(m: Dictionary): return not m.get("optional", false))
	moves.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.priority != b.priority: return a.priority < b.priority
		if a.source == "row" and b.source != "row": return false
		if b.source == "row" and a.source != "row": return true
		return a.card < b.card)
	if not moves.is_empty(): return moves[0]
	var p: Dictionary = state.players[seat]
	if p.held >= 0: return {"type": "end"}
	if p.play_count > 0: return {"type": "draw"}
	if p.reserve_count > 0: return {"type": "draw", "source": "bottom"}
	return {"type": "end"}
