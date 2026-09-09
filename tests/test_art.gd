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
	for card in range(52):
		assert((BurnsDeckArt.portrait(card) != null) == (card == 51), "Only the supplied King gets a portrait")
	print("PASS: exact pip counts, unique pip placement, original King checksum, eleven court placeholders")
	quit()
