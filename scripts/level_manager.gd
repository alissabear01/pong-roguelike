extends Node
## Keeps track of which level we're on and runs the handoff between them.
## Autoloaded as `LevelManager`.

## levels in play order -- drop a new scene path in here and it joins the rotation
const LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
]

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
	await Transition.fade_out()

	# wrap back to the first level for now so the run never dead-ends
	current_index = (current_index + 1) % LEVELS.size()
	get_tree().change_scene_to_file(LEVELS[current_index])
	# the swap happens at the end of the frame, so wait for the new tree
	await get_tree().process_frame

	await Transition.fade_in()
	get_tree().paused = false
	_changing = false
