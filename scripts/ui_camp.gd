extends Control
## Camp preparation: formation, class identity and talent reading stay separate.

var game
const GOLD := Color("d9b977")
const GOLD_DIM := Color("57492f")
const PARCH := Color("e4dfd3")
const MUTED := Color("aaa293")
const BG := Color("131519")
const MAP := Rect2(14, 54, 482, 316)

var map_view: Control
var info: RichTextLabel
var btn_go: Button
var msg: RichTextLabel
var dyn: VBoxContainer
var picked_cls := "priest"
# Browsing survives refreshes; reading a talent never changes the hero's build.
var talent_previews: Dictionary = {}
var talent_preview_panel: RichTextLabel
var talent_choose_button: Button
var class_description: RichTextLabel
var skill_description: RichTextLabel
var skill_choose_button: Button
var skill_previews: Dictionary = {}
var skill_buttons: Dictionary = {}
var recruit_buttons: Dictionary = {}
var class_buttons: Dictionary = {}
var formation_cards: Array = []
var move_source := ""
var drop_target := -1
var formation_hint: Label
var cancel_move_button: Button


class FormationCard extends Button:
	var ui
	var slot_index := -1
	var cls := ""

	func _ready() -> void:
		mouse_entered.connect(func():
			if ui.game.can_edit() and not ui.move_source.is_empty() and slot_index < ui.game.slots():
				ui.set_formation_destination(slot_index))
		mouse_exited.connect(func():
			if is_instance_valid(ui) and ui.drop_target == slot_index: ui.set_formation_destination(-1))

	func _get_drag_data(_at_position: Vector2):
		if not ui.game.can_edit() or cls.is_empty(): return null
		ui.begin_formation_drag(cls)
		var preview := Label.new()
		preview.text = DB.classes[cls]["name"] + "  →"
		preview.add_theme_font_size_override("font_size", 19)
		preview.add_theme_color_override("font_color", GOLD)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_drag_preview(preview)
		return {"kind": "party_hero", "owner": ui.get_instance_id(), "cls": cls}

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		var accepted: bool = data is Dictionary and data.get("kind") == "party_hero" and data.get("owner") == ui.get_instance_id()
		accepted = accepted and ui.game.can_edit() and slot_index >= 0 and slot_index < ui.game.slots()
		if accepted:
			accepted = data.get("cls", "") in ui.game.party_ids and not ui.game.party_ids.is_empty()
		if accepted: ui.set_formation_destination(slot_index)
		return accepted

	func _drop_data(_at_position: Vector2, data) -> void:
		if _can_drop_data(Vector2.ZERO, data): ui.drop_formation(str(data["cls"]), slot_index)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and is_instance_valid(ui): ui.finish_formation_drag()

	func _draw() -> void:
		if is_instance_valid(ui) and ui.drop_target == slot_index:
			draw_rect(Rect2(-3, 0, 3, size.y), Color("9cdbcf"))


