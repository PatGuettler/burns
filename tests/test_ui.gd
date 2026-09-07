extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for count in range(2, 9):
		scene.player_count = count
		scene._show_table()
		await process_frame
		var cards := _count_cards(scene)
		assert(cards == count + 5, "Table must render five public cards and one hidden pile per player")
	scene._show_rules()
	await process_frame
	scene._show_menu()
	await process_frame
	print("PASS: menu, rules, and 2–8-player table scenes")
	quit()

func _count_cards(node: Node) -> int:
	var count := 1 if node is BurnsCardView else 0
	for child in node.get_children():
		count += _count_cards(child)
	return count
