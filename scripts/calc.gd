class_name Calc
## Формулы боя. Всё, что нужно теорикрафтерам, считается здесь.
##   урон = (база умения × уровень + плоский) → конверсия →
##          × (1 + Σ increased) → защита врага → крит → × скорость

const RES_CAP := 75.0
# Коэффициенты прототипа, вынесены отдельно для настройки баланса.
const LEVEL_DMG := 0.005    # +0.5% к базе за уровень, максимум +15%
const LEVEL_LIFE := 1.0     # +1 здоровья за уровень, максимум +30
const MAIN_ATTACK_RATIO := 3.0
const OFF_ATTACK_RATIO := 1.0
const INTELLECT_SPELL_RATIO := 3.0
const ATTACK_SKILL_RATIO := 0.25
const SPELL_SKILL_RATIO := 0.30
const HEAL_POWER_RATIO := 0.40
const INTELLECT_MANA_RATIO := 5.0
const INTELLECT_REGEN_RATIO := 1.0
const STAT_CRIT_RATIO := 0.06 # процентных пункта за единицу стата
const AGILITY_DODGE_RATIO := 0.04
const STRENGTH_BLOCK_RATIO := 0.06
const BLOCK_FRACTION := 0.30


static func level_multiplier(level: int) -> float:
	return 1.0 + minf(0.15, LEVEL_DMG * maxi(0, level - 1))


static func crit_chance(s: Dictionary, kind: String) -> float:
	return float(s.get("crit_attack" if kind == "attack" else "crit_spell", minf(100.0, s.get("crit_chance", 5.0) * (1.0 + s.get("inc_crit", 0.0) / 100.0))))


## Сводные статы героя: ветка + уровень + таланты + бафы отряда + шмот (сломанный не считается)
static func hero_stats(hero: Dictionary, floor_n: int, party: Dictionary = {}) -> Dictionary:
	DB.ensure()
	var sp := DB.spec(hero)
	var s: Dictionary = {}
	var add := func(src: Dictionary) -> void:
		for k in src:
			s[k] = s.get(k, 0.0) + float(src[k])
	add.call(sp["base"])
	add.call(sp.get("passive", {}))
	add.call(DB.skill(hero).get("stats", {}))
	for tier in DB.talent_tiers(hero):
		var pick = hero.get("talents", {}).get(str(int(tier["lvl"])))
		if pick != null and int(hero["lvl"]) >= int(tier["lvl"]) and int(pick) < tier["options"].size():
			add.call(tier["options"][int(pick)].get("stats", {}))
	add.call(party.get("party", {}))
	s["life"] = s.get("life", 0.0) + minf(30.0, LEVEL_LIFE * maxi(0, int(hero["lvl"]) - 1))
	var weapon = hero["items"].get("weapon")
	var off_blocked: bool = DB.is_two_handed(weapon) and not DB.has_talent_flag(hero, "titan_grip")
	for slot in DB.SLOTS:
		var it = hero["items"].get(slot)
		if it == null or Items.broken(it) or (slot == "offhand" and off_blocked):
			continue
		add.call(Items.stats_of(it))
	var strength: float = s.get("strength", 0.0)
	var agility: float = s.get("agility", 0.0)
	var intellect: float = s.get("intellect", 0.0)
	var main := DB.main_stat(hero)
	s["strength"] = strength
	s["agility"] = agility
	s["intellect"] = intellect
	s["attack_power"] = s.get("attack_power", 0.0) + strength * (MAIN_ATTACK_RATIO if main == "strength" else OFF_ATTACK_RATIO) + agility * (MAIN_ATTACK_RATIO if main == "agility" else OFF_ATTACK_RATIO) + intellect * float(sp.get("intellect_attack_ratio", 0.0))
	s["spell_power"] = s.get("spell_power", 0.0) + intellect * INTELLECT_SPELL_RATIO
	s["mana"] = s.get("mana", 0.0) + intellect * INTELLECT_MANA_RATIO
	s["mana_regen"] = s.get("mana_regen", 0.0) + intellect * INTELLECT_REGEN_RATIO
	var crit_mult: float = 1.0 + s.get("inc_crit", 0.0) / 100.0
	s["crit_attack"] = minf(100.0, (s.get("crit_chance", 5.0) + agility * STAT_CRIT_RATIO) * crit_mult)
	s["crit_spell"] = minf(100.0, (s.get("crit_chance", 5.0) + intellect * STAT_CRIT_RATIO) * crit_mult)
	s["dodge_chance"] = clampf(s.get("dodge_chance", 0.0) + agility * AGILITY_DODGE_RATIO, 0.0, 25.0)
	var offhand = hero["items"].get("offhand")
	var has_shield: bool = offhand != null and offhand["kind"] == "shield" and not Items.broken(offhand) and not off_blocked
	if main == "strength":
		s["armour"] = s.get("armour", 0.0) + strength
	if DB.role(hero) == "tank":
		s["block_chance"] = clampf(s.get("block_chance", 0.0) + 5.0 + strength * STRENGTH_BLOCK_RATIO, 0.0, 40.0) if has_shield else 0.0
	else:
		s["block_chance"] = minf(40.0, s.get("block_chance", 0.0)) if has_shield else 0.0
	s["block_fraction"] = BLOCK_FRACTION
	s["armour"] = s.get("armour", 0.0) * (1.0 + s.get("inc_armour", 0.0) / 100.0)
	for e in DB.ELEMENTS:
		s["res_" + e] = s.get("res_" + e, 0.0) + s.get("res_all_ele", 0.0)
	# штраф к сопротивлениям с глубиной, как акты в PoE: -10% каждые 5 этажей, до -60%
	var penalty := minf(60.0, 10.0 * floori((floor_n - 1) / 5.0))
	s["res_penalty"] = penalty
	for t in DB.ELEMENTS + ["chaos"]:
		var raw: float = s.get("res_" + t, 0.0) - penalty
		s["res_" + t + "_raw"] = raw
		s["res_" + t] = minf(RES_CAP, raw)
	s["max_life"] = s.get("life", 0.0) * (1.0 + s.get("inc_life", 0.0) / 100.0)
	s["max_mana"] = s.get("mana", 0.0)
	return s


