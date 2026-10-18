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
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://tutorial_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.simulating = true
	await process_frame
	var dashboard = game.dashboard
	var camp = dashboard.camp_view
	check(game.party_ids.is_empty(), "Fresh party must remain empty until the player recruits.")
	check(dashboard.intro_panel.visible, "The introductory instructions should be visible on first launch.")
	check(dashboard.go_button.disabled, "Starting a run with no party must be disabled in the battle page.")
	for card in dashboard.hero_cards:
		check(not card.root.visible, "Empty party must not display stale hero cards.")
	game.acknowledge_intro()
	dashboard.refresh()
	check(not dashboard.intro_panel.visible, "Acknowledging the introduction should close it.")
	check(dashboard.tutorial_panel.visible, "The current tutorial task should replace the introduction.")
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
	game.free()
	quit(1 if failures else 0)
