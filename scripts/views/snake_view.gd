class_name SnakeView
extends Node2D
## Draws the snake as a glowing, tapering energy body interpolated between
## grid cells, with an exhaust trail from the tail and per-power-up looks.
## The body is built from textured quads (Config.disc / soft_dot): hundreds of
## antialiased draw_circle calls cost several ms per frame and caused input lag.

const R_BODY := 11.5
const R_TAIL := 5.0
const R_HEAD := 13.0
const SUBSTEPS := 3
## Seconds to blend away the forward jump when a turn triggers an early step.
const EARLY_STEP_BLEND := 0.05

## [head, tail, core] colour sets.
const PALETTE_BASE := [Config.SNAKE_HEAD, Config.SNAKE_TAIL, Config.SNAKE_CORE]
const PALETTE_HYPER := [Color(1.0, 0.85, 0.35), Color(1.0, 0.25, 0.1), Color(2.8, 1.8, 0.6)]
const PALETTE_WARP := [Color(0.45, 1.0, 0.65), Color(0.1, 0.45, 0.6), Color(0.9, 2.6, 1.4)]
const PALETTE_PHASE := [Color(0.8, 0.6, 1.0), Color(0.45, 0.15, 0.9), Color(1.8, 1.2, 2.8)]

var game: Game

var _palette: Array[Color] = [Config.SNAKE_HEAD, Config.SNAKE_TAIL, Config.SNAKE_CORE]
var _disc := Config.disc()
var _glow := Config.soft_dot()
var _trail: CPUParticles2D
var _seen_early_steps := 0
var _blend := 1.0
var _blend_from := PackedVector2Array()
var _last_drawn := PackedVector2Array()


func _ready() -> void:
	_trail = CPUParticles2D.new()
	_trail.amount = 90
	_trail.lifetime = 0.6
	_trail.local_coords = false
	_trail.show_behind_parent = true
	_trail.texture = _glow
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 4.0
	_trail.spread = 180.0
	_trail.gravity = Vector2.ZERO
	_trail.initial_velocity_min = 4.0
	_trail.initial_velocity_max = 22.0
	_trail.scale_amount_min = 0.12
	_trail.scale_amount_max = 0.28
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
	if game.early_steps != _seen_early_steps:
		_seen_early_steps = game.early_steps
		_blend_from = _last_drawn
		_blend = 0.0
	_blend = minf(1.0, _blend + delta / EARLY_STEP_BLEND)

	var target: Array = PALETTE_BASE
	if game.powerups.has(&"surge"):
		var hue := fmod(game.time * 0.35, 1.0)
		target = [Color.from_hsv(hue, 0.7, 1.1), Color.from_hsv(fmod(hue + 0.35, 1.0), 0.85, 1.0), Color.from_hsv(hue, 0.35, 2.6)]
	elif game.powerups.has(&"hyperdrive"):
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
		var cell := s.body[i]
		var prev := s.prev_body[mini(i, s.prev_body.size() - 1)]
		var d := cell - prev
		# Wrapped through a wormhole edge: slide in from just outside the board.
		if absi(d.x) > 1:
			d.x = -signi(d.x)
		if absi(d.y) > 1:
			d.y = -signi(d.y)
		var to := Config.cell_center(cell)
		pts.append((to - Vector2(d) * Config.CELL).lerp(to, t))
	if _blend < 1.0:
		for i in mini(pts.size(), _blend_from.size()):
			pts[i] = _blend_from[i].lerp(pts[i], _blend)
	return pts


func _draw() -> void:
	if not game.is_live():
		return
	var pts := _segment_points()
	_last_drawn = pts
	var n := pts.size()
	var t := game.time
	var alpha := 1.0
	if game.powerups.has(&"phase"):
		alpha = 0.4 + 0.15 * sin(t * 30.0)

	# Dense samples from tail to head so the body reads as one continuous tube.
	# Gaps (a wormhole wrap) break the tube instead of drawing across the board.
	var samples := PackedVector2Array()
	var ks := PackedFloat32Array() # 0 at head, 1 at tail
	var breaks := PackedInt32Array() # sample indices where a new tube run starts
	var gap_sq := (Config.CELL * 1.5) ** 2
	for i in range(n - 1, 0, -1):
		if pts[i].distance_squared_to(pts[i - 1]) > gap_sq:
			samples.append(pts[i])
			ks.append(float(i) / (n - 1))
			breaks.append(samples.size())
			continue
		for step in SUBSTEPS:
			var u := float(step) / SUBSTEPS
			samples.append(pts[i].lerp(pts[i - 1], u))
			ks.append((i - u) / float(n - 1))

	var count := samples.size()
	var radii := PackedFloat32Array()
	var colors := PackedColorArray()
	radii.resize(count)
	colors.resize(count)
	for j in count:
		radii[j] = _radius(ks[j])
		colors[j] = _palette[0].lerp(_palette[1], ks[j])

	# Outer haze, dark rim for definition, the body tube, a soft top highlight.
	for j in count:
		_quad(_glow, samples[j], radii[j] * 2.2, Color(colors[j], 0.12 * alpha))
	for j in count:
		_quad(_disc, samples[j], radii[j] + 1.5, Color(colors[j] * 0.25, alpha))
	for j in count:
		_quad(_disc, samples[j], radii[j], Color(colors[j], alpha))
	for j in count:
		_quad(_disc, samples[j] - Vector2(0, radii[j] * 0.35), radii[j] * 0.45, Color(colors[j].lightened(0.35), 0.5 * alpha))

	# Bright spine, one polyline per unbroken run.
	var start := 0
	breaks.append(count)
	for end in breaks:
		if end - start >= 2:
			var spine_colors := PackedColorArray()
			for j in range(start, end):
				spine_colors.append(Color(_palette[2] * (1.0 - ks[j] * 0.6), alpha))
			draw_polyline_colors(samples.slice(start, end), spine_colors, 2.5)
		start = end

	# Energy pulses travelling down the spine.
	for i in range(1, n):
		var e := pow(0.5 + 0.5 * sin(t * 8.0 - i * 0.7), 3.0)
		if e > 0.05:
			_quad(_disc, pts[i], _radius(float(i) / (n - 1)) * 0.4 * e, Color(_palette[2] * 1.2, alpha * e))

	var fwd := _heading()
	if game.powerups.has(&"lance"):
		_draw_lance(pts[0], fwd, t)
	_draw_head(pts[0], fwd, alpha, t)


