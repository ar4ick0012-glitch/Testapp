extends RefCounted
## Только стенд: имитирует ручной набор, стартовый комплект и выбор умения.
static func choose_skills(game) -> void:
	for hero in game.roster.values():
		var options := DB.skill_options(hero)
		if not options.is_empty(): hero["skill_id"] = options[0]["id"]

static func starter(game, ids: Array) -> void:
	game.party_ids = ids.duplicate()
	for cls in ids:
		var hero: Dictionary = game.roster[cls]
		hero["items"].clear()
		for kind in ["weapon", "armour", "helmet", "gloves", "boots"]:
			hero["items"][kind] = game.starter_item(hero, kind)
		var offs: Array = DB.spec(hero).get("offhands", DB.classes[cls]["offhands"])
		if not offs.is_empty() and not DB.is_two_handed(hero["items"]["weapon"]):
			hero["items"]["offhand"] = game.starter_item(hero, offs[0])
		var options := DB.skill_options(hero)
		if not options.is_empty(): hero["skill_id"] = options[0]["id"]
	game.selected_dungeon = "crypt"
	game._set_party()
