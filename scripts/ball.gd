class_name Ball

extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## how big the ball starts out (1 = sprite size). chest Big ball upgrades stack on top
@export var base_size: float = 1.0

## how much damage the ball deals to enemies
@export var damage: int = 1

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

## seconds you get to aim the arrow before the ball fires on its own
@export var aim_time: float = 4.0

## how far either side of straight ahead the arrow can swing, in degrees
@export var max_aim_angle: float = 60.0

## how fast the arrow swings while a direction is held, in degrees per s
@export var aim_turn_speed: float = 120.0

## how far in front of the ball's centre the arrow sits, in px
@export var arrow_distance: float = 11.0

## how much bigger the ball's sprite swells when it gets a chest upgrade, and
## how long it takes to settle back (s)
@export var upgrade_pulse_size: float = 1.8
@export var upgrade_pulse_time: float = 0.45

## seconds the ball can spend stuck in a repeating bounce loop before it relaunches
@export var loop_timeout: float = 5.0

## straight ahead for the arrow: into the room, away from the paddle
var launch_direction := Vector2.UP

## the paddle, so it can hold still while you aim. the level sets it
var paddle: Player

# how far the arrow is swung away from launch_direction, in radians
var _aim_offset: float = 0.0

# where the level placed the ball, so we can put it back after a lost life
var _start_position: Vector2

# the velocity we'll take once the aim countdown runs out
var _launch_velocity := Vector2.ZERO

# seconds left before launch. 0 = already moving
var _aim_left: float = 0.0

# two bounces this close together (px) and this close in direction (dot) count as the same bounce
const LOOP_POS_TOLERANCE := 4.0
const LOOP_DIR_TOLERANCE := 0.995
# how many recent bounces we remember when looking for a repeat
const LOOP_HISTORY_SIZE := 32
# if everywhere the ball has been for loop_timeout fits in a strip this thin (px),
# it's ping-ponging between two walls or rattling in a corner
const LOOP_STRIP_WIDTH := 64.0
# how often (s) we sample the ball's position for the strip check
const TRACK_INTERVAL := 0.1

# seconds the ball has been moving since its last launch, used to timestamp bounces
var _move_time: float = 0.0
# recent non-paddle bounces as {pos, dir, time}. cleared whenever the paddle hits it
var _bounces: Array[Dictionary] = []
# when the current loop started (time of the first bounce it repeats), -1 = not looping
var _loop_start: float = -1.0
# where the ball was every TRACK_INTERVAL s, newest last, loop_timeout s worth
var _track := PackedVector2Array()
var _next_track_time: float = 0.0

@onready var _arrow: Sprite2D = $LaunchArrow

## runs when ball enters the scene
func _ready() -> void:
	# apply speed upgrades once, when the level spawns the ball
	speed *= RunState.ball_speed_mult
	scale *= RunState.ball_size_mult * base_size
	damage += RunState.ball_damage_bonus
	_start_position = global_position
	launch()

## for levels that place the ball after it has spawned: moves it, remembers the
## spot for respawns and relaunches it toward the paddle
func set_start(pos: Vector2, direction: Vector2) -> void:
	_start_position = pos
	global_position = pos
	launch_direction = direction
	launch()

## holds the ball still with the arrow showing so the player can aim it:
## the move keys swing the arrow and ui_accept (Space / Enter) fires. if
## nobody fires within aim_time it goes off on its own
func launch() -> void:
	# starts a little off straight ahead, so a shot nobody steers doesn't
	# just go straight out and straight back
	var side := 1.0 if randf() < 0.5 else -1.0
	_aim(deg_to_rad(randf_range(10.0, 30.0)) * side)

# stops the ball where it is and shows the arrow, swung offset radians away
# from launch_direction
func _aim(offset: float) -> void:
	_aim_offset = offset
	velocity = Vector2.ZERO
	_aim_left = aim_time
	_reset_loop_check()
	if paddle:
		# the move keys aim the arrow for now, so the paddle waits
		paddle.frozen = true
		# the ball sits on the paddle like an orb it's holding, wherever the
		# paddle is, and shoots straight out from it into the room
		var radius: float = $CollisionShape2D.shape.radius * scale.x
		var spot := paddle.hold_spot(radius)
		global_position = spot[0]
		launch_direction = spot[1]
	_arrow.show()
	_point_arrow()

