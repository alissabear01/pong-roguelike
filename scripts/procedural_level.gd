extends "res://scripts/level.gd"
## Builds a fresh room every time it loads: a wall border with one hole knocked
## out of it (sometimes wrapping round a corner), the paddle sitting in that
## hole, and enemies scattered inside. Once the room exists, level.gd counts
## the enemies like it would in a hand-made level.

const TILE_SIZE := 16
# the only tile in wall_tileset.tres that has collision
const WALL_SOURCE := 0
const WALL_ATLAS := Vector2i(0, 0)
# the sides the hole can go on, as the direction pointing out of the room
const SIDES: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]

## enemy scenes to spawn, one picked at random for each enemy
@export var enemy_scenes: Array[PackedScene] = []

## room interior size in tiles, rolled between these (inclusive).
## the screen fits 30x16 tiles, walls included, so stay under 28x14
@export var min_room_size := Vector2i(16, 9)
@export var max_room_size := Vector2i(24, 12)

## hole length in tiles, rolled between these (inclusive). the paddle slides
## inside the hole and the wall on either end stops it
@export var hole_size := Vector2i(5, 10)

## tiles of slack the hole always has beyond the paddle's length, so a
## big paddle upgrade can't leave it with nowhere to move
@export var min_paddle_room: int = 2

## chance the hole wraps round a corner, so the paddle can slide from one
## wall onto the next
@export_range(0.0, 1.0) var corner_hole_chance: float = 0.4

## for a corner hole, tiles the hole runs along each wall past the corner
## tile, rolled between these (inclusive). always enough for the whole paddle
@export var corner_arm_size := Vector2i(4, 7)

## enemies on level 1, and how many more each level after that
@export var base_enemy_count: int = 2
@export var enemies_per_level: int = 1

## distance between the spots enemies can spawn on, in px.
## big enough that a skeleton never overlaps its neighbour
@export var enemy_spacing := Vector2(32, 32)

## px of open floor kept clear on the hole's sides for the paddle and ball.
## enemies spawn and move only outside it
@export var paddle_clearance: float = 72.0

## 0 rolls a new room every time, anything else always builds the same room
@export var room_seed: int = 0

@onready var walls: TileMapLayer = $Walls
@onready var enemies: Node2D = $Enemies
@onready var ball: Ball = $Ball
@onready var player: Player = $Player
@onready var death_zone: Area2D = $DeathZone
@onready var camera: Camera2D = $Camera2D

var _rng := RandomNumberGenerator.new()

# the sides the hole is cut into, pointing out of the room. two when it wraps a corner
var _hole_sides: Array[Vector2i] = []
# the line the paddle slides along, through the middle of the hole. one
# segment per side in _hole_sides, in the same order
var _track := PackedVector2Array()
# which segment of the track the paddle starts on
var _start_segment := 0


func _ready() -> void:
	if room_seed != 0:
		_rng.seed = room_seed
	# printed so a weird room can be rebuilt by pasting this into room_seed
	print("level %d, room seed %d" % [LevelManager.level_number, _rng.seed])

	var room := _build_walls()
	_cut_hole(room)
	_place_paddle_and_ball()
	_place_death_zone()
	_spawn_enemies(room)

	# enemies are in the tree now, so the base level can count them
	super._ready()


## Rolls a room size, puts a wall on every side of it and returns the open
## interior in pixels.
func _build_walls() -> Rect2:
	var size := Vector2i(
		_rng.randi_range(min_room_size.x, max_room_size.x),
		_rng.randi_range(min_room_size.y, max_room_size.y))
	# top-left interior cell, picked so the room sits around the origin
	var origin := -size / 2

	# walls sit one cell outside the interior on every side
	for x in range(origin.x - 1, origin.x + size.x + 1):
		walls.set_cell(Vector2i(x, origin.y - 1), WALL_SOURCE, WALL_ATLAS)
		walls.set_cell(Vector2i(x, origin.y + size.y), WALL_SOURCE, WALL_ATLAS)
	for y in range(origin.y, origin.y + size.y):
		walls.set_cell(Vector2i(origin.x - 1, y), WALL_SOURCE, WALL_ATLAS)
		walls.set_cell(Vector2i(origin.x + size.x, y), WALL_SOURCE, WALL_ATLAS)

	var room := Rect2(Vector2(origin * TILE_SIZE), Vector2(size * TILE_SIZE))
	camera.position = room.get_center()
	return room


