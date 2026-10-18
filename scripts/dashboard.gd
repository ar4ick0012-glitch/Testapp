extends Control
## Основной интерфейс: навигация и контейнеры, бой и счётчики обновляются без пересоздания кнопок.

const GOLD := Color("d9b977")
const TEXT := Color("e4dfd3")
const MUTED := Color("948c80")
const LINE := Color("423a30")
const PANEL := Color("191b20")
var game
var pages: Dictionary = {}
var nav: Dictionary = {}
var active_page := "camp"
var header_info: Label
var status: Label
var go_button: Button
var repeat_box: CheckBox
var dungeon_label: Label
var encounter_label: Label
var enemy_bar: ProgressBar
var hero_cards: Array = []
var battle_meter: VBoxContainer
var full_meter: VBoxContainer
var log_label: RichTextLabel
var camp_view: Control
var gear_view: Control
var arena: Control
var meter_kind := "dmg"
var meter_buttons: Dictionary = {}
var elapsed := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var th := Theme.new()
	th.default_font_size = 15
	th.set_color("font_color", "Label", TEXT)
	th.set_color("default_color", "RichTextLabel", TEXT)
	for kind in ["Button", "OptionButton"]:
		th.set_stylebox("normal", kind, box(Color("232329"), LINE, 6))
		th.set_stylebox("hover", kind, box(Color("333039"), GOLD, 6))
		th.set_stylebox("pressed", kind, box(Color("403526"), GOLD, 6))
		th.set_stylebox("disabled", kind, box(Color("17181d"), Color("2b2b30"), 6))
		th.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), GOLD, 6))
		th.set_color("font_color", kind, TEXT)
		th.set_color("font_disabled_color", kind, MUTED)
	th.set_color("font_color", "CheckBox", TEXT)
	theme = th
	var bg := ColorRect.new()
	bg.color = Color("101216")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	label(brand, "IDLE DUNGEON", 26, GOLD)
	label(brand, "Собери отряд. Найди свой билд. Переживи следующий поход.", 13, MUTED)
	header_info = label(header, "", 15, GOLD)
	header_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	var names := {"camp": "01   Лагерь", "gear": "02   Снаряжение и крафт", "battle": "03   Бой", "details": "04   Аналитика"}
	for key in names:
		var b := button(tabs, names[key], func(): select_page(key))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		nav[key] = b
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	for key in names:
		var page := VBoxContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 12)
		content.add_child(page)
		pages[key] = page
	_make_camp()
	_make_gear()
	_make_battle()
	_make_details()
	status = label(root, "", 13, MUTED)
	select_page("camp")


