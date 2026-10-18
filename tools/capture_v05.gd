extends SceneTree
## Реальный интерфейс и прохождение; отдельный XDG_DATA_HOME обязателен.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	seed(9)
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://tests/capture-v05.json"
	root.add_child(game)
	game.set_process(false)
	game.simulating = true
	root.size = Vector2i(1600,1000)
	game.dashboard.select_page("camp")
	await shot("01-intro")
	game.acknowledge_intro()
	for cls in ["warrior","priest","mage"]: game.set_in_party(cls,true)
	game.dashboard.select_page("camp")
	await shot("02-party")
	game.dashboard.camp_view.preview_talent("warrior",5,1)
	var scroll = game.dashboard.camp_view.get_parent().get_parent()
	scroll.scroll_vertical = 420
	await shot("03-talents")
	scroll.scroll_vertical = 0
	game.start_run("training")
	while game.mode == "run" and float(game.run["t"]) < 600:
		game.t += 0.1
		game.step(0.1)
	game.dashboard.select_page("gear")
	var gear = game.dashboard.gear_view
	gear.hero_i = 0
	for it in game.bag:
		if it.get("starter_for") == "warrior": gear.selected=it; break
	gear.refresh()
	await shot("04-first-loot")
	for i in game.heroes.size():
		for it in game.bag.duplicate():
			if it.get("starter_for") == game.heroes[i]["cls"]: game.equip(i,it)
	game.start_run("crypt")
	var boss_seconds := 0.0
	while game.mode == "run" and float(game.run["t"]) < 900:
		game.t += 0.1
		game.step(0.1)
		if game.enemy.get("kind") == "boss":
			boss_seconds += 0.1
			if boss_seconds >= 15: break
	game.dashboard.select_page("battle")
	game.dashboard._update_meter(game.dashboard.battle_meter,"dmg")
	await shot("05-first-boss")
	while game.mode == "run" and float(game.run["t"]) < 900: game.step(0.1)
	game.dashboard.select_page("gear")
	gear.hero_i=0
	gear.selected=game.heroes[0]["items"]["weapon"]
	gear.refresh()
	gear.show_tip(gear.doll_cells["weapon"])
	await shot("06-equipped-stats")
	gear.hide_tip()
	game.dashboard.select_page("details")
	game.dashboard.meter_kind="heal"
	game.dashboard._update_meter(game.dashboard.full_meter,"heal")
	await shot("07-healing")
	root.size=Vector2i(1280,720)
	game.dashboard.select_page("camp")
	await shot("08-camp-720")
	quit()
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var args:=OS.get_cmdline_user_args()
	var directory:=args[0] if not args.is_empty() else OS.get_user_data_dir()+"/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var err:=root.get_texture().get_image().save_png(directory+"/"+name+".png")
	print("SCREENSHOT ",name," error=",err)
