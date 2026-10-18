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
var _tip_source: Cell
var _tip_serial := 0


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
		mouse_exited.connect(func(): ui._defer_tip_hide())

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
			Icons.item(self, item, r.grow(-5), rc)
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
			draw_rect(r.grow(-2), Color(0.03, 0.025, 0.022, 0.72))
			if size.y >= 50:
				draw_string(get_theme_default_font(), Vector2(2, size.y - 5), "пусто", HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 10, Color("807567"))
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
	var sell_normal := _button(Vector2(502, by), Vector2(140, 26), "Продать обычные видимые", func(): _sell_where(func(it): return it["rarity"] == "normal"))
	sell_normal.add_theme_font_size_override("font_size", 10)
	var sell_visible := _button(Vector2(648, by), Vector2(144, 26), "Продать видимые", func(): _sell_where(func(it): return true))
	for b in [sell_normal, sell_visible]:
		b.tooltip_text = "Продажа только показанных совместимых вещей. Скрытые вещи других героев остаются в общей сумке."
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
	tip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tip_panel.mouse_exited.connect(_defer_tip_hide)
	tip_panel.visible = false
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = false
	tip_text.scroll_active = true
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_text.add_theme_font_size_override("normal_font_size", 12)
	tip_text.add_theme_font_size_override("bold_font_size", 13)
	tip_text.mouse_filter = Control.MOUSE_FILTER_PASS
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
	if game.heroes.is_empty():
		refresh()
		return
	if game.bag.size() != _last_bag:
		refresh()
	else:
		_refresh_currency()
		if visible and not game.heroes.is_empty() and hero_i < game.heroes.size():
			hero_summary.text = _summary(game.heroes[hero_i])
			_show_details()
	# Смерть и потеря прочности меняют DPS даже без новой вещи в сумке.
	if visible and tip_panel.visible and is_instance_valid(_tip_source):
		show_tip(_tip_source)


func refresh() -> void:
	if not visible:
		return
	_last_bag = game.bag.size()
	if game.heroes.is_empty():
		_show_empty_party()
		return
	hero_i = clampi(hero_i, 0, game.heroes.size() - 1)
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
	var items := displayed_items()
	if selected != null and _in_bag(selected) and not DB.can_use(hero, selected):
		selected = null
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
	bag_title.text = "Для героя: %d · всего %d/%d" % [items.size(), game.bag.size(), game.BAG_CAP]
	bag_title.tooltip_text = "Показаны вещи для класса и доступного материала брони. Основная характеристика не ограничивает выбор. Сумка общая для всех героев."
	_refresh_currency()
	hero_summary.text = _summary(hero)
	_refresh_slots()
	_show_details()


## Фильтр только по возможности надеть вещь: чужая основная характеристика не скрывает её.
func displayed_items() -> Array:
	if game.heroes.is_empty() or hero_i < 0 or hero_i >= game.heroes.size():
		return []
	var hero: Dictionary = game.heroes[hero_i]
	var items: Array = game.bag.filter(func(it): return DB.can_use(hero, it))
	var rank := {"rare": 0, "magic": 1, "normal": 2}
	items.sort_custom(func(a, b): return [rank[a["rarity"]], a["kind"], -int(a["ilvl"])] < [rank[b["rarity"]], b["kind"], -int(b["ilvl"])])
	return items.slice(0, GRID_COLS * GRID_ROWS)


func _show_empty_party() -> void:
	hero_i = 0
	selected = null
	chosen_slot = ""
	hide_tip()
	for tab in hero_tabs:
		tab.hide()
	for c in doll_cells.values() + bag_cells:
		c.item = null
		c.selected = false
		c.upgrade = false
		c.queue_redraw()
	hero_summary.text = "[color=#d9b86a]В отряде нет героев[/color]\nДобавь героя в «Лагере», затем выбери здесь его снаряжение."
	bag_title.text = "Выбери героя · всего %d/%d" % [game.bag.size(), game.BAG_CAP]
	details.text = "Снаряжение показано для героев текущего отряда. Вещи и валюта сохраняются в общей сумке."
	preview.text = "Добавь героя в «Лагере», чтобы выбрать вещь для крафта."
	slot_choice.clear()
	slot_choice.disabled = true
	equip_button.disabled = true
	btn_repair.disabled = true
	btn_repair.text = "Нет героев в отряде"
	lock_label.text = ""
	_refresh_currency()


