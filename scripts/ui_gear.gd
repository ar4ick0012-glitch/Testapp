extends Control
## Окно «Снаряжение» в духе PoE/Torchlight/WoW:
## слева кукла героя со слотами, в центре сетка сумки, справа крафт.
## ЛКМ = выбрать вещь (цель крафта), ПКМ или двойной клик = надеть / снять.

var game  # ссылка на game.gd

const C := 42.0           # размер ячейки сумки
const GRID_COLS := 10
const GRID_ROWS := 6
const GOLD := Color(0.85, 0.72, 0.42)
const GOLD_DIM := Color(0.42, 0.33, 0.18)
const PARCH := Color(0.86, 0.80, 0.66)
const BG := Color(0.055, 0.045, 0.04)
const INSET := Color(0.03, 0.025, 0.022)

# расположение слотов на кукле: позиция и размер
const DOLL := {
	"helmet":  [Rect2(139, 30, 52, 52)],
	"amulet":  [Rect2(203, 46, 36, 36)],
	"weapon":  [Rect2(30, 92, 56, 112)],
	"armour":  [Rect2(131, 92, 68, 92)],
	"offhand": [Rect2(244, 92, 56, 112)],
	"ring1":   [Rect2(88, 194, 36, 36)],
	"belt":    [Rect2(131, 194, 68, 30)],
	"ring2":   [Rect2(206, 194, 36, 36)],
	"gloves":  [Rect2(30, 214, 56, 56)],
	"boots":   [Rect2(244, 214, 56, 56)],
}

var hero_i := 0
var selected = null           # выбранная вещь (цель крафта)
var currency_id := "ember_attack"

var hero_tabs: Array = []
var doll_cells: Dictionary = {}   # слот -> Cell
var bag_cells: Array = []
var cur_cells: Dictionary = {}
var hero_summary: RichTextLabel
var details: RichTextLabel
var preview: RichTextLabel
var result_label: RichTextLabel
var bag_title: Label
var equip_button: Button
var slot_choice: OptionButton
var details_box: CheckBox
var chosen_slot := ""
var tip_panel: PanelContainer
var tip_text: RichTextLabel
var _last_bag := -1
var btn_repair: Button
var lock_label: Label


# ================= ЯЧЕЙКА =================

class Cell extends Control:
	var ui           # окно
	var item = null
	var slot := ""   # для куклы: ключ слота; для сумки пусто
	var cur_id := "" # для валюты
	var count := 0
	var placeholder := ""
	var selected := false
	var upgrade := false   # стрелка: вещь усилит героя

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): ui.show_tip(self))
		mouse_exited.connect(func(): ui.hide_tip())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				ui.on_cell(self, e.double_click)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				ui.on_cell(self, true)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.025, 0.022))
		var border := Color(0.3, 0.24, 0.15)
		if item != null:
			var rc := Color(DB.RARITY_COLORS[item["rarity"]])
			draw_rect(r.grow(-2), Color(rc.r, rc.g, rc.b, 0.08))
			border = rc.darkened(0.35)
			Icons.draw(self, item["kind"], r.grow(-5), rc)
			if item.get("corrupted", false):
				draw_rect(Rect2(r.end - Vector2(9, 9), Vector2(6, 6)), Color(0.8, 0.15, 0.15))
			var dur := float(item.get("dur", 100.0))
			if dur < 100.0:
				var bw := (r.size.x - 6) * dur / 100.0
				draw_rect(Rect2(3, r.size.y - 5, r.size.x - 6, 2), Color(0.15, 0.05, 0.05))
				draw_rect(Rect2(3, r.size.y - 5, bw, 2), Color(0.9, 0.7, 0.2) if dur > 0.0 else Color(1, 0.1, 0.1))
				if dur <= 0.0:
					draw_rect(r.grow(-2), Color(0.6, 0.0, 0.0, 0.25))
			if upgrade:
				var a := Vector2(9, 5)
				draw_colored_polygon(PackedVector2Array([a + Vector2(0, -2), a + Vector2(6, 5), a + Vector2(-6, 5)]), Color(0.3, 1.0, 0.3))
				draw_rect(Rect2(a + Vector2(-2, 5), Vector2(4, 5)), Color(0.3, 1.0, 0.3))
		elif cur_id != "":
			Icons.currency(self, cur_id, r.grow(-8))
			var font := get_theme_default_font()
			var n := str(count)
			draw_string_outline(font, Vector2(r.end.x - 3, r.end.y - 3), n, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, 3, Color.BLACK)
			draw_string(font, Vector2(r.end.x - 3, r.end.y - 3), n, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, PARCH if count > 0 else Color(0.5, 0.45, 0.4))
		elif placeholder != "":
			Icons.draw(self, placeholder, r.grow(-8), Color(0.25, 0.21, 0.16))
		draw_rect(r.grow(-0.5), border, false, 1.0)
		if selected:
			draw_rect(r.grow(-1.5), GOLD, false, 2.0)