## Erases one run of wall cells, either along a single side or round a corner.
## Fills in _hole_sides, _track and _start_segment.
func _cut_hole(room: Rect2) -> void:
	var interior := Rect2i(Vector2i(room.position) / TILE_SIZE, Vector2i(room.size) / TILE_SIZE)
	var paddle_tiles := ceili(player.half_width * 2 / TILE_SIZE)
	if _rng.randf() < corner_hole_chance and _cut_corner_hole(interior, paddle_tiles):
		return
	_cut_straight_hole(interior, paddle_tiles)


## Picks a side and erases a run of its wall cells. Always leaves at least one
## wall cell at each end so the paddle has something to stop against.
func _cut_straight_hole(interior: Rect2i, paddle_tiles: int) -> void:
	var shortest_hole := maxi(hole_size.x, paddle_tiles + min_paddle_room)

	# only sides long enough for the paddle. the top and bottom are always the
	# longest, so they're the fallback if the paddle has grown huge
	var sides: Array[Vector2i] = []
	for side in SIDES:
		if _side_length(interior, side) - 2 >= shortest_hole:
			sides.append(side)
	if sides.is_empty():
		sides = [Vector2i.DOWN, Vector2i.UP]
	var hole_side := sides[_rng.randi_range(0, sides.size() - 1)]

	var side_length := _side_length(interior, hole_side)
	var longest_hole := mini(hole_size.y, side_length - 2)
	var length := _rng.randi_range(mini(shortest_hole, longest_hole), longest_hole)
	var start := _rng.randi_range(1, side_length - length - 1)

	# first wall cell of the side, and which way the side runs
	var first: Vector2i
	var along: Vector2i
	match hole_side:
		Vector2i.DOWN:
			first = Vector2i(interior.position.x, interior.end.y)
			along = Vector2i.RIGHT
		Vector2i.UP:
			first = Vector2i(interior.position.x, interior.position.y - 1)
			along = Vector2i.RIGHT
		Vector2i.LEFT:
			first = Vector2i(interior.position.x - 1, interior.position.y)
			along = Vector2i.DOWN
		Vector2i.RIGHT:
			first = Vector2i(interior.end.x, interior.position.y)
			along = Vector2i.DOWN

	var hole_start := first + along * start
	for i in length:
		walls.erase_cell(hole_start + along * i)

	# from the hole's near edge to its far edge, through the middle of the wall
	var first_centre := (Vector2(hole_start) + Vector2(0.5, 0.5)) * TILE_SIZE
	_track = [
		first_centre - Vector2(along) * TILE_SIZE / 2,
		first_centre + Vector2(along) * (length - 0.5) * TILE_SIZE]
	_hole_sides = [hole_side]
	_start_segment = 0


## Erases a corner wall cell and a run of cells along both walls that meet
## there, so the paddle can slide round from one onto the other. Returns false
## (and cuts nothing) if the room is too small for the paddle to fit on both.
func _cut_corner_hole(interior: Rect2i, paddle_tiles: int) -> bool:
	# each arm fits the whole paddle past the corner tile and leaves a wall
	# cell at its far end
	var shortest_arm := maxi(corner_arm_size.x, paddle_tiles + 1)
	if interior.size.x - 1 < shortest_arm or interior.size.y - 1 < shortest_arm:
		return false

	# -1/1 on each axis: left/right, top/bottom
	var corner := Vector2i(_rng.randi_range(0, 1) * 2 - 1, _rng.randi_range(0, 1) * 2 - 1)
	var corner_cell := Vector2i(
		interior.position.x - 1 if corner.x < 0 else interior.end.x,
		interior.position.y - 1 if corner.y < 0 else interior.end.y)
	var flat_arm := _rng.randi_range(shortest_arm, maxi(shortest_arm, mini(corner_arm_size.y, interior.size.x - 1)))
	var tall_arm := _rng.randi_range(shortest_arm, maxi(shortest_arm, mini(corner_arm_size.y, interior.size.y - 1)))

	walls.erase_cell(corner_cell)
	for i in range(1, flat_arm + 1):
		walls.erase_cell(corner_cell + Vector2i(-corner.x * i, 0))
	for i in range(1, tall_arm + 1):
		walls.erase_cell(corner_cell + Vector2i(0, -corner.y * i))

	# along the top or bottom wall into the corner, then along the side wall
	var centre := (Vector2(corner_cell) + Vector2(0.5, 0.5)) * TILE_SIZE
	_track = [
		centre + Vector2(-corner.x, 0) * (flat_arm + 0.5) * TILE_SIZE,
		centre,
		centre + Vector2(0, -corner.y) * (tall_arm + 0.5) * TILE_SIZE]
	_hole_sides = [Vector2i(0, corner.y), Vector2i(corner.x, 0)]
	_start_segment = _rng.randi_range(0, 1)
	return true


