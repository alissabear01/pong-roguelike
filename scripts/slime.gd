extends "res://scripts/enemy.gd"
## Once a second it glides to one of the tiles next to where it spawned, so it
## never strays more than a tile from home.

## how far each spot it moves to is from home, one tile
@export var hop_distance: float = 16.0
## seconds between moves
@export var move_interval: float = 1.0
## seconds each glide takes
@export var glide_time: float = 0.4

# the tiles beside home that the whole body fits on
var _spots: Array[Vector2] = []
var _timer := Timer.new()


func _ready() -> void:
	super._ready()
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var spot: Vector2 = home + dir * hop_distance
		if _fits_at(spot):
			_spots.append(spot)
	if _spots.is_empty():
		return

	_timer.one_shot = true
	_timer.timeout.connect(_move)
	add_child(_timer)
	# first move comes at a random point in the second so slimes don't all go together
	_timer.start(randf_range(0.1, move_interval))


func _move() -> void:
	# anywhere but the tile it's already on
	var choices := _spots.filter(func(spot: Vector2) -> bool: return not spot.is_equal_approx(position))
	var target: Vector2 = choices[randi_range(0, choices.size() - 1)]

	var tween := create_tween()
	# move with the physics step so the ball sees where we really are
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", target, glide_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_timer.start(move_interval)
