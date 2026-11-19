extends Node2D
## The boss room: a pong court. Our paddle guards the bottom, the boss's paddle
## guards the top, walls down both sides. Get a ball past the boss to hurt it;
## a ball past us works like any level (only the last ball costs a life).
## Chests keep turning up in the middle and let out extra balls.

const TILE_SIZE := 16
const WALL_SOURCE := 0
const WALL_ATLAS := Vector2i(0, 0)

## court interior in tiles. the screen fits 30x16 walls included
@export var court_size := Vector2i(16, 12)

## chest that turns up in the middle of the court; breaking it lets out a ball
@export var chest_scene: PackedScene
## the ball scene, for the extra balls that come out of chests
@export var ball_scene: PackedScene
## seconds after the fight starts, or after the last chest broke, before a new
## chest turns up. only one at a time
@export var chest_interval: float = 5.0
## how far from dead centre (px) a chest can land
@export var chest_spread := Vector2(56, 20)

@onready var walls: TileMapLayer = $Walls
@onready var ball: Ball = $Ball
@onready var player: Player = $Player
@onready var boss: Node2D = $Boss
@onready var death_zone: Area2D = $DeathZone
@onready var goal: Area2D = $BossGoal
@onready var camera: Camera2D = $Camera2D
@onready var bar_fill: ColorRect = $BossBar/Bar/Fill

var _court: Rect2
# where every ball respawns, above our paddle
var _ball_start: Vector2
var _chest_timer := Timer.new()


func _ready() -> void:
	Hud.show()
	_court = _build_walls()
	camera.position = _court.get_center()

	# our paddle slides along the open bottom row, the boss along the top
	var bottom_y := _court.end.y + TILE_SIZE / 2.0
	var top_y := _court.position.y - TILE_SIZE / 2.0
	var outs: Array[Vector2] = [Vector2.DOWN]
	player.set_track(PackedVector2Array([
		Vector2(_court.position.x, bottom_y), Vector2(_court.end.x, bottom_y)]), outs, 0)
	boss.position = Vector2(_court.get_center().x, top_y)
	boss.set_lane(_court.position.x, _court.end.x)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)

	_ball_start = player.position + Vector2.UP * (TILE_SIZE / 2.0 + 56)
	# the ball sits on our paddle and gets aimed up the court, same as a normal level
	ball.paddle = player
	ball.set_start(_ball_start, Vector2.UP)

	# a strip past each open end: ours costs balls, the boss's costs it health
	_place_strip(death_zone, bottom_y + TILE_SIZE / 2.0, 1.0)
	_place_strip(goal, top_y - TILE_SIZE / 2.0, -1.0)
	goal.body_entered.connect(_on_goal)

	_chest_timer.one_shot = true
	_chest_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_chest_timer.timeout.connect(_spawn_chest)
	add_child(_chest_timer)
	_chest_timer.start(chest_interval)


## Walls down both sides of the court, plus one cell at each corner of the
## top and bottom rows so the paddles' lanes have ends. Returns the interior.
func _build_walls() -> Rect2:
	var origin := -court_size / 2
	for y in range(origin.y - 1, origin.y + court_size.y + 1):
		walls.set_cell(Vector2i(origin.x - 1, y), WALL_SOURCE, WALL_ATLAS)
		walls.set_cell(Vector2i(origin.x + court_size.x, y), WALL_SOURCE, WALL_ATLAS)
	return Rect2(Vector2(origin * TILE_SIZE), Vector2(court_size * TILE_SIZE))


# lays a wide strip on area just past edge_y, on the side side points to (1 below, -1 above)
func _place_strip(area: Area2D, edge_y: float, side: float) -> void:
	var collision: CollisionShape2D = area.get_node("CollisionShape2D")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 200)
	collision.shape = shape
	collision.position = Vector2(_court.get_center().x, edge_y + side * shape.size.y / 2)


func _on_goal(body: Node2D) -> void:
	if not body is Ball:
		return
	Sfx.play(&"boss_hurt")
	boss.take_goal()

	# like losing a ball on our side, minus the life: extra balls just vanish,
	# the last one comes back to our paddle
	body.remove_from_group("balls")
	if get_tree().get_nodes_in_group("balls").is_empty():
		body.add_to_group("balls")
		body.respawn()
	else:
		body.queue_free()


func _on_boss_health_changed(health: int, max_health: int) -> void:
	var tween := create_tween()
	tween.tween_property(bar_fill, "anchor_right", float(health) / max_health, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_boss_defeated() -> void:
	Sfx.play(&"boss_defeated")
	LevelManager.level_cleared("Boss defeated")


## Puts a chest near the middle of the court, unless a ball is right there.
func _spawn_chest() -> void:
	if chest_scene == null:
		return
	for attempt in 16:
		var pos := _court.get_center() + Vector2(
			randf_range(-chest_spread.x, chest_spread.x),
			randf_range(-chest_spread.y, chest_spread.y))
		var clear := true
		for b: Node2D in get_tree().get_nodes_in_group("balls"):
			if pos.distance_to(b.global_position) < 24.0:
				clear = false
				break
		if not clear:
			continue
		var chest := chest_scene.instantiate()
		chest.position = pos
		# deferred: the chest breaks in the middle of a ball's physics step
		chest.ball_released.connect(_on_chest_broken, CONNECT_DEFERRED)
		add_child(chest)
		return
	# a ball is sitting in the middle, try again shortly
	_chest_timer.start(1.0)


func _on_chest_broken(pos: Vector2) -> void:
	if ball_scene:
		var new_ball: Ball = ball_scene.instantiate()
		add_child(new_ball)
		# paddle set after it is in the tree so its own first launch cannot grab
		# it, and it never waits on the paddle. if it ends up the last ball it
		# comes back for an aimed shot like the first one
		new_ball.paddle = player
		new_ball.set_respawn(_ball_start, Vector2.UP)
		new_ball.release(pos)
		new_ball.flash_upgrade()
	_chest_timer.start(chest_interval)