func _refresh_currency() -> void:
	for id in cur_cells:
		var c: Cell = cur_cells[id]
		c.count = int(game.wallet.get(id, 0))
		c.selected = id == currency_id
		c.queue_redraw()


func _summary(hero: Dictionary) -> String:
	var s: Dictionary = game.stats[hero_i]
	var target: Dictionary = game.comparison_enemy()
	var o := Calc.offense(hero, s, target)
	var lines: Array[String] = []
	lines.append("[color=#d9b86a][b]%s[/b][/color] · ур. %d · %s" % [DB.hero_name(hero), hero["lvl"], DB.ROLE_NAMES[DB.role(hero)]])
	lines.append("Сила %s · ловкость %s · интеллект %s" % [_number(s.get("strength", 0)), _number(s.get("agility", 0)), _number(s.get("intellect", 0))])
	lines.append("Основная: %s" % DB.STAT_NAMES.get(DB.main_stat(hero), DB.main_stat(hero)))
	lines.append("Сила атаки %s · заклинаний %s" % [_number(s.get("attack_power", 0)), _number(s.get("spell_power", 0))])
	lines.append("DPS по «%s»: [color=#ffffff]%.2f[/color]" % [target["name"], o["dps"]])
	lines.append("Удар %.2f · скорость %.2f/с" % [o["hit"], o["speed"]])
	lines.append("Крит атак %s%% · заклинаний %s%%" % [_number(s.get("crit_attack", o["crit_chance"])), _number(s.get("crit_spell", o["crit_chance"]))])
	lines.append("Множитель крита %s%%" % _number(o["crit_multi"]))
	lines.append("Здоровье %s · броня %s · −%s%% урона" % [_number(s["max_life"]), _number(s.get("armour", 0)), _number(s.get("less_taken", 0))])
	lines.append("Блок %s%% · уклонение %s%%" % [_number(s.get("block_chance", 0)), _number(s.get("dodge_chance", 0))])
	var mana_regen: float = game.MANA_REGEN * (1.0 + s.get("mana_regen", 0.0) / 100.0) if s["max_mana"] > 0 else 0.0
	lines.append("Мана %s · восстановление %s/с" % [_number(s["max_mana"]), _number(mana_regen)])
	lines.append("Восстановление здоровья %s/с" % _number(s["max_life"] * s.get("regen", 0) / 100.0))
	if DB.spec(hero)["skill"].has("heal"):
		lines.append("Лечение [color=#70ff70]%s[/color] за каст" % _number(Calc.heal(hero, s)))
	var res := []
	for t in ["fire", "cold", "lightning", "chaos"]:
		var v: float = s["res_" + t]
		var col := "#70d070" if v >= 75 else ("#e0c060" if v >= 0 else "#e06060")
		res.append("%s [color=%s]%d%%[/color]" % [DB.TYPE_NAMES[t], col, v])
	lines.append("  ".join(res))
	lines.append("[color=#807060]Штраф глубины: −%s%% к сопр.[/color]" % _number(s["res_penalty"]))
	return "\n".join(lines)


func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


# ================= ДЕЙСТВИЯ =================

func _select_hero(i: int) -> void:
	hero_i = clampi(i, 0, maxi(0, game.heroes.size() - 1))
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
	if game.heroes.is_empty():
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
	if selected == null or not _in_bag(selected) or game.heroes.is_empty():
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
	if selected == null or not _in_bag(selected) or game.heroes.is_empty():
		return
	var err: String = game.equip(hero_i, selected, chosen_slot)
	result_label.text = "[color=#e06060]%s[/color]" % err if err != "" else "Предмет надет"
	hide_tip()
	refresh()


func _repair() -> void:
	result_label.text = game.repair_all()
	refresh()


func _sell_selected() -> void:
	if not game.can_edit():
		result_label.text = "В походе продавать нельзя"
		return
	if selected != null and _in_bag(selected) and not game.heroes.is_empty() and DB.can_use(game.heroes[hero_i], selected):
		game.sell_item(selected)
		selected = null
		refresh()


