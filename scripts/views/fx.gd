class_name Fx
extends Node2D
## One-shot visual effects: particle bursts, the death shatter, expanding
## shockwave rings and floating score text.

const RING_LIFE := 0.6
const TEXT_LIFE := 1.0

var game: Game

var _dot := Config.soft_dot()
var _font: Font = preload("res://assets/fonts/Orbitron.ttf")
var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []


func burst(pos: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := _particles(amount, 0.7)
	p.position = pos
	p.color = color
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	_emit(p)


## Breaks the snake into stardust: one emission point per body segment,
## coloured along the head-to-tail gradient.
func shatter(points: PackedVector2Array) -> void:
	var p := _particles(clampi(points.size() * 8, 40, 500), 1.8)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	var colors := PackedColorArray()
	for i in points.size():
		var k := float(i) / maxf(1.0, points.size() - 1)
		colors.append(Config.SNAKE_CORE.lerp(Config.SNAKE_TAIL * 2.0, k))
	p.emission_colors = colors
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 260.0
	p.damping_min = 60.0
	p.damping_max = 140.0
	p.scale_amount_max = 0.6
	_emit(p)


func shockwave(pos: Vector2, color: Color, radius: float) -> void:
	_rings.append({"pos": pos, "color": color, "radius": radius, "age": 0.0})


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_texts.append({"pos": pos, "text": text, "color": color, "age": 0.0})


func _process(delta: float) -> void:
	_age(_rings, delta, RING_LIFE)
	_age(_texts, delta, TEXT_LIFE)
	queue_redraw()


func _age(list: Array[Dictionary], delta: float, life: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		list[i].age += delta
		if list[i].age >= life:
			list.remove_at(i)


func _draw() -> void:
	for r in _rings:
		var k: float = r.age / RING_LIFE
		var grow := 1.0 - pow(1.0 - k, 3.0)
		draw_arc(r.pos, r.radius * grow, 0, TAU, 64, Color(r.color, 1.0 - k), 1.0 + 4.0 * (1.0 - k), true)
	for t in _texts:
		var k: float = t.age / TEXT_LIFE
		var pos: Vector2 = t.pos + Vector2(-90, -14 - 44.0 * k)
		draw_string(_font, pos, t.text, HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color(t.color, 1.0 - k * k))


func _particles(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.texture = _dot
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.damping_min = 100.0
	p.damping_max = 220.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p


func _emit(p: CPUParticles2D) -> void:
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
