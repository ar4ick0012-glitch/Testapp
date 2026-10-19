extends SceneTree
## Автопилот: прогоняет игру на ускорении и печатает прогресс по данжам.
## Запуск: godot --headless --script res://tools/sim.gd -- 8 [seed] [test]
## 8 = сколько часов игры прогнать. test = тестовый режим (всё открыто, отряд из 4).
## Без test: пустой старт, автопилот сам выбирает тройку и вручную надевает учебную добычу.

const DT := 0.25
var started := false
var passive := false
var first_clears: Dictionary = {}

func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	run()
	return true

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var hours := float(args[0]) if args.size() > 0 else 8.0
	seed(int(args[1]) if args.size() > 1 else 1)
	var game = load("res://main.tscn").instantiate()
	game.simulating = true
	game.test_mode = args.has("test")
	passive = args.has("passive")
	root.add_child(game)
	game._new_game()
	game._set_party()
	_camp(game)
	game.repeat_run = true
	var sim_t := 0.0
	var runs := 0
	var streak := 0
	var next_report := 0.0
	var ids: Array = DB.dungeons.map(func(d): return d["id"])
	print("мин | данж | побед подряд | вайпов | уровни | золото | починка")
	print("Режим: ", "пассивный (без смены вещей, талантов и починки)" if passive else "активный (решения в лагере имитирует автопилот)")
	while sim_t < hours * 3600.0:
		var was_run: bool = game.mode == "run"
		game.t += DT
		game.step(DT)
		sim_t += DT
		if was_run and game.mode == "camp":
			runs += 1
			if game.last_result == "win" and not first_clears.has(game.selected_dungeon):
				first_clears[game.selected_dungeon] = snappedf(sim_t / 3600.0, 0.01)
			streak = streak + 1 if game.last_result == "win" else 0
			_camp(game)
			var k: int = ids.find(game.selected_dungeon)
			# две победы подряд: идём в следующий открытый данж
			if streak >= 2 and k + 1 < ids.size() and game.dungeon_open(ids[k + 1]):
				game.selected_dungeon = ids[k + 1]
				streak = 0
				print("%4d | → %s" % [sim_t / 60, DB.dungeon(ids[k + 1])["name"]])
			# автоповтор выключился после вайпов: шаг назад, покачаться попроще
			if not game.repeat_run:
				if k > 0:
					game.selected_dungeon = ids[k - 1]
					print("%4d | ← назад в %s" % [sim_t / 60, DB.dungeon(ids[k - 1])["name"]])
				game.repeat_run = true
				game.wipe_streak = 0
			game._recalc()
		if sim_t >= next_report:
			next_report += 1800.0
			var lv := []
			for h in game.heroes:
				lv.append("%s %d" % [h["cls"], h["lvl"]])
			print("%4d | %s | %d | %d | %s | %d | %d" % [sim_t / 60, DB.dungeon(game.selected_dungeon)["name"], streak, game.wipes, lv, game.gold, game.repair_cost()])
	print("\nИтог: походов %d, вайпов %d, пройдено: %s" % [runs, game.wipes, game.cleared])
	print("Первое прохождение (игровые часы): ", first_clears)
	for i in game.heroes.size():
		print("\n" + Calc.sheet(game.heroes[i], game.stats[i], game.ref_enemy()))


## В лагере: добираем отряд, раскидываем таланты, надеваем лучшее, продаём остальное
func _camp(game) -> void:
	for c in ["warrior", "priest", "mage", "hunter", "paladin", "warlock", "shaman"]:
		if game.party_ids.size() < game.slots() and game.class_unlocked(c) and not (c in game.party_ids):
			game.set_in_party(c, true)
	# Обоим сценариям задаём только обязательное ручное обучение.
	for i in game.heroes.size():
		var h: Dictionary = game.heroes[i]
		if h["items"].get("weapon") != null: continue
		for it in game.bag.duplicate():
			if it.get("starter_for") == h["cls"]: game.equip(i, it); break
	preload("res://tools/early_fixture.gd").choose_skills(game)
	if passive: return
	for h in game.heroes:
		for tier in DB.talent_tiers(h):
			if not h["talents"].has(str(int(tier["lvl"]))):
				h["talents"][str(int(tier["lvl"]))] = 0
	game._set_party()
	game.equip_best()
	# Не продаём учебное оружие героя, который ещё ждёт четвёртого места.
	for it in game.bag.duplicate():
		if it.get("starter_for", "") not in DB.start["classes"] or it.get("starter_for", "") in game.party_ids:
			game.sell_item(it)
	game.repair_all(true)
