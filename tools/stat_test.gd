extends SceneTree
## Проверка границ: тип экипировки, реальные коэффициенты, потолок роста и крафта.

var checks := 0
var failures := 0


func _initialize() -> void:
	DB.ensure()
	seed(504)
	var enemy := {"armour": 0.0, "res": {}}
	var mage := _hero("mage")
	var priest := _hero("priest")
	var warrior := _hero("warrior")
	var hunter := _hero("hunter")
	var strength_sword := Items.generate(8, "normal", "sword", "", "strength")
	var intellect_sword := Items.generate(8, "normal", "sword", "", "intellect")
	_ok(DB.can_use(mage, strength_sword), "маг носит меч силы: фильтр по типу, не по оптимальности")
	mage["items"]["weapon"] = strength_sword
	var poor := Calc.offense(mage, Calc.hero_stats(mage, 1), enemy)["dps"] as float
	mage["items"]["weapon"] = intellect_sword
	var suited := Calc.offense(mage, Calc.hero_stats(mage, 1), enemy)["dps"] as float
	_ok(suited > poor * 1.2, "меч интеллекта заметно усиливает заклинания по сравнению с мечом силы")
	var cloth := Items.generate(8, "normal", "armour", "cloth", "intellect")
	var plate := Items.generate(8, "normal", "armour", "plate", "strength")
	_ok(DB.can_use(mage, cloth) and not DB.can_use(mage, plate), "магу доступна ткань, латы пока закрыты")
	_ok(DB.can_use(warrior, plate) and not DB.can_use(warrior, cloth), "воин пока носит латы")
	for material in ["leather", "mail"]:
		_ok(DB.can_use(hunter, Items.generate(1, "normal", "armour", material, "agility")), "охотник носит " + material)
	_ok(not DB.can_use(hunter, cloth) and not DB.can_use(hunter, plate), "охотнику не подходят ткань и латы")
	for kind in ["staff", "dagger", "mace", "book", "talisman"]:
		_ok(DB.can_use(priest, Items.generate(1, "normal", kind, "", "intellect")), "жрец может носить " + kind)
	_ok(not DB.can_use(priest, strength_sword), "жрец не носит меч")
	_ok(DB.is_two_handed(Items.generate(1, "normal", "staff")), "посох занимает обе руки")
	var legacy := plate.duplicate(true)
	legacy.erase("armor_type")
	var before := legacy.duplicate(true)
	_ok(DB.can_use(mage, legacy), "старая броня без материала остаётся допустимой")
	mage["items"]["armour"] = legacy
	Calc.hero_stats(mage, 1)
	_ok(legacy == before, "расчёт статов не изменяет старые предметы")
	var sword := Items.for_hero(warrior, 1, "normal", "weapon")
	_ok(sword["slot"] == "weapon" and sword["profile"] == "strength", "обучение выдаёт оружие подходящего типа и профиля")
	var chest := Items.for_hero(warrior, 1, "normal", "armour")
	_ok(sword["implicit"]["strength"] > chest["implicit"]["strength"] * 2.0, "основной стат сосредоточен на оружии")
	warrior["items"] = {"weapon": sword, "offhand": Items.for_hero(warrior, 1, "normal", "shield")}
	var ws := Calc.hero_stats(warrior, 1)
	_ok(is_equal_approx(ws["attack_power"], ws["strength"] * 3.0 + ws["agility"]), "воин: 3AP за силу и 1AP за ловкость")
	var raw_armour: float = DB.spec(warrior)["base"]["armour"] + warrior["items"]["offhand"]["implicit"]["armour"]
	_ok(ws["block_chance"] > 0 and is_equal_approx(ws["armour"] - raw_armour, ws["strength"]), "танк получает ровно 1 броню за силу поверх базы и щита")
	var arms := _hero("warrior")
	arms["spec"] = "arms"
	arms["items"]["weapon"] = Items.for_hero(arms, 1, "normal", "weapon")
	var arms_stats := Calc.hero_stats(arms, 1)
	_ok(is_equal_approx(arms_stats["armour"] - float(DB.spec(arms)["base"]["armour"]), arms_stats["strength"]) and arms_stats["block_chance"] == 0.0, "сила даёт броню двуручнику, но не блок без щита")
	var no_block := ws.duplicate()
	no_block["block_chance"] = 0.0
	_ok(Calc.damage_taken(ws, 100, {"phys": 1.0}) < Calc.damage_taken(no_block, 100, {"phys": 1.0}), "блок реально снижает ожидаемый физический урон")
	_ok(is_equal_approx(Calc.damage_taken(ws, 100, {"fire": 1.0}), Calc.damage_taken(no_block, 100, {"fire": 1.0})), "блок не уменьшает огненный урон")
	warrior["items"]["offhand"]["dur"] = 0
	_ok(Calc.hero_stats(warrior, 1)["block_chance"] == 0.0, "сломанный щит не даёт блок")
	hunter["items"]["weapon"] = Items.for_hero(hunter, 8, "normal", "weapon")
	var hs := Calc.hero_stats(hunter, 1)
	_ok(is_equal_approx(hs["attack_power"], hs["agility"] * 3.0 + hs["strength"]), "охотник: 3AP за ловкость и 1AP за силу")
	var leather := Items.generate(8, "normal", "armour", "leather", "agility")
	var mail := Items.generate(8, "normal", "armour", "mail", "agility")
	_ok(not leather["implicit"].has("intellect") and mail["implicit"]["intellect"] > 0, "кольчуга отличается от кожи примесью интеллекта")
	hunter["items"]["armour"] = mail
	var mail_stats := Calc.hero_stats(hunter, 1)
	_ok(mail_stats["max_mana"] > hs["max_mana"] and mail_stats["mana_regen"] > hs["mana_regen"], "интеллект охотника увеличивает ману и её восполнение")
	_ok(mail_stats["spell_power"] > hs["spell_power"] and mail_stats["crit_spell"] > hs["crit_spell"], "интеллект повышает силу заклинаний и их крит")
	var ms := Calc.hero_stats(mage, 1)
	_ok(is_equal_approx(ms["spell_power"], ms["intellect"] * 3.0), "1 интеллект = 3 силы заклинаний")
	var level_one := Calc.hero_stats(priest, 1)
	var heal_one := Calc.heal(priest, level_one)
	priest["lvl"] = 999
	var high := Calc.hero_stats(priest, 1)
	_ok(high["max_life"] - level_one["max_life"] <= 30.01, "рост жизни от уровня ограничен 30")
	_ok(Calc.heal(priest, high) <= heal_one * 1.15 + 0.01, "рост базы умения от уровня ограничен 15%")
	for ilvl in [1, 8, 18, 28]:
		var item := Items.generate(ilvl, "rare", "sword")
		var cap := Items.capacity(item)
		var expected := 2 if ilvl == 1 else (6 if ilvl == 28 else 4)
		_ok(cap["total"] == expected, "вместимость ilvl%d = %d" % [ilvl, expected])
		for n in 25:
			for currency in ["ember_attack", "ember_elemental", "ember_defense"]:
				if Craft.check(item, currency) == "":
					Craft.apply(item, currency)
		var pre := 0
		var suf := 0
		for mod in item["mods"]:
			if mod["type"] == "prefix": pre += 1
			else: suf += 1
		_ok(pre <= cap["prefix"] and suf <= cap["suffix"], "повторный крафт не переполняет базу ilvl%d" % ilvl)
	var low := Items.generate(1, "normal", "sword")
	_ok(Items.add_mod(low, Items.affix_def("strength"), 3).is_empty() and low["mods"].is_empty(), "прямое добавление аффикса тоже не обходит ilvl")
	Items.add_mod(low, Items.affix_def("strength"), 0)
	_ok(Items.add_mod(low, Items.affix_def("agility"), 0).is_empty() and low["mods"].size() == 1, "прямое добавление не обходит вместимость суффиксов")
	_ok(Craft.check(low, "chisel") != "", "повышение тира ограничено ilvl")
	var unchanged := low.duplicate(true)
	Craft.apply(low, "chisel")
	_ok(low == unchanged, "недопустимый крафт не меняет вещь")
	print("Stat tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _hero(cls: String) -> Dictionary:
	return {"cls": cls, "spec": DB.classes[cls]["specs"].keys()[0], "lvl": 1, "xp": 0, "talents": {}, "items": {}}


func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