# ================= ПОСТРОЕНИЕ =================

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
	DB.ensure()
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(size)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var deco := Control.new()  # рамки панелей рисуем отдельным слоем
	deco.size = Vector2(size)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func(): _draw_panels(deco))
	add_child(deco)

	# --- вкладки героев ---
	for i in 4:
		var b := _button(Vector2(14 + i * 84, 10), Vector2(80, 28), "", func(): _select_hero(i))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 11)
		hero_tabs.append(b)
	equip_button = _button(Vector2(356, 10), Vector2(144, 28), "Надеть выбранное", _equip_selected)
	slot_choice = OptionButton.new()
	slot_choice.position = Vector2(506, 10)
	slot_choice.size = Vector2(254, 28)
	slot_choice.add_theme_font_size_override("font_size", 12)
	slot_choice.item_selected.connect(func(index):
		chosen_slot = str(slot_choice.get_item_metadata(index))
		_show_details())
	add_child(slot_choice)
	btn_repair = _button(Vector2(766, 10), Vector2(170, 28), "", _repair)
	lock_label = _label(Vector2(946, 16), "")
	lock_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

	# --- кукла ---
	var doll_origin := Vector2(14, 48)
	for slot in DOLL:
		var r: Rect2 = DOLL[slot][0]
		var c := _cell(doll_origin + r.position, r.size)
		c.slot = slot
		c.placeholder = _placeholder_kind(slot)
		doll_cells[slot] = c
	hero_summary = _rich(Vector2(22, 336), Vector2(314, 214))

	# --- сумка ---
	bag_title = _label(Vector2(356, 48), "Сумка")
	var grid_origin := Vector2(356, 68)
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var c := _cell(grid_origin + Vector2(col, row) * (C + 2), Vector2(C, C))
			bag_cells.append(c)
	var by := grid_origin.y + GRID_ROWS * (C + 2) + 6
	_button(Vector2(356, by), Vector2(140, 26), "Продать выбранное", _sell_selected)
	_button(Vector2(502, by), Vector2(140, 26), "Продать обычные", func(): _sell_where(func(it): return it["rarity"] == "normal"))
	_button(Vector2(648, by), Vector2(144, 26), "Продать всё", func(): _sell_where(func(it): return true))
	details = _rich(Vector2(362, by + 38), Vector2(426, 552 - by - 44))
	details_box = CheckBox.new()
	details_box.text = "Все свойства"
	details_box.position = Vector2(656, 44)
	details_box.add_theme_font_size_override("font_size", 12)
	details_box.toggled.connect(func(_on):
		hide_tip()
		_show_details())
	add_child(details_box)

	# --- крафт ---
	_label(Vector2(810, 48), "Крафт: выбери вещь и валюту")
	var i := 0
	for c in DB.currency:
		var cell := _cell(Vector2(810 + (i % 7) * 43, 70), Vector2(40, 40))
		cell.cur_id = c["id"]
		cur_cells[c["id"]] = cell
		i += 1
	preview = _rich(Vector2(816, 120), Vector2(290, 330))
	_button(Vector2(810, 460), Vector2(146, 30), "Применить", func(): _apply(1))
	_button(Vector2(962, 460), Vector2(146, 30), "Применить ×10", func(): _apply(10))
	result_label = _rich(Vector2(816, 498), Vector2(290, 54))

	# --- всплывающая карточка ---
	tip_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.97)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	tip_panel.add_theme_stylebox_override("panel", sb)
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.custom_minimum_size = Vector2(300, 0)
	tip_text.add_theme_font_size_override("normal_font_size", 12)
	tip_text.add_theme_font_size_override("bold_font_size", 13)
	tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_text)
	add_child(tip_panel)


