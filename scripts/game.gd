extends Control
## Idle-данж в окне над панелью задач.
## Цикл: лагерь (собрать отряд, таланты, шмот, починка) → поход в подземелье (бой сам, менять ничего нельзя)
## → награда или поражение → снова лагерь. Формулы в calc.gd, предметы в items.gd, данные в data/*.json.

const SAVE_PATH := "user://save2.json"
var save_path := SAVE_PATH  # тесты используют собственный файл и не трогают игровой прогресс
const PACKS_PER_FLOOR := 5        # обычных пачек на этаже, потом босс этажа
const BAG_CAP := 60
const OFFLINE_CAP_SEC := 8 * 3600
const OFFLINE_EFFICIENCY := 0.5
const REST_HEAL := 0.2            # между пачками отряд переводит дух: +20% здоровья, +30% маны
const REST_MANA := 0.3
const HEAL_COST := 10.0           # мана за каст лечения
const MANA_REGEN := 3.0           # маны в секунду без бонусов
const DEATH_DURABILITY := 10.0    # смерть героя снимает 10% прочности со всего надетого, как в WoW
const CAMP_PAUSE := 3.0           # пауза в лагере перед автоповтором
const BATTLE_W := 520.0

var simulating := false   # автопилот ставит true: без сохранений, лога и картинок

# --- сохраняемое состояние ---
var roster: Dictionary = {}       # класс -> герой {cls, spec, lvl, xp, items, talents, illusion}
var party_ids: Array = []         # классы в отряде
var cleared: Dictionary = {}      # id данжа -> сколько раз пройден
var test_mode := false             # тест: открыты все данжи, классы и 4 места в отряде
var selected_dungeon := "crypt"
var repeat_run := false            # автоповтор данжа
var gold := 0
var bag: Array = []
var wallet: Dictionary = {}
var kills := 0
var wipes := 0
var hints_shown: Dictionary = {}

# --- поход ---
var mode := "camp"                # camp | run
var run: Dictionary = {}          # {id, floor_i, pack, deaths, t}
var heroes: Array = []            # отряд (ссылки на героев из roster), по порядку построения
var stats: Array = []
var offense: Array = []
var party: Dictionary = {}        # бафы отряда
var enemy: Dictionary = {}
var enemy_timer := 0.0
var camp_timer := 0.0
var wipe_streak := 0
var meter: Dictionary = {}        # «Details»: урон, хил, получено, смерти за поход
var last_result := ""

# --- кадр ---
var t := 0.0
var save_timer := 0.0
var attack_flash: Array = [0.0, 0.0, 0.0, 0.0]
var heal_flash: Array = [0.0, 0.0, 0.0, 0.0]
var hurt_flash := 0.0
var dragging := false
var drag_offset := Vector2i.ZERO
var tex: Dictionary = {}

# --- интерфейс ---
var log_label: RichTextLabel
var info_label: Label
var sub_label: Label
var hero_buttons: Array = []
var btn_go: Button
var btn_repeat: CheckBox
var meter_tab := "dmg"
var tab_buttons: Dictionary = {}


func _ready() -> void:
	DB.ensure()
	get_viewport().transparent_bg = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_new_game()
	if not simulating:
		_load_textures()
		_build_ui()
		get_window().min_size = Vector2i(1280, 720)
		_load_game()
	_set_party()
	_refresh_ui()


func _new_game() -> void:
	roster.clear()
	var specs := {"warrior": "prot", "priest": "light", "mage": "elem", "hunter": "beast",
		"paladin": "ret", "warlock": "demon", "shaman": "elements"}
	for cls in DB.classes:
		var h := {"cls": cls, "spec": specs.get(cls, DB.classes[cls]["specs"].keys()[0]), "lvl": 1, "xp": 0,
			"items": {}, "talents": {}, "illusion": ""}
		var kinds: Array = DB.spec(h).get("weapons", DB.classes[cls]["weapons"])
		h["items"]["weapon"] = Items.generate(1, "normal", kinds[0])
		h["items"]["armour"] = Items.generate(1, "normal", "armour")
		var offhands: Array = DB.spec(h).get("offhands", DB.classes[cls]["offhands"])
		if not offhands.is_empty() and not DB.is_two_handed(h["items"]["weapon"]):
			h["items"]["offhand"] = Items.generate(1, "normal", offhands[0])
		roster[cls] = h
	party_ids = ["warrior", "priest", "mage", "hunter"] if test_mode else ["warrior", "priest"]


# ================= ПРОГРЕССИЯ =================

func slots() -> int:
	if test_mode:
		return 4
	var n: int = int(DB.start["slots"])
	for d in DB.dungeons:
		if cleared.has(d["id"]):
			n = maxi(n, int(d["unlocks"].get("slots", 0)))
	return n


func class_unlocked(cls: String) -> bool:
	if test_mode or cls in DB.start["classes"]:
		return true
	for d in DB.dungeons:
		if cleared.has(d["id"]) and cls in d["unlocks"].get("classes", []):
			return true
	return false


## Где открывается класс или место в отряде (для подсказки в лагере)
func unlock_source(what: String, value) -> String:
	for d in DB.dungeons:
		if what == "class" and value in d["unlocks"].get("classes", []):
			return d["name"]
		if what == "slot" and int(d["unlocks"].get("slots", 0)) == int(value):
			return d["name"]
	return ""


func dungeon_open(id: String) -> bool:
	if test_mode:
		return true
	var d := DB.dungeon(id)
	return not d.has("requires") or cleared.has(d["requires"])


# ================= ОТРЯД =================

## Строим отряд из party_ids: танк впереди, лекари сзади
func _set_party() -> void:
	var order := {"tank": 0, "offtank": 1, "dps": 2, "support": 3, "healer": 4}
	var ids: Array = party_ids.filter(func(c): return roster.has(c) and class_unlocked(c))
	ids = ids.slice(0, slots())
	ids.sort_custom(func(a, b): return order[DB.role(roster[a])] < order[DB.role(roster[b])])
	party_ids = ids
	heroes = ids.map(func(c): return roster[c])
	_recalc()
	for i in heroes.size():
		heroes[i]["life"] = stats[i]["max_life"]
		heroes[i]["mana"] = stats[i]["max_mana"]


func can_edit() -> bool:
	return mode == "camp"


func set_in_party(cls: String, on: bool) -> String:
	if not can_edit():
		return "В походе отряд менять нельзя"
	if on:
		if cls in party_ids:
			return ""
		if party_ids.size() >= slots():
			return "Мест в отряде: %d" % slots()
		party_ids.append(cls)
	else:
		party_ids.erase(cls)
	_set_party()
	_refresh_ui()
	return ""


func set_spec(cls: String, spec_id: String) -> String:
	if not can_edit():
		return "В походе ветку менять нельзя"
	var h: Dictionary = roster[cls]
	h["spec"] = spec_id
	# оружие, которое новая ветка не носит, уходит в сумку
	for slot in ["weapon", "offhand"]:
		var it = h["items"].get(slot)
		if it != null and not DB.can_use(h, it):
			h["items"].erase(slot)
			bag.append(it)
	_set_party()
	_refresh_ui()
	return ""


func set_talent(cls: String, lvl: int, option: int) -> String:
	if not can_edit():
		return "В походе таланты менять нельзя"
	roster[cls]["talents"][str(lvl)] = option
	_set_party()
	_refresh_ui()
	return ""


func set_illusion(copy_cls: String) -> void:
	if can_edit():
		roster["shaman"]["illusion"] = copy_cls
		_set_party()
		_refresh_ui()


