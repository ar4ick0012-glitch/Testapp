extends Control
## Строй и видимые переходы используют то же состояние, что и симуляция боя.

var game
var floats: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	for f in floats:
		f.pos.y -= delta * 22.0
		f.life -= delta
	floats = floats.filter(func(f): return f.life > 0.0)
	queue_redraw()


func add_number(text: String, old_pos: Vector2, color: Color, font_size: int) -> void:
	if floats.size() > 35: return
	var x := size.x * 0.82
	for i in game.heroes.size():
		if absf(old_pos.x - game._hero_x(i)) < 15.0:
			x = _hero_pos(i).x
	floats.append({"text": text, "pos": Vector2(x, size.y * 0.35), "life": 1.2, "color": color, "size": maxi(font_size, 16)})


func _hero_pos(i: int) -> Vector2:
	# Позиция 0 — передняя: справа, ближе к врагу.
	var gap := clampf(size.x * 0.105, 65.0, 82.0)
	var advance := sin(game.travel_progress() * PI) * 18.0 if game.is_travelling() else 0.0
	return Vector2(floorf(size.x * 0.51 - i * gap + advance), floorf(size.y * 0.78))


func _draw() -> void:
	if game == null: return
	var font := get_theme_default_font()
	var ground := floorf(size.y * 0.78)
	var travelling: bool = game.is_travelling()
	_draw_corridor(ground)
	for i in range(game.heroes.size() - 1, -1, -1):
		_draw_hero(i, font, travelling)
	if not travelling and not game.enemy.is_empty():
		_draw_enemy(Vector2(size.x * 0.82, ground))
		var text: String = game.enemy["name"]
		draw_string(font, Vector2(size.x * 0.65, 28), text, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.33, 17, Color("dfaaa0"))
		draw_string(font, Vector2(size.x * 0.65, 50), "%.0f / %.0f здоровья" % [game.enemy["hp"], game.enemy["max_hp"]], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.33, 13, Color("ae9290"))
	elif travelling:
		draw_string(font, Vector2(size.x * 0.58, 35), "К следующей встрече →", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.4, 17, Color("d8c090"))
		var bar := Rect2(size.x * 0.67, 47, size.x * 0.22, 4)
		draw_rect(bar, Color("33303a"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * game.travel_progress(), 4)), Color("aa925d"))
	else:
		draw_string(font, Vector2(size.x * 0.63, ground - 70), "ЛАГЕРЬ", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.34, 20, Color("bba16e"))
	for f in floats:
		var color: Color = f.color
		color.a = minf(f.life, 1.0)
		draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, f.size, 4, Color("101216"))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, f.size, color)


func _draw_corridor(ground: float) -> void:
	var dungeon := DB.dungeon(game.run.get("id", game.selected_dungeon))
	var accent := Color(dungeon.get("color", "#8a8070"))
	# Дистанция растёт только в переходах; во время боя коридор неподвижен.
	var distance: float = game.travel_distance
	var wall_offset := fposmod(distance * 0.66, 56.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("141519"))
	for row in int(ground / 24.0) + 1:
		for col in int(size.x / 56.0) + 3:
			var x := col * 56.0 - (28.0 if row % 2 else 0.0) - wall_offset
			var shade := 0.085 + float((row * 7 + col * 11) % 5) * 0.008
			var stone := Color(shade, shade * 0.97, shade * 1.04).lerp(accent.darkened(0.8), 0.22)
			draw_rect(Rect2(x + 1, row * 24 + 1, 54, 22), stone)
	var arch_spacing := 240.0
	var arch_offset := fposmod(distance * 0.66, arch_spacing)
	for k in int(size.x / arch_spacing) + 2:
		var center := Vector2(k * arch_spacing + 110.0 - arch_offset, ground - 100)
		draw_rect(Rect2(center + Vector2(-34, 0), Vector2(68, 110)), Color("0c0e13"))
		var border := Color("403b36").lerp(accent.darkened(0.6), 0.2)
		draw_arc(center, 34, PI, TAU, 12, border, 8)
		draw_line(center + Vector2(-38, 0), center + Vector2(-38, 106), border, 8)
		draw_line(center + Vector2(38, 0), center + Vector2(38, 106), border, 8)
		_draw_torch(Vector2(center.x + 100.0, ground - 96), k)
	draw_rect(Rect2(0, ground, size.x, size.y - ground), Color("232024").lerp(accent.darkened(0.78), 0.15))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color("65513c"), 2)
	var floor_offset := fposmod(distance, 74.0)
	for k in int(size.x / 74.0) + 2:
		var x := k * 74.0 - floor_offset
		draw_line(Vector2(x, ground + 2), Vector2(x - 18, size.y), Color("302a2c"), 1)
	for y in [ground + 18, ground + 48]:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("302a2c"), 1)


