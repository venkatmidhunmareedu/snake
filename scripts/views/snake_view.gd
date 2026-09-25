class_name SnakeView
extends Node2D
## Draws the snake as a glowing, tapering energy body interpolated between
## grid cells, with an exhaust trail from the tail and per-power-up looks.

const R_BODY := 11.5
const R_TAIL := 5.0
const R_HEAD := 13.0
const SUBSTEPS := 3

## [head, tail, core] colour sets.
const PALETTE_BASE := [Config.SNAKE_HEAD, Config.SNAKE_TAIL, Config.SNAKE_CORE]
const PALETTE_HYPER := [Color(1.0, 0.85, 0.35), Color(1.0, 0.25, 0.1), Color(2.8, 1.8, 0.6)]
const PALETTE_WARP := [Color(0.45, 1.0, 0.65), Color(0.1, 0.45, 0.6), Color(0.9, 2.6, 1.4)]
const PALETTE_PHASE := [Color(0.8, 0.6, 1.0), Color(0.45, 0.15, 0.9), Color(1.8, 1.2, 2.8)]

var game: Game

var _palette: Array[Color] = [Config.SNAKE_HEAD, Config.SNAKE_TAIL, Config.SNAKE_CORE]
var _trail: CPUParticles2D


func _ready() -> void:
	_trail = CPUParticles2D.new()
	_trail.amount = 90
	_trail.lifetime = 0.6
	_trail.local_coords = false
	_trail.show_behind_parent = true
	_trail.texture = Config.soft_dot()
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 4.0
	_trail.spread = 180.0
	_trail.gravity = Vector2.ZERO
	_trail.initial_velocity_min = 4.0
	_trail.initial_velocity_max = 22.0
	_trail.scale_amount_min = 0.25
	_trail.scale_amount_max = 0.55
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_trail.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	_trail.color_ramp = ramp
	add_child(_trail)


func _process(delta: float) -> void:
	var target: Array = PALETTE_BASE
	if game.powerups.has(&"hyperdrive"):
		target = PALETTE_HYPER
	elif game.powerups.has(&"timewarp"):
		target = PALETTE_WARP
	elif game.powerups.has(&"phase"):
		target = PALETTE_PHASE
	var w := 1.0 - exp(-delta * 6.0)
	for i in 3:
		_palette[i] = _palette[i].lerp(target[i], w)

	var live := game.is_live()
	_trail.emitting = live
	if live:
		var pts := _segment_points()
		_trail.position = pts[pts.size() - 1]
		_trail.color = _palette[2] * (1.6 if game.powerups.has(&"hyperdrive") else 1.0)
	queue_redraw()


func _segment_points() -> PackedVector2Array:
	var s := game.snake
	var t := game.tick_progress
	var pts := PackedVector2Array()
	for i in s.body.size():
		var from := Config.cell_center(s.prev_body[mini(i, s.prev_body.size() - 1)])
		pts.append(from.lerp(Config.cell_center(s.body[i]), t))
	return pts


func _draw() -> void:
	if not game.is_live():
		return
	var pts := _segment_points()
	var n := pts.size()
	var t := game.time
	var alpha := 1.0
	if game.powerups.has(&"phase"):
		alpha = 0.4 + 0.15 * sin(t * 30.0)

	# Dense samples from tail to head so the body reads as one continuous tube.
	var samples := PackedVector2Array()
	var ks := PackedFloat32Array() # 0 at head, 1 at tail
	for i in range(n - 1, 0, -1):
		for step in SUBSTEPS:
			var u := float(step) / SUBSTEPS
			samples.append(pts[i].lerp(pts[i - 1], u))
			ks.append((i - u) / float(n - 1))

	# Outer haze, dark rim for definition, the body tube, then a bright spine.
	for j in samples.size():
		draw_circle(samples[j], _radius(ks[j]) * 1.8, Color(_color(ks[j]), 0.05 * alpha), true, -1.0, true)
	for j in samples.size():
		draw_circle(samples[j], _radius(ks[j]) + 1.5, Color(_color(ks[j]) * 0.25, alpha), true, -1.0, true)
	for j in samples.size():
		draw_circle(samples[j], _radius(ks[j]), Color(_color(ks[j]), alpha), true, -1.0, true)
	for j in samples.size():
		draw_circle(samples[j] - Vector2(0, _radius(ks[j]) * 0.35), _radius(ks[j]) * 0.45, Color(_color(ks[j]).lightened(0.35), 0.5 * alpha), true, -1.0, true)
	if samples.size() >= 2:
		var spine_colors := PackedColorArray()
		for k in ks:
			spine_colors.append(Color(_palette[2] * (1.0 - k * 0.6), alpha))
		draw_polyline_colors(samples, spine_colors, 2.5, true)
	# Energy pulses travelling down the spine.
	for i in range(1, n):
		var k := float(i) / (n - 1)
		var e := pow(0.5 + 0.5 * sin(t * 8.0 - i * 0.7), 3.0)
		draw_circle(pts[i], _radius(k) * 0.4 * e, Color(_palette[2] * 1.2, alpha * e), true, -1.0, true)

	_draw_head(pts[0], _heading(), alpha, t)


