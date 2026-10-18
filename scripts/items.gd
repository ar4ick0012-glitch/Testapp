class_name Items
## Генерация предметов: база, редкость, префиксы и суффиксы с тирами.
## Предмет это словарь:
## {kind, slot, base, rarity, ilvl, name, implicit: {stat: v}, mods: [{id, stat, tier, value, type}]}

const WEAPON_KINDS := ["sword", "bow", "staff", "greatsword", "mace", "dagger"]
const OFFHAND_KINDS := ["shield", "quiver", "orb", "book", "talisman"]
const ARMOUR_KINDS := ["helmet", "armour", "gloves", "boots"]
const MAX_PREFIX := 3
const MAX_SUFFIX := 3

const RARE_FIRST := ["Гибельный", "Чёрный", "Кровавый", "Пепельный", "Могильный", "Вороний", "Тёмный", "Скорбный"]
const RARE_SECOND := ["Шёпот", "Клык", "Рок", "Зов", "Оскал", "Вой", "Знак", "Обет"]


static func roll_rarity(rare_bonus: float = 1.0) -> String:
	var w_rare := 10.0 * rare_bonus
	var w_magic := 35.0
	var w_normal := 55.0
	var r := randf() * (w_rare + w_magic + w_normal)
	if r < w_rare:
		return "rare"
	if r < w_rare + w_magic:
		return "magic"
	return "normal"


static func roll_kind() -> String:
	var r := randf()
	if r < 0.2:
		return WEAPON_KINDS[randi() % WEAPON_KINDS.size()]
	if r < 0.3:
		return OFFHAND_KINDS[randi() % OFFHAND_KINDS.size()]
	if r < 0.7:
		return ARMOUR_KINDS[randi() % ARMOUR_KINDS.size()]
	if r < 0.8:
		return "belt"
	if r < 0.9:
		return "amulet"
	return "ring"


static func slot_of(kind: String) -> String:
	if kind in WEAPON_KINDS:
		return "weapon"
	if kind in OFFHAND_KINDS:
		return "offhand"
	return kind


static func generate(ilvl: int, rarity: String = "", kind: String = "", armor_type: String = "", profile: String = "") -> Dictionary:
	DB.ensure()
	ilvl = maxi(1, ilvl)
	if kind == "":
		kind = roll_kind()
	if rarity == "":
		rarity = roll_rarity()
	if kind in ARMOUR_KINDS and armor_type == "":
		armor_type = DB.ARMOR_NAMES.keys().pick_random()
	if profile == "":
		if armor_type == "cloth" or kind in ["staff", "orb", "book", "talisman"]:
			profile = "intellect"
		elif armor_type in ["leather", "mail"] or kind in ["bow", "quiver", "dagger"]:
			profile = "agility"
		else:
			profile = "strength"
	# база: случайная из доступных по ilvl, чаще самые новые
	var avail: Array = DB.bases[kind].filter(func(b): return int(b["ilvl"]) <= ilvl and (armor_type == "" or b.get("armor_type", "") == armor_type))
	var base: Dictionary = avail[randi() % avail.size()]
	if avail.size() > 1 and randf() < 0.5:
		base = avail[avail.size() - 1]
	var item := {
		"kind": kind, "slot": slot_of(kind), "base": base["name"], "rarity": rarity,
		"ilvl": ilvl, "implicit": base["implicit"].duplicate(), "mods": [], "name": "",
	}
	item["profile"] = profile
	if kind in ARMOUR_KINDS:
		item["armor_type"] = armor_type
	# ilvl усиливает базу плавно; материал и основной стат — разные признаки.
	var scale := 1.0 + 0.025 * maxi(0, ilvl - int(base["ilvl"]))
	for stat in item["implicit"]:
		item["implicit"][stat] = snappedf(float(item["implicit"][stat]) * scale, 0.01)
	var stat_budget := 5.0 + 0.5 * (ilvl - 1)
	if kind in WEAPON_KINDS:
		item["implicit"][profile] = snappedf(stat_budget, 0.01)
		if profile == "intellect":
			item["implicit"].erase("flat_phys")
	elif kind in ARMOUR_KINDS:
		item["implicit"][profile] = snappedf(stat_budget * 0.32, 0.01)
		if armor_type == "mail" and profile == "agility":
			item["implicit"]["intellect"] = snappedf(stat_budget * 0.12, 0.01)
	elif kind in ["book", "talisman", "orb", "quiver"]:
		item["implicit"][profile] = snappedf(stat_budget * 0.35, 0.01)
	var count := 0
	match rarity:
		"magic": count = 1 + randi() % 2
		"rare": count = 3 + randi() % 4
	for i in count:
		add_random_mod(item)
	item["name"] = make_name(item)
	return item


## Добыча нужного типа, но подбор оптимальных аффиксов остаётся решением игрока.
static func for_hero(hero: Dictionary, ilvl: int, rarity: String = "", kind: String = "") -> Dictionary:
	DB.ensure()
	var cls: Dictionary = DB.classes[hero["cls"]]
	var sp := DB.spec(hero)
	var weapons: Array = sp.get("weapons", cls["weapons"])
	var offhands: Array = sp.get("offhands", cls["offhands"])
	if kind == "weapon":
		kind = weapons[0]
	elif kind == "offhand" and not offhands.is_empty():
		kind = offhands[0]
	if kind == "":
		var choices: Array = weapons + ARMOUR_KINDS + ["belt", "amulet", "ring"]
		if not DB.is_two_handed(hero.get("items", {}).get("weapon")):
			choices += offhands
		kind = choices.pick_random()
	var material := ""
	if kind in ARMOUR_KINDS:
		material = cls.get("armor_types", ["cloth"]).pick_random()
	return generate(ilvl, rarity, kind, material, DB.main_stat(hero))