# ================= БОЙ =================

func _recalc() -> void:
	var floor_n := _floor_power()
	party = Calc.party_mods(heroes)
	stats.clear()
	for h in heroes:
		var s := Calc.hero_stats(h, floor_n, party)
		h["life"] = minf(float(h.get("life", s["max_life"])), s["max_life"])
		h["mana"] = minf(float(h.get("mana", s["max_mana"])), s["max_mana"])
		stats.append(s)
	_recalc_offense()


func _recalc_offense() -> void:
	offense.clear()
	var target := enemy if not enemy.is_empty() else ref_enemy()
	for i in heroes.size():
		offense.append(Calc.offense(heroes[i], stats[i], target))


func _floor_power() -> int:
	var d := DB.dungeon(run["id"] if mode == "run" else selected_dungeon)
	return int(d["power"]) + (int(run["floor_i"]) if mode == "run" else 0)


## Типичный враг данжа: по нему лагерь считает DPS и сравнивает вещи
func ref_enemy(id: String = "", floor_i: int = 0) -> Dictionary:
	var d := DB.dungeon(id if id != "" else selected_dungeon)
	return _make_enemy(d, floor_i, "pack", true)


func _make_enemy(d: Dictionary, floor_i: int, kind: String, reference: bool = false) -> Dictionary:
	var p: int = int(d["power"]) + floor_i
	var res := {"fire": 0.0, "cold": 0.0, "lightning": 0.0, "chaos": 0.0}
	var base_res := minf(40.0, 2.0 * (p - 1))
	for e in DB.ELEMENTS:
		res[e] = base_res
	for tp in d["dmg_types"]:
		if tp in DB.ELEMENTS:
			res[tp] += 30.0   # враги стихийного данжа устойчивы к своей стихии
	var names: Array = d["names"]
	var e := {
		"name": names[0] if reference else names[randi() % names.size()], "kind": kind, "boss": kind != "pack", "rare": false, "mods": [],
		"hp": 55.0 * pow(1.25, p - 1), "dmg": 7.0 * pow(1.2, p - 1), "res": res,
		"armour": 8.0 * pow(p, 1.4), "dmg_types": d["dmg_types"], "power": p,
	}
	if kind == "floor_boss":
		e["name"] = d["floor_boss"]
		e["hp"] *= 7.0
		e["dmg"] *= 1.7
	elif kind == "boss":
		e["name"] = d["boss"]
		e["hp"] *= 12.0
		e["dmg"] *= 2.0
	var n_mods := 0
	if kind == "boss" and p >= 5:
		n_mods = 1
	elif not reference and kind == "pack" and p >= 3 and randf() < 0.08 + 0.01 * p:
		e["rare"] = true
		n_mods = 1 + int(p >= 10)
		e["hp"] *= 2.0
	for i in n_mods:
		var m: Dictionary = DB.rare_mods[randi() % DB.rare_mods.size()]
		e["mods"].append(m["name"])
		for tp in m.get("res", {}):
			e["res"][tp] += float(m["res"][tp])
		e["armour"] *= float(m.get("armour_mult", 1.0))
		e["dmg"] *= float(m.get("dmg_mult", 1.0))
		e["hp"] *= float(m.get("hp_mult", 1.0))
	var tuning: Dictionary = d.get("tuning", {})
	e["hp"] *= float(tuning.get("hp", 1.0)) * float(tuning.get(kind + "_hp", 1.0))
	e["dmg"] *= float(tuning.get("dmg", 1.0)) * float(tuning.get(kind + "_dmg", 1.0))
	e["max_hp"] = e["hp"]
	return e


func start_run(id: String = "") -> String:
	if mode == "run":
		return "Отряд уже в походе"
	if id != "":
		selected_dungeon = id
	if not dungeon_open(selected_dungeon):
		return "Этот данж ещё закрыт"
	if heroes.is_empty():
		return "В отряде никого нет"
	mode = "run"
	run = {"id": selected_dungeon, "floor_i": 0, "pack": 1, "deaths": 0, "t": 0.0}
	meter = {"dmg": [], "heal": [], "taken": [], "deaths": []}
	for i in heroes.size():
		meter["dmg"].append(0.0)
		meter["heal"].append(0.0)
		meter["taken"].append(0.0)
		heroes[i]["cd"] = randf() * 0.5
		heroes[i]["pet_dead"] = false
	_recalc()
	for i in heroes.size():
		heroes[i]["life"] = stats[i]["max_life"]
		heroes[i]["mana"] = stats[i]["max_mana"]
		heroes[i]["pet_life"] = _pet_max(i)
	enemy_timer = 0.0
	_spawn_enemy()
	var d := DB.dungeon(selected_dungeon)
	_log("[color=#d9b86a]Поход: %s (сила %d–%d)[/color]" % [d["name"], d["power"], int(d["power"]) + int(d["floors"]) - 1])
	_refresh_ui()
	return ""


func retreat() -> void:
	if mode != "run":
		return
	_log("[color=#e0a040]Отряд отступил[/color]")
	_end_run("retreat")


func _pet_max(i: int) -> float:
	if heroes[i]["cls"] != "hunter":
		return 0.0
	return stats[i]["max_life"] * 0.9 * (1.0 + stats[i].get("pet_life", 0.0) / 100.0)


func _spawn_enemy() -> void:
	var d := DB.dungeon(run["id"])
	var kind := "pack"
	if run["pack"] > PACKS_PER_FLOOR:
		kind = "boss" if run["floor_i"] == int(d["floors"]) - 1 else "floor_boss"
	enemy = _make_enemy(d, run["floor_i"], kind)
	_recalc_offense()


func alive() -> Array:
	return range(heroes.size()).filter(func(i): return heroes[i]["life"] > 0.0)


func step(delta: float) -> void:
	if mode == "camp":
		if repeat_run and not heroes.is_empty():
			camp_timer += delta
			if camp_timer >= CAMP_PAUSE:
				camp_timer = 0.0
				start_run()
		return
	run["t"] += delta
	for i in heroes.size():
		attack_flash[i] = maxf(0.0, attack_flash[i] - delta)
		heal_flash[i] = maxf(0.0, heal_flash[i] - delta)
	# действия героев
	for i in alive():
		var h: Dictionary = heroes[i]
		var s: Dictionary = stats[i]
		if s["max_mana"] > 0.0:
			h["mana"] = minf(s["max_mana"], h["mana"] + MANA_REGEN * (1.0 + s.get("mana_regen", 0.0) / 100.0) * delta)
		h["life"] = minf(s["max_life"], h["life"] + s["max_life"] * s.get("regen", 0.0) / 100.0 * delta)
		h["cd"] = float(h.get("cd", 0.0)) - delta
		while h["cd"] <= 0.0 and enemy["hp"] > 0.0:
			h["cd"] += 1.0 / maxf(0.1, offense[i]["speed"])
			_act(i)
	if enemy["hp"] <= 0.0:
		_on_kill()
		return
	# удары врага: проклятие замедляет, метка и проклятие заставляют промахиваться
	enemy_timer += delta
	var interval := 1.0 / maxf(0.3, 1.0 - party["enemy"]["slow"] / 100.0)
	while enemy_timer >= interval:
		enemy_timer -= interval
		_enemy_hits()
		if alive().is_empty():
			_on_wipe()
			return


