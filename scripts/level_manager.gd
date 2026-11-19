extends Node
## Keeps track of how far into the run we are and runs the handoff between
## levels. Autoloaded as `LevelManager`.

## every level is a fresh roll of this scene -- procedural_level.gd builds the room on load
const LEVEL_SCENE := "res://scenes/levels/procedural_level.tscn"

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

## every this many levels is a boss level. 5 -> levels 5, 10, 15... the run is
## endless, so it just keeps going (and the bosses keep getting tougher)
const BOSS_EVERY: int = 5

## 1 on the first level, +1 per clear. the generator reads it to scale enemy count
var level_number: int = 1

## bosses killed this run. the boss reads it to scale its health
var bosses_beaten: int = 0

# guards against two enemies dying on the same frame and starting two handoffs
var _changing: bool = false


## Called by level.gd once every enemy in the level is dead
func level_cleared() -> void:
	if _changing:
		return
	_changing = true

	# freeze the ball and paddle so nothing moves behind the banner
	get_tree().paused = true

	if is_boss_level():
		await Transition.show_banner("Boss defeated")
		await Transition.fade_out()
		bosses_beaten += 1
		# a boss drops a special ball instead of the normal upgrade pick
		await _give_special_ball()
	else:
		await Transition.show_banner("Level clear")
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
	bosses_beaten = 0
	await _swap_scene(LEVEL_SCENE)


## Called by the death zone when the last life is lost
func game_over() -> void:
	if _changing:
		return
	_changing = true

	get_tree().paused = true
	await Transition.show_banner("Game over")
	# roguelike rules: back to the title, the next Play starts a brand new run
	await _swap_scene(MAIN_MENU)


## Called by the pause menu's Main Menu button. Gives up on the current run
func quit_to_menu() -> void:
	if _changing:
		return
	_changing = true

	# the game is already paused under the pause menu, so just fade and swap
	await _swap_scene(MAIN_MENU)


## True on every BOSS_EVERY-th level. the generator builds a boss room instead
func is_boss_level() -> bool:
	return level_number % BOSS_EVERY == 0


# HOOK for special balls: runs on the black screen after every boss.
# the plan is a random special ball drop (or a pick of a few), saved in
# RunState.special_ball so it lasts the rest of the run. ball.gd would read it
# in _ready() the same way it reads the other RunState upgrades.
# for now it just gives the normal upgrade pick so the boss isn't a dud
func _give_special_ball() -> void:
	var id: String = await UpgradePicker.choose()
	RunState.apply_upgrade(id)


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
