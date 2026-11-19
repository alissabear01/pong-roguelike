extends Node
## Keeps track of how far into the run we are and runs the handoff between
## levels. Autoloaded as `LevelManager`.

## every level is a fresh roll of this scene -- procedural_level.gd builds the room on load
const LEVEL_SCENE := "res://scenes/levels/procedural_level.tscn"

## the boss fight: a pong match against an AI paddle
const BOSS_SCENE := "res://scenes/levels/boss_level.tscn"

## every this-many-th level is a boss fight (5, 10, 15...)
const BOSS_EVERY := 5

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

## 1 on the first level, +1 per clear. the generator reads it to scale enemy count
var level_number: int = 1

# guards against two enemies dying on the same frame and starting two handoffs
var _changing: bool = false

# true while the boss fight is on, so beating it never leads straight into another
var _in_boss: bool = false


## B jumps straight to a boss fight from any normal level
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_B:
		go_to_boss()


## Called by level.gd once every enemy in the level is dead, and by the boss
## level (with its own banner) once the boss is beaten
func level_cleared(banner: String = "LEVEL CLEAR") -> void:
	if _changing:
		return
	_changing = true

	# freeze the ball and paddle so nothing moves behind the banner
	get_tree().paused = true
	await Transition.show_banner(banner)
	await Transition.fade_out()

	# pick an upgrade on the black screen, before the next level loads
	var id: String = await UpgradePicker.choose()
	RunState.apply_upgrade(id)

	level_number += 1
	var boss_next := level_number % BOSS_EVERY == 0 and not _in_boss
	_in_boss = boss_next
	if boss_next:
		await _swap_scene(BOSS_SCENE, "BOSS LEVEL")
	else:
		await _swap_scene(LEVEL_SCENE)


## Leaves the current level for a boss fight (the B key). Only from a normal
## level that's being played, not menus, fades, or a boss fight already on
func go_to_boss() -> void:
	var scene := get_tree().current_scene
	if _changing or _in_boss or get_tree().paused \
			or scene == null or scene.scene_file_path != LEVEL_SCENE:
		return
	_changing = true
	_in_boss = true
	get_tree().paused = true
	await _swap_scene(BOSS_SCENE, "BOSS LEVEL")


## Called by the main menu's Play button. Fresh run from level 1
func start_run() -> void:
	if _changing:
		return
	_changing = true

	RunState.reset_run()
	level_number = 1
	_in_boss = false
	await _swap_scene(LEVEL_SCENE)


## Called by the death zone when the last life is lost
func game_over() -> void:
	if _changing:
		return
	_changing = true

	get_tree().paused = true
	await Transition.show_banner("GAME OVER")
	_in_boss = false
	# roguelike rules: back to the title, the next Play starts a brand new run
	await _swap_scene(MAIN_MENU)


## Called by the pause menu's Main Menu button. Gives up on the current run
func quit_to_menu() -> void:
	if _changing:
		return
	_changing = true

	_in_boss = false
	# the game is already paused under the pause menu, so just fade and swap
	await _swap_scene(MAIN_MENU)


## True while a fade or scene swap is running, so the pause menu stays out of the way
func is_changing() -> bool:
	return _changing


# fades out, swaps to any scene, fades back in and unfreezes the game.
# with an intro, that banner shows over the new scene before play starts
func _swap_scene(path: String, intro: String = "") -> void:
	await Transition.fade_out()

	get_tree().change_scene_to_file(path)
	# the swap happens at the end of the frame, so wait for the new tree
	await get_tree().process_frame

	await Transition.fade_in()
	if intro != "":
		await Transition.show_banner(intro)
		await Transition.hide_banner()
	get_tree().paused = false
	_changing = false
