class_name Player
extends CharacterBody2D

@export var speed := 200.0

## how wide the paddle starts out (1 = sprite size). Big Paddle upgrades stack on top
@export var base_width: float = 1.25

## degrees the ball gets tilted the way the paddle is moving when it's hit,
## on top of the angle it gets from where it landed. 0 turns it off
@export var move_nudge: float = 18.0

## the steepest the ball can leave the paddle, in degrees from straight out.
## stops the nudge sending it flat along the wall
@export var max_leave_angle: float = 78.0

## true while the ball is being aimed: the move keys steer the arrow instead,
## so the paddle holds still
var frozen := false

# which way the paddle moved this physics frame: 1 forward along its length
# (or its track), -1 back, 0 still
var _move_dir := 0.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

## half the paddle width, used by the ball to work out where along the paddle it hit
var half_width: float

# the line the paddle slides along, for levels that cut a hole for it. runs
# through the middle of the hole, one segment per wall the hole is in
var _track := PackedVector2Array()
# for each segment, the direction pointing out of the room
var _track_out: Array[Vector2] = []
# distance along the track to each point
var _track_dist: Array[float] = []
# how far along the track the paddle's centre is
var _track_pos: float

# on a track the paddle bends round corners like a snake: it's drawn as a
# line along the track, with one hitbox for the part on each wall
var _line: Line2D
var _pieces: Array[CollisionShape2D] = []
var _thickness: float


func _ready() -> void:
	# copy the shape first! the .tscn shares one shape resource, so editing it
	# directly would also change the paddle saved in the scene file
	collision.shape = collision.shape.duplicate()
	var width_mult := RunState.paddle_width_mult * base_width
	collision.shape.size.x *= width_mult
	sprite.scale.x = width_mult
	half_width = collision.shape.size.x / 2


## Puts the paddle on a track (see _track) in the middle of start_segment.
## Without one it just slides along its own length until a wall stops it.
func set_track(points: PackedVector2Array, outs: Array[Vector2], start_segment: int) -> void:
	_track = points
	_track_out = outs
	_track_dist = [0.0]
	for i in range(1, points.size()):
		_track_dist.append(_track_dist[i - 1] + points[i - 1].distance_to(points[i]))

	# swap the straight sprite for a line that can bend
	_line = Line2D.new()
	_line.texture = _paddle_texture()
	_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_line.joint_mode = Line2D.LINE_JOINT_SHARP
	_line.width = _line.texture.get_height()
	add_child(_line)
	sprite.hide()

	_thickness = collision.shape.size.y
	_pieces = [collision]
	for i in range(1, points.size() - 1):
		var piece := CollisionShape2D.new()
		add_child(piece)
		_pieces.append(piece)
	for piece in _pieces:
		piece.shape = RectangleShape2D.new()

	var middle := (_track_dist[start_segment] + _track_dist[start_segment + 1]) / 2
	_track_pos = clampf(middle, half_width, _track_dist[-1] - half_width)
	_lay_on_track()


## Which way the ball leaves after hitting the paddle at point: straight out
## from the face it hit in the middle, out at max_angle (radians) at the ends.
func bounce_direction(point: Vector2, max_angle: float) -> Vector2:
	var up := Vector2.UP.rotated(global_rotation)
	var along := global_transform.x.normalized()
	# -1 at one end of the paddle, 0 in the middle, +1 at the other end
	var offset := (point - global_position).dot(along) / half_width

	if not _track.is_empty():
		# the paddle may be bent, so find the bit of track nearest the hit
		# and measure along the track instead
		var local: Vector2 = get_parent().to_local(point)
		var nearest := INF
		for i in _track.size() - 1:
			var tangent := _tangent(i)
			var d := clampf((local - _track[i]).dot(tangent), 0.0, _track_dist[i + 1] - _track_dist[i])
			var gap := local.distance_to(_track[i] + tangent * d)
			if gap < nearest:
				nearest = gap
				up = -_track_out[i]
				along = tangent
				offset = (_track_dist[i] + d - _track_pos) / half_width

	# where it landed picks the angle, and a moving paddle pushes it a bit
	# further the way it's going
	var angle := max_angle * clampf(offset, -1.0, 1.0) + deg_to_rad(move_nudge) * _move_dir
	var steepest := maxf(max_angle, deg_to_rad(max_leave_angle))
	angle = clampf(angle, -steepest, steepest)
	return up * cos(angle) + along * sin(angle)