func _draw_panels(ci: Control) -> void:
	for r in [Rect2(8, 44, 336, 510), Rect2(350, 44, 448, 510), Rect2(804, 44, 308, 510)]:
		ci.draw_rect(r, Color(0.075, 0.062, 0.052))
		ci.draw_rect(r, GOLD_DIM, false, 1.0)
	# силуэт героя за слотами
	var o := Vector2(14, 48)
	var sil := Color(0.12, 0.1, 0.085)
	ci.draw_circle(o + Vector2(165, 56), 22, sil)
	ci.draw_rect(Rect2(o + Vector2(120, 82), Vector2(90, 120)), sil)
	ci.draw_rect(Rect2(o + Vector2(132, 202), Vector2(28, 80)), sil)
	ci.draw_rect(Rect2(o + Vector2(170, 202), Vector2(28, 80)), sil)
	ci.draw_line(o + Vector2(160, 300), o + Vector2(170, 300), GOLD_DIM, 1.0)
	ci.draw_line(Vector2(22, 328), Vector2(330, 328), GOLD_DIM, 1.0)


func _placeholder_kind(slot: String) -> String:
	if slot == "offhand":
		return "shield"
	match slot:
		"ring1", "ring2":
			return "ring"
		"weapon":
			return "sword"
		"offhand":
			return "shield"
	return slot


# ================= ОБНОВЛЕНИЕ =================

func open() -> void:
	show()
	refresh()



## Зовётся игрой после каждого убийства: всё перерисовываем, только если что-то поменялось
func on_game_update() -> void:
	if game.bag.size() != _last_bag:
		refresh()
	else:
		_refresh_currency()


func refresh() -> void:
	if not visible:
		return
	_last_bag = game.bag.size()
	if game.heroes.is_empty():
		return
	hero_i = mini(hero_i, game.heroes.size() - 1)
	var hero: Dictionary = game.heroes[hero_i]
	var cls: Dictionary = DB.classes[hero["cls"]]
	var sp := DB.spec(hero)
	for i in 4:
		hero_tabs[i].visible = i < game.heroes.size()
		if i < game.heroes.size():
			var h: Dictionary = game.heroes[i]
			hero_tabs[i].text = "%s · %d" % [DB.classes[h["cls"]]["name"], h["lvl"]]
			hero_tabs[i].button_pressed = i == hero_i
	var rc: int = game.repair_cost()
	btn_repair.text = "Починить всё (%d з)" % rc if rc > 0 else "Чинить нечего"
	btn_repair.disabled = rc == 0 or not game.can_edit()
	lock_label.text = "" if game.can_edit() else "В походе: только смотреть"
	for slot in doll_cells:
		var c: Cell = doll_cells[slot]
		c.item = hero["items"].get(slot)
		var weapons: Array = sp.get("weapons", cls["weapons"])
		var offs: Array = sp.get("offhands", cls["offhands"])
		if slot == "weapon":
			c.placeholder = weapons[0]
		elif slot == "offhand":
			c.placeholder = offs[0] if not offs.is_empty() else ("greatsword" if DB.has_talent_flag(hero, "titan_grip") else "")
		c.selected = c.item != null and is_same(c.item, selected)
		c.queue_redraw()
	var items: Array = game.bag.duplicate()
	var rank := {"rare": 0, "magic": 1, "normal": 2}
	items.sort_custom(func(a, b): return [rank[a["rarity"]], a["kind"], -int(a["ilvl"])] < [rank[b["rarity"]], b["kind"], -int(b["ilvl"])])
	for i in bag_cells.size():
		var c: Cell = bag_cells[i]
		c.item = items[i] if i < items.size() else null
		c.selected = c.item != null and is_same(c.item, selected)
		c.upgrade = false
		if c.item != null:
			var comparison: Dictionary = game.compare_item(hero, c.item)
			if not comparison.is_empty():
				for key in ["dps", "survival", "healing"]:
					if comparison["after"][key] > comparison["before"][key] * 1.02:
						c.upgrade = true
		c.queue_redraw()
	bag_title.text = "Сумка  %d / %d" % [game.bag.size(), game.BAG_CAP]
	_refresh_currency()
	hero_summary.text = _summary(hero)
	_refresh_slots()
	_show_details()


