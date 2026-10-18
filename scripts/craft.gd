class_name Craft
## Крафт в духе Torchlight: перед каждым применением видно, что может прокнуть и с каким шансом.
## Валюта и шансы описаны в data/currency.json.


## Пустая строка = можно применять, иначе причина, почему нельзя
static func check(item: Dictionary, cur_id: String) -> String:
	var c := DB.currency_def(cur_id)
	if item.get("corrupted", false):
		return "Вещь осквернена, крафт невозможен"
	var mods: Array = item["mods"]
	match c["action"]:
		"ember":
			if _ember_options(item, c).is_empty():
				return "Подходящих аффиксов этой группы нет для этой вещи"
		"reroll_values", "remove", "corrupt":
			if mods.is_empty() and c["action"] != "corrupt":
				return "На вещи нет аффиксов"
		"tier_up":
			if _upgradable(item).is_empty():
				return "Все аффиксы уже на лучшем тире"
	return ""


## Применяет валюту. Возвращает строку для лога.
static func apply(item: Dictionary, cur_id: String) -> String:
	var c := DB.currency_def(cur_id)
	var mods: Array = item["mods"]
	var msg := ""
	match c["action"]:
		"ember":
			var opts := _ember_options(item, c)
			var o: Dictionary = opts[randi() % opts.size()]
			if o["remove"] >= 0:
				var old: Dictionary = mods[o["remove"]]
				mods.remove_at(o["remove"])
				msg = "заменён «%s» → " % _mod_text(old)
			var m := Items.add_mod(item, o["affix"])
			msg += "«%s» T%d" % [_mod_text(m), m["tier"]]
		"reroll_values":
			for m in mods:
				var t := _tier_def(m)
				m["value"] = randi_range(int(t["min"]), int(t["max"]))
			msg = "числа перекатаны"
		"tier_up":
			var ups := _upgradable(item)
			var m: Dictionary = ups[randi() % ups.size()]
			m["tier"] -= 1
			var t := _tier_def(m)
			m["value"] = randi_range(int(t["min"]), int(t["max"]))
			msg = "«%s» теперь T%d" % [_mod_text(m), m["tier"]]
		"remove":
			var i := randi() % mods.size()
			msg = "удалён «%s»" % _mod_text(mods[i])
			mods.remove_at(i)
		"corrupt":
			msg = _corrupt(item)
	_update_rarity(item)
	return "%s: %s" % [c["name"], msg]


## Текст для панели: что может произойти и с какими шансами
static func preview(item: Dictionary, cur_id: String) -> String:
	var c := DB.currency_def(cur_id)
	var L: Array[String] = ["[b]%s[/b] (%s)" % [c["name"], c["desc"]]]
	var err := check(item, cur_id)
	if err != "":
		L.append("[color=#ff7070]%s[/color]" % err)
		return "\n".join(L)
	match c["action"]:
		"ember":
			# шанс каждого аффикса с учётом того, что при полной вещи один заменяется
			var opts := _ember_options(item, c)
			var by_id := {}
			for o in opts:
				var id: String = o["affix"]["id"]
				by_id[id] = by_id.get(id, 0.0) + 1.0 / opts.size()
			if opts[0]["remove"] >= 0:
				L.append("[color=#ffb060]Места нет: заменит один из %d аффиксов[/color]" % item["mods"].size())
			var ids := by_id.keys()
			ids.sort_custom(func(x, y): return by_id[x] > by_id[y])
			for id in ids:
				var a := Items.affix_def(id)
				var tiers: Array[String] = []
				for tc in Items.tier_chances(a, int(item["ilvl"])):
					var t: Dictionary = a["tiers"][tc["idx"]]
					tiers.append("T%d %d–%d: %.0f%%" % [tc["tier"], t["min"], t["max"], tc["chance"] * 100.0])
				L.append("%.0f%%  %s  [color=#909090](%s)[/color]" % [by_id[id] * 100.0, (a["text"] as String) % "#", ", ".join(tiers)])
		"tier_up":
			var ups := _upgradable(item)
			for m in ups:
				L.append("%.0f%%  %s: T%d → T%d" % [100.0 / ups.size(), _mod_text(m), m["tier"], m["tier"] - 1])
		"remove":
			for m in item["mods"]:
				L.append("%.0f%%  удалить «%s»" % [100.0 / item["mods"].size(), _mod_text(m)])
		"reroll_values":
			for m in item["mods"]:
				var t := _tier_def(m)
				L.append("%s → от %d до %d" % [_mod_text(m), t["min"], t["max"]])
		"corrupt":
			var total := 0.0
			for o in DB.corrupt_outcomes:
				total += float(o["weight"])
			for o in DB.corrupt_outcomes:
				L.append("%.0f%%  %s" % [float(o["weight"]) / total * 100.0, o["name"]])
	return "\n".join(L)


