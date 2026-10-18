extends SceneTree
## Проверка крафта: генерит вещи, применяет всю валюту, печатает превью и результат.
## Запуск: godot --headless --script res://tools/craft_test.gd
func _initialize() -> void:
	seed(7)
	DB.ensure()
	var it := Items.generate(30, "normal", "sword")
	print(Items.describe(it))
	for cid in ["ember_attack", "ember_elemental", "ember_attack", "ember_defense", "ember_attack", "ember_elemental", "ember_attack", "ember_attack"]:
		print("\n--- ", Craft.preview(it, cid))
		if Craft.check(it, cid) == "":
			print(">>> ", Craft.apply(it, cid))
	for cid in ["sand", "chisel", "oblivion", "blight", "chisel"]:
		print("\n--- ", Craft.preview(it, cid))
		if Craft.check(it, cid) == "":
			print(">>> ", Craft.apply(it, cid))
	print("\n", Items.describe(it))
	quit()