## Бафы отряда: что каждый класс даёт всем, плюс тотемы шамана и таланты с party
static func party_mods(party: Array) -> Dictionary:
	var out := {"party": {}, "enemy": {"miss": 0.0, "slow": 0.0}, "tank_less": 0.0, "names": []}
	var add := func(src: Dictionary, k: float) -> void:
		for key in src:
			out["party"][key] = out["party"].get(key, 0.0) + float(src[key]) * k
	var classes_in: Array = party.map(func(h): return h["cls"])
	for h in party:
		var cls: Dictionary = DB.classes[h["cls"]]
		var buff: Dictionary = cls["buff"]
		add.call(buff.get("party", {}), 1.0)
		for key in buff.get("enemy", {}):
			out["enemy"][key] += float(buff["enemy"][key])
		out["names"].append(buff["name"])
		for tier in DB.talent_tiers(h):
			var pick = h.get("talents", {}).get(str(int(tier["lvl"])))
			if pick != null and int(h["lvl"]) >= int(tier["lvl"]) and int(pick) < tier["options"].size():
				add.call(tier["options"][int(pick)].get("party", {}), 1.0)
		if h["cls"] == "shaman":
			var own := hero_stats(h, 1)
			var k: float = 1.0 + own.get("totem_mult", 0.0) / 100.0
			add.call({"regen": 0.3, "mana_regen": 25}, k)                      # тотем воды
			out["tank_less"] += (10.0 + own.get("earth_bonus", 0.0)) * k       # тотем земли
			var copy: String = h.get("illusion", "")                           # тотем иллюзии
			if copy == "" or not (copy in classes_in) or copy == "shaman":
				copy = ""
				for c in classes_in:
					if c != "shaman":
						copy = c
						break
			add.call({"inc_dmg": 3}, k)
			if copy != "":
				var b: Dictionary = DB.classes[copy]["buff"]
				add.call(b.get("party", {}), 0.5 * k)
				for key in b.get("enemy", {}):
					out["enemy"][key] += float(b["enemy"][key]) * 0.5 * k
				out["names"].append("Иллюзия: " + b["name"])
	return out


## Исцеление за один каст (среднее, с учётом крита)
static func heal(hero: Dictionary, s: Dictionary) -> float:
	var sk := DB.skill(hero)
	if not sk.has("heal"):
		return 0.0
	var lvl_mult := level_multiplier(int(hero["lvl"]))
	var h: float = (float(sk["heal"]) * lvl_mult + s.get("flat_heal", 0.0) + s.get("spell_power", 0.0) * HEAL_POWER_RATIO) * (1.0 + s.get("inc_heal", 0.0) / 100.0)
	return h * (1.0 + crit_chance(s, "spell") / 100.0 * (s.get("crit_multi", 150.0) / 100.0 - 1.0))


