class_name Game
extends Node2D
## Root of the game. Owns the state machine and the fixed-tick simulation, and
## builds every view node (background, board, items, snake, fx, HUD) in code.
## Views hold a reference to this node and read its state each frame.

enum State { MENU, PLAYING, PAUSED, GAME_OVER }


class Food:
	var cell: Vector2i
	var bonus := false
	var ttl := INF
	var age := 0.0


const BONUS_TTL := 7.0
## A turn pressed once at least this much of the current step has elapsed is
## applied immediately instead of waiting for the next tick.
const EARLY_TURN_PROGRESS := 0.12
const COMBO_BANNERS := {3: "NICE", 5: "STELLAR", 8: "GALACTIC"}

var state := State.MENU
## True while the AI pilot plays behind the title screen.
var ai_mode := true
var snake := Snake.new()
var powerups := PowerUpManager.new()
var foods: Array[Food] = []

var score := 0
var high_score := 0
var new_record := false
var eaten := 0
var combo := 0
var combo_timer := 0.0
var time := 0.0
## 0..1 progress from the previous tick to the next, used to interpolate drawing.
var tick_progress := 0.0
## Seconds since the last state change.
var state_time := 0.0
## Bumped whenever a step happens early, so the snake view can smooth the jump.
var early_steps := 0

var hud: Hud
var fx: Fx
var sfx: Sfx

var _camera: Camera2D
var _tick_accum := 0.0
var _tick_count := 0
var _shake := 0.0


func _ready() -> void:
	_load_high_score()
	_build_scene()
	_start(true)


func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 1
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_hdr_threshold = 1.0
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)

	# Oversized so screen shake never reveals the edge.
	var nebula := _shader_rect(preload("res://shaders/nebula.gdshader"), Rect2(-40, -40, Config.VIEW_SIZE.x + 80, Config.VIEW_SIZE.y + 80))
	add_child(nebula)
	_add_view(StarfieldView.new())
	add_child(_shader_rect(preload("res://shaders/grid.gdshader"), Config.board_rect()))
	_add_view(BoardView.new())
	_add_view(ItemView.new())
	_add_view(SnakeView.new())
	fx = Fx.new()
	_add_view(fx)

	sfx = Sfx.new()
	sfx.game = self
	add_child(sfx)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)


func _add_view(view: Node2D) -> void:
	view.set("game", self)
	add_child(view)


func _shader_rect(shader: Shader, rect: Rect2) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	r.material = mat
	return r


# --- State machine -----------------------------------------------------------

func _start(ai: bool) -> void:
	ai_mode = ai
	snake.reset(Config.START_CELL, Config.START_LENGTH, Vector2i.RIGHT)
	foods.clear()
	powerups.reset()
	score = 0
	eaten = 0
	combo = 0
	combo_timer = 0.0
	new_record = false
	_tick_accum = 0.0
	_tick_count = 0
	tick_progress = 0.0
	_spawn_food()
	_set_state(State.MENU if ai else State.PLAYING)


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0


