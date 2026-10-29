class_name Player
extends CharacterBody2D

@export var speed := 200.0

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
	collision.shape.size.x *= RunState.paddle_width_mult
	sprite.scale.x = RunState.paddle_width_mult
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

	var angle := max_angle * clampf(offset, -1.0, 1.0)
	return up * cos(angle) + along * sin(angle)


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))

	if _track.is_empty():
		# the paddle only slides along its own length. on a side wall it's
		# turned 90 degrees, so up/down moves it there instead of left/right
		var along := global_transform.x.abs().round()
		velocity = input * along * speed
		# Walls are on physics layer 1 (our collision_mask), so move_and_slide stops us at them
		move_and_slide()
	else:
		_move_along_track(input, delta)


# The leading end of the paddle steers: to move toward an end, push along the
# wall that end is on (left/right on the top and bottom, up/down on the
# sides). An end stops when it reaches a corner, and only goes round once you
# push along the next wall, then the rest of the paddle snakes after it.
func _move_along_track(input: Vector2, delta: float) -> void:
	var front := _track_pos + half_width
	var back := _track_pos - half_width
	# the wall each end would move along. an end sitting on a corner is
	# about to go round it, so it counts as on the next wall
	var front_segment := _segment_ahead(front, true)
	var back_segment := _segment_ahead(back, false)

	var step := 0.0
	var forward := input.dot(_tangent(front_segment))
	var backward := input.dot(_tangent(back_segment))
	if forward > 0:
		step = forward
	elif backward < 0:
		step = backward

	# the leading end goes no further than the end of its wall: the next
	# corner, or the hole's edge
	var move := step * speed * delta
	if move > 0:
		move = minf(move, _track_dist[front_segment + 1] - front)
	elif move < 0:
		move = maxf(move, _track_dist[back_segment] - back)
	_track_pos = clampf(_track_pos + move, half_width, _track_dist[-1] - half_width)
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


# the segment an end of the paddle at dist moves along going forward (or back).
# on a corner that's the segment past it, the way it's heading
func _segment_ahead(dist: float, forward: bool) -> int:
	for i in range(_track.size() - 2):
		var corner := _track_dist[i + 1]
		if (forward and dist < corner - 0.001) or (not forward and dist <= corner + 0.001):
			return i
	return _track.size() - 2


func _point_at(dist: float) -> Vector2:
	var i := _segment_at(dist)
	return _track[i] + _tangent(i) * (dist - _track_dist[i])
