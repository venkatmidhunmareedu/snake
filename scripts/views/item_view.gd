class_name ItemView
extends Node2D
## Draws food stars, bonus stars and the power-up planet orb.

var game: Game
var _font: Font = preload("res://assets/fonts/Orbitron.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := game.time
	for f in game.foods:
		var c := Config.cell_center(f.cell)
		var appear := clampf(f.age * 5.0, 0.1, 1.0)
		if f.bonus:
			if f.ttl < 2.0 and fmod(t, 0.2) < 0.08:
				continue
			var pulse := 1.0 + 0.2 * sin(t * 9.0 + f.cell.x)
			_draw_star(c, 9.0 * pulse * appear, 3.5 * appear, 4, -t * 3.0, Config.BONUS_FOOD)
		else:
			var pulse := 1.0 + 0.15 * sin(t * 5.0)
			draw_circle(c, 15.0 * pulse * appear, Color(Config.FOOD * 0.3, 0.12), true, -1.0, true)
			_draw_star(c, 13.0 * pulse * appear, 4.5 * appear, 4, t * 1.2, Config.FOOD)
			_draw_star(c, 8.0 * appear, 3.0 * appear, 4, t * 1.2 + PI / 4.0, Config.FOOD * 0.7)
			draw_circle(c, 3.0 * appear, Color(3.0, 3.0, 2.6), true, -1.0, true)

	var orb := game.powerups.orb
	if orb != null:
		if orb.ttl < 2.0 and fmod(t, 0.25) < 0.1:
			return
		_draw_planet(Config.cell_center(orb.cell), orb, t)


func _draw_planet(c: Vector2, orb: PowerUpManager.Orb, t: float) -> void:
	var col := orb.kind.color
	var s := clampf(orb.age * 4.0, 0.1, 1.0) * (1.0 + 0.08 * sin(t * 6.0))
	var r := 11.0 * s
	var dim := Color(col.r * 0.3, col.g * 0.3, col.b * 0.3)

	draw_circle(c, r + 9.0, Color(dim, 0.25), true, -1.0, true)
	var ring := PackedVector2Array()
	var tilt := 0.45 + 0.15 * sin(t * 1.7)
	for i in 49:
		var a := TAU * i / 48.0
		ring.append(c + Vector2(cos(a) * r * 1.9, sin(a) * r * 0.55).rotated(tilt))
	draw_polyline(ring.slice(0, 25), Color(col, 0.6), 2.0, true)
	draw_circle(c, r, dim * 1.6, true, -1.0, true)
	draw_circle(c + Vector2(-r, -r) * 0.3, r * 0.55, Color(col * 0.55, 1.0), true, -1.0, true)
	draw_arc(c, r, 0, TAU, 32, col, 1.5, true)
	draw_polyline(ring.slice(24), col, 2.0, true)

	draw_string(_font, c + Vector2(-20, 5), orb.kind.glyph, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, Color(2.5, 2.5, 2.5))
	# Remaining lifetime.
	var frac := orb.ttl / Config.POWERUP_LIFETIME
	draw_arc(c, r + 12.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, Color(col, 0.7), 2.0, true)


func _draw_star(c: Vector2, outer: float, inner: float, points: int, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * i / points
		var rad := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, col)
