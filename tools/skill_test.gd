extends SceneTree
## Базовые умения: явный выбор с уровня 1, честный предпросмотр и реальные компромиссы.

var checks := 0
var failed := 0


func _initialize() -> void:
	DB.ensure()
	var enemy := {"armour": 0.0, "res": {}}
	for cls in ["warrior", "priest", "mage", "hunter"]:
		for spec in DB.classes[cls]["specs"]:
			var hero := _hero(cls, spec)
			var options := DB.skill_options(hero)
			_ok(options.size() == 2 and options[0]["id"] != options[1]["id"], "%s/%s: два разных базовых умения" % [cls, spec])
			_ok(not DB.skill_selected(hero) and not hero.has("skill_id"), "предпросмотр не назначает умение автоматически")
			var fallback := Calc.offense(hero, Calc.hero_stats(hero, 1), enemy)
			var fallback_heal := Calc.heal(hero, Calc.hero_stats(hero, 1))
			hero["skill_id"] = options[0]["id"]
			_ok(is_equal_approx(Calc.offense(hero, Calc.hero_stats(hero, 1), enemy)["dps"], fallback["dps"]) and is_equal_approx(Calc.heal(hero, Calc.hero_stats(hero, 1)), fallback_heal), "первый выбор сохраняет численный баланс старого умения")
			for option in options:
				hero["skill_id"] = option["id"]
				var before := hero.duplicate(true)
				var stats := Calc.hero_stats(hero, 1)
				var offense := Calc.offense(hero, stats, enemy)
				var sheet := Calc.sheet(hero, stats, enemy)
				_ok(DB.skill_selected(hero) and is_finite(offense["dps"]) and offense["dps"] > 0 and sheet.contains(option["name"]), "%s: выбор первого уровня работает в расчёте и листе героя" % option["name"])
				_ok(hero == before, "предпросмотр не меняет героя и выбранное умение")
	var warrior := _hero("warrior", "prot")
	warrior["skill_id"] = "steel_rush"
	var offense_stats := Calc.hero_stats(warrior, 1)
	var offense_dps: float = Calc.offense(warrior, offense_stats, enemy)["dps"]
	warrior["skill_id"] = "guarded_strike"
	var guard_stats := Calc.hero_stats(warrior, 1)
	_ok(is_equal_approx(guard_stats["less_taken"] - offense_stats["less_taken"], 4.0), "защитный выпад добавляет ровно 4 процентных пункта снижения урона")
	_ok(Calc.damage_taken(guard_stats, 100.0, {"phys": 1.0}) < Calc.damage_taken(offense_stats, 100.0, {"phys": 1.0}), "защитный выбор действительно снижает входящий урон")
	_ok(Calc.offense(warrior, guard_stats, enemy)["dps"] < offense_dps, "дополнительная защита оплачена потерей урона")
	_ok(Calc.hero_stats(warrior, 1) == guard_stats, "повторный расчёт не накапливает бонус умения")
	warrior["skill_id"] = "weighted_shot"
	_ok(not DB.skill_selected(warrior) and DB.skill(warrior) == DB.spec(warrior)["skill"], "умение другого класса не считается выбранным")
	warrior["skill_id"] = "removed_option"
	_ok(not DB.skill_selected(warrior) and Calc.offense(warrior, Calc.hero_stats(warrior, 1), enemy)["dps"] > 0, "неизвестное умение допускает предпросмотр через безопасный fallback")
	warrior["skill_id"] = "steel_rush"
	warrior["spec"] = "arms"
	_ok(not DB.skill_selected(warrior), "смена ветки не превращает старый выбор в новый автоматически")
	var priest := _hero("priest", "light")
	priest["skill_id"] = "steady_light"
	var steady_stats := Calc.hero_stats(priest, 1)
	var steady_heal := Calc.heal(priest, steady_stats)
	var steady_speed: float = Calc.offense(priest, steady_stats, enemy)["speed"]
	priest["skill_id"] = "fleeting_light"
	var quick_stats := Calc.hero_stats(priest, 1)
	var quick_speed: float = Calc.offense(priest, quick_stats, enemy)["speed"]
	_ok(Calc.heal(priest, quick_stats) < steady_heal and quick_speed > steady_speed, "быстрое лечение слабее за каст, но действует чаще")
	_ok(is_equal_approx(quick_speed / steady_speed, 1.15), "при одинаковой цене каста быстрый свет тратит ману на 15% чаще")
	_ok(Calc.sheet(priest, quick_stats, enemy).contains("Быстрый отблеск"), "лист персонажа показывает имя выбранного лечения")
	priest["spec"] = "shadow"
	priest["skill_id"] = "sheltered_dusk"
	_ok(Calc.heal(priest, Calc.hero_stats(priest, 1)) == 0.0, "защитное умение тьмы не выдаёт несуществующее лечение")
	var mage := _hero("mage", "elem")
	var resistant := {"armour": 0.0, "res": {"cold": 75.0}}
	mage["skill_id"] = "ember_frost"
	var split: float = Calc.offense(mage, Calc.hero_stats(mage, 1), resistant)["dps"]
	mage["skill_id"] = "frost_lance"
	var focused := Calc.offense(mage, Calc.hero_stats(mage, 1), enemy)
	_ok(focused["by_type"].get("fire", 0.0) == 0.0 and focused["by_type"]["cold"] > 0.0, "ледяной выбор меняет базовый тип урона")
	_ok(Calc.offense(mage, Calc.hero_stats(mage, 1), resistant)["dps"] < split, "против высокого сопротивления холоду двухстихийный выбор полезнее")
	var hunter := _hero("hunter", "beast")
	hunter["skill_id"] = "quick_shot"
	var bare_quick: float = Calc.offense(hunter, Calc.hero_stats(hunter, 1), enemy)["dps"]
	hunter["skill_id"] = "weighted_shot"
	var bare_heavy: float = Calc.offense(hunter, Calc.hero_stats(hunter, 1), enemy)["dps"]
	_ok(bare_heavy > bare_quick, "слабое оружие оставляет смысл сильному базовому выстрелу")
	hunter["items"]["weapon"] = Items.for_hero(hunter, 1, "normal", "weapon")
	var geared_heavy: float = Calc.offense(hunter, Calc.hero_stats(hunter, 1), enemy)["dps"]
	hunter["skill_id"] = "quick_shot"
	_ok(Calc.offense(hunter, Calc.hero_stats(hunter, 1), enemy)["dps"] > geared_heavy, "плоский урон оружия усиливает быстрые выстрелы чаще")
	var future := _hero("shaman", "elements")
	_ok(DB.skill_options(future).is_empty() and not DB.skill_selected(future) and Calc.heal(future, Calc.hero_stats(future, 1)) > 0.0, "будущий класс сохраняет старый расчёт без открытия новых умений")
	print("Skill tests: %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)


func _hero(cls: String, spec: String) -> Dictionary:
	return {"cls": cls, "spec": spec, "lvl": 1, "xp": 0, "talents": {}, "items": {}}


func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(label)