## Ход героя: лекарь лечит самого раненого, если есть кого, иначе бьёт
func _act(i: int) -> void:
	var h: Dictionary = heroes[i]
	var heal := Calc.heal(h, stats[i])
	if heal > 0.0 and h["mana"] >= HEAL_COST:
		var threshold := 0.9 if DB.role(h) == "healer" else 0.6
		var target := -1
		var worst := threshold
		for j in alive():
			var r: float = heroes[j]["life"] / maxf(1.0, stats[j]["max_life"])
			if r < worst:
				worst = r
				target = j
		if target >= 0:
			h["mana"] -= HEAL_COST
			var got := minf(heal, stats[target]["max_life"] - heroes[target]["life"])
			heroes[target]["life"] += got
			meter["heal"][i] += got
			heal_flash[target] = 0.3
			attack_flash[i] = 0.15
			_float("+" + _short(got), Vector2(_hero_x(target), GROUND - 70), Color(0.45, 1.0, 0.45), 11)
			return
	var o: Dictionary = offense[i]
	var crit_factor: float = 1.0 + o["crit_chance"] / 100.0 * (o["crit_multi"] / 100.0 - 1.0)
	var dmg: float = o["hit"] * crit_factor
	enemy["hp"] -= dmg
	meter["dmg"][i] += dmg
	attack_flash[i] = 0.15
	if not simulating:
		var crit: bool = randf() * 100.0 < o["crit_chance"]
		var shown: float = o["hit"] * (o["crit_multi"] / 100.0 if crit else 1.0)
		var jitter := Vector2(randf_range(-14, 14), randf_range(-6, 6))
		_float(_short(shown) + ("!" if crit else ""), Vector2(ENEMY_X, GROUND - 60) + jitter,
			Color(1.0, 0.85, 0.2) if crit else Color(0.95, 0.92, 0.85), 15 if crit else 11)


func _enemy_hits() -> void:
	var a := alive()
	var hit: float = enemy["dmg"] * (1.0 - minf(60.0, party["enemy"]["miss"]) / 100.0)
	var shares := {}
	var aoe := 0.0
	if enemy["boss"]:
		aoe = hit * 0.3   # боссы бьют по площади: 30% удара достаётся каждому
		hit *= 0.7
	var tank := -1
	var tank_share := 0.0
	for i in a:
		if DB.role(heroes[i]) == "tank":
			tank = i
			tank_share = 0.75
			break
	if tank < 0:
		for i in a:
			if DB.role(heroes[i]) == "offtank":
				tank = i
				tank_share = 0.55
				break
	var wolf := -1
	if tank < 0:
		for i in a:
			if heroes[i]["cls"] == "hunter" and not heroes[i].get("pet_dead", false):
				wolf = i
	if tank >= 0:
		shares[tank] = tank_share
		for i in a:
			if i != tank:
				shares[i] = (1.0 - tank_share) / (a.size() - 1)
		if a.size() == 1:
			shares[tank] = 1.0
	elif wolf >= 0:
		_hit_wolf(wolf, hit * 0.65)
		for i in a:
			shares[i] = 0.35 / a.size()
	else:
		for i in a:
			shares[i] = 1.0 / a.size()
	for i in a:
		var raw: float = hit * shares.get(i, 0.0) + aoe
		if i == tank:
			raw *= 1.0 - party["tank_less"] / 100.0   # тотем земли забирает часть урона по танку
		var dmg := Calc.damage_taken(stats[i], raw, enemy["dmg_types"])
		heroes[i]["life"] -= dmg
		meter["taken"][i] += dmg
		if dmg >= 1.0:
			_float("-" + _short(dmg), Vector2(_hero_x(i), GROUND - 52), Color(1.0, 0.35, 0.3), 10)
		if heroes[i]["life"] <= 0.0:
			_hero_died(i, dmg)
	hurt_flash = 0.15


func _hit_wolf(i: int, raw: float) -> void:
	var dmg := Calc.damage_taken(stats[i], raw, enemy["dmg_types"])
	heroes[i]["pet_life"] -= dmg
	if heroes[i]["pet_life"] <= 0.0:
		heroes[i]["pet_dead"] = true
		_log("[color=#ff9060]Волк пал[/color]")
		_recalc_offense()


func _hero_died(i: int, last_hit: float) -> void:
	var h: Dictionary = heroes[i]
	h["life"] = 0.0
	run["deaths"] += 1
	meter["deaths"].append({"t": run["t"], "who": DB.classes[h["cls"]]["name"], "by": enemy["name"], "hit": last_hit,
		"floor": int(run["floor_i"]) + 1})
	# смерть ломает снаряжение: −10% прочности со всего надетого
	var broke: Array = []
	for slot in h["items"]:
		var it: Dictionary = h["items"][slot]
		var was := Items.broken(it)
		it["dur"] = maxf(0.0, float(it.get("dur", 100.0)) - DEATH_DURABILITY)
		if Items.broken(it) and not was:
			broke.append(it["name"])
	_log("[color=#ff6060]%s пал[/color] (%s, удар %d)" % [DB.classes[h["cls"]]["name"], enemy["name"], int(last_hit)])
	if not broke.is_empty():
		_log("[color=#ff4040]Сломалось: %s[/color]" % ", ".join(broke))
		_recalc()
	hint("death", "каждая смерть снимает 10% прочности со всего надетого. Сломанные вещи не дают статов, чинить в лагере за золото.")


func _on_kill() -> void:
	kills += 1
	var p: int = enemy["power"]
	var mult := 10.0 if enemy["kind"] == "boss" else (5.0 if enemy["kind"] == "floor_boss" else (2.5 if enemy["rare"] else 1.0))
	var xp := int(6.0 * pow(1.2, p - 1) * mult)
	for i in alive():
		# Слабые враги дают лут, но не позволяют бесконечно перерасти стену уровнем.
		if int(heroes[i]["lvl"]) - p > int(DB.start.get("xp_level_gap", 2)):
			hint("xp_gap", "враги на 3 и больше уровня слабее героя не дают опыта. Добыча остаётся: усиливай вещи и пробуй следующий данж.")
			continue
		var earned := maxi(1, int(xp * float(DB.start.get("xp_multiplier", 0.2))))
		_gain_xp(heroes[i], earned)
	gold += int(2.0 * pow(1.15, p - 1) * (3.0 if enemy["boss"] else 1.0))
	var d := DB.dungeon(run["id"])
	var ilvl := p * 2
	match enemy["kind"]:
		"pack":
			if randf() < (0.25 if enemy["rare"] else 0.06):
				_drop_currency()
			run["pack"] += 1
			for i in alive():   # передышка между пачками
				heroes[i]["life"] = minf(stats[i]["max_life"], heroes[i]["life"] + stats[i]["max_life"] * REST_HEAL)
				heroes[i]["mana"] = minf(stats[i]["max_mana"], heroes[i]["mana"] + stats[i]["max_mana"] * REST_MANA)
		"floor_boss":
			_log("[color=#ffb020]%s повержен. Этаж %d пройден[/color]" % [enemy["name"], int(run["floor_i"]) + 1])
			_drop(_loot_item(ilvl, false))
			_drop_currency()
			run["floor_i"] += 1
			run["pack"] = 1
			_revive_all(0.5)
		"boss":
			_log("[color=#ffd75a]%s повержен! %s пройден[/color]" % [enemy["name"], d["name"]])
			for k in 2:
				_drop(_loot_item(ilvl + 2, true))
			for k in 3:
				_drop_currency()
			var first := not cleared.has(run["id"])
			cleared[run["id"]] = int(cleared.get(run["id"], 0)) + 1
			if first and not test_mode:
				var u: Dictionary = d["unlocks"]
				if u.has("slots"):
					_log("[color=#70ff70]Открыто место в отряде: теперь %d[/color]" % int(u["slots"]))
				for c in u.get("classes", []):
					_log("[color=#70ff70]Открыт класс: %s[/color]" % DB.classes[c]["name"])
			_end_run("win")
			return
	_spawn_enemy()
	_refresh_ui()