# swings the arrow toward whichever move key is held
func _steer_arrow(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	# how much the keys push to the arrow's right. works whichever wall the
	# paddle is on: left/right aims on the top and bottom, up/down on the sides
	var turn := input.dot(launch_direction.rotated(PI / 2))
	var limit := deg_to_rad(max_aim_angle)
	_aim_offset = clampf(_aim_offset + turn * deg_to_rad(aim_turn_speed) * delta, -limit, limit)
	_point_arrow()

# lines the arrow (and the shot it shows) up with _aim_offset
func _point_arrow() -> void:
	var angle := launch_direction.angle() + _aim_offset
	_launch_velocity = Vector2.RIGHT.rotated(angle) * speed
	# the arrow art points right, so rotating it by the angle aims it
	_arrow.rotation = angle
	_update_arrow()

# sends the ball off the way the arrow points and lets the paddle move again
func _fire() -> void:
	_aim_left = 0.0
	_arrow.hide()
	velocity = _launch_velocity
	if paddle:
		paddle.frozen = false

## puts the ball back at its start and relaunches it (with the aim arrow first)
func respawn() -> void:
	global_position = _start_position
	launch()

# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# counting down on the physics clock means the pause menu freezes it too
	if _aim_left > 0.0:
		_aim_left -= delta
		_steer_arrow(delta)
		# the first moment is skipped so the Enter that picked an upgrade or
		# pressed Play can't also fire the ball
		var fired := Input.is_action_just_pressed("ui_accept") and aim_time - _aim_left > 0.2
		if fired or _aim_left <= 0.0:
			_fire()
		return

	_move_time += delta
	if _is_stuck():
		_unstick()
		return

	# try to move. if hit something, return collision info null if not. delta converts px per s to px this frame
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider is Player:
		velocity = _bounce_off_paddle(collider)
		# the player is steering it, so whatever it was doing isn't a loop
		_reset_loop_check()
	else:
		# get_normal() is direction the suface faces. bounce() reflects our velocity off it
		velocity = velocity.bounce(collision.get_normal())
		_record_bounce()

		# if it was something breakable, damage it
		if collider.has_method("take_damage"):
			collider.take_damage(damage)

# The ball moves at a constant speed and reflects perfectly, so if it bounces
# off the same spot heading the same way as before, it's going to repeat that
# path forever. Also catches it rattling in a corner, where every bounce is in
# the same couple of spots.
func _record_bounce() -> void:
	var dir := velocity.normalized()
	var repeat_of := -1.0
	for b in _bounces:
		if b.pos.distance_to(global_position) <= LOOP_POS_TOLERANCE \
				and b.dir.dot(dir) >= LOOP_DIR_TOLERANCE:
			repeat_of = b.time
			break

	if repeat_of < 0.0:
		# a bounce we haven't seen before, so whatever loop we were in is broken
		_loop_start = -1.0
	elif _loop_start < 0.0:
		# the loop began back when the ball first made this bounce
		_loop_start = repeat_of

	_bounces.append({"pos": global_position, "dir": dir, "time": _move_time})
	if _bounces.size() > LOOP_HISTORY_SIZE:
		_bounces.pop_front()

# true once the ball has been looping, or going nowhere, for loop_timeout s
func _is_stuck() -> bool:
	if _loop_start >= 0.0 and _move_time - _loop_start >= loop_timeout:
		return true

	if _move_time < _next_track_time:
		return false
	_next_track_time += TRACK_INTERVAL
	_track.append(global_position)
	var samples := int(loop_timeout / TRACK_INTERVAL) + 1
	if _track.size() > samples:
		_track.remove_at(0)
	if _track.size() < samples:
		return false

	var area := Rect2(_track[0], Vector2.ZERO)
	for p in _track:
		area = area.expand(p)
	return minf(area.size.x, area.size.y) <= LOOP_STRIP_WIDTH

func _reset_loop_check() -> void:
	_bounces.clear()
	_loop_start = -1.0
	_move_time = 0.0
	_track.clear()
	_next_track_time = 0.0

# stuck in a loop too long: the ball comes back to its start for a fresh
# aimed shot. no life lost
func _unstick() -> void:
	respawn()

# nudges the arrow back and forth in whole pixels and blinks it just before launch
func _update_arrow() -> void:
	var dir := _launch_velocity.normalized()
	var bob := roundf(sin(_aim_left * TAU * 2.0))
	_arrow.position = (dir * (arrow_distance + bob)).round()
	# last half second: blink so the player knows it's about to go
	_arrow.visible = _aim_left > 0.5 or fmod(_aim_left, 0.16) > 0.08

# Breakout-style aiming: where the ball lands on the paddle picks the angle it leaves at.
# Centre sends it straight up, the edges send it out at max_bounce_angle.
func _bounce_off_paddle(hit_paddle: Player) -> Vector2:
	# the paddle can sit on any wall and bend round corners, so it works out
	# which way its face points where we hit it. it also adds a nudge the way
	# it's moving
	return hit_paddle.bounce_direction(global_position, deg_to_rad(max_bounce_angle)) * speed


func apply_upgrade(upgrade: StringName) -> String:
	match upgrade:
		&"speed":
			RunState.ball_speed_mult *= 1.25
			speed *= 1.25
			velocity = velocity.normalized() * speed
			return "Fast ball  25% faster"
		&"size":
			RunState.ball_size_mult *= 1.25
			_scale_ball(1.25)
			return "Big ball  25% bigger"
		&"power":
			RunState.ball_damage_bonus += 1
			damage += 1
			return "Power ball  1 more damage"
	return ""


## quick white flash and swell on the sprite, so it's clear the ball just
## got an upgrade. only the sprite pulses, the hitbox stays put
func flash_upgrade() -> void:
	var sprite: Sprite2D = $Sprite2D
	sprite.scale = Vector2.ONE * upgrade_pulse_size
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2.ONE, upgrade_pulse_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color.WHITE, upgrade_pulse_time)


func _scale_ball(multiplier: float) -> void:
	scale *= multiplier
