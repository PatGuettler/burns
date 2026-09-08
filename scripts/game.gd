class_name BurnsGame
extends RefCounted
## Authoritative state. Array backs are pile tops; array fronts are pile bottoms.
## Only view() crosses the network. Never transmit s or the shuffle seed.

var s: Dictionary = {}

func start(names: Array, seed_value: int) -> void:
	s = BurnsDeck.deal(names.size(), seed_value)
	if s.has("error"):
		return
	for i in range(names.size()):
		s.players[i].merge({"name": str(names[i]).left(24), "reserve": [], "held": -1})
	s.merge({"version": 1, "revision": 0, "active": 0, "phase": "turn", "turn": 1,
		"missed": "", "reviewers": [], "donors": [], "burnt": -1, "winner": -1,
		"log": ["The table is dealt. Player 1 begins."], "turn_moves": 0})

static func alternate(a: int, b: int) -> bool:
	return (BurnsDeck.suit_of(a) in BurnsDeck.RED_SUITS) != (BurnsDeck.suit_of(b) in BurnsDeck.RED_SUITS)

func _log(message: String) -> void:
	s.log.append(message)
	if s.log.size() > 30:
		s.log.pop_front()

func remaining(seat: int) -> int:
	var p: Dictionary = s.players[seat]
	return p.play.size() + p.discard.size() + p.reserve.size() + (1 if p.held >= 0 else 0)

func _normalize() -> void:
	var p: Dictionary = s.players[s.active]
	if p.play.is_empty() and p.held == -1 and p.reserve.is_empty() and not p.discard.is_empty():
		p.reserve = p.discard
		p.discard = []

func sources() -> Array:
	var result: Array = []
	var p: Dictionary = s.players[s.active]
	if p.held >= 0:
		result.append({"kind": "held", "index": 0, "offset": 0, "cards": [p.held]})
	if not p.discard.is_empty():
		result.append({"kind": "discard", "index": s.active, "offset": 0, "cards": [p.discard.back()]})
	if not p.reserve.is_empty():
		result.append({"kind": "reserve", "index": s.active, "offset": 0, "cards": [p.reserve.back()]})
	for row in range(5):
		for offset in range(s.rows[row].size()):
			result.append({"kind": "row", "index": row, "offset": offset, "cards": s.rows[row].slice(offset)})
	return result

func moves() -> Array:
	var result: Array = []
	for source in sources():
		var card: int = source.cards[0]
		var rank := BurnsDeck.rank_of(card)
		var suit := BurnsDeck.suit_of(card)
		if source.cards.size() == 1 and s.foundations[suit].size() == rank - 1:
			result.append(_move(source, "foundation", suit, 0))
		for row in range(5):
			if source.kind == "row" and source.index == row:
				continue
			var target: Array = s.rows[row]
			# Moving a whole row into an empty row changes no opportunities; it is not compulsory.
			if target.is_empty():
				result.append(_move(source, "row", row, 1))
			elif BurnsDeck.rank_of(target.back()) == rank + 1 and alternate(card, target.back()):
				result.append(_move(source, "row", row, 1))
		if source.kind == "row" or source.cards.size() != 1:
			continue
		for seat in range(s.players.size()):
			if seat == s.active:
				continue
			var discard: Array = s.players[seat].discard
			if discard.is_empty() or (absi(BurnsDeck.rank_of(discard.back()) - rank) == 1 and alternate(card, discard.back())):
				result.append(_move(source, "opponent", seat, 2))
	return result

func _move(source: Dictionary, kind: String, index: int, priority: int) -> Dictionary:
	return {"type": "move", "source": source.kind, "index": source.index, "offset": source.offset,
		"target": kind, "to": index, "priority": priority, "card": source.cards[0], "count": source.cards.size(),
		"optional": source.kind == "row" and kind == "row" and (source.offset > 0 or s.rows[index].is_empty())}

func describe(move: Dictionary) -> String:
	var place: String = {"foundation": "the Aces area", "row": "row %d" % (move.to + 1), "opponent": "another player's discard"}[move.target]
	return "%s could play to %s." % [BurnsDeck.card_name(move.card), place]