func _revive_all(ratio: float) -> void:
	for i in heroes.size():
		if heroes[i]["life"] <= 0.0:
			heroes[i]["life"] = stats[i]["max_life"] * ratio
		heroes[i]["pet_dead"] = false
		heroes[i]["pet_life"] = _pet_max(i)
	_recalc()


func _on_wipe() -> void:
	wipes += 1
	_log("[color=#ff4040]Отряд погиб на этаже %d[/color]" % (int(run["floor_i"]) + 1))
	hint("wipe", "отряд погиб. Смени состав или таланты, почини шмот или покачайся в данже попроще.")
	_end_run("wipe")


## Конец похода: добыча остаётся в сумке. Вещи и починку выбирает игрок.
func _end_run(result: String) -> void:
	last_result = result
	mode = "camp"
	enemy = {}
	camp_timer = 0.0
	wipe_streak = wipe_streak + 1 if result == "wipe" else 0
	if result == "retreat":
		repeat_run = false
	if wipe_streak >= 2 and repeat_run:
		repeat_run = false
		_log("[color=#ff9060]Два вайпа подряд: автоповтор выключен. Пересобери отряд или выбери данж попроще.[/color]")
	_recalc()
	for i in heroes.size():
		heroes[i]["life"] = stats[i]["max_life"]
		heroes[i]["mana"] = stats[i]["max_mana"]
		heroes[i]["pet_dead"] = false
	_refresh_ui()


func _gain_xp(h: Dictionary, xp: int) -> void:
	h["xp"] += xp
	while h["xp"] >= Calc.xp_to_next(h["lvl"]):
		h["xp"] -= Calc.xp_to_next(h["lvl"])
		h["lvl"] += 1
		if not simulating:
			for tier in DB.talent_tiers(h):
				if int(tier["lvl"]) == int(h["lvl"]):
					_log("[color=#70ff70]%s: открыт ярус талантов[/color]" % DB.classes[h["cls"]]["name"])
		_recalc()


# ================= ЛУТ =================

## Лут редкий, но лучше: чаще то, что подходит отряду
func _loot_item(ilvl: int, chest: bool) -> Dictionary:
	var rarity := "rare" if randf() < (0.6 if chest else 0.3) else ("magic" if randf() < 0.75 else "normal")
	var kind := ""
	if randf() < 0.5 and not heroes.is_empty():
		var h: Dictionary = heroes[randi() % heroes.size()]
		var kinds: Array = []
		kinds.append_array(DB.spec(h).get("weapons", DB.classes[h["cls"]]["weapons"]))
		kinds.append_array(DB.spec(h).get("offhands", DB.classes[h["cls"]]["offhands"]))
		if not kinds.is_empty():
			kind = kinds[randi() % kinds.size()]
	return Items.generate(ilvl, rarity, kind)


func _drop(item: Dictionary) -> void:
	item["dur"] = 100.0
	_to_bag(item)
	var col: String = DB.RARITY_COLORS[item["rarity"]]
	_float(item["name"], Vector2(ENEMY_X, GROUND - 30), Color(col), 11)
	_log("Добыча: [color=%s]%s[/color]" % [col, item["name"]])


func _drop_currency() -> void:
	var total := 0.0
	for c in DB.currency:
		total += float(c["drop"])
	var r := randf() * total
	for c in DB.currency:
		r -= float(c["drop"])
		if r <= 0.0:
			wallet[c["id"]] = int(wallet.get(c["id"], 0)) + 1
			_float("+ " + c["name"], Vector2(ENEMY_X, GROUND - 14), WALLET_ICONS.get(c["id"], GOLD), 10)
			if c["drop"] <= 6:
				_log("Выпало: [color=#e0a040]%s[/color]" % c["name"])
			return


## Один выбор слота для карточки и надевания: кольца и «Титаническая хватка».
func equipment_slot(h: Dictionary, item: Dictionary, requested: String = "") -> String:
	var allowed := DB.equip_slots(item, h)
	if requested in allowed:
		return requested
	for slot in allowed:
		if h["items"].get(slot) == null:
			return slot
	return allowed[0]


## Общие правила замены. Предпросмотр вызывает их только на копии героя.
func _replace_equipment(h: Dictionary, item: Dictionary, slot: String) -> Array:
	var remove: Array = [slot]
	if not DB.has_talent_flag(h, "titan_grip"):
		if slot == "weapon" and DB.is_two_handed(item):
			remove.append("offhand")
		elif slot == "offhand" and DB.is_two_handed(h["items"].get("weapon")):
			remove.append("weapon")
	var displaced: Array = []
	for key in remove:
		if h["items"].has(key):
			displaced.append(h["items"][key])
			h["items"].erase(key)
	h["items"][slot] = item
	return displaced


func _equipment_metrics(h: Dictionary, target: Dictionary) -> Dictionary:
	var members: Array = heroes.map(func(member): return h if member["cls"] == h["cls"] else member)
	var buffs := Calc.party_mods(members)
	var s := Calc.hero_stats(h, int(target["power"]), buffs)
	var o := Calc.offense(h, s, target)
	var hit: float = target["dmg"]
	var taken := Calc.damage_taken(s, hit, target["dmg_types"])
	if DB.role(h) == "tank":
		taken *= maxf(0.0, 1.0 - float(buffs["tank_less"]) / 100.0)
	return {
		"dps": o["dps"],
		"survival": s["max_life"] * hit / maxf(taken, 0.001),
		"healing": Calc.heal(h, s) * o["speed"],
	}


## Краткое сравнение с реальной заменой слота, без изменения вещей и RNG боя.
func compare_item(h: Dictionary, item: Dictionary, requested: String = "") -> Dictionary:
	if not DB.can_use(h, item):
		return {}
	var slot := equipment_slot(h, item, requested)
	var copy := h.duplicate(true)
	var removed := _replace_equipment(copy, item, slot)
	var target := enemy if not enemy.is_empty() else ref_enemy()
	return {"slot": slot, "target": target["name"], "removed": removed,
		"before": _equipment_metrics(h, target), "after": _equipment_metrics(copy, target)}


## Оценка только для тестового автопилота: игрок сам выбирает компромисс DPS/защита.
func _score_metrics(h: Dictionary, metrics: Dictionary) -> float:
	var ehp: float = metrics["survival"]
	var power: float = metrics["dps"]
	match DB.role(h):
		"healer":
			power = metrics["healing"] * 3.0 + metrics["dps"] * 0.3
		"support":
			power = metrics["healing"] + metrics["dps"]
		"tank":
			return sqrt(maxf(metrics["dps"], 0.1)) * ehp
	return power * sqrt(ehp)


## Насколько вещь усилит героя (1.0 = никак). Слот возвращается вторым элементом.
func upgrade_for(h: Dictionary, item: Dictionary) -> Array:
	if not DB.can_use(h, item) or Items.broken(item):
		return [1.0, ""]
	var best := 1.0
	var best_slot := ""
	for es in DB.equip_slots(item, h):
		var comparison := compare_item(h, item, es)
		var before := _score_metrics(h, comparison["before"])
		var after := _score_metrics(h, comparison["after"])
		var gain := after / maxf(before, 0.001)
		if gain > best:
			best = gain
			best_slot = es
	return [best, best_slot]