class MapView extends Control:
	var ui

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for dungeon in DB.dungeons:
				if (_pos(dungeon) - event.position).length() < 20.0:
					ui.pick_dungeon(dungeon["id"])
					return

	func _pos(dungeon: Dictionary) -> Vector2:
		return Vector2(40 + dungeon["pos"][0] * (size.x - 80), 30 + dungeon["pos"][1] * (size.y - 80))

	func _get_tooltip(at_position: Vector2) -> String:
		for index in DB.dungeons.size():
			var dungeon: Dictionary = DB.dungeons[index]
			if (_pos(dungeon) - at_position).length() < 20.0:
				return "%d · %s\nУровни врагов: %d–%d" % [index + 1, dungeon["name"], dungeon["level_min"], dungeon["level_max"]]
		return ""

	func _draw() -> void:
		var g = ui.game
		var font := get_theme_default_font()
		var lesson: Dictionary = g.tutorial_state()
		draw_rect(Rect2(Vector2.ZERO, size), Color("1b1d20"))
		for k in range(1, DB.dungeons.size()):
			var a := _pos(DB.dungeons[k - 1])
			var b := _pos(DB.dungeons[k])
			var open: bool = g.dungeon_open(DB.dungeons[k]["id"])
			var color := Color("95815a") if open else Color("3d3b3c")
			var count := maxi(1, int((b - a).length() / 9.0))
			for i in count:
				if i % 2 == 0:
					draw_line(a.lerp(b, float(i) / count), a.lerp(b, float(i + 1) / count), color, 2.0)
		for index in DB.dungeons.size():
			var dungeon: Dictionary = DB.dungeons[index]
			var p := _pos(dungeon)
			var open: bool = g.dungeon_open(dungeon["id"])
			var done: bool = g.cleared.has(dungeon["id"])
			var color := Color(dungeon["color"]) if open else Color("514c4a")
			if dungeon["id"] == g.selected_dungeon:
				draw_circle(p, 22, Color(0.9, 0.77, 0.46, 0.20))
				draw_arc(p, 20, 0, TAU, 24, GOLD, 2)
			if lesson.get("action") == "dungeon" and lesson.get("dungeon") == dungeon["id"]:
				draw_circle(p, 25, Color(0.75, 0.95, 0.85, 0.17))
				draw_arc(p, 24, 0, TAU, 32, Color("b4ead3"), 3)
			draw_circle(p, 15, Color("111216"))
			draw_circle(p, 13, color.darkened(0.35))
			if done: draw_arc(p, 16, 0, TAU, 24, Color("95bb8c"), 2)
			draw_string(font, p + Vector2(-13, 5), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 14, PARCH if open else MUTED)
			var level_min := int(dungeon.get("level_min", dungeon["power"]))
			var level_max := int(dungeon.get("level_max", int(dungeon["power"]) + int(dungeon["floors"]) - 1))
			var levels := "ур. %d–%d" % [level_min, level_max]
			draw_string_outline(font, p + Vector2(-48, 35), levels, HORIZONTAL_ALIGNMENT_CENTER, 96, 13, 3, Color("111216"))
			draw_string(font, p + Vector2(-48, 35), levels, HORIZONTAL_ALIGNMENT_CENTER, 96, 13, PARCH if open else MUTED)
		draw_rect(Rect2(Vector2.ZERO, size), GOLD_DIM, false, 1)


func _init() -> void:
	custom_minimum_size = Vector2(1120, 1000)
	size = custom_minimum_size


func _ready() -> void:
	var compact := game.dashboard.theme.duplicate() as Theme
	compact.default_font_size = 14
	for kind in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := get_theme_stylebox(state, kind).duplicate() as StyleBoxFlat
			if style != null:
				style.set_content_margin_all(6)
				compact.set_stylebox(state, kind, style)
	theme = compact
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label_at(Vector2(14, 14), "Маршрут экспедиции", 19)
	map_view = MapView.new()
	map_view.ui = self
	map_view.position = MAP.position
	map_view.size = MAP.size
	map_view.clip_contents = true
	add_child(map_view)
	info = RichTextLabel.new()
	info.position = Vector2(14, 450)
	info.size = Vector2(482, 300)
	info.bbcode_enabled = true
	info.scroll_active = false
	info.add_theme_font_size_override("normal_font_size", 15)
	add_child(info)
	btn_go = _button_at(Vector2(14, 388), Vector2(230, 44), "В поход", func():
		var error: String = game.start_run()
		_msg(error if error != "" else "Отряд ушёл в поход")
		if error == "" and game.dashboard != null: game.dashboard.select_page("battle")
		refresh())
	_button_at(Vector2(254, 388), Vector2(242, 44), "Починить снаряжение", func():
		_msg(game.repair_all())
		refresh())
	msg = RichTextLabel.new()
	msg.position = Vector2(14, 766)
	msg.size = Vector2(482, 76)
	msg.bbcode_enabled = true
	msg.scroll_active = false
	msg.add_theme_font_size_override("normal_font_size", 15)
	add_child(msg)
	var rules := RichTextLabel.new()
	rules.position = Vector2(14, 860)
	rules.size = Vector2(482, 130)
	rules.bbcode_enabled = true
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 15)
	rules.text = "[b]Перед выходом[/b]\n№1 ближе всех к врагу. Строй, базовые умения и сочетания героев выбираешь сам. Добычу надеваешь вручную; подготовка доступна только в лагере."
	add_child(rules)
	dyn = VBoxContainer.new()
	dyn.position = Vector2(520, 14)
	dyn.size = Vector2(586, 0)
	dyn.custom_minimum_size.x = 586
	dyn.add_theme_constant_override("separation", 12)
	add_child(dyn)


