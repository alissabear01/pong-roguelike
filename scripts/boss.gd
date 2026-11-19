extends StaticBody2D
## The boss: an AI paddle guarding the top of the boss room. It slides after
## whichever ball will reach it first, at a capped speed, so steep shots off
## the edge of your paddle can outrun it. Every ball you get past it costs it
## one health, and it speeds up a little each time.

## fires whenever health changes, so the boss bar can redraw
signal health_changed(health: int, max_health: int)
## fires once, when the last of its health is gone
signal defeated

## balls it has to let past before it's beaten
@export var max_health: int = 3
## px per s it can slide
@export var speed: float = 85.0
## px per s it gains each time a ball gets past it
@export var speed_per_hit: float = 12.0
## it lines up this many px (at most) off the ball's centre, rerolled for each
## incoming ball, so its returns come back at an angle and it sometimes whiffs
@export var aim_error: float = 14.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var health: int
var half_width: float

# the x range its centre can slide over, set by the level
var _min_x := -INF
var _max_x := INF
# the ball it's going after, and how far off centre it's lining up on it
var _target: Ball
var _offset := 0.0


func _ready() -> void:
	health = max_health
	half_width = collision.shape.size.x / 2


## keeps its centre between min_x and max_x (global x)
func set_lane(min_x: float, max_x: float) -> void:
	_min_x = min_x + half_width
	_max_x = max_x - half_width


func _physics_process(delta: float) -> void:
	var ball := _incoming_ball()
	if ball != _target:
		_target = ball
		_offset = randf_range(-aim_error, aim_error)

	# nothing coming: drift back to the middle
	var goal_x := (_min_x + _max_x) / 2
	if ball:
		goal_x = ball.global_position.x + _offset
	goal_x = clampf(goal_x, _min_x, _max_x)
	global_position.x = move_toward(global_position.x, goal_x, speed * delta)


# the ball heading our way that will get here soonest, or null
func _incoming_ball() -> Ball:
	var best: Ball = null
	var soonest := INF
	for ball: Ball in get_tree().get_nodes_in_group("balls"):
		# below us and moving up
		var gap := ball.global_position.y - global_position.y
		if ball.velocity.y >= 0.0 or gap <= 0.0:
			continue
		var time := gap / -ball.velocity.y
		if time < soonest:
			soonest = time
			best = ball
	return best


## Same rule as the player's paddle, facing down: straight back in the
## middle, out at max_angle (radians) at the ends.
func bounce_direction(point: Vector2, max_angle: float) -> Vector2:
	var offset := clampf((point.x - global_position.x) / half_width, -1.0, 1.0)
	var angle := max_angle * offset
	return Vector2(sin(angle), cos(angle))


## called by the level when a ball gets past us
func take_goal() -> void:
	if health <= 0:
		return
	health -= 1
	speed += speed_per_hit
	health_changed.emit(health, max_health)

	# flash white and shudder
	var tween := create_tween()
	sprite.modulate = Color(3, 3, 3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	for i in 4:
		tween.parallel().tween_property(sprite, "position",
			Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03).set_delay(i * 0.03)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.03)

	if health <= 0:
		defeated.emit()
