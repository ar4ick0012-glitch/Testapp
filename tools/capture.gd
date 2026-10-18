extends SceneTree
## Снимки настоящего интерфейса. Запуск с графическим дисплеем и --audio-driver Dummy.
## Отдельный XDG_DATA_HOME защищает пользовательское сохранение во время съёмки.

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	seed(1)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.repeat_run = false
	game.dashboard.select_page("camp")
	await shot("camp")
	game.simulating = true
	game.start_run("crypt")
	game.t += 0.4
	game.step(0.4)
	game.dashboard.select_page("battle")
	await shot("march")
	var boss_seconds := 0.0
	while game.mode == "run" and float(game.run["t"]) < 1800:
		if game.enemy.get("kind") == "boss":
			boss_seconds += 0.1
			if boss_seconds >= 18.0: break
		game.t += 0.1
		game.step(0.1)
	game.simulating = false
	game.dashboard.select_page("battle")
	game.dashboard._update_meter(game.dashboard.battle_meter, "dmg")
	await shot("battle")
	game.dashboard.select_page("details")
	game.dashboard.meter_kind = "heal"
	game.dashboard._update_meter(game.dashboard.full_meter, "heal")
	await shot("details")
	game.retreat()
	game.dashboard.select_page("gear")
	if not game.bag.is_empty():
		var gear = game.dashboard.gear_view
		gear.selected = game.bag[0]
		for i in game.heroes.size():
			if DB.can_use(game.heroes[i], gear.selected):
				gear.hero_i = i
				break
		gear.refresh()
	await shot("gear")
	var gear = game.dashboard.gear_view
	gear.hero_i = 0
	gear.selected = game.heroes[0]["items"]["weapon"]
	gear.refresh()
	gear.show_tip(gear.doll_cells["weapon"])
	await process_frame
	await process_frame
	await shot("gear-equipped")
	gear.hide_tip()
	# Просмотр моделей в действующем интерфейсе; это тестовые встречи, не прохождение.
	game.test_mode = true
	for sample in [["catacombs", "Слизень"], ["cult", "Пламенная мать"], ["spire", "Глашатай пустоты"]]:
		game.start_run(sample[0])
		if sample[0] != "catacombs":
			game.run["floor_i"] = int(DB.dungeon(sample[0])["floors"]) - 1
			game.run["pack"] = game.PACKS_PER_FLOOR + 1
		for attempt in 50:
			game._spawn_enemy()
			if game.enemy["name"] == sample[1]: break
		game.dashboard.select_page("battle")
		await shot("enemy-" + sample[0])
		game.retreat()
	root.size = Vector2i(1280, 720)
	game.dashboard.select_page("camp")
	await shot("camp-720")
	quit()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if not args.is_empty() else OS.get_user_data_dir() + "/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var err := root.get_texture().get_image().save_png(directory + "/" + name + ".png")
	print("SCREENSHOT ", name, " error=", err)
