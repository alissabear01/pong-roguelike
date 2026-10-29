extends "res://scripts/level.gd"
## Builds a fresh room every time it loads: a wall border on every side and
## enemies scattered inside. Once the room exists, level.gd counts the enemies
## like it would in a hand-made level.

const TILE_SIZE := 16
# the only tile in wall_tileset.tres that has collision
const WALL_SOURCE := 0
const WALL_ATLAS := Vector2i(0, 0)

## enemy scenes to spawn, one picked at random for each enemy
@export var enemy_scenes: Array[PackedScene] = []

## room interior size in tiles, rolled between these (inclusive).
## the screen fits 30x16 tiles, walls included, so stay under 28x14
@export var min_room_size := Vector2i(16, 9)
@export var max_room_size := Vector2i(24, 12)

## enemies on level 1, and how many more each level after that
@export var base_enemy_count: int = 2
@export var enemies_per_level: int = 1

## distance between the spots enemies can spawn on, in px.
## big enough that a skeleton never overlaps its neighbour
@export var enemy_spacing := Vector2(32, 32)

## px of open floor kept above the bottom wall for the paddle and ball
@export var bottom_clearance: float = 72.0

## 0 rolls a new room every time, anything else always builds the same room
@export var room_seed: int = 0

@onready var walls: TileMapLayer = $Walls
@onready var enemies: Node2D = $Enemies
@onready var ball: Node2D = $Ball
@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera2D

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if room_seed != 0:
		_rng.seed = room_seed
	# printed so a weird room can be rebuilt by pasting this into room_seed
	print("level %d, room seed %d" % [LevelManager.level_number, _rng.seed])

	var room := _build_walls()
	_place_paddle_and_ball(room)
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


func _place_paddle_and_ball(room: Rect2) -> void:
	# same gap above the bottom wall as the hand-made levels had
	player.position = Vector2(room.get_center().x, room.end.y - 12)

	# somewhere over the middle half of the paddle's lane, so the first
	# downward launch is always catchable
	var ball_x := room.get_center().x + _rng.randf_range(-room.size.x / 4, room.size.x / 4)
	ball.position = Vector2(ball_x, room.end.y - 56)


## Splits the top of the room into a grid of spawn spots and fills a random
## handful of them. One enemy per spot, so they never overlap.
func _spawn_enemies(room: Rect2) -> void:
	if enemy_scenes.is_empty():
		push_warning("no enemy_scenes set on %s" % name)
		return

	var zone := Rect2(room.position, Vector2(room.size.x, room.size.y - bottom_clearance))
	var cols := floori(zone.size.x / enemy_spacing.x)
	var rows := floori(zone.size.y / enemy_spacing.y)
	# leftover space gets split evenly on both sides so the grid is centred
	var margin := (zone.size - Vector2(cols, rows) * enemy_spacing) / 2

	var spots: Array[Vector2] = []
	for row in rows:
		for col in cols:
			spots.append(zone.position + margin + (Vector2(col, row) + Vector2(0.5, 0.5)) * enemy_spacing)
	_shuffle(spots)

	var count := base_enemy_count + enemies_per_level * (LevelManager.level_number - 1)
	count = mini(count, spots.size())

	for i in count:
		var scene: PackedScene = enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
		var enemy := scene.instantiate()
		enemy.position = spots[i]
		enemies.add_child(enemy)


# Array.shuffle() uses the global RNG, so do it by hand to keep room_seed repeatable
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
