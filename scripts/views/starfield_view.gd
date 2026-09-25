class_name StarfieldView
extends Node2D
## Three parallax star layers drifting left, a distant ringed planet and the
## occasional shooting star. Stars stretch into streaks while warp is high
## (Hyperdrive) and nearly freeze during Time Warp.

const LAYERS := [
	{"count": 120, "speed": 5.0, "size": 0.9, "bright": 0.55},
	{"count": 70, "speed": 13.0, "size": 1.3, "bright": 0.85},
	{"count": 28, "speed": 28.0, "size": 1.9, "bright": 1.5},
]

var game: Game
var _glow := Config.soft_dot()

var _stars: Array[Dictionary] = []
var _warp := 1.0
var _shooting: Array[Dictionary] = []
var _next_shooting := 3.0


func _ready() -> void:
	for layer in LAYERS.size():
		for i in LAYERS[layer].count:
			_stars.append({
				"pos": Vector2(randf() * Config.VIEW_SIZE.x, randf() * Config.VIEW_SIZE.y),
				"layer": layer,
				"phase": randf() * TAU,
				"twinkle": randf_range(1.0, 3.5),
				"tint": Color(0.75, 0.85, 1.0).lerp(Color(1.0, 0.8, 0.9), randf() * 0.5),
			})


func _process(delta: float) -> void:
	_warp = lerpf(_warp, game.star_warp(), 1.0 - exp(-delta * 3.0))
	for s in _stars:
		var layer: Dictionary = LAYERS[s.layer]
		s.pos = s.pos - Vector2(layer.speed * _warp * delta, 0.0)
		if s.pos.x < -20.0:
			s.pos = Vector2(Config.VIEW_SIZE.x + randf() * 20.0, randf() * Config.VIEW_SIZE.y)

	_next_shooting -= delta
	if _next_shooting <= 0.0:
		_next_shooting = randf_range(3.0, 8.0)
		_shooting.append({
			"pos": Vector2(randf_range(200, Config.VIEW_SIZE.x + 100), -20),
			"vel": Vector2(-randf_range(500, 800), randf_range(250, 400)),
			"life": 1.2,
		})
	for i in range(_shooting.size() - 1, -1, -1):
		var sh: Dictionary = _shooting[i]
		sh.pos += sh.vel * delta
		sh.life -= delta
		if sh.life <= 0.0:
			_shooting.remove_at(i)
	queue_redraw()


func _draw() -> void:
	_draw_planet(Vector2(1235, 845), 130.0)
	var streak := clampf((_warp - 2.0) / 8.0, 0.0, 1.0)
	for s in _stars:
		var layer: Dictionary = LAYERS[s.layer]
		var tw := 0.65 + 0.35 * sin(game.time * s.twinkle + s.phase)
		var col: Color = s.tint * (layer.bright * tw)
		col.a = 1.0
		if streak > 0.0:
			var length: float = layer.speed * _warp * 0.06 * streak
			draw_line(s.pos, s.pos + Vector2(length, 0), col, layer.size)
		else:
			# Textured quads, not antialiased circles: ~20x cheaper per star.
			var r: float = layer.size * 2.2
			draw_texture_rect(_glow, Rect2(s.pos.x - r, s.pos.y - r, r * 2.0, r * 2.0), false, col)
	for sh in _shooting:
		var a: float = clampf(sh.life, 0.0, 1.0)
		var dir: Vector2 = sh.vel.normalized()
		draw_line(sh.pos - dir * 45.0, sh.pos, Color(1.2, 1.4, 2.0, a), 2.0)
		draw_texture_rect(_glow, Rect2(sh.pos - Vector2(5, 5), Vector2(10, 10)), false, Color(2.0, 2.2, 2.6, a))


func _draw_planet(c: Vector2, r: float) -> void:
	var ring := _ellipse(c, r * 1.9, r * 0.38, -0.3)
	# Back half of the ring, planet body with a lit crescent, then the front half.
	draw_polyline(ring.slice(0, ring.size() / 2 + 1), Color(0.55, 0.45, 0.8, 0.35), 5.0, true)
	draw_circle(c, r, Color(0.13, 0.07, 0.25), true, -1.0, true)
	for i in 6:
		var k := float(i) / 6.0
		draw_circle(c + Vector2(-r * 0.25, -r * 0.2) * k, r * (1.0 - k * 0.55), Color(0.28, 0.14, 0.5, 0.18), true, -1.0, true)
	draw_arc(c, r, 0, TAU, 64, Color(0.6, 0.45, 1.0, 0.35), 2.0, true)
	draw_polyline(ring.slice(ring.size() / 2), Color(0.7, 0.55, 0.95, 0.5), 5.0, true)


static func _ellipse(c: Vector2, a: float, b: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 65:
		var t := TAU * i / 64.0
		pts.append(c + Vector2(cos(t) * a, sin(t) * b).rotated(rot))
	return pts
