extends Control
## Окно «Лагерь»: слева карта подземелий с прогрессией, справа сбор отряда, ветки и таланты.
## Всё это меняется только в лагере. В походе окно открывается для просмотра.

var game  # ссылка на game.gd

const GOLD := Color(0.85, 0.72, 0.42)
const GOLD_DIM := Color(0.42, 0.33, 0.18)
const PARCH := Color(0.86, 0.80, 0.66)
const BG := Color(0.055, 0.045, 0.04)
const MAP := Rect2(14, 48, 600, 330)

var map_view: Control
var info: RichTextLabel
var btn_go: Button
var test_box: CheckBox
var msg: RichTextLabel
var dyn: Control              # правая панель, пересобирается при каждом обновлении
var picked_cls := "warrior"   # чей лист талантов открыт


class MapView extends Control:
	var ui

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for d in DB.dungeons:
				if (_pos(d) - e.position).length() < 18.0:
					ui.pick_dungeon(d["id"])
					return

	func _pos(d: Dictionary) -> Vector2:
		return Vector2(30 + d["pos"][0] * (size.x - 60), 30 + d["pos"][1] * (size.y - 60))

	func _draw() -> void:
		var g = ui.game
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.085, 0.065))
		# пятна местности
		for k in 14:
			var p := Vector2(fmod(k * 137.0, size.x), fmod(k * 89.0 + 40.0, size.y))
			draw_circle(p, 40 + (k % 4) * 12, Color(0.13, 0.11, 0.08, 0.6))
		# дороги по порядку прохождения
		for k in range(1, DB.dungeons.size()):
			var a: Vector2 = _pos(DB.dungeons[k - 1])
			var b: Vector2 = _pos(DB.dungeons[k])
			var open: bool = g.dungeon_open(DB.dungeons[k]["id"])
			var col := Color(0.55, 0.42, 0.25) if open else Color(0.25, 0.2, 0.15)
			var n := int((b - a).length() / 9.0)
			for i in n:
				if i % 2 == 0:
					draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 2.0)
		for d in DB.dungeons:
			var p := _pos(d)
			var open: bool = g.dungeon_open(d["id"])
			var done: bool = g.cleared.has(d["id"])
			var col := Color(d["color"]) if open else Color(0.3, 0.27, 0.24)
			if d["id"] == g.selected_dungeon:
				draw_circle(p, 20, Color(1, 0.9, 0.5, 0.25))
			draw_circle(p, 13, Color(0.05, 0.04, 0.03))
			draw_circle(p, 11, col.darkened(0.3))
			draw_circle(p, 7, col)
			if done:
				draw_arc(p, 14, 0, TAU, 24, GOLD, 2.0)
			if not open:
				draw_rect(Rect2(p + Vector2(-4, -2), Vector2(8, 7)), Color(0.15, 0.13, 0.11))
				draw_arc(p + Vector2(0, -3), 3, PI, TAU, 8, Color(0.15, 0.13, 0.11), 2.0)
			var label: String = d["name"]
			var lvl := "сила %d–%d" % [d["power"], int(d["power"]) + int(d["floors"]) - 1]
			var tc := PARCH if open else Color(0.45, 0.4, 0.35)
			draw_string_outline(font, p + Vector2(-70, 28), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, 3, Color.BLACK)
			draw_string(font, p + Vector2(-70, 28), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, tc)
			draw_string(font, p + Vector2(-60, 41), lvl, HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.6, 0.55, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), GOLD_DIM, false, 1.0)


func _init() -> void:
	custom_minimum_size = Vector2(1120, 560)
	size = custom_minimum_size