func _refresh_currency() -> void:
	for id in cur_cells:
		var c: Cell = cur_cells[id]
		c.count = int(game.wallet.get(id, 0))
		c.selected = id == currency_id
		c.queue_redraw()


func _summary(hero: Dictionary) -> String:
	var s: Dictionary = game.stats[hero_i]
	var target: Dictionary = game.enemy if not game.enemy.is_empty() else game.ref_enemy()
	var o := Calc.offense(hero, s, target)
	var heal_line := ""
	if DB.spec(hero)["skill"].has("heal"):
		heal_line = "\nИсцеление [color=#70ff70]%d[/color] за каст, мана %d" % [Calc.heal(hero, s), s["max_mana"]]
	var res := []
	for t in ["fire", "cold", "lightning", "chaos"]:
		var v: float = s["res_" + t]
		var col := "#70d070" if v >= 75 else ("#e0c060" if v >= 0 else "#e06060")
		res.append("%s [color=%s]%d%%[/color]" % [DB.TYPE_NAMES[t], col, v])
	return "[color=#d9b86a][b]%s[/b][/color]  ур. %d, %s\nDPS по «%s» [color=#ffffff]%d[/color]   удар %d   %.2f/с%s\nКрит %.1f%% × %d%%\nЗдоровье %d   броня %d   −%d%% урона\n%s\n[color=#807060]Штраф глубины: −%d%% к сопр.[/color]" % [
		DB.hero_name(hero), hero["lvl"], DB.ROLE_NAMES[DB.role(hero)], target["name"], o["dps"], o["hit"], o["speed"], heal_line,
		o["crit_chance"], o["crit_multi"], s["max_life"], s.get("armour", 0.0), s.get("less_taken", 0.0),
		"  ".join(res), s["res_penalty"]]


# ================= ДЕЙСТВИЯ =================

func _select_hero(i: int) -> void:
	hero_i = i
	chosen_slot = ""
	hide_tip()
	refresh()


func on_cell(c: Cell, alt: bool) -> void:
	if c.cur_id != "":
		currency_id = c.cur_id
		_refresh_currency()
		_show_details()
		return
	if c.item == null:
		return
	if alt:
		var err: String
		if c.slot != "":
			err = game.unequip(hero_i, c.slot)
		else:
			err = game.equip(hero_i, c.item, chosen_slot if is_same(c.item, selected) else "")
		result_label.text = "[color=#e06060]%s[/color]" % err if err != "" else ""
		hide_tip()
		refresh()
		return
	selected = c.item
	chosen_slot = ""
	hide_tip()
	refresh()


func _refresh_slots() -> void:
	slot_choice.clear()
	equip_button.disabled = true
	slot_choice.disabled = true
	if selected == null or selected not in game.bag or game.heroes.is_empty():
		return
	var hero: Dictionary = game.heroes[hero_i]
	if not DB.can_use(hero, selected):
		return
	chosen_slot = game.equipment_slot(hero, selected, chosen_slot)
	for slot in DB.equip_slots(selected, hero):
		var old = hero["items"].get(slot)
		var name: String = DB.SLOT_NAMES[slot]
		if slot in ["ring1", "ring2"]:
			name += " " + slot.right(1)
		var index := slot_choice.item_count
		slot_choice.add_item("%s: %s" % [name, old["name"] if old != null else "пусто"])
		slot_choice.set_item_metadata(index, slot)
		if slot == chosen_slot:
			slot_choice.select(index)
	slot_choice.disabled = not game.can_edit() or slot_choice.item_count < 2
	equip_button.disabled = not game.can_edit()


