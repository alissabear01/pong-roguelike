extends Control
## Title screen. The first scene the game opens on (Project Settings > Application > Run > Main Scene).

@onready var play_button: Button = $Layout/PlayButton
@onready var quit_button: Button = $Layout/QuitButton


func _ready() -> void:
	# the HUD is an autoload, so it would sit on top of the menu unless we hide it
	Hud.hide()
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# focus Play so Enter starts the game without touching the mouse
	play_button.grab_focus()


func _on_play_pressed() -> void:
	LevelManager.start_run()


func _on_quit_pressed() -> void:
	get_tree().quit()
