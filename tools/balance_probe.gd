extends SceneTree
## Первые три данжа: два состава × 20 сидов, полный слабый стартовый комплект.

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	DB.ensure()
	var failures := 0
	for live in [false, true]:
		for damage_class in ["mage", "hunter"]:
			for id in ["crypt", "catacombs", "cult"]:
				if live and id != "crypt": continue
				var wins := 0
				var bosses := 0
				var deaths := 0
				var min_life := 0.0
				var pack_min_life := 0.0
				var healing := 0.0
				var secs := 0.0
				for sample in range(1, 21):
					seed(sample)
					var game = load("res://main.tscn").instantiate()
					game.simulating = true
					game.test_mode = true
					root.add_child(game)
					preload("res://tools/early_fixture.gd").starter(game, ["warrior", "priest", damage_class])
					game.simulating = not live
					game.set_process(false)
					game.repeat_run = false
					game.start_run(id)
					var low := 1.0
					var pack_low := 1.0
					var reached := false
					while game.mode == "run" and float(game.run["t"]) < 3600:
						var ordinary: bool = game.enemy.get("kind", "") == "pack"
						game.step(0.1)
						for i in game.heroes.size():
							var ratio: float = game.heroes[i]["life"] / game.stats[i]["max_life"]
							low = minf(low, ratio)
							if ordinary: pack_low = minf(pack_low, ratio)
						if game.mode == "run" and game.enemy.get("kind") == "boss": reached = true
					wins += int(game.last_result == "win")
					bosses += int(reached)
					deaths += game.meter["deaths"].size()
					min_life += low
					pack_min_life += pack_low
					for amount in game.meter["heal"]: healing += amount
					secs += game.run["t"]
					game.free()
				print("PROBE %s %s/%s wins=%d/20 boss_reached=%d/20 deaths=%d min_hp_avg=%.1f%% pack_min_hp_avg=%.1f%% healing_avg=%.1f secs_avg=%.1f" % ["LIVE_RNG" if live else "SIM", damage_class, id, wins, bosses, deaths, min_life/20*100, pack_min_life/20*100, healing/20, secs/20])
				if id == "crypt" and (wins != 20 or deaths != 0 or healing <= 0.0 or min_life / 20.0 >= 0.65):
					failures += 1
				if id == "catacombs" and (wins != 0 or bosses != 20):
					failures += 1
				if id == "cult" and wins != 0:
					failures += 1
	print("BALANCE PROBE: 160 scenarios, %d failed expectations" % failures)
	quit(0 if failures == 0 else 1)
