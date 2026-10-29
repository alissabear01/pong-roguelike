extends Node
## everything that lasts for one whole run: lives, upgrades
## autoloaded as 'RunState', so it survives scene changes between levels

## fires whenever lives go up or down, so the HUD can redraw

signal lives_changed(lives: int)

const STARTING_LIVES: int = 3

var lives: int

func _ready() -> void:
	reset_run()
	

## puts everything back to a fresh run. called at startup and after game over
func reset_run() -> void:
	lives = STARTING_LIVES
	lives_changed.emit(lives)
	
## takes a life away. returns true if that was the last one
func lose_life() -> bool:
	lives -= 1
	lives_changed.emit(lives)
	return lives <= 0
