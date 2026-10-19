extends SceneTree
## Actual camp controls: click insertion, Godot drag/drop callbacks and read-only runs.

var checks := 0
var failures := 0


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
	game.save_path = "user://formation_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.simulating = true
	game.intro_seen = true
	game.craft_taught = true
	for cls in ["priest", "warrior", "mage"]:
		game.set_in_party(cls, true)
		var options: Array = DB.skill_options(game.roster[cls])
		if not options.is_empty(): game.set_skill(cls, str(options[0]["id"]))
	var dashboard = game.dashboard
	dashboard.select_page("camp")
	var camp = dashboard.camp_view
	await process_frame
	await process_frame
	check(game.party_ids == ["priest", "warrior", "mage"], "Recruitment order should remain player-defined.")
	camp.formation_cards[0].pressed.emit()
	check(camp.move_source == "priest" and camp.picked_cls == "priest", "A card click should select the source and open its class description.")
	check(camp.cancel_move_button.visible, "A selected source should offer explicit cancellation.")
	camp.formation_cards[2].mouse_entered.emit()
	check(camp.drop_target == 2, "In click mode, hovering a destination should mark the insertion point.")
	camp.formation_cards[2].mouse_exited.emit()
	check(camp.drop_target == -1, "Leaving a card should clear its insertion marker.")
	camp.formation_cards[2].pressed.emit()
	check(game.party_ids == ["warrior", "mage", "priest"], "Click-to-click should insert the hero at the requested final position.")
	check(camp.move_source.is_empty() and camp.picked_cls == "priest", "After insertion, retain the moved hero for reading and clear the source.")
	camp.formation_cards[0].pressed.emit()
	camp.cancel_move_button.pressed.emit()
	check(camp.move_source.is_empty(), "Cancel should clear the pending move.")
	camp.formation_cards[1].pressed.emit()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	camp._unhandled_key_input(escape)
	check(camp.move_source.is_empty(), "Escape should cancel a pending move.")
	# Force a real Viewport drag, then execute the receiving Control's Godot callbacks.
	var source = camp.formation_cards[2]
	var data := {"kind": "party_hero", "owner": camp.get_instance_id(), "cls": "priest"}
	camp.begin_formation_drag("priest")
	var preview := Label.new()
	preview.text = "Жрец"
	source.force_drag(data, preview)
	check(root.gui_is_dragging(), "The viewport should recognize a real Godot drag operation.")
	var target = camp.formation_cards[0]
	check(target._can_drop_data(Vector2(10, 10), data), "Formation cards should accept a valid local hero payload.")
	check(camp.drop_target == 0, "The hovered insertion destination should be visible before dropping.")
	check(not camp.formation_cards[3]._can_drop_data(Vector2.ZERO, data), "The unopened fourth slot should reject drops.")
	check(not target._can_drop_data(Vector2.ZERO, {"kind": "party_hero", "owner": 0, "cls": "priest"}), "Unrelated drag payloads must not move the party.")
	target._drop_data(Vector2(10, 10), data)
	check(game.party_ids == ["priest", "warrior", "mage"], "Drag/drop should insert a rear hero at the front.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-10, -10)
	root.push_input(release, true)
	await process_frame
	camp.finish_formation_drag()
	camp.refresh()
	await process_frame
	await process_frame
	# Also drive a normal mouse drag through the Viewport, not just callbacks.
	var source_position: Vector2 = camp.formation_cards[0].get_global_rect().get_center()
	var target_position: Vector2 = camp.formation_cards[2].get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = source_position
	press.global_position = source_position
	root.push_input(press, true)
	await process_frame
	var begin_motion := InputEventMouseMotion.new()
	begin_motion.position = source_position + Vector2(24, 0)
	begin_motion.global_position = begin_motion.position
	begin_motion.relative = Vector2(24, 0)
	begin_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(begin_motion, true)
	await process_frame
	check(root.gui_is_dragging(), "Normal mouse motion should invoke the card's drag-source callback.")
	var move_motion := InputEventMouseMotion.new()
	move_motion.position = target_position
	move_motion.global_position = target_position
	move_motion.relative = target_position - begin_motion.position
	move_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move_motion, true)
	await process_frame
	check(camp.drop_target == 2, "Mouse dragging over a real card should highlight its insertion destination.")
	release.position = target_position
	release.global_position = target_position
	root.push_input(release, true)
	await process_frame
	check(game.party_ids == ["warrior", "mage", "priest"], "Mouse release should drop through Godot and reorder the actual party.")
	check(not root.gui_is_dragging(), "Releasing the mouse should end the viewport drag.")
	game.start_run("crypt")
	camp.refresh()
	var before: Array = game.party_ids.duplicate()
	check(not camp.formation_cards[0]._can_drop_data(Vector2.ZERO, data), "Drag/drop must be disabled during an expedition.")
	camp.formation_cards[0].pressed.emit()
	camp.formation_cards[2].pressed.emit()
	check(game.party_ids == before and camp.move_source.is_empty(), "During an expedition, card clicks may read heroes but must not reorder them.")
	check(camp.picked_cls == "priest", "Class descriptions remain readable while formation editing is locked.")
	print("FORMATION_UI_CHECKS checks=", checks, " failures=", failures)
	await process_frame
	await process_frame
	game.free()
	await process_frame
	quit(1 if failures else 0)
