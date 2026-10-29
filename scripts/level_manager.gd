extends Node
## Keeps track of which level we're on and runs the handoff between them.
## Autoloaded as `LevelManager`.

## levels in play order -- drop a new scene path in here and it joins the rotation
const LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
]

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

var current_index: int = 0

# guards against two enemies dying on the same frame and starting two handoffs
var _changing: bool = false


## Called by level.gd on load so running a level straight from the editor
## still leaves us pointed at the right spot in LEVELS.
func register_level(scene_path: String) -> void:
	var i := LEVELS.find(scene_path)
	if i != -1:
		current_index = i


## Called by level.gd once every enemy in the level is dead
func level_cleared() -> void:
	if _changing:
		return
	_changing = true

	# freeze the ball and paddle so nothing moves behind the banner
	get_tree().paused = true
	await Transition.show_banner("LEVEL CLEAR")
	
	# wrap back to the first level for now so run doesnt dead end
	await _go_to_level((current_index +1 ) % LEVELS.size())
	
## Called by the main menu's Play button. Fresh run from level 1
func start_run() -> void:
	if _changing:
		return
	_changing = true

	RunState.reset_run()
	await _go_to_level(0)


## Called by the death zone when the last life is lost
func game_over() -> void:
	if _changing:
		return
	_changing = true

	get_tree().paused = true
	await Transition.show_banner("GAME OVER")
	# roguelike rules: back to the title, the next Play starts a brand new run
	await _swap_scene(MAIN_MENU)


func _go_to_level(index: int) -> void:
	current_index = index
	await _swap_scene(LEVELS[current_index])


# fades out, swaps to any scene, fades back in and unfreezes the game
func _swap_scene(path: String) -> void:
	await Transition.fade_out()

	get_tree().change_scene_to_file(path)
	# the swap happens at the end of the frame, so wait for the new tree
	await get_tree().process_frame

	await Transition.fade_in()
	get_tree().paused = false
	_changing = false
