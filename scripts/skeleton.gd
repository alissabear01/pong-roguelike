extends "res://scripts/enemy.gd"
## Walks back and forth along a short stretch either side of where it spawned,
## turning to face the way it walks. The shield turns with it.

## px it walks either side of its spawn spot
@export var patrol_distance: float = 16.0
## walk speed in px per s
@export var walk_speed: float = 15.0

# the ends of the walk, as x positions
var _left: float
var _right: float
# 1 walking right, -1 walking left
var _dir: float
# each collision shape's x when facing left, the way the sprite is drawn
var _shape_x := {}


func _ready() -> void:
	super._ready()
	for shape: CollisionShape2D in find_children("*", "CollisionShape2D", true, false):
		_shape_x[shape] = shape.position.x

	_left = home.x
	_right = home.x
	if move_bounds.has_area():
		# cut the walk short wherever the body would poke out of move_bounds
		var body := _body_rect()
		_left = minf(home.x, maxf(home.x - patrol_distance, move_bounds.position.x - body.position.x))
		_right = maxf(home.x, minf(home.x + patrol_distance, move_bounds.end.x - body.end.x))

	_face(1.0 if randf() < 0.5 else -1.0)


func _physics_process(delta: float) -> void:
	if _right - _left < 1.0:
		return
	var end := _right if _dir > 0 else _left
	position.x = move_toward(position.x, end, walk_speed * delta)
	if position.x == end:
		_face(-_dir)


# flips the sprite and mirrors the hitbox and shield to face dir
func _face(dir: float) -> void:
	_dir = dir
	sprite.flip_h = dir > 0
	for shape: CollisionShape2D in _shape_x:
		shape.position.x = _shape_x[shape] * -dir
