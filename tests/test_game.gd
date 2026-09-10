extends SceneTree

var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func fixture() -> BurnsGame:
	var g := BurnsGame.new()
	g.start(["A", "B", "C"], 1)
	g.s.rows = [[], [], [], [], []]
	for p in g.s.players:
		p.play = [12]
		p.discard = []
	return g

func _init() -> void:
	var g := fixture()
	check(g.act(1, {"type": "draw"}) != "", "Reject out-of-turn draws")
	g.s.players[0].held = 0 # ace diamonds
	var ace := {"type": "move", "source": "held", "index": 0, "offset": 0, "target": "foundation", "to": 0}
	check(g.act(0, ace) == "", "Ace starts its foundation")
	check(g.s.foundations[0] == [0], "Ace moved correctly")
	g.s.players[0].held = 2
	check(g.act(0, ace) != "", "Cannot skip a foundation rank")
	g.s.players[0].held = 1
	check(g.act(0, ace) == "", "Two follows ace in suit")
	g = fixture()
	g.s.rows = [[16], [2, 14], [9], [22], [35]] # black4, red3 black2
	var sequence := {"type": "move", "source": "row", "index": 1, "offset": 0, "target": "row", "to": 0}
	check(g.act(0, sequence) == "", "Move a descending alternating sequence")
	check(g.s.rows[0] == [16, 2, 14] and g.s.rows[1].is_empty(), "Moving a whole row opens the slot")
	g.s.players[0].held = 11
	check(g.act(0, {"type": "move", "source": "held", "index": 0, "offset": 0, "target": "row", "to": 1}) == "", "Any rank fills an empty row")
	g = fixture()
	g.s.players[1].discard = [17] # black5
	g.s.players[0].held = 3 # red4
	var onto_discard := {"type": "move", "source": "held", "index": 0, "offset": 0, "target": "opponent", "to": 1}
	check(g.act(0, onto_discard) == "", "Opponent discard accepts one rank down")
	g.s.players[0].held = 17
	check(g.act(0, onto_discard) == "", "Opponent discard accepts one rank up")
	g.s.players[0].held = 18
	check(g.act(0, onto_discard) != "", "Reject same-color discard play")
	g.s.players[1].discard = [12]
	g.s.players[0].held = 13
	check(g.act(0, onto_discard) != "", "No King-to-Ace wrap")
	g = fixture()
	g.s.players[0].held = 0
	check(g.act(0, {"type": "end"}) == "", "Discard ends turn")
	check(g.s.phase == "review" and g.s.active == 0, "Next player cannot draw before Burns review")
	check(g.act(1, {"type": "draw"}) != "", "Review window blocks next draw")
	check(g.act(1, {"type": "burn"}) == "" and g.s.burnt == 0, "Missed ace burns offender")
	var before: int = g.s.players[0].play.size()
	check(g.act(1, {"type": "donate", "source": "play"}) == "", "First donor chooses hidden top")
	check(g.act(2, {"type": "donate", "source": "play"}) == "", "Second donor chooses hidden top")
	check(g.s.players[0].play.size() == before + 2, "Burnt receives every gift")
	g = fixture()
	g.s.phase = "review"
	g.s.reviewers = [1, 2]
	g.s.missed = ""
	check(g.act(1, {"type": "burn"}) == "" and g.s.burnt == 1, "False caller is burnt")
	check(g.s.donors == [2, 0], "Penalty ordering is clockwise from burnt player")
	g = fixture()
	g.s.players[0].play = []
	g.s.players[0].discard = [8, 20, 5]
	check(g.act(0, {"type": "draw", "source": "bottom"}) == "", "Exhausted stock opens discard and reveals bottom")
	check(g.s.players[0].held == 8 and g.s.players[0].reserve == [20, 5], "Open pile preserves order")
	check(g.act(0, {"type": "end"}) == "", "New discard converts open pile to stock")
	check(g.s.players[0].play == [20, 5] and g.s.players[0].discard == [8], "Stock conversion preserves existing order")
	g = fixture()
	g.s.players[0].play = []
	g.s.players[0].held = 0
	check(g.act(0, ace) == "", "Final personal card can be played")
	check(g.act(0, {"type": "end"}) == "" and g.s.phase == "review", "Win waits for final challenge")
	check(g.act(1, {"type": "pass"}) == "", "First player waives challenge")
	check(g.act(2, {"type": "pass"}) == "" and g.s.winner == 0, "Win after everyone passes")
	g = BurnsGame.new()
	g.start(["A", "B"], 10)
	var v := g.view()
	check(not v.has("missed") and not v.has("missed_move"), "Adjudication evidence stays private until a challenge")
	for p in v.players:
		check(not p.has("play") and not p.has("reserve") and not p.has("discard"), "No hidden arrays in client snapshots")
	check(g.invariant(), "Initial deck conservation")
	var restored := BurnsGame.new()
	check(restored.restore(g.s) and restored.s == g.s, "Save round trip preserves exact state")
	var corrupt := g.s.duplicate(true)
	corrupt.players[0].play = "not a pile"
	check(not restored.restore(corrupt), "Reject malformed saved piles")
	corrupt = g.s.duplicate(true)
	corrupt.players[0].play.append(0)
	check(not restored.restore(corrupt), "Reject duplicate saved cards")
	check(not restored.restore({"version": 99}), "Reject unsupported saves")
	# Empty opponent discards are never moves or evidence for Burns.
	g = fixture()
	g.s.rows = [[4], [17], [30], [43], [8]]
	g.s.players[0].held = 15
	check(g.moves().is_empty(), "Black 3 cannot play on any empty opponent discard")
	check(g.act(0, {"type": "end"}) == "" and g.s.missed.is_empty(), "Discarding without a play records no missed move")
	check(g.act(1, {"type": "burn"}) == "" and g.s.burnt == 1, "Calling Burns over an empty discard burns the caller")
	g = fixture()
	g.s.rows = [[4], [17], [30], [43], [8]]
	g.s.players[0].held = 15
	g.s.players[1].discard = [3]
	check(g.act(0, {"type": "end"}) == "", "End turn with an occupied playable opponent discard")
	check(g.act(1, {"type": "burn"}) == "" and g.s.burnt == 0, "Missing a real discard play still burns the offender")
	check(g.s.burn_message.contains("B's discard (4 of Diamonds)"), "Verdict identifies the opponent and the exact card")
	check(g.view().burn_evidence.target == "opponent" and g.view().burn_evidence.to == 1, "Confirmed challenge publishes its destination for highlighting")
	g = BurnsGame.new()
	g.start(["A", "B", "C"], 42)
	check(g.act(0, {"type": "draw"}) == "", "Reveal before an early call")
	var revealed: int = g.s.players[0].held
	var turn: int = g.s.turn
	check(g.act(1, {"type": "burn"}) == "" and g.s.burnt == 1, "An early caller is burnt, not blocked")
	check(g.act(2, {"type": "burn"}) == "" and g.s.burnt == 2, "Calls during a penalty create a false-call penalty")
	var nested := BurnsGame.new()
	check(nested.restore(g.s), "Interrupted penalties survive save/restore")
	g = nested
	while g.s.phase == "penalty":
		check(g.act(g.s.donors[0], {"type": "donate", "source": "play"}) == "", "Resolve nested donors")
		check(g.invariant(), "Nested penalties preserve all 52 cards")
	check(g.s.active == 0 and g.s.turn == turn and g.s.phase == "turn", "Resume the interrupted turn without advancing")
	check(g.s.players[0].held == revealed, "The interrupted revealed card stays in hand")
	check(g.act(0, {"type": "burn"}) == "" and not g.s.burn_correct, "Even the active player's own early call is false")
	# Simulate full games across all player counts; never grant bots hidden foresight.
	var completed := 0
	for count in range(2, 9):
		for seed_value in range(5):
			g = BurnsGame.new()
			var names: Array = []
			for i in range(count): names.append("Bot %d" % i)
			g.start(names, seed_value)
			for step in range(10000):
				if g.s.phase == "finished": completed += 1; break
				var actor: int = g.s.active
				if g.s.phase == "review": actor = g.s.reviewers[0]
				if g.s.phase == "penalty": actor = g.s.donors[0]
				var action := BurnsBot.choose(g, actor)
				var error := g.act(actor, action)
				check(error.is_empty(), "Bot action must succeed: %s / %s" % [action, error])
				check(g.invariant(), "Every card appears exactly once after any action")
			check(g.s.phase == "finished", "Seed %d with %d players must finish within budget" % [seed_value, count])
	print("PASS: %d checks, including %d complete simulated games" % [checks, completed])
	quit()