## Только для tools/sim.gd: имитирует решения активного игрока в лагере.
func equip_best() -> int:
	if not can_edit():
		return 0
	var n := 0
	for it in bag.duplicate():
		var best_i := -1
		var best := 1.02
		var best_slot := ""
		for i in heroes.size():
			var u := upgrade_for(heroes[i], it)
			if u[0] > best:
				best = u[0]
				best_i = i
				best_slot = u[1]
		if best_i >= 0:
			equip(best_i, it, best_slot)
			n += 1
			_log("%s надел [color=%s]%s[/color] (+%.0f%% силы)" % [DB.classes[heroes[best_i]["cls"]]["name"], DB.RARITY_COLORS[it["rarity"]], it["name"], (best - 1.0) * 100.0])
	return n


## Одинаковые по свойствам вещи остаются разными экземплярами.
func bag_index(item: Dictionary) -> int:
	for i in bag.size():
		if is_same(bag[i], item):
			return i
	return -1


func equip(hero_i: int, item: Dictionary, slot: String = "") -> String:
	if not can_edit():
		return "В походе снаряжение менять нельзя"
	var index := bag_index(item)
	if hero_i < 0 or hero_i >= heroes.size() or index < 0:
		return "Выбери вещь из сумки и героя"
	var h: Dictionary = heroes[hero_i]
	if not DB.can_use(h, item):
		return "Это не для «%s»" % DB.hero_name(h)
	slot = equipment_slot(h, item, slot)
	var copy := h.duplicate(true)
	if bag.size() - 1 + _replace_equipment(copy, item, slot).size() > BAG_CAP:
		return "Освободи место в сумке для снимаемых вещей"
	bag.remove_at(index)
	bag.append_array(_replace_equipment(h, item, slot))
	_recalc()
	_refresh_ui()
	return ""


func unequip(hero_i: int, slot: String) -> String:
	if not can_edit():
		return "В походе снаряжение менять нельзя"
	var h: Dictionary = heroes[hero_i]
	var it = h["items"].get(slot)
	if it == null:
		return ""
	if bag.size() >= BAG_CAP:
		return "Сумка полна"
	h["items"].erase(slot)
	bag.append(it)
	_recalc()
	_refresh_ui()
	return ""


func repair_cost() -> int:
	var sum := 0
	for cls in roster:
		for slot in roster[cls]["items"]:
			sum += Items.repair_cost(roster[cls]["items"][slot])
	return sum


## Починка: всё, что можно оплатить, сначала самое поломанное
func repair_all(quiet: bool = false) -> String:
	if not can_edit():
		return "Чинить можно только в лагере"
	var items: Array = []
	for cls in roster:
		for slot in roster[cls]["items"]:
			var it: Dictionary = roster[cls]["items"][slot]
			if float(it.get("dur", 100.0)) < 100.0:
				items.append(it)
	items.sort_custom(func(a, b): return float(a.get("dur", 100.0)) < float(b.get("dur", 100.0)))
	var spent := 0
	var fixed := 0
	for it in items:
		var c := Items.repair_cost(it)
		if c <= gold:
			gold -= c
			spent += c
			it["dur"] = 100.0
			fixed += 1
	_recalc()
	_refresh_ui()
	if fixed == 0:
		return "" if quiet else ("Нечего чинить" if items.is_empty() else "Не хватает золота")
	if not quiet or spent > 0:
		_log("Починка: %d вещей за %d з" % [fixed, spent])
	return "Починено %d вещей за %d з" % [fixed, spent]


func sell_item(item: Dictionary) -> void:
	var index := bag_index(item)
	if not can_edit() or index < 0:
		return
	bag.remove_at(index)
	gold += Items.sell_price(item)
	_refresh_ui()


func craft(item: Dictionary, cur_id: String) -> String:
	if not can_edit():
		return "Крафт доступен только в лагере"
	if int(wallet.get(cur_id, 0)) <= 0:
		return "Нет такой валюты"
	var err := Craft.check(item, cur_id)
	if err != "":
		return err
	wallet[cur_id] = int(wallet[cur_id]) - 1
	var msg := Craft.apply(item, cur_id)
	_recalc()
	_refresh_ui()
	return msg


func _worn(item: Dictionary) -> bool:
	for cls in roster:
		if item in roster[cls]["items"].values():
			return true
	return false


func _to_bag(item: Dictionary) -> void:
	bag.append(item)
	if bag.size() > BAG_CAP:
		var idx := 0
		for i in bag.size():
			if Items.sell_price(bag[i]) < Items.sell_price(bag[idx]):
				idx = i
		gold += Items.sell_price(bag[idx])
		bag.remove_at(idx)


func sell_bag() -> void:
	var sum := 0
	for it in bag:
		sum += Items.sell_price(it)
	gold += sum
	bag.clear()
	_refresh_ui()


# ================= ЦИКЛ =================

func _process(delta: float) -> void:
	t += delta
	hurt_flash = maxf(0.0, hurt_flash - delta)
	_update_floats(delta)
	step(delta)
	save_timer += delta
	if save_timer > 30.0 and not simulating:
		save_timer = 0.0
		save_game()
	if not simulating:
		_refresh_live()
	queue_redraw()


# ================= ИНТЕРФЕЙС =================

var ui_theme: Theme
var dashboard: Control

func _make_theme() -> Theme:
	var th := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.085, 0.065)
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_content_margin_all(3)
	var hover := normal.duplicate()
	hover.border_color = GOLD
	hover.bg_color = Color(0.16, 0.12, 0.085)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.16, 0.1)
	pressed.border_color = Color(1.0, 0.85, 0.5)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.07, 0.06, 0.05)
	disabled.border_color = Color(0.2, 0.17, 0.12)
	for st in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		th.set_stylebox(st[0], "Button", st[1])
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", PARCH)
	th.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.7))
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_hover_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", Color(0.4, 0.37, 0.32))
	th.set_color("font_color", "Label", PARCH)
	th.set_color("default_color", "RichTextLabel", PARCH)
	th.set_color("font_color", "CheckBox", PARCH)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.065, 0.055, 0.98)
	panel.border_color = GOLD_DIM
	panel.set_border_width_all(1)
	panel.set_content_margin_all(6)
	th.set_stylebox("panel", "TooltipPanel", panel)
	th.set_color("font_color", "TooltipLabel", PARCH)
	th.set_font_size("font_size", "TooltipLabel", 12)
	return th


func _build_ui() -> void:
	ui_theme = _make_theme()
	theme = ui_theme
	dashboard = preload("res://scripts/dashboard.gd").new()
	dashboard.game = self
	add_child(dashboard)
	log_label = dashboard.log_label


func _set_tab(id: String) -> void:
	meter_tab = id
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == id
	if log_label != null:
		log_label.visible = id == "log"


func _go_pressed() -> void:
	if mode == "run":
		retreat()
	else:
		var err := start_run()
		if err != "":
			_log("[color=#e06060]%s[/color]" % err)


func size_or_default() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


