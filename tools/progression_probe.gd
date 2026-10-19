extends SceneTree
## Не выдача наград: стенд проверяет, что законный подготовленный билд может пройти стену.

func _initialize() -> void:
	call_deferred("run_probe")


func run_probe() -> void:
	DB.ensure()
	var failed := 0
	for scenario in ["no_healer", "heavy_fighter", "heavy_prepared", "first_rewards", "prepared_cold", "quick_heal_mage", "quick_heal_hunter"]:
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
			if scenario in ["heavy_fighter", "heavy_prepared"]: game.roster["warrior"]["spec"] = "arms"
			preload("res://tools/early_fixture.gd").starter(game, ids)
			if scenario == "heavy_prepared":
				for h in game.heroes:
					for kind in ["weapon","armour","helmet","gloves","boots"]:
						h["items"][kind] = Items.for_hero(h,8,"magic",kind)
				game._set_party()
			if scenario in ["quick_heal_mage","quick_heal_hunter"]:
				if scenario == "quick_heal_hunter":
					preload("res://tools/early_fixture.gd").starter(game,["warrior","priest","hunter"])
				game.roster["priest"]["skill_id"] = DB.skill_options(game.roster["priest"])[1]["id"]
				game._set_party()
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
		if scenario == "heavy_prepared" and wins < 15: failed += 1
		if scenario in ["quick_heal_mage","quick_heal_hunter"] and (wins != 20 or deaths != 0): failed += 1
		if scenario == "prepared_cold" and wins != 20: failed += 1
	print("PROGRESSION PROBE: 140 scenarios, %d failed expectations" % failed)
	quit(0 if failed == 0 else 1)
