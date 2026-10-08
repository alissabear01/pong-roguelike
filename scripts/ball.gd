extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## physics layer 1 holds the walls (and the bricks), used when we check what's boxing us in
const WALL_LAYER := 1

## how deep we have to be inside the paddle before we treat it as a squash. a clean bounce leaves
## us resting right up against it, and that shouldn't count
const PINCH_DEPTH := 0.5

## a sliver of clearance so we never come to rest exactly on a surface
const EDGE_GAP := 1.0

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

## ceiling on the extra speed a swinging paddle can put into the ball
@export var max_speed: float = 500.0

## how far from straight-up (in degrees) the ball is sent when it hits the very edge of the paddle
@export var max_bounce_angle: float = 60.0

## how far above horizontal (in degrees) the ball is sent when it's hit by one of the paddle's ends
@export var side_hit_angle: float = 30.0

@onready var _radius: float = $CollisionShape2D.shape.radius

## the paddle, so we can tell when it has driven into us. looked up lazily because the ball sits
## above the player in the level, so its _ready() runs first
var _paddle: Player


# runs when ball enters the scene
func _ready() -> void:
	# picks random launch angle between 45 & 135 degrees so ball goes downwardish & adds velocity -- can change later
	var angle := randf_range(PI * 0.25, PI * 0.75)
	velocity = Vector2.RIGHT.rotated(angle) * speed


# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# try to move. if hit something, return collision info null if not. delta converts px per s to px this frame
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		if collider is Player:
			velocity = _bounce_off_paddle(collider, collision.get_normal())
		else:
			# get_normal() is direction the suface faces. bounce() reflects our velocity off it
			velocity = velocity.bounce(collision.get_normal())

			# if it was something breakable, damage it
			if collider.has_method("take_damage"):
				collider.take_damage()

	# the paddle only collides with walls, so it slides clean through the ball. move_and_collide
	# never sees that, because the paddle came to us rather than us to it
	_settle_against_paddle()


# Where the ball meets the paddle picks the angle it leaves at: Breakout-style aiming on the long
# faces, a sideways smack on the short ends.
func _bounce_off_paddle(paddle: Player, normal: Vector2) -> Vector2:
	# a mostly sideways normal means we caught one of the paddle's ends rather than its face
	if absf(normal.x) > absf(normal.y):
		return _bounce_off_paddle_end(paddle, normal)

	# -1 at the paddle's left edge, 0 in the middle, +1 at the right edge
	var hit_offset := (global_position.x - paddle.global_position.x) / paddle.half_width
	hit_offset = clampf(hit_offset, -1.0, 1.0)

	var angle := deg_to_rad(max_bounce_angle) * hit_offset
	# leave along the face we actually touched, so clipping the underside sends us down rather than
	# straight back up through the paddle
	return Vector2(sin(angle), signf(normal.y) * cos(angle)) * speed


# The paddle's short ends: knock the ball back out sideways, tilted off the paddle's midline so it
# has a way out of the gap rather than sitting in it.
func _bounce_off_paddle_end(paddle: Player, normal: Vector2) -> Vector2:
	var horizontal := signf(normal.x)
	# up if we caught the end above the paddle's middle, down if below
	var vertical := signf(global_position.y - paddle.global_position.y)
	if is_zero_approx(vertical):
		vertical = -1.0

	var angle := deg_to_rad(side_hit_angle)
	var out := Vector2(horizontal * cos(angle), vertical * sin(angle)) * speed

	# the paddle moves at 2/3 our speed, so a flat constant-speed bounce off an end barely beats a
	# paddle that's still coming at us -- it just dribbles the ball along in front of itself. put
	# the paddle's own swing into the ball so a side hit actually sends it away
	if signf(paddle.velocity.x) == horizontal:
		out.x += paddle.velocity.x

	# and the paddle moves after we do, so leaving the ball flush against the end gets it buried
	# again on this same frame. put a whole paddle step between us first, unless there's a wall
	# there -- then _settle_against_paddle() takes us out over the top instead
	var clearance := paddle.half_width + _radius + _paddle_step(paddle)
	var short_by := clearance - (global_position.x - paddle.global_position.x) * horizontal
	if short_by > 0.0 and not _blocked_sideways(horizontal, short_by):
		global_position.x += horizontal * short_by

	return out.limit_length(max_speed)


# Undo any overlap the paddle made by driving into us, and bounce as if we'd hit it ourselves.
func _settle_against_paddle() -> void:
	if _paddle == null:
		_paddle = get_tree().get_first_node_in_group("player") as Player
		if _paddle == null:
			return

	# how far inside the paddle's box (grown by our radius) our centre sits, on each axis
	var to_ball := global_position - _paddle.global_position
	var overlap_x := _paddle.half_width + _radius - absf(to_ball.x)
	var overlap_y := _paddle.half_height + _radius - absf(to_ball.y)
	if overlap_x <= PINCH_DEPTH or overlap_y <= PINCH_DEPTH:
		return

	var horizontal := signf(to_ball.x)
	if is_zero_approx(horizontal):
		horizontal = -1.0
	var vertical := signf(to_ball.y)
	if is_zero_approx(vertical):
		vertical = -1.0

	# out sideways by default, but sideways is exactly how we get squashed into a wall, so go over
	# the top (or under) whenever there's something solid in the gap
	var step := _paddle_step(_paddle)
	if overlap_y < overlap_x or _blocked_sideways(horizontal, overlap_x + step):
		global_position.y += vertical * (overlap_y + EDGE_GAP)
		velocity = _bounce_off_paddle(_paddle, Vector2(0.0, vertical))
	else:
		global_position.x += horizontal * (overlap_x + step + EDGE_GAP)
		velocity = _bounce_off_paddle(_paddle, Vector2(horizontal, 0.0))


# how far the paddle travels in one physics tick
func _paddle_step(paddle: Player) -> float:
	return paddle.speed * get_physics_process_delta_time()


# true if popping out sideways would only shove us into a wall
func _blocked_sideways(direction: float, distance: float) -> bool:
	# ignore the paddle for this check, we're standing inside it
	var mask := collision_mask
	collision_mask = WALL_LAYER
	var blocked := test_move(global_transform, Vector2(direction * (distance + _radius), 0.0))
	collision_mask = mask
	return blocked