func _equip_selected() -> void:
	if selected == null or selected not in game.bag:
		return
	var err: String = game.equip(hero_i, selected, chosen_slot)
	result_label.text = "[color=#e06060]%s[/color]" % err if err != "" else "Предмет надет"
	hide_tip()
	refresh()


func _repair() -> void:
	result_label.text = game.repair_all()
	refresh()


func _sell_selected() -> void:
	if selected != null and selected in game.bag:
		game.sell_item(selected)
		selected = null
		refresh()


func _sell_where(pred: Callable) -> void:
	var sold := 0
	for it in game.bag.duplicate():
		if pred.call(it):
			game.sell_item(it)
			sold += 1
	if selected != null and not (selected in game.bag):
		var still_worn := false
		for h in game.heroes:
			if selected in h["items"].values():
				still_worn = true
		if not still_worn:
			selected = null
	result_label.text = "Продано: %d" % sold
	refresh()


func _apply(times: int) -> void:
	if selected == null:
		result_label.text = "Сначала выбери вещь (ЛКМ)"
		return
	var last := ""
	for i in times:
		last = game.craft(selected, currency_id)
		if Craft.check(selected, currency_id) != "" or int(game.wallet.get(currency_id, 0)) <= 0:
			break
	result_label.text = last
	refresh()


func _show_details() -> void:
	if selected == null:
		details.text = "[color=#807060]Добыча остаётся в сумке. ЛКМ: сравнить вещь и выбрать для крафта.\n«Надеть выбранное», ПКМ или двойной клик: надеть в лагере.\nЗелёная стрелка: есть прирост урона, лечения или защиты; проверь потери.\n«Все свойства»: подробные аффиксы.[/color]"
		preview.text = "[color=#807060]Выбери вещь, затем валюту: здесь появятся шансы.[/color]"
		return
	details.text = item_card(selected, true)
	preview.text = Craft.preview(selected, currency_id)


# ================= КАРТОЧКА ПРЕДМЕТА =================

func item_card(it: Dictionary, with_compare: bool) -> String:
	var col: String = DB.RARITY_COLORS[it["rarity"]]
	var L: Array[String] = []
	L.append("[color=%s][b]%s[/b][/color]" % [col, it["name"]])
	var sub: String = it["base"] if it["rarity"] == "rare" else DB.SLOT_NAMES.get(it["slot"], "")
	L.append("[color=#a09070]%s · %s · ур. предмета %d[/color]" % [sub, DB.RARITY_NAMES[it["rarity"]], it["ilvl"]])
	if with_compare and it in game.bag:
		L.append(_compare(game.heroes[hero_i], it))
	if details_box.button_pressed and not it["implicit"].is_empty():
		L.append("[color=#3a3020]────────────────[/color]")
		for k in it["implicit"]:
			L.append("[color=#8fb0ff]%s[/color]" % DB.stat_text(k, it["implicit"][k]))
	if details_box.button_pressed and not it["mods"].is_empty():
		L.append("[color=#3a3020]────────────────[/color]")
		for m in it["mods"]:
			var d := Items.affix_def(m["id"])
			var tag := "П" if m["type"] == "prefix" else "С"
			var tcol := "#ffd75a" if int(m["tier"]) == 1 else ("#c0c0c0" if int(m["tier"]) <= 2 else "#808080")
			L.append("[color=%s]%s T%d[/color]  %s" % [tcol, tag, m["tier"], (d["text"] as String) % str(m["value"])])
	if it.get("corrupted", false):
		L.append("[color=#d04040]Осквернено[/color]")
	var dur := float(it.get("dur", 100.0))
	if dur <= 0.0:
		L.append("[color=#ff4040]Сломано: статы не работают. Почини в лагере (%d з)[/color]" % Items.repair_cost(it))
	elif dur < 100.0:
		L.append("[color=#c0a060]Прочность %d%%, починка %d з[/color]" % [dur, Items.repair_cost(it)])
	L.append("[color=#807060]Продажа: %d з[/color]" % Items.sell_price(it))
	if not details_box.button_pressed:
		L.append("[color=#807060]Аффиксы: включи «Все свойства»[/color]")
	return "\n".join(L)