func act(seat: int, action: Dictionary) -> String:
	if s.is_empty() or seat < 0 or seat >= s.players.size():
		return "Unknown player."
	if s.phase == "finished":
		return "This game has finished."
	var error := ""
	match str(action.get("type", "")):
		"burn", "pass":
			error = _review(seat, action.type)
		"donate":
			error = _donate(seat, str(action.get("source", "")))
		_:
			if s.phase != "turn" or seat != s.active:
				return "Wait for your turn."
			match str(action.get("type", "")):
				"draw": error = _draw(str(action.get("source", "play")))
				"move": error = _play(action)
				"end": error = _end()
				_: error = "Unknown action."
	if error.is_empty():
		s.revision += 1
	return error

func _draw(source: String) -> String:
	_normalize()
	var p: Dictionary = s.players[s.active]
	if p.held != -1:
		return "Play or discard the revealed card first."
	if source == "play" and not p.play.is_empty():
		p.held = p.play.pop_back()
	elif source == "bottom" and not p.reserve.is_empty():
		p.held = p.reserve.pop_front()
	else:
		return "There is no card to draw there."
	return ""

func _play(action: Dictionary) -> String:
	var legal := moves()
	var chosen: Dictionary = {}
	var best := 3
	for move in legal:
		if not move.optional: best = mini(best, move.priority)
		var matches := true
		for key in ["source", "index", "offset", "target", "to"]:
			if action.get(key) != move[key]: matches = false
		if matches: chosen = move
	if chosen.is_empty():
		return "That placement does not fit. Rows go down in alternating colors; discards go up or down."
	if chosen.priority > best and s.missed.is_empty():
		for move in legal:
			if move.priority == best:
				s.missed = "A higher-priority play was skipped. " + describe(move)
				break
	var p: Dictionary = s.players[s.active]
	var cards: Array = []
	match chosen.source:
		"held": cards = [p.held]; p.held = -1
		"discard": cards = [p.discard.pop_back()]
		"reserve": cards = [p.reserve.pop_back()]
		"row":
			cards = s.rows[chosen.index].slice(chosen.offset)
			s.rows[chosen.index].resize(chosen.offset)
	match chosen.target:
		"foundation": s.foundations[chosen.to].append_array(cards)
		"row": s.rows[chosen.to].append_array(cards)
		"opponent": s.players[chosen.to].discard.append_array(cards)
	s.turn_moves += 1
	_log("%s played %s%s." % [p.name, BurnsDeck.card_name(chosen.card), " and its sequence" if cards.size() > 1 else ""])
	_normalize()
	return ""

func _end() -> String:
	var p: Dictionary = s.players[s.active]
	# A player with cards must draw before ending; reserve-only turns can discard the top.
	if p.held == -1 and not p.play.is_empty():
		return "Reveal a card, then play it or discard it to end your turn."
	var available := moves().filter(func(m: Dictionary): return not m.optional)
	if not available.is_empty() and s.missed.is_empty():
		s.missed = describe(available[0])
	var discarded := -1
	if p.held >= 0:
		discarded = p.held
		p.held = -1
	elif not p.reserve.is_empty():
		discarded = p.reserve.pop_back()
	elif not p.discard.is_empty():
		return "Play from your discard or reveal a card first."
	if discarded >= 0:
		p.discard.append(discarded)
		_log("%s discarded %s." % [p.name, BurnsDeck.card_name(discarded)])
		if not p.reserve.is_empty():
			# Preserve existing order; former face-up top is the next face-down top.
			p.play = p.reserve
			p.reserve = []
	else:
		_log("%s has no cards left; last chance to call Burns." % p.name)
	s.phase = "review"
	s.reviewers = []
	for seat in range(s.players.size()):
		if seat != s.active: s.reviewers.append(seat)
	return ""

func _review(seat: int, kind: String) -> String:
	if s.phase != "review" or seat not in s.reviewers:
		return "You cannot challenge this turn now."
	if kind == "pass":
		s.reviewers.erase(seat)
		if s.reviewers.is_empty(): _next_turn()
		return ""
	var correct: bool = not s.missed.is_empty()
	s.burnt = s.active if correct else seat
	_log("%s called Burns. %s" % [s.players[seat].name, s.missed if correct else "False call: no playable move was missed."])
	_log("%s receives one card from each other player." % s.players[s.burnt].name)
	s.donors = []
	# Fixed clockwise donation order makes pile ordering deterministic across clients.
	for offset in range(1, s.players.size()):
		var donor: int = (s.burnt + offset) % s.players.size()
		if remaining(donor) > 0: s.donors.append(donor)
	s.phase = "penalty"
	s.reviewers = []
	if s.donors.is_empty(): _next_turn()
	return ""