static func box(fill: Color, border: Color, radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s


static func label(parent: Node, text: String, font_size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func panel(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PANEL, LINE, 6))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _embedded(parent: Node, view: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(view)


func _make_camp() -> void:
	camp_view = preload("res://scripts/ui_camp.gd").new()
	camp_view.game = game
	_embedded(pages.camp, camp_view)


func _make_gear() -> void:
	gear_view = preload("res://scripts/ui_gear.gd").new()
	gear_view.game = game
	_embedded(pages.gear, gear_view)


func _make_battle() -> void:
	var page: VBoxContainer = pages.battle
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(name_box)
	dungeon_label = label(name_box, "", 22, GOLD)
	encounter_label = label(name_box, "", 13, MUTED)
	repeat_box = CheckBox.new()
	repeat_box.text = "Повторять данж"
	repeat_box.tooltip_text = "Повторяет выбранный поход. Не меняет вещи и не тратит золото на починку. Два вайпа подряд останавливают повтор."
	repeat_box.toggled.connect(func(on): game.repeat_run = on)
	actions.add_child(repeat_box)
	go_button = button(actions, "В поход", func():
		if game.mode == "run":
			game.retreat()
		else:
			var err: String = game.start_run()
			if err != "": game._log(err)
		refresh())
	go_button.custom_minimum_size.x = 170
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var arena_box := panel(row)
	arena_box.get_parent().size_flags_stretch_ratio = 2.4
	enemy_bar = ProgressBar.new()
	enemy_bar.custom_minimum_size.y = 24
	enemy_bar.show_percentage = false
	enemy_bar.add_theme_stylebox_override("background", box(Color("251c21"), Color("573038"), 3))
	enemy_bar.add_theme_stylebox_override("fill", box(Color("a64447"), Color("bc5a54"), 3))
	arena_box.add_child(enemy_bar)
	arena = preload("res://scripts/battle_view.gd").new()
	arena.game = game
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size = Vector2(560, 230)
	arena_box.add_child(arena)
	label(arena_box, "Бой идёт сам. Снаряжение, таланты и отряд меняются в лагере.", 12, MUTED)
	var side := panel(row)
	side.get_parent().custom_minimum_size.x = 340
	label(side, "DETAILS  /  ТЕКУЩИЙ ПОХОД", 15, GOLD)
	battle_meter = VBoxContainer.new()
	battle_meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(battle_meter)
	button(side, "Открыть полную аналитику", func(): select_page("details"))
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	page.add_child(hero_row)
	for i in 4:
		var card := panel(hero_row)
		card.get_parent().size_flags_vertical = Control.SIZE_SHRINK_END
		var title := label(card, "", 15)
		var hp := ProgressBar.new()
		hp.custom_minimum_size.y = 22
		hp.show_percentage = false
		hp.add_theme_stylebox_override("background", box(Color("2c2025"), Color("4b3035"), 3))
		hp.add_theme_stylebox_override("fill", box(Color("793a43"), Color("a65456"), 3))
		card.add_child(hp)
		var hp_text := label(card, "", 12)
		var mana := label(card, "", 12, Color("8fabdd"))
		hero_cards.append({"root": card.get_parent(), "title": title, "bar": hp, "hp": hp_text, "mana": mana})


func _make_details() -> void:
	var page: VBoxContainer = pages.details
	var top := HBoxContainer.new()
	page.add_child(top)
	label(top, "Аналитика похода", 22, GOLD)
	for pair in [["dmg", "Урон"], ["heal", "Лечение"], ["taken", "Получено"], ["deaths", "Смерти"]]:
		var b := button(top, pair[1], func():
			meter_kind = pair[0]
			_update_meter(full_meter, meter_kind))
		b.toggle_mode = true
		meter_buttons[pair[0]] = b
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	page.add_child(row)
	var meter_panel := panel(row)
	label(meter_panel, "ГЕРОЙ  /  ВСЕГО  /  В СЕКУНДУ  /  ДОЛЯ", 13, MUTED)
	full_meter = VBoxContainer.new()
	full_meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_panel.add_child(full_meter)
	label(meter_panel, "DPS и HPS считаются по времени всего похода. Смерти показывают источник последнего удара.", 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var log_panel := panel(row)
	label(log_panel, "ЖУРНАЛ СОБЫТИЙ", 15, GOLD)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(log_label)


func select_page(key: String) -> void:
	active_page = key
	for id in pages:
		pages[id].visible = id == key
		nav[id].set_pressed_no_signal(id == key)
	refresh()


func refresh() -> void:
	if status == null:
		return
	header_info.text = "%d золота     ·     Сумка %d / %d" % [game.gold, game.bag.size(), game.BAG_CAP]
	if active_page == "gear": gear_view.refresh()
	if active_page == "camp": camp_view.refresh()
	refresh_live()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.2:
		elapsed = 0.0
		if active_page == "battle": _update_meter(battle_meter, "dmg")
		if active_page == "details": _update_meter(full_meter, meter_kind)


func refresh_live() -> void:
	if status == null or game.heroes.is_empty():
		return
	var d := DB.dungeon(game.run.get("id", game.selected_dungeon) if game.mode == "run" else game.selected_dungeon)
	dungeon_label.text = d["name"]
	go_button.text = "Отступить" if game.mode == "run" else "В поход"
	repeat_box.set_pressed_no_signal(game.repeat_run)
	if game.mode == "run":
		encounter_label.text = "Этаж %d / %d   ·   Встреча %d / %d   ·   %s" % [int(game.run["floor_i"]) + 1, d["floors"], game.run["pack"], game.PACKS_PER_FLOOR + 1, game.enemy.get("name", "")]
	else:
		encounter_label.text = "Лагерь   ·   Подготовь отряд и выбери снаряжение"
	enemy_bar.visible = not game.enemy.is_empty()
	if not game.enemy.is_empty():
		enemy_bar.max_value = game.enemy["max_hp"]
		enemy_bar.value = game.enemy["hp"]
	for i in hero_cards.size():
		var c: Dictionary = hero_cards[i]
		c.root.visible = i < game.heroes.size()
		if i >= game.heroes.size(): continue
		var h: Dictionary = game.heroes[i]
		var s: Dictionary = game.stats[i]
		c.title.text = "%s · %d ур. · %s" % [DB.classes[h["cls"]]["name"], h["lvl"], DB.ROLE_NAMES[DB.role(h)]]
		c.title.add_theme_color_override("font_color", Color(DB.classes[h["cls"]]["color"]).lightened(0.35))
		c.bar.max_value = s["max_life"]
		c.bar.value = h["life"]
		c.hp.text = "Здоровье  %.0f / %.0f" % [h["life"], s["max_life"]]
		c.mana.text = "Мана  %.0f / %.0f" % [h["mana"], s["max_mana"]] if s["max_mana"] > 0 else "Без маны"
	var rc: int = game.repair_cost()
	status.text = "В походе: изменения заблокированы" if game.mode == "run" else "Лагерь: можно менять отряд, таланты и снаряжение"
	if rc > 0: status.text += "     ·     Требуется починка: %d золота" % rc
	if arena != null: arena.queue_redraw()


func _update_meter(parent: VBoxContainer, kind: String) -> void:
	for ch in parent.get_children():
		parent.remove_child(ch)
		ch.queue_free()
	for key in meter_buttons:
		meter_buttons[key].set_pressed_no_signal(key == meter_kind)
	if game.meter.is_empty():
		label(parent, "Отправь отряд в поход.\nЗдесь появятся реальные цифры боя.", 14, MUTED)
		return
	var seconds := maxf(float(game.run.get("t", 0.0)), 1.0)
	if kind == "deaths":
		if game.meter.deaths.is_empty(): label(parent, "Все живы", 16, Color("8ebda0"))
		for event in game.meter.deaths.slice(-8):
			label(parent, "%02d:%02d · %s\n%s — %.2f урона" % [int(event.t) / 60, int(event.t) % 60, event.who, event.by, event.hit], 14, Color("e1918b"))
		return
	var vals: Array = game.meter[kind]
	var total := 0.0
	var top := 1.0
	for value in vals:
		total += value
		top = maxf(top, value)
	var order := range(vals.size())
	order.sort_custom(func(a, b): return vals[a] > vals[b])
	label(parent, "Всего %.2f  ·  %.2f/с" % [total, total / seconds], 16, TEXT)
	for i in order:
		if i >= game.heroes.size(): continue
		var color := Color(DB.classes[game.heroes[i]["cls"]]["color"]).lightened(0.2)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		parent.add_child(row)
		label(row, DB.classes[game.heroes[i]["cls"]]["name"], 15, color)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 12
		bar.show_percentage = false
		bar.max_value = top
		bar.value = vals[i]
		bar.add_theme_stylebox_override("background", box(Color("111318"), Color("111318"), 3))
		bar.add_theme_stylebox_override("fill", box(color.darkened(0.25), color.darkened(0.25), 3))
		row.add_child(bar)
		label(row, "%.2f  ·  %.2f/с  ·  %.1f%%" % [vals[i], vals[i] / seconds, 100.0 * vals[i] / maxf(total, 0.001)], 13, MUTED)
