extends SceneTree
## Не выдача наград: стенд проверяет, что законный подготовленный билд может пройти стену.

func _initialize() -> void:
	call_deferred("run_probe")


func run_probe() -> void:
	DB.ensure()
	var failed := 0
	for scenario in ["no_healer", "heavy_fighter", "first_rewards", "prepared_cold"]:
		var wins := 0
		var deaths := 0
		for sample in range(1, 21):
			seed(sample)
			var game = load("res://main.tscn").instantiate()
			game.simulating = true
			game.test_mode = true
			root.add_child(game)
			var ids: Array = ["warrior", "mage", "hunter"] if scenario == "no_healer" else ["warrior", "priest", "mage"]
			if scenario in ["first_rewards", "prepared_cold"]: ids.append("hunter")
			if scenario == "heavy_fighter": game.roster["warrior"]["spec"] = "arms"
			preload("res://tools/early_fixture.gd").starter(game, ids)
			var dungeon := "crypt"
			if scenario in ["first_rewards", "prepared_cold"]:
				game.cleared["crypt"] = 1
				dungeon = "catacombs"
				for h in game.heroes:
					var ilvl := 8 if scenario == "first_rewards" else 18
					h["items"]["weapon"] = Items.for_hero(h, ilvl, "magic" if scenario == "first_rewards" else "normal", "weapon")
					h["items"]["armour"] = Items.for_hero(h, ilvl, "magic" if scenario == "first_rewards" else "normal", "armour")
					if scenario == "prepared_cold":
						for kind in ["armour", "helmet", "gloves", "boots"]:
							var item := Items.for_hero(h, ilvl, "normal", kind)
							Items.add_mod(item, Items.affix_def("life"), 1)
							Items.add_mod(item, Items.affix_def("res_cold"), 1)
							item["rarity"] = "magic"
							item["name"] = Items.make_name(item)
							h["items"][kind] = item
					if h["cls"] == "warrior": h["items"]["offhand"] = Items.for_hero(h, ilvl, "normal", "shield")
				game._recalc()
			game.start_run(dungeon)
			while game.mode == "run" and float(game.run["t"]) < 1800:
				game.step(0.1)
			wins += int(game.last_result == "win")
			deaths += game.meter["deaths"].size()
			game.free()
		print("PROGRESSION %s wins=%d/20 deaths=%d" % [scenario, wins, deaths])
		if scenario == "no_healer" and wins > 5: failed += 1
		if scenario == "heavy_fighter" and wins < 15: failed += 1
		if scenario == "prepared_cold" and wins != 20: failed += 1
	print("PROGRESSION PROBE: 80 scenarios, %d failed expectations" % failed)
	quit(0 if failed == 0 else 1)
