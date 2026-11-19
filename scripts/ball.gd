class_name Ball

extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## how much damage the ball deals to enemies
@export var damage: int = 1

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

## seconds the ball sits still with the arrow showing before it launches
@export var aim_time: float = 2.0

## how far in front of the ball's centre the arrow sits, in px
@export var arrow_distance: float = 11.0

## seconds the ball can spend stuck in a repeating bounce loop before it relaunches
@export var loop_timeout: float = 5.0

## aim assist: leaving the paddle, if an enemy or chest is within this many
## degrees of the ball's path, the ball heads straight for it instead
@export var aim_assist_angle: float = 10.0

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
# seconds between the beeps while the aim arrow is showing
const BEEP_INTERVAL := 0.5

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
	# lets the death zone tell whether this was the last ball in play
	add_to_group("balls")
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

## sends the ball off from pos straight away in a random direction, no aim
## arrow. for balls breaking out of a chest. respawns still go wherever
## set_start put them
func release(pos: Vector2) -> void:
	global_position = pos
	_aim_left = 0.0
	_arrow.hide()
	_reset_loop_check()
	velocity = Vector2.RIGHT.rotated(_random_angle()) * speed

# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# counting down on the physics clock means the pause menu freezes it too
	if _aim_left > 0.0:
		var before := _aim_left
		_aim_left -= delta
		if _aim_left <= 0.0:
			_arrow.hide()
			velocity = _launch_velocity
			# higher beep: go!
			Sfx.play(&"aim_beep", 1.6)
		else:
			# a beep as the arrow appears and every half second after
			if before >= aim_time or floori(before / BEEP_INTERVAL) > floori(_aim_left / BEEP_INTERVAL):
				Sfx.play(&"aim_beep")
			_update_arrow()
		return

	_move_time += delta
	if _is_stuck():
		_unstick()
		return

	# try to move. if hit something, return collision info null if not. delta converts px per s to px this frame
	var motion := velocity * delta
	# a few pierces a frame at most, so nothing odd can ever loop forever here
	for i in 4:
		var collision := move_and_collide(motion)
		if collision == null:
			return
		if not _hit(collision):
			return
		# smashed straight through it, so carry on with the rest of this frame's move
		motion = collision.get_remainder()

# Reacts to bumping into something. Returns true if the ball broke it and
# keeps going (pierce), false if it bounced.
func _hit(collision: KinematicCollision2D) -> bool:
	var collider := collision.get_collider()
	if collider is Player:
		velocity = _bounce_off_paddle(collider)
		# the player is steering it, so whatever it was doing isn't a loop
		_reset_loop_check()
		Sfx.play(&"ball_hit", 1.25, 0.03)
		return false

	# the boss's paddle aims its returns the same way ours does
	if collider.has_method("bounce_direction"):
		velocity = collider.bounce_direction(global_position, deg_to_rad(max_bounce_angle)) * speed
		Sfx.play(&"ball_hit", 0.8, 0.03)
		return false

	# take_damage returns true when that hit killed it (or broke a chest open).
	# then there's nothing left to bounce off, so fly on through
	if collider.has_method("take_damage") and collider.take_damage(damage):
		add_collision_exception_with(collider)
		return true

	# get_normal() is direction the suface faces. bounce() reflects our velocity off it
	velocity = velocity.bounce(collision.get_normal())
	_record_bounce()
	# enemies make their own hurt sound, so only blip for plain bounces
	if not collider.has_method("take_damage"):
		Sfx.play(&"ball_hit", 1.0, 0.05)
	return false

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
	_aim(_random_angle())

# any direction, but at least 10 degrees off horizontal and vertical:
# straight along an axis is the easiest way to end up in a loop
func _random_angle() -> float:
	var angle := randf() * TAU
	var off_axis := fposmod(angle, PI * 0.5)
	var margin := deg_to_rad(10.0)
	return angle + clampf(off_axis, margin, PI * 0.5 - margin) - off_axis

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
	var dir := paddle.bounce_direction(global_position, deg_to_rad(max_bounce_angle))
	return _assist_aim(dir) * speed

# Aim assist. Each pixel of paddle swings the shot about 3 degrees, finer than
# anyone can aim, so if a target is within aim_assist_angle of dir, head
# straight at the closest one (by angle) instead.
func _assist_aim(dir: Vector2) -> Vector2:
	var best := deg_to_rad(aim_assist_angle)
	var result := dir
	var targets := get_tree().get_nodes_in_group("enemies") \
		+ get_tree().get_nodes_in_group("upgrade_chests")
	for target: Node2D in targets:
		var to_target := target.global_position - global_position
		var off := absf(dir.angle_to(to_target))
		if off < best:
			best = off
			result = to_target.normalized()
	return result