## Урон героя по конкретному врагу. Возвращает dps и разбор по шагам.
static func offense(hero: Dictionary, s: Dictionary, enemy: Dictionary) -> Dictionary:
	var skill := DB.skill(hero)
	var lvl_mult := level_multiplier(int(hero["lvl"]))
	var attack: bool = skill["kind"] == "attack"
	var power: float = s.get("attack_power", 0.0) * ATTACK_SKILL_RATIO if attack else s.get("spell_power", 0.0) * SPELL_SKILL_RATIO
	var base_total := 0.0
	for base_type in skill["base"]:
		base_total += float(skill["base"][base_type])

	# 1. база + плоский урон
	var raw := {}
	for t in DB.DAMAGE_TYPES:
		var base: float = float(skill["base"].get(t, 0.0))
		# Сила атаки/заклинаний распределяется по собственным типам умения.
		var flat: float = s.get("flat_" + t, 0.0) if attack or t != "phys" else 0.0
		raw[t] = base * lvl_mult + flat + power * base / maxf(1.0, base_total)

	# 2. конверсия физ → стихии (сумма больше 100% масштабируется вниз)
	var conv := {}
	var conv_total := 0.0
	for e in DB.ELEMENTS:
		conv[e] = s.get("conv_phys_" + e, 0.0)
		conv_total += conv[e]
	var scale := 1.0 if conv_total <= 100.0 else 100.0 / conv_total
	# части урона: тип и откуда пришёл (сконвертированное получает бонусы обоих типов)
	var parts: Array = []
	var phys_left: float = raw["phys"]
	for e in DB.ELEMENTS:
		var amount: float = raw["phys"] * conv[e] * scale / 100.0
		if amount > 0.0:
			parts.append({"type": e, "from_phys": true, "amount": amount})
			phys_left -= amount
	parts.append({"type": "phys", "from_phys": false, "amount": phys_left})
	for t in ["fire", "cold", "lightning", "chaos", "arcane", "holy"]:
		if raw[t] > 0.0:
			parts.append({"type": t, "from_phys": false, "amount": raw[t]})
	# питомец: волк охотника бьёт физом, бес чернокнижника огнём
	var pet: float = s.get("pet_mult", 0.0)
	if pet > 0.0 and not hero.get("pet_dead", false):
		var total := 0.0
		for t in raw:
			total += raw[t]
		parts.append({"type": "fire" if hero["cls"] == "warlock" else "phys", "from_phys": false, "amount": total * pet / 100.0, "pet": true})

	# 3. increased (складываются) и 4. защита врага
	var by_type := {}
	var hit := 0.0
	var hit_unmitigated := 0.0
	for p in parts:
		var t: String = p["type"]
		var inc: float = s.get("inc_dmg", 0.0) + s.get("inc_" + t, 0.0)
		inc += s.get("inc_attack" if skill["kind"] == "attack" else "inc_spell", 0.0)
		if t in DB.ELEMENTS:
			inc += s.get("inc_elemental", 0.0)
		if p["from_phys"]:
			inc += s.get("inc_phys", 0.0)
		var dmg: float = p["amount"] * (1.0 + inc / 100.0)
		hit_unmitigated += dmg
		dmg *= mitigation(t, dmg, enemy, s)
		by_type[t] = by_type.get(t, 0.0) + dmg
		hit += dmg

	# 5. крит
	var crit_chance := crit_chance(s, skill["kind"])
	var crit_multi: float = s.get("crit_multi", 150.0)
	var crit_factor := 1.0 + crit_chance / 100.0 * (crit_multi / 100.0 - 1.0)

	# 6. скорость
	var speed: float = float(skill["speed"]) * maxf(0.2, 1.0 + s.get("inc_speed", 0.0) / 100.0)
	return {
		"dps": hit * crit_factor * speed,
		"dps_no_def": hit_unmitigated * crit_factor * speed,
		"hit": hit, "by_type": by_type, "speed": speed,
		"crit_chance": crit_chance, "crit_multi": crit_multi,
	}


