extends Node2D

enum GameState { READY, PLAYING, WON }

@onready var ball: Ball = $Ball
@onready var score_label: Label = $HUD/TopBar/Score
@onready var enemies_label: Label = $HUD/TopBar/Enemies
@onready var message_label: Label = $HUD/MessageBand/Message
@onready var prompt_label: Label = $HUD/MessageBand/Prompt
@onready var message_band: ColorRect = $HUD/MessageBand
@onready var upgrade_notice: ColorRect = $HUD/UpgradeNotice
@onready var upgrade_label: Label = $HUD/UpgradeNotice/Upgrade

var game_state := GameState.READY
var score := 0
var enemies_remaining := 0


func _ready() -> void:
	ball.set_physics_process(false)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemies_remaining += 1
		enemy.connect("damaged", _on_enemy_damaged)
		enemy.connect("defeated", _on_enemy_defeated)

	for chest in get_tree().get_nodes_in_group("upgrade_chests"):
		chest.connect("upgrade_revealed", _on_upgrade_revealed)

	_update_hud()
	_show_message("PONG ROGUELIKE", "SPACE TO LAUNCH")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("launch_ball"):
		if game_state == GameState.READY:
			_start_round()
		elif game_state == GameState.WON:
			get_tree().reload_current_scene()
	elif event.is_action_pressed("restart_level"):
		get_tree().reload_current_scene()


func _start_round() -> void:
	game_state = GameState.PLAYING
	message_band.hide()
	ball.set_physics_process(true)


func _on_enemy_damaged() -> void:
	score += 100
	_update_hud()


func _on_enemy_defeated() -> void:
	enemies_remaining = maxi(enemies_remaining - 1, 0)
	_update_hud()

	if enemies_remaining == 0:
		game_state = GameState.WON
		ball.set_physics_process(false)
		_show_message("ROOM CLEARED", "SPACE TO PLAY AGAIN")


func _on_upgrade_revealed(upgrade: StringName) -> void:
	var upgrade_text := ball.apply_upgrade(upgrade)
	score += 250
	_update_hud()

	upgrade_label.text = upgrade_text
	upgrade_notice.modulate = Color.WHITE
	upgrade_notice.show()

	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(upgrade_notice, "modulate:a", 0.0, 0.35)
	tween.tween_callback(upgrade_notice.hide)


func _update_hud() -> void:
	score_label.text = "SCORE  %04d" % score
	enemies_label.text = "ENEMIES  %d" % enemies_remaining


func _show_message(title: String, prompt: String) -> void:
	message_label.text = title
	prompt_label.text = prompt
	message_band.show()