func _make_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_button(pos: Vector2, text: String, cb: Callable, sz: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.text = text
	b.size = sz
	b.add_theme_font_size_override("font_size", 11)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	add_child(b)
	return b


func _refresh_ui() -> void:
	if not simulating and dashboard != null:
		dashboard.refresh()


func _refresh_live() -> void:
	if dashboard != null:
		dashboard.refresh_live()


func _short(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % int(v)


var gear_window: Window = null
var camp_window: Window = null

func open_gear() -> void:
	dashboard.select_page("gear")


func open_camp() -> void:
	dashboard.select_page("camp")


func hint(id: String, text: String) -> void:
	if simulating or hints_shown.has(id):
		return
	hints_shown[id] = true
	_log("[color=#ffe066]Подсказка:[/color] " + text)


func _log(text: String) -> void:
	if log_label != null and not simulating:
		log_label.append_text(text + "\n")


# --- палитра в духе Diablo 2 ---
const GOLD := Color(0.85, 0.72, 0.42)
const GOLD_DIM := Color(0.42, 0.33, 0.18)
const PARCH := Color(0.86, 0.80, 0.66)
const BG := Color(0.055, 0.045, 0.04)
const INSET := Color(0.03, 0.025, 0.022)
const GROUND := 124.0
const ENEMY_X := 445.0
const SPRITE_SCALE := 2.0

var floats: Array = []   # всплывающие цифры и дроп: {text, pos, life, col, size}


func _hero_x(i: int) -> float:
	return 330.0 - i * 62.0


func _float(text: String, pos: Vector2, col: Color, sz: int = 12) -> void:
	if simulating or floats.size() > 40:
		return
	if dashboard != null and dashboard.arena != null:
		dashboard.arena.add_number(text, pos, col, sz)
	floats.append({"text": text, "pos": pos, "life": 1.0, "col": col, "size": sz})


func _update_floats(delta: float) -> void:
	for f in floats:
		f["life"] -= delta * 0.9
		f["pos"].y -= delta * 14.0
	floats = floats.filter(func(f): return f["life"] > 0.0)


func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/sprites/enemy_guard.png"):
		tex["enemy"] = load("res://assets/sprites/enemy_guard.png")
	for cls in DB.classes:
		for sp in DB.classes[cls]["specs"].values():
			var path := "res://assets/sprites/%s.png" % sp["sprite"]
			if ResourceLoader.exists(path):
				tex[sp["sprite"]] = load(path)
	if ResourceLoader.exists("res://assets/sprites/hunter_pet_wolf.png"):
		tex["wolf"] = load("res://assets/sprites/hunter_pet_wolf.png")


func _draw() -> void:
	if simulating or dashboard != null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_frame(Rect2(Vector2.ZERO, size), 3)
	_draw_arena()

	if mode == "run":
		var d := DB.dungeon(run["id"])
		draw_rect(Rect2(14, 13, 200, 18), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(14, 13, 200, 18), GOLD_DIM, false, 1.0)
		draw_string(font, Vector2(20, 27), "%s · %d/%d" % [d["name"].to_upper(), int(run["floor_i"]) + 1, d["floors"]], HORIZONTAL_ALIGNMENT_LEFT, 190, 11, GOLD)
		for k in PACKS_PER_FLOOR + 1:
			var c := Vector2(20 + k * 11, 40)
			var done: bool = k < run["pack"] - 1
			var cur: bool = k == run["pack"] - 1
			var col := GOLD if done else (Color(1, 0.9, 0.6) if cur else Color(0.3, 0.25, 0.18))
			if k == PACKS_PER_FLOOR:
				_skull(c + Vector2(3, 0), col if (done or cur) else Color(0.35, 0.18, 0.15))
			else:
				_diamond(c, 3.5 if cur else 3.0, col)
		if not enemy.is_empty():
			_draw_enemy(font)
	else:
		_draw_camp(font)

	for i in heroes.size():
		_draw_hero(i)

	for f in floats:
		var c: Color = f["col"]
		c.a = clampf(f["life"] * 1.5, 0.0, 1.0)
		draw_string_outline(font, f["pos"], f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, f["size"], 3, Color(0, 0, 0, c.a))
		draw_string(font, f["pos"], f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, f["size"], c)

	# средняя панель и правая панель
	var mid := Rect2(BATTLE_W + 6, 8, 278, size.y - 16)
	draw_rect(mid, INSET)
	draw_rect(mid, GOLD_DIM, false, 1.0)
	if meter_tab != "log":
		_draw_meter(font, Rect2(mid.position + Vector2(4, 24), mid.size - Vector2(8, 28)))
	var right := Rect2(BATTLE_W + 290, 8, size.x - BATTLE_W - 298, size.y - 16)
	draw_rect(right, Color(0.075, 0.062, 0.052))
	draw_rect(right, GOLD_DIM, false, 1.0)
	_draw_wallet(font, Vector2(BATTLE_W + 298, 60))
	for i in heroes.size():
		var hb: Button = hero_buttons[i] if i < hero_buttons.size() else null
		if hb == null:
			continue
		var ratio: float = heroes[i]["life"] / maxf(stats[i]["max_life"], 1.0)
		var r := Rect2(hb.position + Vector2(0, -5), Vector2(hb.size.x, 3))
		draw_rect(r, Color(0.15, 0.05, 0.05))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0, 1), 3)), Color(0.8, 0.15, 0.12))


func _draw_arena() -> void:
	var arena := Rect2(8, 8, BATTLE_W - 8, size.y - 16)
	draw_rect(arena, Color(0.09, 0.075, 0.065))
	var moving := mode == "run"
	var off := fmod(t * 18.0, 32.0) if moving else 0.0
	for row in 7:
		var y := 8.0 + row * 18.0
		if y > GROUND:
			break
		var shift := 16.0 if row % 2 == 1 else 0.0
		var x := 8.0 - off + shift - 32.0
		while x < BATTLE_W:
			var r := Rect2(maxf(x, 8.0), y, minf(30.0, BATTLE_W - maxf(x, 8.0)), minf(16.0, GROUND - y))
			if r.size.x > 0:
				var shade := 0.11 + 0.025 * sin(x * 0.37 + row * 1.7)
				draw_rect(r, Color(shade, shade * 0.85, shade * 0.75))
			x += 32.0
	for tx in [60.0, 400.0]:
		var fx: float = tx
		var flick := 0.8 + 0.2 * sin(t * 13.0 + tx) * sin(t * 7.3)
		draw_circle(Vector2(fx, 52), 26.0 * flick, Color(1.0, 0.55, 0.15, 0.07))
		draw_circle(Vector2(fx, 52), 13.0 * flick, Color(1.0, 0.6, 0.2, 0.12))
		draw_rect(Rect2(fx - 2, 54, 4, 12), Color(0.3, 0.2, 0.12))
		draw_circle(Vector2(fx, 50), 4.0 * flick, Color(1.0, 0.7, 0.25))
		draw_circle(Vector2(fx, 48), 2.0 * flick, Color(1.0, 0.95, 0.6))
	draw_rect(Rect2(8, GROUND, BATTLE_W - 8, size.y - GROUND - 8), Color(0.13, 0.105, 0.085))
	draw_line(Vector2(8, GROUND), Vector2(BATTLE_W, GROUND), Color(0.25, 0.2, 0.14), 1.0)
	for k in 6:
		var a := 0.12 - k * 0.02
		draw_rect(Rect2(8 + k * 4, 8, 4, size.y - 16), Color(0, 0, 0, a))
		draw_rect(Rect2(BATTLE_W - 4 - k * 4, 8, 4, size.y - 16), Color(0, 0, 0, a))


