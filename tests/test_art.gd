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
	assert(BurnsDeckArt.supplied(49).region == Rect2(75, 69, 570, 1171), "Only screenshot margins are excluded")
	var courts := {}
	for card in range(52):
		assert((BurnsDeckArt.supplied(card) != null) == (card in [49, 51]), "Only the Jack and King of Spades are supplied whole")
		assert(_art(card) != null, "Every card carries artwork")
	for suit in range(4):
		assert(BurnsDeckArt.face(suit * 13) == BurnsDeckArt.ACES[suit], "Each ace shows its own engraved medallion")
		for rank in range(2, 11):
			assert(BurnsDeckArt.face(suit * 13 + rank - 1) == BurnsDeckArt.FIELDS[suit], "Number cards share their suit's field")
		for rank in [11, 12, 13]:
			var art := _art(suit * 13 + rank - 1)
			assert(not BurnsDeckArt.FIELDS.has(art) and not BurnsDeckArt.ACES.has(art), "Courts never fall back to a suit field")
			courts[art.resource_path] = true
	assert(courts.size() == 12, "All twelve courts have their own portrait")
	assert(BurnsDeckArt.WINDOW.get_center().is_equal_approx(BurnsDeckArt.PIP_CENTER), "Pips are centred in the artwork window")
	print("PASS: exact pip counts, unique pip placement, original portrait checksums, twelve distinct courts, artwork on all 52 cards")
	quit()

func _art(card: int) -> Texture2D:
	var supplied := BurnsDeckArt.supplied(card)
	return supplied if supplied else BurnsDeckArt.face(card)