func _ready() -> void:
	# Встроенным панелям нужны компактные отступы, чтобы кнопки не перекрывались.
	var compact := game.dashboard.theme.duplicate() as Theme
	for kind in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := get_theme_stylebox(state, kind).duplicate() as StyleBoxFlat
			if style != null:
				style.set_content_margin_all(3)
				compact.set_stylebox(state, kind, style)
	theme = compact
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(size)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var deco := Control.new()
	deco.size = Vector2(size)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		for r in [Rect2(8, 40, 612, 512), Rect2(628, 40, 484, 512)]:
			deco.draw_rect(r, Color(0.075, 0.062, 0.052))
			deco.draw_rect(r, GOLD_DIM, false, 1.0))
	add_child(deco)
	_label(Vector2(14, 14), "Карта подземелий")
	test_box = CheckBox.new()
	test_box.text = "Тест: всё открыто"
	test_box.position = Vector2(470, 10)
	test_box.add_theme_font_size_override("font_size", 12)
	test_box.focus_mode = Control.FOCUS_NONE
	test_box.tooltip_text = "Тестовый режим: открыты все данжи, классы и 4 места в отряде.\nВыключи, чтобы проверить прогрессию: 2 места на старте, 3-е и 4-е открываются данжами."
	test_box.toggled.connect(func(on):
		if not game.can_edit(): return
		game.test_mode = on
		game._set_party()
		game._refresh_ui()
		refresh())
	add_child(test_box)
	map_view = MapView.new()
	map_view.ui = self
	map_view.position = MAP.position
	map_view.size = MAP.size
	map_view.clip_contents = true
	add_child(map_view)
	info = _rich(Vector2(18, 386), Vector2(440, 160))
	btn_go = _button(Vector2(470, 390), Vector2(140, 34), "▶ В поход", func():
		var err: String = game.start_run()
		_msg(err if err != "" else "Отряд ушёл в поход")
		if err == "" and game.dashboard != null:
			game.dashboard.select_page("battle")
		refresh())
	_button(Vector2(470, 430), Vector2(140, 28), "Починить всё", func():
		_msg(game.repair_all())
		refresh())
	msg = _rich(Vector2(470, 466), Vector2(146, 80))
	_label(Vector2(634, 14), "Отряд")
	dyn = Control.new()
	dyn.position = Vector2(634, 46)
	dyn.size = Vector2(472, 500)
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
	if not visible:
		return
	test_box.set_pressed_no_signal(game.test_mode)
	test_box.disabled = not game.can_edit()
	map_view.queue_redraw()
	var d: Dictionary = DB.dungeon(game.selected_dungeon)
	var types: Array = []
	for tp in d["dmg_types"]:
		types.append("%s %d%%" % [DB.TYPE_NAMES[tp], int(float(d["dmg_types"][tp]) * 100)])
	var unl: Array = []
	if d["unlocks"].has("slots"):
		unl.append("место в отряде (%d)" % int(d["unlocks"]["slots"]))
	for c in d["unlocks"].get("classes", []):
		unl.append("класс «%s»" % DB.classes[c]["name"])
	var lines: Array = [
		"[color=#d9b86a][b]%s[/b][/color]   сила %d–%d, этажей %d" % [d["name"], d["power"], int(d["power"]) + int(d["floors"]) - 1, d["floors"]],
		"Враги бьют: %s" % ", ".join(types),
		"Босс: %s" % d["boss"],
		"Лут: 1 вещь с босса этажа, сундук из 2 вещей в конце",
	]
	if not unl.is_empty():
		lines.append("Первое прохождение открывает: %s" % ", ".join(unl))
	if game.cleared.has(d["id"]):
		lines.append("[color=#70d070]Пройден %d раз[/color]" % int(game.cleared[d["id"]]))
	elif not game.dungeon_open(d["id"]):
		lines.append("[color=#e06060]Закрыт: сначала пройди «%s»[/color]" % DB.dungeon(d["requires"])["name"])
	info.text = "\n".join(lines)
	btn_go.disabled = game.mode != "camp" or not game.dungeon_open(d["id"])
	btn_go.text = "▶ В поход" if game.mode == "camp" else "В походе…"
	_build_party()


# ================= ОТРЯД И ТАЛАНТЫ =================

func _build_party() -> void:
	for ch in dyn.get_children():
		ch.queue_free()
	var editable: bool = game.can_edit()
	var slots: int = game.slots()
	# места в отряде
	for i in 4:
		var r := Rect2(Vector2(i * 117, 0), Vector2(112, 44))
		var txt := ""
		var col := PARCH
		if i < game.heroes.size():
			var h: Dictionary = game.heroes[i]
			txt = "%s %d\n%s" % [DB.classes[h["cls"]]["name"], h["lvl"], DB.ROLE_NAMES[DB.role(h)]]
		elif i < slots:
			txt = "свободно"
			col = Color(0.6, 0.55, 0.45)
		else:
			txt = "закрыто\n%s" % game.unlock_source("slot", i + 1)
			col = Color(0.5, 0.35, 0.3)
		var b := _dbutton(r.position, r.size, txt, func(): pass)
		b.add_theme_color_override("font_color", col)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = i >= slots
	# список классов
	var y := 54.0
	var k := 0
	for cls in DB.classes:
		var h: Dictionary = game.roster[cls]
		var unlocked: bool = game.class_unlocked(cls)
		var in_party: bool = cls in game.party_ids
		var pos := Vector2((k % 2) * 236, y + (k / 2) * 30)
		var b := _dbutton(pos, Vector2(150, 26), "%s · %d" % [DB.classes[cls]["name"], h["lvl"]], func():
			picked_cls = cls
			refresh())
		b.toggle_mode = true
		b.button_pressed = cls == picked_cls
		b.disabled = not unlocked
		if not unlocked:
			b.tooltip_text = "Откроется в «%s»" % game.unlock_source("class", cls)
		var tog := _dbutton(pos + Vector2(154, 0), Vector2(76, 26), "В отряде" if in_party else "Взять", func():
			_msg(game.set_in_party(cls, not in_party))
			refresh())
		tog.disabled = not unlocked or not editable
		if in_party:
			tog.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		k += 1
	y += ceilf(k / 2.0) * 30 + 8
	_build_hero(game.roster[picked_cls], y, editable)