# how many cells a side of the interior has
func _side_length(interior: Rect2i, side: Vector2i) -> int:
	return interior.size.x if side.y != 0 else interior.size.y


## Lays the paddle on the hole's track and puts the ball a little way in
## front of where it starts.
func _place_paddle_and_ball() -> void:
	var outs: Array[Vector2] = []
	for side in _hole_sides:
		outs.append(Vector2(side))
	player.set_track(_track, outs, _start_segment)

	# somewhere over the middle half of the paddle's starting wall, so the
	# first launch is always catchable
	var out := outs[_start_segment]
	var segment := _track[_start_segment + 1] - _track[_start_segment]
	var ball_pos := player.position - out * (TILE_SIZE / 2.0 + 56) \
		+ segment * _rng.randf_range(-0.25, 0.25)
	ball.set_start(ball_pos, out)


## Lays a long strip just outside each wall the hole is in, so a ball that
## gets past the paddle costs a life. Only the hole leads out there, so the
## strips can be wide.
func _place_death_zone() -> void:
	for i in _hole_sides.size():
		var collision: CollisionShape2D
		if i == 0:
			collision = death_zone.get_node("CollisionShape2D")
		else:
			collision = CollisionShape2D.new()
			death_zone.add_child(collision)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(4000, 200)
		collision.shape = shape

		var out := Vector2(_hole_sides[i])
		collision.rotation = out.angle() - PI / 2
		# its inner edge lines up with the outer face of the wall
		var wall_middle := (_track[i] + _track[i + 1]) / 2
		collision.position = wall_middle + out * (TILE_SIZE / 2.0 + shape.size.y / 2)


## Splits the room (minus the strip in front of the paddle) into a grid of
## spawn spots and fills a random handful of them. Enemies move about a tile,
## so the spots beside a filled one are left empty and neighbours can't walk
## into each other.
func _spawn_enemies(room: Rect2) -> void:
	if enemy_scenes.is_empty():
		push_warning("no enemy_scenes set on %s" % name)
		return

	# shave the clearance off whichever sides the hole is on
	var zone := room.grow_individual(
		-paddle_clearance if Vector2i.LEFT in _hole_sides else 0.0,
		-paddle_clearance if Vector2i.UP in _hole_sides else 0.0,
		-paddle_clearance if Vector2i.RIGHT in _hole_sides else 0.0,
		-paddle_clearance if Vector2i.DOWN in _hole_sides else 0.0)
	var cols := floori(zone.size.x / enemy_spacing.x)
	var rows := floori(zone.size.y / enemy_spacing.y)
	# leftover space gets split evenly on both sides so the grid is centred
	var margin := (zone.size - Vector2(cols, rows) * enemy_spacing) / 2

	var cells: Array[Vector2i] = []
	for row in rows:
		for col in cols:
			cells.append(Vector2i(col, row))
	_shuffle(cells)

	var count := base_enemy_count + enemies_per_level * (LevelManager.level_number - 1)
	# grid cells that are filled, or right beside a filled one
	var blocked := {}

	for cell in cells:
		if count == 0:
			break
		if blocked.has(cell):
			continue
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			blocked[cell + offset] = true

		var scene: PackedScene = enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
		var enemy := scene.instantiate()
		enemy.position = zone.position + margin + (Vector2(cell) + Vector2(0.5, 0.5)) * enemy_spacing
		# keeps it inside the room and out of the paddle's clearance
		enemy.move_bounds = zone
		enemies.add_child(enemy)
		count -= 1


# Array.shuffle() uses the global RNG, so do it by hand to keep room_seed repeatable
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
