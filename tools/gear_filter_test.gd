extends SceneTree
## Фильтр по классу/материалу, общая валюта, безопасная продажа и пустой отряд.

var checks := 0
var failures := 0


class TutorialGame extends "res://scripts/game.gd":
	var tutorial_fixture: Dictionary = {}

	func tutorial_state() -> Dictionary:
		return tutorial_fixture


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
	var game = TutorialGame.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# Урок подсвечивает настоящие элементы, но ни вещи, ни валюту сам не применяет.
	var reward := Items.for_hero(game.heroes[0], 4, "normal", "sword")
	reward["implicit"]["flat_phys"] = 100.0
	game.bag = [reward]
	game._recalc()
	ui.selected = null
	ui.hero_i = 1
	game.tutorial_fixture = {"id": "first-loot", "page": "gear", "action": "gear", "cls": "warrior"}
	ui.refresh()
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await process_frame
	check(ui.hero_i == 0 and ui.tutorial_target != null and is_same(ui.tutorial_target.item, reward), "Урок добычи не нашёл героя и реальную ячейку улучшения")
	game.tutorial_fixture["item"] = reward
	ui.tutorial_target.upgrade = false
	ui._sync_tutorial_target()
	check(ui.tutorial_target != null and is_same(ui.tutorial_target.item, reward), "Урок игнорирует вещь из состояния, если суммарный прирост билда не дал отдельной стрелки")
	check(ui.tutorial_hint.visible and ui._tip_bounds().encloses(ui.tutorial_hint.get_rect()), "Подсказка урока не видна при 1280×720")
	check(ui.tutorial_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and ui.tutorial_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Подсказка перехватывает клики игрока")
	var before_weapon: Dictionary = game.heroes[0]["items"]["weapon"]
	ui.on_game_update()
	check(game.bag_index(reward) >= 0 and is_same(game.heroes[0]["items"]["weapon"], before_weapon), "Подсказка сама надела предмет")
	ui._select_hero(1)
	ui.refresh()
	check(ui.hero_i == 1, "Повторное обновление урока сбросило ручной выбор героя")
	ui._select_hero(0)
	var reward_cell = ui.tutorial_target
	ui.on_cell(reward_cell, false)
	check(ui.tutorial_target == ui.equip_button, "Выбор улучшения не подсветил настоящую кнопку надевания")
	ui._equip_selected()
	game.tutorial_fixture = {}
	ui.refresh()
	check(ui.tutorial_target == null and not ui.tutorial_hint.visible and is_same(game.heroes[0]["items"]["weapon"], reward), "После ручного надевания подсказка не очистилась")
	game.wallet["ember_attack"] = 2
	game.tutorial_fixture = {"id": "first-craft", "page": "gear", "action": "craft", "cls": "warrior"}
	ui.selected = null
	ui.refresh()
	check(ui.tutorial_target == ui.doll_cells["weapon"], "Урок крафта не выделил надетое оружие")
	ui.on_cell(ui.doll_cells["weapon"], false)
	check(ui.tutorial_target == ui.cur_cells["ember_attack"], "Урок крафта не потребовал ручного выбора доступного угля")
	var wallet_before: Dictionary = game.wallet.duplicate()
	var reward_before: Dictionary = reward.duplicate(true)
	ui.on_game_update()
	check(game.wallet == wallet_before and reward == reward_before, "Подсказка потратила валюту или сама изменила оружие")
	ui.on_cell(ui.cur_cells["ember_attack"], false)
	check(ui.tutorial_target == ui.apply_button, "Выбор угля не подсветил настоящую кнопку применения")
	ui._apply(1)
	game.tutorial_fixture = {}
	ui.refresh()
	check(game.wallet["ember_attack"] == 1 and ui.tutorial_target == null, "Ручной крафт не потратил ровно один уголь или не убрал подсветку")
	# Сохраняем исходный объём вещей для проверки пустого отряда.
	game.bag = [plate, bow]
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
