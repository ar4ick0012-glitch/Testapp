class_name EnemyArt
extends RefCounted
## Собственные модели монстров: каждому имени из данных соответствует его спрайт.

static var registry: Dictionary = {}
static var textures: Dictionary = {}


static func ensure() -> void:
	if not registry.is_empty(): return
	var file := FileAccess.open("res://data/enemy_visuals.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: registry = parsed


static func key_for(enemy_name: String) -> String:
	ensure()
	return str(registry.get(enemy_name, {}).get("sprite", "skeleton"))


static func texture_for(enemy_name: String) -> Texture2D:
	var key := key_for(enemy_name)
	if not textures.has(key):
		var path := "res://assets/sprites/enemies/%s.png" % key
		if ResourceLoader.exists(path): textures[key] = load(path)
	return textures.get(key)