func _sell_where(pred: Callable) -> void:
	if not game.can_edit():
		result_label.text = "В походе продавать нельзя"
		return
	var sold := 0
	for it in displayed_items():
		if pred.call(it):
			game.sell_item(it)
			sold += 1
	if selected != null and not _in_bag(selected) and _equipped_owner(selected).is_empty():
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
		details.text = "[color=#807060]Показаны совместимые вещи выбранного героя; остальная добыча остаётся в общей сумке. ЛКМ: сравнить и выбрать для крафта.\n«Надеть выбранное», ПКМ или двойной клик: надеть в лагере.\nЗелёная стрелка: есть прирост урона, лечения или защиты; проверь потери.\n«Все свойства»: подробные аффиксы.[/color]"
		preview.text = "[color=#807060]Выбери вещь, затем валюту: здесь появятся шансы.[/color]"
		return
	details.text = item_card(selected, true)
	var has_material := false
	for amount in game.wallet.values():
		if int(amount) > 0: has_material = true
	preview.text = Craft.preview(selected, currency_id) if has_material else "[color=#a09070]Сначала надень оружие.\n\nУгли для крафта начнут выпадать в катакомбах. Тогда здесь появятся свойства и шансы их получения.[/color]"


# ================= КАРТОЧКА ПРЕДМЕТА =================

func item_card(it: Dictionary, with_compare: bool) -> String:
	var col: String = DB.RARITY_COLORS[it["rarity"]]
	var L: Array[String] = []
	L.append("[color=%s][b]%s[/b][/color]" % [col, it["name"]])
	var sub: String = it["base"] if it["rarity"] == "rare" else DB.SLOT_NAMES.get(it["slot"], "")
	L.append("[color=#a09070]%s · %s · ур. предмета %d[/color]" % [sub, DB.RARITY_NAMES[it["rarity"]], it["ilvl"]])
	if it.get("armor_type", "") != "":
		L.append("Материал: %s" % DB.ARMOR_NAMES.get(it["armor_type"], it["armor_type"]))
	if it.get("profile", "") != "":
		L.append("Профиль характеристик: %s" % DB.STAT_NAMES.get(it["profile"], it["profile"]))
	var cap := Items.capacity(it)
	var prefixes := 0
	var suffixes := 0
	for mod in it["mods"]:
		if mod["type"] == "prefix": prefixes += 1
		else: suffixes += 1
	L.append("Аффиксы %d/%d · префиксы %d/%d · суффиксы %d/%d" % [prefixes + suffixes, cap["total"], prefixes, cap["prefix"], suffixes, cap["suffix"]])
	var owner := _equipped_owner(it)
	var full_stats := not owner.is_empty() or details_box.button_pressed
	if not owner.is_empty():
		L.append(_equipped_summary(owner))
	if with_compare and _in_bag(it) and not game.heroes.is_empty():
		L.append(_compare(game.heroes[hero_i], it))
	var dur := float(it.get("dur", 100.0))
	if dur <= 0.0:
		L.append("[color=#ff4040]Сломано: статы не работают. Почини в лагере (%d з)[/color]" % Items.repair_cost(it))
	elif dur < 100.0:
		L.append("[color=#c0a060]Прочность %d%%, починка %d з[/color]" % [dur, Items.repair_cost(it)])
	if full_stats and not it["implicit"].is_empty():
		L.append("[color=#3a3020]────────────────[/color]")
		for k in it["implicit"]:
			L.append("[color=#8fb0ff]%s[/color]" % DB.stat_text(k, _number(float(it["implicit"][k]))))
	if full_stats and not it["mods"].is_empty():
		L.append("[color=#3a3020]────────────────[/color]")
		for m in it["mods"]:
			var d := Items.affix_def(m["id"])
			var tag := "П" if m["type"] == "prefix" else "С"
			var tcol := "#ffd75a" if int(m["tier"]) == 1 else ("#c0c0c0" if int(m["tier"]) <= 2 else "#808080")
			L.append("[color=%s]%s T%d[/color]  %s" % [tcol, tag, m["tier"], (d["text"] as String) % _number(float(m["value"]))])
	if it.get("corrupted", false):
		L.append("[color=#d04040]Осквернено[/color]")
	L.append("[color=#807060]Продажа: %d з[/color]" % Items.sell_price(it))
	if not full_stats:
		L.append("[color=#807060]Аффиксы: включи «Все свойства»[/color]")
	return "\n".join(L)


