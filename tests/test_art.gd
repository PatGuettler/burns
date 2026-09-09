extends SceneTree
func _init() -> void:
	for rank in range(1, 11):
		var pips := BurnsDeckArt.pip_positions(rank)
		assert(pips.size() == rank, "Displayed pip count must match rank")
		var distinct := {}
		for pip in pips:
			assert(Rect2(20, 20, 36, 74).has_point(pip), "Pips stay inside the index gutters")
			distinct[pip] = true
		assert(distinct.size() == rank, "Pips must not overlap")
	assert(FileAccess.get_sha256("res://assets/art/deck/faces/king_spades.jpg") == "67550f1b2b9ffd4cd31ec0cbc0aa86157c09b2980cfc38f5222e0dfc67a6b229", "User's King artwork is unchanged")
	assert(FileAccess.get_sha256("res://assets/art/deck/faces/jack_spades.png") == "cf625d4725448214742a1b0d7aed03f36b16483f7749c2abbbe9e133c5517591", "User Jack source is unchanged")
	assert(BurnsDeckArt.portrait(49).region == Rect2(75, 69, 570, 1171), "Only screenshot margins are excluded")
	for card in range(52):
		assert((BurnsDeckArt.portrait(card) != null) == (card in [49, 51]), "Only the supplied Jack and King get portraits")
	print("PASS: exact pip counts, unique pip placement, original portrait checksums, ten court placeholders")
	quit()
