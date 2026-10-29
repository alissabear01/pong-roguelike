extends Node
## everything that lasts for one whole run: lives, upgrades
## autoloaded as 'RunState', so it survives scene changes between levels

## fires whenever lives go up or down, so the HUD can redraw

signal lives_changed(lives: int)

const STARTING_LIVES: int = 3

## every upgrade the picker can offer. add a new one here + a match branch in apply_upgrade()
const UPGRADES: Array[Dictionary] = [
	{"id": "fast_ball", "name": "Fast Ball", "desc": "Ball speed +20%"},
	{"id": "slow_ball", "name": "Slow Ball", "desc": "Ball speed -20%"},
	{"id": "big_paddle", "name": "Big Paddle", "desc": "Paddle 25% wider"},
]

var lives: int

## 1.0 = normal. the ball and paddle multiply by these when a level loads
var ball_speed_mult: float
var paddle_width_mult: float

func _ready() -> void:
	reset_run()
	

## puts everything back to a fresh run. called at startup and when Play starts a run
func reset_run() -> void:
	lives = STARTING_LIVES
	ball_speed_mult = 1.0
	paddle_width_mult = 1.0
	lives_changed.emit(lives)
	
## takes a life away. returns true if that was the last one
func lose_life() -> bool:
	lives -= 1
	lives_changed.emit(lives)
	return lives <= 0

## applies an upgrade by its id. upgrades stack, so taking big_paddle twice makes it even wider
func apply_upgrade(id: String) -> void:
	match id:
		"fast_ball":
			ball_speed_mult *= 1.2
		"slow_ball":
			ball_speed_mult *= 0.8
		"big_paddle":
			paddle_width_mult *= 1.25
		_:
			# catches typos in an id so they don't fail silently
			push_warning("unknown upgrade: %s" % id)
