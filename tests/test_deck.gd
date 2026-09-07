extends SceneTree

func _init() -> void:
	var deck := BurnsDeck.create_deck()
	assert(deck.size() == 52)
	assert(BurnsDeck.card_name(0) == "A of Diamonds")
	assert(BurnsDeck.card_name(51) == "K of Spades")
	for player_count in range(2, 9):
		for seed_value in range(40):
			var state := BurnsDeck.deal(player_count, seed_value)
			assert(state == BurnsDeck.deal(player_count, seed_value), "Same seed must replay the same deal")
			assert(state.rows.size() == 5)
			var seen: Array = []
			for row in state.rows:
				assert(row.size() == 1)
				seen.append_array(row)
			var smallest := 52
			var largest := 0
			for player in state.players:
				assert(player.discard.is_empty())
				seen.append_array(player.play)
				smallest = mini(smallest, player.play.size())
				largest = maxi(largest, player.play.size())
			assert(largest - smallest <= 1, "Deal must be balanced")
			seen.sort()
			assert(seen == deck, "Every card must appear exactly once")
	assert(BurnsDeck.deal(1, 0).has("error"))
	assert(BurnsDeck.deal(9, 0).has("error"))
	print("PASS: 280 deterministic deals, card conservation, balanced distribution, names, invalid player counts")
	quit()
