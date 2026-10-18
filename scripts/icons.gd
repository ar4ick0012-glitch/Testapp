class_name Icons
## Иконки предметов и валюты, нарисованные кодом. Заглушки до настоящего арта:
## когда будут спрайты, заменим тело draw() на draw_texture_rect.

const METAL := Color(0.72, 0.72, 0.76)
const DARK_METAL := Color(0.42, 0.42, 0.46)
const WOOD := Color(0.52, 0.36, 0.2)
const LEATHER := Color(0.45, 0.3, 0.18)


static func draw(ci: CanvasItem, kind: String, r: Rect2, accent: Color) -> void:
	var c := r.get_center()
	var w := r.size.x
	var h := r.size.y
	var s := minf(w, h)
	match kind:
		"sword", "greatsword":
			var top := Vector2(c.x + s * 0.3, r.position.y + h * 0.05)
			var bot := Vector2(c.x - s * 0.25, r.end.y - h * 0.22)
			ci.draw_line(top, bot, METAL, maxf(3.0, s * 0.13))
			ci.draw_line(top, bot, Color(1, 1, 1, 0.5), 1.0)
			var guard := bot.lerp(top, 0.08)
			var n := (top - bot).normalized().orthogonal() * s * 0.28
			ci.draw_line(guard - n, guard + n, accent, 3.0)
			ci.draw_line(bot, bot + (bot - top).normalized() * h * 0.15, LEATHER, 4.0)
			ci.draw_circle(bot + (bot - top).normalized() * h * 0.17, 2.5, accent)
		"mace":
			var head := Vector2(c.x + s * 0.12, r.position.y + h * 0.22)
			ci.draw_line(Vector2(c.x - s * 0.12, r.end.y - h * 0.08), head, WOOD, maxf(3.0, s * 0.12))
			ci.draw_circle(head, s * 0.25, DARK_METAL)
			ci.draw_circle(head + Vector2(-s * 0.04, -s * 0.04), s * 0.17, METAL)
			ci.draw_line(head - Vector2(s * 0.28, 0), head + Vector2(s * 0.28, 0), accent, 2.0)
		"bow":
			ci.draw_arc(Vector2(c.x - s * 0.15, c.y), h * 0.42, -1.25, 1.25, 16, WOOD, 3.0)
			var a := Vector2(c.x - s * 0.15, c.y) + Vector2(cos(-1.25), sin(-1.25)) * h * 0.42
			var b := Vector2(c.x - s * 0.15, c.y) + Vector2(cos(1.25), sin(1.25)) * h * 0.42
			ci.draw_line(a, b, Color(0.9, 0.9, 0.8, 0.8), 1.0)
			ci.draw_circle(Vector2(c.x + s * 0.27, c.y), 2.5, accent)
		"staff":
			ci.draw_line(Vector2(c.x - s * 0.2, r.end.y - 2), Vector2(c.x + s * 0.15, r.position.y + h * 0.22), WOOD, 3.0)
			var tip := Vector2(c.x + s * 0.17, r.position.y + h * 0.16)
			ci.draw_circle(tip, s * 0.2, Color(accent.r, accent.g, accent.b, 0.25))
			ci.draw_circle(tip, s * 0.11, accent)
		"shield":
			var pts := PackedVector2Array([
				Vector2(r.position.x + w * 0.15, r.position.y + h * 0.12), Vector2(r.end.x - w * 0.15, r.position.y + h * 0.12),
				Vector2(r.end.x - w * 0.15, c.y + h * 0.05), Vector2(c.x, r.end.y - h * 0.06), Vector2(r.position.x + w * 0.15, c.y + h * 0.05)])
			ci.draw_colored_polygon(pts, WOOD)
			pts.append(pts[0])
			ci.draw_polyline(pts, DARK_METAL, 2.0)
			ci.draw_circle(Vector2(c.x, c.y - h * 0.05), s * 0.12, accent)
		"quiver":
			ci.draw_rect(Rect2(c.x - w * 0.18, c.y - h * 0.15, w * 0.36, h * 0.55), LEATHER)
			for k in 3:
				var x := c.x - w * 0.1 + k * w * 0.1
				ci.draw_line(Vector2(x, c.y - h * 0.15), Vector2(x, r.position.y + h * 0.08), Color(0.8, 0.75, 0.6), 1.5)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, r.position.y + h * 0.14), Vector2(x, r.position.y + h * 0.02), Vector2(x + 3, r.position.y + h * 0.14)]), accent)
		"orb":
			ci.draw_circle(c, s * 0.38, Color(accent.r, accent.g, accent.b, 0.18))
			ci.draw_circle(c, s * 0.28, accent.darkened(0.3))
			ci.draw_circle(c + Vector2(-s * 0.08, -s * 0.08), s * 0.09, Color(1, 1, 1, 0.7))
		"helmet":
			ci.draw_circle(Vector2(c.x, c.y + h * 0.05), s * 0.34, METAL)
			ci.draw_rect(Rect2(c.x - s * 0.34, c.y + h * 0.05, s * 0.68, s * 0.3), METAL)
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y + h * 0.1, s * 0.44, s * 0.07), Color(0.05, 0.05, 0.05))
			ci.draw_line(Vector2(c.x, c.y - s * 0.3), Vector2(c.x, c.y + h * 0.08), accent, 2.0)
		"armour":
			var pts := PackedVector2Array([
				Vector2(c.x - w * 0.38, r.position.y + h * 0.15), Vector2(c.x - w * 0.12, r.position.y + h * 0.08),
				Vector2(c.x, r.position.y + h * 0.16), Vector2(c.x + w * 0.12, r.position.y + h * 0.08),
				Vector2(c.x + w * 0.38, r.position.y + h * 0.15), Vector2(c.x + w * 0.3, r.end.y - h * 0.08),
				Vector2(c.x - w * 0.3, r.end.y - h * 0.08)])
			ci.draw_colored_polygon(pts, DARK_METAL)
			ci.draw_line(Vector2(c.x, r.position.y + h * 0.2), Vector2(c.x, r.end.y - h * 0.1), METAL, 1.5)
			ci.draw_line(Vector2(c.x - w * 0.28, c.y + h * 0.12), Vector2(c.x + w * 0.28, c.y + h * 0.12), accent, 2.0)
		"gloves":
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.1, s * 0.4, s * 0.42), LEATHER)
			for k in 4:
				ci.draw_rect(Rect2(c.x - s * 0.22 + k * s * 0.1, c.y - s * 0.34, s * 0.08, s * 0.26), LEATHER.lightened(0.1))
			ci.draw_rect(Rect2(c.x + s * 0.18, c.y - s * 0.05, s * 0.14, s * 0.1), LEATHER.lightened(0.1))
			ci.draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.22, s * 0.44, s * 0.08), accent)
		"boots":
			ci.draw_rect(Rect2(c.x - s * 0.18, r.position.y + h * 0.12, s * 0.3, h * 0.6), LEATHER)
			ci.draw_rect(Rect2(c.x - s * 0.18, r.end.y - h * 0.3, s * 0.52, h * 0.18), LEATHER)
			ci.draw_rect(Rect2(c.x - s * 0.2, r.position.y + h * 0.12, s * 0.34, h * 0.08), accent)
		"belt":
			ci.draw_rect(Rect2(r.position.x + 2, c.y - h * 0.16, w - 4, h * 0.32), LEATHER)
			ci.draw_rect(Rect2(c.x - s * 0.16, c.y - h * 0.22, s * 0.32, h * 0.44), accent, false, 2.0)
		"amulet":
			ci.draw_arc(Vector2(c.x, c.y - h * 0.2), s * 0.3, 0.2, PI - 0.2, 12, Color(0.8, 0.7, 0.4), 1.5)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, c.y), Vector2(c.x + s * 0.16, c.y + s * 0.16), Vector2(c.x, c.y + s * 0.36), Vector2(c.x - s * 0.16, c.y + s * 0.16)]), accent)
		"ring":
			ci.draw_arc(Vector2(c.x, c.y + s * 0.06), s * 0.26, 0, TAU, 20, Color(0.85, 0.72, 0.42), maxf(2.0, s * 0.09))
			ci.draw_circle(Vector2(c.x, c.y - s * 0.22), s * 0.11, accent)
		_:
			ci.draw_rect(r.grow(-s * 0.2), accent)


