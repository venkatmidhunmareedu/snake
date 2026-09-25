class_name Snake
extends RefCounted
## Pure grid logic for the snake. body[0] is the head. prev_body holds the
## previous tick's body so the renderer can interpolate between cells.

var body: Array[Vector2i] = []
var prev_body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var grow_pending := 0
var _turns: Array[Vector2i] = []


func reset(head_cell: Vector2i, length: int, dir: Vector2i) -> void:
	body.clear()
	for i in length:
		body.append(head_cell - dir * i)
	prev_body = body.duplicate()
	direction = dir
	grow_pending = 0
	_turns.clear()


func head() -> Vector2i:
	return body[0]


## Buffers up to two turns so quick key sequences (e.g. up-left) aren't lost.
## Reversal into the neck is rejected against the last queued direction.
func queue_direction(dir: Vector2i) -> void:
	var last: Vector2i = direction if _turns.is_empty() else _turns.back()
	if dir == last or dir == -last or _turns.size() >= 2:
		return
	_turns.append(dir)


func force_direction(dir: Vector2i) -> void:
	direction = dir
	_turns.clear()


func consume_turn() -> void:
	if not _turns.is_empty():
		direction = _turns.pop_front()


func next_head() -> Vector2i:
	return body[0] + direction


## True if moving the head onto `cell` hits the body. The tail cell is free
## unless the snake is growing this tick (the tail stays put).
func hits_self(cell: Vector2i, growing: bool) -> bool:
	var n := body.size() if growing else body.size() - 1
	for i in n:
		if body[i] == cell:
			return true
	return false


func occupies(cell: Vector2i) -> bool:
	return body.has(cell)


func advance() -> void:
	prev_body = body.duplicate()
	body.push_front(next_head())
	if grow_pending > 0:
		grow_pending -= 1
	else:
		body.pop_back()
