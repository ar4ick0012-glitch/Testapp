extends SceneTree
## Снимки настоящего интерфейса. Запуск с графическим дисплеем и --audio-driver Dummy.
## Отдельный XDG_DATA_HOME защищает пользовательское сохранение во время съёмки.

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	seed(1)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.repeat_run = false
	game.dashboard.select_page("camp")
	await shot("camp")
	game.simulating = true
	game.start_run("crypt")
	var boss_seconds := 0.0
	while game.mode == "run" and float(game.run["t"]) < 1800:
		if game.enemy.get("kind") == "boss":
			boss_seconds += 0.1
			if boss_seconds >= 18.0: break
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
	quit()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if not args.is_empty() else OS.get_user_data_dir() + "/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var err := root.get_texture().get_image().save_png(directory + "/" + name + ".png")
	print("SCREENSHOT ", name, " error=", err)
