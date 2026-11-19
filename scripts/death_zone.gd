extends Area2D
## invisible strip outside the paddle's hole. a ball that falls into it is gone,
## and losing the last ball in play costs a life.


func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# only balls count, ignore anything else that wanders in
	if not body is Ball:
		return

	# take it out of the count right away, so two balls falling in on the same
	# frame can't both think another one is still left
	body.remove_from_group("balls")
	if not get_tree().get_nodes_in_group("balls").is_empty():
		# other balls are still in play, so this one just disappears
		body.queue_free()
		return

	# that was the last one: lose a life and bring it back at the paddle
	body.add_to_group("balls")
	Sfx.play(&"life_lost")
	var run_over := RunState.lose_life()
	if run_over:
		LevelManager.game_over()
	else:
		body.respawn()
