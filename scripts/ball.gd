class_name Ball

extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

# where the level placed the ball, so we can put it back after a lost life
var _start_position: Vector2

## runs when ball enters the scene
func _ready() -> void:
	# apply speed upgrades once, when the level spawns the ball
	speed *= RunState.ball_speed_mult
	_start_position = global_position
	launch()

## picks random launch angle between 45 & 135 degrees so ball goes downwardish & adds velocity -- can change later
func launch() -> void:
	var angle := randf_range(PI * 0.25, PI * 0.75)
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
	# -1 at the paddle's left edge, 0 in the middle, +1 at the right edge
	var hit_offset := (global_position.x - paddle.global_position.x) / paddle.half_width
	hit_offset = clampf(hit_offset, -1.0, 1.0)

	var angle := deg_to_rad(max_bounce_angle) * hit_offset
	return Vector2.UP.rotated(angle) * speed
