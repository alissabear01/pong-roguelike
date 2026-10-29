class_name Ball

extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

## which way the ball heads on launch (give or take 45 degrees). points at the paddle
var launch_direction := Vector2.DOWN

# where the level placed the ball, so we can put it back after a lost life
var _start_position: Vector2

## runs when ball enters the scene
func _ready() -> void:
	# apply speed upgrades once, when the level spawns the ball
	speed *= RunState.ball_speed_mult
	_start_position = global_position
	launch()

## for levels that place the ball after it has spawned: moves it, remembers the
## spot for respawns and relaunches it toward the paddle
func set_start(pos: Vector2, direction: Vector2) -> void:
	_start_position = pos
	global_position = pos
	launch_direction = direction
	launch()

## picks a random launch angle within 45 degrees of launch_direction & adds velocity
func launch() -> void:
	var angle := launch_direction.angle() + randf_range(-PI * 0.25, PI * 0.25)
	velocity = Vector2.RIGHT.rotated(angle) * speed

## puts the ball back at its start, holds it still for a moment, then relaunches
func respawn() -> void:
	global_position = _start_position
	velocity = Vector2.ZERO
	# short pause so the player can see where the ball is before it moves
	await get_tree().create_timer(0.6).timeout
	launch()

# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# try to move. if hit something, return collision info null if not. delta converts px per s to px this frame
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider is Player:
		velocity = _bounce_off_paddle(collider)
	else:
		# get_normal() is direction the suface faces. bounce() reflects our velocity off it
		velocity = velocity.bounce(collision.get_normal())

		# if it was something breakable, damage it
		if collider.has_method("take_damage"):
			collider.take_damage()

# Breakout-style aiming: where the ball lands on the paddle picks the angle it leaves at.
# Centre sends it straight up, the edges send it out at max_bounce_angle.
func _bounce_off_paddle(paddle: Player) -> Vector2:
	# the paddle can sit on any wall and bend round corners, so it works out
	# which way its face points where we hit it
	return paddle.bounce_direction(global_position, deg_to_rad(max_bounce_angle)) * speed
