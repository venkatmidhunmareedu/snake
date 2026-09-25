class_name AiPilot
## Simple autopilot for the title-screen attract mode: head for the nearest
## food or orb, but avoid moves that lead into a pocket smaller than the snake.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func choose(game: Game) -> Vector2i:
	var s := game.snake
	var head := s.head()
	var target := _target(game, head)
	var d := s.direction
	var best := d
	var best_score := -INF
	for dir: Vector2i in [d, Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]:
		var c := head + dir
		if game.is_fatal(c, false):
			continue
		var need := s.body.size() + 2
		var space := space_from(game, c, need)
		var score := -float(absi(target.x - c.x) + absi(target.y - c.y)) + randf() * 0.3
		if space < need:
			score -= 500.0 - space
		if score > best_score:
			best_score = score
			best = dir
	return best


## Flood-fill count of reachable free cells from `start`, stopping at `cap`.
static func space_from(game: Game, start: Vector2i, cap: int) -> int:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size() and queue.size() < cap:
		var c := queue[i]
		i += 1
		for dir in DIRS:
			var n := c + dir
			if seen.has(n) or not Config.in_bounds(n) or game.snake.occupies(n):
				continue
			seen[n] = true
			queue.append(n)
	return queue.size()


static func _target(game: Game, head: Vector2i) -> Vector2i:
	var cells: Array[Vector2i] = []
	for f in game.foods:
		cells.append(f.cell)
	if game.powerups.orb != null:
		cells.append(game.powerups.orb.cell)
	var best := head
	var best_d := 1 << 30
	for c in cells:
		var dist := absi(c.x - head.x) + absi(c.y - head.y)
		if dist < best_d:
			best_d = dist
			best = c
	return best
