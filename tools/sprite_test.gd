extends SceneTree
## Все враги из данных должны иметь импортированный спрайт, а строй — совпадать с направлением боя.

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	DB.ensure()
	EnemyArt.ensure()
	var names: Dictionary = {}
	var pixels: Dictionary = {}
	var bodies: Dictionary = {}
	for d in DB.dungeons:
		for name in d["names"] + [d["floor_boss"], d["boss"]]:
			names[name] = true
	for name in names:
		check(EnemyArt.registry.has(name), "Нет записи модели: " + name)
		var tx := EnemyArt.texture_for(name)
		check(tx != null, "Не импортирован спрайт: " + name)
		if tx == null: continue
		check(tx.get_size() == Vector2(144, 64), "Неверные кадры спрайта: " + name)
		var im := tx.get_image()
		check(im != null and im.get_used_rect().has_area(), "Спрайт пустой: " + name)
		if im != null: pixels[im.get_data().hex_encode()] = true
		bodies[EnemyArt.registry[name]["archetype"]] = true
	check(pixels.size() == names.size(), "Разные враги используют одинаковые изображения")
	check(bodies.size() >= 10, "Недостаточно разных типов модели")
	check(EnemyArt.texture_for("Неизвестный монстр") != null, "Неизвестное имя делает врага невидимым")
	var game = load("res://main.tscn").instantiate()
	game.simulating = true
	game.test_mode = true
	root.add_child(game)
	game._set_party()
	var view = load("res://scripts/battle_view.gd").new()
	view.game = game
	view.size = Vector2(800, 300)
	check(view._hero_pos(0).x > view._hero_pos(1).x and view._hero_pos(1).x > view._hero_pos(2).x, "Первый в строю визуально дальше от врага")
	game.start_run("crypt")
	var origin: Vector2 = view._hero_pos(0)
	game.step(0.3)
	check(view._hero_pos(0).x > origin.x and game.travel_distance > 0.0, "Переход не сдвигает героев и окружение")
	view.free()
	game.free()
	print("SPRITE TEST: %d checks, %d failures; %d models / %d body types" % [checks, failures, names.size(), bodies.size()])
	quit(0 if failures == 0 else 1)
