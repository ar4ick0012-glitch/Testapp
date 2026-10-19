extends SceneTree
var game
## Живое окно v0.6: реальные выборы, ошибка строя, исправление и победа.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	seed(9)
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://tests/capture-v06.json"
	root.add_child(game)
	game.set_process(false)
	game.simulating = true
	root.size = Vector2i(1600,1000)
	game.dashboard.select_page("camp")
	await shot("01-intro")
	game.acknowledge_intro()
	await shot("02-invite-healer")
	game.set_in_party("priest",true)
	await shot("03-first-skill")
	game.set_skill("priest",DB.skill_options(game.roster["priest"])[0]["id"])
	for cls in ["warrior","mage"]:
		game.set_in_party(cls,true)
		game.set_skill(cls,DB.skill_options(game.roster[cls])[0]["id"])
	await shot("04-party")
	game.start_run("crypt")
	game.dashboard.select_page("battle")
	while game.mode == "run" and not game.run.get("front_healer_lost",false) and float(game.run["t"]) < 600:
		game.t += 0.1; game.step(0.1)
	await shot("05-front-healer-falls")
	while game.mode == "run" and float(game.run["t"]) < 900: game.step(0.1)
	game.dashboard.select_page("camp")
	await shot("06-formation-lesson")
	var camp = game.dashboard.camp_view
	camp.formation_click(0)
	await shot("07-move-card")
	camp.formation_click(2)
	await shot("08-corrected-party")
	game.start_run("crypt")
	game.dashboard.select_page("battle")
	while game.mode == "run" and float(game.run["t"]) < 900:
		game.t += 0.1; game.step(0.1)
		if game.enemy.get("kind") == "boss" and game.enemy["hp"] < game.enemy["max_hp"] * 0.5: break
	game.dashboard.refresh()
	await shot("09-first-boss")
	while game.mode == "run" and float(game.run["t"]) < 900: game.step(0.1)
	game.dashboard.select_page("gear")
	await shot("10-loot-highlight")
	var state: Dictionary = game.tutorial_state()
	if state.get("action") == "gear": game.equip(game.party_ids.find(state["cls"]),state["item"])
	game.dashboard.select_page("gear")
	var gear = game.dashboard.gear_view
	gear.hero_i=0
	gear.selected=game.heroes[0]["items"]["weapon"]
	gear.refresh(); gear.show_tip(gear.doll_cells["weapon"])
	await shot("11-equipped-stats")
	gear.hide_tip()
	game.dashboard.select_page("details")
	game.dashboard.meter_kind="heal"
	game.dashboard._update_meter(game.dashboard.full_meter,"heal")
	await shot("12-healing")
	root.size=Vector2i(1280,720)
	game.dashboard.select_page("camp")
	await shot("13-camp-720")
	print("CAPTURE game_result=",game.last_result," deaths=",game.meter.get("deaths",[]).size())
	if game.sound != null: game.sound.set_muted(true)
	game.free()
	await create_timer(0.1).timeout
	await process_frame
	quit()
func shot(name: String) -> void:
	game.dashboard.refresh()
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var args:=OS.get_cmdline_user_args()
	var directory:=args[0] if not args.is_empty() else OS.get_user_data_dir()+"/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var err:=root.get_texture().get_image().save_png(directory+"/"+name+".png")
	print("SCREENSHOT ",name," error=",err)
