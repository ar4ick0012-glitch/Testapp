extends Control
## Крупные пиксельные герои и собственные враги. Масштаб спрайтов целочисленный.

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
	var x := size.x * 0.8
	for i in game.heroes.size():
		if absf(old_pos.x - game._hero_x(i)) < 15.0:
			x = _hero_pos(i).x
	floats.append({"text": text, "pos": Vector2(x, size.y * 0.35), "life": 1.2, "color": color, "size": maxi(font_size, 16)})


func _hero_pos(i: int) -> Vector2:
	return Vector2(size.x * 0.18 + i * 82.0, size.y * 0.78)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("141519"))
	var ground := floorf(size.y * 0.78)
	# Собственная кладка, арки и факелы. Нет внешних игровых ассетов.
	for row in int(ground / 24.0) + 1:
		for col in int(size.x / 56.0) + 2:
			var x := col * 56.0 - (28.0 if row % 2 else 0.0)
			var shade := 0.085 + float((row * 7 + col * 11) % 5) * 0.008
			draw_rect(Rect2(x + 1, row * 24 + 1, 54, 22), Color(shade, shade * 0.97, shade * 1.04))
	for k in 3:
		var center := Vector2(size.x * (0.16 + k * 0.34), ground - 100)
		draw_rect(Rect2(center + Vector2(-34, 0), Vector2(68, 110)), Color("0c0e13"))
		draw_arc(center, 34, PI, TAU, 12, Color("403b36"), 8)
		draw_line(center + Vector2(-38, 0), center + Vector2(-38, 106), Color("403b36"), 8)
		draw_line(center + Vector2(38, 0), center + Vector2(38, 106), Color("403b36"), 8)
	var flame := 0.85 + 0.15 * sin(game.t * 9.0)
	for x in [size.x * 0.38, size.x * 0.69]:
		var p := Vector2(x, ground - 96)
		draw_circle(p, 45, Color(0.9, 0.43, 0.17, 0.04))
		draw_circle(p, 24, Color(0.9, 0.43, 0.17, 0.08))
		draw_rect(Rect2(p + Vector2(-3, 7), Vector2(6, 19)), Color("57412c"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 8), p + Vector2(0, -14 * flame), p + Vector2(7, 8)]), Color("d68d4a"))
		draw_circle(p + Vector2(0, 3), 4 * flame, Color("ffe4a1"))
	draw_rect(Rect2(0, ground, size.x, size.y - ground), Color("232024"))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color("65513c"), 2)
	for i in game.heroes.size():
		var hero: Dictionary = game.heroes[i]
		var feet := _hero_pos(i)
		var dead: bool = hero.get("life", 1.0) <= 0.0
		var frame := 2 if game.attack_flash[i] > 0 else int(game.t * 2 + i) % 2
		var scale_n := 3.0
		if size.y > 340: scale_n = 4.0
		var tx: Texture2D = game.tex.get(DB.spec(hero)["sprite"])
		if tx != null:
			draw_set_transform(feet + Vector2(0, 2), 0, Vector2(1, 0.25))
			draw_circle(Vector2.ZERO, 25, Color(0, 0, 0, 0.5))
			draw_set_transform(Vector2.ZERO)
			var tint := Color("81c89c") if game.heal_flash[i] > 0.0 else Color.WHITE
			if dead:
				draw_set_transform(feet + Vector2(-25, -2), -PI / 2)
				tint = Color("71676b")
				draw_texture_rect_region(tx, Rect2(-48, -144, 96, 144), Rect2(0, 0, 32, 48), tint)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(tx, Rect2(feet.x - 16 * scale_n, feet.y - 48 * scale_n, 32 * scale_n, 48 * scale_n), Rect2(frame * 32, 0, 32, 48), tint)
		var color := Color(DB.classes[hero["cls"]]["color"]).lightened(0.35)
		draw_string(font, feet + Vector2(-44, 27), DB.classes[hero["cls"]]["name"], HORIZONTAL_ALIGNMENT_CENTER, 88, 14, color)
		if hero["cls"] == "hunter" and not hero.get("pet_dead", false):
			var wolf: Texture2D = game.tex.get("wolf")
			if wolf != null:
				draw_texture_rect_region(wolf, Rect2(feet + Vector2(20, -48), Vector2(64, 48)), Rect2(frame * 32, 0, 32, 24))
	if not game.enemy.is_empty():
		_draw_enemy(Vector2(size.x * 0.82, ground))
		var text: String = game.enemy["name"]
		draw_string(font, Vector2(size.x * 0.64, 28), text, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.34, 17, Color("dfaaa0"))
		draw_string(font, Vector2(size.x * 0.64, 50), "%.0f / %.0f здоровья" % [game.enemy["hp"], game.enemy["max_hp"]], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.34, 13, Color("ae9290"))
	else:
		draw_string(font, Vector2(size.x * 0.63, ground - 70), "ЛАГЕРЬ", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.34, 20, Color("bba16e"))
	for f in floats:
		var color: Color = f.color
		color.a = minf(f.life, 1.0)
		draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, f.size, 4, Color("101216"))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, f.size, color)


func _draw_enemy(feet: Vector2) -> void:
	var tx: Texture2D = game.tex.get("enemy")
	if tx == null: return
	var frame := int(game.t * 2.0) % 2
	var scale_n := 4.0 if game.enemy["boss"] else 3.0
	scale_n = maxf(1.0, minf(scale_n, floorf((feet.y - 58.0) / 64.0)))
	var tint := Color.WHITE
	if game.hurt_flash > 0: tint = Color("f7b9ad")
	draw_set_transform(feet + Vector2(0, 2), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(tx, Rect2(feet.x - 24 * scale_n, feet.y - 64 * scale_n, 48 * scale_n, 64 * scale_n), Rect2(frame * 48, 0, 48, 64), tint)