## Какая доля урона проходит через защиту врага
static func mitigation(t: String, hit_size: float, enemy: Dictionary, s: Dictionary) -> float:
	if t == "phys":
		var a: float = enemy.get("armour", 0.0)
		return 1.0 - minf(0.9, a / (a + 10.0 * maxf(hit_size, 1.0)))
	var res: float = enemy["res"].get(t, 0.0) - s.get("pen_" + t, 0.0)
	if t == "holy" or t == "arcane":
		res = enemy["res"].get("fire", 0.0) * 0.4 - s.get("pen_" + t, 0.0)  # тайной магии и свету враги почти не сопротивляются
	return maxf(0.0, 1.0 - res / 100.0)  # резист выше 100% = иммунитет, но не лечит врага


## Урон, который герой получает от удара врага (по типам)
static func damage_taken(s: Dictionary, hit: float, dmg_types: Dictionary) -> float:
	var total := 0.0
	for t in dmg_types:
		var d: float = hit * float(dmg_types[t])
		if t == "phys":
			var a: float = s.get("armour", 0.0)
			d *= 1.0 - minf(0.9, a / (a + 10.0 * maxf(d, 1.0)))
			# В автобое считаем среднее: уклонение и блок защищают от физических атак.
			d *= 1.0 - clampf(s.get("dodge_chance", 0.0), 0.0, 25.0) / 100.0
			d *= 1.0 - clampf(s.get("block_chance", 0.0), 0.0, 40.0) / 100.0 * s.get("block_fraction", BLOCK_FRACTION)
		else:
			d *= 1.0 - s.get("res_" + t, 0.0) / 100.0
		total += d
	return total * maxf(0.2, 1.0 - s.get("less_taken", 0.0) / 100.0)


## Лист персонажа для подсказки: откуда берётся каждая цифра
static func sheet(hero: Dictionary, s: Dictionary, enemy: Dictionary) -> String:
	var sp := DB.spec(hero)
	var selected_skill := DB.skill(hero)
	var L: Array[String] = []
	L.append("%s, ур. %d (опыт %d/%d), роль: %s" % [DB.hero_name(hero), hero["lvl"], hero["xp"], xp_to_next(hero["lvl"]), DB.ROLE_NAMES[sp["role"]]])
	if not enemy.is_empty():
		var o := offense(hero, s, enemy)
		L.append("Умение: %s, %.2f в сек." % [selected_skill["name"], o["speed"]])
		var parts: Array[String] = []
		for t in o["by_type"]:
			if o["by_type"][t] > 0.5:
				parts.append("%s %.0f" % [DB.TYPE_NAMES[t], o["by_type"][t]])
		L.append("Удар по врагу: %.0f (%s)" % [o["hit"], ", ".join(parts)])
		L.append("Крит: %.1f%% × %.0f%%" % [o["crit_chance"], o["crit_multi"]])
		L.append("DPS по врагу: %.0f   без его защиты: %.0f" % [o["dps"], o["dps_no_def"]])
	if selected_skill.has("heal"):
		L.append("%s: %.0f за каст, мана %.0f" % [selected_skill["heal_name"], heal(hero, s), s["max_mana"]])
	L.append("Здоровье %.0f   броня %.0f   снижение урона %.0f%%" % [s["max_life"], s.get("armour", 0.0), s.get("less_taken", 0.0)])
	L.append("Сила %.2f · Ловкость %.2f · Интеллект %.2f" % [s.get("strength", 0.0), s.get("agility", 0.0), s.get("intellect", 0.0)])
	L.append("Сила атаки %.2f · Сила заклинаний %.2f" % [s.get("attack_power", 0.0), s.get("spell_power", 0.0)])
	L.append("Уклонение %.2f%% · Блок %.2f%% (снимает %.0f%% физического удара, средний расчёт)" % [s.get("dodge_chance", 0.0), s.get("block_chance", 0.0), 100.0 * BLOCK_FRACTION])
	L.append("Сопр.: огонь %.0f%%  холод %.0f%%  молния %.0f%%  хаос %.0f%%  (штраф глубины -%.0f%%)" % [
		s["res_fire"], s["res_cold"], s["res_lightning"], s["res_chaos"], s["res_penalty"]])
	var broken := 0
	for slot in DB.SLOTS:
		var it = hero["items"].get(slot)
		if it != null and Items.broken(it):
			broken += 1
	if broken > 0:
		L.append("Сломано вещей: %d (не дают статов, почини в лагере)" % broken)
	return "\n".join(L)


static func xp_to_next(lvl: int) -> int:
	return int(40.0 * pow(1.3, lvl - 1))
