extends SceneTree
var checks := 0
var failures := 0
var game
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_tests")
func finish_run() -> void:
	while game.mode == "run" and float(game.run["t"]) < 900.0: game.step(0.1)
func run_tests() -> void:
	seed(12)
	game = load("res://main.tscn").instantiate()
	game.simulating = true
	root.add_child(game)
	check(game.SAVE_PATH == "user://save_v05.json", "Новая кампания перезаписывает прежнее сохранение")
	check(game.party_ids.is_empty() and game.heroes.is_empty(), "Игра сама набрала отряд")
	check(game.bag.is_empty() and game.wallet.is_empty(), "Свежая сумка не пуста")
	for cls in game.roster:
		check(game.roster[cls]["lvl"] == 1 and game.roster[cls]["items"].is_empty(), "Не все герои начали голыми с уровня1")
	check(game.start_run() != "", "Можно отправить пустой отряд")
	check(not game.dungeon_open("crypt"), "Склеп доступен до обучения")
	check(game.set_in_party("paladin", true) != "" and game.set_in_party("warlock", true) != "", "Будущие классы доступны")
	game.acknowledge_intro()
	for cls in ["priest", "mage", "warrior"]: game.set_in_party(cls, true)
	check(game.party_ids == ["priest", "mage", "warrior"], "Игра поставила танка вперёд сама")
	check(game.slots() == 3 and game.set_in_party("hunter", true) != "", "Начальные места не соответствуют дизайну")
	game.move_in_party("warrior", 0)
	check(game.start_run("training") == "", "Нельзя начать обучение")
	finish_run()
	check(game.last_result == "win" and game.meter["deaths"].is_empty(), "Обучение убивает сбалансированный голый отряд")
	check(game.bag.size() == 4 and game.wallet.is_empty(), "Обучение не выдало ровно4оружия или выдало валюту")
	for h in game.heroes: check(h["items"].is_empty(), "Обучение автоматически надело оружие")
	check(game.tutorial_target() == "gear", "Обучение не направляет надеть предметы")
	game.start_run("training")
	finish_run()
	check(game.bag.size() == 4, "Повтор обучения дублирует награду")
	for i in game.heroes.size():
		var hero: Dictionary = game.heroes[i]
		for it in game.bag.duplicate():
			if it.get("starter_for") == hero["cls"]: check(game.equip(i, it) == "", "Не надевается стартовое оружие")
	check(game.tutorial_target() == "camp", "Обучение не возвращает к выбору данжа")
	game.start_run("crypt")
	finish_run()
	check(game.last_result == "win" and game.meter["deaths"].is_empty(), "Первый данж не пройден живым отрядом")
	check(game.slots() == 4 and game.dungeon_open("catacombs"), "Первая победа не открыла4место/катакомбы")
	check(game.wallet.is_empty(), "Угли выпали раньше второго данжа")
	check(game.bag.size() >= 8, "Нет гарантированных улучшений первой победы")
	var reward_weapon: Dictionary = {}
	for it in game.bag:
		if it["slot"] == "weapon" and int(it["ilvl"]) == 8: reward_weapon = it; break
	check(not reward_weapon.is_empty(), "Первая победа не дала оружие следующего ilvl")
	game.start_run("catacombs")
	while game.mode == "run" and not game.craft_currency_received and float(game.run["t"]) < 900: game.step(0.1)
	check(game.craft_currency_received and game.wallet.get("ember_attack",0) >= 1, "Второй данж не выдал обучающий материал")
	game.retreat()
	var original_count: int = game.wallet["ember_attack"]
	check(game.craft(reward_weapon, "ember_attack") != "" and game.wallet["ember_attack"] == original_count - 1, "Ручной крафт не тратит ровно1материал")
	check(game.craft_taught and not game.tutorial_active(), "Крафт оружия не завершил обучение")
	var fake: Dictionary = reward_weapon.duplicate(true)
	check(game.craft(fake, "ember_elemental") == "Этого предмета нет в снаряжении или сумке", "Можно крафтить чужую копию предмета")
	var hero: Dictionary = game.heroes[0]
	hero["lvl"] = 14; hero["xp"] = 0
	game.start_run("crypt")
	game._spawn_enemy(); game.enemy["hp"] = 0; game.step(0.01)
	check(hero["xp"] == 0, "Мобы на7уровней ниже героя дают XP до предела данжа")
	game.retreat()
	hero["lvl"] = 18; hero["xp"] = 0
	game.selected_dungeon = "crypt"
	game.start_run()
	game._spawn_enemy(); game.enemy["hp"] = 0; game.step(0.01)
	check(hero["lvl"] == 18 and hero["xp"] == 0, "Серые мобы продолжают давать опыт")
	game.retreat()
	game._gain_xp(hero, 999999, 18)
	check(hero["lvl"] == 18 and hero["xp"] == 0, "Опыт перескочил пределданжа")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()+"/tests")
	game.save_path = "user://tests/onboarding-save.json"
	game.simulating = false; game.save_game(); game.simulating = true
	var order: Array = game.party_ids.duplicate()
	game._new_game(); game._load_game()
	check(game.party_ids == order and game.craft_taught and game.intro_seen, "Сохранение потеряло строй или обучение")
	check(game.training_claimed.size() == 4 and game.cleared.has("training"), "Сохранение повторно разрешило стартовую награду")
	check(game.class_unlocked("hunter") and not game.class_unlocked("shaman"), "Сохранение открыло будущие классы")
	game.free()
	print("ONBOARDING TEST: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
