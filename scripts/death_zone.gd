extends Area2D
## invisible strip below the paddle. if the ball falls into it, the player loses a life.


func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# only the ball counts, ignore anything else that wanders in
	if not body is Ball:
		return
		
	var run_over := RunState.lose_life()
	if run_over:
		LevelManager.game_over()
	else:
		body.respawn()
	
