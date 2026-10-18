extends RefCounted
## Только тестовый стенд: решения игрока задаются явно, обычная игра этого не вызывает.
static func starter(game, ids: Array) -> void:
	game.party_ids = ids.duplicate()
	game.cleared["training"] = 1
	for cls in ids:
		var hero: Dictionary = game.roster[cls]
		hero["items"] = {"weapon": Items.for_hero(hero, 1, "normal", "weapon")}
	game.selected_dungeon = "crypt"
	game._set_party()