func _who_can_use(it: Dictionary) -> String:
	if not (it["slot"] in ["weapon", "offhand"]):
		return ""
	var who: Array = []
	for cls in game.roster:
		var h: Dictionary = game.roster[cls]
		for sp_id in DB.classes[cls]["specs"]:
			var probe := {"cls": cls, "spec": sp_id, "talents": h["talents"], "lvl": h["lvl"]}
			if DB.can_use(probe, it):
				who.append("%s (%s)" % [DB.classes[cls]["name"], DB.classes[cls]["specs"][sp_id]["name"]])
	return "Для: " + ", ".join(who) if not who.is_empty() else "Никому из классов"


func _compare(hero: Dictionary, it: Dictionary) -> String:
	if not DB.can_use(hero, it):
		return "[color=#909090]Не подходит: %s[/color]" % DB.hero_name(hero)
	var comparison: Dictionary = game.compare_item(hero, it, chosen_slot if is_same(it, selected) else "")
	var before: Dictionary = comparison["before"]
	var after: Dictionary = comparison["after"]
	var L: Array[String] = ["[color=#d9b86a]%s · %s[/color]" % [DB.classes[hero["cls"]]["name"], DB.SLOT_NAMES[comparison["slot"]]]]
	L.append(_delta("DPS", before["dps"], after["dps"]))
	L.append(_delta("Выживаемость", before["survival"], after["survival"], true))
	if DB.spec(hero)["skill"].has("heal"):
		L.append(_delta("Лечение/с", before["healing"], after["healing"]))
	var removed: Array = comparison["removed"].map(func(old): return old["name"])
	L.append("[color=#a09070]Вместо: %s[/color]" % (", ".join(removed) if not removed.is_empty() else "пустого слота"))
	L.append("[color=#807060]Оценка против «%s»; выживаемость — запас здоровья с учётом защиты.[/color]" % comparison["target"])
	return "\n".join(L)


func _delta(name: String, a: float, b: float, percent_only: bool = false) -> String:
	var difference := b - a
	if absf(difference) < 0.05 or (a > 0.0 and absf(difference / a) < 0.0005):
		return "%s: [color=#909090]без изменений[/color]" % name
	var col := "#70d070" if difference > 0.0 else "#e06060"
	var sign_text := "+" if difference > 0.0 else "−"
	var change := "%s%.1f" % [sign_text, absf(difference)]
	if a > 0.001:
		var pct := "%s%.1f%%" % [sign_text, absf(difference / a * 100.0)]
		change = pct if percent_only else "%s (%s)" % [change, pct]
	return "%s: [color=%s]%s[/color]" % [name, col, change]


func show_tip(c: Cell) -> void:
	var txt := ""
	if c.item != null:
		txt = item_card(c.item, true)
	elif c.cur_id != "":
		var d := DB.currency_def(c.cur_id)
		txt = "[b]%s[/b] ×%d\n%s" % [d["name"], c.count, d["desc"]]
	elif c.slot != "":
		txt = "[color=#807060]%s: пусто[/color]" % DB.SLOT_NAMES[c.slot]
	if txt == "":
		return
	tip_text.text = txt
	tip_panel.reset_size()
	tip_panel.visible = true
	var p := c.position + Vector2(c.size.x + 8, 0)
	await get_tree().process_frame
	var sz := tip_panel.size
	if p.x + sz.x > size.x - 4:
		p.x = c.position.x - sz.x - 8
	p.y = clampf(p.y, 4, size.y - sz.y - 4)
	tip_panel.position = p


func hide_tip() -> void:
	tip_panel.visible = false


# ---------- помощники ----------

func _cell(pos: Vector2, sz: Vector2) -> Cell:
	var c := Cell.new()
	c.ui = self
	c.position = pos
	c.size = sz
	add_child(c)
	return c


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
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GOLD)
	add_child(l)
	return l


func _rich(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.position = pos
	r.size = sz
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 13)
	add_child(r)
	return r
