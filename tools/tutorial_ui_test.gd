extends SceneTree
## User actions: a locked talent can be read, and only the separate choice applies it.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var scene = load("res://main.tscn")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	if not "save_path" in game:
		quit(1)
		return
	game.save_path = "user://tutorial_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.simulating = true
	await process_frame
	var dashboard = game.dashboard
	var camp = dashboard.camp_view
	check(game.party_ids.is_empty(), "Fresh party must remain empty until the player recruits.")
	check(camp.picked_cls == "priest", "The first class description should recommend the priest without recruiting it.")
	check(dashboard.intro_panel.visible, "The introductory instructions should be visible on first launch.")
	check(dashboard.go_button.disabled, "Starting a run with no party must be disabled in the battle page.")
	for card in dashboard.hero_cards:
		check(not card.root.visible, "Empty party must not display stale hero cards.")
	game.acknowledge_intro()
	dashboard.refresh()
	check(not dashboard.intro_panel.visible, "Acknowledging the introduction should close it.")
	check(dashboard.tutorial_panel.visible, "The current tutorial task should replace the introduction.")
	check(game.tutorial_state()["action"] == "recruit" and game.tutorial_state()["cls"] == "priest", "The first actionable tutorial step should point at priest recruitment.")
	game.set_in_party("priest", true)
	dashboard.refresh()
	var priest: Dictionary = game.roster["priest"]
	var skill_options: Array = DB.skill_options(priest)
	check(skill_options.size() >= 2, "A level-one hero needs a real choice of basic skills.")
	var skill: Dictionary = skill_options[-1]
	camp.preview_skill("priest", str(skill["id"]))
	check(not DB.skill_selected(priest), "Reading a basic skill must not equip it automatically.")
	check(camp.skill_description.text == skill["desc"], "The skill preview should show its persistent readable description.")
	check(not camp.skill_choose_button.disabled, "A basic skill should be selectable at level one.")
	await process_frame
	await process_frame
	await process_frame
	var scroll = camp.get_parent().get_parent()
	check(scroll is ScrollContainer and scroll.get_global_rect().intersects(camp.skill_choose_button.get_global_rect()), "The tutorial should reveal an off-screen skill choice.")
	check(dashboard.coach_glow.targets.has(camp.skill_choose_button), "The tutorial glow should point at the actual skill choice control.")
	scroll.scroll_vertical = 0
	dashboard._refresh_tutorial()
	await process_frame
	await process_frame
	check(scroll.scroll_vertical == 0, "Refreshing the same tutorial state must not yank a player back after manual scrolling.")
	camp.skill_choose_button.pressed.emit()
	check(priest["skill_id"] == skill["id"] and DB.skill_selected(priest), "The explicit choose button should apply the basic skill.")
	check(priest["talents"].is_empty(), "Basic-skill selection must not allocate talent tiers.")
	check(game.party_ids == ["priest"], "Tutorial actions must not auto-fill or reorder the party.")
	var hero: Dictionary = game.roster["warrior"]
	var before: Dictionary = hero["talents"].duplicate(true)
	camp.picked_cls = "warrior"
	camp.preview_talent("warrior", 10, 1)
	check(hero["talents"] == before, "Reading a locked talent must not allocate it.")
	check(camp.talent_preview_panel.text == DB.talent_tiers(hero)[1]["options"][1]["desc"], "Locked talent description should be readable.")
	check(camp.talent_choose_button.disabled, "The choice button must show a level requirement for locked talents.")
	var key: String = camp._preview_key(hero)
	camp.refresh()
	check(camp.talent_previews[key]["level"] == 10 and camp.talent_previews[key]["option"] == 1, "Refresh should retain the chosen talent preview.")
	check(camp.class_description.get_theme_font_size("normal_font_size") >= 14, "Class descriptions should use a readable font.")
	hero["lvl"] = 10
	camp.refresh()
	check(not camp.talent_choose_button.disabled, "An unlocked, unchosen talent should allow explicit selection.")
	check(hero["talents"] == before, "Levelling and refreshing must not silently choose a talent.")
	camp.talent_choose_button.pressed.emit()
	check(int(hero["talents"].get("10", -1)) == 1, "The separate choose button should apply the previewed talent.")
	print("TUTORIAL_UI_CHECKS checks=", checks, " failures=", failures)
	await process_frame
	await process_frame
	game.free()
	await process_frame
	quit(1 if failures else 0)