## Предельное число аффиксов: начальная база 1+1, следующая 2+2, с ilvl28 — 3+3.
static func capacity(item: Dictionary) -> Dictionary:
	var ilvl := int(item.get("ilvl", 1))
	var each := 1 if ilvl < 8 else (2 if ilvl < 28 else 3)
	return {"prefix": each, "suffix": each, "total": each * 2}


static func add_random_mod(item: Dictionary) -> bool:
	var max_each := 1 if item["rarity"] == "magic" else MAX_PREFIX
	var pool := eligible_affixes(item, [], max_each)
	if pool.is_empty():
		return false
	add_mod(item, pool[randi() % pool.size()])
	return true


## Какие аффиксы могут встать на предмет. only_ids пустой = любые.
static func eligible_affixes(item: Dictionary, only_ids: Array, max_each: int = MAX_PREFIX) -> Array:
	max_each = mini(max_each, int(capacity(item)["prefix"]))
	var n_pre := 0
	var n_suf := 0
	var taken := {}
	for m in item["mods"]:
		taken[m["id"]] = true
		if m["type"] == "prefix":
			n_pre += 1
		else:
			n_suf += 1
	var pool: Array = []
	for a in DB.affixes:
		if taken.has(a["id"]) or not (item["slot"] in a["slots"]):
			continue
		if not only_ids.is_empty() and not (a["id"] in only_ids):
			continue
		if a["type"] == "prefix" and n_pre >= max_each:
			continue
		if a["type"] == "suffix" and n_suf >= max_each:
			continue
		if int(a["tiers"][0]["ilvl"]) > int(item["ilvl"]):
			continue
		pool.append(a)
	return pool


## Шансы тиров: [{tier: номер T, chance: 0..1}]. Лучший доступный 50%, каждый ниже вдвое реже.
static func tier_chances(a: Dictionary, ilvl: int) -> Array:
	var tiers: Array = a["tiers"]
	var top := 0
	for i in tiers.size():
		if int(tiers[i]["ilvl"]) <= ilvl:
			top = i
	var out: Array = []
	var left := 1.0
	for idx in range(top, -1, -1):
		var c := left * 0.5 if idx > 0 else left
		out.append({"tier": tiers.size() - idx, "idx": idx, "chance": c})
		left -= c
	return out


static func add_mod(item: Dictionary, a: Dictionary, forced_idx: int = -1) -> Dictionary:
	if a.is_empty() or eligible_affixes(item, [a["id"]]).is_empty():
		return {}
	var tiers: Array = a["tiers"]
	var idx := forced_idx
	if idx >= 0 and (idx >= tiers.size() or int(tiers[idx]["ilvl"]) > int(item["ilvl"])):
		return {}
	if idx < 0:
		var r := randf()
		for tc in tier_chances(a, int(item["ilvl"])):
			idx = tc["idx"]
			r -= tc["chance"]
			if r <= 0.0:
				break
	var t: Dictionary = tiers[idx]
	var m := {
		"id": a["id"], "stat": a["stat"], "type": a["type"],
		"tier": tiers.size() - idx,  # T1 = лучший, как в PoE
		"value": randi_range(int(t["min"]), int(t["max"])),
	}
	item["mods"].append(m)
	return m


static func affix_def(id: String) -> Dictionary:
	for a in DB.affixes:
		if a["id"] == id:
			return a
	return {}


static func make_name(item: Dictionary) -> String:
	match item["rarity"]:
		"rare":
			return "%s %s" % [RARE_FIRST[randi() % RARE_FIRST.size()], RARE_SECOND[randi() % RARE_SECOND.size()]]
		"magic":
			var pre := ""
			var suf := ""
			for m in item["mods"]:
				var d := affix_def(m["id"])
				var names: Array = d["names"]
				var nm: String = names[mini(int(d["tiers"].size()) - int(m["tier"]), names.size() - 1)]
				if m["type"] == "prefix":
					pre = nm + " "
				else:
					suf = " " + nm
			return pre + item["base"] + suf
	return item["base"]


## Все статы предмета одним словарем (имплисит + аффиксы)
static func stats_of(item: Dictionary) -> Dictionary:
	var s: Dictionary = item["implicit"].duplicate()
	for m in item["mods"]:
		s[m["stat"]] = s.get(m["stat"], 0) + m["value"]
	return s


static func describe(item: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s [%s, ур. %d]" % [item["name"], DB.RARITY_NAMES[item["rarity"]], item["ilvl"]])
	if item["rarity"] == "rare":
		lines.append("  " + item["base"])
	for k in item["implicit"]:
		lines.append("  · " + DB.stat_text(k, item["implicit"][k]))
	for m in item["mods"]:
		var d := affix_def(m["id"])
		var tag := "П" if m["type"] == "prefix" else "С"
		lines.append("  %s T%d: %s" % [tag, m["tier"], (d["text"] as String) % str(m["value"])])
	return "\n".join(lines)


## Вещь сломана: прочность 0, статы не работают, пока не починишь
static func broken(item: Dictionary) -> bool:
	return float(item.get("dur", 100.0)) <= 0.0


static func repair_cost(item: Dictionary) -> int:
	var missing := 100.0 - float(item.get("dur", 100.0))
	return int(ceil(missing / 100.0 * 4.0 * pow(maxf(1.0, float(item["ilvl"])), 1.25)))


static func sell_price(item: Dictionary) -> int:
	var mult := {"normal": 1, "magic": 3, "rare": 10}
	return int(mult[item["rarity"]]) * maxi(1, int(item["ilvl"]))