func open() -> void:
	show()
	refresh()


func pick_dungeon(id: String) -> void:
	if game.mode == "camp":
		game.selected_dungeon = id
		game._recalc()
		game._refresh_ui()
	refresh()


func _msg(text: String) -> void:
	msg.text = text


func refresh() -> void:
	if not visible or dyn == null: return
	map_view.queue_redraw()
	var dungeon: Dictionary = DB.dungeon(game.selected_dungeon)
	var types: Array = []
	for type in dungeon["dmg_types"]:
		types.append("%s %d%%" % [DB.TYPE_NAMES[type], int(float(dungeon["dmg_types"][type]) * 100)])
	var unlocks: Array = []
	if dungeon["unlocks"].has("slots"):
		unlocks.append("мест в отряде: %d" % int(dungeon["unlocks"]["slots"]))
	for cls in dungeon["unlocks"].get("classes", []):
		unlocks.append("класс «%s»" % DB.classes[cls]["name"])
	var level_min := int(dungeon.get("level_min", dungeon["power"]))
	var level_max := int(dungeon.get("level_max", int(dungeon["power"]) + int(dungeon["floors"]) - 1))
	var lines: Array = [
		"[color=#d9b977][b]%s[/b][/color]" % dungeon["name"],
		"Уровни врагов: %d–%d  ·  Этажей: %d" % [level_min, level_max, dungeon["floors"]],
		"Входящий урон: %s" % ", ".join(types),
		"Босс: %s" % dungeon["boss"],
	]
	if dungeon.has("xp_cap"):
		lines.append("Опыт до %d уровня; после — только добыча." % int(dungeon["xp_cap"]))
	var loot_hint := str(dungeon.get("loot_hint", "Боссы дают снаряжение; обычные враги могут оставить добычу."))
	lines.append("Добыча: %s" % loot_hint)
	if not unlocks.is_empty(): lines.append("Откроется после победы: %s" % ", ".join(unlocks))
	if game.cleared.has(dungeon["id"]):
		lines.append("[color=#95bb8c]Пройдено: %d[/color]" % int(game.cleared[dungeon["id"]]))
	elif not game.dungeon_open(dungeon["id"]):
		var required := str(dungeon.get("requires", ""))
		lines.append("[color=#e1918b]Сначала пройди «%s».[/color]" % DB.dungeon(required)["name"])
	info.text = "\n".join(lines)
	var pending_skills: bool = game.heroes.any(func(hero): return not DB.skill_selected(hero))
	btn_go.disabled = game.mode != "camp" or not game.dungeon_open(dungeon["id"]) or game.heroes.is_empty() or pending_skills
	btn_go.text = "Сначала собери отряд" if game.heroes.is_empty() else ("Выбери умения" if pending_skills else ("В поход" if game.mode == "camp" else "Отряд в походе"))
	_build_party()
	call_deferred("_fit_height")


func _fit_height() -> void:
	custom_minimum_size.y = maxf(1000.0, dyn.position.y + dyn.get_combined_minimum_size().y + 20.0)


