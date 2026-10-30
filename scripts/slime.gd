extends "res://scripts/enemy.gd"
## Once a second it glides to one of the tiles next to where it spawned, so it
## never strays more than a tile from home. Leaves a fading trail as it goes.

## how far each spot it moves to is from home, one tile
@export var hop_distance: float = 16.0
## seconds between moves
@export var move_interval: float = 1.0
## seconds each glide takes
@export var glide_time: float = 0.7
## trail colour, the slime's body green
@export var trail_color: Color = Color("62aa67")
## px across the trail
@export var trail_width: float = 10.0
## seconds each bit of trail lasts before it's gone
@export var trail_fade: float = 0.3

# the tiles beside home that the whole body fits on
var _spots: Array[Vector2] = []
var _timer := Timer.new()
var _gliding := false
# the trail. lives in the level just before us so it draws underneath us
var _trail := Line2D.new()
# when each trail point was dropped, in seconds of _clock
var _trail_times: Array[float] = []
var _clock := 0.0


func _ready() -> void:
	super._ready()
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var spot: Vector2 = home + dir * hop_distance
		if _fits_at(spot):
			_spots.append(spot)
	if _spots.is_empty():
		return

	_trail.width = trail_width
	# solid at our end, see-through at the tail
	var fade := Gradient.new()
	fade.set_color(0, Color(trail_color, 0.0))
	fade.set_color(1, trail_color)
	_trail.gradient = fade
	# deferred in case the level is still adding its children
	_attach_trail.call_deferred()

	_timer.one_shot = true
	_timer.timeout.connect(_move)
	add_child(_timer)
	# first move comes at a random point in the second so slimes don't all go together
	_timer.start(randf_range(0.1, move_interval))


func _physics_process(delta: float) -> void:
	_clock += delta
	if _gliding and _trail.is_inside_tree():
		_trail.add_point(_trail.to_local(sprite.global_position))
		_trail_times.append(_clock)
	# drop the tail as it gets old, so the trail shrinks away once we stop
	while not _trail_times.is_empty() and _clock - _trail_times[0] > trail_fade:
		_trail.remove_point(0)
		_trail_times.pop_front()


func _move() -> void:
	# anywhere but the tile it's already on
	var choices := _spots.filter(func(spot: Vector2) -> bool: return not spot.is_equal_approx(position))
	var target: Vector2 = choices[randi_range(0, choices.size() - 1)]

	_gliding = true
	var tween := create_tween()
	# move with the physics step so the ball sees where we really are
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", target, glide_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void: _gliding = false)
	_timer.start(move_interval)


## puts the trail in the level just before us, so it stays put while we move
## and draws under us (a child of ours would always draw on top)
func _attach_trail() -> void:
	get_parent().add_child(_trail)
	get_parent().move_child(_trail, get_index())


func _exit_tree() -> void:
	# the trail isn't ours, so take it with us when we die
	if is_instance_valid(_trail):
		_trail.queue_free()