# ---------- внутреннее ----------

## Варианты угля: [{affix, remove}], remove = индекс заменяемого аффикса или -1
static func _ember_options(item: Dictionary, c: Dictionary) -> Array:
	var ids: Array = DB.pools[c["pool"]]["affixes"]
	var out: Array = []
	for a in Items.eligible_affixes(item, ids):
		out.append({"affix": a, "remove": -1})
	if not out.is_empty():
		return out
	# места нет: каждый аффикс может быть заменён с равным шансом
	var mods: Array = item["mods"]
	for i in mods.size():
		var copy := item.duplicate(true)
		copy["mods"].remove_at(i)
		var opts := Items.eligible_affixes(copy, ids)
		for a in opts:
			# вес нормируем так, чтобы каждый удаляемый аффикс был равновероятен
			for k in int(360 / opts.size()):
				out.append({"affix": a, "remove": i})
	return out


static func _upgradable(item: Dictionary) -> Array:
	return item["mods"].filter(func(m): return int(m["tier"]) > 1)


static func _tier_def(m: Dictionary) -> Dictionary:
	var a := Items.affix_def(m["id"])
	var tiers: Array = a["tiers"]
	return tiers[tiers.size() - int(m["tier"])]


static func _mod_text(m: Dictionary) -> String:
	return (Items.affix_def(m["id"])["text"] as String) % str(m["value"])


static func _update_rarity(item: Dictionary) -> void:
	var n_pre := 0
	var n_suf := 0
	for m in item["mods"]:
		if m["type"] == "prefix":
			n_pre += 1
		else:
			n_suf += 1
	var old: String = item["rarity"]
	if n_pre + n_suf == 0:
		item["rarity"] = "normal"
	elif n_pre <= 1 and n_suf <= 1:
		item["rarity"] = "magic"
	else:
		item["rarity"] = "rare"
	if old != item["rarity"] or item["rarity"] == "magic":
		item["name"] = Items.make_name(item)


static func _corrupt(item: Dictionary) -> String:
	item["corrupted"] = true
	var total := 0.0
	for o in DB.corrupt_outcomes:
		total += float(o["weight"])
	var r := randf() * total
	var pick: Dictionary = DB.corrupt_outcomes[0]
	for o in DB.corrupt_outcomes:
		r -= float(o["weight"])
		if r <= 0.0:
			pick = o
			break
	var mods: Array = item["mods"]
	match pick["id"]:
		"overforge":
			if not mods.is_empty():
				var m: Dictionary = mods[randi() % mods.size()]
				m["value"] = int(ceil(m["value"] * 1.25))
		"gift":
			var g: Dictionary = DB.corrupt_gifts[randi() % DB.corrupt_gifts.size()]
			item["implicit"][g["stat"]] = item["implicit"].get(g["stat"], 0) + g["value"]
		"shatter":
			for m in mods:
				m["value"] = int(floor(m["value"] * 0.7))
	return pick["name"]