func _launch() -> void:
	sfx.play(&"launch")
	_start(false)
	hud.banner("LAUNCH", "grab the stars · ride the power-ups", Config.ACCENT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if event.is_action_pressed("toggle_music"):
		sfx.toggle_music()
		return
	match state:
		State.PLAYING:
			if event.is_action_pressed("pause"):
				_set_state(State.PAUSED)
				sfx.play(&"blip")
			elif event.is_action_pressed("move_up"):
				_steer(Vector2i.UP)
			elif event.is_action_pressed("move_down"):
				_steer(Vector2i.DOWN)
			elif event.is_action_pressed("move_left"):
				_steer(Vector2i.LEFT)
			elif event.is_action_pressed("move_right"):
				_steer(Vector2i.RIGHT)
		State.PAUSED:
			if event.is_action_pressed("pause") or event.is_action_pressed("confirm"):
				_set_state(State.PLAYING)
				sfx.play(&"blip")
		State.MENU:
			if event.is_action_pressed("confirm"):
				_launch()
		State.GAME_OVER:
			if ai_mode or state_time > 0.8:
				if event.is_action_pressed("confirm"):
					_launch()
				elif event.is_action_pressed("pause") and not ai_mode:
					_start(true)


func _steer(dir: Vector2i) -> void:
	var first := not snake.has_pending_turn()
	if not snake.queue_direction(dir):
		return
	sfx.play(&"turn")
	if first and tick_progress >= EARLY_TURN_PROGRESS:
		_tick_accum = 0.0
		tick_progress = 0.0
		early_steps += 1
		_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING:
		_set_state(State.PAUSED)


# --- Simulation --------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	state_time += delta
	if state == State.MENU or state == State.PLAYING:
		_simulate(delta)
	elif state == State.GAME_OVER and ai_mode and state_time > 2.0:
		_start(true)
	_shake = move_toward(_shake, 0.0, delta * 1.6)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 18.0


func _simulate(delta: float) -> void:
	powerups.update(self, delta)
	for i in range(foods.size() - 1, -1, -1):
		var f := foods[i]
		f.age += delta
		f.ttl -= delta
		if f.ttl <= 0.0:
			foods.remove_at(i)
	if combo_timer > 0.0 and not powerups.has(&"stasis"):
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0

	var interval := tick_interval()
	_tick_accum += delta
	while _tick_accum >= interval:
		_tick_accum -= interval
		_tick()
		if state == State.GAME_OVER:
			return
	tick_progress = _tick_accum / interval


func tick_interval() -> float:
	return maxf(Config.MIN_TICK, Config.BASE_TICK - eaten * Config.TICK_STEP) * powerups.tick_factor()


func _tick() -> void:
	if ai_mode:
		snake.force_direction(AiPilot.choose(self))
	snake.consume_turn()
	var next := resolve(snake.next_head())
	var food_i := _food_index(next)
	if is_fatal(next, food_i >= 0 or snake.grow_pending > 0):
		if not _try_shield():
			_die()
			return
		next = resolve(snake.next_head())
		food_i = _food_index(next)

	if food_i >= 0:
		snake.grow_pending += 1
	if next != snake.next_head():
		sfx.play(&"wrap")
	snake.advance(next)
	_tick_count += 1

	if food_i >= 0:
		_eat(food_i)
	if powerups.orb != null and powerups.orb.cell == next:
		_collect_powerup()
	if powerups.has(&"gravity") and _tick_count % 2 == 0:
		_pull_food()
	if powerups.has(&"lance"):
		_fire_lance()


## Wormhole: cells past an edge come out on the opposite side.
func resolve(cell: Vector2i) -> Vector2i:
	if powerups.has(&"wormhole"):
		return Vector2i(posmod(cell.x, Config.GRID.x), posmod(cell.y, Config.GRID.y))
	return cell


func is_fatal(cell: Vector2i, growing: bool) -> bool:
	if not Config.in_bounds(cell):
		return true
	if powerups.has(&"phase"):
		return false
	return snake.hits_self(cell, growing)


## Force Shield: swerve onto the roomier safe side instead of crashing.
func _try_shield() -> bool:
	if not powerups.has(&"shield"):
		return false
	var d := snake.direction
	var best := Vector2i.ZERO
	var best_space := -1
	for side: Vector2i in [Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]:
		var cell := resolve(snake.head() + side)
		if is_fatal(cell, _food_index(cell) >= 0):
			continue
		var space := AiPilot.space_from(self, cell, 64)
		if space > best_space:
			best_space = space
			best = side
	if best == Vector2i.ZERO:
		return false

	powerups.consume(&"shield", self)
	snake.force_direction(best)
	var pos := Config.cell_center(snake.head())
	fx.shockwave(pos, Color(0.4, 1.6, 2.6), 110.0)
	fx.burst(pos, Color(0.4, 1.6, 2.6), 26, 240.0)
	fx.float_text(pos, "SHIELD DOWN", Color(0.5, 1.4, 2.0))
	hud.flash(Color(0.4, 0.8, 1.0), 0.35)
	sfx.play(&"shield")
	_shake = maxf(_shake, 0.55)
	return true


func _eat(index: int) -> void:
	var f := foods[index]
	foods.remove_at(index)
	eaten += 1
	var prev_combo := combo
	combo = mini(combo + 1, Config.COMBO_MAX) if combo_timer > 0.0 else 1
	combo_timer = Config.COMBO_WINDOW
	var points := Config.FOOD_POINTS * combo * powerups.score_factor()
	_add_score(points)

	var pos := Config.cell_center(f.cell)
	var col := Config.BONUS_FOOD if f.bonus else Config.FOOD
	fx.burst(pos, col, 16, 170.0)
	fx.float_text(pos, "+%d" % points, col)
	sfx.play(&"bonus" if f.bonus else &"eat", 1.0 + (combo - 1) * 0.07)
	if combo != prev_combo and COMBO_BANNERS.has(combo):
		hud.banner("COMBO ×%d" % combo, COMBO_BANNERS[combo], Config.BONUS_FOOD)
		sfx.play(&"combo")
	if not f.bonus:
		_spawn_food()


func _add_score(points: int) -> void:
	score += points
	if not ai_mode and score > high_score:
		high_score = score
		new_record = true


func _collect_powerup() -> void:
	var pos := Config.cell_center(powerups.orb.cell)
	var rolled := powerups.orb.kind.id == &"quantum"
	var p := powerups.collect(self)
	fx.shockwave(pos, p.color, 140.0)
	fx.burst(pos, p.color, 32, 280.0)
	hud.banner(p.display_name, ("quantum roll · " if rolled else "") + p.tagline, p.color)
	var sound := &"shield_up" if p.id == &"shield" else p.id
	if rolled:
		sfx.play(&"quantum")
		sfx.play_later(sound, 0.33)
	else:
		sfx.play(sound)
	_shake = maxf(_shake, 0.3)


func _die() -> void:
	var points := PackedVector2Array()
	for c in snake.body:
		points.append(Config.cell_center(c))
	fx.shatter(points)
	fx.shockwave(Config.cell_center(snake.head()), Config.DANGER, 180.0)
	hud.flash(Color(1.0, 0.35, 0.55), 0.5)
	sfx.play(&"death")
	_shake = 1.0
	combo = 0
	_set_state(State.GAME_OVER)
	if not ai_mode:
		_save_high_score()
		if new_record:
			sfx.play_later(&"record", 0.9)


func on_powerup_expired(p: PowerUp) -> void:
	sfx.play(&"expire")
	fx.float_text(Config.cell_center(snake.head()), p.display_name + " OFF", Color(p.color, 0.8))


func on_powerup_warning(_p: PowerUp) -> void:
	sfx.play(&"warn")


func on_orb_spawned() -> void:
	sfx.play(&"spawn")
	fx.shockwave(Config.cell_center(powerups.orb.cell), powerups.orb.kind.color, 50.0)


# --- Board helpers -----------------------------------------------------------

func _food_index(cell: Vector2i) -> int:
	for i in foods.size():
		if foods[i].cell == cell:
			return i
	return -1


func is_free(cell: Vector2i) -> bool:
	if not Config.in_bounds(cell) or snake.occupies(cell) or _food_index(cell) >= 0:
		return false
	return powerups.orb == null or powerups.orb.cell != cell


## Returns (-1, -1) when the board is full.
func random_free_cell() -> Vector2i:
	var free: Array[Vector2i] = []
	for y in Config.GRID.y:
		for x in Config.GRID.x:
			var c := Vector2i(x, y)
			if is_free(c):
				free.append(c)
	return Vector2i(-1, -1) if free.is_empty() else free.pick_random()


func _spawn_food() -> void:
	var cell := random_free_cell()
	if cell != Vector2i(-1, -1):
		var f := Food.new()
		f.cell = cell
		foods.append(f)


## Supernova: scatter short-lived bonus stars in a ring around the head.
func spawn_bonus_burst(count: int) -> void:
	var head := snake.head()
	var cells: Array[Vector2i] = []
	for y in range(-6, 7):
		for x in range(-6, 7):
			var c := head + Vector2i(x, y)
			if maxi(absi(x), absi(y)) >= 2 and is_free(c):
				cells.append(c)
	cells.shuffle()
	for i in mini(count, cells.size()):
		var f := Food.new()
		f.cell = cells[i]
		f.bonus = true
		f.ttl = BONUS_TTL
		foods.append(f)
		fx.burst(Config.cell_center(f.cell), Config.BONUS_FOOD, 8, 120.0)


## Molt: shed ~40% of the growth as stardust, scoring for every segment.
func molt() -> void:
	var shed := int((snake.body.size() - Config.START_LENGTH) * 0.4)
	if shed <= 0:
		return
	var pts := PackedVector2Array()
	for i in shed:
		pts.append(Config.cell_center(snake.body[snake.body.size() - 1 - i]))
	snake.trim(snake.body.size() - shed)
	var points := shed * 5 * powerups.score_factor()
	_add_score(points)
	fx.shatter(pts)
	fx.float_text(Config.cell_center(snake.head()), "SHED %d  +%d" % [shed, points], Color(1.4, 2.4, 0.3))


## Plasma Lance: eat every star in a straight line ahead of the head.
func _fire_lance() -> void:
	var cell := snake.head() + snake.direction
	while Config.in_bounds(cell):
		var i := _food_index(cell)
		if i >= 0:
			fx.burst(Config.cell_center(cell), Color(2.8, 0.5, 0.4), 12, 200.0)
			sfx.play(&"zap")
			snake.grow_pending += 1
			_eat(i)
		cell += snake.direction


## Gravity Well: every food steps one cell toward the head.
func _pull_food() -> void:
	var head := snake.head()
	for f in foods:
		var d := head - f.cell
		if absi(d.x) + absi(d.y) <= 1:
			continue
		var steps: Array[Vector2i] = [Vector2i(signi(d.x), 0), Vector2i(0, signi(d.y))]
		if absi(d.y) > absi(d.x):
			steps.reverse()
		for s in steps:
			if s != Vector2i.ZERO and is_free(f.cell + s):
				f.cell += s
				break


# --- Queries for views ---------------------------------------------------------

func is_live() -> bool:
	return state != State.GAME_OVER


func speed_multiplier() -> float:
	return Config.BASE_TICK / tick_interval()


func star_warp() -> float:
	if state == State.PAUSED or state == State.GAME_OVER:
		return 0.3
	return powerups.warp_factor() * (1.0 + eaten * 0.03)


# --- Persistence -------------------------------------------------------------

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Config.SAVE_PATH) == OK:
		high_score = int(cfg.get_value("scores", "high", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Config.SAVE_PATH) # keep other sections (audio settings)
	cfg.set_value("scores", "high", high_score)
	cfg.save(Config.SAVE_PATH)