func _draw_torch(p: Vector2, index: int) -> void:
	var flame := 0.85 + 0.15 * sin(game.t * 9.0 + index)
	draw_circle(p, 45, Color(0.9, 0.43, 0.17, 0.04))
	draw_circle(p, 24, Color(0.9, 0.43, 0.17, 0.08))
	draw_rect(Rect2(p + Vector2(-3, 7), Vector2(6, 19)), Color("57412c"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 8), p + Vector2(0, -14 * flame), p + Vector2(7, 8)]), Color("d68d4a"))
	draw_circle(p + Vector2(0, 3), 4 * flame, Color("ffe4a1"))


func _draw_hero(i: int, font: Font, travelling: bool) -> void:
	var hero: Dictionary = game.heroes[i]
	var feet := _hero_pos(i)
	var dead: bool = hero.get("life", 1.0) <= 0.0
	var walking := travelling and not dead
	var stride := sin(game.travel_distance * 0.15 + i * 0.8)
	var bob := -floorf(absf(stride) * 3.0) if walking else 0.0
	var frame := 2 if game.attack_flash[i] > 0.0 and not walking else int(game.t * 2 + i) % 2
	var scale_n := 4.0 if size.y > 340 else 3.0
	var tx: Texture2D = game.tex.get(DB.spec(hero)["sprite"])
	if tx != null:
		draw_set_transform(feet + Vector2(0, 2), 0, Vector2(1, 0.25))
		draw_circle(Vector2.ZERO, 25, Color(0, 0, 0, 0.5))
		draw_set_transform(Vector2.ZERO)
		var tint := Color("81c89c") if game.heal_flash[i] > 0.0 else Color.WHITE
		if dead:
			draw_set_transform(feet + Vector2(-25, -2), -PI / 2)
			draw_texture_rect_region(tx, Rect2(-48, -144, 96, 144), Rect2(0, 0, 32, 48), Color("71676b"))
			draw_set_transform(Vector2.ZERO)
		elif walking:
			# Оригинальные герои: ноги поочерёдно делают шаг, корпус слегка покачивается.
			var top := feet + Vector2(-16 * scale_n, -48 * scale_n + bob)
			draw_texture_rect_region(tx, Rect2(top, Vector2(32, 40) * scale_n), Rect2(frame * 32, 0, 32, 40), tint)
			for leg in 2:
				var foot_y := -maxf(0.0, stride * (1.0 if leg == 0 else -1.0)) * 3.0
				var offset_x := floorf(stride * (1.0 if leg == 0 else -1.0))
				var foot_top := feet + Vector2((-16 + leg * 16) * scale_n + offset_x, -8 * scale_n + bob + foot_y)
				draw_texture_rect_region(tx, Rect2(foot_top, Vector2(16, 8) * scale_n), Rect2(frame * 32 + leg * 16, 40, 16, 8), tint)
			# След пыли за шагающими героями.
			var puff := fposmod(game.travel_distance * 0.026 + i * 0.23, 1.0)
			draw_rect(Rect2(feet + Vector2(-18 - puff * 25, -2 - puff * 6), Vector2(3, 2)), Color(0.58, 0.50, 0.39, (1.0 - puff) * 0.5))
		else:
			draw_texture_rect_region(tx, Rect2(feet.x - 16 * scale_n, feet.y - 48 * scale_n, 32 * scale_n, 48 * scale_n), Rect2(frame * 32, 0, 32, 48), tint)
	var color := Color(DB.classes[hero["cls"]]["color"]).lightened(0.35)
	var caption: String = "%d. %s" % [i + 1, DB.classes[hero["cls"]]["name"]]
	draw_string(font, feet + Vector2(-44, 27), caption, HORIZONTAL_ALIGNMENT_CENTER, 88, 13, color)
	if i == game.front_hero_index():
		draw_string(font, feet + Vector2(-44, 43), "ПЕРЕДНИЙ", HORIZONTAL_ALIGNMENT_CENTER, 88, 10, Color("cfb47b"))
	if hero["cls"] == "hunter" and not dead and not hero.get("pet_dead", false):
		var wolf: Texture2D = game.tex.get("wolf")
		if wolf != null:
			draw_texture_rect_region(wolf, Rect2(feet + Vector2(20, -48 + bob), Vector2(64, 48)), Rect2(frame * 32, 0, 32, 24))


func _draw_enemy(feet: Vector2) -> void:
	var tx: Texture2D = EnemyArt.texture_for(game.enemy["name"])
	if tx == null: return
	var frame := 2 if game.hurt_flash > 0.08 else int(game.t * 2.0) % 2
	var scale_n := 4.0 if game.enemy["boss"] else 3.0
	scale_n = maxf(1.0, minf(scale_n, floorf((feet.y - 58.0) / 64.0)))
	var tint := Color("f7b9ad") if game.hurt_flash > 0.0 else Color.WHITE
	draw_set_transform(feet + Vector2(0, 2), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 29 if game.enemy["boss"] else 22, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(tx, Rect2(feet.x - 24 * scale_n, feet.y - 64 * scale_n, 48 * scale_n, 64 * scale_n), Rect2(frame * 48, 0, 48, 64), tint)
