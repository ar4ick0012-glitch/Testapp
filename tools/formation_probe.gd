extends SceneTree
## Живой прогон первого данжа: тот же шмот и состав, меняется только порядок.

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var passed := true
	for front in ["warrior", "priest"]:
		var wins := 0
		var deaths := 0
		var priest_first := 0
		for sample in range(1, 21):
			seed(sample)
			var game = load("res://main.tscn").instantiate()
			game.simulating = true
			root.add_child(game)
			game.party_ids = ["warrior", "priest"] if front == "warrior" else ["priest", "warrior"]
			game._set_party()
			game.start_run("crypt")
			while game.mode == "run" and float(game.run["t"]) < 600.0:
				game.step(0.1)
			wins += int(game.last_result == "win")
			deaths += game.meter["deaths"].size()
			if not game.meter["deaths"].is_empty() and game.meter["deaths"][0]["who"] == "Жрец":
				priest_first += 1
			game.free()
		print("FORMATION PROBE front=%s wins=%d/20 deaths=%d first_death_priest=%d/20" % [front, wins, deaths, priest_first])
		if front == "warrior" and wins != 20: passed = false
		if front == "priest" and (wins != 0 or priest_first != 20): passed = false
	print("FORMATION PROBE: 40 scenarios, expectations ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
