extends Node
## Keeps track of how far into the run we are and runs the handoff between
## levels. Autoloaded as `LevelManager`.

## every level is a fresh roll of this scene -- procedural_level.gd builds the room on load
const LEVEL_SCENE := "res://scenes/levels/procedural_level.tscn"

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

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

	# pick an upgrade on the black screen, before the next level loads
	var id: String = await UpgradePicker.choose()
	RunState.apply_upgrade(id)

	level_number += 1
	await _swap_scene(LEVEL_SCENE)


## Called by the main menu's Play button. Fresh run from level 1
func start_run() -> void:
	if _changing:
		return
	_changing = true

	RunState.reset_run()
	level_number = 1
	await _swap_scene(LEVEL_SCENE)


## Called by the death zone when the last life is lost
func game_over() -> void:
	if _changing:
		return
	_changing = true

	get_tree().paused = true
	await Transition.show_banner("GAME OVER")
	# roguelike rules: back to the title, the next Play starts a brand new run
	await _swap_scene(MAIN_MENU)


## Called by the pause menu's Main Menu button. Gives up on the current run
func quit_to_menu() -> void:
	if _changing:
		return
	_changing = true

	# the game is already paused under the pause menu, so just fade and swap
	await _swap_scene(MAIN_MENU)


## True while a fade or scene swap is running, so the pause menu stays out of the way
func is_changing() -> bool:
	return _changing


# fades out, swaps to any scene, fades back in and unfreezes the game
func _swap_scene(path: String) -> void:
	await Transition.fade_out()

	get_tree().change_scene_to_file(path)
	# the swap happens at the end of the frame, so wait for the new tree
	await get_tree().process_frame

	await Transition.fade_in()
	get_tree().paused = false
	_changing = false