func _build_party() -> void:
	for child in dyn.get_children():
		dyn.remove_child(child)
		child.queue_free()
	var editable: bool = game.can_edit()
	var slots: int = game.slots()
	_text(dyn, "Твой отряд · %d / %d" % [game.heroes.size(), slots], 19, GOLD)
	_text(dyn, "Карточки: перетащи или выбери героя, затем нужное место.", 14, MUTED)
	var formation := HBoxContainer.new()
	formation.add_theme_constant_override("separation", 8)
	dyn.add_child(formation)
	formation_cards.clear()
	for i in 4:
		var hero: Dictionary = game.heroes[i] if i < game.heroes.size() else {}
		var title := "%d · Свободно" % [i + 1]
		if i >= slots: title = "%d · Закрыто" % [i + 1]
		if not hero.is_empty():
			title = "%d · %s\n%s" % [i + 1, DB.classes[hero["cls"]]["name"], DB.ROLE_NAMES[DB.role(hero)]]
		var card := FormationCard.new()
		card.ui = self
		card.slot_index = i
		card.cls = str(hero.get("cls", ""))
		card.text = title
		card.custom_minimum_size = Vector2(136, 64)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_size_override("font_size", 13)
		card.disabled = i >= slots
		card.tooltip_text = "Нажми для чтения и переноса, затем нажми нужную позицию. Можно перетащить мышью." if not hero.is_empty() else "Место в отряде"
		if i >= slots: card.tooltip_text = game.unlock_source("slot", i + 1)
		card.pressed.connect(func(): formation_click(i))
		formation.add_child(card)
		formation_cards.append(card)
	var instruction := HBoxContainer.new()
	dyn.add_child(instruction)
	formation_hint = _text(instruction, "№1 ближе к врагу. Порядок сохраняется после похода.", 13, MUTED)
	cancel_move_button = _button(instruction, "Отменить · Esc", cancel_formation_move)
	cancel_move_button.add_theme_font_size_override("font_size", 12)
	_update_formation_styles()
	recruit_buttons.clear()
	class_buttons.clear()
	var class_grid := GridContainer.new()
	class_grid.columns = 2
	class_grid.add_theme_constant_override("h_separation", 12)
	class_grid.add_theme_constant_override("v_separation", 8)
	dyn.add_child(class_grid)
	var selectable: Array = []
	# Recommend the healer first without recruiting or sorting the party for the player.
	for cls in ["priest", "warrior", "mage", "hunter", "paladin", "warlock", "shaman"]:
		if DB.classes.has(cls) and game.class_unlocked(cls): selectable.append(cls)
	if not selectable.has(picked_cls) and not selectable.is_empty(): picked_cls = selectable[0]
	for cls in selectable:
		var hero: Dictionary = game.roster[cls]
		var in_party: bool = cls in game.party_ids
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		class_grid.add_child(row)
		var read := _button(row, "%s · %d ур." % [DB.classes[cls]["name"], hero["lvl"]], func():
			picked_cls = cls
			refresh())
		read.custom_minimum_size.x = 180
		read.toggle_mode = true
		read.button_pressed = cls == picked_cls
		class_buttons[cls] = read
		var take := _button(row, "Убрать" if in_party else "Взять", func():
			_msg(game.set_in_party(cls, not in_party))
			refresh())
		take.custom_minimum_size.x = 90
		recruit_buttons[cls] = take
		take.disabled = not editable or (not in_party and game.party_ids.size() >= slots)
		if in_party: take.add_theme_color_override("font_color", Color("95bb8c"))
	if game.roster.has(picked_cls): _build_hero(game.roster[picked_cls], editable)