func _quad(tex: Texture2D, center: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(tex, Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0), false, color)


func _radius(k: float) -> float:
	return lerpf(R_BODY, R_TAIL, pow(k, 2.2))


func _heading() -> Vector2:
	return Vector2(game.snake.direction)


## Plasma Lance: a flickering beam from the head to the board edge.
func _draw_lance(h: Vector2, fwd: Vector2, t: float) -> void:
	var rect := Config.board_rect()
	var end := h
	while rect.has_point(end + fwd * Config.CELL * 0.5):
		end += fwd * Config.CELL
	var flicker := 0.75 + 0.25 * sin(t * 40.0)
	var col: Color = game.powerups.active[&"lance"].color
	draw_line(h + fwd * R_HEAD, end, Color(col * 0.4, 0.35 * flicker), 9.0)
	draw_line(h + fwd * R_HEAD, end, Color(col, flicker), 2.5)
	_quad(_glow, end, 14.0 * flicker, Color(col, 0.8))


func _draw_head(h: Vector2, fwd: Vector2, alpha: float, t: float) -> void:
	var side := Vector2(-fwd.y, fwd.x)
	var head_col := Color(_palette[0], alpha)
	var core := Color(_palette[2], alpha)

	# Swept-back antennae.
	for sgn: float in [-1.0, 1.0]:
		var base := h + side * sgn * 6.0 - fwd * 3.0
		var tip := base - fwd * 11.0 + side * sgn * 7.0
		draw_line(base, tip, core, 2.0, true)
		_quad(_disc, tip, 2.4, Color(_palette[2] * 1.3, alpha))

	_quad(_glow, h, R_HEAD * 2.6, Color(_palette[0], 0.18 * alpha))
	_quad(_disc, h - fwd * 2.0, R_HEAD, head_col)
	_quad(_disc, h + fwd * 3.0, R_HEAD * 0.82, head_col)
	_quad(_disc, h + fwd * 1.0, R_HEAD * 0.45, Color(_palette[2] * 0.6, alpha))

	for sgn: float in [-1.0, 1.0]:
		var eye := h + fwd * 4.0 + side * sgn * 5.5
		_quad(_disc, eye, 3.6, Color(3.0, 3.0, 3.0, alpha))
		_quad(_disc, eye + fwd * 1.3, 1.7, Color(0.02, 0.02, 0.1, alpha))

	var pu := game.powerups
	if pu.has(&"shield"):
		var rr := R_HEAD + 9.0 + sin(t * 5.0) * 1.5
		_quad(_disc, h, rr, Color(0.3, 0.8, 1.5, 0.08))
		for k in 3:
			var a0 := t * 2.5 + k * TAU / 3.0
			draw_arc(h, rr, a0, a0 + 1.5, 16, Color(0.5, 1.8, 2.8), 2.5, true)
	if pu.has(&"gravity"):
		var col: Color = pu.active[&"gravity"].color
		for k in 3:
			var ph := fmod(t * 0.9 + k / 3.0, 1.0)
			draw_arc(h, lerpf(80.0, 16.0, ph), 0, TAU, 48, Color(col, ph * 0.35), 1.5)
	if pu.has(&"stasis"):
		var col: Color = pu.active[&"stasis"].color
		for k in 6:
			var a := t * 0.8 + k * TAU / 6.0
			_quad(_disc, h + Vector2(cos(a), sin(a)) * 24.0, 2.2, Color(col, 0.9))
	if pu.has(&"hyperdrive"):
		for k in 4:
			var off := side * randf_range(-8.0, 8.0)
			var streak := randf_range(18.0, 40.0)
			draw_line(h - fwd * 14.0 + off, h - fwd * (14.0 + streak) + off, Color(2.4, 1.3, 0.3, 0.5), 2.0)