func _build_hero(h: Dictionary, y: float, editable: bool) -> void:
	var cls: Dictionary = DB.classes[h["cls"]]
	var line := Control.new()
	line.position = Vector2(0, y)
	line.size = Vector2(472, 1)
	line.draw.connect(func(): line.draw_line(Vector2.ZERO, Vector2(472, 0), GOLD_DIM, 1.0))
	dyn.add_child(line)
	y += 6
	# ветки
	var x := 0.0
	for sp_id in cls["specs"]:
		var sp: Dictionary = cls["specs"][sp_id]
		var b := _dbutton(Vector2(x, y), Vector2(150, 26), "%s (%s)" % [sp["name"], DB.ROLE_NAMES[sp["role"]]], func():
			_msg(game.set_spec(h["cls"], sp_id))
			refresh())
		b.toggle_mode = true
		b.button_pressed = h["spec"] == sp_id
		b.disabled = not editable
		b.tooltip_text = sp["desc"]
		x += 156
	y += 32
	var r := _drich(Vector2(0, y), Vector2(472, 54))
	r.text = "%s\n[color=#d9b86a]Баф: %s[/color] — %s" % [DB.spec(h)["desc"], cls["buff"]["name"], cls["buff"]["desc"]]
	y += 58
	# таланты: по одному выбору на ярус
	for tier in DB.talent_tiers(h):
		var lvl := int(tier["lvl"])
		var open_tier: bool = int(h["lvl"]) >= lvl
		var lab := Label.new()
		lab.text = "ур. %d" % lvl
		lab.position = Vector2(0, y + 5)
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", GOLD if open_tier else Color(0.45, 0.4, 0.35))
		dyn.add_child(lab)
		var pick = h["talents"].get(str(lvl))
		for oi in tier["options"].size():
			var opt: Dictionary = tier["options"][oi]
			var b := _dbutton(Vector2(44 + oi * 214, y), Vector2(210, 26), opt["name"], func():
				_msg(game.set_talent(h["cls"], lvl, oi))
				refresh())
			b.toggle_mode = true
			b.button_pressed = pick != null and int(pick) == oi
			b.disabled = not editable or not open_tier
			b.tooltip_text = opt["desc"] + ("" if open_tier else "\nОткроется на %d уровне" % lvl)
			b.add_theme_font_size_override("font_size", 11)
		y += 30
	# иллюзия шамана
	if h["cls"] == "shaman":
		var lab := Label.new()
		lab.text = "Иллюзия копирует:"
		lab.position = Vector2(0, y + 5)
		lab.add_theme_font_size_override("font_size", 11)
		dyn.add_child(lab)
		var ob := OptionButton.new()
		ob.position = Vector2(130, y)
		ob.size = Vector2(200, 26)
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("первого в отряде")
		var ids: Array = [""]
		for c in DB.classes:
			if c != "shaman":
				ob.add_item(DB.classes[c]["buff"]["name"])
				ids.append(c)
		ob.select(maxi(0, ids.find(h.get("illusion", ""))))
		ob.disabled = not editable
		ob.item_selected.connect(func(idx):
			game.set_illusion(ids[idx])
			refresh())
		dyn.add_child(ob)


# ---------- помощники ----------

func _dbutton(pos: Vector2, sz: Vector2, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	dyn.add_child(b)
	return b


func _drich(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.position = pos
	r.size = sz
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 11)
	dyn.add_child(r)
	return r


func _button(pos: Vector2, sz: Vector2, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GOLD)
	add_child(l)
	return l


func _rich(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.position = pos
	r.size = sz
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 12)
	add_child(r)
	return r