func _donate(seat: int, source: String) -> String:
	if s.phase != "penalty" or s.donors.is_empty() or s.donors[0] != seat:
		return "Wait for your turn to give a penalty card."
	var p: Dictionary = s.players[seat]
	var card := -1
	if source in ["play", "discard", "reserve"] and not p[source].is_empty():
		card = p[source].pop_back()
	else:
		return "Choose the top of a nonempty pile."
	s.players[s.burnt].play.push_front(card)
	s.donors.pop_front()
	if s.donors.is_empty(): _next_turn()
	return ""

func _next_turn() -> void:
	for seat in range(s.players.size()):
		if remaining(seat) == 0:
			s.winner = seat
			s.phase = "finished"
			_log("%s wins the table!" % s.players[seat].name)
			return
	s.active = (s.active + 1) % s.players.size()
	s.turn += 1
	s.phase = "turn"
	s.missed = ""
	s.burnt = -1
	s.turn_moves = 0
	_normalize()
	_log("%s's turn." % s.players[s.active].name)

func view() -> Dictionary:
	# Even the active client only sees a play card after an explicit draw.
	var result := s.duplicate(true)
	result.erase("missed")
	for p in result.players:
		p.play_count = p.play.size()
		p.discard_count = p.discard.size()
		p.reserve_count = p.reserve.size()
		p.discard_top = p.discard.back() if not p.discard.is_empty() else -1
		p.reserve_top = p.reserve.back() if not p.reserve.is_empty() else -1
		p.erase("play")
		p.erase("discard")
		p.erase("reserve")
	return result

func invariant() -> bool:
	var cards: Array = []
	for row in s.rows: cards.append_array(row)
	for pile in s.foundations: cards.append_array(pile)
	for p in s.players:
		for pile in [p.play, p.discard, p.reserve]: cards.append_array(pile)
		if p.held >= 0: cards.append(p.held)
	cards.sort()
	return cards == BurnsDeck.create_deck()

func restore(value: Variant) -> bool:
	if not value is Dictionary: return false
	var required := ["version", "revision", "active", "phase", "turn", "missed", "reviewers", "donors", "burnt", "winner", "log", "turn_moves", "rows", "foundations", "players"]
	if not value.has_all(required) or value.version != 1: return false
	if not value.players is Array or value.players.size() < 2 or value.players.size() > 8: return false
	for key in ["revision", "active", "turn", "burnt", "winner", "turn_moves"]:
		if not value[key] is int: return false
	if value.active < 0 or value.active >= value.players.size(): return false
	if value.burnt < -1 or value.burnt >= value.players.size() or value.winner < -1 or value.winner >= value.players.size(): return false
	if value.phase not in ["turn", "review", "penalty", "finished"] or not value.missed is String: return false
	if not value.log is Array or value.log.size() > 30: return false
	for entry in value.log:
		if not entry is String: return false
	for key in ["reviewers", "donors"]:
		if not value[key] is Array: return false
		for seat in value[key]:
			if not seat is int or seat < 0 or seat >= value.players.size(): return false
	if value.phase == "review" and value.reviewers.is_empty(): return false
	if value.phase == "penalty" and (value.donors.is_empty() or value.burnt < 0): return false
	if value.phase == "finished" and value.winner < 0: return false
	if not value.rows is Array or value.rows.size() != 5: return false
	if not value.foundations is Array or value.foundations.size() != 4: return false
	for group in [value.rows, value.foundations]:
		for pile in group:
			if not _valid_pile(pile): return false
	for p in value.players:
		if not p is Dictionary or not p.has_all(["name", "play", "discard", "reserve", "held"]): return false
		if not p.name is String or not p.held is int or p.held < -1 or p.held > 51: return false
		for key in ["play", "discard", "reserve"]:
			if not _valid_pile(p[key]): return false
	var previous := s
	s = value.duplicate(true)
	if not invariant():
		s = previous
		return false
	return true

func _valid_pile(value: Variant) -> bool:
	if not value is Array or value.size() > 52: return false
	for card in value:
		if not card is int or card < 0 or card > 51: return false
	return true
