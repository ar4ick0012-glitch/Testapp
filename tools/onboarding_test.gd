extends SceneTree
## Старт v0.6 и причинное обучение, без обращения к игровому сохранению.
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
	check(game.SAVE_PATH == "user://save_v06.json", "Кампания перезаписывает прежнее сохранение")
	check(game.heroes.is_empty() and game.party_ids.is_empty(), "Игра сама набрала отряд")
	check(game.bag.is_empty() and game.wallet.is_empty(), "Свежая сумка не пуста")
	check(DB.dungeon("training").is_empty() and not game.dungeon_open("training"), "Нулевой данж остался доступен")
	check(game.selected_dungeon == "crypt" and game.dungeon_open("crypt"), "Первый данж требует отменённого обучения")
	check(game.start_run() != "", "Можно отправить пустой отряд")
	for cls in game.roster:
		var h: Dictionary = game.roster[cls]
		check(h["lvl"] == 1 and h["items"].has("weapon") and h["items"].has("armour"), "Герой не получил слабый стартовый комплект")
		if cls in DB.start["classes"]:
			check(not DB.skill_selected(h), "Умение выбрано автоматически")
			for it in h["items"].values(): check(it["mods"].is_empty() and it.get("starter",false), "Начальная вещь не является простой базовой")
	game.acknowledge_intro()
	check(game.tutorial_state()["id"] == "healer" and game.tutorial_state()["cls"] == "priest", "Первым предлагается не жрец")
	check(game.set_in_party("paladin", true) != "", "Будущий класс доступен")
	game.set_in_party("priest",true)
	check(game.party_ids == ["priest"] and game.tutorial_state()["action"] == "skill", "После найма жреца нет выбора умения")
	check(game.start_run() != "", "Без базового умения можно начать бой")
	check(game.set_skill("priest","steel_rush") != "" and not DB.skill_selected(game.roster["priest"]), "Можно выбрать чужое умение")
	check(game.set_skill("priest", DB.skill_options(game.roster["priest"])[0]["id"]) == "", "Ручной выбор умения не работает")
	check(game.tutorial_state()["id"] == "recruit", "Обучение не предлагает добрать отряд")
	for cls in ["warrior","mage"]:
		game.set_in_party(cls,true)
		game.set_skill(cls,DB.skill_options(game.roster[cls])[0]["id"])
	check(game.party_ids == ["priest","warrior","mage"], "Воин сам переместился вперёд")
	check(game.tutorial_state()["action"] == "start", "Готовый отряд не направлен в поход")
	game.start_run()
	var healer: Dictionary = game.roster["priest"]
	var old: String = healer["skill_id"]
	var old_life: float = game.heroes[0]["life"]
	healer["skill_id"] = DB.skill_options(healer)[1]["id"]
	game._recalc()
	game.heroes[0]["life"] = 1.0
	var mana_before: float = healer["mana"]
	game._act(0)
	check(is_equal_approx(healer["mana"], mana_before-8.0), "Быстрое лечение не использует свой расход маны")
	healer["skill_id"] = old
	game._recalc()
	game.heroes[0]["life"] = old_life
	healer["mana"] = game.stats[0]["max_mana"]
	check(game.set_skill("priest",DB.skill_options(game.roster["priest"])[1]["id"]) != "" and game.roster["priest"]["skill_id"] == old, "Умение меняется в походе")
	check(game.tutorial_state()["page"] == "battle", "Во время похода урок ведёт в лагерь")
	finish_run()
	check(game.last_result == "wipe" and not game.meter["deaths"].is_empty() and game.meter["deaths"][0]["who"] == "Жрец", "Ошибка строя не приводит к гибели жреца первым")
	check(game.formation_lesson and game.tutorial_state()["action"] == "formation", "Причина поражения не привела к уроку строя")
	check(game.party_ids[0] == "priest", "После поражения игра сама исправила строй")
	game.move_in_party("warrior",0)
	check(not game.formation_lesson and game.formation_corrected, "Ручная перестановка не продвинула обучение")
	game.start_run()
	finish_run()
	check(game.last_result == "win" and game.meter["deaths"].is_empty(), "Правильная тройка не проходит первый данж живой")
	check(game.slots() == 4 and game.dungeon_open("catacombs"), "Первая победа не открыла место/катакомбы")
	check(game.wallet.is_empty() and game.bag.size() >= 7, "Первый данж не дал улучшений или дал преждевременную валюту")
	check(game.tutorial_state()["action"] == "gear", "Обучение не объясняет ручное надевание новой добычи")
	var state: Dictionary = game.tutorial_state()
	var owner: int = game.party_ids.find(state["cls"])
	var reward: Dictionary = state["item"]
	check(game.equip(owner,reward) == "" and game.loot_equipped, "Надевание улучшения не завершило шаг обучения")
	check(game.tutorial_state()["action"] == "dungeon" and game.tutorial_state()["dungeon"] == "catacombs", "Урок не подсвечивает нужный данж")
	game.selected_dungeon = "catacombs"
	check(game.tutorial_state()["id"] == "currency", "После выбора данжа нет подсказки похода")
	game.start_run("catacombs")
	while game.mode == "run" and not game.craft_currency_received and float(game.run["t"]) < 900: game.step(0.1)
	game.retreat()
	check(game.craft_currency_received and game.tutorial_state()["action"] == "craft", "Материалы не запускают урок крафта")
	var weapon: Dictionary = game.heroes[0]["items"]["weapon"]
	var count: int = game.wallet["ember_attack"]
	game.craft(weapon,"ember_attack")
	check(game.wallet["ember_attack"] == count-1 and game.craft_taught and not game.tutorial_active(), "Крафт не завершает обучение")
	var fake := weapon.duplicate(true)
	check(game.craft(fake,"ember_elemental") == "Этого предмета нет в снаряжении или сумке", "Можно крафтить копию отсутствующей вещи")
	var hero: Dictionary = game.heroes[0]
	hero["lvl"] = 14; hero["xp"] = 0
	game.start_run("crypt")
	game._spawn_enemy(); game.enemy["hp"] = 0; game.step(0.01)
	check(hero["xp"] == 0, "Серые мобы дают опыт")
	game.retreat(); hero["lvl"] = 18
	game._gain_xp(hero,999999,18)
	check(hero["lvl"] == 18 and hero["xp"] == 0, "XP перескочил предел данжа")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()+"/tests")
	game.save_path = "user://tests/onboarding-save.json"
	game.sound_volume = 0.2; game.sound_muted = true
	game.simulating = false; game.save_game(); game.simulating = true
	var order: Array = game.party_ids.duplicate()
	game._new_game(); game._load_game()
	check(game.party_ids == order and game.craft_taught and game.intro_seen and game.formation_corrected, "Сейв потерял обучение или строй")
	check(game.sound_volume == 0.2 and game.sound_muted, "Сейв потерял настройки звука")
	check(DB.skill_selected(game.roster["priest"]), "Сейв потерял выбранное умение")
	check(game.class_unlocked("hunter") and not game.class_unlocked("shaman"), "Открылись будущие классы")
	game.free()
	print("ONBOARDING TEST: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