func _in_bag(it: Dictionary) -> bool:
	return game.bag_index(it) >= 0


## Два одинаковых по свойствам предмета остаются разными вещами.
## Выбранный предмет может принадлежать другой вкладке или герою вне отряда.
func _equipped_owner(it: Dictionary) -> Dictionary:
	for hero in game.roster.values():
		for slot in hero["items"]:
			if is_same(hero["items"][slot], it):
				return {"hero": hero, "slot": slot}
	return {}


func _equipped_summary(owner: Dictionary) -> String:
	var hero: Dictionary = owner["hero"]
	var lines: Array[String] = ["[color=#d9b86a]Надето: %s · %s[/color]" % [DB.classes[hero["cls"]]["name"], DB.SLOT_NAMES[owner["slot"]]]]
	var it: Dictionary = hero["items"][owner["slot"]]
	if it["slot"] != "weapon":
		return "\n".join(lines)
	var target: Dictionary = game.comparison_enemy()
	var s: Dictionary = {}
	for i in game.heroes.size():
		if is_same(game.heroes[i], hero):
			s = game.stats[i]
			break
	if s.is_empty():
		s = Calc.hero_stats(hero, int(target["power"]), game.party)
	var o := Calc.offense(hero, s, target)
	lines.append("DPS героя с этим оружием: [color=#ffffff]%.2f[/color]" % o["dps"])
	lines.append("Удар %.2f · скорость %.2f/с" % [o["hit"], o["speed"]])
	lines.append("[color=#807060]По «%s», с учётом билда и защиты врага.[/color]" % target["name"])
	return "\n".join(lines)


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
	if tip_panel.visible and is_same(_tip_source, c) and tip_text.text == txt and _tip_bounds().encloses(tip_panel.get_rect()):
		return  # Не сбрасываем прокрутку неизменившейся карточки при обновлении боя.
	_tip_serial += 1
	var serial := _tip_serial
	_tip_source = c
	tip_text.text = txt
	var bounds := _tip_bounds().grow(-4)
	tip_panel.size = Vector2(minf(360.0, bounds.size.x), 100)
	tip_panel.visible = true
	var p := c.position + Vector2(c.size.x + 8, 0)
	await get_tree().process_frame
	if serial != _tip_serial or not tip_panel.visible:
		return
	bounds = _tip_bounds().grow(-4)
	tip_panel.size.y = minf(tip_text.get_content_height() + 16.0, bounds.size.y)
	var sz := tip_panel.size
	if p.x + sz.x > bounds.end.x:
		p.x = c.position.x - sz.x - 8
	p.x = clampf(p.x, bounds.position.x, bounds.end.x - sz.x)
	p.y = clampf(p.y, bounds.position.y, bounds.end.y - sz.y)
	tip_panel.position = p
	tip_text.scroll_to_line(0)


func _tip_bounds() -> Rect2:
	# У встроенной панели может быть прокрутка, особенно при высоте окна 720.
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var bounds := Rect2(Vector2.ZERO, size).intersection(inverse * get_viewport_rect())
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor.clip_contents or ancestor is ScrollContainer):
			var clip: Rect2 = ancestor.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ancestor.size)
			bounds = bounds.intersection(inverse * clip)
		ancestor = ancestor.get_parent()
	return bounds


func _defer_tip_hide() -> void:
	# Небольшой зазор можно пересечь мышью, чтобы прокрутить длинную карточку.
	var serial := _tip_serial
	await get_tree().create_timer(0.15).timeout
	if serial != _tip_serial or not tip_panel.visible:
		return
	var mouse := get_global_mouse_position()
	if tip_panel.get_global_rect().has_point(mouse):
		return
	if is_instance_valid(_tip_source) and _tip_source.get_global_rect().has_point(mouse):
		return
	hide_tip()


func hide_tip() -> void:
	_tip_serial += 1
	_tip_source = null
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
