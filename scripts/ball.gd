class_name Ball

extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

## seconds the ball sits still with the arrow showing before it launches
@export var aim_time: float = 2.0

## how far in front of the ball's centre the arrow sits, in px
@export var arrow_distance: float = 11.0

## seconds the ball can spend stuck in a repeating bounce loop before it relaunches
@export var loop_timeout: float = 5.0

## which way the ball heads on launch (give or take 45 degrees). points at the paddle
var launch_direction := Vector2.DOWN

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
	_start_position = global_position
	launch()

## for levels that place the ball after it has spawned: moves it, remembers the
## spot for respawns and relaunches it toward the paddle
func set_start(pos: Vector2, direction: Vector2) -> void:
	_start_position = pos
	global_position = pos
	launch_direction = direction
	launch()

## picks a random launch angle within 45 degrees of launch_direction, holds the
## ball still for aim_time with an arrow showing that way, then sends it off
func launch() -> void:
	_aim(launch_direction.angle() + randf_range(-PI * 0.25, PI * 0.25))

# stops the ball where it is and shows the arrow at angle for aim_time, then launches
func _aim(angle: float) -> void:
	_launch_velocity = Vector2.RIGHT.rotated(angle) * speed
	velocity = Vector2.ZERO
	_aim_left = aim_time
	_reset_loop_check()
	# the arrow art points right, so rotating it by the angle aims it
	_arrow.rotation = angle
	_arrow.show()
	_update_arrow()

## puts the ball back at its start and relaunches it (with the aim arrow first)
func respawn() -> void:
	global_position = _start_position
	launch()

# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# counting down on the physics clock means the pause menu freezes it too
	if _aim_left > 0.0:
		_aim_left -= delta
		if _aim_left <= 0.0:
			_arrow.hide()
			velocity = _launch_velocity
		else:
			_update_arrow()
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
			collider.take_damage()

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

# stuck in a loop too long: freeze, show the arrow, and fire off somewhere random
func _unstick() -> void:
	var angle := randf() * TAU
	# straight along an axis is the easiest way to end up in another loop, so
	# keep it at least 10 degrees off horizontal and vertical
	var off_axis := fposmod(angle, PI * 0.5)
	var margin := deg_to_rad(10.0)
	angle += clampf(off_axis, margin, PI * 0.5 - margin) - off_axis
	_aim(angle)

# nudges the arrow back and forth in whole pixels and blinks it just before launch
func _update_arrow() -> void:
	var dir := _launch_velocity.normalized()
	var bob := roundf(sin(_aim_left * TAU * 2.0))
	_arrow.position = (dir * (arrow_distance + bob)).round()
	# last half second: blink so the player knows it's about to go
	_arrow.visible = _aim_left > 0.5 or fmod(_aim_left, 0.16) > 0.08

# Breakout-style aiming: where the ball lands on the paddle picks the angle it leaves at.
# Centre sends it straight up, the edges send it out at max_bounce_angle.
func _bounce_off_paddle(paddle: Player) -> Vector2:
	# the paddle can sit on any wall and bend round corners, so it works out
	# which way its face points where we hit it
	return paddle.bounce_direction(global_position, deg_to_rad(max_bounce_angle)) * speed
