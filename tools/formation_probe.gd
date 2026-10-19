extends SceneTree
## Живой прогон первого данжа: тот же шмот и состав, меняется только порядок.

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var passed := true
	for heal_skill in ["steady_light", "fleeting_light"]:
		for damage_class in ["mage", "hunter"]:
			for front in ["warrior", "priest"]:
				var wins := 0
				var deaths := 0
				var priest_first := 0
				var first_pack := 0
				var first_floor := 0
				var first_death_time := 0.0
				for sample in range(1, 21):
					seed(sample)
					var game = load("res://main.tscn").instantiate()
					game.simulating = true
					root.add_child(game)
					preload("res://tools/early_fixture.gd").starter(game, ["warrior", "priest", damage_class] if front == "warrior" else ["priest", "warrior", damage_class])
					game.roster["priest"]["skill_id"] = heal_skill
					game.start_run("crypt")
					while game.mode == "run" and float(game.run["t"]) < 600.0:
						var before: int = game.meter["deaths"].size()
						var kind: String = game.enemy.get("kind", "")
						var floor_i: int = game.run["floor_i"]
						game.step(0.1)
						if before == 0 and not game.meter["deaths"].is_empty() and game.meter["deaths"][0]["who"] == "Жрец":
							first_pack += int(kind == "pack")
							first_death_time += float(game.meter["deaths"][0]["t"])
							first_floor += int(floor_i == 0)
					wins += int(game.last_result == "win")
					deaths += game.meter["deaths"].size()
					if not game.meter["deaths"].is_empty() and game.meter["deaths"][0]["who"] == "Жрец":
						priest_first += 1
					game.free()
				print("FORMATION PROBE %s heal=%s front=%s wins=%d/20 deaths=%d first_death_priest=%d/20 on_pack=%d/20 floor1=%d/20 first_death_t=%.1fs" % [damage_class, heal_skill, front, wins, deaths, priest_first, first_pack, first_floor, first_death_time / maxf(1.0, priest_first)])
				if front == "warrior" and heal_skill == "steady_light" and (wins != 20 or deaths != 0): passed = false
				if front == "priest" and (wins != 0 or priest_first != 20 or first_pack != 20): passed = false
	print("FORMATION PROBE: 160 scenarios, expectations ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
