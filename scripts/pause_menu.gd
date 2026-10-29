extends CanvasLayer
## Esc pauses a level and shows Resume / Main Menu. Autoloaded as `PauseMenu`.
## Process mode is Always, so it can still hear Esc and clicks while the tree is paused.

@onready var resume_button: Button = $Layout/ResumeButton
@onready var menu_button: Button = $Layout/MenuButton


func _ready() -> void:
	hide()
	resume_button.pressed.connect(_resume)
	menu_button.pressed.connect(_on_menu_pressed)


# ui_cancel is Godot's built-in action for Esc, so no new input map entry is needed
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		_resume()
	elif _can_pause():
		_pause()
	get_viewport().set_input_as_handled()


# only pause during normal play: in a level, not mid-fade, not while picking an upgrade
func _can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not LevelManager.LEVELS.has(scene.scene_file_path):
		return false
	return not LevelManager.is_changing() and not UpgradePicker.visible


func _pause() -> void:
	get_tree().paused = true
	show()
	# focus Resume so Enter or Esc gets you straight back in
	resume_button.grab_focus()


func _resume() -> void:
	hide()
	get_tree().paused = false


func _on_menu_pressed() -> void:
	hide()
	LevelManager.quit_to_menu()
