extends SceneTree
## Фильтр по классу/материалу, общая валюта, безопасная продажа и пустой отряд.

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run_tests")


func has_identity(items: Array, target: Dictionary) -> bool:
	return items.any(func(it): return is_same(it, target))


func run_tests() -> void:
	DB.ensure()
	seed(52)
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://gear-filter-test-unused-save.json"
	root.add_child(game)
	game.simulating = true
	game.set_process(false)
	game.test_mode = true
	game.party_ids = ["warrior", "mage", "priest"]
	game._set_party()
	game.dashboard.select_page("gear")
	var ui = game.dashboard.gear_view
	var sword := Items.generate(5, "normal", "sword", "", "strength")
	var plate := Items.generate(5, "normal", "armour", "plate", "strength")
	var cloth := Items.generate(5, "normal", "armour", "cloth", "intellect")
	var bow := Items.generate(5, "normal", "bow", "", "agility")
	var ring := Items.generate(5, "magic", "ring", "", "agility")
	game.bag = [sword, plate, cloth, bow, ring]
	game.wallet["ember_attack"] = 9
	ui._select_hero(1)
	var mage: Dictionary = game.heroes[1]
	var shown: Array = ui.displayed_items()
	check(DB.can_use(mage, sword) and has_identity(shown, sword), "Маг не видит подходящий меч с чужой основной характеристикой")
	check(not has_identity(shown, plate) and not has_identity(shown, bow), "Маг видит чужой материал или тип оружия")
	check(has_identity(shown, cloth) and has_identity(shown, ring), "Совместимая ткань или общие украшения скрыты")
	check(shown.all(func(it): return DB.can_use(mage, it)), "Фильтр расходится с правилами надевания")
	check(ui.bag_title.text.contains("Для героя: %d" % shown.size()) and ui.bag_title.text.contains("всего 5/"), "Счётчик смешивает показанные вещи и общую вместимость")
	check(ui.cur_cells["ember_attack"].count == 9, "Валюта не общая для выбранного героя")
	ui.selected = bow
	ui.refresh()
	check(ui.selected == null and ui.equip_button.disabled, "Скрытая вещь осталась выбранной для надевания")
	# Ровно совместимые обычные вещи продаются, скрытые и магическое кольцо остаются.
	var expected_gold := 0
	for it in shown:
		if it["rarity"] == "normal": expected_gold += Items.sell_price(it)
	var gold_before: int = game.gold
	ui._sell_where(func(it): return it["rarity"] == "normal")
	check(game.bag_index(sword) < 0 and game.bag_index(cloth) < 0, "Продажа обычных не продала видимые обычные вещи")
	check(game.bag_index(plate) >= 0 and game.bag_index(bow) >= 0 and game.bag_index(ring) >= 0, "Продажа обычных затронула скрытые или магические вещи")
	check(game.gold == gold_before + expected_gold, "Золото не совпадает с продажей только видимых обычных вещей")
	ui._sell_where(func(_it): return true)
	check(game.bag.size() == 2 and game.bag_index(plate) >= 0 and game.bag_index(bow) >= 0, "Продать видимые продало вещи другого героя")
	ui._select_hero(0)
	check(has_identity(ui.displayed_items(), plate), "Скрытая броня потерялась при смене героя")
	check(ui.cur_cells["ember_attack"].count == 9, "Смена героя изменила общую валюту")
	var card: String = ui.item_card(plate, false)
	var cap := Items.capacity(plate)
	check(card.contains("Материал: Латы") and card.contains("Профиль характеристик: Сила"), "В карточке нет понятного материала и профиля")
	check(card.contains("Аффиксы 0/%d" % cap["total"]) and card.contains("префиксы 0/%d" % cap["prefix"]), "Карточка не использует лимиты Items.capacity")
	check(ui.hero_summary.text.contains("Сила атаки") and ui.hero_summary.text.contains("заклинаний") and ui.hero_summary.text.contains("уклонение") and ui.hero_summary.text.contains("Крит атак") and ui.hero_summary.text.contains("Мана"), "Нет расширенных характеристик героя")
	check(ui._number(12.34567) == "12.35" and ui._number(12.0) == "12" and ui._number(12.5) == "12.5", "Числа не ограничены двумя знаками")
	# Пустой отряд не открывает сумку чужих героев и не позволяет ничего продать.
	game.party_ids = []
	game._set_party()
	ui.refresh()
	ui.on_game_update()
	ui._equip_selected()
	ui._sell_where(func(_it): return true)
	check(ui.displayed_items().is_empty() and ui.hero_tabs.all(func(tab): return not tab.visible), "Пустой отряд показывает вкладки или предметы")
	check(ui.hero_summary.text.contains("Добавь героя") and ui.equip_button.disabled, "Нет понятного состояния пустого отряда")
	check(game.bag.size() == 2 and ui.bag_cells.all(func(cell): return cell.item == null), "Пустой отряд продал или показывает скрытые вещи")
	check(not ui.item_card(plate, true).is_empty(), "Просмотр карточки без отряда вызвал ошибку")
	game.free()
	print("GEAR FILTER TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
