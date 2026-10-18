extends SceneTree
## Первые три данжа: 20 сидов, стартовая пара без смены вещей и талантов.

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	DB.ensure()
	var failures := 0
	for id in ["crypt", "catacombs", "cult"]:
		var wins := 0
		var bosses := 0
		var deaths := 0
		var min_life := 0.0
		var healing := 0.0
		var secs := 0.0
		for sample in range(1, 21):
			seed(sample)
			var game = load("res://main.tscn").instantiate()
			game.simulating = true
			game.test_mode = true
			root.add_child(game)
			game.party_ids = ["warrior", "priest"]
			game._set_party()
			game.repeat_run = false
			game.start_run(id)
			var low := 1.0
			var reached := false
			while game.mode == "run" and float(game.run["t"]) < 3600:
				game.step(0.1)
				for i in game.heroes.size():
					low = minf(low, game.heroes[i]["life"] / game.stats[i]["max_life"])
				if game.mode == "run" and game.enemy.get("kind") == "boss": reached = true
			wins += int(game.last_result == "win")
			bosses += int(reached)
			deaths += game.meter["deaths"].size()
			min_life += low
			for amount in game.meter["heal"]: healing += amount
			secs += game.run["t"]
			game.free()
		print("PROBE %s wins=%d/20 boss_reached=%d/20 deaths=%d min_hp_avg=%.1f%% healing_avg=%.1f secs_avg=%.1f" % [id, wins, bosses, deaths, min_life/20*100, healing/20, secs/20])
		if id == "crypt" and (wins != 20 or healing <= 0.0 or min_life / 20.0 >= 0.5):
			failures += 1
		if id == "catacombs" and (wins != 0 or bosses != 20):
			failures += 1
		if id == "cult" and wins != 0:
			failures += 1
	print("BALANCE PROBE: 60 scenarios, %d failed expectations" % failures)
	quit(0 if failures == 0 else 1)
