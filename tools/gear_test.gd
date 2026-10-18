extends SceneTree
## Регрессии ручного снаряжения и сравнения. Использовать отдельный каталог пользовательских данных.

var checks := 0
var failures := 0
var game


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run_tests")


func item(kind: String, stats: Dictionary) -> Dictionary:
	var it := Items.generate(1, "normal", kind)
	it["implicit"] = stats
	it["dur"] = 100.0
	return it


func run_tests() -> void:
	DB.ensure()
	seed(7)
	game = load("res://main.tscn").instantiate()
	game.simulating = true
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/tests")
	game.save_path = "user://tests/gear-save.json"
	game.test_mode = true
	root.add_child(game)
	game.party_ids = ["warrior", "priest", "paladin"]
	game._set_party()
	game.repeat_run = false
	var hero: Dictionary = game.roster["warrior"]
	var before: Dictionary = hero["items"].duplicate(true)
	var sword := item("sword", {"flat_phys": 30})
	game.bag.append(sword)
	game._end_run("win")
	check(hero["items"] == before and sword in game.bag, "Конец похода сам сменил вещи")
	var worn: Dictionary = hero["items"]["weapon"]
	worn["dur"] = 50.0
	game.gold = 100
	game.repeat_run = true
	game.step(game.CAMP_PAUSE)
	check(game.gold == 100 and worn["dur"] == 50.0, "Автоповтор потратил золото на починку")
	check(game.equip(0, sword) != "" and sword in game.bag, "Можно надеть предмет в бою")
	game.wallet["ember_attack"] = 2
	var sword_before := sword.duplicate(true)
	check(game.craft(sword, "ember_attack") != "" and sword == sword_before, "Крафт изменил вещь в бою")
	game.retreat()
	game.repair_all(true)
	check(worn["dur"] == 100.0 and game.gold < 100, "Ручная починка не сработала")
	var comparison: Dictionary = game.compare_item(hero, sword)
	check(comparison["after"]["dps"] > comparison["before"]["dps"], "Оружие не даёт прирост DPS в сравнении")
	check(game.equip(0, sword) == "", "Ручное надевание не сработало")
	var actual := Calc.offense(hero, game.stats[0], game.ref_enemy())
	check(is_equal_approx(actual["dps"], comparison["after"]["dps"]), "DPS после надевания не совпал с карточкой")
	check(sword not in game.bag and worn in game.bag, "Замена потеряла предмет")
	var twin_a := item("boots", {"armour": 10})
	var twin_b: Dictionary = twin_a.duplicate(true)
	game.bag.append_array([twin_a, twin_b])
	game.equip(0, twin_b)
	check(game.bag_index(twin_a) >= 0 and game.bag_index(twin_b) < 0 and is_same(hero["items"]["boots"], twin_b), "Одинаковые вещи дублируются при надевании")
	check(game.equip(0, twin_a.duplicate(true)) != "", "Можно надеть копию, которой нет в сумке")
	var ring1 := item("ring", {"flat_phys": 2})
	var ring2 := item("ring", {"life": 30})
	var new_ring := item("ring", {"flat_phys": 6})
	hero["items"]["ring1"] = ring1
	hero["items"]["ring2"] = ring2
	game.bag.append(new_ring)
	comparison = game.compare_item(hero, new_ring, "ring2")
	check(comparison["slot"] == "ring2" and comparison["after"]["survival"] < comparison["before"]["survival"], "Кольцо сравнивается с неправильным слотом")
	game.equip(0, new_ring, "ring2")
	check(hero["items"]["ring1"] == ring1 and hero["items"]["ring2"] == new_ring and ring2 in game.bag, "Замена второго кольца не совпала с выбором")
	var paladin: Dictionary = game.roster["paladin"]
	var paladin_i: int = game.heroes.find(paladin)
	var shield := item("shield", {"armour": 100})
	paladin["items"]["weapon"] = item("mace", {"flat_phys": 4})
	paladin["items"]["offhand"] = shield
	var two_handed := item("greatsword", {"flat_phys": 20})
	game.bag.append(two_handed)
	game._recalc()
	comparison = game.compare_item(paladin, two_handed)
	check(comparison["removed"].size() == 2, "Сравнение двуручки не учитывает потерю щита")
	check(comparison["after"]["survival"] < comparison["before"]["survival"], "Карточка скрывает потерю защиты при снятии щита")
	check(game.equip(paladin_i, two_handed) == "" and not paladin["items"].has("offhand") and shield in game.bag, "Двуручка не сняла щит")
	var after_s: Dictionary = game.stats[paladin_i]
	var enemy: Dictionary = game.ref_enemy()
	var ehp: float = after_s["max_life"] * enemy["dmg"] / Calc.damage_taken(after_s, enemy["dmg"], enemy["dmg_types"])
	check(is_equal_approx(ehp, comparison["after"]["survival"]), "Выживаемость после замены не совпала с карточкой")
	# В полной сумке нельзя потерять второй предмет при переходе на двуручку.
	var offhand := item("shield", {"armour": 15})
	game.bag.append(offhand)
	game.equip(paladin_i, offhand)
	while game.bag.size() < game.BAG_CAP:
		game.bag.append(item("helmet", {"armour": 5}))
	var onehand := item("mace", {"flat_phys": 4})
	game.bag[game.bag.size() - 1] = onehand
	game.equip(paladin_i, onehand)
	while game.bag.size() < game.BAG_CAP: game.bag.append(item("helmet", {}))
	if two_handed not in game.bag: game.bag[0] = two_handed
	var old_items: Dictionary = paladin["items"].duplicate(true)
	check(game.equip(paladin_i, two_handed) != "" and paladin["items"] == old_items and game.bag.size() == game.BAG_CAP, "Полная сумка теряет снимаемые вещи")
	# Просмотр карточки не должен бросать кубики за спиной игрока.
	seed(777)
	var expected := randf()
	seed(777)
	var state: Dictionary = hero.duplicate(true)
	for i in 5: game.compare_item(hero, new_ring, "ring2")
	check(is_equal_approx(randf(), expected) and hero == state, "Предпросмотр изменил героя или RNG")
	var broken := item("sword", {"flat_phys": 900})
	broken["dur"] = 0.0
	comparison = game.compare_item(hero, broken)
	check(comparison["after"]["dps"] < comparison["before"]["dps"], "Сломанное оружие даёт статы в сравнении")
	hero["spec"] = "arms"
	hero["talents"]["15"] = 0
	hero["lvl"] = 1
	check(not DB.has_talent_flag(hero, "titan_grip"), "Талант последнего яруса работает до 15 уровня")
	hero["lvl"] = 15
	check(DB.has_talent_flag(hero, "titan_grip"), "Талант не открыл вторую двуручку на 15 уровне")
	# Старый флаг автонадевания не должен вернуться вместе с сохранением.
	hero["spec"] = "prot"
	game._set_party()
	game.simulating = false
	game.save_game()
	game.simulating = true
	var file := FileAccess.open(game.save_path, FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	saved["auto_equip"] = true
	file = FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	game._load_game()
	check(game.roster["warrior"]["lvl"] == 15 and game.bag.size() == game.BAG_CAP, "Миграция старого сохранения потеряла прогресс")
	var restored: Dictionary = game.roster["warrior"]["items"].duplicate(true)
	game._end_run("win")
	check(game.roster["warrior"]["items"] == restored, "Старое сохранение снова включило автонадевание")
	game.free()
	print("GEAR TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
