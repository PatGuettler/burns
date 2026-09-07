class_name BurnsDeck
extends RefCounted
## Immutable card IDs: suit * 13 + rank - 1. Never store texture IDs as game state.

const SUITS := ["Diamonds", "Clubs", "Cherries", "Spades", "Hearts", "Dice"]
const SYMBOLS := ["♦", "♣", "●", "♠", "♥", "⚄"]
const RED_SUITS := [0, 2, 4]

static func rank_of(card: int) -> int:
	return card % 13 + 1

static func suit_of(card: int) -> int:
	return card / 13

static func rank_text(card: int) -> String:
	var rank := rank_of(card)
	return {1: "A", 11: "J", 12: "Q", 13: "K"}.get(rank, str(rank))

static func card_name(card: int) -> String:
	return "%s of %s" % [rank_text(card), SUITS[suit_of(card)]]

static func create_deck() -> Array[int]:
	var cards: Array[int] = []
	for card in range(78):
		cards.append(card)
	return cards

static func deal(player_count: int, seed_value: int) -> Dictionary:
	if player_count < 2 or player_count > 8:
		return {"error": "Burns needs 2 to 8 players."}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards := create_deck()
	for index in range(cards.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap := cards[index]
		cards[index] = cards[other]
		cards[other] = swap
	var rows: Array = []
	for index in range(5):
		rows.append([cards.pop_back()])
	var players: Array = []
	for index in range(player_count):
		players.append({"play": [], "discard": []})
	var recipient := 0
	while not cards.is_empty():
		players[recipient % player_count].play.append(cards.pop_back())
		recipient += 1
	return {"rows": rows, "foundations": [[], [], [], [], [], []], "players": players}
