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
	preload("res://scripts/powerups/wormhole.gd"),
	preload("res://scripts/powerups/molt.gd"),
	preload("res://scripts/powerups/stellar_surge.gd"),
	preload("res://scripts/powerups/stasis_field.gd"),
	preload("res://scripts/powerups/plasma_lance.gd"),
	preload("res://scripts/powerups/quantum.gd"),
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
		var before := p.remaining
		p.remaining -= delta
		for mark in [1.5, 1.0, 0.5]:
			if before > mark and p.remaining <= mark:
				game.on_powerup_warning(p)
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


## Called when the head enters the orb's cell. Returns the activated power-up
## (for Quantum, the random power-up it rolled).
func collect(game: Game) -> PowerUp:
	var script: GDScript = orb.kind.get_script()
	if orb.kind.id == &"quantum":
		script = _pick_type(game, &"quantum").get_script()
	orb = null
	return activate(game, script)


func activate(game: Game, script: GDScript) -> PowerUp:
	var p: PowerUp = script.new()
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


## Random type that can spawn now, preferring ones that aren't already running
## (those would only refresh).
func _pick_type(game: Game, exclude: StringName = &"") -> PowerUp:
	var fresh: Array[PowerUp] = []
	var allowed: Array[PowerUp] = []
	for p in catalog:
		if p.id == exclude or not p.can_spawn(game):
			continue
		allowed.append(p)
		if not active.has(p.id):
			fresh.append(p)
	return fresh.pick_random() if not fresh.is_empty() else allowed.pick_random()


func _spawn_orb(game: Game) -> void:
	var cell := game.random_free_cell()
	if cell == Vector2i(-1, -1):
		spawn_timer = 2.0
		return
	orb = Orb.new()
	orb.cell = cell
	orb.kind = _pick_type(game)
	orb.ttl = Config.POWERUP_LIFETIME
	game.on_orb_spawned()