func _draw_camp(font: Font) -> void:
	# костёр
	var fire := Vector2(430, GROUND - 4)
	var flick := 0.8 + 0.2 * sin(t * 11.0) * sin(t * 6.1)
	draw_circle(fire + Vector2(0, -8), 34.0 * flick, Color(1.0, 0.5, 0.15, 0.08))
	draw_line(fire + Vector2(-12, 3), fire + Vector2(12, -2), Color(0.35, 0.22, 0.12), 4.0)
	draw_line(fire + Vector2(-12, -2), fire + Vector2(12, 3), Color(0.3, 0.2, 0.1), 4.0)
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-8, 0), fire + Vector2(0, -22 * flick), fire + Vector2(8, 0)]), Color(1.0, 0.5, 0.15))
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-4, 0), fire + Vector2(0, -12 * flick), fire + Vector2(4, 0)]), Color(1.0, 0.9, 0.5))
	draw_rect(Rect2(14, 13, 250, 18), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(14, 13, 250, 18), GOLD_DIM, false, 1.0)
	var txt := "ЛАГЕРЬ"
	match last_result:
		"win": txt = "ЛАГЕРЬ · данж пройден"
		"wipe": txt = "ЛАГЕРЬ · отряд погиб"
		"retreat": txt = "ЛАГЕРЬ · отступили"
	if repeat_run and not heroes.is_empty():
		txt += " · снова через %d" % ceili(CAMP_PAUSE - camp_timer)
	draw_string(font, Vector2(20, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, 240, 11, GOLD)
	if heroes.is_empty():
		draw_string(font, Vector2(20, 60), "Собери отряд в «Лагере»", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCH)


func _draw_meter(font: Font, r: Rect2) -> void:
	if meter.is_empty():
		draw_string(font, r.position + Vector2(4, 14), "Счётчик появится в походе", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.4))
		return
	if meter_tab == "deaths":
		var y := r.position.y + 12
		var list: Array = meter["deaths"]
		if list.is_empty():
			draw_string(font, Vector2(r.position.x + 4, y), "Никто не умер", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.8, 0.5))
		for k in range(maxi(0, list.size() - 7), list.size()):
			var e: Dictionary = list[k]
			draw_string(font, Vector2(r.position.x + 4, y), "%d:%02d эт.%d  %s ← %s (%d)" % [int(e["t"]) / 60, int(e["t"]) % 60, e["floor"], e["who"], e["by"], int(e["hit"])], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 10, Color(1.0, 0.6, 0.55))
			y += 14
		return
	var vals: Array = meter[meter_tab]
	var total := 0.0
	var top := 1.0
	for v in vals:
		total += v
		top = maxf(top, v)
	var order := range(vals.size())
	order.sort_custom(func(a, b): return vals[a] > vals[b])
	var secs := maxf(1.0, float(run.get("t", 1.0)))
	var y := r.position.y
	for i in order:
		if i >= heroes.size():
			continue
		var h: Dictionary = heroes[i]
		var col := Color(DB.classes[h["cls"]]["color"])
		var w: float = r.size.x * vals[i] / top
		draw_rect(Rect2(r.position.x, y, r.size.x, 19), Color(0.08, 0.07, 0.06))
		draw_rect(Rect2(r.position.x, y, w, 19), col.darkened(0.35))
		draw_string(font, Vector2(r.position.x + 4, y + 14), DB.classes[h["cls"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color.WHITE)
		var pct: float = 100.0 * vals[i] / maxf(total, 1.0)
		draw_string(font, Vector2(r.end.x - 4, y + 14), "%s (%s/с, %d%%)" % [_short(vals[i]), _short(vals[i] / secs), int(pct)], HORIZONTAL_ALIGNMENT_RIGHT, 160, 11, Color.WHITE)
		y += 21


func _frame(r: Rect2, inset: float) -> void:
	draw_rect(r.grow(-0.5), Color(0.2, 0.15, 0.09), false, 1.0)
	draw_rect(r.grow(-inset), GOLD_DIM, false, 1.0)
	for c in [r.position + Vector2(inset, inset), Vector2(r.end.x - inset, r.position.y + inset),
			Vector2(r.position.x + inset, r.end.y - inset), r.end - Vector2(inset, inset)]:
		_diamond(c, 4.0, GOLD)


func _diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)


func _skull(c: Vector2, col: Color) -> void:
	draw_circle(c + Vector2(0, -1), 4.5, col)
	draw_rect(Rect2(c + Vector2(-2.5, 2), Vector2(5, 3)), col)
	draw_circle(c + Vector2(-1.7, -1.5), 1.2, BG)
	draw_circle(c + Vector2(1.7, -1.5), 1.2, BG)


func _shadow(p: Vector2, w: float) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Кадр спрайта: 0 и 1 стойка, 2 атака
func _sprite(key: String, frame: int, feet: Vector2, fw: float, fh: float, tint: Color = Color.WHITE, rot: float = 0.0) -> void:
	var tx: Texture2D = tex.get(key)
	if tx == null:
		return
	var sz := Vector2(fw, fh) * SPRITE_SCALE
	if rot != 0.0:
		draw_set_transform(feet, rot, Vector2.ONE)
		draw_texture_rect_region(tx, Rect2(Vector2(-sz.x / 2, -sz.y), sz), Rect2(frame * fw, 0, fw, fh), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_texture_rect_region(tx, Rect2(feet - Vector2(sz.x / 2, sz.y), sz), Rect2(frame * fw, 0, fw, fh), tint)


func _draw_hero(i: int) -> void:
	var h: Dictionary = heroes[i]
	var x := _hero_x(i) - (40.0 if mode == "camp" else 0.0)
	var feet := Vector2(x, GROUND + 2)
	var dead: bool = h["life"] <= 0.0
	_shadow(feet + Vector2(0, -1), 14)
	var key: String = DB.spec(h)["sprite"]
	if dead:
		_sprite(key, 0, feet + Vector2(-20, -2), 32, 48, Color(0.45, 0.4, 0.4), -PI / 2)
		return
	var frame := 2 if attack_flash[i] > 0.0 else int(t * 2.0 + i * 0.7) % 2
	var tint := Color(0.85, 1.0, 0.85) if heal_flash[i] > 0.0 else Color.WHITE
	_sprite(key, frame, feet, 32, 48, tint)
	if h["cls"] == "hunter":
		var wolf_dead: bool = h.get("pet_dead", false)
		var wf := 2 if attack_flash[i] > 0.0 else int(t * 2.0) % 2
		var wpos := Vector2(370, GROUND + 2) if mode == "run" else Vector2(x + 30, GROUND + 2)
		if not wolf_dead:
			_shadow(wpos + Vector2(0, -1), 16)
			_sprite("wolf", wf, wpos, 32, 24)
	# полоска здоровья и маны над головой
	var head_y := GROUND - 92.0
	var ratio: float = h["life"] / maxf(stats[i]["max_life"], 1.0)
	var bar := Rect2(x - 15, head_y, 30, 3)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0, 1), 3)), Color(0.8, 0.12, 0.1))
	if stats[i]["max_mana"] > 0.0:
		var mr: float = h["mana"] / stats[i]["max_mana"]
		draw_rect(Rect2(bar.position + Vector2(0, 4), Vector2(30, 2)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position + Vector2(0, 4), Vector2(30 * clampf(mr, 0, 1), 2)), Color(0.3, 0.5, 1.0))
	# снаряд на атаке
	var atk: float = attack_flash[i] / 0.15
	if atk > 0.0 and mode == "run":
		var kind: String = DB.spec(h)["skill"]["kind"]
		var role := DB.role(h)
		if kind == "spell" or h["cls"] == "hunter":
			var col := Color(DB.classes[h["cls"]]["color"]).lightened(0.3)
			var p := Vector2(lerpf(x + 20, ENEMY_X - 14, 1.0 - atk), GROUND - 50)
			if h["cls"] == "hunter":
				draw_line(p - Vector2(10, 0), p, Color(0.9, 0.85, 0.7), 1.5)
			elif role != "healer" or heal_flash.max() <= 0.0:
				draw_circle(p, 6.0, Color(col.r, col.g, col.b, 0.3))
				draw_circle(p, 3.5, col)
		elif i == 0 or role == "tank":
			draw_arc(Vector2(x + 26, GROUND - 46), 18, -1.6, 0.6, 10, Color(1, 1, 1, 0.5 * atk), 2.0)


