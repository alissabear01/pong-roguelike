extends Node
## Keeps track of how far into the run we are and runs the handoff between
## levels. Autoloaded as `LevelManager`.

## every level is a fresh roll of this scene -- procedural_level.gd builds the room on load
const LEVEL_SCENE := "res://scenes/levels/procedural_level.tscn"

## 1 on the first level, +1 per clear. the generator reads it to scale enemy count
var level_number: int = 1

# guards against two enemies dying on the same frame and starting two handoffs
var _changing: bool = false


## Called by level.gd once every enemy in the level is dead
func level_cleared() -> void:
	if _changing:
		return
	_changing = true

	# freeze the ball and paddle so nothing moves behind the banner
	get_tree().paused = true

	await Transition.show_banner("LEVEL CLEAR")
	await Transition.fade_out()

	level_number += 1
	get_tree().change_scene_to_file(LEVEL_SCENE)
	# the swap happens at the end of the frame, so wait for the new tree
	await get_tree().process_frame

	await Transition.fade_in()
	get_tree().paused = false
	_changing = false
