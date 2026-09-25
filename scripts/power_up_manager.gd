class_name PowerUpManager
extends RefCounted
## Owns the power-up orb on the field and the set of active effects.

const TYPES: Array[GDScript] = [
	preload("res://scripts/powerups/hyperdrive.gd"),
	preload("res://scripts/powerups/phase_shift.gd"),
	preload("res://scripts/powerups/gravity_well.gd"),
	preload("res://scripts/powerups/time_warp.gd"),
	preload("res://scripts/powerups/force_shield.gd"),
	preload("res://scripts/powerups/supernova.gd"),
]


class Orb:
	var cell: Vector2i
	var kind: PowerUp ## prototype instance, used for colour/glyph and on pickup
	var ttl: float
	var age := 0.0


var active: Dictionary[StringName, PowerUp] = {}
var orb: Orb = null
var spawn_timer := Config.POWERUP_FIRST_SPAWN
## One prototype of every type, for legends and UI.
var catalog: Array[PowerUp] = []


func _init() -> void:
	for t in TYPES:
		catalog.append(t.new())


func reset() -> void:
	active.clear()
	orb = null
	spawn_timer = Config.POWERUP_FIRST_SPAWN


func has(id: StringName) -> bool:
	return active.has(id)


func tick_factor() -> float:
	var f := 1.0
	for p in active.values():
		f *= p.tick_factor()
	return f


func score_factor() -> int:
	var f := 1
	for p in active.values():
		f *= p.score_factor()
	return f


func warp_factor() -> float:
	var f := 1.0
	for p in active.values():
		f *= p.warp_factor()
	return f


func update(game: Game, delta: float) -> void:
	for id in active.keys():
		var p: PowerUp = active[id]
		if is_inf(p.duration):
			continue
		p.remaining -= delta
		if p.remaining <= 0.0:
			active.erase(id)
			p.expire(game)
			game.on_powerup_expired(p)

	if orb == null:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_orb(game)
	else:
		orb.age += delta
		orb.ttl -= delta
		if orb.ttl <= 0.0:
			orb = null
			spawn_timer = randf_range(Config.POWERUP_SPAWN_MIN, Config.POWERUP_SPAWN_MAX)


## Called when the head enters the orb's cell. Returns the activated power-up.
func collect(game: Game) -> PowerUp:
	var script: GDScript = orb.kind.get_script()
	var p: PowerUp = script.new()
	orb = null
	spawn_timer = randf_range(Config.POWERUP_SPAWN_MIN, Config.POWERUP_SPAWN_MAX)
	p.remaining = p.duration
	if not p.is_instant():
		if active.has(p.id):
			active[p.id].remaining = p.duration
		else:
			active[p.id] = p
	p.apply(game)
	return p


func consume(id: StringName, game: Game) -> void:
	if active.has(id):
		var p: PowerUp = active[id]
		active.erase(id)
		p.expire(game)


func _spawn_orb(game: Game) -> void:
	var cell := game.random_free_cell()
	if cell == Vector2i(-1, -1):
		spawn_timer = 2.0
		return
	# Don't offer something that's already running (it would only refresh).
	var choices: Array[PowerUp] = []
	for p in catalog:
		if not active.has(p.id):
			choices.append(p)
	if choices.is_empty():
		choices = catalog
	orb = Orb.new()
	orb.cell = cell
	orb.kind = choices.pick_random()
	orb.ttl = Config.POWERUP_LIFETIME
	game.on_orb_spawned()