func _draw_enemy(font: Font) -> void:
	var big: bool = enemy["boss"]
	var rare: bool = enemy["rare"]
	var tint := Color(0.4, 0.38, 0.35)
	var types: Dictionary = enemy["dmg_types"]
	if types.has("fire"): tint = Color(0.55, 0.22, 0.12)
	if types.has("cold"): tint = Color(0.3, 0.42, 0.55)
	if types.has("lightning"): tint = Color(0.45, 0.42, 0.65)
	if types.has("chaos"): tint = Color(0.35, 0.2, 0.42)
	var sc := (1.9 if enemy["kind"] == "boss" else 1.6) if big else (1.25 if rare else 1.05)
	var x := ENEMY_X + (5.0 if hurt_flash > 0.0 else 0.0)
	var b := sin(t * 3.0) * 1.5
	_shadow(Vector2(x, GROUND), 14 * sc)
	if big or rare:
		var ac := Color(1.0, 0.5, 0.2, 0.12) if big else Color(1.0, 0.85, 0.3, 0.1)
		draw_circle(Vector2(x, GROUND - 18 * sc), 24 * sc, ac)
	var c := Vector2(x, GROUND - 14 * sc + b)
	draw_circle(c, 13 * sc, tint)
	draw_circle(c + Vector2(-6, -11) * sc, 8 * sc, tint.lightened(0.1))
	draw_line(c + Vector2(-10, -16) * sc, c + Vector2(-15, -24) * sc, Color(0.8, 0.75, 0.6), 2.0 * sc)
	draw_line(c + Vector2(-2, -17) * sc, c + Vector2(2, -25) * sc, Color(0.8, 0.75, 0.6), 2.0 * sc)
	draw_circle(c + Vector2(-9, -12) * sc, 1.6 * sc, Color(1, 0.25, 0.15))
	draw_circle(c + Vector2(-4, -12) * sc, 1.6 * sc, Color(1, 0.25, 0.15))
	draw_line(c + Vector2(-12, 2) * sc, c + Vector2(-20, 10) * sc, tint.darkened(0.3), 4.0 * sc)
	if hurt_flash > 0.0:
		draw_circle(c, 13 * sc, Color(1, 1, 1, 0.25))
	var nm: String = enemy["name"]
	var name_col := PARCH
	if big:
		name_col = Color(1.0, 0.55, 0.25)
	elif rare:
		name_col = Color(1.0, 0.85, 0.35)
	var plate := Rect2(368, 12, 144, 30)
	draw_rect(plate, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(plate.position.x + 5, plate.position.y + 12), nm.to_upper() if big else nm, HORIZONTAL_ALIGNMENT_LEFT, 134, 10, name_col)
	if not enemy["mods"].is_empty():
		draw_string(font, Vector2(plate.position.x + 5, plate.end.y + 10), ", ".join(enemy["mods"]), HORIZONTAL_ALIGNMENT_LEFT, 140, 9, Color(0.9, 0.6, 0.35))
	var hp := Rect2(plate.position.x + 5, plate.position.y + 18, plate.size.x - 10, 6)
	draw_rect(hp.grow(1), Color(0.2, 0.15, 0.1))
	draw_rect(hp, Color(0.12, 0.03, 0.03))
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * clampf(enemy["hp"] / enemy["max_hp"], 0, 1), 6)), Color(0.7, 0.12, 0.1))
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * clampf(enemy["hp"] / enemy["max_hp"], 0, 1), 2)), Color(0.95, 0.35, 0.3))


const WALLET_ICONS := {
	"ember_attack": Color(0.9, 0.35, 0.2), "ember_elemental": Color(0.35, 0.6, 1.0),
	"ember_defense": Color(0.6, 0.65, 0.7), "sand": Color(0.85, 0.75, 0.45),
	"chisel": Color(0.75, 0.9, 0.95), "oblivion": Color(0.75, 0.5, 0.95), "blight": Color(0.45, 0.85, 0.35),
}


func _draw_wallet(font: Font, pos: Vector2) -> void:
	var x := pos.x
	for c in DB.currency:
		var id: String = c["id"]
		var col: Color = WALLET_ICONS.get(id, GOLD)
		_diamond(Vector2(x + 4, pos.y - 4), 4.5, col)
		_diamond(Vector2(x + 3, pos.y - 5), 1.5, col.lightened(0.5))
		var n := str(int(wallet.get(id, 0)))
		draw_string(font, Vector2(x + 11, pos.y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PARCH)
		x += 16 + n.length() * 7


# ================= ОКНО =================

func _place_above_taskbar() -> void:
	var win := get_window()
	var area := DisplayServer.screen_get_usable_rect(win.current_screen)  # без панели задач
	win.position = Vector2i(area.position.x + (area.size.x - win.size.x) / 2, area.end.y - win.size.y)


func _gui_input(event: InputEvent) -> void:
	if dashboard != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_offset = DisplayServer.mouse_get_position() - get_window().position
	elif event is InputEventMouseMotion and dragging:
		get_window().position = DisplayServer.mouse_get_position() - drag_offset


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _quit() -> void:
	save_game()
	get_tree().quit()


# ================= СОХРАНЕНИЕ =================

func save_game() -> void:
	if simulating:
		return
	var data := {
		"roster": roster, "party_ids": party_ids, "cleared": cleared, "test_mode": test_mode,
		"selected_dungeon": selected_dungeon, "repeat_run": repeat_run, "gold": gold, "bag": bag,
		"wallet": wallet, "kills": kills, "wipes": wipes, "hints_shown": hints_shown,
		"time": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


func _load_game() -> void:
	if not FileAccess.file_exists(save_path):
		_log("Лагерь у подножия гор. Собери отряд в «Лагере», выбери данж и жми «В поход».")
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("roster"):
		return
	for cls in d["roster"]:
		if roster.has(cls):
			var h: Dictionary = d["roster"][cls]
			h["lvl"] = int(h["lvl"])
			h["xp"] = int(h["xp"])
			roster[cls] = h
	party_ids = d["party_ids"]
	cleared = d.get("cleared", {})
	test_mode = bool(d.get("test_mode", false))
	selected_dungeon = d.get("selected_dungeon", "crypt")
	repeat_run = bool(d.get("repeat_run", false))
	gold = int(d["gold"])
	bag = d["bag"]
	wallet = d.get("wallet", {})
	# Старое поле auto_equip игнорируем: добыча всегда остаётся в сумке.
	kills = int(d.get("kills", 0))
	wipes = int(d.get("wipes", 0))
	hints_shown = d.get("hints_shown", {})
	_set_party()
	# офлайн: отряд ходил в данж с автоповтором вполсилы
	var away := minf(Time.get_unix_time_from_system() - float(d["time"]), OFFLINE_CAP_SEC)
	var sec := int(away * OFFLINE_EFFICIENCY)
	if sec > 60 and repeat_run:
		var k0 := kills
		var g0 := gold
		simulating = true
		for i in sec:
			step(1.0)
		if mode == "run":
			_end_run("retreat")
			repeat_run = true
		simulating = false
		_log("Пока тебя не было (%d мин): убито %d, золота +%d" % [int(away / 60), kills - k0, gold - g0])
