extends SceneTree
## Проверяем реальный строй, смерть поддержки и переходы без обращения к игровому сохранению.

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	seed(11)
	var game = load("res://main.tscn").instantiate()
	game.simulating = true
	game.test_mode = true
	root.add_child(game)
	preload("res://tools/early_fixture.gd").choose_skills(game)
	game.party_ids = ["priest", "mage", "warrior"]
	game._set_party()
	check(game.party_ids == ["priest", "mage", "warrior"], "Строй сам сортируется по классам")
	check(game.heroes[0]["cls"] == "priest", "Передний герой не соответствует выбранному порядку")
	check(game.move_in_party("warrior", 0) == "" and game.party_ids == ["warrior", "priest", "mage"], "Нельзя поставить танка вперёд")
	check(game.move_in_party("warrior", 2) == "" and game.party_ids == ["priest", "mage", "warrior"], "Нельзя поставить танка в тыл")
	var order: Array = game.party_ids.duplicate()
	check(game.move_in_party("warrior", -1) != "" and game.party_ids == order, "Неверная позиция меняет строй")
	check(game.move_in_party("paladin", 0) != "" and game.party_ids == order, "Герой вне отряда попал в строй через перестановку")
	game.set_spec("warrior", "prot")
	check(game.party_ids == order, "Смена ветки сбрасывает порядок")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/tests")
	game.save_path = "user://tests/formation-save.json"
	game.simulating = false
	game.save_game()
	game.simulating = true
	game.party_ids = ["warrior", "mage", "priest"]
	game._load_game()
	check(game.party_ids == order, "Сохранение не восстановило порядок отряда")
	game.start_run("crypt")
	check(game.is_travelling() and game.enemy.is_empty(), "Вместо выхода из лагеря сразу возник бой")
	var hp: Array = game.heroes.map(func(h): return h["life"])
	game.step(0.3)
	check(game.is_travelling() and game.travel_distance > 0.0 and game.travel_progress() > 0.0, "Переход не движется во времени симуляции")
	check(game.heroes.map(func(h): return h["life"]) == hp and game.meter["dmg"] == [0.0, 0.0, 0.0], "В пустом коридоре идёт бой")
	check(game.move_in_party("warrior", 0) != "" and game.party_ids == order, "Можно менять строй в переходе похода")
	game.step(game.TRAVEL_DURATION - 0.3)
	check(not game.is_travelling() and not game.enemy.is_empty(), "После перехода не появился враг")
	check(is_equal_approx(game.run["t"], game.TRAVEL_DURATION), "Время перехода потеряно или посчитано дважды")
	var distance: float = game.travel_distance
	game.enemy["hp"] = 100000.0
	game.enemy["max_hp"] = 100000.0
	game.step(0.05)
	check(is_equal_approx(game.travel_distance, distance), "Коридор продолжает двигаться во время боя")
	check(game.move_in_party("warrior", 0) != "" and game.party_ids == order, "Можно менять строй в бою")
	game.enemy["boss"] = false
	game.enemy["dmg"] = 20.0
	game._enemy_hits()
	check(game.meter["taken"][0] > game.meter["taken"][1] and game.meter["taken"][0] > game.meter["taken"][2], "Танк в тылу перехватил основной удар вместо приста")
	check(game.party["party"].get("inc_life", 0.0) == 3.0, "Живой прист не даёт баф")
	game._hero_died(0, 999.0)
	check(game.front_hero_index() == 1, "После гибели переднего враг не переключился на следующего живого")
	check(game.party["party"].get("inc_life", 0.0) == 0.0, "Мёртвый прист продолжает давать баф живым")
	var taken: Array = game.meter["taken"].duplicate()
	game._enemy_hits()
	check(game.meter["taken"][1] - taken[1] > game.meter["taken"][2] - taken[2], "После смерти приста враг выбрал танка в обход мага")
	var healed: float = game.meter["heal"][0]
	game.heroes[1]["life"] = game.stats[1]["max_life"] * 0.5
	game.step(1.1)
	check(game.heroes[0]["life"] == 0.0 and game.meter["heal"][0] == healed, "Мёртвый прист продолжает лечить")
	game.heroes[1]["life"] = 1.0
	game._enemy_hits()
	check(game.front_hero_index() == 2, "Оставшийся танк не стал передним после гибели мага")
	check(game.meter["deaths"][0]["who"] == "Жрец" and game.meter["deaths"][1]["who"] == "Маг", "Журнал не отражает последовательность гибели")
	game.enemy["hp"] = 0.0
	var kills: int = game.kills
	game.step(0.01)
	check(game.kills == kills + 1 and game.is_travelling() and game.enemy.is_empty(), "После победы нет отдельной фазы движения")
	game.retreat()
	game.step(2.0)
	check(game.mode == "camp" and not game.is_travelling() and game.enemy.is_empty(), "После отступления переход породил нового врага")
	game.party_ids = ["warrior", "shaman"]
	game._set_party()
	var target: Dictionary = game.ref_enemy()
	var tank: Dictionary = game.heroes[0]
	var metrics: Dictionary = game._equipment_metrics(tank, target)
	var raw: float = target["dmg"] * (1.0 - float(game.party["tank_less"]) / 100.0)
	var expected: float = game.stats[0]["max_life"] * target["dmg"] / Calc.damage_taken(game.stats[0], raw, target["dmg_types"])
	check(is_equal_approx(metrics["survival"], expected), "Карточка применяет тотем после брони вместо уменьшения входящего удара")
	game.move_in_party("warrior", 1)
	metrics = game._equipment_metrics(tank, target)
	expected = game.stats[1]["max_life"] * target["dmg"] / Calc.damage_taken(game.stats[1], target["dmg"], target["dmg_types"])
	check(is_equal_approx(metrics["survival"], expected), "Карточка даёт танку в тылу защиту тотема передней линии")
	game.move_in_party("warrior", 0)
	game.start_run("crypt")
	check(game.party["tank_less"] > 0.0, "Живой шаман не защищает отряд")
	game._spawn_enemy()
	game._hero_died(1, 999.0)
	check(game.party["tank_less"] == 0.0 and game.party["party"].get("regen", 0.0) == 0.0, "Мёртвый шаман продолжает поддерживать отряд")
	game.free()
	print("FORMATION TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