## Where the ball sits while it's being aimed: resting on the paddle's inside
## face, in the middle of it. Returns [spot, direction into the room], both in
## global space. ball_radius keeps the ball just clear of the paddle.
func hold_spot(ball_radius: float) -> Array:
	if _track.is_empty():
		var up := Vector2.UP.rotated(global_rotation)
		var gap: float = collision.shape.size.y / 2 + ball_radius + 1.0
		return [global_position + up * gap, up]

	# a bent paddle covers two walls, so use whichever holds more of it and
	# sit in the middle of that part (well away from the corner)
	var back_end := _track_pos - half_width
	var front_end := _track_pos + half_width
	var best := 0
	var best_length := -1.0
	var best_mid := _track_pos
	for i in _track.size() - 1:
		var start := maxf(back_end, _track_dist[i])
		var end := minf(front_end, _track_dist[i + 1])
		if end - start > best_length:
			best_length = end - start
			best = i
			best_mid = (start + end) / 2
	var into_room := -_track_out[best]
	var on_track := _track[best] + _tangent(best) * (best_mid - _track_dist[best])
	var spot := on_track + into_room * (_thickness / 2 + ball_radius + 1.0)
	var parent: Node2D = get_parent()
	return [parent.to_global(spot), into_room]


func _physics_process(delta: float) -> void:
	if frozen:
		_move_dir = 0.0
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))

	if _track.is_empty():
		# the paddle only slides along its own length. on a side wall it's
		# turned 90 degrees, so up/down moves it there instead of left/right
		var along := global_transform.x.abs().round()
		velocity = input * along * speed
		_move_dir = signf(velocity.dot(global_transform.x))
		# Walls are on physics layer 1 (our collision_mask), so move_and_slide stops us at them
		move_and_slide()
	else:
		_move_along_track(input, delta)


# Any key that points along any wall of the track moves the paddle that way
# along the whole track, corners included. So on a track that goes right then
# up, right and up both mean "forward" and left and down both mean "back":
# hold one key and the paddle snakes round the corner on its own, no need to
# switch keys at the bend. (the two walls of a corner are at right angles, so
# the four keys always split two forward, two back and never clash)
func _move_along_track(input: Vector2, delta: float) -> void:
	var forward := Vector2.ZERO
	for i in _track.size() - 1:
		forward += _tangent(i)
	var step := clampf(input.dot(forward), -1.0, 1.0)

	var move := step * speed * delta
	var before := _track_pos
	_track_pos = clampf(_track_pos + move, half_width, _track_dist[-1] - half_width)
	# only counts as moving if it really went somewhere, not pushing into the hole's end
	_move_dir = signf(_track_pos - before) if absf(_track_pos - before) > 0.01 else 0.0
	_lay_on_track()


# Bends the paddle along the track around its centre: the line it's drawn
# with follows the track, and each wall it covers gets a hitbox.
func _lay_on_track() -> void:
	var centre := _point_at(_track_pos)
	position = centre
	var back_end := _track_pos - half_width
	var front_end := _track_pos + half_width

	var line_points := PackedVector2Array([_point_at(back_end) - centre])
	for i in range(1, _track.size() - 1):
		if _track_dist[i] > back_end and _track_dist[i] < front_end:
			line_points.append(_track[i] - centre)
	line_points.append(_point_at(front_end) - centre)
	_line.points = line_points

	for i in _pieces.size():
		var piece := _pieces[i]
		var start := maxf(back_end, _track_dist[i])
		var end := minf(front_end, _track_dist[i + 1])
		piece.disabled = end <= start
		if piece.disabled:
			continue
		# reach half the thickness past a corner, so the two hitboxes meet
		# in a solid L with no notch at the outside of the bend
		if start > back_end:
			start -= _thickness / 2
		if end < front_end:
			end += _thickness / 2
		var tangent := _tangent(i)
		var a := _track[i] + tangent * (start - _track_dist[i])
		var b := _track[i] + tangent * (end - _track_dist[i])
		piece.position = (a + b) / 2 - centre
		piece.rotation = tangent.angle()
		piece.shape.size = Vector2(end - start, _thickness)


# the paddle's pixels cut out of the sprite sheet, for the line to stretch along the track
func _paddle_texture() -> Texture2D:
	var image := sprite.texture.get_image().get_region(Rect2i(sprite.region_rect.grow(1)))
	return ImageTexture.create_from_image(image.get_region(image.get_used_rect()))


func _tangent(segment: int) -> Vector2:
	return (_track[segment + 1] - _track[segment]).normalized()


func _segment_at(dist: float) -> int:
	for i in range(_track.size() - 2):
		if dist < _track_dist[i + 1]:
			return i
	return _track.size() - 2


func _point_at(dist: float) -> Vector2:
	var i := _segment_at(dist)
	return _track[i] + _tangent(i) * (dist - _track_dist[i])