static func currency(ci: CanvasItem, id: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	var col: Color = {
		"ember_attack": Color(0.95, 0.4, 0.2), "ember_elemental": Color(0.35, 0.6, 1.0),
		"ember_defense": Color(0.7, 0.72, 0.78), "sand": Color(0.85, 0.75, 0.45),
		"chisel": Color(0.75, 0.9, 0.95), "oblivion": Color(0.75, 0.5, 0.95), "blight": Color(0.45, 0.85, 0.35),
	}.get(id, Color(0.85, 0.72, 0.42))
	match id:
		"ember_attack", "ember_elemental", "ember_defense":
			ci.draw_circle(c, s * 0.48, Color(col.r, col.g, col.b, 0.15))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.3, s * 0.1), c + Vector2(0, s * 0.4), c + Vector2(-s * 0.3, s * 0.1)]), col)
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.14, col.lightened(0.6))
		"sand":
			for k in 7:
				ci.draw_circle(c + Vector2(cos(k * 2.4) * s * 0.25, sin(k * 1.7) * s * 0.2 + s * 0.08), s * 0.08, col)
		"chisel":
			ci.draw_line(c + Vector2(-s * 0.35, s * 0.35), c + Vector2(s * 0.2, -s * 0.2), WOOD, 4.0)
			ci.draw_line(c + Vector2(s * 0.12, -s * 0.12), c + Vector2(s * 0.38, -s * 0.38), col, 4.0)
		"oblivion":
			ci.draw_circle(c, s * 0.38, Color(col.r, col.g, col.b, 0.2))
			ci.draw_arc(c, s * 0.3, 0, TAU * 0.8, 16, col, 2.0)
			ci.draw_circle(c, s * 0.1, col.lightened(0.4))
		"blight":
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.3, col.darkened(0.4))
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.15), s * 0.12, col)
			ci.draw_circle(c + Vector2(s * 0.14, -s * 0.05), s * 0.09, col)
		_:
			ci.draw_circle(c, s * 0.3, col)