func _radius(k: float) -> float:
	return lerpf(R_BODY, R_TAIL, pow(k, 2.2))


func _color(k: float) -> Color:
	return _palette[0].lerp(_palette[1], k)


func _heading() -> Vector2:
	var s := game.snake
	var d := s.body[0] - s.prev_body[0]
	return Vector2(d if d != Vector2i.ZERO else s.direction)


func _draw_head(h: Vector2, fwd: Vector2, alpha: float, t: float) -> void:
	var side := Vector2(-fwd.y, fwd.x)
	var head_col := Color(_palette[0], alpha)
	var core := Color(_palette[2], alpha)

	# Swept-back antennae.
	for sgn: float in [-1.0, 1.0]:
		var base := h + side * sgn * 6.0 - fwd * 3.0
		var tip := base - fwd * 11.0 + side * sgn * 7.0
		draw_line(base, tip, core, 2.0, true)
		draw_circle(tip, 2.4, Color(_palette[2] * 1.3, alpha), true, -1.0, true)

	draw_circle(h, R_HEAD * 2.0, Color(_palette[0], 0.07 * alpha), true, -1.0, true)
	draw_circle(h - fwd * 2.0, R_HEAD, head_col, true, -1.0, true)
	draw_circle(h + fwd * 3.0, R_HEAD * 0.82, head_col, true, -1.0, true)
	draw_circle(h + fwd * 1.0, R_HEAD * 0.45, Color(_palette[2] * 0.6, alpha), true, -1.0, true)

	for sgn: float in [-1.0, 1.0]:
		var eye := h + fwd * 4.0 + side * sgn * 5.5
		draw_circle(eye, 3.6, Color(3.0, 3.0, 3.0, alpha), true, -1.0, true)
		draw_circle(eye + fwd * 1.3, 1.7, Color(0.02, 0.02, 0.1, alpha), true, -1.0, true)

	var pu := game.powerups
	if pu.has(&"shield"):
		var rr := R_HEAD + 9.0 + sin(t * 5.0) * 1.5
		draw_circle(h, rr, Color(0.3, 0.8, 1.5, 0.08), true, -1.0, true)
		for k in 3:
			var a0 := t * 2.5 + k * TAU / 3.0
			draw_arc(h, rr, a0, a0 + 1.5, 16, Color(0.5, 1.8, 2.8), 2.5, true)
	if pu.has(&"gravity"):
		var col: Color = pu.active[&"gravity"].color
		for k in 3:
			var ph := fmod(t * 0.9 + k / 3.0, 1.0)
			draw_arc(h, lerpf(80.0, 16.0, ph), 0, TAU, 48, Color(col, ph * 0.35), 1.5, true)
	if pu.has(&"hyperdrive"):
		for k in 4:
			var off := side * randf_range(-8.0, 8.0)
			var streak := randf_range(18.0, 40.0)
			draw_line(h - fwd * 14.0 + off, h - fwd * (14.0 + streak) + off, Color(2.4, 1.3, 0.3, 0.5), 2.0, true)
