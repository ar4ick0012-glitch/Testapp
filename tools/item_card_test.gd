extends SceneTree
## Карточки проверяются в настоящем интерфейсе с отдельными пользовательскими данными.

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
	DB.ensure()
	seed(37)
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://item-card-test-unused-save.json"
	root.add_child(game)
	game.simulating = true
	game.set_process(false)
	root.size = Vector2i(1280, 720)
	game.party_ids = ["warrior", "priest"]
	game._set_party()
	game.dashboard.select_page("gear")
	var ui = game.dashboard.gear_view
	var hero: Dictionary = game.roster["warrior"]
	var weapon := Items.generate(2, "normal", "sword")
	weapon["rarity"] = "magic"
	weapon["implicit"] = {"flat_phys": 12.5}
	weapon["mods"] = [{"id": "inc_speed", "stat": "inc_speed", "tier": 2, "type": "suffix", "value": 15.25}]
	hero["items"]["weapon"] = weapon
	var twin := weapon.duplicate(true)
	game.bag = [twin]
	game._recalc()
	ui.hero_i = 0
	ui.selected = weapon
	ui.refresh()
	var card: String = ui.item_card(weapon, true)
	var offense := Calc.offense(hero, game.stats[0], game.ref_enemy())
	check(card.contains("DPS героя с этим оружием:") and card.contains("%.2f" % offense["dps"]), "Надетое оружие не показывает фактический DPS героя")
	check(card.contains("Удар %.2f" % offense["hit"]) and card.contains("скорость %.2f/с" % offense["speed"]), "Нет абсолютного урона и скорости")
	check(card.contains(DB.stat_text("flat_phys", 12.5)) and card.contains("15.25"), "Свойства надетого предмета скрыты без флажка")
	check(not card.contains("включи «Все свойства»"), "Карточка надетой вещи предлагает открыть уже показанные свойства")
	check(not card.contains("Вместо:"), "Надетая вещь ошибочно сравнивается с одинаковой вещью в сумке")
	check(ui.equip_button.disabled, "Надетый предмет можно снова надеть из-за одинакового предмета в сумке")
	check(ui.doll_cells["weapon"].selected and not ui.bag_cells[0].selected, "Одинаковые предметы выделяются вместе")
	var bag_card: String = ui.item_card(twin, true)
	check(bag_card.contains("Вместо:") and not bag_card.contains("Надето:"), "Копия в сумке ошибочно считается надетой")
	check(bag_card.contains("включи «Все свойства»"), "Сумка перестала показывать краткое сравнение")
	ui.details_box.button_pressed = true
	check(ui.item_card(twin, true).contains(DB.stat_text("flat_phys", 12.5)), "Флажок не раскрывает свойства предмета из сумки")
	ui.details_box.button_pressed = false
	ui._select_hero(1)
	check(ui.details.text.contains("Надето: Воин") and ui.details.text.contains("%.2f" % offense["dps"]), "Смена вкладки приписывает выбранное оружие другому герою")
	var healthy_dps: float = offense["dps"]
	weapon["dur"] = 0.0
	game._recalc()
	card = ui.item_card(weapon, true)
	offense = Calc.offense(hero, game.stats[0], game.ref_enemy())
	check(card.contains("Сломано: статы не работают") and card.contains("%.2f" % offense["dps"]) and offense["dps"] < healthy_dps, "Карточка сломанного оружия учитывает неработающие бонусы")
	check(card.contains(DB.stat_text("flat_phys", 12.5)), "Сломанное оружие потеряло описание своих свойств")
	ui.on_game_update()
	check(ui.details.text.contains("Сломано: статы не работают") and ui.details.text.contains("%.2f" % offense["dps"]), "Выбранная карточка не обновляется после потери прочности без новой добычи")
	# Просмотр не должен менять героя и состояние генератора случайных чисел.
	var state: Dictionary = hero.duplicate(true)
	seed(900)
	var expected := randf()
	seed(900)
	for i in 3:
		ui.item_card(weapon, true)
	check(hero == state and is_equal_approx(randf(), expected), "Карточка меняет героя или RNG")
	# Крайняя ячейка и максимально длинная карточка остаются внутри панели.
	ui._select_hero(0)
	for i in 24:
		weapon["mods"].append({"id": "inc_speed", "stat": "inc_speed", "tier": 2, "type": "suffix", "value": i})
	var cell = ui.bag_cells.back()
	cell.item = weapon
	await process_frame
	await process_frame
	ui.show_tip(cell)
	await process_frame
	await process_frame
	await process_frame
	var tip_rect: Rect2 = ui.tip_panel.get_rect()
	check(Rect2(Vector2.ZERO, ui.size).encloses(tip_rect), "Длинная подсказка выходит за границы панели при 1280×720: %s, панель %s" % [tip_rect, ui.size])
	check(ui._tip_bounds().encloses(tip_rect), "Длинная подсказка обрезается внешней прокруткой при 1280×720")
	check(tip_rect.size.x <= 360 and tip_rect.size.y <= ui.size.y - 8, "Размер подсказки не ограничен")
	check(ui.tip_text.scroll_active and ui.tip_text.get_content_height() > ui.tip_text.size.y, "Длинную подсказку невозможно прокрутить")
	ui.tip_text.get_v_scroll_bar().value = 50.0
	var scroll_before: float = ui.tip_text.get_v_scroll_bar().value
	ui.on_game_update()
	await process_frame
	await process_frame
	check(is_equal_approx(ui.tip_text.get_v_scroll_bar().value, scroll_before), "Периодическое обновление сбрасывает прокрутку неизменившейся карточки")
	# Закрытие во время отложенного размещения не возвращает старую подсказку.
	ui.show_tip(cell)
	ui.hide_tip()
	await process_frame
	await process_frame
	check(not ui.tip_panel.visible, "Отложенное размещение снова открывает закрытую подсказку")
	game.free()
	print("ITEM CARD TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