func _build_hero(hero: Dictionary, editable: bool) -> void:
	var cls: Dictionary = DB.classes[hero["cls"]]
	var description := _card(dyn)
	_text(description, "%s · %s · %d ур." % [cls["name"], DB.ROLE_NAMES[DB.role(hero)], hero["lvl"]], 18, GOLD)
	class_description = _rich(description, str(cls.get("desc", DB.spec(hero)["desc"])), 15)
	_text(description, "Поддержка: %s" % cls["buff"]["name"], 15, GOLD)
	_rich(description, str(cls["buff"]["desc"]), 14)
	var specs := HBoxContainer.new()
	specs.add_theme_constant_override("separation", 8)
	dyn.add_child(specs)
	for spec_id in cls["specs"]:
		var spec: Dictionary = cls["specs"][spec_id]
		var b := _button(specs, "%s\n%s" % [spec["name"], DB.ROLE_NAMES[spec["role"]]], func():
			_msg(game.set_spec(hero["cls"], spec_id))
			refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = hero["spec"] == spec_id
		b.disabled = not editable
		b.tooltip_text = spec["desc"]
	_rich(dyn, DB.spec(hero)["desc"], 15)
	_build_skills(hero, editable)
	_build_talents(hero, editable)
	if hero["cls"] == "shaman": _build_illusion(hero, editable)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not move_source.is_empty():
		cancel_formation_move()
		get_viewport().set_input_as_handled()


func formation_click(position_i: int) -> void:
	if position_i < 0 or position_i >= game.slots(): return
	var hero: Dictionary = game.heroes[position_i] if position_i < game.heroes.size() else {}
	if not game.can_edit():
		if not hero.is_empty(): picked_cls = hero["cls"]
		cancel_formation_move()
		_msg("В походе можно читать описания. Строй меняется в лагере.")
		refresh()
		return
	if not move_source.is_empty():
		if hero.get("cls", "") == move_source:
			cancel_formation_move()
		else:
			drop_formation(move_source, position_i)
		return
	if not hero.is_empty():
		move_source = hero["cls"]
		picked_cls = move_source
		drop_target = -1
		refresh()


func begin_formation_drag(cls: String) -> void:
	if not game.can_edit() or not cls in game.party_ids: return
	move_source = cls
	picked_cls = cls
	drop_target = -1
	_update_formation_styles()


func set_formation_destination(position_i: int) -> void:
	drop_target = position_i
	_update_formation_styles()


func drop_formation(cls: String, position_i: int) -> void:
	if not game.can_edit(): return
	var target := clampi(position_i, 0, game.party_ids.size() - 1)
	move_source = ""
	drop_target = -1
	picked_cls = cls
	var error: String = game.move_in_party(cls, target)
	_msg(error if not error.is_empty() else "%s теперь на позиции %d." % [DB.classes[cls]["name"], target + 1])
	refresh()


func finish_formation_drag() -> void:
	if move_source.is_empty() and drop_target < 0: return
	move_source = ""
	drop_target = -1
	_update_formation_styles()
	# Rebuild only after the engine has finished the drag operation.
	call_deferred("refresh")


func cancel_formation_move() -> void:
	move_source = ""
	drop_target = -1
	_update_formation_styles()


func _update_formation_styles() -> void:
	for card in formation_cards:
		if not is_instance_valid(card): continue
		var selected: bool = card.cls == move_source and not move_source.is_empty()
		var destination: bool = card.slot_index == drop_target
		var fill := Color("334644") if destination else (Color("423924") if selected else Color("232329"))
		var border := Color("9cdbcf") if destination else (GOLD if selected else Color("423a30"))
		var style: StyleBoxFlat = game.dashboard.box(fill, border, 5)
		style.set_border_width_all(2 if selected or destination else 1)
		for state in ["normal", "hover", "pressed"]: card.add_theme_stylebox_override(state, style)
		card.queue_redraw()
	if is_instance_valid(formation_hint):
		formation_hint.text = "%s: нажми место для вставки или перетащи карточку." % DB.classes[move_source]["name"] if not move_source.is_empty() else "№1 ближе к врагу. Порядок сохраняется после похода."
	if is_instance_valid(cancel_move_button): cancel_move_button.visible = not move_source.is_empty()


func preview_skill(cls: String, id: String) -> void:
	skill_previews[_preview_key(game.roster[cls])] = id
	refresh()


func _build_skills(hero: Dictionary, editable: bool) -> void:
	var options: Array = DB.skill_options(hero)
	if options.is_empty(): return
	_text(dyn, "Базовое умение · выбор с 1 уровня", 17, GOLD)
	var key := _preview_key(hero)
	var preview_id := str(skill_previews.get(key, hero.get("skill_id", "")))
	var preview: Dictionary = options[0]
	for option in options:
		if str(option["id"]) == preview_id: preview = option
	skill_previews[key] = str(preview["id"])
	skill_buttons.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	dyn.add_child(row)
	for option in options:
		var id := str(option["id"])
		var selected: bool = str(hero.get("skill_id", "")) == id and DB.skill_selected(hero)
		var b := _button(row, ("✓ " if selected else "") + str(option["name"]), func(): preview_skill(hero["cls"], id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = id == str(preview["id"])
		b.add_theme_font_size_override("font_size", 14)
		skill_buttons[id] = b
	var panel := _card(dyn)
	_text(panel, str(preview["name"]), 17, GOLD)
	skill_description = _rich(panel, str(preview["desc"]), 15)
	var chosen: bool = str(hero.get("skill_id", "")) == str(preview["id"]) and DB.skill_selected(hero)
	_text(panel, "Умение выбрано. Таланты 5/10/15 уровня — отдельные решения." if chosen else "Перед первым походом выбери одно базовое умение для этого героя.", 14, MUTED)
	skill_choose_button = _button(panel, "Умение выбрано" if chosen else "Выбрать умение", func():
		_msg(game.set_skill(hero["cls"], str(preview["id"])))
		refresh())
	skill_choose_button.disabled = not editable or chosen


func tutorial_controls(state: Dictionary) -> Array:
	var action := str(state.get("action", ""))
	var cls := str(state.get("cls", ""))
	var controls: Array = []
	if action == "recruit":
		if not cls.is_empty() and recruit_buttons.has(cls):
			controls.append(recruit_buttons[cls])
		else:
			for id in recruit_buttons:
				if not id in game.party_ids and not recruit_buttons[id].disabled: controls.append(recruit_buttons[id])
	elif action == "skill":
		if cls == picked_cls and is_instance_valid(skill_choose_button): controls.append(skill_choose_button)
		elif class_buttons.has(cls): controls.append(class_buttons[cls])
	elif action == "start": controls.append(btn_go)
	elif action == "dungeon": controls.append(map_view)
	elif action == "formation":
		if move_source.is_empty():
			for card in formation_cards:
				if card.cls == cls: controls.append(card)
			if controls.is_empty() and not formation_cards.is_empty(): controls.append(formation_cards[0])
		else:
			var destination: int = game.heroes.size() - 1 if move_source == "priest" else 0
			if destination >= 0 and destination < formation_cards.size(): controls.append(formation_cards[destination])
	return controls


func _preview_key(hero: Dictionary) -> String:
	return str(hero["cls"]) + ":" + str(hero["spec"])


func preview_talent(cls: String, level: int, option: int) -> void:
	var hero: Dictionary = game.roster[cls]
	talent_previews[_preview_key(hero)] = {"level": level, "option": option}
	refresh()


func _build_talents(hero: Dictionary, editable: bool) -> void:
	_text(dyn, "Таланты · сначала прочитай, затем выбери", 17, GOLD)
	var tiers: Array = DB.talent_tiers(hero)
	if tiers.is_empty(): return
	var key := _preview_key(hero)
	if not talent_previews.has(key):
		var first: Dictionary = tiers[0]
		talent_previews[key] = {"level": int(first["lvl"]), "option": int(hero["talents"].get(str(int(first["lvl"])), 0))}
	var preview: Dictionary = talent_previews[key]
	var preview_tier: Dictionary = tiers[0]
	for tier in tiers:
		if int(tier["lvl"]) == int(preview["level"]): preview_tier = tier
	var level := int(preview_tier["lvl"])
	var option_i := clampi(int(preview["option"]), 0, preview_tier["options"].size() - 1)
	var option: Dictionary = preview_tier["options"][option_i]
	var unlocked := int(hero["lvl"]) >= level
	var selected: bool = int(hero["talents"].get(str(level), -1)) == option_i
	var panel := _card(dyn)
	_text(panel, str(option["name"]), 17, GOLD)
	talent_preview_panel = _rich(panel, str(option["desc"]), 15)
	var state := "Уже выбран в этом ярусе." if selected else "Чтение не меняет билд. Можно выбрать один талант в ярусе."
	if not unlocked: state = "Откроется на %d уровне. Сейчас у героя %d уровень." % [level, hero["lvl"]]
	_text(panel, state, 14, Color("95bb8c") if selected else MUTED)
	talent_choose_button = _button(panel, "Выбран" if selected else ("Выбрать" if unlocked else "Нужен %d уровень" % level), func():
		_msg(game.set_talent(hero["cls"], level, option_i))
		refresh())
	talent_choose_button.disabled = not editable or not unlocked or selected
	for tier in tiers:
		var tier_level := int(tier["lvl"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		dyn.add_child(row)
		var tier_open := int(hero["lvl"]) >= tier_level
		var title := _text(row, "%d ур." % tier_level, 14, GOLD if tier_open else MUTED)
		title.custom_minimum_size.x = 54
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		for oi in tier["options"].size():
			var opt: Dictionary = tier["options"][oi]
			var chosen: bool = int(hero["talents"].get(str(tier_level), -1)) == oi
			var b := _button(row, ("✓ " if chosen else "") + str(opt["name"]), func(): preview_talent(hero["cls"], tier_level, oi))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.toggle_mode = true
			b.button_pressed = level == tier_level and option_i == oi
			b.add_theme_font_size_override("font_size", 13)
			b.tooltip_text = "Открыть описание. Выбор — отдельной кнопкой." + ("" if tier_open else " Откроется на %d уровне." % tier_level)
			if not tier_open: b.add_theme_color_override("font_color", MUTED)


func _build_illusion(hero: Dictionary, editable: bool) -> void:
	_text(dyn, "Иллюзия копирует поддержку:", 15, GOLD)
	var ob := OptionButton.new()
	ob.add_item("Первого героя в отряде")
	var ids: Array = [""]
	for cls in DB.classes:
		if cls != "shaman":
			ob.add_item(DB.classes[cls]["buff"]["name"])
			ids.append(cls)
	ob.select(maxi(0, ids.find(hero.get("illusion", ""))))
	ob.disabled = not editable
	ob.item_selected.connect(func(index):
		game.set_illusion(ids[index])
		refresh())
	dyn.add_child(ob)


func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", game.dashboard.box(Color("1b1e24"), GOLD_DIM, 5))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content


func _text(parent: Node, text: String, font_size: int = 15, color: Color = PARCH) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _rich(parent: Node, text: String, font_size: int = 15) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = text
	rich.fit_content = true
	rich.scroll_active = false
	rich.add_theme_font_size_override("normal_font_size", font_size)
	parent.add_child(rich)
	return rich


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 34
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _button_at(pos: Vector2, dimensions: Vector2, text: String, callback: Callable) -> Button:
	var b := _button(self, text, callback)
	b.position = pos
	b.size = dimensions
	return b


func _label_at(pos: Vector2, text: String, font_size: int) -> Label:
	var label := _text(self, text, font_size, GOLD)
	label.position = pos
	label.size.x = 482
	return label
